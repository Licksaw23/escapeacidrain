local ViewportModelCFrame = CFrame.new(0, -4, -9) * CFrame.Angles(math.rad(8), math.rad(-13), math.rad(0))
local ViewportPlantCFrame = CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), math.rad(20), math.rad(20))

-- player --

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera

-- services --

local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

-- folders --

local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Gears = GameFolder.Models.Gears
local Utilities = Modules.Utilities
local Libraries = Modules.Libraries
local UI = GameFolder.UI

-- modules --

local NewTS = require(Utilities.Tweener)
local GearLibrary = require(Libraries.GearsData)
local ViewportFitter = require(Utilities.ViewportFitter)

-- ui --

local MainUI = PlayerGui:WaitForChild("MainUI")
local TimerText = MainUI.GearShop.Frame.Timer
local SeedScroll = MainUI.GearShop.Scrolls.MainScroll

-- data --

local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data
local IndexData = PlayerData.Unlocks
local Tweener = require(Utilities.Tweener)
local Spring = require(Utilities.Tweener.Spring)


-- remotes --

local RestockRemote = RS.Remotes.UpdateGearStore

-- // Code \\ --

local module = {}

-- [[ FIXED: Global stock cache - all players see the same stock ]] --
local GlobalStock = {}
local CurrentResetTime = 0

for itemName, itemInfo in GearLibrary do
	if itemInfo.MinimumStock then
		local newSeedSlot = script.SeedSlot:Clone()
		newSeedSlot.Parent = SeedScroll
		newSeedSlot.Name = itemName
		newSeedSlot.Visible = true
		newSeedSlot.Title.Text = itemName
		newSeedSlot.Rarity.Text = itemInfo.Rarity
		newSeedSlot.LayoutOrder = itemInfo.Layout or 1
		local getRarity = UI.Gradients[itemInfo.Rarity]:Clone()
		getRarity.Parent = newSeedSlot.Rarity
		newSeedSlot.Buy.ButtonText.Text = "$"..itemInfo.BuyPrice

		for _, imgLabel in newSeedSlot.BGEffects:GetChildren() do
			if imgLabel.Name == "ImageLabel" then
				local newGrad = getRarity:Clone()
				newGrad.Parent = imgLabel
			end
		end

		-- VIEWPORT --
		local seedModel = GameFolder.Models.Gears[itemName]:Clone() -- Get seed model
		local Viewport = newSeedSlot.ViewportFrame
		local Camera = Instance.new("Camera")
		Camera.Parent = Viewport
		Viewport.CurrentCamera = Camera

		-- Setup seed model initially
		local viewModel = seedModel:Clone()
		viewModel.Name = "ViewModel"
		viewModel.Parent = Viewport
		local viewportFitter = ViewportFitter.new(Viewport, Camera)
		local modelCFrame, modelSize = viewModel:GetBoundingBox()
		viewportFitter:SetModel(viewModel)
		-- Offset the viewport
		local cameraDistance = viewportFitter:GetFitDistance(modelCFrame.Position) * 1
		Camera.CFrame = CFrame.new(modelCFrame.Position) * CFrame.fromEulerAnglesXYZ(0, -86, 95) * CFrame.new(0, 0, cameraDistance)

		-- BUY --

		local BGEffects = newSeedSlot.BGEffects

		local tweenInfo = TweenInfo.new(
			3, -- Duration (3 seconds)
			Enum.EasingStyle.Quad, -- Smooth quad
			Enum.EasingDirection.InOut, -- Ease in and out
			-1, -- Repeat count (-1 = infinite)
			true, -- Reverse (creates the breathing effect)
			0 -- Delay
		)

		newSeedSlot.Buy.Click.MouseButton1Click:Connect(function()
			local quanity = newSeedSlot.Buy
			RestockRemote:FireServer("PurchaseStock", itemName)
		end)
		
		-- ROBUX BUY BUTTON --
		if itemInfo.PurchaseID and itemInfo.PurchaseID > 0 then
			local robuxButton = newSeedSlot:FindFirstChild("RobuxBuy")
			if robuxButton then
				-- Get product info to display price
				local success, productInfo = pcall(function()
					return MarketplaceService:GetProductInfo(itemInfo.PurchaseID, Enum.InfoType.Product)
				end)
				
				if success and productInfo then
					-- Set button text to Robux icon + price
					local buttonText = robuxButton:FindFirstChild("ButtonText")
					if buttonText then
						-- Robux icon + price
						buttonText.Text = "  " .. productInfo.PriceInRobux
					end
					
					-- Make button visible
					robuxButton.Visible = true
					
					-- Handle click
					local robuxClick = robuxButton:FindFirstChild("Click")
					if robuxClick then
						robuxClick.MouseButton1Click:Connect(function()
							-- Prompt the product purchase (no stock check, can buy anytime)
							MarketplaceService:PromptProductPurchase(Player, itemInfo.PurchaseID)
						end)
					end
				else
					-- Hide button if we can't get product info
					robuxButton.Visible = false
				end
			end
		end
	end
