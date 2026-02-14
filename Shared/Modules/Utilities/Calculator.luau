local module = {}

local Brainrots = require(game.ReplicatedStorage.Game.Modules.Libraries.BrainrotsData)
local MutationsData = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)

function module.CalculateMoneyPerSecond(name, weight, mutations, rebirths)
	local baseMoneyPerSecond = Brainrots[name].MoneyPerSecond
	local finalMultiplier = 1
	
	
	-- mutations --
	for _, mutation in mutations or {} do
		local mut_cache = MutationsData[mutation]
	
		if mut_cache then
			finalMultiplier += mut_cache.Multiplier
		end
	end
	
	if weight > 1 then
		finalMultiplier += (weight/15)
	end
	
	if rebirths and rebirths > 0 then
		finalMultiplier += (rebirths * 0.5)
	end
	
	return math.floor(baseMoneyPerSecond * finalMultiplier)
end

function module.CalculateScaleFromWeight(weight, itemWeightPool, model)
	if not weight or weight < 0 then
		warn("Invalid weight:", weight)
		return nil
	end
	if not itemWeightPool or not itemWeightPool[1] or not itemWeightPool[2] then
		warn("Invalid weight pool:", itemWeightPool)
		return nil
	end
	if not model then
		warn("Model not provided")
		return nil
	end

	local baseScale = model:GetScale()
	local minWeight = itemWeightPool[1]
	local maxWeight = itemWeightPool[2]

	if weight <= minWeight then
		return baseScale
	end

	if minWeight == maxWeight then
		return baseScale
	end

	local excessWeight = weight - minWeight
	local weightRange = maxWeight - minWeight
	local normalizedExcess = excessWeight / weightRange
	local scaleFactor = math.log(1 + normalizedExcess * 9) / math.log(10)
	local maxScaleMultiplier = 1.5
	local scaleMultiplier = 1 + (scaleFactor * (maxScaleMultiplier - 1))

	return baseScale * scaleMultiplier
end




function module.CalculateWorth(basePrice, weight, mutations) -- can calculate brainrots, fruits, and returns final price. --
	local base = basePrice
	
	local finalMultiplier = 1

	-- mutations --
	for _, mutation in mutations or {} do
		local mut_cache = MutationsData[mutation]

		if mut_cache then
			finalMultiplier += mut_cache.Multiplier
		end
	end

	if weight > 1 then
		finalMultiplier += (weight/3)
	end

	return math.floor(base * finalMultiplier)
end

return module