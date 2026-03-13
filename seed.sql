-- ============================================================
--  Retro Clurix Miners — Seed / Demo Data
--  Run AFTER schema.sql
-- ============================================================
USE `rcm_db`;

-- ── Demo users (password for all = "Demo1234!")
--    Hash generated with PASSWORD_BCRYPT cost 12
INSERT INTO `users`
  (`uuid`,`email`,`password_hash`,`first_name`,`last_name`,`country`,`referral_code`,`experience`,`email_verified`,`kyc_status`,`kyc_level`,`role`,`status`,`last_login_at`)
VALUES
(
  '00000000-0000-0000-0000-000000000001',
  'admin@retroclurixminers.net',
  '$2y$12$eImiTXuWVxfM37uY4JANjQe5LmB0RkCbwCIBm91Z.ZHVbAl4OLVHK', -- Demo1234!
  'Alex','Kovalenko','United Kingdom','ADMIN001','professional',1,'approved',3,'admin','active',NOW()
),
(
  '00000000-0000-0000-0000-000000000002',
  'demo@retroclurixminers.net',
  '$2y$12$eImiTXuWVxfM37uY4JANjQe5LmB0RkCbwCIBm91Z.ZHVbAl4OLVHK',
  'Demo','User','United States','DEMO001','intermediate',1,'approved',2,'user','active',NOW()
),
(
  '00000000-0000-0000-0000-000000000003',
  'trader@example.com',
  '$2y$12$eImiTXuWVxfM37uY4JANjQe5LmB0RkCbwCIBm91Z.ZHVbAl4OLVHK',
  'James','Harrington','Australia','TRD0003','experienced',1,'approved',2,'user','active',NOW()
);

-- ── Wallets for demo users
INSERT INTO `wallets` (`user_id`,`currency`,`balance`,`locked`) VALUES
(1,'USD',  250000.00,  0.00),
(1,'BTC',       4.82500000, 0),
(1,'ETH',      42.00000000, 0),
(2,'USD',   12430.50,   500.00),
(2,'BTC',       0.18240000, 0.01),
(2,'ETH',       2.44000000, 0),
(2,'USDT',   3200.00,   0.00),
(3,'USD',   45870.00,  2000.00),
(3,'BTC',       0.65000000, 0),
(3,'ETH',       8.10000000, 0);

-- ── Transactions for demo user (id=2)
INSERT INTO `transactions` (`uuid`,`user_id`,`wallet_id`,`type`,`currency`,`amount`,`fee`,`status`,`method`,`processed_at`) VALUES
('tx-0001-demo',2,4,'deposit','USD',  5000.00, 0.00,'completed','bitcoin',         DATE_SUB(NOW(),INTERVAL 30 DAY)),
('tx-0002-demo',2,4,'deposit','USD',  3000.00, 0.00,'completed','card',            DATE_SUB(NOW(),INTERVAL 22 DAY)),
('tx-0003-demo',2,5,'deposit','BTC',     0.05, 0.00,'completed','bitcoin',         DATE_SUB(NOW(),INTERVAL 18 DAY)),
('tx-0004-demo',2,4,'trade_pnl','USD', 840.50, 0.00,'completed',NULL,             DATE_SUB(NOW(),INTERVAL 14 DAY)),
('tx-0005-demo',2,4,'trade_fee','USD', -12.40, 0.00,'completed',NULL,             DATE_SUB(NOW(),INTERVAL 14 DAY)),
('tx-0006-demo',2,4,'trade_pnl','USD',-320.00, 0.00,'completed',NULL,             DATE_SUB(NOW(),INTERVAL 10 DAY)),
('tx-0007-demo',2,4,'withdrawal','USD',-1000.00,25.00,'completed','bank_wire',    DATE_SUB(NOW(),INTERVAL 7 DAY)),
('tx-0008-demo',2,4,'deposit','USD',  2000.00, 0.00,'completed','usdt',           DATE_SUB(NOW(),INTERVAL 3 DAY)),
('tx-0009-demo',2,4,'trade_pnl','USD', 522.40, 0.00,'completed',NULL,             DATE_SUB(NOW(),INTERVAL 1 DAY)),
('tx-0010-demo',2,4,'withdrawal','USD',-500.00,0.00,'pending',  'bitcoin',        NULL);

-- ── Closed trades for demo user (id=2)
INSERT INTO `trades`
  (`uuid`,`user_id`,`instrument_id`,`direction`,`status`,`quantity`,`leverage`,`margin_used`,`open_price`,`close_price`,`stop_loss`,`take_profit`,`realised_pnl`,`fee_open`,`fee_close`,`opened_at`,`closed_at`)
VALUES
('tr-0001',2,1,'long','closed',0.05,10,338.00, 67600.00,69280.00,65000.00,71000.00, 84.00,0.0034,0.0035,DATE_SUB(NOW(),INTERVAL 20 DAY),DATE_SUB(NOW(),INTERVAL 14 DAY)),
('tr-0002',2,2,'short','closed',0.30,5, 212.00, 3540.00, 3680.00, 3600.00,3400.00,-42.00,0.0018,0.0018,DATE_SUB(NOW(),INTERVAL 16 DAY),DATE_SUB(NOW(),INTERVAL 12 DAY)),
('tr-0003',2,7,'long','closed',1000,50,217.30,  1.0832,  1.0865, 1.0800,  1.0900,  32.50,0.0000,0.0003,DATE_SUB(NOW(),INTERVAL 12 DAY),DATE_SUB(NOW(),INTERVAL 10 DAY)),
('tr-0004',2,11,'long','closed',0.10,10,231.00, 2298.00, 2310.00, 2250.00,2380.00,  12.00,0.0000,0.0005,DATE_SUB(NOW(),INTERVAL 8 DAY),DATE_SUB(NOW(),INTERVAL 5 DAY)),
('tr-0005',2,14,'long','closed',2.00,20,524.88, 5234.00, 5248.80, 5100.00,5400.00, 29.60,0.0000,0.0005,DATE_SUB(NOW(),INTERVAL 5 DAY),DATE_SUB(NOW(),INTERVAL 1 DAY));

-- ── Open positions for demo user (id=2)
INSERT INTO `trades`
  (`uuid`,`user_id`,`instrument_id`,`direction`,`status`,`quantity`,`leverage`,`margin_used`,`open_price`,`stop_loss`,`take_profit`,`liquidation_price`,`fee_open`,`opened_at`)
VALUES
('tr-0006',2,1,'long','open',0.08,10,540.00, 67420.00,65000.00,72000.00,61280.00,0.0034,DATE_SUB(NOW(),INTERVAL 2 DAY)),
('tr-0007',2,2,'long','open',0.50,5, 354.00,  3540.00, 3300.00, 4000.00, 3186.00,0.0018,DATE_SUB(NOW(),INTERVAL 1 DAY));

-- ── Audit log entries
INSERT INTO `audit_log` (`user_id`,`action`,`ip_address`,`details`) VALUES
(2,'register',   '102.88.12.44', JSON_OBJECT('method','email')),
(2,'email_verify','102.88.12.44',JSON_OBJECT('status','verified')),
(2,'login',      '102.88.12.44', JSON_OBJECT('method','email','success',true)),
(2,'deposit',    '102.88.12.44', JSON_OBJECT('amount',5000,'currency','USD','method','bitcoin')),
(2,'trade_open', '102.88.12.44', JSON_OBJECT('instrument','BTC/USD','direction','long','leverage',10)),
(2,'withdrawal', '102.88.12.44', JSON_OBJECT('amount',1000,'currency','USD','method','bank_wire'));