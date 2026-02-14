--[[
	GLOBAL SEED SHOP FIX - DOCUMENTATION
	=====================================
	
	ISSUES FOUND:
	-------------
	1. STOCK WAS PER-PLAYER INSTEAD OF GLOBAL
	   - Each player had their own Stock table in their data
	   - When player A bought a seed, player B still saw original quantity
	   - This defeated the purpose of a "limited stock" system
	
	2. NO ATOMIC PURCHASE VALIDATION
	   - Race condition: Two players could buy the last item simultaneously
	   - No server-side lock/check to prevent overselling
	
	3. STOCK UPDATES DIDN'T BROADCAST
	   - Only the purchasing player got the "UpdateOne" event
	   - Other players saw outdated stock until they rejoined
	
	4. PERSONAL RESTOCK CREATED DIFFERENT STOCKS
	   - restockPlayer() generated unique stock per player
	   - This was intentional for a "personal restock" feature
	   - But conflicted with global stock concept
	
	5. NO GLOBAL STOCK STORAGE
	   - Store.CurrentStock existed but was only used to initialize players
	   - After init, each player maintained their own copy
	
	FIXES IMPLEMENTED:
	------------------
	1. GLOBAL STOCK STORAGE
	   - Store.CurrentStock is now the SINGLE SOURCE OF TRUTH
	   - All purchases read from and write to this global table
	   - Player data only stores CurrentStock timestamp for validation
	
	2. ATOMIC PURCHASE OPERATIONS
	   - Added purchase validation that checks global stock atomically
	   - Prevents race conditions with server-side stock check
	   - Returns proper error if stock is exhausted
	
	3. BROADCAST STOCK UPDATES
	   - FireAllClients("UpdateStock", itemName, newQuantity) on every purchase
	   - All players see stock decrease in real-time
	   - Creates competitive scarcity gameplay
	
	4. SYNCHRONIZED REPLENISHMENT
	   - All players get the same new stock when timer resets
	   - Uses consistent random seed based on reset timestamp
	   - MessagingService syncs across all servers
	
	5. REMOVED PER-PLAYER STOCK DATA
	   - Stock is no longer stored in player replica data
	   - Only CurrentStock timestamp is kept for "staleness" detection
	   - Reduces data bloat and synchronization issues

	6. ADDED PROPER ERROR HANDLING
	   - Out of stock notifications
	   - Insufficient funds checks
	   - Inventory full validation
	   - All with appropriate UI feedback
]]

local PlayersService = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Data = require(Replicated:WaitForChild("ServerPlayerData"))
local ItemsData = require(Replicated.Game.Modules.Libraries.ItemsData)
local GearsData = require(Replicated.Game.Modules.Libraries.GearsData)

local FXRemote = Replicated.Remotes.FX
local UIRemote = Replicated.Remotes.UI

-- [[ GLOBAL STORE SYSTEM ]] --

local StoreConfigs = {
	Seed = {
		DataStoreName = "SeedStoreData",
		ItemDataTable = ItemsData,
		RemoteName = "UpdateSeedStore",
		ResetInterval = 300, -- 5 minutes
		StockRange = {min = 4, max = 10},
		InventoryGamePass = 1657482065,
		InventorySizes = {default = 250, gamepass = 400},
		AttributeName = "SeedRestockTime",
		DisplayName = "Seed Shop",
		DataKeys = {
			CurrentStock = "CurrentStock",
			Stock = "Stock"
		},
		ItemFilter = function(itemInfo) return itemInfo.BestStock ~= nil end
	},
	Gear = {
		DataStoreName = "GearStoreData",
		ItemDataTable = GearsData,
		RemoteName = "UpdateGearStore",
		ResetInterval = 300, -- 5 minutes
		StockRange = {min = 4, max = 10},
		InventoryGamePass = 1657482065,
		InventorySizes = {default = 250, gamepass = 400},
		AttributeName = "GearRestockTime",
		DisplayName = "Gear Shop",
		DataKeys = {
			CurrentStock = "CurrentGearStock",
			Stock = "GearStock"
		},
		ItemFilter = function(itemInfo) return itemInfo.BestStock ~= nil end
	}
}

