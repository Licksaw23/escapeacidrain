-- ServerUtility.luau
-- Server-side utilities for fruit system with client-side authority

local Utility = {}

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Modules = RS.Game.Modules
local Remotes = RS.Remotes

local Libraries = Modules.Libraries
local Utilities = Modules.Utilities

local UpdateRemote = Remotes.Update
local SpawnRemote = Remotes.Spawn
local FXRemote = Remotes.FX
local UIRemote = Remotes.UI
local PlotRemote = Remotes.Plot

local Brainrots = require(Libraries.BrainrotsData)
local BezierPath = require(Utilities.BezierPath)
local Mutations = require(Libraries.MutationsData)
local PickMutations = require(Utilities.PickMutations)
local PickWeight = require(Utilities.PickScale)
local Items = require(Libraries.ItemsData)
local FruitSystem = require(game.ServerScriptService.Server.Game.Plot.FruitSystem)

local BrainrotModels = RS.Game.Models.Brainrot3D
local PlayerReplica = require(RS:WaitForChild("ServerPlayerData"))

local BrainrotsByRarity = {["Rare"] = {}; ["Epic"] = {}; ["Legendary"] = {}; ["Mythic"] = {}; ["Godly"] = {}; ["Secret"] = {};}

for _, mdl in BrainrotModels:GetChildren() do
	if mdl:IsA("Model") and mdl:GetAttribute("Rarity") then
		table.insert(BrainrotsByRarity[mdl:GetAttribute("Rarity")], mdl.Name)
	end
end

