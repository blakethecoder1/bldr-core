-- Advanced logging system for BLDR modules
-- Provides structured logging with different levels and categories

local QBCore = exports['qb-core']:GetCoreObject()

BLDRLogger = {}
BLDRLogger.levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

BLDRLogger.categories = {
    XP = 'xp',
    MONEY = 'money',
    DATABASE = 'database',
    ADMIN = 'admin',
    PERFORMANCE = 'performance',
    SECURITY = 'security'
}

BLDRLogger.config = {
    enabled = true,
    minLevel = BLDRLogger.levels.INFO,
    logToFile = false,
    logToConsole = true,
    logToDatabase = false,
    includeStackTrace = false
}

-- Format log message with timestamp and metadata
function BLDRLogger:formatMessage(level, category, message, data)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local levelName = ''
    
    for name, value in pairs(self.levels) do
        if value == level then
            levelName = name
            break
        end
    end
    
    local formatted = ('[%s] [%s] [%s] %s'):format(timestamp, levelName, category, message)
    
    if data and type(data) == 'table' then
        formatted = formatted .. ' | Data: ' .. json.encode(data)
    end
    
    return formatted
end

-- Main logging function
function BLDRLogger:log(level, category, message, data, source)
    if not self.config.enabled or level < self.config.minLevel then
        return
    end
    
    local formatted = self:formatMessage(level, category, message, data)
    
    -- Console logging
    if self.config.logToConsole then
        print(formatted)
    end
    
    -- File logging (if enabled and supported)
    if self.config.logToFile then
        -- File logging would be implemented here
        -- This requires additional file system access
    end
    
    -- Database logging
    if self.config.logToDatabase then
        local logData = {
            timestamp = os.date('%Y-%m-%d %H:%M:%S'),
            level = level,
            category = category,
            message = message,
            data = data and json.encode(data) or nil,
            source = source,
            resource = GetCurrentResourceName()
        }
        
        -- Store in database (would need a logs table)
        MySQL.Async.execute('INSERT INTO bldr_logs (timestamp, level, category, message, data, source, resource) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            logData.timestamp, logData.level, logData.category, logData.message, 
            logData.data, logData.source, logData.resource
        })
    end
end

-- Convenience methods for different log levels
function BLDRLogger:debug(category, message, data, source)
    self:log(self.levels.DEBUG, category, message, data, source)
end

function BLDRLogger:info(category, message, data, source)
    self:log(self.levels.INFO, category, message, data, source)
end

function BLDRLogger:warn(category, message, data, source)
    self:log(self.levels.WARN, category, message, data, source)
end

function BLDRLogger:error(category, message, data, source)
    self:log(self.levels.ERROR, category, message, data, source)
end

-- Activity tracking functions
function BLDRLogger:trackXP(source, amount, totalXP, level, activity)
    self:info(self.categories.XP, 'XP Gained', {
        source = source,
        amount = amount,
        totalXP = totalXP,
        level = level,
        activity = activity
    }, source)
end

function BLDRLogger:trackMoney(source, amount, account, bonus, activity)
    self:info(self.categories.MONEY, 'Money Transaction', {
        source = source,
        amount = amount,
        account = account,
        bonus = bonus,
        activity = activity
    }, source)
end

function BLDRLogger:trackSecurity(source, action, details)
    self:warn(self.categories.SECURITY, 'Security Event', {
        source = source,
        action = action,
        details = details,
        timestamp = GetGameTimer()
    }, source)
end

function BLDRLogger:trackAdmin(source, command, args)
    self:info(self.categories.ADMIN, 'Admin Command', {
        source = source,
        command = command,
        args = args
    }, source)
end

function BLDRLogger:trackPerformance(operation, duration, details)
    self:debug(self.categories.PERFORMANCE, 'Performance Metric', {
        operation = operation,
        duration = duration,
        details = details
    })
end

return BLDRLogger