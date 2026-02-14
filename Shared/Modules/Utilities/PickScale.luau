local module = {}

function module.RandomizeWeight(WeightPool, luck)
	local weightPool = WeightPool
	if not weightPool then
		warn("No WeightPool defined for item")
		return 1
	end

	luck = luck or 1 -- Default to no luck modifier

	local minWeight = weightPool[1]
	local maxWeight = weightPool[2]

	-- Generate random value between 0 and 1
	local randomValue = math.random()

	-- Apply luck modifier by raising to a power (inverse of luck)
	-- Higher luck = lower power = biases towards 1 (max weight)
	-- luck = 1: no change
	-- luck = 2: moderate bias towards max
	-- luck = 3: strong bias towards max
	if luck > 1 then
		randomValue = randomValue ^ (1 / luck)
	end

	-- Calculate weight within the pool
	local weight = minWeight + (randomValue * (maxWeight - minWeight))

	-- Round to 1 decimal place
	weight = math.floor(weight * 10 + 0.5) / 10

	return weight
end

return module