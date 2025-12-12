-- Client-side Statistics and Leaderboards UI
-- Displays player statistics and server leaderboards

local QBCore = exports['qb-core']:GetCoreObject()

-- Show player statistics
RegisterNetEvent('bldr_core:showStats', function(stats)
    if not stats then
        QBCore.Functions.Notify('No statistics available', 'error')
        return
    end
    
    -- Try using ox_lib menu if available
    if exports['ox_lib'] and exports['ox_lib'].registerContext then
        local statsMenu = {
            id = 'player_stats',
            title = '📊 Your Statistics',
            options = {
                {
                    title = '🌾 Farming Stats',
                    description = string.format('Planted: %d | Harvested: %d | XP: %d', 
                        stats.plants_planted or 0,
                        stats.plants_harvested or 0,
                        stats.total_farming_xp or 0),
                    icon = 'seedling'
                },
                {
                    title = '🔨 Crafting Stats',
                    description = string.format('Items Crafted: %d | Recipes: %d | XP: %d', 
                        stats.items_crafted or 0,
                        stats.recipes_unlocked or 0,
                        stats.total_crafting_xp or 0),
                    icon = 'hammer'
                },
                {
                    title = '💰 Economic Stats',
                    description = string.format('Earned: $%d | Spent: $%d | Net: $%d', 
                        stats.money_earned or 0,
                        stats.money_spent or 0,
                        (stats.money_earned or 0) - (stats.money_spent or 0)),
                    icon = 'dollar-sign'
                },
                {
                    title = '⏱️ Session Stats',
                    description = string.format('Sessions: %d | Playtime: %s hours', 
                        stats.sessions_played or 0,
                        string.format("%.1f", (stats.time_played or 0) / 3600)),
                    icon = 'clock'
                },
                {
                    title = '📈 Total XP',
                    description = string.format('Total Experience: %d', stats.total_xp or 0),
                    icon = 'chart-line'
                }
            }
        }
        
        exports['ox_lib']:registerContext(statsMenu)
        exports['ox_lib']:showContext('player_stats')
    else
        -- Fallback: Show in chat
        local message = string.format([[
^2[Your Statistics]^0
🌾 Farming: Planted %d | Harvested %d | XP %d
🔨 Crafting: Items %d | Recipes %d | XP %d
💰 Money: Earned $%d | Spent $%d
⏱️ Sessions: %d | Playtime: %.1f hours
📈 Total XP: %d
        ]], 
            stats.plants_planted or 0,
            stats.plants_harvested or 0,
            stats.total_farming_xp or 0,
            stats.items_crafted or 0,
            stats.recipes_unlocked or 0,
            stats.total_crafting_xp or 0,
            stats.money_earned or 0,
            stats.money_spent or 0,
            stats.sessions_played or 0,
            (stats.time_played or 0) / 3600,
            stats.total_xp or 0)
        
        TriggerEvent('chat:addMessage', {
            color = { 255, 255, 255 },
            multiline = true,
            args = { message }
        })
    end
end)

-- Show leaderboards
RegisterNetEvent('bldr_core:showLeaderboard', function(category, leaderboard)
    if not leaderboard or #leaderboard == 0 then
        QBCore.Functions.Notify('No leaderboard data available', 'error')
        return
    end
    
    -- Get category label
    local categoryLabels = {
        total_xp = '🏆 Top Players',
        plants_harvested = '🌾 Top Farmers',
        items_crafted = '🔨 Top Crafters',
        money_earned = '💰 Top Earners'
    }
    
    local title = categoryLabels[category] or 'Leaderboard'
    
    -- Try using ox_lib menu if available
    if exports['ox_lib'] and exports['ox_lib'].registerContext then
        local options = {}
        
        for _, entry in ipairs(leaderboard) do
            local rankEmoji = entry.rank == 1 and '🥇' or entry.rank == 2 and '🥈' or entry.rank == 3 and '🥉' or ('  ' .. entry.rank .. '.')
            
            table.insert(options, {
                title = string.format('%s %s', rankEmoji, entry.name),
                description = string.format('Score: %s', formatNumber(entry.value)),
                disabled = true
            })
        end
        
        local leaderboardMenu = {
            id = 'leaderboard_' .. category,
            title = title,
            options = options
        }
        
        exports['ox_lib']:registerContext(leaderboardMenu)
        exports['ox_lib']:showContext('leaderboard_' .. category)
    else
        -- Fallback: Show in chat
        local message = '^2[' .. title .. ']^0\n'
        
        for _, entry in ipairs(leaderboard) do
            local rankEmoji = entry.rank == 1 and '🥇' or entry.rank == 2 and '🥈' or entry.rank == 3 and '🥉' or tostring(entry.rank) .. '.'
            message = message .. string.format('%s %s: %s\n', rankEmoji, entry.name, formatNumber(entry.value))
        end
        
        TriggerEvent('chat:addMessage', {
            color = { 255, 255, 255 },
            multiline = true,
            args = { message }
        })
    end
end)

-- Helper function to format numbers with commas
function formatNumber(num)
    if not num then return '0' end
    local formatted = tostring(num)
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Command to open stats menu
RegisterCommand('stats', function()
    ExecuteCommand('mystats')
end, false)

-- Command to open leaderboard menu
RegisterCommand('leaders', function(source, args)
    local category = args[1] or 'total_xp'
    ExecuteCommand('leaderboard ' .. category)
end, false)

-- Export for other scripts
exports('ShowStats', function()
    ExecuteCommand('mystats')
end)

exports('ShowLeaderboard', function(category)
    ExecuteCommand('leaderboard ' .. (category or 'total_xp'))
end)
