local ViewportModelCFrame = CFrame.new(0, -4, -9) * CFrame.Angles(math.rad(8), math.rad(-13), math.rad(0))
local ViewportPlantCFrame = CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), math.rad(20), math.rad(20))

-- player --

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local EncodingService = game:GetService("EncodingService")
local TweenService = game:GetService("TweenService")
-- services --

local RS = game:GetService("ReplicatedStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TS = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- folders --

local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries

local orderRemote = RS.Remotes.Order
local timerRemote = RS.Remotes.Timers
local spawnRemote = RS.Remotes.Spawn
local PlotRemote = RS.Remotes.Plot
local ItemsData = require(ReplicatedStorage.Game.Modules.Libraries.ItemsData)
local Registry = require(StarterPlayer.StarterPlayerScripts.Framework.Registry)
local MutationsListData = ReplicatedStorage.Game.Modules.Libraries.MutationsData
local NewTS = require(Utilities.Tweener)
local Spring = require(Utilities.Tweener.Spring)

-- modules --

local Zone = require(Utilities.Zone)
local NewTS = require(Utilities.Tweener)
local ItemLibrary = require(Libraries.ItemsData)
local flowUtil = require(Utilities.flowUtil)
local ViewportFitter = require(Utilities.ViewportFitter)
local LerpMover = require(Utilities.LerpMover)
local MutationsData = require(Libraries.MutationsData)
local NumberShortener = require(Utilities.NumberShortener)
local CalculateMoney = require(Utilities.Calculator)
local GetScale = require(script.Parent.Parent.Parent.Handlers.VFX.Scale)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local VFX = require(script.Parent.Parent.Parent.Handlers.VFX)
local Gear_Shop__Client_ = require(script.Parent["Gear Shop [Client]"])
local ItemsLibrary = require(Libraries.ItemsData)

-- ui --

local MainUI = PlayerGui:WaitForChild("MainUI")

-- data --

local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data


local module = {}

repeat task.wait() until Player:GetAttribute("Plot")

local Plot = Player:GetAttribute("Plot")
local PlotFolder = workspace.Plots[Plot]
local DeskFolder = PlotFolder.Desks

local buttons = {
	--Accept = {
	--	button = DeskFolder.Desk1.Accept,
	--	color = Color3.fromRGB(103, 172, 38)
	--},
	--Deny = {
	--	button = Desk.Decline,
	--	color = Color3.fromRGB(185, 48, 55)
	--}
}

for i = 1,3 do
	buttons["accept"..i] = {
		button = DeskFolder["Desk"..i].Accept,
		color = Color3.fromRGB(103,172,38)
	}

	buttons["deny"..i] = {
		button = DeskFolder["Desk"..i].Decline,
		color = Color3.fromRGB(185,48,55),
	}
end

local getPlotFolder = workspace.Plots:WaitForChild(Plot)

module.CurrentOrder = {[1] = {}; [2] = {}; [3] = {}}

local giveFruitUI = MainUI.GiveFruits 
local giveFruitList = giveFruitUI.FruitList

-- FRUIT SAVES --
-- Structure: SavedFruits[fruitName][itemID] = {weight, mutations, ...}
module.SavedFruits = {}

-- State for two-level fruit selection
module.FruitSelectionLevel = 1 -- 1 = fruit type, 2 = individual fruits
module.SelectedFruitType = nil -- Which fruit type is selected in level 2

local rarityToSort = {
	["Rare"] = 1;
	["Epic"] = 2;
	["Legendary"] = 3;
	["Mythic"] = 4;
	["Godly"] = 5;
	["Secret"] = 6;
}

local mutationToSort = {
	["Normal"] = 1;
	["Gold"] = 2;
	["Petrified"] = 3;
	["Emerald"] = 4;
	["Diamond"] = 5;
	["Rainbow"] = 6;
}

-- Helper to get primary mutation (for sorting)
local function getPrimaryMutation(mutations)
	if not mutations or #mutations == 0 then
		return "Normal"
	end
	-- Return the first non-effect mutation
	for _, mut in ipairs(mutations) do
		local mutData = MutationsData[mut]
		if mutData and not mutData.IsEffect then
			return mut
		end
	end
	return mutations[1] or "Normal"
end

-- Helper to count total fruits of a type
local function getTotalFruitCount(fruitName)
	if not module.SavedFruits[fruitName] then return 0 end
	local count = 0
	for _ in pairs(module.SavedFruits[fruitName]) do
		count = count + 1
	end
	return count
end

-- Clear all fruit frames from the list (instant, no animation)
local function clearFruitList()
	for _, child in giveFruitList:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "OrderTemplate" then
			child:Destroy()
		end
	end
end

-- Forward declaration
local addOrderFrameToUI
local populateFruitList
local populateMutationList

-- Track if a transition is in progress to prevent double-clicks
local isTransitioning = false

-- Helper to animate frames OUT and return how long it takes
local function animateFramesOut()
	local getList = {}
	for _, frame in giveFruitList:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "OrderTemplate" then
			table.insert(getList, frame)
		end
	end
	
	if #getList == 0 then return 0 end
	
	-- Sort in reverse order (right to left, high to low LayoutOrder) for exit animation
	table.sort(getList, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder > b.LayoutOrder
		end
		return a.AbsolutePosition.X > b.AbsolutePosition.X
	end)
	
	local animDuration = 0.15
	local stagger = 0.03
	
	for i, frame in ipairs(getList) do
		if frame:FindFirstChild("UIScale") then
			task.delay((i-1) * stagger, function()
				if frame and frame:FindFirstChild("UIScale") then
					TweenService:Create(frame.UIScale, TweenInfo.new(animDuration, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
				end
			end)
		end
	end
	
	-- Return total animation time
	return (#getList - 1) * stagger + animDuration
end

-- Helper to animate frames IN after populating
local function animateFramesIn()
	local getList = {}
	for _, frame in giveFruitList:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "OrderTemplate" then
			table.insert(getList, frame)
		end
	end
	
	-- Sort by LayoutOrder first, then by horizontal position (left to right)
	table.sort(getList, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.AbsolutePosition.X < b.AbsolutePosition.X
	end)
	
	-- For individual fruits (level 2), animate all at once. For fruit types (level 1), stagger them
	local stagger = module.FruitSelectionLevel == 2 and 0 or 0.04
	
	for i, frame in ipairs(getList) do
		if frame:FindFirstChild("UIScale") then
			frame.UIScale.Scale = 0
			task.delay((i-1) * stagger, function()
				if frame and frame:FindFirstChild("UIScale") then
					NewTS:TweenBounce(frame.UIScale, {Scale = 1}, nil, 4)
				end
			end)
		end
	end
end

-- Smooth transition helper - animates out, clears, then calls the populate callback
local function smoothTransition(populateCallback, instant)
	if isTransitioning then return end
	isTransitioning = true
	
	task.spawn(function()
		if instant then
			-- Instant transition: clear and populate immediately
			clearFruitList()
			populateCallback()
			animateFramesIn()
			isTransitioning = false
		else
			-- Smooth transition with out animation
			local outDuration = animateFramesOut()
			
			-- Wait for out animation to complete
			--if outDuration > 0 then
			--	task.wait(outDuration + 0.05)
			--end
			
			-- Clear and populate
			clearFruitList()
			populateCallback()
			
			-- Animate new frames in
			animateFramesIn()
			
			-- Small delay before allowing next transition
			--task.wait(0.2)
			isTransitioning = false
		end
	end)
end

-- Helper to update UIListLayout based on selection level
local function updateFruitListLayout()
	local listLayout = giveFruitList:FindFirstChildOfClass("UIListLayout")
	
	if listLayout then
		if module.FruitSelectionLevel == 1 then
			-- Level 1: Center alignment
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		else
			-- Level 2: Left alignment
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	end
end

-- Internal populate functions (no animation, just create frames)
local function createFruitTypeFrames()
	module.FruitSelectionLevel = 1
	module.SelectedFruitType = nil
	updateFruitListLayout()
	
	for fruitName, fruitsTable in pairs(module.SavedFruits) do
		local totalCount = getTotalFruitCount(fruitName)
		if totalCount > 0 then
			addOrderFrameToUI({
				["Parent"] = giveFruitList;
				["Item"] = {["Name"] = fruitName; ["Amount"] = totalCount};
				["Visible"] = true;
				["LayoutOrder"] = rarityToSort[ItemsData[fruitName] and ItemsData[fruitName].Rarity or "Rare"];
				["IsFruitType"] = true;
			})
		end
	end
end

local function createIndividualFruitFrames(fruitName)
	module.FruitSelectionLevel = 2
	module.SelectedFruitType = fruitName
	updateFruitListLayout()
	
	-- Add back button
	local backTemplate = giveFruitList.OrderTemplate:Clone()
	backTemplate.Name = "BackButton"
	backTemplate.Title.Position = UDim2.new(0.5, 0, 0.5, 0)
	backTemplate.Title.AnchorPoint = Vector2.new(0.5, 0.5)
	backTemplate.Title.Text = "<- Back"
	backTemplate.Quantity.Text = ""
	backTemplate.Visible = true
	backTemplate.Parent = giveFruitList
	backTemplate.LayoutOrder = 0
	
	local backUIScale = Instance.new("UIScale", backTemplate)
	backUIScale.Scale = 0
	
	-- Style back button
	for _, img in backTemplate.BGEffects:GetChildren() do
		img:Destroy()
	end
	
	-- Clear viewport for back button
	for _, child in backTemplate.Viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	
	backTemplate.TextButton.MouseButton1Click:Connect(function()
		populateFruitList()
	end)
	
	-- Build sorted list of individual fruits
	local individualFruits = {}
	if module.SavedFruits[fruitName] then
		for itemID, fruitData in pairs(module.SavedFruits[fruitName]) do
			table.insert(individualFruits, {
				itemID = itemID,
				weight = fruitData.Weight or 0,
				mutations = fruitData.Mutations or {},
				primaryMutation = getPrimaryMutation(fruitData.Mutations)
			})
		end
	end
	
	-- Sort by: 1) primary mutation (Rainbow > Diamond > etc.), 2) weight (high to low)
	table.sort(individualFruits, function(a, b)
		local mutA = mutationToSort[a.primaryMutation] or 99
		local mutB = mutationToSort[b.primaryMutation] or 99
		if mutA ~= mutB then
			return mutA > mutB  -- Higher mutation value = better = first
		end
		return a.weight > b.weight  -- Higher weight = first
	end)
	
	-- Create frame for each individual fruit
	for index, fruitData in ipairs(individualFruits) do
		addOrderFrameToUI({
			["Parent"] = giveFruitList;
			["Item"] = {
				["Name"] = fruitName;
				["Amount"] = 1;
			};
			["Visible"] = true;
			["LayoutOrder"] = index;
			["IsIndividualFruit"] = true;
			["ItemID"] = fruitData.itemID;
			["Weight"] = fruitData.weight;
			["Mutations"] = fruitData.mutations;
		})
	end
end

-- Public populate functions with smooth transitions
populateFruitList = function(skipAnimation)
	if skipAnimation then
		clearFruitList()
		createFruitTypeFrames()
		animateFramesIn()
	else
		-- Going back to level 1: instant clear
		smoothTransition(createFruitTypeFrames, true)
	end
end

populateMutationList = function(fruitName)
	-- Going to level 2: instant transition
	smoothTransition(function()
		createIndividualFruitFrames(fruitName)
	end, true)
end

addOrderFrameToUI = function(info)
	local newOrderTemplate = info.Parent.OrderTemplate:Clone()
	
	-- Display name setup
	local displayName = info.Item.Name
	if info.IsIndividualFruit then
		displayName = string.format("%.1fkg", info.Weight)
	end
	
	newOrderTemplate.Name = info.IsIndividualFruit and (info.ItemID or "Individual") or info.Item.Name
	newOrderTemplate.Title.Text = displayName
	newOrderTemplate.Quantity.Text = info.IsIndividualFruit and "" or ("x"..info.Item.Amount)
	newOrderTemplate.Visible = info.Visible or false
	newOrderTemplate.Parent = info.Parent

	local UIScale = Instance.new("UIScale", newOrderTemplate)

	if info.Parent ~= giveFruitList then 
		module.CurrentOrder[info.Path][info.Item.Name] = info.Item.Amount 
	else 
		UIScale.Scale = 0 
	end
	if info.LayoutOrder then newOrderTemplate.LayoutOrder = info.LayoutOrder end
	
	if info.Parent == giveFruitList then
		local isHolding = false
		local holdThread = nil
		
		if info.IsFruitType then
			-- Level 1: clicking a fruit type shows individual fruits
			newOrderTemplate.TextButton.MouseButton1Click:Connect(function()
				populateMutationList(info.Item.Name)
			end)
		elseif info.IsIndividualFruit then
			-- Level 2: clicking an individual fruit gives it
			local function giveFruit()
				local path = module.OpenOrderZone
				if not path then return false end
				
				local itemData = PlayerData.Inventory[info.ItemID]
				if not itemData or itemData.Favorited then return false end
				
				orderRemote:FireServer("GiveFruit", path, info.ItemID)
				return true
			end
			
			-- Single click
			newOrderTemplate.TextButton.MouseButton1Click:Connect(function()
				giveFruit()
			end)
			
			-- Hold to spam
			newOrderTemplate.TextButton.MouseButton1Down:Connect(function()
				isHolding = true
				holdThread = task.spawn(function()
					task.wait(0.3)
					while isHolding do
						if not giveFruit() then break end
						task.wait(0.15)
					end
				end)
			end)
			
			newOrderTemplate.TextButton.MouseButton1Up:Connect(function()
				isHolding = false
				if holdThread then
					task.cancel(holdThread)
					holdThread = nil
				end
			end)
			
			newOrderTemplate.TextButton.MouseLeave:Connect(function()
				isHolding = false
				if holdThread then
					task.cancel(holdThread)
					holdThread = nil
				end
			end)
		else
			-- Legacy behavior for order frames
			local function giveFruit()
				local path = module.OpenOrderZone
				if not path then return false end
				
				for itemID, fruitData in pairs(module.SavedFruits[info.Item.Name] or {}) do
					local itemData = PlayerData.Inventory[itemID]
					if itemData and not itemData.Favorited then
						orderRemote:FireServer("GiveFruit", path, itemID)
						return true
					end
				end
				return false
			end
			
			newOrderTemplate.TextButton.MouseButton1Click:Connect(function()
				giveFruit()
			end)
		end
	end

	local Viewport = newOrderTemplate.Viewport
	local Camera = Instance.new("Camera")
	Camera.Parent = Viewport
	Viewport.CurrentCamera = Camera

	-- Create and position the view model
	local FruitName = info.Item.Name
	local fruitModel = GameFolder.Models.Plants:FindFirstChild(FruitName)
	if fruitModel then
		local viewModel = fruitModel:Clone()
		viewModel.Name = "ViewModel"
		viewModel.Parent = Viewport
		
		-- Apply mutations to individual fruit viewport
		if info.IsIndividualFruit and info.Mutations and #info.Mutations > 0 then
			for _, mutName in ipairs(info.Mutations) do
				local mutData = MutationsData[mutName]
				if mutData and mutData.Apply and not mutData.IsEffect then
					mutData.Apply(viewModel, Viewport)
					break  -- Only apply first non-effect mutation visually
				end
			end
		end

		-- Fit the model in the viewport
		local viewportFitter = ViewportFitter.new(Viewport, Camera)
		local modelCFrame, modelSize = viewModel:GetBoundingBox()
		viewportFitter:SetModel(viewModel)

		-- Offset the viewport
		local cameraDistance = viewportFitter:GetFitDistance(modelCFrame.Position) * 1
		Camera.CFrame = CFrame.new(modelCFrame.Position) * CFrame.fromEulerAnglesXYZ(0, -86, 95) * CFrame.new(0, 0, cameraDistance)
	end

	-- Apply gradient/mutation icons
	local rarity = ItemLibrary[FruitName] and ItemLibrary[FruitName].Rarity or "Rare"
	local rarGrad = UI.Gradients[rarity]
	
	-- For individual fruits with mutations, show mutation icons instead of gradients
	if info.IsIndividualFruit and info.Mutations and #info.Mutations > 0 then
		-- Clear background gradients
		--for _, img in newOrderTemplate.BGEffects:GetChildren() do
		--	img:Destroy()
		--end
		
		-- Standard rarity gradient for fruit types
		for _, img in newOrderTemplate.BGEffects:GetChildren() do
			rarGrad:Clone().Parent = img
		end
		
		-- Create mutation icon list at bottom of frame
		local mutationListFrame = newOrderTemplate:FindFirstChild("MutationIcons")
		if not mutationListFrame then
			mutationListFrame = Instance.new("Frame")
			mutationListFrame.Name = "MutationIcons"
			mutationListFrame.Size = UDim2.new(1, 0, 0.15, 0)
			mutationListFrame.Position = UDim2.new(0.5, 0, 0.1, 0)
			mutationListFrame.AnchorPoint = Vector2.new(0.5, 0)
			mutationListFrame.BackgroundTransparency = 1
			mutationListFrame.ZIndex = 999999999
			mutationListFrame.Parent = newOrderTemplate
			
			local listLayout = Instance.new("UIListLayout")
			listLayout.FillDirection = Enum.FillDirection.Horizontal
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			listLayout.Padding = UDim.new(0, 2)
			listLayout.Parent = mutationListFrame
		end
		
		-- Add mutation icon for each mutation
		for _, mutName in ipairs(info.Mutations) do
			local mutData = MutationsData[mutName]
			if mutData and mutData.Gradient then
				local iconFrame = Instance.new("Frame")
				iconFrame.Name = mutName
				iconFrame.Size = UDim2.new(0, 20, 0, 20)
				iconFrame.BackgroundTransparency = 1
				iconFrame.Parent = mutationListFrame
				
				-- Add gradient/icon
				local iconImage = Instance.new("ImageLabel")
				iconImage.Size = UDim2.fromScale(1, 1)
				iconImage.BackgroundTransparency = 1
				iconImage.Image = MutationsData[mutName].Icon or "rbxassetid://0" -- Use a circle or square icon
				iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
				iconImage.Parent = iconFrame
			end
		end
	else
		-- Standard rarity gradient for fruit types
		for _, img in newOrderTemplate.BGEffects:GetChildren() do
			rarGrad:Clone().Parent = img
		end
	end
end

local function verifyAndAdd(itemID, itemValue)
	if not itemValue or not itemValue.Name then return end
	if not ItemsData[itemValue.Name] or ItemsData[itemValue.Name].Type ~= "Fruit" then return end
	
	local fruitName = itemValue.Name
	
	-- Initialize table if needed
	if not module.SavedFruits[fruitName] then 
		module.SavedFruits[fruitName] = {}
	end
	
	-- Store fruit data with weight and mutations
	module.SavedFruits[fruitName][itemID] = {
		Weight = itemValue.Weight or 0,
		Mutations = itemValue.Mutations or {}
	}
	
	-- Update UI based on current level
	if module.FruitSelectionLevel == 1 then
		-- Update or create fruit type frame
		local fruitFrame = giveFruitList:FindFirstChild(fruitName)
		local totalCount = getTotalFruitCount(fruitName)
		
		if fruitFrame then
			fruitFrame.Quantity.Text = "x"..totalCount
		else
			addOrderFrameToUI({
				["Parent"] = giveFruitList;
				["Item"] = {["Name"] = fruitName; ["Amount"] = totalCount};
				["Visible"] = true;
				["LayoutOrder"] = rarityToSort[ItemsData[fruitName].Rarity];
				["IsFruitType"] = true;
			})
		end
	elseif module.FruitSelectionLevel == 2 and module.SelectedFruitType == fruitName then
		-- Need to repopulate to maintain sort order
		populateMutationList(fruitName)
	end
end

local function verifyAndRemove(itemID, itemValue)
	local fruitName = itemValue.Name
	if not module.SavedFruits[fruitName] then return end
	
	-- Remove from tracking
	module.SavedFruits[fruitName][itemID] = nil
	
	-- Clean up empty fruit tables
	local hasAny = false
	for _ in pairs(module.SavedFruits[fruitName]) do
		hasAny = true
		break
	end
	if not hasAny then
		module.SavedFruits[fruitName] = nil
	end
	
	-- Update UI based on current level
	if module.FruitSelectionLevel == 1 then
		local fruitFrame = giveFruitList:FindFirstChild(fruitName)
		if fruitFrame then
			local totalCount = getTotalFruitCount(fruitName)
			if totalCount == 0 then
				fruitFrame:Destroy()
			else
				fruitFrame.Quantity.Text = "x"..totalCount
			end
		end
	elseif module.FruitSelectionLevel == 2 and module.SelectedFruitType == fruitName then
		-- Specific fruit frame needs to be removed
		local fruitFrame = giveFruitList:FindFirstChild(itemID)
		if fruitFrame then
			fruitFrame:Destroy()
		end
		
		-- If no more fruits of this type, go back to level 1
		if getTotalFruitCount(fruitName) == 0 then
			populateFruitList()
		end
	end
end

-- Track which items we've already processed
local trackedItems = {}

-- Listen to ALL inventory changes using ListenToRaw
PlayerReplica:ListenToRaw(function(actionName, pathArray, ...)
	if pathArray[1] == "Inventory" then
		local itemID = pathArray[2]
		
		if itemID then
			local newValue = PlayerData.Inventory[itemID]
			
			if newValue then
				verifyAndAdd(itemID, newValue)
				trackedItems[itemID] = true
			else
				local args = {...}
				local oldValue = args[1]
				if oldValue and oldValue.Name then
					verifyAndRemove(itemID, oldValue)
				elseif trackedItems[itemID] then
					-- Fallback: try to find by itemID in SavedFruits
					for fruitName, fruitsTable in pairs(module.SavedFruits) do
						if fruitsTable[itemID] then
							verifyAndRemove(itemID, {Name = fruitName})
							break
						end
					end
				end
				trackedItems[itemID] = nil
			end
		else
			-- Entire inventory might have changed, resync all
			for id, value in PlayerData.Inventory do
				if not trackedItems[id] then
					verifyAndAdd(id, value)
					trackedItems[id] = true
				end
			end
		end
	end
end)

-- Initialize with existing inventory items
for itemID, itemValue in PlayerData.Inventory do
	verifyAndAdd(itemID, itemValue)
	trackedItems[itemID] = true
end

-- ORDER FUNCTIONS --
module.OrderFunctions = {
	["Thinking"] = function(info)
		PlotFolder = workspace.Plots[info.Plot]

		local GetDesk = PlotFolder.Desks:WaitForChild("Desk"..info.Path)
		local GetRot = PlotFolder.Customers:WaitForChild(info.ID)

		flowUtil:PlaySound(Sounds.BrainrotSounds.thinking,GetRot.PrimaryPart,true)

		local RotUI = GetRot.PrimaryPart.Attachment[info.ID]
		local Speech = RotUI.Speech

		Speech.Visible = true
		RotUI.OrderFrame.Visible = false
		RotUI.TitleFrame.Visible = false

		local iterator = 0
		local bubble = Speech.template
		local cancel = false

		local function iterate()
			task.spawn(function()
				for i = 1,4 do
					if cancel then return end

					iterator += 1

					if iterator == 4 then
						for _, f in Speech:GetChildren() do if f:IsA("Frame") and f.Name ~= "template" then f:Destroy() end end 
						iterator = 0
					end

					if not Speech.Parent then
						return
					end

					local newBubble = bubble:Clone()
					newBubble.Parent = Speech 
					newBubble.Name = "bubble"
					newBubble.Visible = true
					TS:Create(newBubble.UIScale, TweenInfo.new(0.3), {Scale = 1}):Play()
					task.wait(0.2)
				end

				if cancel then RotUI.TitleFrame.Visible = true; Speech.Visible = false; return end

				iterate()
			end)
		end

		iterate()
	end,

	["CreateOrderUI"] = function(info)
		PlotFolder = workspace.Plots[info.Plot]

		local GetDesk = PlotFolder.Desks:FindFirstChild("Desk"..info.Path)
		if not GetDesk then return end

		-- Create the OrderOverhead UI once
		local OrderOverhead = GameFolder.UI.OrderOverhead:Clone()
		OrderOverhead.Name = "Order-"..info.ID
		OrderOverhead.Parent = PlayerGui
		OrderOverhead.Adornee = GetDesk
		OrderOverhead.OrderFrame.Visible = true
	end,

	["AddOrder"] = function(info)
		PlotFolder = workspace.Plots[info.Plot]

		local OrderOverhead = PlayerGui:FindFirstChild("Order-"..info.ID)
		if not OrderOverhead then return end
		local OrderFrame = OrderOverhead.OrderFrame

		info.Parent = OrderFrame

		addOrderFrameToUI(info)
	end,
	
	["OrderVisible"] = function(info)
		PlotFolder = workspace.Plots[info.Plot]

		local GetDesk = PlotFolder.Desks:FindFirstChild("Desk"..info.Path)
		local GetRot = PlotFolder.Customers:FindFirstChild(info.ID)

		if GetDesk and GetRot then
			local CustomerUI = GetRot.PrimaryPart.Attachment[info.ID]
			local Speech = CustomerUI.Speech

			Speech:Destroy()
			CustomerUI.TitleFrame.Visible = true
		end

		local OrderOverhead = PlayerGui:FindFirstChild("Order-"..info.ID)
		if not OrderOverhead then return end

		local OrderStuff = OrderOverhead.OrderFrame

		if info.Time then 
			local frameSize = 0.17
			local paddingOverOneSize = 0.01
			local totalFrames = #OrderStuff:GetChildren()-2
			local totalSize = (totalFrames * frameSize) + ((totalFrames - 1) * paddingOverOneSize)
			OrderOverhead.OrderTimer.Size = UDim2.new(totalSize, 0, OrderOverhead.OrderTimer.Size.Y.Scale, 0)

			local fill = OrderOverhead.OrderTimer.Fill
			local maxTime = info.Time
			local timeRemaining = maxTime

			if not module.OrderTimers then
				module.OrderTimers = {}
			end
			module.OrderTimers[info.ID] = {
				TimeRemaining = timeRemaining,
				MaxTime = maxTime
			}

			local greenColor = Color3.fromRGB(0, 255, 115)
			local yellowColor = Color3.fromRGB(255, 255, 50)
			local orangeColor = Color3.fromRGB(255, 165, 0)
			local redColor = Color3.fromRGB(255, 50, 50)

			local timerConnection
			timerConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
				if not module.OrderTimers[info.ID] then
					if timerConnection then
						timerConnection:Disconnect()
					end
					return
				end

				local timerData = module.OrderTimers[info.ID]
				timerData.TimeRemaining -= deltaTime

				if timerData.TimeRemaining <= 0 then
					timerData.TimeRemaining = 0
					if timerConnection then
						timerConnection:Disconnect()
					end
				end

				local percentage = timerData.TimeRemaining / timerData.MaxTime
				fill.Size = UDim2.new(percentage, 0, 1, 0)

				local color
				if percentage > 0.75 then
					color = greenColor
				elseif percentage > 0.5 then
					local alpha = (percentage - 0.5) / 0.25
					color = yellowColor:Lerp(greenColor, alpha)
				elseif percentage > 0.25 then
					local alpha = (percentage - 0.25) / 0.25
					color = orangeColor:Lerp(yellowColor, alpha)
				else
					local alpha = percentage / 0.25
					color = redColor:Lerp(orangeColor, alpha)
				end

				local gradient = fill:FindFirstChildOfClass("UIGradient")
				if gradient then
					local existingSequence = gradient.Color.Keypoints

					local lightenedColor = Color3.new(
						math.min(color.R + 0.3, 1),
						math.min(color.G + 0.3, 1),
						math.min(color.B + 0.3, 1)
					)

					local newKeypoints = {
						ColorSequenceKeypoint.new(0, color),
						ColorSequenceKeypoint.new(existingSequence[2].Time, lightenedColor)
					}

					for i = 3, #existingSequence do
						table.insert(newKeypoints, existingSequence[i])
					end

					gradient.Color = ColorSequence.new(newKeypoints)
				else
					fill.BackgroundColor3 = color
				end
			end)

			task.spawn(function()
				local timeLeftText = OrderOverhead.OrderTimer.TimeRemaining
				local lastDisplayedTime = -1

				while module.OrderTimers[info.ID] do
					local currentTime = module.OrderTimers[info.ID].TimeRemaining
					local displayTime = math.ceil(currentTime)

					if displayTime ~= lastDisplayedTime then
						timeLeftText.Text = displayTime.."s"
						lastDisplayedTime = displayTime

						local ogSize = timeLeftText.Size
						timeLeftText.Rotation = timeLeftText.Rotation + math.random(-7,7)
						timeLeftText.Size += UDim2.new(0,15,0,15)

						NewTS:Tween(timeLeftText,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Rotation = 0}):Play()
						NewTS:Tween(timeLeftText,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size = ogSize}):Play()
					end

					task.wait(0.1)
				end

				if timeLeftText then
					timeLeftText.Text = "0s"
				end
			end)
		end

		for _, order in OrderStuff:GetChildren() do
			if order:IsA("Frame") and order.Name ~= "OrderTemplate" then
				if order.Name == "OrderTimer" then 
					TS:Create(order.UIScale, TweenInfo.new(0.3), {Scale = 1}):Play()
				else
					TS:Create(order.UIScale, TweenInfo.new(0.3), {Scale = 0.6}):Play()
				end

				order.Visible = true

				task.wait(0.15)
			end
		end
	end,

	["UpdateOrder"] = function(info)
		PlotFolder = workspace.Plots[info.Plot]

		local OrderOverhead = PlayerGui:FindFirstChild("Order-"..info.ID)
		if not OrderOverhead then return end
		local OrderFrame = OrderOverhead.OrderFrame

		local brainrotID = info.ID
		local info = info.Info
		local brainrotName = info.Name
		local targetItem = info.Item
		local newNumber = info.Current
		
		
		if info.TimeRemaining and module.OrderTimers and module.OrderTimers[brainrotID] then
			module.OrderTimers[brainrotID].TimeRemaining = info.TimeRemaining
			module.OrderTimers[brainrotID].MaxTime = module.OrderTimers[brainrotID].MaxTime or info.TimeRemaining
		end
		


		local getFrame = OrderFrame:FindFirstChild(targetItem)
		local size

		if getFrame then
			local requirement = module.CurrentOrder[info.Path][targetItem]
			getFrame.Quantity.Text = "x"..requirement-newNumber

			local quanity = getFrame.Quantity
			local defaultsize = quanity.Size

			quanity.Rotation = quanity.Rotation + math.random(-35,35)
			quanity.Size += UDim2.new(0,30,0,30)
			getFrame.Size += UDim2.new(0,25,0,25)
			NewTS:Tween(getFrame,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size = UDim2.new(1, 0,1.143, 0, 0)}):Play()

			NewTS:Tween(quanity,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Rotation = 15}):Play()
			NewTS:Tween(quanity,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size = UDim2.new(1, 0,0.23, 0)}):Play()

			local Brainrot = getPlotFolder.Customers:FindFirstChild(brainrotID)

			-- Clone the fruit model from Plants folder instead of tool
			local FruitModel = Plants:FindFirstChild(targetItem)
			if not FruitModel then return end
			local FruitClone = FruitModel:Clone()

			-- Get start position from player's character
			local character = Player.Character
			local startPos = character and character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position + Vector3.new(0, 2, 0) or Vector3.new(0, 5, 0)
			local brainrotCenter, df = Brainrot:GetBoundingBox()
			local targetPos = brainrotCenter.Position

			local function quadraticBezier(p0, p1, p2, t)
				local l1 = p0:Lerp(p1, t)
				local l2 = p1:Lerp(p2, t)
				return l1:Lerp(l2, t)
			end

			local midPoint = (startPos + targetPos) / 2
			local controlPoint = midPoint + Vector3.new(
				math.random(-7, 7),
				math.random(8, 15),
				math.random(-7, 7)
			)

			for _, part in FruitClone:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.Anchored = true
				end
			end

			FruitClone:PivotTo(CFrame.new(startPos))
			FruitClone.Parent = workspace

			local startTime = tick()
			local duration = 0.35
			local fruitConnection
			fruitConnection = game.RunService.RenderStepped:Connect(function()
				local elapsed = tick() - startTime
				local alpha = math.min(elapsed / duration, 1)
				local easedAlpha = 1 - math.cos(alpha * math.pi / 2)
				local currentPos = quadraticBezier(startPos, controlPoint, targetPos, easedAlpha)

				local spinRotation = CFrame.Angles(0, math.rad(alpha * 360 * 2), 0)
				FruitClone:PivotTo(CFrame.new(currentPos) * spinRotation)

				if alpha >= 1 then
					fruitConnection:Disconnect()
					FruitClone:Destroy()

					flowUtil:PlaySound(Sounds.BrainrotSounds["Eat Sound"],Brainrot.PrimaryPart,true)

					local cf, size = Brainrot:GetBoundingBox()
					local centerPos = cf.Position

					local wasMutated
					local mutatedby

					local actualOverhead = Brainrot.PrimaryPart.Attachment:FindFirstChild(brainrotID)
					if info.Mutations then
						for mutationIndex, mutationName in info.Mutations do
							local mutationCache = MutationsData[mutationName]
							local isEffect = mutationCache.IsEffect
							local MutationTemplate = UI.MutationListTemplate

							if not isEffect then
								continue
							end

							local effectFrame = actualOverhead.List.Effects

							if not effectFrame:FindFirstChild(mutationName) then
								wasMutated = true
								VFX.cachedModules["Mutate"]({
									Array = {
										[1] = {
											["Model"] = Brainrot;
											["Mutation"] = mutationName;
										};
									};
								})
								if not actualOverhead.List.Effects.Visible then 
									actualOverhead.List.Effects.Visible = true 
								end
								local newTemplate = MutationTemplate:Clone()
								newTemplate.Parent = actualOverhead.List.Effects
								newTemplate.Name = mutationName
								newTemplate.Text = mutationName
								if mutationCache.Gradient then
									mutationCache.Gradient:Clone().Parent = newTemplate
								end
							end
						end
					end

					if wasMutated then
						flowUtil:PlaySound(Sounds.BrainrotSounds["eatmutated"],Brainrot.PrimaryPart)

						local camera = workspace.CurrentCamera

						local tweenOut = TweenService:Create(camera, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 80})
						tweenOut:Play()

						tweenOut.Completed:Connect(function()
							task.wait(0.05)
							local tweenIn = TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70})
							tweenIn:Play()
						end)

						for i = 1,4 do
							local MutationPop = UI.MutationPop:Clone()
							local NewAttachment = Instance.new("Attachment")
							NewAttachment.Parent = workspace.Terrain
							local random = Random.new()

							NewAttachment.CFrame = CFrame.new(cf.Position) * CFrame.new(0,0,0)
							MutationPop.Parent = NewAttachment

							NewTS:TweenBounce(MutationPop.Frame.UIScale,{Scale = random:NextNumber(0.7,.95)},nil,4)

							MutationPop.Frame.Header.Rotation = math.random(-45,45)

							Spring.target(MutationPop, 2.5, 4, {StudsOffset = vector.create(random:NextNumber(-4,4), random:NextNumber(-5,5), 0)})
							task.delay(0.75,function()
								Spring.target(MutationPop.Frame.Header, 1, 5, {
									["TextTransparency"] = 1,
									["TextStrokeTransparency"] = 1
								})
								Spring.target(MutationPop.Frame.Header.UIStroke, 1, 5, {
									["Transparency"] = 1,
								})

								Spring.target(MutationPop.Frame.Header.Header, 1, 5, {
									["TextTransparency"] = 1,
									["TextStrokeTransparency"] = 1
								})
								Spring.target(MutationPop.Frame.Header.Header.UIStroke, 1, 5, {
									["Transparency"] = 1,
								})
							end)
						end
					end

					local length =  1.15
					local Highlight = Instance.new("Highlight")
					Highlight.Adornee = Brainrot
					Highlight.FillColor = Color3.new(1, 1, 1)
					Highlight.FillTransparency = not wasMutated and 0.3 or 0.1
					Highlight.OutlineTransparency = not wasMutated and 0.3 or 0.1
					Highlight.Parent = Brainrot
					Highlight.Enabled = true
					Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
					local PointLight = Instance.new("PointLight")
					PointLight.Range = 10
					PointLight.Brightness = 1.5
					PointLight.Color = Color3.new(1, 1, 1)
					PointLight.Parent = Brainrot.PrimaryPart

					TweenService:Create(PointLight, TweenInfo.new(length, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0), {
						Range = 0
					}):Play()

					game.Debris:AddItem(PointLight, length)
					game.Debris:AddItem(Highlight, length + 0.45)

					TweenService:Create(Highlight, TweenInfo.new(length + 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						FillTransparency = 1, 
						OutlineTransparency = 1
					}):Play()

					local BrainrotLibraryData = BrainrotLibrary[brainrotName]

					local getScale = CalculateMoney.CalculateScaleFromWeight(info.Weight,BrainrotLibraryData.WeightPool,Models[brainrotName])

					NewTS:TweenBounce(Brainrot, {Scale = getScale}, nil, 3.5)

					local shock = game.ReplicatedStorage.Game.VFX.shock.Attachment:Clone()
					shock.Parent = workspace.Terrain
					shock.CFrame = CFrame.new(centerPos)

					if wasMutated then
						local rainbowConnection
						local elapsed = 0

						rainbowConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
							elapsed += dt
							local hue = (elapsed * 2) % 1
							local rainbowColor = Color3.fromHSV(hue, 1, 1)

							Highlight.FillColor = rainbowColor
							Highlight.OutlineColor = rainbowColor
							PointLight.Color = rainbowColor
							shock.shockwave.Color = ColorSequence.new(rainbowColor)

							if elapsed >= length + 0.25 then
								rainbowConnection:Disconnect()
							end
						end)
					end

					flowUtil:resizeAllParticle(shock,Brainrot:GetScale() * 0.8)
					flowUtil:Emit(shock)

					game.Debris:AddItem(shock,5)

					local baseOffset = BrainrotLibraryData.YOffset or 0.5
					local currentPivot = Brainrot:GetPivot()
					local currentPos = currentPivot.Position

					local allMutations = {}

					actualOverhead.TitleFrame.MoneyPerSecond.Text = "$"..NumberShortener.roundNumber(CalculateMoney.CalculateMoneyPerSecond(brainrotName,info.Weight,info.allMutations,info.Owner:GetAttribute("Rebirths"))).."/s"

					if requirement-newNumber < 0 then
						getFrame.Quantity.Text = "x0"
					end

					if requirement <= newNumber then
						flowUtil:PlaySound(Sounds.BrainrotSounds["ordercomplete"],Brainrot.PrimaryPart)

						getFrame.Rotation += math.random(-45,45)
						TS:Create(getFrame, TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Rotation = 0}):Play()

						TS:Create(getFrame.Completed, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {ImageTransparency = 0}):Play()
						TS:Create(getFrame.Viewport, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {ImageTransparency = 0.7}):Play()
						TS:Create(getFrame.Quantity, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {TextTransparency = 0.7}):Play()
						TS:Create(getFrame.Title, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {TextTransparency = 0.7}):Play()
						TS:Create(getFrame.Quantity.UIStroke, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Transparency = 0.7}):Play()
						TS:Create(getFrame.Title.UIStroke, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Transparency = 0.7}):Play()
					end
				end
			end)
		end
	end,

	["Cleanup"] = function(info)
		PlotFolder = workspace.Plots[info.Plot]

		local OrderOverhead = PlayerGui:FindFirstChild("Order-"..info.ID)
		if not OrderOverhead then  return end
		OrderOverhead:Destroy()

		if module.OrderTimers and module.OrderTimers[info.ID] then
			module.OrderTimers[info.ID] = nil
		end
	end,

}

