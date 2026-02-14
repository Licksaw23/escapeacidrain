-- player --

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera

-- services --

local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

-- data --


-- folders --

local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Remotes = RS.Remotes
local Utilities = Modules.Utilities
local UITemplates = GameFolder.UI

-- remotes --

local UIRemote = Remotes.UI

-- modules --

local NewTS = require(Utilities.Tweener)
local NumberShortener = require(RS.Game.Modules.Utilities.NumberShortener)
local PromptModule = require(script["Prompt [Client]"])

local RainbowGradient = require(RS.Game.Modules.Utilities.RainbowGradient):Init()
local SecretGradient = require(RS.Game.Modules.Utilities.SecretGradient):Init()
local OldSecretGradient = require(RS.Game.Modules.Utilities.OldSecretGradient):Init()

for _, InitializedModule in script:GetChildren() do
	if InitializedModule:IsA("ModuleScript") then
		pcall(function()
			require(InitializedModule)
		end)
	end
end

-- ui --

local MainUI = PlayerGui:WaitForChild("MainUI")
local BackpackGUI = PlayerGui:WaitForChild("BackpackGui")

-- // code \\ --

local HUD = {}

--local CurrentBoost = PlayerGui:FindFirstChild("FriendBoost").FriendBoost
--local CurrentShadow = PlayerGui:FindFirstChild("FriendBoost").Shadow
--local function updateFriendBoost()
--	local friendBoost = Player:GetAttribute("FriendBoost") or 0
--	CurrentBoost.Text = string.format("Friend Boost: +%d%%", math.floor(friendBoost * 10))
--	CurrentShadow.Text = string.format("Friend Boost: +%d%%", math.floor(friendBoost * 10))
--end

---- Connect to attribute changes
--Player:GetAttributeChangedSignal("FriendBoost"):Connect(updateFriendBoost)

---- Initial update
--updateFriendBoost()

-- update cash --






-- item notifications --

local function giftFunc(one, two, sentData)
	local ID = sentData.ID
	local Dependency = sentData.Dependency

	local prompts = {}

	for _, player in game.Players:GetChildren() do
		if player ~= Player then
			local newProximityPrompt = Instance.new("ProximityPrompt")
			newProximityPrompt.Name = "PROMPT"
			newProximityPrompt.ActionText = "Gift Brainrot"
			newProximityPrompt:SetAttribute("PromptText", one)
			newProximityPrompt:SetAttribute("BoldText", two)
			newProximityPrompt:SetAttribute("PromptType", "GiftBrainrot")
			newProximityPrompt:SetAttribute("Offset", Vector3.new(0,5,0))
			newProximityPrompt:SetAttribute("PromptData", ID)
			newProximityPrompt:SetAttribute("BrainrotName", sentData.Brainrot)
			newProximityPrompt.RequiresLineOfSight = false
			newProximityPrompt.Parent = player.Character.HumanoidRootPart
			table.insert(prompts, newProximityPrompt)
		end
	end

	local tConn;
	tConn = Dependency.AncestryChanged:Connect(function()
		for _, prompt in prompts do
			prompt:Destroy()
		end
		tConn:Disconnect()
	end)
end

UIRemote.OnClientEvent:Connect(function(call, sentData)
	if call == "ItemNotification" then
		HUD.ItemAdded(sentData.Text, sentData.Color)
	elseif call == "TopNotification" then
		HUD.TopNotification(sentData)
	elseif call == "Prompt" then
		PromptModule.CreatePrompt(sentData.Text, sentData.Type, sentData, HUD.OpenFrame, HUD.CloseFrame)
	elseif call == "Timer" then
		HUD.Passive({
			["Text"] = sentData.Text;
			["Gradient"] = sentData.Gradient;
			["Time"] = sentData.Time;
		})
	elseif call == "GiftBrainrotPrompt" then
		giftFunc("Gift", "Brainrot", sentData)
	elseif call == "GiftItemPrompt" then
		giftFunc("Gift", "Item", sentData)
	end
end)

-- frame open / close --

local Blur = Instance.new("BlurEffect", game.Lighting)
Blur.Size = 0

HUD.OpenedFrame = nil

local TweenTime = 0.3

