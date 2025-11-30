-- Database schema for bldr_core player progression system
-- This creates the table to store player XP and levels persistently

CREATE TABLE IF NOT EXISTS `bldr_player_data` (
  `license` varchar(50) PRIMARY KEY NOT NULL,
  `xp` int(11) NOT NULL DEFAULT 0,
  `level` int(11) NOT NULL DEFAULT 0,
  `total_money_earned` int(11) NOT NULL DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_level` (`level`),
  INDEX `idx_xp` (`xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;