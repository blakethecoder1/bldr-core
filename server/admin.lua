-- admin.lua for bldr_core
--
-- Provides a utility function `IsBLDRAdmin` which centralises
-- permission checks for BLDR admin commands.  Supports QBCore
-- permission groups ('god' or 'admin'), ACE permissions, static
-- whitelisting by license, and a console override.  A debug
-- command `/bldrperms` is also registered to help verify what
-- permissions the server sees for a player.

local QBCore = exports['qb-core']:GetCoreObject()

Config = Config or {}
Config.AdminWhitelist = Config.AdminWhitelist or {
    -- add your license here to always allow admin commands, e.g.:
    -- ["license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"] = true,
}

-- internal helper to get the Rockstar license identifier
local function getLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then
            return id
        end
    end
    return nil
end

-- helper to see if a bypass is enabled via ConVar (setr bldr_admin_bypass 1)
local function bypassOn()
    return GetConvarInt('bldr_admin_bypass', 0) == 1
end

--[[
    IsBLDRAdmin

    Checks whether a player (source) has permission to run admin
    commands in BLDR modules.  It returns true in the following
    cases:
      - The call is from the console (source <= 0)
      - The bldr_admin_bypass ConVar is set to 1
      - QBCore reports the player has 'god' or 'admin' permission
      - ACE permissions allow 'bldr.admin' or 'command'
      - The player's license appears in Config.AdminWhitelist
]]
function IsBLDRAdmin(src)
    -- console always allowed
    if src <= 0 then return true end
    -- runtime bypass for testing
    if bypassOn() then return true end
    -- check QBCore permission groups
    if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(src, 'god') or QBCore.Functions.HasPermission(src, 'admin') then
            return true
        end
    end
    -- check ACE permissions via server.cfg
    if IsPlayerAceAllowed(src, 'bldr.admin') or IsPlayerAceAllowed(src, 'command') then
        return true
    end
    -- check static whitelist
    local lic = getLicense(src)
    if lic and Config.AdminWhitelist[lic] then
        return true
    end
    return false
end

--
-- Export the admin check so other resources can call it safely.
-- Usage: local ok = exports['bldr_core']:IsBLDRAdmin(source)
--
exports('IsBLDRAdmin', function(src)
    return IsBLDRAdmin(src)
end)

--[[
    /bldrperms

    Debug command to print the current permission state for the
    invoking player.  It shows whether bypass is on, the license
    identifier, QBCore permission flags, ACE flags and the final
    result of IsBLDRAdmin.
]]
RegisterCommand('bldrperms', function(source)
    local src = source
    local lic = getLicense(src) or 'n/a'
    local qbGod, qbAdmin = false, false
    if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
        qbGod   = QBCore.Functions.HasPermission(src, 'god')
        qbAdmin = QBCore.Functions.HasPermission(src, 'admin')
    end
    local aceBLDR = IsPlayerAceAllowed(src, 'bldr.admin')
    local aceCmd  = IsPlayerAceAllowed(src, 'command')
    local allowed = IsBLDRAdmin(src)
    local msg = ("BLDR perms → bypass:%s lic:%s | QB(god:%s admin:%s) | ACE(bldr.admin:%s command:%s) | FINAL:%s")
      :format(tostring(bypassOn()), lic, tostring(qbGod), tostring(qbAdmin), tostring(aceBLDR), tostring(aceCmd), tostring(allowed))
    TriggerClientEvent('chat:addMessage', src, { args = { '^3BLDR', msg } })
end, false)