end

-- Functions. --
function module.LoadShopOnData(data)
	
end

-- [[ FIXED: Handle both global refresh and personal refresh ]] --
RestockRemote.OnClientEvent:Connect(function(call, a1, a2)
	if call == "Refresh" then
		-- Global stock refresh - all players get the same stock
		local serverStock = a1
		local resetTime = a2
		
		-- Update our local cache
		GlobalStock = serverStock
		CurrentResetTime = resetTime
		
		-- Update UI for all items
		for itemName, quantity in pairs(serverStock) do
			local itemFrame = SeedScroll:FindFirstChild(itemName)
			if itemFrame then
				itemFrame.Stock.Text = "x" .. quantity .. " in Stock"
			end
		end
		
		-- Hide items that are not in stock
		for _, frame in ipairs(SeedScroll:GetChildren()) do
			if frame:IsA("Frame") and GearLibrary[frame.Name] and GearLibrary[frame.Name].MinimumStock then
				if not serverStock[frame.Name] then
					frame.Stock.Text = "x0 in Stock"
				end
			end
		end
		
	elseif call == "RefreshPersonal" then
		-- Personal restock - only this player sees this stock
		local personalStock = a1
		local resetTime = a2
		
		-- Update our local cache with personal stock
		GlobalStock = personalStock
		CurrentResetTime = resetTime
		
		-- Update UI for all items in personal stock
		for itemName, quantity in pairs(personalStock) do
			local itemFrame = SeedScroll:FindFirstChild(itemName)
			if itemFrame then
				itemFrame.Stock.Text = "x" .. quantity .. " in Stock"
			end
		end
		
		-- Hide items not in personal stock
		for _, frame in ipairs(SeedScroll:GetChildren()) do
			if frame:IsA("Frame") and GearLibrary[frame.Name] and GearLibrary[frame.Name].MinimumStock then
				if not personalStock[frame.Name] then
					frame.Stock.Text = "x0 in Stock"
				end
			end
		end
		
	elseif call == "UpdateStock" then
		-- [[ NEW: Global stock update - when ANY player purchases ]] --
		local itemName = a1
		local newQuantity = a2
		
		-- Update our local cache
		GlobalStock[itemName] = newQuantity
		
		-- Update UI for this item
		local itemFrame = SeedScroll:FindFirstChild(itemName)
		if itemFrame then
			itemFrame.Stock.Text = "x" .. newQuantity .. " in Stock"
		end
		
	elseif call == "UpdateOne" then
		-- Legacy update for backwards compatibility
		local itemName = a1
		local newQuantity = a2
		
		GlobalStock[itemName] = newQuantity
		
		local itemFrame = SeedScroll:FindFirstChild(itemName)
		if itemFrame then
			itemFrame.Stock.Text = "x" .. newQuantity .. " in Stock"
		end
	end
end)
 
workspace:GetAttributeChangedSignal("GearRestockTime"):Connect(function()
	local function FormatTime(seconds)
		seconds = math.floor(seconds)
		local minutes = math.floor(seconds / 60)
		local secs = seconds % 60

		return string.format("%02d:%02d", minutes, secs)
	end
	
	repeat wait() until Player:GetAttribute("Plot")
	
	local getSeconds = workspace:GetAttribute("GearRestockTime")
	local timer = workspace.Plots[Player:GetAttribute("Plot")].NPC["Gear Merchant"].Gear.TitleFrame.Timer
	
	timer.Text = FormatTime(getSeconds)
	TimerText.Text = FormatTime(getSeconds)
end)

return module
