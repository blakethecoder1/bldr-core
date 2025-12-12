-- bldr_core server script
--
-- This file implements the server‑side logic for the generic BLDR core.
-- It provides functions to add experience points, add money and
-- retrieve a player's level.  Modules such as farming or crafting
-- should use these exports rather than implementing their own XP
-- systems.  Player XP and level are now stored persistently in MySQL.

local QBCore = exports['qb-core']:GetCoreObject()

-- Internal cache per player for performance. Data is persisted to database.
local PlayerDataCache = {}

-- Get player license identifier for database operations
local function getPlayerLicense(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return Player.PlayerData.license
end

-- Load player data from database or create new entry if needed
local function loadPlayerData(src)
    local license = getPlayerLicense(src)
    if not license then return { xp = 0, level = 0 } end
    
    -- Check cache first
    if PlayerDataCache[license] then
        return PlayerDataCache[license]
    end
    
    -- Load from database
    local result = MySQL.Sync.fetchAll('SELECT xp, level FROM bldr_player_data WHERE license = ?', { license })
    
    local playerData
    if result and #result > 0 then
        playerData = {
            xp = result[1].xp or 0,
            level = result[1].level or 0
        }
    else
        -- Create new player entry
        playerData = { xp = 0, level = 0 }
        MySQL.Async.execute('INSERT INTO bldr_player_data (license, xp, level) VALUES (?, ?, ?)', {
            license, playerData.xp, playerData.level
        })
    end
    
    -- Cache the data
    PlayerDataCache[license] = playerData
    return playerData
end

-- Save player data to database
local function savePlayerData(src, xp, level)
    local license = getPlayerLicense(src)
    if not license then return end
    
    -- Update cache
    PlayerDataCache[license] = { xp = xp, level = level }
    
    -- Save to database asynchronously
    MySQL.Async.execute('UPDATE bldr_player_data SET xp = ?, level = ? WHERE license = ?', {
        xp, level, license
    })
end

-- Determine the player's level and reward multiplier based on XP.
-- Iterates through Config.Levels from highest to lowest to find the
-- highest level whose XP requirement is met.
local function getLevelForXp(xp)
    local level = 0
    local multiplier = 1.0
    for i = #Config.Levels, 1, -1 do
        local lvlCfg = Config.Levels[i]
        if xp >= lvlCfg.xp then
            level = lvlCfg.level
            multiplier = lvlCfg.multiplier
            break
        end
    end
    return level, multiplier
end

-- Exported function: AddXP
-- Adds a specified amount of experience points to the given player.  If
-- the new XP total crosses a level threshold the player's level will
-- update automatically.  Returns the player's new total XP and level.
exports('AddXP', function(src, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    
    local pdata = loadPlayerData(src)
    local oldLevel = pdata.level
    pdata.xp = pdata.xp + amount
    local newLevel, multiplier = getLevelForXp(pdata.xp)
    pdata.level = newLevel
    
    -- Save to database
    savePlayerData(src, pdata.xp, pdata.level)
    
    -- Update total_xp in stats if statistics system is enabled
    if Config.Statistics and Config.Statistics.enabled then
        exports['bldr-core']:UpdateStat(src, 'total_xp', amount)
    end
    
    -- Notify player of level up
    if newLevel > oldLevel then
        local levelConfig = Config.Levels[newLevel + 1] -- +1 because array is 1-indexed but levels start at 0
        if levelConfig then
            TriggerClientEvent('QBCore:Notify', src, 
                ('Level Up! You are now %s (Level %d)'):format(levelConfig.title, newLevel), 
                'success', 5000)
        end
    end
    
    if Config.Debug then
        print(('[bldr_core] Added %d XP to %s (total XP: %d, level: %d)')
            :format(amount, src, pdata.xp, pdata.level))
    end
    return pdata.xp, pdata.level
end)

-- Exported function: AddMoney
-- Convenience wrapper around QBCore's AddMoney with level-based bonuses.
-- Adds the given amount of money to a player's account with optional bonuses
-- based on player level and item quality.
exports('AddMoney', function(src, amount, account, quality)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    amount = tonumber(amount) or 0
    quality = tonumber(quality) or 100
    if amount <= 0 then return false end
    
    local finalAmount = amount
    local bonusText = ""
    
    -- Apply level bonus if enabled
    if Config.Money.levelBonusEnabled then
        local pdata = loadPlayerData(src)
        local level, multiplier = getLevelForXp(pdata.xp)
        local levelConfig = Config.Levels[level + 1]
        if levelConfig and levelConfig.moneyBonus > 0 then
            finalAmount = finalAmount + levelConfig.moneyBonus
            bonusText = bonusText .. ('Level %d Bonus: $%d'):format(level, levelConfig.moneyBonus)
        end
    end
    
    -- Apply quality bonus if enabled
    if Config.Money.qualityBonusEnabled and quality then
        local qualityMultiplier = quality / 100
        local qualityBonus = math.floor(amount * (qualityMultiplier - 1))
        if qualityBonus > 0 then
            finalAmount = finalAmount + qualityBonus
            if bonusText ~= "" then bonusText = bonusText .. " | " end
            bonusText = bonusText .. ('Quality Bonus: $%d'):format(qualityBonus)
        end
    end
    
    -- Determine account to deposit into
    account = account or Config.Money.type or 'cash'
    local usedMarked = false
    
    if Config.Money.useMarkedBills and math.random() < (Config.Money.markedBillsChance or 0.0) then
        usedMarked = true
        Player.Functions.AddItem(Config.Money.markedBillsItem or 'markedbills', 1, false, { worth = finalAmount })
    else
        Player.Functions.AddMoney(account, finalAmount, 'bldr-core-payment')
    end
    
    -- Show bonus notification if applicable
    if bonusText ~= "" and Config.Notifications.moneyBonus then
        TriggerClientEvent('QBCore:Notify', src, bonusText, 'success', 3000)
    end
    
    if Config.Debug then
        print(('[bldr_core] Added $%d to %s (%s) [original: $%d] [marked: %s] [bonuses: %s]')
            :format(finalAmount, src, account, amount, tostring(usedMarked), bonusText))
    end
    
    return true, finalAmount
end)

-- Exported function: GetLevel
-- Returns the current level of the given player.  If the player has
-- not yet earned any XP the function returns 0.  Does not alter state.
exports('GetLevel', function(src)
    local pdata = loadPlayerData(src)
    return pdata.level or 0
end)

-- Exported function: GetXP
-- Returns the current XP of the given player.
exports('GetXP', function(src)
    local pdata = loadPlayerData(src)
    return pdata.xp or 0
end)

-- Exported function: GetPlayerStats
-- Returns comprehensive player statistics including XP, level, title, and multiplier
exports('GetPlayerStats', function(src)
    local pdata = loadPlayerData(src)
    local level, multiplier = getLevelForXp(pdata.xp)
    local levelConfig = Config.Levels[level + 1] -- +1 because array is 1-indexed but levels start at 0
    
    return {
        xp = pdata.xp,
        level = level,
        title = levelConfig and levelConfig.title or 'Novice',
        multiplier = multiplier,
        nextLevelXP = level < #Config.Levels - 1 and Config.Levels[level + 2].xp or nil
    }
end)

-- Cleanup player data from cache when they disconnect
AddEventHandler('playerDropped', function(reason)
    local license = getPlayerLicense(source)
    if license and PlayerDataCache[license] then
        PlayerDataCache[license] = nil
    end
end)

-- Preload player data when they join
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    loadPlayerData(src) -- This will cache their data
end)

-- Performance: Auto-save system to periodically save cached data
if Config.Performance and Config.Performance.saveInterval > 0 then
    CreateThread(function()
        while true do
            Wait(Config.Performance.saveInterval)
            
            local saveCount = 0
            local batchSize = Config.Performance.batchSaveSize or 10
            
            for license, data in pairs(PlayerDataCache) do
                if saveCount >= batchSize then break end
                
                -- Save to database
                MySQL.Async.execute('UPDATE bldr_player_data SET xp = ?, level = ? WHERE license = ?', {
                    data.xp, data.level, license
                })
                saveCount = saveCount + 1
            end
            
            if Config.Debug and saveCount > 0 then
                print(('[bldr_core] Auto-saved %d player records'):format(saveCount))
            end
        end
    end)
end

-- Performance: Cache cleanup system
if Config.Performance and Config.Performance.cacheTimeout > 0 then
    CreateThread(function()
        while true do
            Wait(Config.Performance.cacheTimeout)
            
            local onlinePlayers = {}
            for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
                local license = getPlayerLicense(playerId)
                if license then
                    onlinePlayers[license] = true
                end
            end
            
            -- Remove cached data for offline players
            local cleaned = 0
            for license, _ in pairs(PlayerDataCache) do
                if not onlinePlayers[license] then
                    PlayerDataCache[license] = nil
                    cleaned = cleaned + 1
                end
            end
            
            if Config.Debug and cleaned > 0 then
                print(('[bldr_core] Cleaned %d cached records from offline players'):format(cleaned))
            end
        end
    end)
end

-- Error handling: Wrapper for safe database operations
local function safeDBOperation(operation, params, callback)
    local success, result = pcall(function()
        if callback then
            MySQL.Async.execute(operation, params, callback)
        else
            return MySQL.Sync.fetchAll(operation, params)
        end
    end)
    
    if not success then
        print(('[bldr_core] Database error: %s'):format(result))
        return nil
    end
    
    return result
end

-- Player command to check their own farming level
RegisterCommand('farmlevel', function(source, args, rawCommand)
    if source == 0 then
        print("This command can only be used by players")
        return
    end
    
    -- Debug: Check if player exists
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        print(('[DEBUG] Player %d not found in QBCore'):format(source))
        return
    end
    
    local stats = exports['bldr_core']:GetPlayerStats(source)
    if not stats then
        TriggerClientEvent('QBCore:Notify', source, 'Error retrieving your farming stats', 'error')
        print(('[DEBUG] Failed to get stats for player %d'):format(source))
        return
    end
    
    -- Debug: Print stats to console
    print(('[DEBUG] Player %d stats: XP=%d, Level=%d, Title=%s'):format(source, stats.xp, stats.level, stats.title))
    
    local xpToNext = "N/A"
    if stats.nextLevelXP and stats.nextLevelXP > stats.xp then
        xpToNext = tostring(stats.nextLevelXP - stats.xp)
    end
    
    local message = string.format('🌾 Farming Level: %d (%s)\n📊 XP: %d\n⬆️ XP to Next: %s', 
        stats.level, stats.title, stats.xp, xpToNext)
    
    TriggerClientEvent('QBCore:Notify', source, message, 'primary', 8000)
    
    -- Also send to chat as backup
    TriggerClientEvent('chat:addMessage', source, {
        args = { '^2[Farming]', message:gsub('\n', ' | ') }
    })
end, false)

-- Admin command to check another player's farming level
RegisterCommand('checkfarmlevel', function(source, args, rawCommand)
    -- Check admin permissions
    if not exports['bldr_core']:IsBLDRAdmin(source) then
        if source == 0 then
            print("Admin permission check failed")
        else
            TriggerClientEvent('QBCore:Notify', source, 'You do not have permission to use this command', 'error')
        end
        return
    end
    
    if not args[1] then
        local usage = 'Usage: /checkfarmlevel [player_id]'
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('QBCore:Notify', source, usage, 'error')
        end
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        local error = 'Invalid player ID'
        if source == 0 then
            print(error)
        else
            TriggerClientEvent('QBCore:Notify', source, error, 'error')
        end
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        local error = 'Player not found'
        if source == 0 then
            print(error)
        else
            TriggerClientEvent('QBCore:Notify', source, error, 'error')
        end
        return
    end
    
    local stats = exports['bldr_core']:GetPlayerStats(targetId)
    if not stats then
        local error = 'Error retrieving player farming stats'
        if source == 0 then
            print(error)
        else
            TriggerClientEvent('QBCore:Notify', source, error, 'error')
        end
        return
    end
    
    local xpToNext = "N/A"
    if stats.nextLevelXP and stats.nextLevelXP > stats.xp then
        xpToNext = tostring(stats.nextLevelXP - stats.xp)
    end
    
    local playerName = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname
    local message = string.format('🌾 %s (%d) Farming Stats:\n📊 Level: %d (%s)\n📈 XP: %d\n⬆️ XP to Next: %s', 
        playerName, targetId, stats.level, stats.title, stats.xp, xpToNext)
    
    if source == 0 then
        print(message)
    else
        TriggerClientEvent('QBCore:Notify', source, message, 'primary', 10000)
        -- Also send to chat as backup
        TriggerClientEvent('chat:addMessage', source, {
            args = { '^3[Admin]', message:gsub('\n', ' | ') }
        })
    end
end, false)

-- Debug command to add XP (admin only)
RegisterCommand('addxp', function(source, args, rawCommand)
    if not exports['bldr_core']:IsBLDRAdmin(source) then
        if source ~= 0 then
            TriggerClientEvent('QBCore:Notify', source, 'You do not have permission to use this command', 'error')
        end
        return
    end
    
    local targetId = source
    local amount = 100
    
    if args[1] then
        targetId = tonumber(args[1]) or source
    end
    if args[2] then
        amount = tonumber(args[2]) or 100
    end
    
    if targetId == 0 and source == 0 then
        print("Cannot add XP to console")
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        local error = 'Player not found'
        if source == 0 then
            print(error)
        else
            TriggerClientEvent('QBCore:Notify', source, error, 'error')
        end
        return
    end
    
    local oldXP, oldLevel = exports['bldr_core']:AddXP(targetId, amount)
    local success = string.format('Added %d XP to player %d', amount, targetId)
    
    if source == 0 then
        print(success)
    else
        TriggerClientEvent('QBCore:Notify', source, success, 'success')
    end
end, false)

-- =================================================================
-- PLAYER STATISTICS SYSTEM
-- =================================================================

local PlayerStats = {}

-- Initialize or load player statistics
local function loadPlayerStats(src)
    local license = getPlayerLicense(src)
    if not license then return nil end
    
    -- Check cache
    if PlayerStats[license] then
        return PlayerStats[license]
    end
    
    -- Load from database
    local result = MySQL.Sync.fetchAll('SELECT * FROM bldr_player_stats WHERE license = ?', { license })
    
    local stats
    if result and #result > 0 then
        stats = json.decode(result[1].stats) or {}
        if Config.Debug then
            print(('[bldr_core] Loaded stats for %s: %s'):format(license, json.encode(stats)))
        end
    else
        -- Create default stats
        stats = {
            plants_planted = 0,
            plants_harvested = 0,
            total_farming_xp = 0,
            items_crafted = 0,
            recipes_unlocked = 0,
            total_crafting_xp = 0,
            money_earned = 0,
            money_spent = 0,
            total_xp = 0,
            sessions_played = 1,
            time_played = 0,
            session_start = os.time()
        }
        MySQL.Async.execute('INSERT INTO bldr_player_stats (license, stats) VALUES (?, ?)', {
            license, json.encode(stats)
        }, function(affectedRows)
            if Config.Debug then
                print(('[bldr_core] Created new stats for %s'):format(license))
            end
        end)
    end
    
    stats.session_start = os.time()
    PlayerStats[license] = stats
    return stats
end

-- Save player statistics
local function savePlayerStats(src)
    local license = getPlayerLicense(src)
    if not license or not PlayerStats[license] then return end
    
    -- Update time played
    if PlayerStats[license].session_start then
        local sessionTime = os.time() - PlayerStats[license].session_start
        PlayerStats[license].time_played = (PlayerStats[license].time_played or 0) + sessionTime
        PlayerStats[license].session_start = os.time()
    end
    
    MySQL.Async.execute('UPDATE bldr_player_stats SET stats = ? WHERE license = ?', {
        json.encode(PlayerStats[license]), license
    })
end

-- Update a specific stat
exports('UpdateStat', function(src, statName, value)
    if not Config.Statistics or not Config.Statistics.enabled then return end
    
    local stats = loadPlayerStats(src)
    if not stats then 
        if Config.Debug then
            print(('[bldr_core] ERROR: Failed to load stats for player %d when updating %s'):format(src, statName))
        end
        return 
    end
    
    local license = getPlayerLicense(src)
    if not license then return end
    
    local oldValue = stats[statName] or 0
    stats[statName] = (stats[statName] or 0) + value
    PlayerStats[license] = stats
    
    if Config.Debug then
        print(('[bldr_core] UpdateStat: %s for player %d | %s: %d -> %d (+%d)'):format(
            statName, src, statName, oldValue, stats[statName], value))
    end
    
    -- Save immediately to ensure it's persisted
    savePlayerStats(src)
end)

-- Get player statistics
exports('GetPlayerStatistics', function(src)
    return loadPlayerStats(src)
end)

-- Save stats periodically
if Config.Statistics and Config.Statistics.enabled then
    CreateThread(function()
        while true do
            Wait(Config.Statistics.saveInterval or 600000)
            
            for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
                savePlayerStats(playerId)
            end
            
            if Config.Debug then
                print('[bldr_core] Auto-saved player statistics')
            end
        end
    end)
end

-- Save stats on player disconnect
AddEventHandler('playerDropped', function(reason)
    savePlayerStats(source)
    local license = getPlayerLicense(source)
    if license and PlayerStats[license] then
        PlayerStats[license] = nil
    end
end)

-- Load stats on player join
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    loadPlayerStats(source)
end)

