local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Data = require(game.ReplicatedStorage:WaitForChild("ServerPlayerData"))
local ItemsData = require(game.ReplicatedStorage.Game.Modules.Libraries.ItemsData)

local ServerUtility = require(script.Parent.ServerUtility)
local Plot = require(script.Parent.Plot)
local GlobalStore = require(script.Parent.GlobalStore)
local BitBuffer = require(game.ReplicatedStorage.Game.Modules.Utilities.BitBuffer)


local UIRemote = game.ReplicatedStorage.Remotes.UI

local PurchaseHandler = {}
PurchaseHandler.__index = PurchaseHandler

-- Store for registered product handlers
local registeredProducts = {}

-- Purchase result enums
local PurchaseResult = {
	NotProcessedYet = Enum.ProductPurchaseDecision.NotProcessedYet,
	PurchaseGranted = Enum.ProductPurchaseDecision.PurchaseGranted,
}

-- Error logging
local function logError(context, err, receipt)
	warn(string.format(
		"[PurchaseHandler] Error in %s: %s | PlayerId: %s | ProductId: %s | PurchaseId: %s",
		context,
		tostring(err),
		receipt and receipt.PlayerId or "N/A",
		receipt and receipt.ProductId or "N/A",
		receipt and receipt.PurchaseId or "N/A"
		))
end

-- Success logging
local function logSuccess(receipt)
	print(string.format(
		"[PurchaseHandler] Purchase granted | Player: %s | Product: %d | PurchaseId: %s",
		receipt.PlayerId,
		receipt.ProductId,
		receipt.PurchaseId
		))
end

-- Validate receipt structure
local function validateReceipt(receipt)
	if type(receipt) ~= "table" then
		return false, "Receipt is not a table"
	end

	if not receipt.PlayerId then
		return false, "Receipt missing PlayerId"
	end

	if not receipt.ProductId then
		return false, "Receipt missing ProductId"
	end

	if not receipt.PurchaseId then
		return false, "Receipt missing PurchaseId"
	end

	if type(receipt.PlayerId) ~= "number" then
		return false, "PlayerId is not a number"
	end

	if type(receipt.ProductId) ~= "number" then
		return false, "ProductId is not a number"
	end

	return true, nil
end

-- Get player from receipt with error checking
local function getPlayerFromReceipt(receipt)
	local success, player = pcall(function()
		return Players:GetPlayerByUserId(receipt.PlayerId)
	end)

	if not success then
		return nil, "Failed to get player: " .. tostring(player)
	end

	if not player then
		return nil, "Player not found in game (may have left)"
	end

	return player, nil
end

