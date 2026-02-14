--[[
    BUG FIX 7.6: Data Validation on Load
    File: Server/Data/init.legacy.luau
    Issue: No validation that loaded data conforms to expected schema
    
    This fix adds comprehensive data validation and repair.
--]]

-- ============================================================================
-- ADD at the top of the file, after imports
-- ============================================================================

--[[
local DATA_SCHEMA = {
    version = "number",
    Cash = "number",
    Rebirths = "number",
    Brainrots = "table",
    Plot = "table",
    PlotGears = "table",
    Unlocks = "table",
    Inventory = "table",
    Settings = "table",
    Stats = "table",
    Purchases = "table",
    Boosts = "table",
    Codes = "table",
    Stock = "table",
    CurrentStock = "number",
    GearStock = "table",
    CurrentGearStock = "number",
    FirstJoin = "number",
    LastLeave = "number",
    OrdersComplete = "number",
    ActiveOrders = "table"
}

local DEFAULT_VALUES = {
    version = 1,
    Cash = 100000,
    Rebirths = 0,
    Brainrots = {},
    Plot = {},
    PlotGears = {},
    Unlocks = {},
    Inventory = {},
    Settings = {
        AutoSell = {},
        SoundEffects = true,
        Music = true,
        DisplayStats = false,
        PerformanceMode = false,
        ShowBrainrots = true,
        TopNotifications = true,
        ItemNotifications = true,
        GiftNotifications = true,
        FavoriteIcons = true
    },
    Stats = {
        Orders = 0,
        Playtime = 0,
        MostCash = 0,
        LifetimeEarnings = 0
    },
    Purchases = {},
    Boosts = {},
    Codes = {},
    Stock = {},
    CurrentStock = 0,
    GearStock = {},
    CurrentGearStock = 0,
    FirstJoin = tick(),
    LastLeave = tick(),
    OrdersComplete = 0,
    ActiveOrders = {}
}

local VALIDATION_RULES = {
    Cash = function(v) return type(v) == "number" and v >= 0 and v <= 9.22e18 end,
    Rebirths = function(v) return type(v) == "number" and v >= 0 and v <= 10000 end,
    OrdersComplete = function(v) return type(v) == "number" and v >= 0 end,
    Brainrots = function(v) return type(v) == "table" end,
    Plot = function(v) return type(v) == "table" end,
    Inventory = function(v) 
        if type(v) ~= "table" then return false end
        -- Check inventory size
        local count = 0
        for _ in pairs(v) do
            count += 1
            if count > 1000 then return false end -- Max 1000 items
        end
        return true
    end
}
--]]

-- ============================================================================
-- ADD validation function
-- ============================================================================

--[[ ADD before PlayerAdded: --]]

--[[
local function validateAndRepairData(data, playerName)
    local repairs = {}
    local isValid = true
    
    -- Check if data is nil or not a table
    if type(data) ~= "table" then
        warn(string.format("[Data Validation] %s has corrupt data (not a table), resetting to defaults", playerName))
        return table.clone(DEFAULT_VALUES), {"Data was corrupt - reset to defaults"}
    end
    
    -- Validate each field
    for field, expectedType in pairs(DATA_SCHEMA) do
        local actualValue = data[field]
        local actualType = type(actualValue)
        
        -- Check type
        if actualValue ~= nil and actualType ~= expectedType then
            table.insert(repairs, string.format("%s: wrong type (%s, expected %s)", field, actualType, expectedType))
            data[field] = DEFAULT_VALUES[field]
            isValid = false
            
        -- Check validation rules
        elseif VALIDATION_RULES[field] and actualValue ~= nil then
            if not VALIDATION_RULES[field](actualValue) then
                table.insert(repairs, string.format("%s: failed validation", field))
                data[field] = DEFAULT_VALUES[field]
                isValid = false
            end
            
        -- Fill missing fields
        elseif actualValue == nil then
            data[field] = DEFAULT_VALUES[field]
            table.insert(repairs, string.format("%s: added missing field", field))
        end
    end
    
    -- Remove unknown fields (optional - could keep them)
    for field in pairs(data) do
        if not DATA_SCHEMA[field] then
            data[field] = nil
            table.insert(repairs, string.format("%s: removed unknown field", field))
        end
    end
    
    -- Deep validate nested tables
    if type(data.Plot) == "table" then
        for plantId, plantData in pairs(data.Plot) do
            if type(plantData) ~= "table" then
                data.Plot[plantId] = nil
                table.insert(repairs, string.format("Plot.%s: removed invalid plant", plantId))
            elseif plantData.Name and type(plantData.Name) ~= "string" then
                data.Plot[plantId] = nil
                table.insert(repairs, string.format("Plot.%s: removed plant with invalid name", plantId))
            end
        end
    end
    
    if type(data.Brainrots) == "table" then
        for rotId, rotData in pairs(data.Brainrots) do
            if type(rotData) ~= "table" or not rotData.Name then
                data.Brainrots[rotId] = nil
                table.insert(repairs, string.format("Brainrots.%s: removed invalid entry", rotId))
            end
        end
    end
    
    if type(data.Inventory) == "table" then
        for itemId, itemData in pairs(data.Inventory) do
            if type(itemData) ~= "table" or not itemData.Name then
                data.Inventory[itemId] = nil
                table.insert(repairs, string.format("Inventory.%s: removed invalid entry", itemId))
            end
        end
    end
    
    -- Log repairs
    if #repairs > 0 then
        warn(string.format("[Data Validation] %s data repairs:", playerName))
        for _, repair in ipairs(repairs) do
            warn("  - " .. repair)
        end
    end
    
    return data, repairs
end
--]]

-- ============================================================================
-- MODIFY PlayerAdded handler to use validation
-- ============================================================================

--[[ In the PlayerAdded handler, AFTER Profile:Reconcile(), ADD: --]]

--[[
-- Validate and repair data
local repairedData, repairs = validateAndRepairData(Profile.Data, plr.Name)
if #repairs > 0 then
    -- Data was repaired, ensure it's saved
    Profile.Data = repairedData
end
--]]

-- ============================================================================
-- ADD data migration function for future schema changes
-- ============================================================================

--[[
local function migrateData(data, currentVersion)
    local version = data.version or 1
    
    -- Migration from v1 to v2
    if version < 2 then
        -- Example: Add new field
        if not data.Stats.LifetimeEarnings then
            data.Stats.LifetimeEarnings = data.Stats.MostCash or 0
        end
        version = 2
    end
    
    -- Migration from v2 to v3
    if version < 3 then
        -- Example: Rename field
        -- if data.OldField then data.NewField = data.OldField; data.OldField = nil end
        version = 3
    end
    
    data.version = currentVersion
    return data
end

-- Use in PlayerAdded after validation:
-- Profile.Data = migrateData(Profile.Data, 2)
--]]

return {}
