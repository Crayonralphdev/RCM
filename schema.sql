-- ============================================================
--  Retro Clurix Miners — MySQL Database Schema
--  Drop & recreate for clean install
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

CREATE DATABASE IF NOT EXISTS `rcm_db`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `rcm_db`;

-- ── 1. USERS ─────────────────────────────────────────────────
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `uuid`            CHAR(36)        NOT NULL UNIQUE,          -- public-facing ID
  `email`           VARCHAR(255)    NOT NULL UNIQUE,
  `password_hash`   VARCHAR(255)    NOT NULL,
  `first_name`      VARCHAR(80)     NOT NULL DEFAULT '',
  `last_name`       VARCHAR(80)     NOT NULL DEFAULT '',
  `phone`           VARCHAR(30)     DEFAULT NULL,
  `country`         VARCHAR(80)     DEFAULT NULL,
  `referral_code`   VARCHAR(20)     NOT NULL UNIQUE,          -- their own referral code
  `referred_by`     VARCHAR(20)     DEFAULT NULL,             -- code used at signup
  `experience`      ENUM('beginner','some','intermediate','experienced','professional') DEFAULT 'beginner',
  -- Auth
  `email_verified`  TINYINT(1)      NOT NULL DEFAULT 0,
  `verify_token`    VARCHAR(80)     DEFAULT NULL,
  `reset_token`     VARCHAR(80)     DEFAULT NULL,
  `reset_expires`   DATETIME        DEFAULT NULL,
  `two_fa_secret`   VARCHAR(80)     DEFAULT NULL,
  `two_fa_enabled`  TINYINT(1)      NOT NULL DEFAULT 0,
  -- KYC
  `kyc_status`      ENUM('none','pending','approved','rejected') NOT NULL DEFAULT 'none',
  `kyc_level`       TINYINT         NOT NULL DEFAULT 0,       -- 0=none 1=email 2=id 3=enhanced
  `kyc_submitted_at` DATETIME       DEFAULT NULL,
  `kyc_reviewed_at`  DATETIME       DEFAULT NULL,
  -- Account
  `role`            ENUM('user','admin','support') NOT NULL DEFAULT 'user',
  `status`          ENUM('active','suspended','banned') NOT NULL DEFAULT 'active',
  `login_attempts`  TINYINT         NOT NULL DEFAULT 0,
  `locked_until`    DATETIME        DEFAULT NULL,
  `last_login_at`   DATETIME        DEFAULT NULL,
  `last_login_ip`   VARCHAR(45)     DEFAULT NULL,
  `created_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_email`   (`email`),
  INDEX `idx_uuid`    (`uuid`),
  INDEX `idx_kyc`     (`kyc_status`),
  INDEX `idx_status`  (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── 2. USER SESSIONS ─────────────────────────────────────────
DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED  NOT NULL,
  `token`       VARCHAR(128)  NOT NULL UNIQUE,        -- secure random token stored in cookie
  `ip_address`  VARCHAR(45)   DEFAULT NULL,
  `user_agent`  VARCHAR(255)  DEFAULT NULL,
  `expires_at`  DATETIME      NOT NULL,
  `created_at`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_token`   (`token`),
  INDEX `idx_user`    (`user_id`),
  CONSTRAINT `fk_session_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ── 3. WALLETS ───────────────────────────────────────────────
DROP TABLE IF EXISTS `wallets`;
CREATE TABLE `wallets` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED  NOT NULL,
  `currency`    VARCHAR(10)   NOT NULL,               -- USD, BTC, ETH, USDT …
  `balance`     DECIMAL(24,8) NOT NULL DEFAULT 0.00000000,
  `locked`      DECIMAL(24,8) NOT NULL DEFAULT 0.00000000,  -- held in open orders
  `created_at`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_currency` (`user_id`, `currency`),
  CONSTRAINT `fk_wallet_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ── 4. TRANSACTIONS ──────────────────────────────────────────
DROP TABLE IF EXISTS `transactions`;
CREATE TABLE `transactions` (
  `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `uuid`            CHAR(36)        NOT NULL UNIQUE,
  `user_id`         INT UNSIGNED    NOT NULL,
  `wallet_id`       INT UNSIGNED    NOT NULL,
  `type`            ENUM('deposit','withdrawal','trade_fee','trade_pnl','referral_bonus','contest_prize') NOT NULL,
  `currency`        VARCHAR(10)     NOT NULL,
  `amount`          DECIMAL(24,8)   NOT NULL,          -- positive = credit, negative = debit
  `fee`             DECIMAL(24,8)   NOT NULL DEFAULT 0,
  `status`          ENUM('pending','completed','failed','cancelled') NOT NULL DEFAULT 'pending',
  `method`          VARCHAR(40)     DEFAULT NULL,       -- bitcoin, card, bank_wire, usdt …
  `tx_hash`         VARCHAR(128)    DEFAULT NULL,       -- blockchain tx hash
  `address`         VARCHAR(128)    DEFAULT NULL,       -- deposit/withdrawal address
  `notes`           TEXT            DEFAULT NULL,
  `processed_at`    DATETIME        DEFAULT NULL,
  `created_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_user`    (`user_id`),
  INDEX `idx_status`  (`status`),
  INDEX `idx_type`    (`type`),
  CONSTRAINT `fk_tx_user`   FOREIGN KEY (`user_id`)   REFERENCES `users`(`id`)   ON DELETE CASCADE,
  CONSTRAINT `fk_tx_wallet` FOREIGN KEY (`wallet_id`) REFERENCES `wallets`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ── 5. INSTRUMENTS ───────────────────────────────────────────
DROP TABLE IF EXISTS `instruments`;
CREATE TABLE `instruments` (
  `id`            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `symbol`        VARCHAR(20)   NOT NULL UNIQUE,        -- BTC/USD, EUR/USD …
  `base`          VARCHAR(10)   NOT NULL,
  `quote`         VARCHAR(10)   NOT NULL,
  `category`      ENUM('crypto','forex','commodity','index') NOT NULL,
  `max_leverage`  SMALLINT      NOT NULL DEFAULT 100,
  `maker_fee`     DECIMAL(6,4)  NOT NULL DEFAULT 0.0001,
  `taker_fee`     DECIMAL(6,4)  NOT NULL DEFAULT 0.0005,
  `overnight_fee` DECIMAL(6,4)  NOT NULL DEFAULT 0.0005,
  `min_trade_usd` DECIMAL(10,2) NOT NULL DEFAULT 10.00,
  `is_active`     TINYINT(1)    NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  INDEX `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed instruments
INSERT INTO `instruments` (`symbol`,`base`,`quote`,`category`,`max_leverage`,`maker_fee`,`taker_fee`,`overnight_fee`,`min_trade_usd`) VALUES
('BTC/USD','BTC','USD','crypto',100,0.0001,0.0005,0.0005,10),
('ETH/USD','ETH','USD','crypto',100,0.0001,0.0005,0.0005,10),
('LTC/USD','LTC','USD','crypto',50, 0.0001,0.0005,0.0005,10),
('XRP/USD','XRP','USD','crypto',50, 0.0001,0.0005,0.0005,10),
('SOL/USD','SOL','USD','crypto',50, 0.0001,0.0005,0.0005,10),
('ETH/BTC','ETH','BTC','crypto',50, 0.0001,0.0005,0.0005,10),
('EUR/USD','EUR','USD','forex', 1000,0.0000,0.0003,0.0001,10),
('GBP/USD','GBP','USD','forex', 1000,0.0000,0.0003,0.0001,10),
('USD/JPY','USD','JPY','forex', 1000,0.0000,0.0003,0.0001,10),
('AUD/USD','AUD','USD','forex', 500, 0.0000,0.0003,0.0001,10),
('GOLD',   'XAU','USD','commodity',150,0.0000,0.0005,0.0003,10),
('SILVER', 'XAG','USD','commodity',100,0.0000,0.0005,0.0003,10),
('CRUDE',  'OIL','USD','commodity',100,0.0000,0.0005,0.0003,10),
('SP500',  'SPX','USD','index',   100,0.0000,0.0005,0.0002,10),
('NASDAQ', 'NDX','USD','index',   100,0.0000,0.0005,0.0002,10),
('GER30',  'DAX','EUR','index',   100,0.0000,0.0005,0.0002,10);


-- ── 6. TRADES (open & closed positions) ─────────────────────
DROP TABLE IF EXISTS `trades`;
CREATE TABLE `trades` (
  `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `uuid`            CHAR(36)        NOT NULL UNIQUE,
  `user_id`         INT UNSIGNED    NOT NULL,
  `instrument_id`   INT UNSIGNED    NOT NULL,
  `direction`       ENUM('long','short') NOT NULL,
  `status`          ENUM('open','closed','liquidated') NOT NULL DEFAULT 'open',
  -- Size
  `quantity`        DECIMAL(24,8)   NOT NULL,           -- base units
  `leverage`        SMALLINT        NOT NULL DEFAULT 1,
  `margin_used`     DECIMAL(18,2)   NOT NULL,           -- USD
  -- Prices
  `open_price`      DECIMAL(18,8)   NOT NULL,
  `close_price`     DECIMAL(18,8)   DEFAULT NULL,
  `stop_loss`       DECIMAL(18,8)   DEFAULT NULL,
  `take_profit`     DECIMAL(18,8)   DEFAULT NULL,
  `liquidation_price` DECIMAL(18,8) DEFAULT NULL,
  -- P&L
  `realised_pnl`    DECIMAL(18,2)   DEFAULT NULL,       -- set on close
  `fee_open`        DECIMAL(18,8)   NOT NULL DEFAULT 0,
  `fee_close`       DECIMAL(18,8)   DEFAULT NULL,
  -- Timestamps
  `opened_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at`       DATETIME        DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_user`       (`user_id`),
  INDEX `idx_status`     (`status`),
  INDEX `idx_instrument` (`instrument_id`),
  CONSTRAINT `fk_trade_user`       FOREIGN KEY (`user_id`)       REFERENCES `users`(`id`)       ON DELETE CASCADE,
  CONSTRAINT `fk_trade_instrument` FOREIGN KEY (`instrument_id`) REFERENCES `instruments`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ── 7. PRICE HISTORY (OHLCV) ─────────────────────────────────
DROP TABLE IF EXISTS `price_history`;
CREATE TABLE `price_history` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `instrument_id` INT UNSIGNED    NOT NULL,
  `timeframe`     ENUM('1m','5m','15m','1h','4h','1d') NOT NULL,
  `open_time`     DATETIME        NOT NULL,
  `open`          DECIMAL(18,8)   NOT NULL,
  `high`          DECIMAL(18,8)   NOT NULL,
  `low`           DECIMAL(18,8)   NOT NULL,
  `close`         DECIMAL(18,8)   NOT NULL,
  `volume`        DECIMAL(24,4)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_candle` (`instrument_id`,`timeframe`,`open_time`),
  CONSTRAINT `fk_ph_instrument` FOREIGN KEY (`instrument_id`) REFERENCES `instruments`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ── 8. OTP / EMAIL CODES ─────────────────────────────────────
DROP TABLE IF EXISTS `otp_codes`;
CREATE TABLE `otp_codes` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED  NOT NULL,
  `code`        VARCHAR(10)   NOT NULL,
  `purpose`     ENUM('email_verify','password_reset','two_fa','withdrawal') NOT NULL,
  `expires_at`  DATETIME      NOT NULL,
  `used`        TINYINT(1)    NOT NULL DEFAULT 0,
  `created_at`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_user_purpose` (`user_id`,`purpose`),
  CONSTRAINT `fk_otp_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ── 9. AUDIT LOG ─────────────────────────────────────────────
DROP TABLE IF EXISTS `audit_log`;
CREATE TABLE `audit_log` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED    DEFAULT NULL,
  `action`      VARCHAR(80)     NOT NULL,              -- register, login, trade_open, deposit …
  `ip_address`  VARCHAR(45)     DEFAULT NULL,
  `details`     JSON            DEFAULT NULL,
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_user`   (`user_id`),
  INDEX `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
--  Schema complete. Run seed.sql next for demo data.
-- ============================================================