-- Core receipt processing function
local function processReceipt(receipt)
	-- Validate receipt structure
	local isValid, validationError = validateReceipt(receipt)
	if not isValid then
		logError("Receipt Validation", validationError, receipt)
		return PurchaseResult.NotProcessedYet
	end

	-- Get the player
	local player, playerError = getPlayerFromReceipt(receipt)
	if not player then
		logError("Player Retrieval", playerError, receipt)
		return PurchaseResult.NotProcessedYet
	end

	-- Check if product is registered
	local productHandler = registeredProducts[receipt.ProductId]
	if not productHandler then
		logError("Product Registration", "Product not registered", receipt)
		return PurchaseResult.NotProcessedYet
	end

	-- Execute the product handler with error protection
	local handlerSuccess, handlerResult = pcall(function()
		-- HIGH FIX: Added player validity checks after yield operations (Issue #8)
		local timeout = 0
		repeat 
			task.wait(0.1)
			timeout += 0.1
			-- Check if player is still in game
			if not player.Parent then
				warn("[PurchaseHandler] Player left during data loading")
				return false
			end
		until Data[player] or timeout > 10
		
		if not Data[player] then
			warn("[PurchaseHandler] Data timeout for player: " .. player.Name)
			return false
		end
		
		local PlayerReplica = Data[player]
		timeout = 0
		repeat 
			task.wait(0.1)
			timeout += 0.1
			if not player.Parent then
				warn("[PurchaseHandler] Player left during replica data loading")
				return false
			end
		until PlayerReplica.Data or timeout > 10
		
		if not PlayerReplica.Data then
			warn("[PurchaseHandler] Replica data timeout for player: " .. player.Name)
			return false
		end
		
		if not PlayerReplica.Data.Purchases[receipt.ProductId] then
			PlayerReplica:SetValue({"Purchases", receipt.ProductId}, 0)
		end

		PlayerReplica:SetValue({"Purchases", receipt.ProductId}, PlayerReplica.Data.Purchases[receipt.ProductId] + 1)

		local getPlot

		for p, pData in Plot.Plots do if pData.Owner == player then getPlot = pData end end

		if getPlot then
			return productHandler(receipt, player, PlayerReplica, getPlot)
		end
	end)

	if not handlerSuccess then
		logError("Handler Execution", handlerResult, receipt)
		return PurchaseResult.NotProcessedYet
	end

	-- Validate handler return value
	if type(handlerResult) ~= "boolean" then
		logError("Handler Return", "Handler must return boolean, got " .. type(handlerResult), receipt)
		return PurchaseResult.NotProcessedYet
	end

	-- Check if handler successfully granted the purchase
	if handlerResult == true then
		logSuccess(receipt)
		return PurchaseResult.PurchaseGranted
	else
		logError("Handler Result", "Handler returned false (purchase not granted)", receipt)
		return PurchaseResult.NotProcessedYet
	end
end

--[[
	Register a product handler
	
	@param productId: number - The developer product ID
	@param handler: function(receipt, player) -> boolean
		- receipt: The purchase receipt
		- player: The Player instance
		- Returns: true if purchase granted successfully, false otherwise
]]
function PurchaseHandler:RegisterProduct(productId, handler)
	assert(type(productId) == "number", "ProductId must be a number")
	assert(type(handler) == "function", "Handler must be a function")

	if registeredProducts[productId] then
	
	end

	registeredProducts[productId] = handler

end

--[[
	Unregister a product handler
	
	@param productId: number - The developer product ID
]]
function PurchaseHandler:UnregisterProduct(productId)
	assert(type(productId) == "number", "ProductId must be a number")

	if registeredProducts[productId] then
		registeredProducts[productId] = nil
	
	else

	end
end

--[[
	Check if a product is registered
	
	@param productId: number - The developer product ID
	@return boolean
]]
function PurchaseHandler:IsProductRegistered(productId)
	return registeredProducts[productId] ~= nil
end

--[[
	Initialize the purchase handler
	Call this once when your game starts
]]
function PurchaseHandler:Initialize()
	local success, err = pcall(function()
		MarketplaceService.ProcessReceipt = processReceipt
	end)

	if success then
	--	print("[PurchaseHandler] Initialized successfully")
	else
		error("[PurchaseHandler] Failed to initialize: " .. tostring(err))
	end
end

--[[
	Prompt a purchase with error handling
	
	@param player: Player - The player to prompt
	@param productId: number - The product ID to purchase
	@return success: boolean, errorMessage: string?
]]
function PurchaseHandler:PromptPurchase(player, productId)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "First argument must be a Player")
	assert(type(productId) == "number", "ProductId must be a number")

	if not self:IsProductRegistered(productId) then
		warn(string.format("[PurchaseHandler] Warning: Product %d is not registered", productId))
	end

	local success, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)

	if not success then
		local errorMsg = string.format("Failed to prompt purchase: %s", tostring(err))
		warn("[PurchaseHandler] " .. errorMsg)
		return false, errorMsg
	end

	return true, nil
end

-- functions --

PurchaseHandler:RegisterProduct(3496358822, function(receipt, player, PlayerReplica, getPlot) -- HARVEST ALL --
	local getPlantsFolder = workspace.Plots[player:GetAttribute("Plot")].Plants
	
	for _, plant in getPlantsFolder:GetDescendants() do
		if plant:GetAttribute("ReadyToHarvest") then
			ServerUtility.ActiveFruit[plant:GetAttribute("PlantID")..plant:GetAttribute("DataIndex")](player)
		end
	end
	
	return true
end)

PurchaseHandler:RegisterProduct(3505949338, function(receipt, player, PlayerReplica, getPlot) -- RESTOCK STORE --
	Plot.RestockPlayerStore(player, "Seed")
	
	return true
end)

PurchaseHandler:RegisterProduct(3514757584, function(receipt, player, PlayerReplica, getPlot) -- RESTOCK GEAR STORE --
	Plot.RestockPlayerStore(player, "Gear")

	return true
end)