orderRemote.OnClientEvent:Connect(function(call, info)
	if module.OrderFunctions[call] then
		module.OrderFunctions[call](info)
	end
end)

local function lightenColor(color, amount)
	local hue, saturation, value = color:ToHSV()
	value = math.min(value + amount, 1) -- make lighter
	saturation = saturation * 0.85 -- wash out with saturation
	return Color3.fromHSV(hue, saturation, value) 
end

for name, data in pairs(buttons) do
	local detector = data.button.Button.ClickDetector

	detector.MouseHoverEnter:Connect(function()
		data.button.Button.Color = lightenColor(data.color, 0.5)
	end)

	detector.MouseHoverLeave:Connect(function()
		data.button.Button.Color = data.color
	end)

	local lastClick
	local originalSize = data.button.Button.Size
	local originalPos = data.button.Button.Position

	detector.MouseClick:Connect(function()
		if lastClick then
			return
		end
		lastClick = true

		local pressedSize = Vector3.new(1.75, 0.1, 2.25) 
		local yDifference = (originalSize.Y - pressedSize.Y) / 2 -- keep it in the same spot

		data.button.Button.Size = pressedSize
		data.button.Button.Position = originalPos - Vector3.new(0, yDifference, 0)

		flowUtil:PlaySound(Sounds.GameSounds.PlotButtonClick,data.button.Button,true)

		task.delay(0.1, function()
			lastClick = false
			data.button.Button.Size = originalSize
			data.button.Button.Position = originalPos
		end)
	end)