Utility.PickBrainrotOnRarity = function(rarity)
	return BrainrotsByRarity[rarity][math.random(1, #BrainrotsByRarity[rarity])]
end

Utility.PickLowestNumberedArray = function(array, blacklist)
	local chosenArray; local chosenArrayCount

	for i,v in array do
		if chosenArray == nil and not blacklist[i] then
			chosenArray = i; chosenArrayCount = #v;
		else
			if #v <= chosenArrayCount and not blacklist[i] then
				chosenArray = i; chosenArrayCount = #v;
			end
		end
	end

	return chosenArray
end 

Utility.ManuallyNumberArray = function(array)
	local count = 0

	for i, v in array do
		if v ~= nil then
			count += 1 
		end
	end

	return count
end

Utility.GetExactBoundingBox = function(model)
	if model:IsA("Model") then
		local minBounds = Vector3.new(1, 1, 1) * (1 / 0)
		local maxBounds = -minBounds
		local descendants = model:GetDescendants()
		if #descendants ~= 0 then
			for _, descendant in descendants do
				if descendant:IsA("BasePart") then
					local partCFrame = descendant.CFrame
					local partSize = descendant.Size
					local halfWidth = partSize.X / 2
					local halfHeight = partSize.Y / 2
					local halfDepth = partSize.Z / 2
					local negHalfWidth = -halfWidth
					local negHalfHeight = -halfHeight
					local negHalfDepth = -halfDepth
					for _, cornerPosition in {
						partCFrame * Vector3.new(negHalfWidth, negHalfHeight, negHalfDepth),
						partCFrame * Vector3.new(halfWidth, negHalfHeight, negHalfDepth),
						partCFrame * Vector3.new(negHalfWidth, halfHeight, negHalfDepth),
						partCFrame * Vector3.new(halfWidth, halfHeight, negHalfDepth),
						partCFrame * Vector3.new(negHalfWidth, negHalfHeight, halfDepth),
						partCFrame * Vector3.new(halfWidth, negHalfHeight, halfDepth),
						partCFrame * Vector3.new(negHalfWidth, halfHeight, halfDepth),
						partCFrame * Vector3.new(halfWidth, halfHeight, halfDepth)
						} do
						local minX = minBounds.X
						local cornerX = cornerPosition.X
						local newMinX = math.min(minX, cornerX)
						local minY = minBounds.Y
						local cornerY = cornerPosition.Y
						local newMinY = math.min(minY, cornerY)
						local minZ = minBounds.Z
						local cornerZ = cornerPosition.Z
						local newMinZ = math.min(minZ, cornerZ)
						minBounds = Vector3.new(newMinX, newMinY, newMinZ)
						local maxX = maxBounds.X
						local cornerX2 = cornerPosition.X
						local newMaxX = math.max(maxX, cornerX2)
						local maxY = maxBounds.Y
						local cornerY2 = cornerPosition.Y
						local newMaxY = math.max(maxY, cornerY2)
						local maxZ = maxBounds.Z
						local cornerZ2 = cornerPosition.Z
						local newMaxZ = math.max(maxZ, cornerZ2)
						maxBounds = Vector3.new(newMaxX, newMaxY, newMaxZ)
					end
				end
			end
			return {
				["Position"] = (minBounds + maxBounds) / 2,
				["Size"] = maxBounds - minBounds
			}
		end
	else
		warn("Expected a Model, got:", model)
	end
end

Utility.FireWhenLoaded = function(remote, clients, call, info)
	for _, client in clients do
		task.spawn(function()
			repeat wait() until client.Character ~= nil

			remote:FireClient(client,call,info)
		end)
	end
end

-- ============================================================================
-- FRUIT SYSTEM - Data-only, client-side authority
-- ============================================================================

-- Active fruit handlers (keyed by plantID..fruitIndex)
Utility.ActiveFruit = {}

-- Generate fruit data (replaces instance-based fruit creation)
function Utility.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
	return FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
end

-- Check if fruit is ready for harvest
function Utility.IsFruitReady(fruitData, currentTime)
	return FruitSystem.IsFruitReady(fruitData, currentTime)
end

-- Check if fruit is on cooldown
function Utility.IsFruitOnCooldown(fruitData, currentTime)
	return FruitSystem.IsFruitOnCooldown(fruitData, currentTime)
end

-- Get remaining cooldown time
function Utility.GetCooldownRemaining(fruitData, currentTime)
	return FruitSystem.GetCooldownRemaining(fruitData, currentTime)
end

-- Get client-safe fruit data
function Utility.GetClientFruitData(fruitData)
	return FruitSystem.GetClientFruitData(fruitData)
end

-- Setup fruit for a plant (DATA-ONLY, no instance creation)
-- This now creates data-only entries, no physical models
Utility.SetupFruit = function(player, plantID, dataIndex, PlayerData, Plot, productName, plantModule)
	if not PlayerData or not PlayerData.Data then
		warn("[SetupFruit] No PlayerData provided")
		return nil
	end

	local ActualData = PlayerData.Data
	local plantData = ActualData.Plot[plantID]

	if not plantData then
		warn("[SetupFruit] Plant not found:", plantID)
		return nil
	end

	-- Ensure Fruits table exists
	if not plantData.Fruits then
		plantData.Fruits = {}
	end

	-- Check if fruit data already exists
	local fruitData = plantData.Fruits[tostring(dataIndex)]

	if not fruitData then
		-- Generate new fruit data using FruitSystem
		local playerLuck = player:GetAttribute("Luck") or 0
		local playerMutationLuck = player:GetAttribute("MutationLuck") or 0
		local eventMultipliers = Plot.EventMultipliers or {}

		fruitData = FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
		plantData.Fruits[tostring(dataIndex)] = fruitData

		-- Save to replica
		PlayerData:SetValue({"Plot", plantID, "Fruits", tostring(dataIndex)}, fruitData)
	end

	-- Create the handler for this fruit
	local fruitKey = plantID .. tostring(dataIndex)

	Utility.ActiveFruit[fruitKey] = function(user, call, info)
		if call == nil then
			-- Harvest request - delegate to plot's harvest function
			local userPlot = nil
			local PlotModule = require(script.Parent.Plot)
			for _, p in ipairs(PlotModule.Plots) do
				if p.Owner == user then
					userPlot = p
					break
				end
			end
			
			if userPlot then
				return userPlot:RequestFruitHarvest(plantID, dataIndex)
			end
			return false, "Plot not found"
		elseif call == "UpdateFavorited" then
			-- Update favorite status
			local newStatus = not fruitData.Favorited
			fruitData.Favorited = newStatus
			PlayerData:SetValue({"Plot", plantID, "Fruits", tostring(dataIndex), "Favorited"}, newStatus)
			return newStatus
		elseif call == "GetData" then
			-- Return current fruit data for client
			return FruitSystem.GetClientFruitData(fruitData)
		end
	end

	-- Notify client that fruit is available
	SpawnRemote:FireClient(player, "FruitDataUpdate", {
		PlantID = plantID,
		FruitIndex = dataIndex,
		FruitData = FruitSystem.GetClientFruitData(fruitData)
	})

	return fruitKey
end

-- Handle fruit harvest request
Utility.HarvestFruit = function(player, plantID, fruitIndex, PlayerData, Plot, productName, plantModule)
	local plantData = PlayerData.Data.Plot[plantID]
	if not plantData then return false, "Plant not found" end

	-- Validate harvest using FruitSystem
	local isValid, errorMsg = FruitSystem.ValidateHarvest(plantData, fruitIndex)
	if not isValid then
		return false, errorMsg
	end

	-- Check inventory space
	local TotalInventorySize = 250
	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1657482065) then
		TotalInventorySize = 400
	end

	local GetInventoryCount = 0
	for _ in pairs(PlayerData.Data.Inventory) do
		GetInventoryCount += 1
	end

	if GetInventoryCount >= TotalInventorySize then
		UIRemote:FireClient(player, "TopNotification", {
			Text = "Your inventory is full! (" .. GetInventoryCount .. "/" .. TotalInventorySize .. ")",
			Duration = 3,
			ShadowColor = Color3.fromRGB(241, 0, 0),
			ShadowTransparency = 0.35,
		})
		return false, "Inventory full"
	end

	-- Get fruit data before harvesting
	local fruitData = plantData.Fruits[tostring(fruitIndex)]
	if not fruitData then return false, "Fruit data not found" end

	-- Process harvest
	local success, result = FruitSystem.ProcessHarvest(plantData, fruitIndex)
	if not success then
		return false, result
	end

	-- Play pickup sound
	FXRemote:FireClient(player, "Replicate", {
		Call = "Sound",
		Sound = RS.Game.Sounds.GameSounds.pickup
	})

	-- Give item to player
	Plot:GiveItem({
		ID = HttpService:GenerateGUID(false),
		Name = productName,
		Weight = result.Weight,
		Mutations = result.Mutations
	})

	-- Update replica with harvested state
	PlayerData:SetValue({"Plot", plantID, "Fruits", tostring(fruitIndex), "HarvestedAt"}, plantData.Fruits[tostring(fruitIndex)].HarvestedAt)

	-- Schedule respawn
	task.delay(FruitSystem.GetCooldownRemaining(plantData.Fruits[tostring(fruitIndex)]) + 0.1, function()
		local respawnSuccess = FruitSystem.RespawnFruit(
			plantData,
			fruitIndex,
			productName,
			player,
			Plot.EventMultipliers or {}
		)

		if respawnSuccess then
			-- Update replica with new fruit data
			PlayerData:SetValue({"Plot", plantID, "Fruits", tostring(fruitIndex)}, plantData.Fruits[tostring(fruitIndex)])

			-- Notify client
			SpawnRemote:FireClient(player, "FruitDataUpdate", {
				PlantID = plantID,
				FruitIndex = fruitIndex,
				FruitData = FruitSystem.GetClientFruitData(plantData.Fruits[tostring(fruitIndex)])
			})
		end
	end)

	return true
end

-- Initialize all fruits for a fully grown plant (DATA-ONLY)
Utility.InitializePlantFruits = function(player, plant, plantID, plantModule, PlayerData, Plot)
	local ActualData = PlayerData.Data
	local plantData = ActualData.Plot[plantID]

	if not plantData then return end

	local productName = plantModule.ProductName
	if not productName then return end

	-- Ensure Fruits table exists
	if not plantData.Fruits then
		plantData.Fruits = {}
	end

	if plantModule.Type == "Single" then
		-- Single plants: one fruit at index "1"
		if not plantData.Fruits["1"] then
			local playerLuck = player:GetAttribute("Luck") or 0
			local playerMutationLuck = player:GetAttribute("MutationLuck") or 0
			local eventMultipliers = Plot.EventMultipliers or {}

			plantData.Fruits["1"] = FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
			PlayerData:SetValue({"Plot", plantID, "Fruits", "1"}, plantData.Fruits["1"])
		end

		-- Setup the fruit handler
		Utility.SetupFruit(player, plantID, "1", PlayerData, Plot, productName, plantModule)

	elseif plantModule.Type == "Spawner" then
		-- Spawner plants: fruits for each branch
		-- Get branch count from the plant instance (passed from client or stored)
		local branches = plantModule.GetBranches and plantModule.GetBranches(plant) or {}

		for _, branch in ipairs(branches) do
			local branchIndex = tostring(branch.Index)

			-- Generate fruit data if not exists
			if not plantData.Fruits[branchIndex] then
				local playerLuck = player:GetAttribute("Luck") or 0
				local playerMutationLuck = player:GetAttribute("MutationLuck") or 0
				local eventMultipliers = Plot.EventMultipliers or {}

				plantData.Fruits[branchIndex] = FruitSystem.GenerateFruitData(productName, playerLuck, playerMutationLuck, eventMultipliers)
				PlayerData:SetValue({"Plot", plantID, "Fruits", branchIndex}, plantData.Fruits[branchIndex])
			end

			-- Setup the fruit handler
			Utility.SetupFruit(player, plantID, branch.Index, PlayerData, Plot, productName, plantModule)
		end
	end

	-- Notify client of all fruit data
	local clientFruitData = {}
	for index, fruitData in pairs(plantData.Fruits) do
		clientFruitData[index] = FruitSystem.GetClientFruitData(fruitData)
	end

	SpawnRemote:FireClient(player, "PlantFruitsInitialized", {
		PlantID = plantID,
		Fruits = clientFruitData
	})
end

-- ============================================================================
-- LEGACY COMPATIBILITY
-- ============================================================================

-- Legacy compatibility: HandleDestroy
Utility.HandleDestroy = function(info)
	local ID = info.ID
	local Plot = info.Plot
	local Model = info.Model

	if ID and Plot then
		if Model then
			local findIndex = table.find(Utility.Mutations, Model)
			local findIndex2 = table.find(Utility.Scales, Model)

			if findIndex then
				table.remove(Utility.Mutations, findIndex)
			end

			if findIndex2 then
				table.remove(Utility.Scales, findIndex2)
			end
		end

		local CustomerSpawns = Utility.CustomerSpawns[Plot]
		local Spawns = Utility.Spawns[Plot]

		if CustomerSpawns then
			local findRotIndex1 = table.find(CustomerSpawns, ID)

			if findRotIndex1 then
				table.remove(CustomerSpawns, findRotIndex1)
			end
		end

		if Spawns then
			local findRotIndex2 = table.find(Spawns, ID)

			if findRotIndex2 then
				table.remove(CustomerSpawns, findRotIndex2)
			end
		end
	end
end

Utility.Mutations = {}
Utility.Scales = {}
Utility.Spawns = {}
Utility.CustomerSpawns = {}

Utility.ClientSpawnCustomerBrainrot = function(ID, cache, plotNumber, orderData, user)
	if not Utility.CustomerSpawns[plotNumber] then
		Utility.CustomerSpawns[plotNumber] = {}
	end

	if not table.find(Utility.CustomerSpawns[plotNumber], ID) then
		table.insert(Utility.CustomerSpawns[plotNumber], ID)
	end
	cache["Plot"] = plotNumber

	if not orderData then
		-- basic spawn --
		if user then SpawnRemote:FireClient(user, "SpawnBrainrot", cache) else SpawnRemote:FireAllClients("SpawnBrainrot", cache) end
	else
		-- at the desk, so spawn them with the currently loaded order data --
		if user then
			SpawnRemote:FireClient(user, "SpawnBrainrot", {
				["Data"] = cache;
				["OrderData"] = orderData;
			})
		else
			SpawnRemote:FireAllClients("SpawnBrainrot", {
				["Data"] = cache;
				["OrderData"] = orderData;
			})
		end
	end
end

Utility.ClientSpawnPlatformBrainrot = function(ID, cache, plotNumber, Owner)
	if not Utility.Spawns[plotNumber] then
		Utility.Spawns[plotNumber] = {}
	end

	table.insert(Utility.Spawns[plotNumber], ID)

	cache["Plot"] = plotNumber

	cache["Owner"] = Owner
	SpawnRemote:FireAllClients("SpawnPlatformBrainrot", cache)
end

Utility.ClientMutate = function(mutation, model)
	if not Utility.Mutations[model] then
		Utility.Mutations[model] = {}
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

Utility.ClientScale = function(scale, model)
	Utility.Scales[model] = scale;

	if model:IsA("Tool") then
		model = model:FindFirstChildOfClass("Model")
	end

	FXRemote:FireAllClients("Replicate",{
		["Call"] = "Scale";

		["Array"] = {
			[1] = {
				Model = model;
				Scale = scale;
			};
		};
	})
end

Utility.CustomMovement = function(array, callback)
	local MovementDuration = array.MovementDuration or 5
	local UpdateInterval = array.UpdateInterval or 0.5
	local Model = array.Model
	local Positions = array.Positions
	local Line = array.Line
	if not Model or not Positions or #Positions < 2 then return end

	-- Create initial path
	local Path = BezierPath.new(Positions, 1)

	-- Store movement data
	Utility.ActiveMovements[Model] = {
		currentTarget = Positions[2];
		PositionData = Positions;
		Path = Path;
		MovementDuration = MovementDuration;
	}

	-- Notify clients that a new movement starts
	UpdateRemote:FireAllClients("start", Model, Utility.ActiveMovements[Model].PositionData[1], Utility.ActiveMovements[Model].PositionData[2], Line, MovementDuration, Utility.ActiveMovements[Model])

	task.spawn(function()
		local startClock = os.clock()
		local lastTarget = Utility.ActiveMovements[Model].PositionData[2]
		local updateCounter = 0

		while true do
			-- Get current movement data from the dictionary
			local MovementData = Utility.ActiveMovements[Model]
			if not MovementData then break end

			local elapsed = os.clock() - startClock
			local t = elapsed / MovementData.MovementDuration

			if t >= 1 then break end

			-- Check if target position has changed
			if lastTarget ~= MovementData.PositionData[2] then

				-- Get current position
				local currentPos = array.Self.Active[array.ID] and array.Self.Active[array.ID].Position or MovementData.PositionData[1]

				-- Update positions array with current position as start
				MovementData.PositionData[1] = currentPos

				MovementData.Path = BezierPath.new(MovementData.PositionData, 1)

				-- Reset timer to create smooth transition
				startClock = os.clock()
				lastTarget = MovementData.PositionData[2]

				-- Notify clients of path change
				UpdateRemote:FireAllClients("start", Model, currentPos, MovementData.PositionData[2], Line, MovementData.MovementDuration, MovementData)
			end

			-- Calculate position along path (for tracking purposes only)
			local cframe = MovementData.Path:CalculateUniformCFrame(math.clamp(t, 0, 1))

			if array.Self.Active[array.ID] then
				array.Self.Active[array.ID].Position = cframe.Position
			end

			task.wait(UpdateInterval)
		end

		-- Movement finished
		local storepositioncauseitsgoated = Utility.ActiveMovements[Model].PositionData[2]
		Utility.ActiveMovements[Model] = nil
		if callback then callback(storepositioncauseitsgoated) end
	end)
end

return Utility