HUD.OpenFrame = function(frame)
	-- close if current open --
	-- if current open == frame then close all --

	if HUD.OpenedFrame ~= nil then
		if HUD.OpenedFrame == frame then
			HUD.CloseFrame(frame)
			return
		else
			HUD.OpenedFrame.Visible = false
		end
	else
		TS:Create(CurrentCamera, TweenInfo.new(TweenTime), {FieldOfView = 80}):Play()
		TS:Create(Blur, TweenInfo.new(TweenTime), {Size = 8}):Play()
		TS:Create(MainUI.MainUI.LeftSide, TweenInfo.new(TweenTime), {Position = UDim2.new(-0.1, 0, 0.5, 0)}):Play()
	end

	frame.Visible = true
	frame.Position = UDim2.new(0.5, 0, 0.6, 0)

	NewTS:TweenBounce(frame, {Position = UDim2.new(0.5, 0, 0.5, 0)}, nil, 2.5)
	HUD.OpenedFrame = frame
end

HUD.CloseFrame = function(frame)
	TS:Create(CurrentCamera, TweenInfo.new(TweenTime), {FieldOfView = 70}):Play()
	TS:Create(Blur, TweenInfo.new(TweenTime), {Size = 0}):Play()
	TS:Create(MainUI.MainUI.LeftSide, TweenInfo.new(TweenTime), {Position = UDim2.new(0, 0, 0.5, 0)}):Play()
	frame.Visible = false
	HUD.OpenedFrame = nil
end

-- item added --

HUD.ItemDelay = nil
HUD.ItemText = nil

local addedNotiTemplate = UITemplates.ItemNotiAdded
local posUp = UDim2.new(addedNotiTemplate.Position.X.Scale, 0, addedNotiTemplate.Position.Y.Scale - 0.05, 0)
local posDown = UDim2.new(addedNotiTemplate.Position.X.Scale, 0, addedNotiTemplate.Position.Y.Scale + 0.05, 0)
local normalPos = addedNotiTemplate.Position

local notiFadeTime = 0.4

HUD.ItemAdded = function(txt, color)
	if Player:GetAttribute("ItemNotifications") == false then return end 

	local newText =	addedNotiTemplate:Clone()
	newText.Parent = PlayerGui.MainUI.MainUI
	newText.UIStroke.Transparency = 1
	newText.TextTransparency = 1
	newText.Position = posUp
	newText.TextColor3 = color
	newText.Text = txt
	newText.Visible = true

	TS:Create(newText, TweenInfo.new(notiFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = normalPos;
		TextTransparency = 0;
	}):Play(); TS:Create(newText.UIStroke, TweenInfo.new(notiFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Transparency = 0}):Play()

	-- handle actives --
	if HUD.ItemDelay then
		task.cancel(HUD.ItemDelay)
	end

	if HUD.ItemText then
		HUD.ItemAddedRemove()
	end

	-- cleanup --
	HUD.ItemText = newText
	HUD.ItemDelay = task.delay(3, function()
		HUD.ItemAddedRemove()
	end)
end

HUD.ItemAddedRemove = function()
	local savedTXT = HUD.ItemText
	HUD.ItemText = nil

	TS:Create(savedTXT, TweenInfo.new(notiFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = posDown;
		TextTransparency = 1;
	}):Play(); TS:Create(savedTXT.UIStroke, TweenInfo.new(notiFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Transparency = 1}):Play()
end

-- luck / passive notis --

local PassiveList = MainUI.MainUI.Actives
local PassiveTemplate = PassiveList.CurrencyLabel
local MultiplierList = MainUI.MainUI.Multipliers
local MultiplierTemplate = MultiplierList.MultiplierTemplate

HUD.Counters = {}

local function SecondsToTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end


-- Initialize HUD.Counters if it doesn't exist
HUD.Counters = HUD.Counters or {}

