# BLDR Core

**Version:** 1.1.0  
**Author:** blakethepet  
**Framework:** QBCore  
**Database:** oxmysql

## 📋 Description

`bldr_core` is a shared progression and reward system for the BLDR suite of scripts. It provides a centralized XP/leveling system and standardized money payouts that can be used across multiple modules (farming, crafting, drugs, etc.). 

This resource eliminates the need for each module to implement its own progression system, ensuring consistency and reducing code duplication.

## ✨ Features

- **Universal XP System** - Single progression system shared across all BLDR modules
- **8 Progressive Levels** - From Novice to Legendary with increasing multipliers
- **Level-Based Bonuses** - Automatic money bonuses based on player level
- **Quality-Based Rewards** - Enhanced payouts for higher quality items
- **Persistent Storage** - All player data saved to MySQL database
- **Performance Optimized** - In-memory caching with configurable auto-save intervals
- **Flexible Money System** - Support for cash, bank, crypto, black_money, and marked bills
- **Advanced Logging** - Structured logging system with multiple severity levels
- **Admin Tools** - Built-in admin commands for testing and player management
- **Granular Permissions** - Multiple permission levels (QBCore, ACE, whitelist, console)

## 🎮 Progression System

### Level Configuration

| Level | XP Required | Title | Multiplier | Money Bonus |
|-------|-------------|-------|------------|-------------|
| 0 | 0 | Novice | 1.00x | $0 |
| 1 | 200 | Apprentice | 1.05x | $50 |
| 2 | 600 | Journeyman | 1.12x | $100 |
| 3 | 1,200 | Artisan | 1.20x | $200 |
| 4 | 2,400 | Expert | 1.35x | $400 |
| 5 | 4,800 | Master | 1.50x | $800 |
| 6 | 9,600 | Grandmaster | 1.75x | $1,600 |
| 7 | 19,200 | Legendary | 2.00x | $3,200 |

### XP Multipliers

Configurable multipliers for different activities:
- **Base:** 1.0x (default)
- **Farming:** 1.0x
- **Crafting:** 1.0x
- **Processing:** 1.2x
- **Weekend Bonus:** 1.5x
- **VIP Bonus:** 2.0x

## 📦 Installation

### 1. Database Setup

Execute the SQL file to create the required table:

```sql
-- Run sql/bldr_core.sql in your database
CREATE TABLE IF NOT EXISTS `bldr_player_data` (
  `license` varchar(50) PRIMARY KEY NOT NULL,
  `xp` int(11) NOT NULL DEFAULT 0,
  `level` int(11) NOT NULL DEFAULT 0,
  `total_money_earned` int(11) NOT NULL DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_level` (`level`),
  INDEX `idx_xp` (`xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2. Resource Installation

1. Place `bldr_core` folder in your server's `resources` directory
2. Add to your `server.cfg`:
```cfg
ensure bldr_core
```

### 3. Dependencies

Required resources:
- `qb-core` - QBCore Framework
- `oxmysql` - Database connector

## 🔧 Configuration

Edit `config.lua` to customize the progression system:

### Level Progression

```lua
Config.Levels = {
    { level = 0, xp = 0,     multiplier = 1.00, title = 'Novice',      moneyBonus = 0 },
    { level = 1, xp = 200,   multiplier = 1.05, title = 'Apprentice',  moneyBonus = 50 },
    -- Add or modify levels as needed
}
```

### Money Settings

```lua
Config.Money = {
    type = 'cash',                    -- 'cash', 'bank', 'crypto', 'black_money'
    useMarkedBills = false,           -- Use marked bills instead of direct money
    markedBillsChance = 0.0,          -- Probability of marked bills (0-1)
    markedBillsItem = 'markedbills',  -- Item name for marked bills
    levelBonusEnabled = true,         -- Enable level-based money bonuses
    qualityBonusEnabled = true        -- Enable quality-based bonuses
}
```

### Notifications

```lua
Config.Notifications = {
    levelUp = true,           -- Show level up notifications
    xpGain = false,          -- Show XP gain notifications
    moneyBonus = true,       -- Show money bonus notifications
    blueprintUnlock = true   -- Show blueprint unlock notifications
}
```

### Performance Tuning

```lua
Config.Performance = {
    saveInterval = 300000,    -- Auto-save every 5 minutes (ms)
    cacheTimeout = 1800000,   -- Clear cache after 30 minutes
    batchSaveSize = 10        -- Max players per batch save
}
```

## 💻 Usage for Developers

### Server-Side Exports

#### AddXP
Add experience points to a player.

```lua
-- Add 50 XP to player
local newXP, newLevel = exports['bldr_core']:AddXP(source, 50)

-- Player will automatically level up if threshold is reached
-- Level up notification is sent automatically
```

#### AddMoney
Award money with automatic level and quality bonuses.

```lua
-- Basic usage - add $500 to player
local success, finalAmount = exports['bldr_core']:AddMoney(source, 500)

-- With custom account type
local success, finalAmount = exports['bldr_core']:AddMoney(source, 500, 'bank')

-- With quality bonus (quality 0-100)
local success, finalAmount = exports['bldr_core']:AddMoney(source, 500, 'cash', 85)

-- Quality of 85% will add bonus money
-- Level bonuses are added automatically based on player's level
```

#### GetLevel
Get a player's current level.

```lua
local level = exports['bldr_core']:GetLevel(source)
print('Player is level: ' .. level)
```

#### GetXP
Get a player's current XP total.

```lua
local xp = exports['bldr_core']:GetXP(source)
print('Player has: ' .. xp .. ' XP')
```

#### GetPlayerStats
Get comprehensive player statistics.

```lua
local stats = exports['bldr_core']:GetPlayerStats(source)
-- Returns: { xp, level, title, multiplier, nextLevelXP, moneyBonus }

print('Level: ' .. stats.level)
print('Title: ' .. stats.title)
print('Multiplier: ' .. stats.multiplier .. 'x')
print('Next Level: ' .. stats.nextLevelXP .. ' XP')
```

#### IsBLDRAdmin
Check if a player has admin permissions.

```lua
if exports['bldr_core']:IsBLDRAdmin(source) then
    -- Player has admin permissions
    -- Grant access to admin commands
end
```

### Example Integration

```lua
-- In your bldr_farming/server/main.lua
RegisterNetEvent('bldr_farming:harvest', function(cropType, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Calculate XP based on crop type
    local xpAmount = amount * 5  -- 5 XP per crop
    
    -- Add XP (player may level up automatically)
    local newXP, newLevel = exports['bldr_core']:AddXP(src, xpAmount)
    
    -- Give items to player
    Player.Functions.AddItem(cropType, amount)
    
    -- Calculate and award money with automatic bonuses
    local basePrice = 50  -- $50 per crop
    local totalValue = basePrice * amount
    local quality = math.random(70, 100)  -- Random quality
    
    -- AddMoney will automatically apply level bonuses and quality bonuses
    local success, finalAmount = exports['bldr_core']:AddMoney(src, totalValue, 'cash', quality)
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 
            ('Harvested %dx %s | +%d XP | Earned $%d'):format(amount, cropType, xpAmount, finalAmount),
            'success')
    end
end)
```

## 🛠️ Admin Commands

### `/bldrxp <player_id> <amount>`
Add XP to a player (admin only).

```
/bldrxp 1 500
-- Adds 500 XP to player with ID 1
```

### `/bldrsetlevel <player_id> <level>`
Set a player's level directly (admin only).

```
/bldrsetlevel 1 5
-- Sets player 1 to level 5 (Master)
```

### `/bldrstats [player_id]`
Check player progression stats.

```
/bldrstats 1
-- Shows XP, level, title, multiplier for player 1

/bldrstats
-- Shows your own stats
```

### `/bldrperms`
Check your current admin permissions.

```
/bldrperms
-- Displays permission state (QBCore, ACE, whitelist status)
```

### `/bldrresetplayer <player_id>`
Reset a player's progression (admin only).

```
/bldrresetplayer 1
-- Resets player 1 back to level 0 with 0 XP
```

## 🔐 Permission System

### Admin Access Methods

The `IsBLDRAdmin` function checks permissions in this order:

1. **Console Access** - Server console always has admin access
2. **ConVar Bypass** - Set `setr bldr_admin_bypass 1` in server.cfg for testing
3. **QBCore Permissions** - Players with 'god' or 'admin' permission group
4. **ACE Permissions** - Players with 'bldr.admin' or 'command' ACE permission
5. **License Whitelist** - Manually whitelist specific licenses in config

### Setting Up Admin Access

#### Method 1: QBCore Permissions
```lua
-- In qb-core/shared/permissions.lua or admin panel
QBCore.Functions.AddPermission(playerId, 'admin')
```

#### Method 2: ACE Permissions
```cfg
# In server.cfg
add_ace group.admin bldr.admin allow
add_principal identifier.license:YOUR_LICENSE_HERE group.admin
```

#### Method 3: License Whitelist
```lua
-- In config.lua
Config.AdminWhitelist = {
    ["license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"] = true,
}
```

## 📊 Logging System

The built-in logger provides structured logging with severity levels:

### Log Levels
- **DEBUG** - Detailed debugging information
- **INFO** - General informational messages
- **WARN** - Warning messages
- **ERROR** - Error conditions

### Categories
- **XP** - Experience point transactions
- **MONEY** - Money transactions and bonuses
- **DATABASE** - Database operations
- **ADMIN** - Admin command usage
- **PERFORMANCE** - Performance metrics
- **SECURITY** - Security-related events

### Usage in Code

```lua
-- Log an XP transaction
BLDRLogger:info(BLDRLogger.categories.XP, 
    'Player gained XP', 
    { player = src, amount = 50, newTotal = 350 })

-- Log an error
BLDRLogger:error(BLDRLogger.categories.DATABASE, 
    'Failed to save player data', 
    { player = src, error = err })
```

## 🔄 Data Persistence

### Auto-Save System
- Player data is cached in memory for performance
- Automatic saves occur every 5 minutes (configurable)
- Data is saved immediately on level up
- Data is saved when player disconnects

### Manual Save
```lua
-- Force save player data (internal use)
savePlayerData(source, xp, level)
```

## 🎯 Performance Optimization

### Caching Strategy
- Player data loaded once and cached in memory
- Cache automatically cleared after 30 minutes of inactivity
- Batch save operations for multiple players
- Asynchronous database operations to prevent blocking

### Database Indexes
- Primary key on `license` for fast lookups
- Index on `level` for leaderboard queries
- Index on `xp` for ranking queries

## 🐛 Debugging

### Enable Debug Mode
```lua
-- In config.lua
Config.Debug = true
```

Debug mode prints verbose information about:
- XP transactions
- Level calculations
- Money bonuses
- Database operations
- Cache operations

### Console Output Example
```
[bldr_core] Added 50 XP to 1 (total XP: 350, level: 2)
[bldr_core] Added $550 to 1 (cash) [original: $500] [marked: false] [bonuses: Level 2 Bonus: $50]
```

## 🔗 Integration Examples

### Farming Module Integration
```lua
-- Award XP and money for harvesting
local xp, level = exports['bldr_core']:AddXP(source, 25)
local success, amount = exports['bldr_core']:AddMoney(source, 500, 'cash', 90)
```

### Crafting Module Integration
```lua
-- Award XP for crafting with quality bonus
local xp, level = exports['bldr_core']:AddXP(source, 50)
local success, amount = exports['bldr_core']:AddMoney(source, 1000, 'cash', itemQuality)
```

### Drug Dealing Module Integration
```lua
-- Check level requirement before allowing sale
local playerLevel = exports['bldr_core']:GetLevel(source)
if playerLevel >= requiredLevel then
    -- Process sale
    local xp, level = exports['bldr_core']:AddXP(source, 100)
    local success, amount = exports['bldr_core']:AddMoney(source, 5000, 'cash')
end
```

## 📝 License

This resource is part of the BLDR suite created by **blakethepet**. All rights reserved.

## 🤝 Support

For issues, questions, or suggestions:
1. Check the debug output with `Config.Debug = true`
2. Use `/bldrperms` to verify admin permissions
3. Verify database table exists and is accessible
4. Check console for error messages

## 📈 Version History

### 1.1.0
- Added advanced logging system
- Improved admin permission checks
- Added comprehensive player stats export
- Performance optimizations
- Enhanced documentation

### 1.0.0
- Initial release
- Core XP and leveling system
- Money reward system with bonuses
- Basic admin commands
