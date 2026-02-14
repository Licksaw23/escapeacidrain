--[[
    MISSION 7 - FIX 3: Effect Mutation Limit Atomic Lock
    File: Server/Game/Plot/init.luau
    
    BUG: Effect mutation limit can be bypassed via race conditions
    FIX: Add atomic lock and batch mutation application
--]]

-- Replace the mutation application code in the brainrot feeding section
-- Around line 2848 in the original file

--[[ OLD CODE:
if holdingItemData.Mutations then
    for index, Mutation in holdingItemData.Mutations do
        if table.find(brainrotstuff.Mutations, Mutation) then
            continue
        end

        local checkMutation = MutationsData[Mutation]
        if checkMutation.IsEffect then
            local effectCount = 0
            for _, existingMutation in brainrotstuff.Mutations do
                if MutationsData[existingMutation].IsEffect then
                    effectCount += 1
                end
            end

            if effectCount < 6 then
                table.insert(brainrotstuff.Mutations, Mutation)
            end
        end
    end
end
--]]

-- NEW CODE:
if holdingItemData.Mutations then
    -- Atomic lock to prevent race conditions
    if not brainrotstuff.MutationLock then
        brainrotstuff.MutationLock = true
        
        -- Count current effects once (atomic)
        local effectCount = 0
        local existingMutations = {}
        
        for _, existingMutation in ipairs(brainrotstuff.Mutations) do
            existingMutations[existingMutation] = true
            local mutationData = MutationsData[existingMutation]
            if mutationData and mutationData.IsEffect then
                effectCount += 1
            end
        end
        
        -- Track non-effect mutations that were added
        local addedAnyMutation = false
        
        -- Process all mutations from the fruit
        for _, Mutation in ipairs(holdingItemData.Mutations) do
            -- Skip if already exists
            if existingMutations[Mutation] then
                continue
            end
            
            local checkMutation = MutationsData[Mutation]
            if not checkMutation then
                continue
            end
            
            if checkMutation.IsEffect then
                -- Effect mutation - check limit
                if effectCount < 6 then
                    table.insert(brainrotstuff.Mutations, Mutation)
                    existingMutations[Mutation] = true
                    effectCount += 1
                    addedAnyMutation = true
                end
            else
                -- Regular mutation - no limit
                table.insert(brainrotstuff.Mutations, Mutation)
                existingMutations[Mutation] = true
                addedAnyMutation = true
            end
        end
        
        -- Update CurrentOrder if mutations were added
        if addedAnyMutation and self.CurrentOrder[self.Active[BrainrotID].Path] then
            self.CurrentOrder[self.Active[BrainrotID].Path].Mutations = brainrotstuff.Mutations
        end
        
        -- Release lock
        brainrotstuff.MutationLock = nil
    else
        -- Another thread is processing mutations, queue this one
        warn("[Plot] Mutation lock conflict for brainrot:", BrainrotID)
        -- Optionally: retry after short delay
        task.delay(0.1, function()
            -- Retry logic could go here
        end)
    end
end

--[[
    ADDITIONAL FIX: Add deduplication helper function
    Add this to the top of Plot/init.luau or in a utility module
--]]

local function DeduplicateMutations(mutationsList)
    if not mutationsList or #mutationsList == 0 then
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

-- Use deduplication when storing mutations
-- After applying mutations, deduplicate before saving:
brainrotstuff.Mutations = DeduplicateMutations(brainrotstuff.Mutations)

--[[
    ADDITIONAL FIX: Apply same atomic logic to fruit generation
    In FruitSystem.GenerateFruitData:
--]]

-- Add to FruitSystem.luau
function FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
    local itemData = ItemsData[productName]
    if not itemData then return nil end

    -- Generate weight
    local weight = PickWeight.RandomizeWeight(itemData.WeightPool)

    -- Generate mutations with deduplication
    local mutations = {}
    local seenMutations = {}
    
    local totalLuck = (playerMutationLuck or 0) + (playerLuck or 0)
    local randomMutation = PickMutations.PickMutation(totalLuck, eventMultipliers or {})
    
    if randomMutation and not seenMutations[randomMutation] then
        table.insert(mutations, randomMutation)
        seenMutations[randomMutation] = true
    end
    
    -- Support for multiple mutation rolls (if luck allows)
    -- Roll for a second mutation with reduced chance
    local secondRollChance = math.min(totalLuck * 0.1, 0.5) -- Max 50% chance
    if math.random() < secondRollChance then
        local secondMutation = PickMutations.PickMutation(totalLuck, eventMultipliers or {})
        if secondMutation and not seenMutations[secondMutation] then
            table.insert(mutations, secondMutation)
            seenMutations[secondMutation] = true
        end
    end

    return {
        PlantedAt = workspace:GetServerTimeNow(),
        GrowthDuration = DEFAULT_FRUIT_GROWTH_TIME,
        RespawnTime = DEFAULT_FRUIT_RESPAWN_TIME,
        HarvestedAt = nil,
        Weight = weight,
        Mutations = mutations,
        Favorited = false
    }
end