end

-- Touch detection for mobile users
local function setupTouchDetection()
	local function raycastFromTouch(touchPosition)
		local camera = workspace.CurrentCamera
		local unitRay = camera:ScreenPointToRay(touchPosition.X, touchPosition.Y)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = {DeskFolder}

		local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

		if raycastResult and raycastResult.Instance then
			local hit = raycastResult.Instance

			-- Check if we hit an Accept or Decline button
			for i = 1, 3 do
				local acceptButton = DeskFolder["Desk"..i].Accept.Button
				local declineButton = DeskFolder["Desk"..i].Decline.Button

				if hit == acceptButton or hit:IsDescendantOf(DeskFolder["Desk"..i].Accept) then
					-- Fire to server for Accept button
					PlotRemote:FireServer("DeskButton", {Type = "Accept", DeskNumber = i})

					-- Play visual and audio feedback
					local data = buttons["accept"..i]
					if data then
						local originalSize = acceptButton.Size
						local originalPos = acceptButton.Position
						local pressedSize = Vector3.new(1.75, 0.1, 2.25)
						local yDifference = (originalSize.Y - pressedSize.Y) / 2

						acceptButton.Size = pressedSize
						acceptButton.Position = originalPos - Vector3.new(0, yDifference, 0)
						acceptButton.Color = lightenColor(data.color, 0.5)

						-- Play sound
						flowUtil:PlaySound(Sounds.GameSounds.PlotButtonClick, acceptButton, true)

						task.delay(0.1, function()
							acceptButton.Size = originalSize
							acceptButton.Position = originalPos
							acceptButton.Color = data.color
						end)
					end
					return true

				elseif hit == declineButton or hit:IsDescendantOf(DeskFolder["Desk"..i].Decline) then
					-- Fire to server for Decline button
					PlotRemote:FireServer("DeskButton", {Type = "Decline", DeskNumber = i})

					-- Play visual and audio feedback
					local data = buttons["deny"..i]
					if data then
						local originalSize = declineButton.Size
						local originalPos = declineButton.Position
						local pressedSize = Vector3.new(1.75, 0.1, 2.25)
						local yDifference = (originalSize.Y - pressedSize.Y) / 2

						declineButton.Size = pressedSize
						declineButton.Position = originalPos - Vector3.new(0, yDifference, 0)
						declineButton.Color = lightenColor(data.color, 0.5)

						-- Play sound
						flowUtil:PlaySound(Sounds.GameSounds.PlotButtonClick, declineButton, true)

						task.delay(0.1, function()
							declineButton.Size = originalSize
							declineButton.Position = originalPos
							declineButton.Color = data.color
						end)
					end
					return true
				end
			end
		end
		return false
	end

	-- Listen for touch taps (mobile)
	UserInputService.TouchTap:Connect(function(touchPositions, gameProcessedEvent)
		if gameProcessedEvent then return end

		if #touchPositions > 0 then
			raycastFromTouch(touchPositions[1])
		end
	end)

	
