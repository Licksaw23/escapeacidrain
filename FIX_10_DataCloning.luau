--[[
    BUG FIX 10: Plot Data Reference Sharing
    File: Server/Game/Plot/init.luau
    Issue: Direct table assignment can cause reference sharing issues
    
    This fix ensures data is always cloned before being set in replica.
--]]

-- ============================================================================
-- Helper function for deep cloning
-- ============================================================================

--[[ ADD at the top of the Plot module: --]]

--[[
-- Deep clone a table to prevent reference sharing
local function deepClone(original)
    if type(original) ~= "table" then
        return original
    end
    
    local clone = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            clone[key] = deepClone(value)
        else
            clone[key] = value
        end
    end
    
    return clone
end

-- Shallow clone for simple tables
local function shallowClone(original)
    if type(original) ~= "table" then
        return original
    end
    
    local clone = {}
    for key, value in pairs(original) do
        clone[key] = value
    end
    
    return clone
end
--]]

-- ============================================================================
-- Fix fruit data setting
-- ============================================================================

--[[ In InitializePlantFruits, REPLACE: --]]

--[[ OLD CODE:
if not plantData.Fruits["1"] then
    local fruitData = ServerUtility.GenerateFruitData(productName, playerLuck, playerMutationLuck, plot.EventMultipliers)
    plantData.Fruits["1"] = fruitData
    PlayerReplica:SetValue({"Plot", PlantID, "Fruits", "1"}, fruitData)
end
--]]

--[[ NEW CODE:
if not plantData.Fruits["1"] then
    local fruitData = ServerUtility.GenerateFruitData(productName, playerLuck, playerMutationLuck, plot.EventMultipliers)
    -- Clone to prevent reference sharing
    local clonedFruitData = deepClone(fruitData)
    plantData.Fruits["1"] = clonedFruitData
    PlayerReplica:SetValue({"Plot", PlantID, "Fruits", "1"}, clonedFruitData)
end
--]]

-- ============================================================================
-- Fix order data setting
-- ============================================================================

--[[ In order creation code, ENSURE data is cloned: --]]

--[[
self.Orders[OrderIndex] = {
    Requirements = deepClone(FinalizedOrderArray),
    Currents = {},
    Mutations = {},
    Weight = 1.1,
    TimeRemaining = OrderTime,
    MaxTime = OrderTime
}

-- When updating, clone the requirements:
self.Orders[OrderIndex].Requirements = deepClone(newRequirements)
--]]

-- ============================================================================
-- Fix inventory item setting
-- ============================================================================

--[[ In GiveItem, REPLACE item data setting: --]]

--[[ OLD CODE:
PlayerReplica:SetValue({"Inventory",Info.ID}, {
    ["Name"] = Info.Name;
    ["Mutations"] = Info.Mutations or nil;
    ["Weight"] = Info.Weight or nil;
})
--]]

--[[ NEW CODE:
-- Clone mutations table to prevent reference sharing
local mutationsClone = nil
if Info.Mutations then
    mutationsClone = shallowClone(Info.Mutations)
end

PlayerReplica:SetValue({"Inventory",Info.ID}, {
    ["Name"] = Info.Name;
    ["Mutations"] = mutationsClone;
    ["Weight"] = Info.Weight or nil;
})
--]]

-- ============================================================================
-- Fix brainrot data setting  
-- ============================================================================

--[[ In PlaceBrainrot, REPLACE: --]]

--[[ OLD CODE:
if not self.OwnerData.Brainrots[BrainrotID] then
    PlayerReplica:SetValue({"Brainrots", BrainrotID}, {
        ["Position"] = Slot;
        ["Mutations"] = mutations or {};
        ["Weight"] = weight or {};
        ["Name"] = name;
        ["Money"] = 0;
        ["OfflineMoney"] = 0;
    })
    -- ...
end
--]]

--[[ NEW CODE:
if not self.OwnerData.Brainrots[BrainrotID] then
    -- Clone mutations to prevent reference sharing
    local mutationsClone = mutations and shallowClone(mutations) or {}
    
    PlayerReplica:SetValue({"Brainrots", BrainrotID}, {
        ["Position"] = Slot;
        ["Mutations"] = mutationsClone;
        ["Weight"] = weight;
        ["Name"] = name;
        ["Money"] = 0;
        ["OfflineMoney"] = 0;
    })
    -- ...
end
--]]

-- ============================================================================
-- Fix boost data setting
-- ============================================================================

--[[ In boost application code: --]]

--[[
-- Clone boost data before setting
local boostDataClone = deepClone({
    ["Type"] = "Luck";
    ["Amount"] = luckAmount;
    ["Start"] = tick();
    ["Time"] = luckTime;
})

Replica:SetValue({"Boosts", HttpService:GenerateGUID(false)}, boostDataClone)
--]]

return {}
