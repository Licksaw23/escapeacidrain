-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera

-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Marketplace = game:GetService("MarketplaceService")

-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries

-- remotes --
local orderRemote = RS.Remotes.Order
local spawnRemote = RS.Remotes.Spawn
local adminRemote = RS.Remotes.Admin
local codesRemote = RS.Remotes.Code
local UpdateSetting = RS.Remotes.Setting

-- modules --
local NewTS = require(Utilities.Tweener)
local Spring = require(Utilities.Tweener.Spring)
local ItemLibrary = require(Libraries.ItemsData)
local flowUtil = require(Utilities.flowUtil)
local ViewportFitter = require(Utilities.ViewportFitter)
local LerpMover = require(Utilities.LerpMover)
local MutationsData = require(Libraries.MutationsData)
local CalculateMoney = require(Utilities.Calculator)
local GetScale = require(script.Parent.Parent.Parent.Handlers.VFX.Scale)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local VFX = require(script.Parent.Parent.Parent.Handlers.VFX)
local Zone = require(Utilities.Zone)
local NumberShortener = require(Utilities.NumberShortener)
local Icon = require(Utilities.Satchel.Packages.topbarplus)

-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
local ShopUI = MainUI.Shop

local MainScroller = ShopUI.Main.ScrollingFrame
local TypeScroller = ShopUI.Main.Categories
local ButtonsFrame = MainScroller.Buttons

local Registry = require(script.Parent.Parent.Parent.Registry)

-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

-- module --
local module = {}

local function moveObjectsOfTypeToParent(currentParent, currType, newParent, attribs)
	for _, child in currentParent:GetChildren() do
		if child:IsA(currType) then
			child.Parent = newParent
			for a,b in attribs do child[a] = b end
		end
	end
end

for _, button in ButtonsFrame:GetChildren() do
	if not button:IsA("Frame") then continue end
	
	button.Button.MouseButton1Click:Connect(function()
		Registry.Registered["HUD"].OpenFrame(MainUI[button.Name])
	end)
end

-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

local function ActivateOverlay(frame, destObj, skip)
	local newOverlay = script.OwnedOverlay:Clone()
	newOverlay.Parent = frame
	
	if not skip then
		destObj:Destroy()
	end
end

local function UpdateFramePrice(button, id, infoType)
	task.spawn(function()
		local success, productInfo = pcall(function()
			return Marketplace:GetProductInfo(id, infoType)
		end)
		
		if success and productInfo then
			local price = productInfo.PriceInRobux
			if price and button and button.Parent then
				local textLabel = button.Parent:FindFirstChild("TextLabel")
				if textLabel then
					textLabel.Text = "" .. tostring(price)
				end
			end
		end
	end)
end

-- owned / preventions & price setup --
for _, Descendant in MainScroller:GetDescendants() do
	if Descendant:GetAttribute("PromptGamepass") then
		local getFrame = Descendant.Parent.Parent
		local id = Descendant:GetAttribute("PromptGamepass")
		
		-- Set price
		UpdateFramePrice(Descendant, id, Enum.InfoType.GamePass)
		
		if Marketplace:UserOwnsGamePassAsync(Player.UserId, id) then
			ActivateOverlay(getFrame, Descendant.Parent)
		end
	elseif Descendant:GetAttribute("PromptPurchase") then
		local getFrame = Descendant.Parent.Parent
		local id = Descendant:GetAttribute("PromptPurchase")
		
		-- Set price
		UpdateFramePrice(Descendant, id, Enum.InfoType.Product)
		
		if getFrame.Parent.Name == "Bundles" then
			if PlayerData.Purchases[tostring(id)] and PlayerData.Purchases[tostring(id)] > 0 then
				ActivateOverlay(getFrame, Descendant.Parent, true)
			end
		end
	end
end