end


setupTouchDetection()

module.CurrentBrainrots = {}

-- HANDLES THE BRAINROT CUSTOMERS ON THE CLIENT SIDE OF THINGS --

local MutationTemplate = UI.MutationListTemplate

spawnRemote.OnClientEvent:Connect(function(call, info)
	if info and info.Plot then PlotFolder = workspace:WaitForChild("Plots"):WaitForChild(info.Plot) end

	if call == "SpawnBrainrot" then -- spawns a CUSTOMER brainrot --
		if PlayerReplica.Data.Settings["ShowBrainrots"] == false then return end
		
		local orderInfo
		if info.OrderData then 
			orderInfo = info.OrderData
			info = info.Data 
		end

		if module.CurrentBrainrots[info.ID] then return end

		module.CurrentBrainrots[info.ID] = info
		local cache = module.CurrentBrainrots[info.ID]
		cache.PlotNumber = info.Plot

		-- spawn & place model --
		local newModel = Models:FindFirstChild(cache.Name):Clone()
		newModel.Parent = PlotFolder.Customers
		newModel.Name = info.ID
		newModel:SetAttribute("Name", cache.Name)
		newModel.PrimaryPart.Anchored = true

		local Calculator = require(Utilities.Calculator)
		local data = BrainrotLibrary[cache.Name]
		local scale = Calculator.CalculateScaleFromWeight(info.Weight,data.WeightPool,Models[cache.Name])

		
		newModel:ScaleTo(scale) -- scale ??

		local TargetCFrame = info.Target
		local CurrentCFrame = info.Position

		local hasReached = info.TestReached or false
		
		local getPlayerForRot
		for _, PLR in game.Players:GetChildren() do if PLR:GetAttribute("Plot") == info.Plot then getPlayerForRot = PLR end end

		if hasReached then
			local spawnPosition = TargetCFrame.Position

			-- Make sure it's facing the right direction using TargetCFrame's orientation
			--local finalCFrame = CFrame.new(spawnPosition) * (TargetCFrame - TargetCFrame.Position)
		
			local finalCFrame = CurrentCFrame
			newModel:PivotTo(finalCFrame)

			cache.Model = newModel
			cache.Mover = LerpMover.new(finalCFrame, 6, newModel, getPlayerForRot)
			-- No movement needed

			-- Play idle animation immediately since it's not moving
			if cache.Mover.IdleTrack then
				cache.Mover.IdleTrack:Play(0.2)
			end
		else
			-- Still moving, spawn at current position and resume movement
			local finalCFrame = CFrame.lookAt(CurrentCFrame.Position, TargetCFrame.Position)
			newModel:PivotTo(finalCFrame)

			cache.Model = newModel
			cache.Mover = LerpMover.new(finalCFrame, 6, newModel, getPlayerForRot)

			local function UpdatePosition(NewCFrame)
				newModel:PivotTo(NewCFrame)
			end

			cache.Mover:MoveTo(TargetCFrame, UpdatePosition)
		end

		local newOverhead = UI.CustomerOverhead:Clone()
		newOverhead.Parent = PlotFolder.Desks["Desk"..info.Path]
		newOverhead.Name = info.ID
		newOverhead.TitleFrame.Visible = false

		local actualOverhead = UI.CustomerOverhead:Clone()
		actualOverhead.Parent = newModel.PrimaryPart.Attachment
		actualOverhead.Name = info.ID
		actualOverhead.TitleFrame.Brainrot.Text = cache.Name
		actualOverhead.TitleFrame.MoneyPerSecond.Text = "$"..CalculateMoney.CalculateMoneyPerSecond(cache.Name,info.Weight,info.Mutations,info.Owner:GetAttribute("Rebirths")).."/s"
		actualOverhead.MaxDistance = 50
		actualOverhead.TitleFrame.Rarity.Text = newModel:GetAttribute("Rarity")
		local getGradient = UI.Gradients[newModel:GetAttribute("Rarity")]:Clone()
		getGradient.Parent = actualOverhead.TitleFrame.Rarity

		for _, mutation in info.Mutations do
			local mutationCache = MutationsData[mutation]
			local isEffect = mutationCache.IsEffect

			local newTemplate = MutationTemplate:Clone()
			if not isEffect then actualOverhead.List.Mutations.Visible = true else actualOverhead.List.Effects.Visible = true end
			newTemplate.Parent = not isEffect and actualOverhead.List.Mutations or actualOverhead.List.Effects
			newTemplate.Name = mutation
			newTemplate.Text = mutation

			if mutationCache.Gradient then
				mutationCache.Gradient:Clone().Parent = newTemplate
			end
		end

		if table.find(info.Mutations,"Gold") then
			flowUtil:PlaySound(Sounds.BrainrotSounds.gold,cache.Model.PrimaryPart)
		elseif table.find(info.Mutations, "Diamond") then
			flowUtil:PlaySound(Sounds.BrainrotSounds.diamond,cache.Model.PrimaryPart)
		elseif table.find(info.Mutations, "Rainbow") then
			flowUtil:PlaySound(Sounds.BrainrotSounds.rainbow,cache.Model.PrimaryPart)
		elseif table.find(info.Mutations, "Secret") then
			flowUtil:PlaySound(Sounds.BrainrotSounds.secret,cache.Model.PrimaryPart)
		elseif table.find(info.Mutations, "Petrified") then
			flowUtil:PlaySound(Sounds.BrainrotSounds.petrified,cache.Model.PrimaryPart)
		end

		actualOverhead.Size = UDim2.new(10.2, 0,3.4, 0)

		for _, indMutation in info.Mutations do
			VFX.cachedModules["Mutate"]({
				Array = {
					[1] = {
						["Model"] = newModel;
						["Mutation"] = indMutation;
					};
				};
			})
		end

		if orderInfo then -- Spawning brainrot that already existed, load their current order data. --
			warn("-- LOADING ORDER INFO FOR PLAYER.. -- : "..info.Plot)

			-- Create order UI. --
			module.OrderFunctions["CreateOrderUI"]({
				["Path"] = info.Path;
				["ID"] = info.ID;
				["Plot"] = info.Plot;
			})

			-- Load current order frames based on the progress of the order. --
			local Requirements = orderInfo.Requirements
			local Currents = orderInfo.Currents

			for fruit, amount in Requirements do
				local getAmount = amount 
				if Currents[fruit] then warn("PREV: "..getAmount); getAmount -= #Currents[fruit]; warn("AFTER: "..getAmount) end

				module.OrderFunctions["AddOrder"]({
					["Path"] = info.Path;
					["ID"] = info.ID;
					["Item"] = {Name = fruit; Amount = getAmount};
					["Plot"] = info.Plot;
				})
			end

			-- Visible. --
			module.OrderFunctions["OrderVisible"]({
				["Path"] = info.Path;
				["Plot"] = info.Plot;
				["ID"] = info.ID;
			})
		end
	elseif call == "MoveBrainrot" then -- moves brainrot --
		local cache = module.CurrentBrainrots[info.ID]
		if not cache then return end
		if cache.Mover._moving then
			cache.Mover:Cancel()
		end

		local function UpdatePosition(NewCFrame)
			cache.Model:PivotTo(NewCFrame)
		end

		cache.Mover:MoveTo(info.Target, UpdatePosition)
	elseif call == "DeleteBrainrot" then -- deletes a brainrot --
		local cache = module.CurrentBrainrots[info.ID]
		if not cache then return end

		if PlayerGui:FindFirstChild("Order-"..info.ID) then
			PlayerGui:FindFirstChild("Order-"..info.ID):Destroy()
		end

		if not info.Platform then
			if info.Fulfilled then
				local Character = info.Owner.Character

				if not Character then
					
					return 
				end

				local Humanoid = Character:FindFirstChild("Humanoid")
				local RootPart = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso")

				if not RootPart then
					
					return
				end

				flowUtil:PlaySound(Sounds.BrainrotSounds.cheer, cache.Model.PrimaryPart, true, true)
				local Brainrot = cache.Model
				Brainrot.PrimaryPart.Attachment[info.ID]:Destroy()
				-- Create highlight
				local Highlight = Instance.new("Highlight")
				Highlight.Adornee = Brainrot
				Highlight.FillColor = Color3.new(1, 1, 1)
				Highlight.FillTransparency = 0
				Highlight.OutlineTransparency = 0
				Highlight.Parent = Brainrot
				Highlight.Enabled = true
				Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				
				
				
				local originalBBoxCFrame, originalSize = Brainrot:GetBoundingBox()
				local originalCenter = originalBBoxCFrame.Position
				local originalPivot = Brainrot:GetPivot()
				local originalScale = Brainrot:GetScale()
				-- Calculate the offset from pivot to bounding box center
				local pivotToCenterOffset = originalCenter - originalPivot.Position

				-- Shrink the brainrot while keeping center position
				local scaleConnection
				scaleConnection = game:GetService("RunService").RenderStepped:Connect(function()
					-- Get current pivot
					local currentPivot = Brainrot:GetPivot()

					-- Calculate where the center should be based on current pivot and original offset
					local currentScale = Brainrot:GetScale()
					local scaledOffset = pivotToCenterOffset * (currentScale / originalScale)
					local targetCenter = currentPivot.Position + scaledOffset

					-- Move pivot so the scaled center stays at original position
					local correction = originalCenter - targetCenter
					Brainrot:PivotTo(currentPivot + correction)
				end)
			
				
				
				NewTS:TweenBounce(Brainrot, {Scale = 0.5}, 1, 4)
				task.wait(0.225)
				
				scaleConnection:Disconnect()
			
			

				-- Get target position (player's torso)
				local targetPos = RootPart.Position
				-- Tween the position
				local pivotCFrame = Brainrot:GetPivot()
				local startPos = pivotCFrame.Position
				

				-- Quadratic Bezier curve function
				local function quadraticBezier(p0, p1, p2, t)
					local l1 = p0:Lerp(p1, t)
					local l2 = p1:Lerp(p2, t)
					return l1:Lerp(l2, t)
				end

				-- Create control point above and to the side for nice curve
				local midPoint = (startPos + targetPos) / 2
				local controlPoint = midPoint + Vector3.new(
					math.random(-9, 9), -- Random X offset
					math.random(10, 20),   -- Up in the air (5-8 studs)
					math.random(-9, 9)  -- Random Z offset
				)

				-- Animate along bezier curve
				local startTime = tick()
				local duration = 0.65
				local connection
				connection = game:GetService("RunService").RenderStepped:Connect(function()
					local elapsed = tick() - startTime
					local alpha = math.min(elapsed / duration, 1)

					-- Ease in for smooth acceleration toward player
					local easedAlpha = 1 - math.cos(alpha * math.pi / 2)

					-- Calculate position on bezier curve
					local currentPos = quadraticBezier(startPos, controlPoint, targetPos, easedAlpha)

					-- Update position (keep original rotation)
					Brainrot:PivotTo(CFrame.new(currentPos) * (pivotCFrame - pivotCFrame.Position))

					if alpha >= 1 then
						connection:Disconnect()
						for _, Part in Brainrot:GetDescendants() do
							if Part:IsA("BasePart") or Part:IsA("Decal") or Part:IsA("Texture") or Part:IsA("MeshPart") then
								TweenService:Create(Part, TweenInfo.new(0.1,Enum.EasingStyle.Linear,Enum.EasingDirection.In), {Transparency = 1}):Play()
							end
						end

						Brainrot:Destroy()
						
						local shock = game.ReplicatedStorage.Game.VFX.shock.Attachment:Clone()
						shock.Parent = workspace.Terrain
						shock.CFrame = CFrame.new(RootPart.Position)
						
						if Player == info.Owner then
							flowUtil:PlaySound(Sounds.BrainrotSounds.claim, RootPart, true)
						end
						
						flowUtil:Emit(shock)
						
					
						local length =  1.15
						local plrHighlight = Instance.new("Highlight")
						plrHighlight.Adornee = Character
						plrHighlight.FillColor = Color3.new(1, 1, 1)
						plrHighlight.FillTransparency = 0.35 
						plrHighlight.OutlineTransparency = 0.35
						plrHighlight.Parent = Character
						plrHighlight.Enabled = true
						plrHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
						TweenService:Create(plrHighlight, TweenInfo.new(length + 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							FillTransparency = 1, 
							OutlineTransparency = 1
						}):Play()

						-- Optional: Play collection sound/effect
						
						
					end
					

				end)
				
				
				task.wait(2)
			else

				local cf, size = cache.Model:GetBoundingBox()
				local centerPos = cf.Position

				local poof = game.ReplicatedStorage.Game.VFX.Part.Attachment:Clone()
				poof.Parent = workspace.Terrain
				poof.CFrame = CFrame.new(centerPos)

				flowUtil:resizeAllParticle(poof,cache.Model:GetScale())
				flowUtil:Emit(poof)

				game.Debris:AddItem(poof,5)


				flowUtil:PlaySound(Sounds.BrainrotSounds.angry,cache.Model.PrimaryPart,true,true)
			end
			
			if info.OrderFailed then
				flowUtil:PlaySound(Sounds.BrainrotSounds.AngryDeny,cache.Model.PrimaryPart,true,true)
			end

			if cache.Mover._moving then
				cache.Mover:Cancel()
			end

			for i,v in info do
		
			end

			PlotFolder = workspace.Plots[info.Plot]

			if PlotFolder.Desks["Desk"..info.Path]:FindFirstChild(info.ID) then
				PlotFolder.Desks["Desk"..info.Path]:FindFirstChild(info.ID):Destroy()
			end

			cache.Model:Destroy()
			module.CurrentBrainrots[info.ID] = nil
		else
			cache.Model:Destroy()
			module.CurrentBrainrots[info.ID] = nil
		end
	elseif call == "MutateBrainrot" then -- adds a mutation to an existing customer brainrot --
		local cache = module.CurrentBrainrots[info.ID]
		if not cache then return end
		local mutation = info.Mutation
		local model = cache.Model

		local actualOverhead = model.PrimaryPart.Attachment[info.ID]
		local mutationCache = MutationsData[mutation]
		local isEffect = mutationCache.IsEffect
		local newTemplate = MutationTemplate:Clone()
		if not isEffect then actualOverhead.List.Mutations.Visible = true else actualOverhead.List.Effects.Visible = true end
		newTemplate.Parent = not isEffect and actualOverhead.List.Mutations or actualOverhead.List.Effects
		newTemplate.Name = mutation
		newTemplate.Text = mutation

		if mutationCache.Gradient then
			mutationCache.Gradient:Clone().Parent = newTemplate
		end

		VFX.cachedModules["Mutate"]({
			Array = {
				[1] = {
					["Model"] = model;
					["Mutation"] = mutation;
				};
			};
		})
	elseif call == "SpawnPlatformBrainrot" then -- spawns a PLATFORM brainrot --
		if module.CurrentBrainrots[info.ID] then return end
		module.CurrentBrainrots[info.ID] = info
		local cache = module.CurrentBrainrots[info.ID]

		-- Use server's MPS value directly (no calculation needed)
		cache.PlotNumber = info.Plot
		cache.Model = Models:FindFirstChild(cache.Name):Clone()
		cache.MPS = info.MPS  -- Use server value
		cache.StoredMoney = info.Money

		local newModel = cache.Model
		newModel.Parent = PlotFolder.Brainrots
		newModel:PivotTo(PlotFolder.Platforms[cache.Platform].Place.CFrame * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, newModel:GetAttribute("YOffset") or 0, 0))

		-- overhead
		local newOverhead = UI.CustomerOverhead:Clone()
		newOverhead.TitleFrame.Brainrot.Text = cache.Name
		newOverhead.TitleFrame.MoneyPerSecond.Text = "$"..cache.Money.." ($"..NumberShortener.roundNumber(info.MPS).."/s)"  -- Use info.MPS
		newOverhead.TitleFrame.Rarity.Text = newModel:GetAttribute("Rarity")
		if newOverhead.TitleFrame.Rarity:FindFirstChild(newModel:GetAttribute("Rarity")) then
			newOverhead.TitleFrame.Rarity:FindFirstChild(newModel:GetAttribute("Rarity")).Enabled = true
		end

		local totalOfflineMoney = info.OfflineMoney
		if totalOfflineMoney > 0 then
			newOverhead.TitleFrame.OfflineMoney.Visible = true
			newOverhead.TitleFrame.OfflineMoney.Text = "($"..NumberShortener.roundNumber(totalOfflineMoney).." Offline)"
		end

		if info.Platform == "Super" then
			newOverhead.TitleFrame.MoneyPerSecond.TextColor3 = Color3.fromRGB(246, 161, 30)
		else
			newOverhead.TitleFrame.MoneyPerSecond.TextColor3 = Color3.fromRGB(47, 255, 55)
		end

		newOverhead.Parent = newModel.PrimaryPart.Attachment
		newOverhead.Size = UDim2.new(10.2, 0, 3.4, 0)

		VFX.cachedModules["Scale"]({
			Array = {
				[1] = {
					["Model"] = newModel;
					["Scale"] = cache.Weight;
				};
			};
		})

		for _, mut in cache.Mutations do
			VFX.cachedModules["Mutate"]({
				Array = {
					[1] = {
						["Model"] = newModel;
						["Mutation"] = mut;
					};
				};
			})
			local mutationCache = MutationsData[mut]
			local isEffect = mutationCache.IsEffect
			local newTemplate = MutationTemplate:Clone()
			if not isEffect then newOverhead.List.Mutations.Visible = true else newOverhead.List.Effects.Visible = true end
			newTemplate.Parent = not isEffect and newOverhead.List.Mutations or newOverhead.List.Effects
			newTemplate.Name = mut
			newTemplate.Text = mut
			local mutationCache = MutationsData[mut]
			mutationCache.Gradient:Clone().Parent = newTemplate
		end

		-- animation
		local loadAnimation = newModel.Humanoid:LoadAnimation(newModel.Idle)
		loadAnimation:Play()
		cache.Idle = loadAnimation
	elseif call == "UpdateOverhead" then
		local getRot = module.CurrentBrainrots[info.ID]
		if not getRot then return end
		local getOverhead = getRot.Model.PrimaryPart.Attachment.CustomerOverhead

		getRot.Money = info.Money or 0
		getRot.MPS = info.MPS or 0

		if not info.OfflineMoney then
			getOverhead.TitleFrame.OfflineMoney.Visible = false
		end

		getOverhead.TitleFrame.MoneyPerSecond.Text = "$"..NumberShortener.roundNumber(getRot.Money).." ($"..NumberShortener.roundNumber(getRot.MPS).."/s)"

		if info.Platform == "Super" then
			getOverhead.TitleFrame.MoneyPerSecond.TextColor3 = Color3.fromRGB(246, 161, 30)
		else
			getOverhead.TitleFrame.MoneyPerSecond.TextColor3 = Color3.fromRGB(47, 255, 55)
		end
	elseif call == "FruitMutationText" then
		
		local getBillboardGUI = Player.PlayerGui:WaitForChild(info.Name,math.huge)

		for _, mutation in info.Mutations do
			local newMutTemplate = UI.MutationListTemplate:Clone()
			newMutTemplate.Parent = getBillboardGUI.Frame.Top.Extra
			local newMutGradient = Modules.Libraries.MutationsData[mutation]:Clone()
			newMutGradient.Parent = newMutTemplate
			newMutTemplate.Text = mutation
			newMutTemplate.TextTransparency = 1
			newMutTemplate.UIStroke.Transparency = 1
		end
	elseif call == "StartTimers" then
		local times = {["Legendary"] = 300; ["Mythic"] = 600}
		local currTimes = {["Legendary"] = 0; ["Mythic"] = 0}

		local localPlotFolder = workspace.Plots[Player:GetAttribute("Plot")]
		local timers = localPlotFolder.Timers.SurfaceGui

		task.spawn(function()
			while wait(1) do
				for timeName, timeRequirement in times do
					currTimes[timeName] += 1

					if currTimes[timeName] >= timeRequirement then
						currTimes[timeName] = 0
					end

					local remainingTime = timeRequirement - currTimes[timeName]
					local totalTime = timeRequirement
					local percVal = remainingTime/totalTime

					local function SecondsToTime(seconds)
						local hours = math.floor(seconds / 3600)
						local minutes = math.floor((seconds % 3600) / 60)
						local secs = math.floor(seconds % 60)

						return string.format("%02d:%02d", minutes, secs)
					end

					TweenService:Create(timers[timeName].Background.Bar, TweenInfo.new(0.1), {Size = UDim2.new(1 - percVal, 0, 1, 0)}):Play()
					timers[timeName].Number.Text = SecondsToTime(remainingTime)
				end
			end
		end)
	end
end)