HUD.Passive = function(array)
	local newNumberSplitter = string.split(array.Text, "x ")
	local newTemp = PassiveTemplate:Clone()
	newTemp.Parent = PassiveList
	newTemp.Text = array.Text.." ("
	newTemp:FindFirstChild(array.Gradient).Enabled = true
	local timeInSeconds = array.Time

	if HUD.Counters[newNumberSplitter[2]] then
		HUD.Counters[newNumberSplitter[2]].Frame:Destroy()
	end

	HUD.Counters[newNumberSplitter[2]] = {
		Total = timeInSeconds;
		Start = tick();
		BaseText = array.Text; -- Store the base text
		Frame = newTemp;
	}

	local timeLeft = timeInSeconds

	newTemp.Text = array.Text.." ("..SecondsToTime(timeLeft)..")"
	newTemp.Visible = true
	newTemp.TextTransparency = 1
	newTemp.UIStroke.Transparency = 1
	TS:Create(newTemp, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
	TS:Create(newTemp.UIStroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
end

HUD.Multiplier = function(array)
	local newMultTemplate

	if MultiplierList:FindFirstChild(array.Name) then
		newMultTemplate = MultiplierList[array.Name]
	else
		newMultTemplate = MultiplierTemplate:Clone()
		newMultTemplate.Parent = MultiplierList

		local top = array.Name

		local luckSplit = string.split(array.Name, "Luck")

		if #luckSplit > 1 and luckSplit[1] ~= "Luck" then
			top = luckSplit[1].." Luck"
		elseif array.Name == "Luck" then
			top = "Total Luck"
		end

		local multSplit = string.split(array.Name, "Multiplier")

		if #multSplit > 1 and multSplit[1] ~= "Multiplier" then
			top = "Cash"
		end

		newMultTemplate.MouseEnter:Connect(function()
			HUD.MouseHover({
				["Top"] = top.." Multiplier";
				["Bottom"] = "+"..math.floor((array.Multiplier-1)*100).."% Multiplier";
				["Name"] = array.Name;
			})
		end)

		newMultTemplate.MouseLeave:Connect(function()
			HUD.CancelHover(array.Name)
		end)
	end

	if array.Multiplier > 1 then
		newMultTemplate.Visible = true
	else
		newMultTemplate.Visible = false
	end

	newMultTemplate.Name = array.Name
	newMultTemplate.Multiplier.Text = array.Multiplier.."x"
	newMultTemplate.Shadow.Text = array.Multiplier.."x"

	if array.Image then newMultTemplate.Image = array.Image end
end

--local MultiplierTypes = {"MutationLuck", "BrainrotLuck", "Luck", "Speed", "MoneyMultiplier", "SizeLuck"}
local MultiplierTypes = {"Luck", "MoneyMultiplier"}

for _, mult in MultiplierTypes do
	if Player:GetAttribute(mult) then 
		HUD.Multiplier({
			["Image"] = RS.Game.UI:FindFirstChild(mult).Image;
			["Multiplier"] = Player:GetAttribute(mult);
			["Name"] = mult;
		})
	end

	Player:GetAttributeChangedSignal(mult):Connect(function()
		HUD.Multiplier({
			["Image"] = RS.Game.UI:FindFirstChild(mult).Image;
			["Multiplier"] = Player:GetAttribute(mult);
			["Name"] = mult;
		})
	end)
end

task.spawn(function()
	while true do
		local hasCounters = false
		for name, data in pairs(HUD.Counters) do
			hasCounters = true

			local template = data.Frame
			local secondsTotal = data.Total
			local startTime = data.Start
			local timeLeft = (startTime + secondsTotal) - tick()

			if timeLeft > 0 then
				-- Update the text with countdown
				template.Text = data.BaseText.." ("..SecondsToTime(timeLeft)..")"
			else
				-- Time expired
				template.Text = data.BaseText.." (0:00)"
				HUD.Counters[template] = nil

				TS:Create(template, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
				TS:Create(template.UIStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()

				task.delay(0.2, function()
					template:Destroy()
				end)
			end
		end

		if not hasCounters then
			task.wait(1)
		else
			task.wait(1)
		end
	end
end)


HUD.Toggle = function(toggle)
	if toggle then 
		NewTS:TweenBounce(BackpackGUI.Backpack, {
			Position = UDim2.new(0, 0, 0, 0);
		})
	else
		NewTS:TweenBounce(BackpackGUI.Backpack, {
			Position = UDim2.new(0, 0, 0.15, 0);
		})
	end
end

-- top noti --

local notiTemplate = UITemplates.NotiTemplate

local activeNotificationThreads = {} -- Store threads outside

HUD.TopNotification = function(array)
	if Player:GetAttribute("TopNotifications") == false then return end 

	local text = array.Text
	local textColor = array.TextColor or Color3.fromRGB(255,255,255)
	local adminIcon = array.Icon
	local duration = array.Duration or 5

	local notificationsFrame = PlayerGui.MainUI.MainUI.Notifications

	-- Check for existing notification with same base text
	local baseText = text:match("^(.-)%s*%[x%d+%]$") or text -- Extract base text without [xN]
	local existingNoti = nil
	local currentQuantity = 1

	for _, noti in ipairs(notificationsFrame:GetChildren()) do
		if noti:IsA("ImageLabel") and noti:FindFirstChild("Title") then
			local notiBaseText = noti.Title.Text:match("^(.-)%s*%[x%d+%]$") or noti.Title.Text
			if notiBaseText == baseText then
				existingNoti = noti
				-- Extract current quantity
				local quantityMatch = noti.Title.Text:match("%[x(%d+)%]$")
				currentQuantity = tonumber(quantityMatch) or 1
				break
			end
		end
	end

	if existingNoti then
		-- Update existing notification
		currentQuantity = currentQuantity + 1
		existingNoti.Title.Text = baseText .. " [x" .. currentQuantity .. "]"
		existingNoti.Title.TextColor3 = textColor

		-- Cancel existing destroy thread
		if activeNotificationThreads[existingNoti] then
			task.cancel(activeNotificationThreads[existingNoti])
		end

		-- Restart duration timer
		local destroyThread = task.delay(duration, function()
			TS:Create(existingNoti, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
			if existingNoti:FindFirstChild("NotiIcon") then
				TS:Create(existingNoti.NotiIcon, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
			end
			TS:Create(existingNoti.Title, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
			if existingNoti.Title:FindFirstChild("UIStroke") then
				TS:Create(existingNoti.Title.UIStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
			end
			task.wait(0.3)
			activeNotificationThreads[existingNoti] = nil
			existingNoti:Destroy()
		end)

		activeNotificationThreads[existingNoti] = destroyThread

		return
	end

	-- Create new notification if none exists
	local newTemplate = notiTemplate:Clone()
	newTemplate.Parent = notificationsFrame
	if array.RichText then newTemplate.Title.RichText = true end
	newTemplate.Title.Text = text
	newTemplate.Title.TextColor3 = textColor

	if array.ShadowColor then
		newTemplate.ImageColor3 = array.ShadowColor 
	end
	if array.ShadowTransparency then
		newTemplate.ImageTransparency = array.ShadowTransparency
	end

	if adminIcon then
		newTemplate.NotiIcon.Visible = true
		newTemplate.NotiIcon.Image = adminIcon
	end

	local destroyThread = task.delay(duration, function()
		TS:Create(newTemplate, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
		TS:Create(newTemplate.NotiIcon, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
		TS:Create(newTemplate.Title, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TS:Create(newTemplate.Title.UIStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		task.wait(0.3)
		activeNotificationThreads[newTemplate] = nil
		newTemplate:Destroy()
	end)

	activeNotificationThreads[newTemplate] = destroyThread
end

-- general buttons -- 
local flowUtil = require(Utilities.flowUtil)
local function playSound(Name)
	local SoundPath = Sounds.GameSounds[Name]
	flowUtil:PlaySound(SoundPath,workspace)
end


--[[
local function setupConnects(Object,UIScale,Sound)
	local isObjectValid = Object.Parent and (Object:IsA("TextButton") or Object:IsA("ImageButton"))
	local isImage = isObjectValid ~= true and Object:IsA("ImageLabel")
	
	if not (isObjectValid or isImage) then
		return
	end
	
	local RotateImage = Object:GetAttribute("RotateImage")
	local HoverType = Object:GetAttribute("Hover") and "Hover" or Object:GetAttribute("HoverParent") and "HoverParent"
	
	-- helper FUNC
	
	local function onHover(Object)
		if not object:FindFirstChild("UIScale") then
			local newScale = Instance.new("UIScale", object)
			newScale.Scale = 1
		end
		
		NewTS:TweenBounce(Object.UIScale, {Scale = 1.1;})
		playSound("hover2")
		
		
		
	end
	
	
end]] -- finish this later cause the code below me is retarded, and AI doesn't udnerstand what ims aying so just hand make it

HUD.HandleObject = function(object)
	if object:IsA("TextButton") or object:IsA("ImageButton") then
		-- hover / unhover --
		if object:GetAttribute("Hover") ~= nil then -- hover for left side buttons --
			if not object:FindFirstChild("UIScale") then
				local newScale = Instance.new("UIScale", object)
				newScale.Scale = 1
			end

			object.MouseEnter:Connect(function()
				NewTS:TweenBounce(object.UIScale, {
					Scale = 1.1;
				})
				playSound("hover2")

				if object:GetAttribute("RotateImage") then
					local Image = object:FindFirstChildWhichIsA("ImageLabel")

					if not Image then
						return
					end

					NewTS:TweenBounce(Image, {
						Rotation = 20;
					})

				end



			end)

			object.MouseLeave:Connect(function()
				NewTS:TweenBounce(object.UIScale, {
					Scale = 1;
				})
				playSound("hover2")


				if object:GetAttribute("RotateImage") then
					local Image = object:FindFirstChildWhichIsA("ImageLabel")

					if not Image then
						return
					end

					NewTS:TweenBounce(Image, {
						Rotation = 0;
					})

				end


			end)

			object.MouseButton1Down:Connect(function()
				NewTS:TweenBounce(object.UIScale, {
					Scale = 0.8;
				})



				if object:GetAttribute("RotateImage") then
					local Image = object:FindFirstChildWhichIsA("ImageLabel")

					if not Image then
						return
					end

					NewTS:TweenBounce(Image, {
						Rotation = -20;
					})

				end

			end)

			object.MouseButton1Up:Connect(function()
				NewTS:TweenBounce(object.UIScale, {
					Scale = 1;
				})
				playSound("hover1")




				if object:GetAttribute("RotateImage") then
					local Image = object:FindFirstChildWhichIsA("ImageLabel")

					if not Image then
						return
					end

					NewTS:TweenBounce(Image, {
						Rotation = 20;
					})

				end


			end)




		end

		if object:GetAttribute("HoverParent") then
			if not object.Parent:FindFirstChild("UIScale") then
				local newScale = Instance.new("UIScale", object.Parent)
				newScale.Scale = 1
			end

			object.MouseEnter:Connect(function()

				NewTS:TweenBounce(object.Parent.UIScale, {
					Scale = 0.95;
				})

				playSound("hover2")
			end)

			object.MouseLeave:Connect(function()
				NewTS:TweenBounce(object.Parent.UIScale, {
					Scale = 1;
				})
				playSound("hover2")
			end)

			object.MouseButton1Down:Connect(function()
				NewTS:TweenBounce(object.Parent.UIScale, {
					Scale = 0.8;
				})
			end)

			object.MouseButton1Up:Connect(function()

				if object.Parent and object.Parent:FindFirstChild("UIScale") then
					NewTS:TweenBounce(object.Parent.UIScale, {
						Scale = 1;
					})
					playSound("hover1")
				end


			end)
		end

		if object:GetAttribute("IndexHoverParent") then
			if not object.Parent then return end
			
			if object.Parent and not object.Parent:FindFirstChild("UIScale") then
				local newScale = Instance.new("UIScale", object.Parent)
				newScale.Scale = 1
			end
			object.MouseEnter:Connect(function()
				NewTS:TweenBounce(object.Parent.UIScale, {
					Scale = 1.05;
				})
				NewTS:TweenBounce(object.Parent.ViewportFrame.UIScale, {
					Scale = 1.15;
				})
				--TS:Create(object.Parent.UIStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(255,255,255)}):Play()
			end)

			object.MouseLeave:Connect(function()
				--TS:Create(object.Parent.UIStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(161,161,161)}):Play()
				NewTS:TweenBounce(object.Parent.UIScale, {
					Scale = 1;
				})
				NewTS:TweenBounce(object.Parent.ViewportFrame.UIScale, {
					Scale = 1;
				})
			end)
		end

		-- click --
		if object:GetAttribute("OpenFrame") then
			object.MouseButton1Click:Connect(function()
				HUD.OpenFrame(MainUI:FindFirstChild(object.Name))
			end)
		end

		if object:GetAttribute("CloseFrame") then
			object.MouseButton1Click:Connect(function()
				HUD.CloseFrame(MainUI:FindFirstChild(object.Name))
			end)
		end

		if object:GetAttribute("PromptPurchase") then
			object.MouseButton1Click:Connect(function()
				MarketplaceService:PromptProductPurchase(Player, tonumber(object:GetAttribute("PromptPurchase")))
			end)
		end

		if object:GetAttribute("PromptProduct") then
			object.MouseButton1Click:Connect(function()
				MarketplaceService:PromptProductPurchase(Player, tonumber(object:GetAttribute("PromptProduct")))
			end)
		end

		if object:GetAttribute("PromptGamepass") then
			object.MouseButton1Click:Connect(function()
				MarketplaceService:PromptGamePassPurchase(Player, tonumber(object:GetAttribute("PromptGamepass")))
			end)
		end
	end

	if object:IsA("ImageLabel") then
		if object:GetAttribute("InOut") then -- size bounce in and out --
			task.spawn(function()
				local defaultTime = 5 -- total (0.5 in, 0.5 out) --

				if not object:FindFirstChild("UIScale") then
					local newScale = Instance.new("UIScale", object)
					newScale.Scale = 1
				end


				local active = false
				local function loop()
					if active == false then
						TS:Create(object.UIScale, TweenInfo.new(defaultTime/2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Scale = 0.8}):Play()
						active = true
					else
						TS:Create(object.UIScale, TweenInfo.new(defaultTime/2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Scale = 1}):Play()
						active = false
					end
					task.wait(defaultTime/2)
					loop()
				end
				loop()
			end)
		end
	end

	if object:IsA("Frame") or object:IsA("ViewportFrame") or object:IsA("ImageLabel") or object:IsA("TextLabel") then
		if object:GetAttribute("SpecialHoverEffect") then
			task.spawn(function()
				local hoverAmount = tonumber(object:GetAttribute("SpecialHoverEffect")) or 0.02 -- default 0.02 if not specified
				local defaultTime = 2 -- time for one cycle (up and down)

				local originalPosition = object.Position
				local offsetY = UDim2.new(0, 0, -hoverAmount, 0)

				local active = false
				local function loop()
					if active == false then
						-- Move up
						TS:Create(object, TweenInfo.new(defaultTime/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Position = originalPosition + offsetY
						}):Play()
						active = true
					else
						-- Move down
						TS:Create(object, TweenInfo.new(defaultTime/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Position = originalPosition
						}):Play()
						active = false
					end
					task.wait(defaultTime/2)
					loop()
				end
				loop()
			end)
		end
	end

	if object:IsA("Model") then
		if object:GetAttribute("ViewportAnimation") then
			local animController = object:FindFirstChild("AnimationController") or object:FindFirstChild("Humanoid")
			local anim = animController:LoadAnimation(object.Idle)
			anim:Play()
		end
	end

	if object:GetAttribute("Rotating") then
		task.spawn(function()
			local function loop()
				local defaultTime = 5
				TS:Create(object, TweenInfo.new(defaultTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Rotation = object.Rotation + 179}):Play()
				task.wait(defaultTime)
				loop()
			end
			loop()
		end)
	end
end

for _, descendant in MainUI:GetDescendants() do
	HUD.HandleObject(descendant)
end

MainUI.DescendantAdded:Connect(function(d)
	HUD.HandleObject(d)
end)

PlayerGui.DescendantAdded:Connect(function(d)
	HUD.HandleObject(d)
end)

local Buttons = MainUI:FindFirstChild("Top")

for _,Button in Buttons:GetChildren() do
	if not Button:IsA("Frame") then
		continue
	end

	local textButton = Button:WaitForChild("Button")

	textButton.MouseButton1Click:Connect(function()
		local Character = Player.Character or Player.CharacterAdded:Wait()
		local Plot = Player:GetAttribute("Plot")
		assert(Plot,"player has no plot")

		local plotFolder = workspace.Plots[Plot].ButtonParts
		local targetCFrame = plotFolder[textButton.Parent.Name].CFrame

		Character:PivotTo(targetCFrame * CFrame.new(0,2,0))

	end)

end

local PlantsFolder = workspace.Plots[Player:GetAttribute("Plot")].Plants
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = { PlantsFolder }

local function CreateHighlight()
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	return hl
end

local HoveredPlant = nil
local HoverFrame = UITemplates.Hover:Clone()
local HoverTemplate = UITemplates.Hover
HoverFrame.Parent = nil

HUD.Hovers = {}

HUD.CancelHover = function(name)
	if HUD.Hovers[name] then HUD.Hovers[name].Conn:Disconnect(); HUD.Hovers[name].Frame:Destroy(); HUD.Hovers[name] = nil end
end

HUD.MouseHover = function(info)
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")

	local HORIZONTAL_OFFSET = 1
	local VERTICAL_OFFSET = 1

	local screenGui = MainUI

	local newFrame = HoverTemplate:Clone()
	newFrame.Parent = screenGui
	newFrame.AnchorPoint = Vector2.new(0, 0) -- very important
	newFrame.Visible = true -- make sure it’s visible

	newFrame.Top.Text = info.Top
	newFrame.Bottom.Text = info.Bottom
	newFrame.Top.TextColor3 = Color3.fromRGB(255, 255, 255)
	newFrame.Visible = false

	if info.Gradient then
		info.Gradient:Clone().Parent = newFrame.Top
	end

	HUD.CancelHover(info.Name)

	HUD.Hovers[info.Name] = {
		Conn = RunService.Heartbeat:Connect(function()
			-- Get mouse position in screen space
			local mousePos = UserInputService:GetMouseLocation()

			-- Get UI and frame size
			local screenSize = screenGui.AbsoluteSize
			local frameSize = newFrame.AbsoluteSize

			-- Start at original offset
			local x = mousePos.X + HORIZONTAL_OFFSET
			local y = mousePos.Y + VERTICAL_OFFSET

			-- Adjust if overflowing right edge
			if x + frameSize.X > screenSize.X then
				x = mousePos.X - frameSize.X - HORIZONTAL_OFFSET
			end

			-- Adjust if overflowing bottom edge
			if y + frameSize.Y > screenSize.Y then
				y = mousePos.Y - frameSize.Y - VERTICAL_OFFSET
			end

			-- Optional: avoid going off top/left edges
			if x < 0 then x = 0 end
			if y < 0 then y = 0 end

			newFrame.Position = UDim2.fromOffset(x, y)
			newFrame.Visible = true
		end),

		Frame = newFrame;
	}
end

local function FindPlantModel(instance)
	local function IsPlantModel(obj)
		-- A plant model must:
		-- 1. Be directly in PlantsFolder
		-- 2. Have a "Product" attribute
		-- 3. Have a "PlacedTick" attribute (fruits don't have this)
		return obj.Parent == PlantsFolder 
			and obj:GetAttribute("Product") 
			and obj:GetAttribute("PlacedTick")
	end

	-- Check if the hit instance itself is a plant model
	if IsPlantModel(instance) then
		return instance
	end

	-- Check if the instance is a part of a plant model (parent is the plant)
	if instance.Parent and IsPlantModel(instance.Parent) then
		return instance.Parent
	end

	-- Check if instance is nested deeper (grandparent is the plant)
	if instance.Parent and instance.Parent.Parent and IsPlantModel(instance.Parent.Parent) then
		return instance.Parent.Parent
	end

	if instance.Parent and instance.Parent.Parent and instance.Parent.Parent.Parent and IsPlantModel(instance.Parent.Parent.Parent) then
		return instance.Parent.Parent.Parent
	end

	return nil
end

local function UpdateHover()
	-- Ray from mouse into world
	local mousePos = Mouse.Hit.Position
	local origin = Camera.CFrame.Position
	local direction = (mousePos - origin).Unit * 500
	local result = workspace:Raycast(origin, direction, raycastParams)

	if result and result.Instance then
		local model = FindPlantModel(result.Instance)

		if model then
			-- If hovering new plant
			if HoveredPlant ~= model then
				HoveredPlant = model
				HoverFrame.Parent = MainUI

				-- Remove any existing gradient
				local existingGradient = HoverFrame.Top:FindFirstChildWhichIsA("UIGradient")
				if existingGradient then
					existingGradient:Destroy()
				end

				-- Add new gradient based on rarity
				local ItemsData = require(RS.Game.Modules.Libraries.ItemsData)
				local Rarity = ItemsData[HoveredPlant:GetAttribute("Product")].Rarity
				local Gradients = GameFolder.UI.Gradients[Rarity]:Clone()
				Gradients.Parent = HoverFrame.Top
			end

		local timePlaced = HoveredPlant:GetAttribute("PlacedTick")
		local growthTime = HoveredPlant:GetAttribute("GrowthTime")
		
		-- Validate attributes exist and are valid
		local PercentCompleted = 0
		if timePlaced and growthTime and growthTime > 0 and timePlaced > 0 then
			PercentCompleted = math.clamp((workspace:GetServerTimeNow() - timePlaced) / growthTime, 0, 1)
		end
		
			HoverFrame.Top.Text = HoveredPlant:GetAttribute("Product")
			HoverFrame.Bottom.Text = math.floor(PercentCompleted*100).."% Grown"
			HoverFrame.Bottom.TextColor3 = Color3.fromRGB(17, 255, 96)

			if PercentCompleted >= 1 then
				HoverFrame.Bottom.Visible = false
				HoverFrame.Position = UDim2.new(0, Mouse.X + 35, 0, Mouse.Y+30)
			else
				HoverFrame.Bottom.Visible = true
				HoverFrame.Position = UDim2.new(0, Mouse.X + 35, 0, Mouse.Y)
			end

			HoverFrame.Visible = true

			return
		end
	end

	-- If not hovering any plant
	HoverFrame.Parent = nil
	HoveredPlant = nil
end

local hoverConn
hoverConn = RunService.RenderStepped:Connect(UpdateHover)

task.spawn(function()
	


local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
repeat  PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData() wait()  until PlayerReplica and PlayerReplica.Data
local PlayerData = PlayerReplica.Data

local ActiveFavoritedIcons = {}


local function ShouldShowIcons()
	return PlayerData.Settings and PlayerData.Settings.FavoriteIcons == true
end


local function UpdateAllIcons()
	local shouldShow = ShouldShowIcons()

	for fruitModel, frame in pairs(ActiveFavoritedIcons) do
		if fruitModel and fruitModel.Parent then
			frame.Enabled = shouldShow
		else
			-- Clean up if fruit no longer exists
			if frame then frame:Destroy() end
			ActiveFavoritedIcons[fruitModel] = nil
		end
	end
end

-- Listen for setting changes
PlayerReplica:ListenToChange({"Settings", "FavoriteIcons"}, function(newValue)
	UpdateAllIcons()
end)

RS.Remotes.FavoriteFruit.OnClientEvent:Connect(function(FruitModel, Show)
	if not FruitModel or not FruitModel:IsDescendantOf(workspace) then
		warn("Invalid FruitModel received")
		return
	end

	local existingFrame = FruitModel:FindFirstChild("FavoritedPlantFrame")

	if Show then
		-- Show the icon if it doesn't exist
		if not existingFrame then
			local FavoritedPlantFrame = UITemplates.FavoritedPlantFrame:Clone()
			FavoritedPlantFrame.Adornee = FruitModel:FindFirstChild("RootPart")
			FavoritedPlantFrame.Enabled = ShouldShowIcons()
			FavoritedPlantFrame.Parent = FruitModel

			-- Track this icon
			ActiveFavoritedIcons[FruitModel] = FavoritedPlantFrame
		end
	else
		-- Remove the icon if it exists
		if existingFrame then
			existingFrame:Destroy()
			ActiveFavoritedIcons[FruitModel] = nil
		end
	end
end)


local oldCash
local cashText = PlayerGui.MainUI.MainUI.Currency.CurrencyLabel
cashText.Text = "$"..NumberShortener.roundNumber(PlayerData.Cash)
oldCash = PlayerData.Cash

local amountAdded = cashText.amountAdded
local downPos = UDim2.new(amountAdded.Position.X.Scale, 0, amountAdded.Position.Y.Scale+0.05, 0)
local upPos = UDim2.new(amountAdded.Position.X.Scale, 0, amountAdded.Position.Y.Scale-0.05, 0)
local middlePos = amountAdded.Position

local cashAddedTweens = {}
local cashAddedDelays = {}

PlayerReplica:ListenToChange({"Cash"}, function(newCash) --// Equipped/ Unequipped the Unit
	local cashDifference = newCash-oldCash
	local prefix
	if cashDifference > 0 then
		prefix = "+"
		amountAdded.TextColor3 = Color3.fromRGB(15, 225, 0)
	else 
		prefix = ""
		amountAdded.TextColor3 = Color3.fromRGB(225, 47, 47)
	end

	amountAdded.TextTransparency = 1
	amountAdded.UIStroke.Transparency = 1
	amountAdded.Position = downPos
	amountAdded.Text = prefix.."$"..NumberShortener.roundNumber(cashDifference)

	local tt = 0.15
	cashAddedTweens[1] = TS:Create(amountAdded, TweenInfo.new(tt), {TextTransparency = 0; Position = middlePos})
	cashAddedTweens[2] = TS:Create(amountAdded.UIStroke, TweenInfo.new(tt), {Transparency = 0})
	cashAddedTweens[1]:Play(); cashAddedTweens[2]:Play()
	cashAddedDelays[1] = task.delay(tt, function()
		cashAddedTweens[3] = TS:Create(amountAdded, TweenInfo.new(tt), {TextTransparency = 1; Position = upPos})
		cashAddedTweens[4] = TS:Create(amountAdded.UIStroke, TweenInfo.new(tt), {Transparency = 1})
		local t1 = cashAddedTweens[3]
		task.wait(0.4)
		if cashAddedTweens[3] ~= t1 then return end
		cashAddedTweens[3]:Play(); cashAddedTweens[4]:Play()
	end)

	cashText.Text = "$"..NumberShortener.roundNumber(newCash)
	oldCash = newCash
end)

end)
-- item notifications --


return HUD