--[[
    MISSION 7 - FIX 1: Event Multipliers Not Applied
    File: Shared/Modules/Utilities/PickMutations.luau
    
    BUG: Event multipliers parameter is passed but never used in rollMutation
    FIX: Update function signature and apply event multipliers to mutation weights
--]]

local Mutations = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)

-- Event-based rarity boosts
local EventRarityMultipliers = {
    Common = 1,
    Rare = 1.5,     -- 50% boosted during event
    Mythic = 3,     -- 3x chance during event
}

local BASE_MUTATION_CHANCE = 20

--[[ OLD CODE:
local function rollMutation(luckMultiplier)
--]]

-- NEW CODE:
local function rollMutation(luckMultiplier, eventMultipliers)
    eventMultipliers = eventMultipliers or {}
    
    local totalWeight = 0
    local weightedPool = {}

    for name, mutation in pairs(Mutations) do
        local weight = mutation.Chance

        -- Apply luck multiplier to everything EXCEPT Normal
        if name ~= "Normal" then
            weight = weight * luckMultiplier
        end
        
        -- NEW: Apply event multipliers based on mutation rarity or type
        -- Check if mutation has a defined rarity in event multipliers
        if eventMultipliers[name] then
            weight = weight * eventMultipliers[name]
        end
        
        -- Also check for category-based multipliers (Rare, Epic, etc.)
        if mutation.Rarity and eventMultipliers[mutation.Rarity] then
            weight = weight * eventMultipliers[mutation.Rarity]
        end

        if weight > 0 then
            weightedPool[name] = weight
            totalWeight += weight
        end
    end

    -- Safety check
    if totalWeight <= 0 then
        warn("Mutation roll failed: totalWeight is 0")
        return nil
    end

    -- Single weighted roll
    local roll = math.random() * totalWeight
    local current = 0
    for name, weight in pairs(weightedPool) do
        current += weight
        if roll <= current then
            if name == "Normal" then
                return nil
            else
                return name, Mutations[name]
            end
        end
    end
    
    -- Fallback (shouldn't reach here)
    return nil
end

local module = {}

module.PickMutation = function(luckMultiplier, eventMultipliers)
    -- Validate GuaranteedMutation on server-side only
    if workspace:GetAttribute("GuaranteedMutation") then
        local guaranteed = workspace:GetAttribute("GuaranteedMutation")
        -- Verify it's a valid mutation
        if Mutations[guaranteed] then
            return guaranteed
        else
            warn("Invalid GuaranteedMutation attribute:", guaranteed)
        end
    end
    
    -- NEW: Pass eventMultipliers to rollMutation
    return rollMutation(luckMultiplier, eventMultipliers)
end

return module