task.spawn(function() -- just adds money to text labels based on current cache, server should update when claims and stuff happen --
	while wait(1) do
		for ID, cache in module.CurrentBrainrots do
			if cache.MPS then
				local getOverhead = cache.Model.PrimaryPart.Attachment.CustomerOverhead
				local totalMoney = cache.Money + cache.MPS
				getOverhead.TitleFrame.MoneyPerSecond.Text = "$"..NumberShortener.roundNumber(totalMoney).." ($"..NumberShortener.roundNumber(cache.MPS).."/s)"
				cache.Money += cache.MPS
			end
		end		
	end
end)

local function FormatTime(seconds)
	seconds = math.floor(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60

	return string.format("%02d:%02d", minutes, secs)
end

timerRemote.OnClientEvent:Connect(function(call, info)
	if call == "UpdateBillboardTimer" then -- updates the timer that says legendary in: or mythic in: --
		local getPlot = workspace.Plots[Player:GetAttribute("Plot")]
		local Timer = getPlot.Timers.SurfaceGui[info.Timer]
		local NextTime = info.Time

		local timePassed = false

		local TotalSeconds = NextTime - tick()
		local SecondsPassed = 0

		task.spawn(function()
			while NextTime > tick() do
				local SecondsUntil = NextTime - tick()

				Timer.Number.Text = FormatTime(SecondsUntil)

				TS:Create(Timer.Background.Bar, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Size = UDim2.new(SecondsPassed/TotalSeconds, 0, 1, 0)}):Play()

				task.wait(1)

				SecondsPassed += 1
			end
		end)
	end
end)

