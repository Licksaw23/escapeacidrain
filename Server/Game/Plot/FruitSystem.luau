-- FruitSystem.luau
-- Centralized fruit system for client-side authority
-- Manages timestamp-based fruit lifecycle

local FruitSystem = {}

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local ItemsData = require(RS.Game.Modules.Libraries.ItemsData)
local PickWeight = require(RS.Game.Modules.Utilities.PickScale)
local PickMutations = require(RS.Game.Modules.Utilities.PickMutations)
local MutationsData = require(RS.Game.Modules.Libraries.MutationsData)

-- Constants
local DEFAULT_FRUIT_RESPAWN_TIME = 17 -- seconds between harvest and new fruit
local DEFAULT_FRUIT_GROWTH_TIME = 4 -- seconds for fruit to grow

-- Helper: Check if fruit is ready for harvest
function FruitSystem.IsFruitReady(fruitData, currentTime)
	if not fruitData or not fruitData.PlantedAt then return false end
	local time = currentTime or workspace:GetServerTimeNow()
	return time >= fruitData.PlantedAt + (fruitData.GrowthDuration or DEFAULT_FRUIT_GROWTH_TIME)
end

-- Helper: Check if fruit is on cooldown (respawning)
function FruitSystem.IsFruitOnCooldown(fruitData, currentTime)
	if not fruitData or not fruitData.HarvestedAt then return false end
	local time = currentTime or workspace:GetServerTimeNow()
	return time < fruitData.HarvestedAt + (fruitData.RespawnTime or DEFAULT_FRUIT_RESPAWN_TIME)
end

-- Helper: Get remaining cooldown time
function FruitSystem.GetCooldownRemaining(fruitData, currentTime)
	if not fruitData or not fruitData.HarvestedAt then return 0 end
	local time = currentTime or workspace:GetServerTimeNow()
	local cooldownEnd = fruitData.HarvestedAt + (fruitData.RespawnTime or DEFAULT_FRUIT_RESPAWN_TIME)
	return math.max(0, cooldownEnd - time)
end

-- Helper: Get time until fruit is ready
function FruitSystem.GetTimeUntilReady(fruitData, currentTime)
	if not fruitData or not fruitData.PlantedAt then return 0 end
	local time = currentTime or workspace:GetServerTimeNow()
	local readyTime = fruitData.PlantedAt + (fruitData.GrowthDuration or DEFAULT_FRUIT_GROWTH_TIME)
	return math.max(0, readyTime - time)
end

-- Generate new fruit data
function FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
	local itemData = ItemsData[productName]
	if not itemData then return nil end

	-- Generate weight
	local weight = PickWeight.RandomizeWeight(itemData.WeightPool)

	-- Generate mutations
	local mutations = {}
	local totalLuck = (playerMutationLuck or 0) + (playerLuck or 0)
	local randomMutation = PickMutations.PickMutation(totalLuck, eventMultipliers or {})
	if randomMutation then
		table.insert(mutations, randomMutation)
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

-- Create initial fruit data for a fully grown plant
function FruitSystem.InitializePlantFruits(plantData, plantModule, player, eventMultipliers)
	local productName = plantModule.ProductName
	if not productName then return {} end

	local playerLuck = player:GetAttribute("Luck") or 0
	local playerMutationLuck = player:GetAttribute("MutationLuck") or 0
	local fruits = {}

	if plantModule.Type == "Single" then
		-- Single plants have one fruit at index "1"
		fruits["1"] = FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
	elseif plantModule.Type == "Spawner" then
		-- Spawner plants: Initialize fruits for each branch (will be set up when branches are known)
		-- This is called later with branch count
	end

	return fruits
end

-- Initialize fruits for a spawner plant with known branch count
function FruitSystem.InitializeSpawnerFruits(plantData, productName, branchCount, player, eventMultipliers)
	local playerLuck = player:GetAttribute("Luck") or 0
	local playerMutationLuck = player:GetAttribute("MutationLuck") or 0
	local fruits = {}

	for i = 1, branchCount do
		fruits[tostring(i)] = FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
	end

	return fruits