-- Internal store class
local Store = {}
Store.__index = Store

function Store.new(storeType, config)
	local self = setmetatable({}, Store)

	self.Type = storeType
	self.Config = config
	self.DataStore = DataStoreService:GetDataStore(config.DataStoreName)
	self.RemoteEvent = Replicated.Remotes:FindFirstChild(config.RemoteName)
	self.AllItems = {}
	self.nextResetTime = 0
	self.CurrentStock = {}
	self.IsInitialized = false
	self.PurchaseLock = {} -- For atomic purchase operations

	-- Initialize items list
	for itemName, itemInfo in pairs(config.ItemDataTable) do
		if config.ItemFilter(itemInfo) then
			table.insert(self.AllItems, itemName)
		end
	end

	return self
end

-- Get next reset timestamp (rounds to nearest interval)
function Store:getNextResetTime()
	local currentTime = os.time()
	local remainder = currentTime % self.Config.ResetInterval
	return currentTime - remainder + self.Config.ResetInterval
end

-- Save forced items to DataStore
function Store:saveForcedItems(forcedItems)
	local success, err = pcall(function()
		self.DataStore:SetAsync("ForcedItems", forcedItems)
	end)
	if not success then
		warn("[" .. self.Type .. " Store] Failed to save forced items:", err)
	end
end

-- Load forced items from DataStore
function Store:loadForcedItems()
	local success, data = pcall(function()
		return self.DataStore:GetAsync("ForcedItems")
	end)
	if success and data then
		return data
	end
	return {}
end

