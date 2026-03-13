<?php
// ============================================================
//  Retro Clurix Miners — Protected API Endpoints
//  GET  /api/me.php           → current user profile
//  GET  /api/wallets.php      → user wallets
//  GET  /api/trades.php       → trade history + open positions
//  POST /api/trades.php       → open a new trade
//  PUT  /api/trades.php       → close a trade
//  GET  /api/transactions.php → transaction history
// ============================================================
require_once __DIR__ . '/../includes/helpers.php';
cors();

$uri    = strtok($_SERVER['REQUEST_URI'], '?');
$method = $_SERVER['REQUEST_METHOD'];

// ── Route ─────────────────────────────────────────────────────
if (str_ends_with($uri, 'me.php'))           route_me($method);
elseif (str_ends_with($uri, 'wallets.php'))  route_wallets($method);
elseif (str_ends_with($uri, 'trades.php'))   route_trades($method);
elseif (str_ends_with($uri, 'transactions.php')) route_transactions($method);
else fail('Not found.', 404);


// ── GET /api/me.php ───────────────────────────────────────────
function route_me(string $method): never {
    if ($method !== 'GET') fail('Method not allowed.', 405);
    $user = auth();
    ok(['user' => [
        'uuid'         => $user['uuid'],
        'email'        => $user['email'],
        'first_name'   => $user['first_name'],
        'last_name'    => $user['last_name'],
        'country'      => $user['country'],
        'phone'        => $user['phone'],
        'role'         => $user['role'],
        'kyc_status'   => $user['kyc_status'],
        'kyc_level'    => $user['kyc_level'],
        'two_fa'       => (bool)$user['two_fa_enabled'],
        'referral_code'=> $user['referral_code'],
        'created_at'   => $user['created_at'],
        'last_login_at'=> $user['last_login_at'],
    ]]);
}


// ── GET /api/wallets.php ──────────────────────────────────────
function route_wallets(string $method): never {
    if ($method !== 'GET') fail('Method not allowed.', 405);
    $user = auth();

    $stmt = db()->prepare(
        'SELECT currency, balance, locked,
                (balance - locked) AS available,
                updated_at
         FROM wallets WHERE user_id = ? ORDER BY currency'
    );
    $stmt->execute([$user['id']]);
    $wallets = $stmt->fetchAll();

    // Compute total in USD (simplified — production would use live rates)
    $rates   = ['USD'=>1,'BTC'=>67420,'ETH'=>3540,'USDT'=>1,'LTC'=>84.4,'XRP'=>0.612];
    $total_usd = array_reduce($wallets, function($carry, $w) use ($rates) {
        $rate = $rates[$w['currency']] ?? 0;
        return $carry + ((float)$w['balance'] * $rate);
    }, 0.0);

    ok(['wallets' => $wallets, 'total_usd' => round($total_usd, 2)]);
}


