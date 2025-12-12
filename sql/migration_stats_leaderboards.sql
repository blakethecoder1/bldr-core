-- Database migration for BLDR Core Statistics and Leaderboards
-- Run this file to add player statistics and leaderboard support

-- Player statistics table
CREATE TABLE IF NOT EXISTS `bldr_player_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  `stats` longtext COLLATE utf8mb4_unicode_ci DEFAULT '{}',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `license` (`license`),
  KEY `idx_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add any missing columns to existing bldr_player_data table (if it exists)
-- This is safe to run even if columns already exist
ALTER TABLE `bldr_player_data` 
  ADD COLUMN IF NOT EXISTS `session_count` int(11) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `last_login` timestamp NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `total_playtime` bigint(20) DEFAULT 0;

-- Create leaderboard view for quick access
CREATE OR REPLACE VIEW `v_leaderboard_xp` AS
SELECT 
    pd.license,
    pd.xp,
    pd.level,
    ps.stats
FROM bldr_player_data pd
LEFT JOIN bldr_player_stats ps ON pd.license COLLATE utf8mb4_unicode_ci = ps.license COLLATE utf8mb4_unicode_ci
ORDER BY pd.xp DESC
LIMIT 100;

-- Create leaderboard view for farming
CREATE OR REPLACE VIEW `v_leaderboard_farming` AS
SELECT 
    ps.license,
    JSON_EXTRACT(ps.stats, '$.plants_harvested') as plants_harvested,
    JSON_EXTRACT(ps.stats, '$.total_farming_xp') as farming_xp
FROM bldr_player_stats ps
WHERE JSON_EXTRACT(ps.stats, '$.plants_harvested') IS NOT NULL
ORDER BY CAST(JSON_EXTRACT(ps.stats, '$.plants_harvested') AS UNSIGNED) DESC
LIMIT 100;

-- Create leaderboard view for crafting
CREATE OR REPLACE VIEW `v_leaderboard_crafting` AS
SELECT 
    ps.license,
    JSON_EXTRACT(ps.stats, '$.items_crafted') as items_crafted,
    JSON_EXTRACT(ps.stats, '$.total_crafting_xp') as crafting_xp
FROM bldr_player_stats ps
WHERE JSON_EXTRACT(ps.stats, '$.items_crafted') IS NOT NULL
ORDER BY CAST(JSON_EXTRACT(ps.stats, '$.items_crafted') AS UNSIGNED) DESC
LIMIT 100;

-- Create leaderboard view for money
CREATE OR REPLACE VIEW `v_leaderboard_money` AS
SELECT 
    ps.license,
    JSON_EXTRACT(ps.stats, '$.money_earned') as money_earned
FROM bldr_player_stats ps
WHERE JSON_EXTRACT(ps.stats, '$.money_earned') IS NOT NULL
ORDER BY CAST(JSON_EXTRACT(ps.stats, '$.money_earned') AS UNSIGNED) DESC
LIMIT 100;