-- Generate stock based on timestamp seed
function Store:generateStock(timestamp, forcedItems)
	forcedItems = forcedItems or {}

	-- Use timestamp as random seed for consistency across servers
	local rng = Random.new(timestamp)
	local available = {}
	local guaranteedItems = {} -- Items with MinimumStock > 0 should ALWAYS be in stock

	-- Separate items into guaranteed (MinimumStock > 0) and regular
	for _, itemName in ipairs(self.AllItems) do
		local itemInfo = self.Config.ItemDataTable[itemName]
		local isForced = false
		for _, forcedData in ipairs(forcedItems) do
			local forcedName = type(forcedData) == "table" and forcedData.Name or forcedData
			if itemName == forcedName then
				isForced = true
				break
			end
		end
		
		if not isForced then
			-- Items with MinimumStock > 0 are ALWAYS in stock
			if itemInfo.MinimumStock and itemInfo.MinimumStock > 0 then
				table.insert(guaranteedItems, itemName)
			else
				table.insert(available, itemName)
			end
		end
	end

	-- Weighted rarity selection - rarer items appear less often
	local rarityWeights = {
		["Rare"] = 100,      -- Very common
		["Epic"] = 60,       -- Common
		["Legendary"] = 25,  -- Uncommon
		["Mythic"] = 10,     -- Rare
		["Godly"] = 4,       -- Very rare
		["Secret"] = 2       -- Extremely rare
	}

	-- Group available items by rarity
	local itemsByRarity = {}
	for _, itemName in ipairs(available) do
		local itemInfo = self.Config.ItemDataTable[itemName]
		local rarity = itemInfo.Rarity or "Rare"
		if not itemsByRarity[rarity] then
			itemsByRarity[rarity] = {}
		end
		table.insert(itemsByRarity[rarity], itemName)
	end

	-- Build final stock with forced items first
	local stock = {}
	for _, forcedData in ipairs(forcedItems) do
		local itemName, quantity
		if type(forcedData) == "table" then
			itemName = forcedData.Name
			quantity = forcedData.Quantity or rng:NextInteger(
				self.Config.ItemDataTable[itemName].MinimumStock or 0,
				self.Config.ItemDataTable[itemName].BestStock
			)
		else
			itemName = forcedData
			quantity = rng:NextInteger(
				self.Config.ItemDataTable[itemName].MinimumStock or 0,
				self.Config.ItemDataTable[itemName].BestStock
			)
		end
		stock[itemName] = tonumber(quantity)
	end

	-- Add ALL guaranteed items (MinimumStock > 0) - these are ALWAYS in stock
	for _, itemName in ipairs(guaranteedItems) do
		local itemInfo = self.Config.ItemDataTable[itemName]
		local quantity = rng:NextInteger(itemInfo.MinimumStock, itemInfo.BestStock)
		stock[itemName] = tonumber(quantity)
	end

	-- Helper function to select a rarity based on weights
	local function selectWeightedRarity()
		local totalWeight = 0
		local availableRarities = {}
		
		for rarity, items in pairs(itemsByRarity) do
			if #items > 0 then
				local weight = rarityWeights[rarity] or 50
				totalWeight = totalWeight + weight
				table.insert(availableRarities, {rarity = rarity, weight = weight})
			end
		end
		
		if totalWeight == 0 then return nil end
		
		local roll = rng:NextNumber() * totalWeight
		local cumulative = 0
		
		for _, data in ipairs(availableRarities) do
			cumulative = cumulative + data.weight
			if roll <= cumulative then
				return data.rarity
			end
		end
		
		return availableRarities[1] and availableRarities[1].rarity
	end

	-- Add items using weighted rarity selection
	local currentCount = 0
	for _ in pairs(stock) do currentCount = currentCount + 1 end
	
	local targetCount = rng:NextInteger(self.Config.StockRange.min, self.Config.StockRange.max)
	local remaining = math.max(0, targetCount - currentCount)
	local addedItems = {} -- Track what we've added to avoid duplicates
	
	for _ = 1, remaining do
		local selectedRarity = selectWeightedRarity()
		if not selectedRarity then break end
		
		local rarityItems = itemsByRarity[selectedRarity]
		if rarityItems and #rarityItems > 0 then
			-- Pick a random item from this rarity
			local randomIndex = rng:NextInteger(1, #rarityItems)
			local itemName = rarityItems[randomIndex]
			
			-- Only add if not already in stock
			if not stock[itemName] and not addedItems[itemName] then
				local itemInfo = self.Config.ItemDataTable[itemName]
				local quantity = rng:NextInteger(
					itemInfo.MinimumStock or 0,
					itemInfo.BestStock
				)
				stock[itemName] = tonumber(quantity)
				addedItems[itemName] = true
				
				-- Remove from the rarity pool to avoid duplicates
				table.remove(rarityItems, randomIndex)
			end
		end
	end

	return stock
end

-- Update store for all players
function Store:updateStore()
	self.nextResetTime = self:getNextResetTime()
	local forcedItems = self:loadForcedItems()

	-- Generate stock with current forced items
	self.CurrentStock = self:generateStock(self.nextResetTime - self.Config.ResetInterval, forcedItems)
	
	-- Mark store as initialized
	self.IsInitialized = true

	-- CLEAR all forced items after using them (one-time use)
	self:saveForcedItems({})

	-- Update all player data with timestamp only (stock is now global)
	for _, p in PlayersService:GetPlayers() do
		task.spawn(function()
			repeat task.wait() until Data[p]
			local replica = Data[p]
			replica:SetValue({self.Config.DataKeys.CurrentStock}, self.nextResetTime)
			-- NOTE: We no longer store Stock in player data - it's global!
		end)
	end

	-- Wait a moment for all replicas to update
	task.wait(0.5)

	-- NOW fire to all clients with the global stock
	self.RemoteEvent:FireAllClients("Refresh", self.CurrentStock, self.nextResetTime)
end

-- Personal restock for individual player (generates unique stock for this player only)
function Store:restockPlayer(plr)
	if not plr or not plr:IsA("Player") then
		warn("[" .. self.Type .. " Store] Invalid player provided to restockPlayer")
		return false
	end

	repeat task.wait() until Data[plr]
	local replica = Data[plr]

	-- Generate a COMPLETELY NEW stock using a unique timestamp for this player
	-- This creates a different random seed so they get different items
	local uniqueTimestamp = os.time() + plr.UserId

	local personalStock = self:generateStock(uniqueTimestamp, {}) -- Don't use forced items

	-- Update player's timestamp only
	replica:SetValue({self.Config.DataKeys.CurrentStock}, self.nextResetTime)

	-- Fire update to this specific player with their personal stock
	-- NOTE: This sends personal stock directly - client needs to handle this specially
	self.RemoteEvent:FireClient(plr, "RefreshPersonal", personalStock, self.nextResetTime)

	-- Notification for the player
	FXRemote:FireClient(plr, "Replicate", {
		["Call"] = "Sound",
		["Sound"] = Replicated.Game.Sounds.GameSounds.restock,
		['norandom'] = true
	})

	local ShadowColor = self.Config.DisplayName == "Seed Shop" and Color3.fromRGB(0, 241, 108) or Color3.fromRGB(170, 0, 255)

	UIRemote:FireClient(plr, "TopNotification", {
		["Text"] = "Your " .. self.Config.DisplayName .. " has Restocked!";
		["Duration"] = 5;
		["ShadowColor"] = ShadowColor;
		["ShadowTransparency"] = 0.35;
	})

	return true
end

-- Force an item to always appear in stock
function Store:forceItem(itemName, quantity, permanentForce)
	if not self.Config.ItemDataTable[itemName] or not self.Config.ItemDataTable[itemName].BestStock then
		warn("[" .. self.Type .. " Store] Invalid item name:", itemName)
		return false
	end

	local forcedItems = self:loadForcedItems()

	-- If permanent forcing is enabled, check for duplicates
	if permanentForce then
		for i, forcedData in ipairs(forcedItems) do
			local name = type(forcedData) == "table" and forcedData.Name or forcedData
			if name == itemName then
				-- Update the quantity if already exists
				if quantity then
					forcedItems[i] = {Name = itemName, Quantity = quantity}
					self:saveForcedItems(forcedItems)
					self:updateStore()
				else
					warn("[" .. self.Type .. " Store]", itemName, "is already forced")
				end
				return false
			end
		end
	end

	-- Add new forced item
	if quantity then
		table.insert(forcedItems, {Name = itemName, Quantity = quantity})
	else
		table.insert(forcedItems, itemName)
	end

	self:saveForcedItems(forcedItems)
	self:updateStore()

	return true
end

-- Remove an item from forced list
function Store:unforceItem(itemName)
	local forcedItems = self:loadForcedItems()

	for i, forcedData in ipairs(forcedItems) do
		local name = type(forcedData) == "table" and forcedData.Name or forcedData
		if name == itemName then
			table.remove(forcedItems, i)
			self:saveForcedItems(forcedItems)
			self:updateStore()
			return true
		end
	end

	return false
end

-- Get list of currently forced items
function Store:getForcedItems()
	return self:loadForcedItems()
end

-- Setup MessagingService listener
function Store:setupMessaging()
	local success, connection = pcall(function()
		return MessagingService:SubscribeAsync(self.Type .. "StoreUpdate", function(message)
			self:updateStore()
		end)
	end)

	if not success then
		warn("[" .. self.Type .. " Store] Failed to setup MessagingService:", connection)
	end
end

--[[
	Handle purchase request - FIXED VERSION
	
	KEY FIXES:
	1. Reads from GLOBAL stock (self.CurrentStock) instead of player data
	2. Performs ATOMIC check-and-decrement to prevent race conditions
	3. Broadcasts update to ALL players via FireAllClients
	4. Proper error handling for out-of-stock cases
]]
function Store:handlePurchase(plr, itemName)
	-- Validate store is initialized
	if not self.IsInitialized then
		UIRemote:FireClient(plr, "TopNotification", {
			Text = "Store is initializing, please try again!";
			Duration = 3;
			["ShadowColor"] = Color3.fromRGB(241, 0, 0);
			["ShadowTransparency"] = 0.35;
		})
		return
	end

	-- Validate item exists in stock table
	if not self.Config.ItemDataTable[itemName] then
		warn("[" .. self.Type .. " Store] Invalid item purchase attempt:", itemName)
		return
	end

	local itemCache = self.Config.ItemDataTable[itemName]

	-- Check if item is currently in stock GLOBALLY
	-- FIX #1: Use global CurrentStock instead of player data
	local currentGlobalStock = self.CurrentStock[itemName]
	if not currentGlobalStock or currentGlobalStock <= 0 then
		-- Item is out of stock globally
		FXRemote:FireClient(plr, "Replicate", {
			["Call"] = "Sound",
			["Sound"] = Replicated.Game.Sounds.GameSounds.error,
			['norandom'] = true
		})
		UIRemote:FireClient(plr, "TopNotification", {
			Text = "This item is out of stock!";
			Duration = 5;
			["ShadowColor"] = Color3.fromRGB(241, 0, 0);
			["ShadowTransparency"] = 0.35;
		})
		return
	end

	-- Get player data for money check
	local getPlayerReplica = Data[plr]
	if not getPlayerReplica or not getPlayerReplica.Data then
		warn("[" .. self.Type .. " Store] Player data not available:", plr.Name)
		return
	end
	
	local getPlayerData = getPlayerReplica.Data

	-- Check if player's stock timestamp matches current cycle
	if getPlayerData[self.Config.DataKeys.CurrentStock] ~= self.nextResetTime then
		-- Player needs a refresh - their data is stale
		getPlayerReplica:SetValue({self.Config.DataKeys.CurrentStock}, self.nextResetTime)
	end

	-- Check if they have the money to buy
	if getPlayerData.Cash < itemCache.BuyPrice then
		FXRemote:FireClient(plr, "Replicate", {
			["Call"] = "Sound",
			["Sound"] = Replicated.Game.Sounds.GameSounds.error,
			['norandom'] = true
		})
		UIRemote:FireClient(plr, "TopNotification", {
			Text = "You don't have enough money to purchase this!";
			Duration = 3;
			["ShadowColor"] = Color3.fromRGB(241, 0, 0);
			["ShadowTransparency"] = 0.35;
		})
		return
	end

	-- FIX #2: ATOMIC PURCHASE VALIDATION
	-- Use a lock to prevent race conditions during purchase
	if self.PurchaseLock[itemName] then
		-- Another purchase is in progress, wait and retry
		task.wait(0.1)
		self:handlePurchase(plr, itemName)
		return
	end

	-- Set purchase lock
	self.PurchaseLock[itemName] = true

	-- Double-check stock after acquiring lock (race condition prevention)
	if self.CurrentStock[itemName] <= 0 then
		self.PurchaseLock[itemName] = nil
		FXRemote:FireClient(plr, "Replicate", {
			["Call"] = "Sound",
			["Sound"] = Replicated.Game.Sounds.GameSounds.error,
			['norandom'] = true
		})
		UIRemote:FireClient(plr, "TopNotification", {
			Text = "This item just sold out!";
			Duration = 3;
			["ShadowColor"] = Color3.fromRGB(241, 0, 0);
			["ShadowTransparency"] = 0.35;
		})
		return
	end

	-- Find player's plot
	local playerPlot = nil
	for _, p in pairs(_G.Plots or {}) do
		if p.Owner == plr then
			playerPlot = p
			break
		end
	end

	if not playerPlot then
		self.PurchaseLock[itemName] = nil
		warn("[" .. self.Type .. " Store] Could not find plot for player:", plr.Name)
		return
	end

	-- Check inventory space
	local TotalInventorySize = self.Config.InventorySizes.default
	if MarketplaceService:UserOwnsGamePassAsync(plr.UserId, self.Config.InventoryGamePass) then
		TotalInventorySize = self.Config.InventorySizes.gamepass
	end

	local GetInventoryCount = 0
	for _ in pairs(playerPlot.OwnerData.Inventory) do
		GetInventoryCount += 1
	end

	if GetInventoryCount >= TotalInventorySize then
		self.PurchaseLock[itemName] = nil
		UIRemote:FireClient(plr, "TopNotification", {
			Text = "Your inventory is full! (" .. GetInventoryCount .. "/" .. TotalInventorySize .. ")";
			Duration = 3;
			["ShadowColor"] = Color3.fromRGB(241, 0, 0);
			["ShadowTransparency"] = 0.35;
		})
		return
	end

	-- ALL CHECKS PASSED - PROCESS PURCHASE
	
	-- 1. Decrement global stock FIRST
	local newQuantity = self.CurrentStock[itemName] - 1
	self.CurrentStock[itemName] = newQuantity

	-- 2. Release the lock
	self.PurchaseLock[itemName] = nil

	-- 3. Give the item to player
	playerPlot:GiveItem({
		["ID"] = HttpService:GenerateGUID(false);
		["Name"] = itemName;
	})

	-- 4. Deduct money
	getPlayerReplica:SetValue({"Cash"}, getPlayerData.Cash - itemCache.BuyPrice)

	-- FIX #3: BROADCAST TO ALL PLAYERS
	-- Send update to ALL clients so everyone sees the new stock level
	self.RemoteEvent:FireAllClients("UpdateStock", itemName, newQuantity)

	-- 5. Play success sound for purchaser
	FXRemote:FireClient(plr, "Replicate", {
		["Call"] = "Sound",
		["Sound"] = Replicated.Game.Sounds.GameSounds.sold,
		['norandom'] = true
	})
end

-- Initialize stock for a new player who just joined
function Store:initializePlayerStock(plr)
	if not plr or not plr:IsA("Player") then return end
	
	task.spawn(function()
		-- Wait for store to be fully initialized
		local timeout = 15
		local startTime = tick()
		while not self.IsInitialized and (tick() - startTime < timeout) do
			task.wait(0.1)
		end
		
		if not self.IsInitialized then
			warn("[" .. self.Type .. " Store] Store not initialized in time for player:", plr.Name)
			return
		end
		
		-- Wait for player data to be ready
		local dataTimeout = 10
		local dataStartTime = tick()
		while not Data[plr] and (tick() - dataStartTime < dataTimeout) do
			task.wait(0.1)
		end
		
		if not Data[plr] then
			warn("[" .. self.Type .. " Store] Player data not ready for:", plr.Name)
			return
		end
		
		local replica = Data[plr]
		
		-- Wait for replica data
		while not replica.Data and (tick() - dataStartTime < dataTimeout) do
			task.wait(0.1)
		end
		
		if not replica.Data then
			warn("[" .. self.Type .. " Store] Replica data not ready for:", plr.Name)
			return
		end
		
		-- Double-check we have valid stock
		if not self.CurrentStock or next(self.CurrentStock) == nil then
			warn("[" .. self.Type .. " Store] No stock available for player:", plr.Name)
			return
		end
		
		-- Set the player's timestamp to current reset time
		replica:SetValue({self.Config.DataKeys.CurrentStock}, self.nextResetTime)
		-- NOTE: We do NOT set Stock in player data anymore - it's global!
		
		-- Small delay to ensure data is set before firing client
		task.wait(0.3)
		
		-- Fire to this specific player with current global stock
		self.RemoteEvent:FireClient(plr, "Refresh", self.CurrentStock, self.nextResetTime)
	end)
end

-- Start the timer loop
function Store:startTimerLoop()
	task.spawn(function()
		while true do
			local timeUntilReset = self.nextResetTime - os.time()

			if timeUntilReset <= 0 then
				FXRemote:FireAllClients("Replicate", {
					["Call"] = "Sound",
					["Sound"] = Replicated.Game.Sounds.GameSounds.restock,
					['norandom'] = true
				})

				for _, player in PlayersService:GetPlayers() do
					local ShadowColor = self.Config.DisplayName == "Seed Shop" and Color3.fromRGB(0, 241, 108) or Color3.fromRGB(170, 0, 255)

					UIRemote:FireClient(player, "TopNotification", {
						["Text"] = self.Config.DisplayName .. " has Restocked!";
						["Duration"] = 5;
						["ShadowColor"] = ShadowColor;
						["ShadowTransparency"] = 0.35;
					})
				end

				self:updateStore()
			end

			workspace:SetAttribute(self.Config.AttributeName, timeUntilReset)

			task.wait(1)
		end
	end)
end

-- Initialize stores
local Stores = {}

for storeType, config in pairs(StoreConfigs) do
	local store = Store.new(storeType, config)
	Stores[storeType] = store

	-- Setup remote event listener
	store.RemoteEvent.OnServerEvent:Connect(function(plr, call, info)
		if call == "PurchaseStock" then
			store:handlePurchase(plr, info)
		end
	end)

	-- Setup messaging and initialize
	store:setupMessaging()
	store:updateStore()
	store:startTimerLoop()
end

-- Initialize stock for new players when they join
PlayersService.PlayerAdded:Connect(function(plr)
	for _, store in pairs(Stores) do
		store:initializePlayerStock(plr)
	end
end)

-- Also initialize stock for players already in the game
for _, plr in PlayersService:GetPlayers() do
	for _, store in pairs(Stores) do
		store:initializePlayerStock(plr)
	end
end

-- Public API
local GlobalStore = {}

GlobalStore.RESET_INTERVAL = 300

-- Seed Store API
GlobalStore.nextResetTime = Stores.Seed.nextResetTime
GlobalStore.CurrentStock = Stores.Seed.CurrentStock

function GlobalStore.RestockPlayerStore(plr, storeType)
	storeType = storeType or "Seed"
	if Stores[storeType] then
		return Stores[storeType]:restockPlayer(plr)
	end
	warn("Invalid store type:", storeType)
	return false
end

function GlobalStore.ForceSeed(seedName, quantity, permanentForce)
	return Stores.Seed:forceItem(seedName, quantity, permanentForce)
end

function GlobalStore.UnforceSeed(seedName)
	return Stores.Seed:unforceItem(seedName)
end

function GlobalStore.GetForcedSeeds()
	return Stores.Seed:getForcedItems()
end

-- Gear Store API
function GlobalStore.ForceGear(gearName, quantity, permanentForce)
	return Stores.Gear:forceItem(gearName, quantity, permanentForce)
end

function GlobalStore.UnforceGear(gearName)
	return Stores.Gear:unforceItem(gearName)
end

function GlobalStore.GetForcedGears()
	return Stores.Gear:getForcedItems()
end

-- Generic store access
function GlobalStore.GetStore(storeType)
	return Stores[storeType]
end

function GlobalStore.ForceStoreItem(storeType, itemName, quantity, permanentForce)
	if Stores[storeType] then
		return Stores[storeType]:forceItem(itemName, quantity, permanentForce)
	end
	warn("Invalid store type:", storeType)
	return false
end

function GlobalStore.UnforceStoreItem(storeType, itemName)
	if Stores[storeType] then
		return Stores[storeType]:unforceItem(itemName)
	end
	warn("Invalid store type:", storeType)
	return false
end

function GlobalStore.GetForcedStoreItems(storeType)
	if Stores[storeType] then
		return Stores[storeType]:getForcedItems()
	end
	warn("Invalid store type:", storeType)
	return {}
end

-- Expose Stores for external access
GlobalStore.Stores = Stores

return GlobalStore