PurchaseHandler:RegisterProduct(3496357750, function(receipt, player, PlayerReplica, getPlot) -- GROW ALL --
	-- Force update all active plants for this player immediately
	for i, plantEntry in ipairs(Plot.ActivePlants) do
		if plantEntry.player == player then
			-- Get the plant module
			local plantModule = plantEntry.module

			-- Set the plant's PlacedTick attribute to the past (instantly grown)
			local newTimePlaced = workspace:GetServerTimeNow() - plantModule.GrowthTime - 1
			plantEntry.plant:SetAttribute("PlacedTick", newTimePlaced)

			-- Update the data as well
			local BufferedTime = BitBuffer.Create()
			BufferedTime:WriteFloat64(newTimePlaced)
			PlayerReplica:SetValue({"Plot", plantEntry.plantID, "TimePlaced"}, BufferedTime:ToBase64())

			-- Force growth to 100% and update to stage 4
			plantEntry.currentStage = 4
			plantModule.UpdateGrowth(
				plantEntry.plant,
				1, -- 100% growth
				plantEntry.currentStage
			)

			-- Make plant fully visible
			for _, desc in plantEntry.plant:GetDescendants() do
				if desc:IsA("Part") and desc.Name ~= "MUTATIONVFX" then
					desc.Transparency = 0
				end
			end

			-- Spawn fruits immediately if not already spawned
			if not plantEntry.fruitsSpawned then
				plantEntry.fruitsSpawned = true

				if plantModule.Type == "Spawner" then
					local branches = plantModule.GetBranches(plantEntry.plant)
					for _, branch in branches do
						task.spawn(function()
							plantModule.SpawnFruit(
								plantEntry.player,
								plantEntry.plant,
								branch,
								plantEntry.plantID,
								branch.Index,
								plantEntry.PlayerData,
								plantEntry.ServerUtility,
								plantEntry.Plot
							)
						end)
					end
				elseif plantModule.Type == "Single" then
					task.spawn(function()
						plantModule.SpawnFruit(
							plantEntry.player,
							plantEntry.plant,
							nil,
							plantEntry.plantID,
							"1",
							plantEntry.PlayerData,
							plantEntry.ServerUtility,
							plantEntry.Plot
						)
					end)
				end
			end
		end
	end

	return true
end)

for rarity, ID in Plot.AutoCompletes do -- AUTO FINISH ORDER FOR ___ RARITY --
	PurchaseHandler:RegisterProduct(ID, function(receipt, player, PlayerReplica, getPlot)
		local getOrder = getPlot.CurrentOrder[player:GetAttribute("CompletedPurchaseData")]
		
		if getOrder then
			-- make sure the rarity of the order is the one being purchased --
			local brainrotModel = game.ReplicatedStorage.Game.Models.Brainrot3D[getOrder.Brainrot]
			
			if Plot.AutoCompletes[brainrotModel:GetAttribute("Rarity")] == ID then
				getPlot.Functions["CompleteOrder"](player:GetAttribute("CompletedPurchaseData"), true)
			end
		end
		
		return true
	end)
end

for seed, seedInfo in ItemsData do
	if seedInfo.Type == "Plant" and seedInfo.PurchaseID then
		PurchaseHandler:RegisterProduct(seedInfo.PurchaseID, function(receipt, player, PlayerReplica, getPlot)
			getPlot:GiveItem({
				["ID"] = HttpService:GenerateGUID(false);
				["Name"] = seed;
				["Quantity"] = 1;
			})
			
			return true
		end)
	end
end

PurchaseHandler:RegisterProduct(3508132587, function(receipt, player, PlayerReplica, getPlot) -- 2x brainrot potion 30m --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Brainrot Potion";
	})

	return true
end)

PurchaseHandler:RegisterProduct(3508132904, function(receipt, player, PlayerReplica, getPlot) -- 2x mutation potion 30m --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Mutation Potion";
	})
	
	return true
end)

PurchaseHandler:RegisterProduct(3509152440, function(receipt, player, PlayerReplica, getPlot) -- 2x size potion 30m --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Size Potion";
	})

	return true
end)

PurchaseHandler:RegisterProduct(3508132720, function(receipt, player, PlayerReplica, getPlot) -- 2x speed potion 30m --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Speed Potion";
	})

	return true
end)

PurchaseHandler:RegisterProduct(3509152880, function(receipt, player, PlayerReplica, getPlot) -- sigma potion 30m --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Sigma Potion";
	})

	return true
end)

PurchaseHandler:RegisterProduct(3508132305, function(receipt, player, PlayerReplica, getPlot) -- 2x server luck 15m --
	Plot.GiveServerLuck(2, "Luck", 15 * 60, nil, true)
	
	return true
end)

PurchaseHandler:RegisterProduct(3508132395, function(receipt, player, PlayerReplica, getPlot) -- starter pack --
	local boostID = HttpService:GenerateGUID(false)

	if tick() > PlayerReplica.Data.FirstJoin + 36400 then warn("Passed day limit- Not doing.") return true end

	-- cash --
	getPlot:GiveCash(10000)
	
	-- freeze ray -- [[ UNCOMMENT WHEN THIS GEAR GETS ADDED. ]] 
	
	--getPlot:GiveItem({
	--	["ID"] = HttpService:GenerateGUID(false);
	--	["Name"] = "Freeze Ray";
	--	["Quantity"] = 1;
	--})
	
	-- apple tree seed --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Red Apple Seed";
		["Quantity"] = 1;
	})
	
	-- brainrot potion --
	getPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = "Brainrot Potion";
	})
	

	return true
end)


PurchaseHandler:Initialize()

return PurchaseHandler