// ── /api/trades.php ───────────────────────────────────────────
function route_trades(string $method): never {
    $user = auth();

    if ($method === 'GET') {
        $status = $_GET['status'] ?? null; // open | closed | liquidated

        $sql = 'SELECT t.*, i.symbol, i.category, i.max_leverage
                FROM trades t
                JOIN instruments i ON i.id = t.instrument_id
                WHERE t.user_id = ?';
        $params = [$user['id']];
        if ($status) { $sql .= ' AND t.status = ?'; $params[] = $status; }
        $sql .= ' ORDER BY t.opened_at DESC LIMIT 200';

        $stmt = db()->prepare($sql);
        $stmt->execute($params);
        ok(['trades' => $stmt->fetchAll()]);
    }

    if ($method === 'POST') {
        $data = require_fields(['symbol','direction','quantity','leverage']);

        $symbol    = strtoupper(trim($data['symbol']));
        $direction = $data['direction'];
        $quantity  = (float)$data['quantity'];
        $leverage  = (int)$data['leverage'];
        $sl        = isset($data['stop_loss'])    ? (float)$data['stop_loss']    : null;
        $tp        = isset($data['take_profit'])  ? (float)$data['take_profit']  : null;

        if (!in_array($direction, ['long','short'])) fail('Direction must be long or short.');
        if ($quantity <= 0)  fail('Quantity must be greater than 0.');
        if ($leverage < 1)   fail('Leverage must be at least 1.');

        // Load instrument
        $inst = db()->prepare('SELECT * FROM instruments WHERE symbol = ? AND is_active = 1');
        $inst->execute([$symbol]);
        $instrument = $inst->fetch();
        if (!$instrument) fail('Instrument not found or inactive.');

        if ($leverage > $instrument['max_leverage'])
            fail("Max leverage for {$symbol} is {$instrument['max_leverage']}×.");

        // For demo: use a fixed "current price" — production would pull from price feed
        $prices = [
            'BTC/USD'=>67420,'ETH/USD'=>3540,'LTC/USD'=>84.4,'XRP/USD'=>0.612,
            'EUR/USD'=>1.0865,'GBP/USD'=>1.263,'USD/JPY'=>149.20,
            'GOLD'=>2310,'SILVER'=>27.4,'CRUDE'=>78.4,
            'SP500'=>5248.8,'NASDAQ'=>18320,'GER30'=>18540,
        ];
        $open_price = $prices[$symbol] ?? fail("No price available for {$symbol}.");

        $notional   = $quantity * $open_price;
        $margin_usd = $notional / $leverage;

        if ($margin_usd < $instrument['min_trade_usd'])
            fail("Minimum trade size is \${$instrument['min_trade_usd']}.");

        // Check USD wallet balance
        $wallet = db()->prepare('SELECT * FROM wallets WHERE user_id=? AND currency="USD"');
        $wallet->execute([$user['id']]);
        $usd = $wallet->fetch();
        if (!$usd || ((float)$usd['balance'] - (float)$usd['locked']) < $margin_usd)
            fail('Insufficient USD balance.');

        // Liquidation price
        $liq_price = $direction === 'long'
            ? $open_price * (1 - 1 / $leverage * 0.9)
            : $open_price * (1 + 1 / $leverage * 0.9);

        $fee = $notional * $instrument['taker_fee'];
        $uuid = uuid4();

        db()->beginTransaction();
        try {
            // Lock margin in wallet
            db()->prepare('UPDATE wallets SET locked = locked + ? WHERE user_id=? AND currency="USD"')
                ->execute([$margin_usd, $user['id']]);

            // Deduct fee from balance
            db()->prepare('UPDATE wallets SET balance = balance - ? WHERE user_id=? AND currency="USD"')
                ->execute([$fee, $user['id']]);

            // Insert trade
            db()->prepare(
                'INSERT INTO trades
                   (uuid,user_id,instrument_id,direction,quantity,leverage,margin_used,
                    open_price,stop_loss,take_profit,liquidation_price,fee_open)
                 VALUES (?,?,?,?,?,?,?,?,?,?,?,?)'
            )->execute([
                $uuid, $user['id'], $instrument['id'], $direction,
                $quantity, $leverage, $margin_usd,
                $open_price, $sl, $tp, $liq_price, $fee
            ]);

            db()->commit();
        } catch (\Throwable $e) {
            db()->rollBack();
            fail('Trade could not be placed. Please try again.');
        }

        audit((int)$user['id'], 'trade_open', ['symbol'=>$symbol,'direction'=>$direction,'leverage'=>$leverage]);

        ok([
            'message'     => 'Trade opened successfully.',
            'trade_uuid'  => $uuid,
            'open_price'  => $open_price,
            'margin_used' => round($margin_usd, 2),
            'fee'         => round($fee, 6),
        ]);
    }

    if ($method === 'PUT') {
        // Close a trade
        $data      = require_fields(['trade_uuid']);
        $trade_uuid = $data['trade_uuid'];

        $stmt = db()->prepare(
            'SELECT t.*, i.symbol, i.taker_fee FROM trades t
             JOIN instruments i ON i.id=t.instrument_id
             WHERE t.uuid=? AND t.user_id=? AND t.status="open"'
        );
        $stmt->execute([$trade_uuid, $user['id']]);
        $trade = $stmt->fetch();
        if (!$trade) fail('Open trade not found.');

        // Demo close price (production: live feed)
        $prices = [
            'BTC/USD'=>67420,'ETH/USD'=>3540,'LTC/USD'=>84.4,'XRP/USD'=>0.612,
            'EUR/USD'=>1.0865,'GBP/USD'=>1.263,'USD/JPY'=>149.20,
            'GOLD'=>2310,'SILVER'=>27.4,'CRUDE'=>78.4,
            'SP500'=>5248.8,'NASDAQ'=>18320,'GER30'=>18540,
        ];
        $close_price = $prices[$trade['symbol']] ?? (float)$trade['open_price'];

        $notional    = (float)$trade['quantity'] * $close_price;
        $fee_close   = $notional * $trade['taker_fee'];

        $pnl = $trade['direction'] === 'long'
            ? ($close_price - $trade['open_price']) * $trade['quantity'] - $fee_close
            : ($trade['open_price'] - $close_price) * $trade['quantity'] - $fee_close;

        $pnl = round($pnl, 2);

        db()->beginTransaction();
        try {
            // Release locked margin + add P&L back to balance
            db()->prepare(
                'UPDATE wallets SET
                   locked  = locked  - ?,
                   balance = balance + ? + ?
                 WHERE user_id=? AND currency="USD"'
            )->execute([$trade['margin_used'], $trade['margin_used'], $pnl, $user['id']]);

            db()->prepare(
                'UPDATE trades SET status="closed", close_price=?, realised_pnl=?, fee_close=?, closed_at=NOW()
                 WHERE uuid=?'
            )->execute([$close_price, $pnl, $fee_close, $trade_uuid]);

            db()->commit();
        } catch (\Throwable $e) {
            db()->rollBack();
            fail('Could not close trade. Please try again.');
        }

        audit((int)$user['id'], 'trade_close', ['uuid'=>$trade_uuid,'pnl'=>$pnl]);
        ok(['message'=>'Trade closed.','close_price'=>$close_price,'realised_pnl'=>$pnl]);
    }

    fail('Method not allowed.', 405);
}


// ── GET /api/transactions.php ─────────────────────────────────
function route_transactions(string $method): never {
    if ($method !== 'GET') fail('Method not allowed.', 405);
    $user = auth();

    $limit  = min((int)($_GET['limit']  ?? 50), 200);
    $offset = (int)($_GET['offset'] ?? 0);
    $type   = $_GET['type'] ?? null;

    $sql    = 'SELECT t.*, w.currency as wallet_currency FROM transactions t
               JOIN wallets w ON w.id = t.wallet_id
               WHERE t.user_id = ?';
    $params = [$user['id']];
    if ($type) { $sql .= ' AND t.type = ?'; $params[] = $type; }
    $sql .= ' ORDER BY t.created_at DESC LIMIT ? OFFSET ?';
    $params[] = $limit;
    $params[] = $offset;

    $stmt = db()->prepare($sql);
    $stmt->execute($params);

    ok(['transactions' => $stmt->fetchAll(), 'limit' => $limit, 'offset' => $offset]);
}