--[[
    BUG FIX 4: Mutation Deduplication
    File: Server/Game/ServerUtility.luau
    Issue: Duplicate mutations can be applied to the same fruit
    
    This fix prevents the same mutation from being applied twice.
--]]

-- STEP 1: Add deduplication helper function
-- Add this to the top of ServerUtility.luau or in the Utility table

--[[
    Adds a mutation to the list only if it doesn't already exist
    Returns true if added, false if duplicate
--]]
function Utility.AddUniqueMutation(mutationsList, newMutation)
    if not mutationsList or not newMutation then
        return false
    end
    
    -- Check if mutation already exists
    for _, existingMutation in ipairs(mutationsList) do
        if existingMutation == newMutation then
            return false -- Already exists, don't add
        end
    end
    
    -- Add new mutation
    table.insert(mutationsList, newMutation)
    return true
end

--[[
    Validates and cleans a mutations list, removing duplicates
--]]
function Utility.DeduplicateMutations(mutationsList)
    if not mutationsList then
        return {}
    end
    
    local seen = {}
    local result = {}
    
    for _, mutation in ipairs(mutationsList) do
        if not seen[mutation] then
            seen[mutation] = true
            table.insert(result, mutation)
        end
    end
    
    return result
end

-- STEP 2: Modify SetupFruit to use deduplication
-- In the "UpdateMutations" call handler:

--[[ REPLACE THIS SECTION in SetupFruit:
        elseif call == "UpdateMutations" then
            if not table.find(mutations, info) then
                table.insert(mutations, info)
                PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
                    Mutations = mutations,
                    Weight = fruitWeight
                })
                Utility.ClientMutate(info, fruitObject)
            end
--]]

-- WITH THIS:
        elseif call == "UpdateMutations" then
            -- Use atomic deduplication
            local added = Utility.AddUniqueMutation(mutations, info)
            if added then
                PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
                    Mutations = mutations,
                    Weight = fruitWeight
                })
                Utility.ClientMutate(info, fruitObject)
            end

-- STEP 3: Deduplicate on fruit spawn
-- In SetupFruit, when loading existing fruit data:

--[[ REPLACE THIS:
    if exists and fruitData and fruitData.Weight then
        local fruitData = ActualData.Plot[plantID][dataIndex]
        fruitWeight = fruitData.Weight
        mutations = fruitData.Mutations
        favorited = fruitData.Favorited or false

        fruitObject:SetAttribute("Weight", fruitWeight)
        Utility.ClientScale(fruitWeight, fruitObject)

        for _, mutationName in mutations do
            Utility.ClientMutate(mutationName, fruitObject)
        end
--]]

-- WITH THIS:
    if exists and fruitData and fruitData.Weight then
        local fruitData = ActualData.Plot[plantID][dataIndex]
        fruitWeight = fruitData.Weight
        -- DEDUPLICATE mutations when loading
        mutations = Utility.DeduplicateMutations(fruitData.Mutations)
        favorited = fruitData.Favorited or false

        fruitObject:SetAttribute("Weight", fruitWeight)
        Utility.ClientScale(fruitWeight, fruitObject)

        -- Only apply unique mutations
        local appliedMutations = {}
        for _, mutationName in mutations do
            if not appliedMutations[mutationName] then
                appliedMutations[mutationName] = true
                Utility.ClientMutate(mutationName, fruitObject)
            end
        end
        
        -- Save deduplicated list back to data if it was different
        if #mutations ~= #(fruitData.Mutations or {}) then
            PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
                Mutations = mutations,
                Weight = fruitWeight,
                Favorited = favorited
            })
        end

-- STEP 4: Apply same fix to brainrot mutations
-- In Plot/init.luau, find where mutations are added to brainrots
-- and apply the same deduplication logic

--[[ In the brainrot spawning/mutation code, replace:
    for _, mutation in Info.Mutations do
        if MutationsData[mutation] then
            ServerUtility.ClientMutate(mutation, getTool:FindFirstChildOfClass("Model"))
        end
    end
--]]

--[[ WITH:
    local appliedMutations = {}
    for _, mutation in Info.Mutations do
        if not appliedMutations[mutation] and MutationsData[mutation] then
            appliedMutations[mutation] = true
            ServerUtility.ClientMutate(mutation, getTool:FindFirstChildOfClass("Model"))
        end
    end
--]]

-- STEP 5: Data migration for existing duplicates
-- Add this function to run once on player join:

function Utility.CleanupDuplicateMutations(playerData)
    local needsSave = false
    
    -- Clean up plot fruits
    for plantID, plantData in pairs(playerData.Plot or {}) do
        for index, fruitData in pairs(plantData) do
            if type(fruitData) == "table" and fruitData.Mutations then
                local deduped = Utility.DeduplicateMutations(fruitData.Mutations)
                if #deduped ~= #fruitData.Mutations then
                    playerData.Plot[plantID][index].Mutations = deduped
                    needsSave = true
                end
            end
        end
    end
    
    -- Clean up inventory items
    for itemID, itemData in pairs(playerData.Inventory or {}) do
        if itemData.Mutations then
            local deduped = Utility.DeduplicateMutations(itemData.Mutations)
            if #deduped ~= #itemData.Mutations then
                playerData.Inventory[itemID].Mutations = deduped
                needsSave = true
            end
        end
    end
    
    return needsSave
end

return {}