end

-- Validate harvest request (server-side validation)
function FruitSystem.ValidateHarvest(plantData, fruitIndex, currentTime)
	if not plantData or not plantData.Fruits then return false end

	local fruitData = plantData.Fruits[tostring(fruitIndex)]
	if not fruitData then return false end

	local time = currentTime or workspace:GetServerTimeNow()

	-- Check if already harvested (on cooldown)
	if fruitData.HarvestedAt then
		local cooldownEnd = fruitData.HarvestedAt + (fruitData.RespawnTime or DEFAULT_FRUIT_RESPAWN_TIME)
		if time < cooldownEnd then
			return false, "On cooldown"
		end
	end

	-- Check if fruit is ready
	if not FruitSystem.IsFruitReady(fruitData, time) then
		return false, "Not ready"
	end

	return true
end

-- Process harvest (server-side)
function FruitSystem.ProcessHarvest(plantData, fruitIndex, currentTime)
	local time = currentTime or workspace:GetServerTimeNow()

	local isValid, errorMsg = FruitSystem.ValidateHarvest(plantData, fruitIndex, time)
	if not isValid then
		return false, errorMsg
	end

	local fruitData = plantData.Fruits[tostring(fruitIndex)]
	if not fruitData then return false, "Fruit not found" end

	-- Mark as harvested
	fruitData.HarvestedAt = time

	-- Return harvest data
	return true, {
		Weight = fruitData.Weight,
		Mutations = fruitData.Mutations,
		Favorited = fruitData.Favorited
	}
end

-- Respawn fruit after cooldown (call this when cooldown is complete)
function FruitSystem.RespawnFruit(plantData, fruitIndex, productName, player, eventMultipliers)
	if not plantData or not plantData.Fruits then return false end

	local fruitData = plantData.Fruits[tostring(fruitIndex)]
	if not fruitData then return false end

	local time = workspace:GetServerTimeNow()

	-- Check if cooldown is complete
	if fruitData.HarvestedAt then
		local cooldownEnd = fruitData.HarvestedAt + (fruitData.RespawnTime or DEFAULT_FRUIT_RESPAWN_TIME)
		if time < cooldownEnd then
			return false, "Still on cooldown"
		end
	end

	-- Generate new fruit data
	local playerLuck = player:GetAttribute("Luck") or 0
	local playerMutationLuck = player:GetAttribute("MutationLuck") or 0
	plantData.Fruits[tostring(fruitIndex)] = FruitSystem.GenerateFruitData(
		productName, 
		playerLuck, 
		playerMutationLuck, 
		eventMultipliers or {}
	)

	return true
end

-- Toggle favorite status
function FruitSystem.ToggleFavorite(plantData, fruitIndex)
	if not plantData or not plantData.Fruits then return false end

	local fruitData = plantData.Fruits[tostring(fruitIndex)]
	if not fruitData then return false end

	fruitData.Favorited = not fruitData.Favorited
	return fruitData.Favorited
end

-- Get fruit data for client sync
function FruitSystem.GetClientFruitData(fruitData)
	if not fruitData then return nil end

	local time = workspace:GetServerTimeNow()

	return {
		PlantedAt = fruitData.PlantedAt,
		GrowthDuration = fruitData.GrowthDuration,
		RespawnTime = fruitData.RespawnTime,
		HarvestedAt = fruitData.HarvestedAt,
		IsReady = FruitSystem.IsFruitReady(fruitData, time),
		IsOnCooldown = FruitSystem.IsFruitOnCooldown(fruitData, time),
		CooldownRemaining = FruitSystem.GetCooldownRemaining(fruitData, time),
		TimeUntilReady = FruitSystem.GetTimeUntilReady(fruitData, time),
		Weight = fruitData.Weight,
		Mutations = fruitData.Mutations,
		Favorited = fruitData.Favorited
	}
end

return FruitSystem
