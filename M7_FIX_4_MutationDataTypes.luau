--[[
    MISSION 7 - FIX 4: Mutation Data Type Standardization
    Files: Multiple
    
    BUG: Mutations stored inconsistently (arrays vs dictionaries, nil vs empty)
    FIX: Standardize all mutation storage to use arrays, normalize nil to empty
--]]

-- ============================================================================
-- FIX FOR: Server/Game/Plot/FruitSystem.luau
-- ============================================================================

-- Helper function at top of module
local function NormalizeMutations(mutations)
    if not mutations then
        return {}  -- Convert nil to empty array
    end
    if type(mutations) ~= "table" then
        warn("[NormalizeMutations] Expected table, got:", type(mutations))
        return {}
    end
    -- Ensure it's an array, not a dictionary
    local result = {}
    for _, v in ipairs(mutations) do
        if type(v) == "string" then
            table.insert(result, v)
        end
    end
    return result
end

-- In GenerateFruitData, normalize output:
function FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
    -- ... existing code ...
    
    return {
        PlantedAt = workspace:GetServerTimeNow(),
        GrowthDuration = DEFAULT_FRUIT_GROWTH_TIME,
        RespawnTime = DEFAULT_FRUIT_RESPAWN_TIME,
        HarvestedAt = nil,
        Weight = weight,
        Mutations = NormalizeMutations(mutations),  -- Normalized!
        Favorited = false
    }
end

-- In ProcessHarvest, normalize before returning:
function FruitSystem.ProcessHarvest(plantData, fruitIndex, currentTime)
    -- ... existing validation ...
    
    -- Return harvest data with normalized mutations
    return true, {
        Weight = fruitData.Weight,
        Mutations = NormalizeMutations(fruitData.Mutations),  -- Normalized!
        Favorited = fruitData.Favorited
    }
end


-- ============================================================================
-- FIX FOR: Server/Game/Plot/init.luau - GiveItem function
-- ============================================================================

function plot:GiveItem(Info)
    local PlayerReplica = Data[self.Owner]
    local getLibraryData = ItemsData[Info.Name] or GearsData[Info.Name]
    local addsItem = true
    
    -- Normalize mutations input
    local normalizedMutations = NormalizeMutations(Info.Mutations)
    
    -- Create a copy to avoid reference issues
    local mutationsCopy = table.clone(normalizedMutations)
    
    if getLibraryData and (getLibraryData.Type == "Plant" or getLibraryData.Type == "Potion" or getLibraryData.Type == "Gear") then
        -- Stackable items logic
        local getID
        for ID, array in PlayerReplica.Data.Inventory do
            if array.Name == Info.Name then
                getID = ID
            end
        end

        if getID then
            PlayerReplica:SetValue({"Inventory", getID, "Quantity"}, 
                PlayerReplica.Data.Inventory[getID].Quantity + 1)
            addsItem = false
        else
            PlayerReplica:SetValue({"Inventory", Info.ID}, {
                ["Name"] = Info.Name;
                ["Mutations"] = mutationsCopy;  -- Use copy!
                ["Weight"] = Info.Weight or nil;
                ["Quantity"] = 1;
            })
        end
    else
        -- Non-stackable items
        PlayerReplica:SetValue({"Inventory", Info.ID}, {
            ["Name"] = Info.Name;
            ["Mutations"] = mutationsCopy;  -- Use copy!
            ["Weight"] = Info.Weight or nil;
        })
    end

    -- ... rest of function ...
    
    -- Handle unlocks with normalized mutations
    if Info.Weight then
        local currentIndexData = PlayerReplica.Data.Unlocks[Info.Name]
        local array = {["Normal"] = true}

        -- Use ipairs for array iteration
        for _, mu in ipairs(mutationsCopy) do
            array[mu] = true
        end

        -- Handle existing mutations (may be array or dictionary from old data)
        if currentIndexData then
            for oldMutation, _ in pairs(currentIndexData) do
                array[oldMutation] = true
            end
        end

        PlayerReplica:SetValue({"Unlocks", Info.Name}, array)
        self.Functions["IndexBoost"]()
    end
    
    -- ... rest of function ...
end


-- ============================================================================
-- FIX FOR: Server/Game/Plot/init.luau - Brainrot feeding
-- ============================================================================

-- When processing mutations from fruit, normalize first
if holdingItemData.Mutations then
    local normalizedFruitMutations = NormalizeMutations(holdingItemData.Mutations)
    
    -- Use normalizedFruitMutations instead of holdingItemData.Mutations
    for _, Mutation in ipairs(normalizedFruitMutations) do
        -- ... rest of mutation logic ...
    end
end


-- ============================================================================
-- FIX FOR: Server/Game/ServerUtility.luau - ClientMutate
-- ============================================================================

Utility.ClientMutate = function(mutation, model)
    if not mutation or not model then return end
    if not MutationsData[mutation] then
        warn("[ClientMutate] Invalid mutation:", mutation)
        return
    end
    
    if not Utility.Mutations[model] then
        Utility.Mutations[model] = {}
    end
    
    -- Check for duplicates before adding
    for _, existing in ipairs(Utility.Mutations[model]) do
        if existing == mutation then
            return  -- Already exists, don't add
        end
    end

    table.insert(Utility.Mutations[model], mutation)

    FXRemote:FireAllClients("Replicate",{
        ["Call"] = "Mutate";
        ["Array"] = {
            [1] = {
                Model = model;
                Mutation = mutation;
            };
        };
    })
end


-- ============================================================================
-- DATA MIGRATION: Clean up existing data
-- ============================================================================

-- Run this once on player join to clean up legacy data formats
function Utility.MigrateMutationData(playerData)
    local needsSave = false
    
    -- Clean up plot fruits
    for plantID, plantData in pairs(playerData.Plot or {}) do
        if type(plantData) == "table" and plantData.Fruits then
            for index, fruitData in pairs(plantData.Fruits) do
                if fruitData.Mutations then
                    local normalized = NormalizeMutations(fruitData.Mutations)
                    if #normalized ~= #(fruitData.Mutations or {}) then
                        playerData.Plot[plantID].Fruits[index].Mutations = normalized
                        needsSave = true
                    end
                end
            end
        end
    end
    
    -- Clean up inventory
    for itemID, itemData in pairs(playerData.Inventory or {}) do
        if itemData.Mutations then
            local normalized = NormalizeMutations(itemData.Mutations)
            if #normalized ~= #(itemData.Mutations or {}) then
                playerData.Inventory[itemID].Mutations = normalized
                needsSave = true
            end
        end
    end
    
    -- Clean up brainrots
    for brainrotID, brainrotData in pairs(playerData.Brainrots or {}) do
        if brainrotData.Mutations then
            local normalized = NormalizeMutations(brainrotData.Mutations)
            if #normalized ~= #(brainrotData.Mutations or {}) then
                playerData.Brainrots[brainrotID].Mutations = normalized
                needsSave = true
            end
        end
    end
    
    -- Clean up unlocks
    for unlockName, unlockData in pairs(playerData.Unlocks or {}) do
        -- Unlocks may be stored as dictionary {["Gold"]=true, ["Rainbow"]=true}
        -- Convert to array format for consistency
        local asArray = {}
        for mutationName, _ in pairs(unlockData) do
            table.insert(asArray, mutationName)
        end
        -- Note: Unlocks might need to stay as dictionary for lookup efficiency
        -- This is optional based on usage patterns
    end
    
    return needsSave
end