for _, CategoryFrame in TypeScroller:GetChildren() do
	if CategoryFrame:IsA("Frame") then
		CategoryFrame.Button.MouseButton1Click:Connect(function()
			local targetFrame = MainScroller:FindFirstChild(CategoryFrame.Name)
			if targetFrame then
				-- Calculate the Y position to scroll to (based on target frame's position)
				local targetY = targetFrame.AbsolutePosition.Y - MainScroller.AbsolutePosition.Y + MainScroller.CanvasPosition.Y
				
				-- Smoothly tween to the position
				TweenService:Create(MainScroller, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {
					CanvasPosition = Vector2.new(0, targetY - 40)
				}):Play()
			end
		end)
	end
end

local serverLuckFrame = MainScroller.Boosts.ServerLuck

workspace:GetAttributeChangedSignal("ServerLuck"):Connect(function()
	local newLuck = workspace:GetAttribute("ServerLuck")
	
	if newLuck == 10 then
		serverLuckFrame.Current.Text = ""
		serverLuckFrame.After.Text = ""
		serverLuckFrame.Middle.Text = "10x (MAX)"
	else
		serverLuckFrame.Current.Text = tostring(newLuck).."x"
		serverLuckFrame.After.Text = tostring(newLuck + 2).."x"
		serverLuckFrame.Middle.Text = "->"
	end
end)



local function setupListener(indValue)
	local function updateFrame(foundID)
		for _, desc in MainScroller:GetDescendants() do
			if desc:GetAttribute("PromptPurchase") then
				if tonumber(desc:GetAttribute("PromptPurchase")) ~= tonumber(foundID) then continue end

				if desc.Parent.Parent.Parent.Name == "Bundles" then
					if #desc.Parent.Parent.Parent:GetChildren() == 1 then
						desc.Parent.Parent.Parent.Parent.BundlesText.Visible = false
						desc.Parent.Parent.Parent:Destroy()
					else
						desc.Parent.Parent:Destroy()
					end
				end
			end
		end
	end

	PlayerReplica:ListenToChange({"Purchases", indValue}, function(newValue, oldValue)
		updateFrame(indValue)
	end)

	updateFrame(indValue)
end

PlayerReplica:ListenToArrayInsert({"Purchases"}, function(index, value)
	setupListener(index)
end)

for indexValue, purchaseValue in PlayerData.Purchases do
	setupListener(indexValue)
end

-- DataTick countdown timer system --
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, mins, secs)
end

local function setupDataTickTimers()
	local firstJoin = PlayerData.FirstJoin
	if not firstJoin then return end
	
	for _, descendant in MainScroller:GetDescendants() do
		if descendant:IsA("TextLabel") and descendant:GetAttribute("DataTick") then
			local dataTick = descendant:GetAttribute("DataTick")
			local originalText = descendant.Text
			local endTime = firstJoin + dataTick
			
			-- Update timer every second
			task.spawn(function()
				while descendant and descendant.Parent do
					local currentTime = tick()
					local remaining = endTime - currentTime
					
					if remaining <= 0 then
						-- Timer expired - destroy parent (and parent.parent if empty)
						local parent = descendant.Parent
						local grandparent = parent and parent.Parent
						
						if parent then
							parent:Destroy()
							
							-- Check if grandparent has no more children (excluding non-Frame children like UIListLayout)
							if grandparent then
								local hasFrameChildren = false
								for _, child in grandparent:GetChildren() do
									if child:IsA("Frame") then
										hasFrameChildren = true
										break
									end
								end
								
								if not hasFrameChildren then
									-- Hide BundlesText if it exists
									local greatGrandparent = grandparent.Parent
									if greatGrandparent then
										local bundlesText = greatGrandparent:FindFirstChild("BundlesText")
										if bundlesText then
											bundlesText.Visible = false
										end
									end
									grandparent:Destroy()
								end
							end
						end
						break
					end
					
					descendant.Text = originalText .. " " .. formatTime(remaining)
					task.wait(1)
				end
			end)
		end
	end
end

setupDataTickTimers()

return module