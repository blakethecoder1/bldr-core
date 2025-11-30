-- Configuration for bldr_core
-- This file defines experience levels and money payout settings for the
-- generic BLDR core.  Other modules (farming, crafting, etc.) can use
-- these values to determine player progression and reward scaling.

Config = {}

-- Progression levels.  Players accumulate XP via modules that call
-- exports['bldr_core']:AddXP(src, amount).  When a player's total XP
-- meets or exceeds the threshold defined in an entry the player is
-- considered to have reached that level.  The multiplier can be used
-- by modules to scale rewards or success chances.
Config.Levels = {
    { level = 0, xp = 0,     multiplier = 1.00, title = 'Novice',      moneyBonus = 0 },
    { level = 1, xp = 200,   multiplier = 1.05, title = 'Apprentice',  moneyBonus = 50 },
    { level = 2, xp = 600,   multiplier = 1.12, title = 'Journeyman',  moneyBonus = 100 },
    { level = 3, xp = 1200,  multiplier = 1.20, title = 'Artisan',     moneyBonus = 200 },
    { level = 4, xp = 2400,  multiplier = 1.35, title = 'Expert',      moneyBonus = 400 },
    { level = 5, xp = 4800,  multiplier = 1.50, title = 'Master',      moneyBonus = 800 },
    { level = 6, xp = 9600,  multiplier = 1.75, title = 'Grandmaster', moneyBonus = 1600 },
    { level = 7, xp = 19200, multiplier = 2.00, title = 'Legendary',   moneyBonus = 3200 }
}

-- XP multiplier settings for different activities
Config.XPMultipliers = {
    base = 1.0,           -- Base XP rate
    farming = 1.0,        -- Farming activity multiplier
    crafting = 1.0,       -- Crafting activity multiplier
    processing = 1.2,     -- Processing multiplier (slightly higher)
    weekend = 1.5,        -- Weekend bonus multiplier
    vip = 2.0            -- VIP player multiplier (if implemented)
}

-- Money payout settings.  The AddMoney export uses these values to
-- determine the default account and whether to award marked bills
-- instead of direct cash deposits.  You can disable marked bills by
-- setting useMarkedBills to false.
Config.Money = {
    type = 'cash',                    -- 'cash', 'bank', 'crypto' or 'black_money'
    useMarkedBills = false,           -- disable marked bills by default for core
    markedBillsChance = 0.0,          -- probability of marked bills (unused when disabled)
    markedBillsItem = 'markedbills',  -- item name for marked bills
    levelBonusEnabled = true,         -- enable level-based money bonuses
    qualityBonusEnabled = true        -- enable quality-based bonuses
}

-- Notification settings
Config.Notifications = {
    levelUp = true,           -- Show level up notifications
    xpGain = false,          -- Show XP gain notifications (can be spammy)
    moneyBonus = true,       -- Show money bonus notifications
    blueprintUnlock = true   -- Show blueprint unlock notifications
}

-- Performance settings
Config.Performance = {
    saveInterval = 300000,    -- Auto-save player data every 5 minutes (ms)
    cacheTimeout = 1800000,   -- Clear unused cache entries after 30 minutes
    batchSaveSize = 10        -- Max players to save in one batch operation
}

-- Optional debug flag.  When true the core will print verbose
-- information to the server console to help diagnose issues.
Config.Debug = false