PlotRemote.OnClientEvent:Connect(function(call, info)
	if call == "PlotLoaded" then
		local getFolder = workspace.Plots:FindFirstChild(info)
		if not getFolder then return end 

		for i = 1,3 do
			local newZone = Zone.new(getFolder.DeskZones[i])

			newZone.localPlayerEntered:Connect(function(playerWhoEntered)
				if playerWhoEntered == Player then
					NewTS:TweenBounce(PlayerGui.BackpackGui.Backpack,{Position = UDim2.new(0, 0, 0.15, 0)},nil,4)
					module.OpenOrderZone = i 
					
					-- Reset to level 1 (fruit types) when entering zone
					-- populateFruitList handles the animation internally
					populateFruitList(true)
					
					-- Tween UI elements in
					NewTS:TweenBounce(giveFruitUI,{Position = UDim2.new(0.5, 0, 0.8, 0)},nil,4)
					NewTS:TweenBounce(MainUI.MainUI.Currency,{Position = UDim2.new(0.001, 0, 1, 0)},nil,4)
					NewTS:TweenBounce(MainUI.Left,{Position = UDim2.new(-0.15, 0, 0.5, 0)},nil,4)
				end
			end)

			newZone.localPlayerExited:Connect(function(playerWhoEntered)
				if playerWhoEntered == Player then
					NewTS:TweenBounce(PlayerGui.BackpackGui.Backpack,{Position = UDim2.new(0, 0, 0, 0)},nil,4)
					-- Tween UI elements out
					NewTS:TweenBounce(giveFruitUI,{Position = UDim2.new(0.5, 0, 1.1, 0)},nil,4)
					NewTS:TweenBounce(MainUI.MainUI.Currency,{Position = UDim2.new(0.001, 0, 0.89, 0)},nil,4)
					NewTS:TweenBounce(MainUI.Left,{Position = UDim2.new(0.005, 0, 0.5, 0)},nil,4)

					-- Animate fruit frames out
					for _, frame in giveFruitList:GetChildren() do
						if frame:IsA("Frame") and frame.Name ~= "OrderTemplate" and frame:FindFirstChild("UIScale") then
							NewTS:TweenBounce(frame.UIScale, {Scale = 0}, nil, 4)
						end
					end
					
					-- Reset selection state when exiting
					module.FruitSelectionLevel = 1
					module.SelectedFruitType = nil
				end
			end)
		end
	end
end)

return module