-- fxmanifest.lua for bldr_core
-- This resource provides a generic XP and money payout system for BLDR scripts.
-- It defines server exports for adding experience points, awarding money and
-- retrieving a player's level.  It is intended to be used by modules such as
-- farming and crafting.  No drug‑specific logic is included.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bldr_core'
description 'Shared core for BLDR modules (XP and payouts)'
author 'blakethepet'
version '1.1.0'

dependencies {
    'qb-core',
    'oxmysql'
}

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logger.lua',
    'server/admin.lua',
    'server/main.lua'
}

client_scripts {
    'client/stats.lua'
}

files {
    'sql/bldr_core.sql',
    'sql/migration_stats_leaderboards.sql'
}

-- No client scripts are included; this resource is server‑only.