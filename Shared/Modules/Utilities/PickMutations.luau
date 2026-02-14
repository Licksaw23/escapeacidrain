local Mutations = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)

-- Event-based rarity boosts
local EventRarityMultipliers = {
	Common = 1,
	Rare = 1.5,     -- 50% boosted during event
	Mythic = 3,     -- 3x chance during event
}

local BASE_MUTATION_CHANCE = 20

local function rollMutation(luckMultiplier)
	local totalWeight = 0
	local weightedPool = {}
	

	for name, mutation in pairs(Mutations) do
		local weight = mutation.Chance

		-- Apply luck multiplier to everything EXCEPT Normal
		if name ~= "Normal" then
			weight = weight * luckMultiplier
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
end

local module = {}

module.PickMutation = function(luckMultiplier, eventMultipliers)
	if workspace:GetAttribute("GuaranteedMutation") then
		return workspace:GetAttribute("GuaranteedMutation")
	else
		return rollMutation(luckMultiplier, eventMultipliers);
	end
end

return module