-- =================================================================
-- LEADERBOARDS SYSTEM
-- =================================================================

local Leaderboards = {}

-- Update leaderboards from database
local function updateLeaderboards()
    if not Config.Leaderboards or not Config.Leaderboards.enabled then return end
    
    for _, category in ipairs(Config.Leaderboards.categories) do
        local statKey = category.id
        
        -- Query to get leaderboard data with player names
        -- Fixed collation mismatch by using COLLATE
        local results = MySQL.Sync.fetchAll([[
            SELECT 
                ps.license,
                ps.stats,
                JSON_EXTRACT(ps.stats, '$.]] .. statKey .. [[') as stat_value,
                p.charinfo
            FROM bldr_player_stats ps
            LEFT JOIN players p ON ps.license COLLATE utf8mb4_unicode_ci = p.license COLLATE utf8mb4_unicode_ci
            WHERE JSON_EXTRACT(ps.stats, '$.]] .. statKey .. [[') IS NOT NULL
                AND CAST(JSON_EXTRACT(ps.stats, '$.]] .. statKey .. [[') AS UNSIGNED) > 0
            ORDER BY CAST(JSON_EXTRACT(ps.stats, '$.]] .. statKey .. [[') AS UNSIGNED) DESC
            LIMIT ?
        ]], { Config.Leaderboards.displayCount or 10 })
        
        if results then
            Leaderboards[statKey] = {}
            for i, row in ipairs(results) do
                local stats = json.decode(row.stats) or {}
                local playerName = 'Unknown'
                
                -- Try to get name from charinfo
                if row.charinfo then
                    local charinfo = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
                    if charinfo and charinfo.firstname and charinfo.lastname then
                        playerName = charinfo.firstname .. ' ' .. charinfo.lastname
                    end
                end
                
                -- Fallback: check if player is currently online
                if playerName == 'Unknown' then
                    local onlinePlayers = QBCore.Functions.GetPlayers()
                    for _, playerId in pairs(onlinePlayers) do
                        local Player = QBCore.Functions.GetPlayer(playerId)
                        if Player and Player.PlayerData.license == row.license then
                            playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
                            break
                        end
                    end
                end
                
                table.insert(Leaderboards[statKey], {
                    rank = i,
                    name = playerName,
                    value = stats[statKey] or 0,
                    license = row.license
                })
            end
            
            if Config.Debug then
                print(('[bldr_core] Updated %s leaderboard with %d entries'):format(statKey, #Leaderboards[statKey]))
            end
        end
    end
    
    if Config.Debug then
        print('[bldr_core] Updated all leaderboards')
    end
end

-- Get leaderboard data
exports('GetLeaderboard', function(category)
    return Leaderboards[category] or {}
end)

-- Get all leaderboards
exports('GetAllLeaderboards', function()
    return Leaderboards
end)

-- Update leaderboards periodically
if Config.Leaderboards and Config.Leaderboards.enabled then
    CreateThread(function()
        Wait(10000) -- Wait for database to be ready
        
        -- Ensure bldr_player_stats table exists
        MySQL.Async.execute([[
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
        ]], {}, function()
            print('[bldr_core] Ensured bldr_player_stats table exists')
            updateLeaderboards() -- Initial update
        end)
        
        while true do
            Wait(Config.Leaderboards.updateInterval or 300000)
            updateLeaderboards()
        end
    end)
end

-- Command to view leaderboards
RegisterCommand('leaderboard', function(source, args, rawCommand)
    if source == 0 then
        print("This command can only be used by players")
        return
    end
    
    local category = args[1] or 'total_xp'
    
    -- Validate category
    local validCategories = {}
    for _, cat in ipairs(Config.Leaderboards.categories) do
        validCategories[cat.id] = true
    end
    
    if not validCategories[category] then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid category. Use: total_xp, plants_harvested, items_crafted, or money_earned', 'error')
        return
    end
    
    local leaderboard = Leaderboards[category] or {}
    
    if not leaderboard or #leaderboard == 0 then
        -- Try updating leaderboards first
        updateLeaderboards()
        Wait(1000)
        leaderboard = Leaderboards[category] or {}
        
        if #leaderboard == 0 then
            TriggerClientEvent('QBCore:Notify', source, 'No leaderboard data available yet. Players need to earn stats first!', 'error')
            
            if Config.Debug then
                print('[bldr_core] Leaderboard empty for category: ' .. category)
                print('[bldr_core] Available categories:', json.encode(Leaderboards))
            end
            return
        end
    end
    
    TriggerClientEvent('bldr_core:showLeaderboard', source, category, leaderboard)
end, false)

-- Command to view personal statistics
RegisterCommand('mystats', function(source, args, rawCommand)
    if source == 0 then
        print("This command can only be used by players")
        return
    end
    
    local stats = loadPlayerStats(source)
    if not stats then
        TriggerClientEvent('QBCore:Notify', source, 'No statistics available', 'error')
        return
    end
    
    TriggerClientEvent('bldr_core:showStats', source, stats)
end, false)

-- Admin command to refresh leaderboards manually
RegisterCommand('refreshleaderboard', function(source, args, rawCommand)
    if source ~= 0 then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        
        local isAdmin = QBCore.Functions.HasPermission(source, 'admin') or 
                       QBCore.Functions.HasPermission(source, 'god')
        
        if not isAdmin then
            TriggerClientEvent('QBCore:Notify', source, 'You do not have permission', 'error')
            return
        end
    end
    
    updateLeaderboards()
    
    if source == 0 then
        print('[bldr_core] Leaderboards refreshed')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Leaderboards refreshed', 'success')
    end
end, false)

-- =================================================================
-- QUALITY SYSTEM
-- =================================================================

-- Calculate item quality based on multiple factors
exports('CalculateQuality', function(src, baseQuality, factors)
    if not Config.Quality or not Config.Quality.enabled then
        return baseQuality or 100
    end
    
    local quality = baseQuality or 50
    factors = factors or {}
    
    -- Player level factor
    if Config.Quality.factors.playerLevel > 0 then
        local pdata = loadPlayerData(src)
        local level = pdata.level or 0
        local levelBonus = level * 2 -- +2 quality per level
        quality = quality + (levelBonus * Config.Quality.factors.playerLevel)
    end
    
    -- Equipment factor
    if factors.equipment and Config.Quality.factors.equipment > 0 then
        quality = quality + (factors.equipment * Config.Quality.factors.equipment)
    end
    
    -- Minigame factor
    if factors.minigame and Config.Quality.factors.minigame > 0 then
        quality = quality + (factors.minigame * Config.Quality.factors.minigame)
    end
    
    -- Random variance
    if Config.Quality.factors.random > 0 then
        local variance = math.random(-10, 10)
        quality = quality + (variance * Config.Quality.factors.random)
    end
    
    -- Clamp between 0 and 100
    quality = math.max(0, math.min(100, quality))
    
    return math.floor(quality)
end)

-- Get quality tier information
exports('GetQualityTier', function(quality)
    if not Config.Quality or not Config.Quality.enabled then
        return { label = 'Common', multiplier = 1.0, color = '#FFFFFF' }
    end
    
    for tier, data in pairs(Config.Quality.tiers) do
        if quality >= data.min and quality <= data.max then
            return {
                tier = tier,
                label = data.label,
                multiplier = data.multiplier,
                color = data.color
            }
        end
    end
    
    return { tier = 'common', label = 'Common', multiplier = 1.0, color = '#FFFFFF' }
end)