-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local PolicyService = game:GetService("PolicyService")
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
-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
local RebirthUI = MainUI:FindFirstChild("Rebirth")
local CashRequired = RebirthUI:FindFirstChild("CashRequired")
local Requirements = RebirthUI:FindFirstChild("Requirements")
local Unlocks = RebirthUI:FindFirstChild("Unlocks")
-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data
local RebirthsData = require(Libraries.RebirthsData)
local ViewportFitter = require(Utilities.ViewportFitter)
local Money = PlayerData.Cash
local CurrentRebirth = PlayerData.Rebirths
local currentReqs = RebirthsData[CurrentRebirth + 1]
-- module --
local module = {}
module.Fitters = {}

local RebirthRemote = RS.Remotes.Rebirth

function module.UpdateProgressBar()
	if not currentReqs or not currentReqs.Requirements then return end
	local requiredMoney = tonumber(currentReqs.Requirements.Money)
	if not requiredMoney then return end
	local currentMoney = PlayerData.Cash
	local progress = math.clamp(currentMoney / requiredMoney, 0, 1)
	local progressBar = CashRequired:FindFirstChild("Inner"):FindFirstChild("ProgressBar")
	if progressBar then
		-- Tween the bar size smoothly
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goal = {Size = UDim2.new(progress, 0, progressBar.Size.Y.Scale, progressBar.Size.Y.Offset)}
		local tween = TweenService:Create(progressBar, tweenInfo, goal)
		tween:Play()
	end

	if CashRequired.TextLabel then
		CashRequired.TextLabel.Text = string.format("$%s / $%s", module.FormatNumber(currentMoney), module.FormatNumber(requiredMoney))
	end
end

function module.FormatNumber(num)
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.1fK", num / 1000)
	else
		return tostring(num)
	end
end

-- Listen for cash changes
PlayerReplica:ListenToChange({"Cash"}, function(newValue)
	module.UpdateProgressBar()
end)

-- Initial update
module.UpdateProgressBar()



local function checkIfOwned(brainrotName, playerInventory, requiredAmount)

	local count = 0
	-- Loop through inventory items with UUID keys
	for uuid, itemData in pairs(PlayerData.Inventory) do
		if itemData.Name == brainrotName then
			count = count + 1
		end
	end
	
	for uuid, itemData in pairs(PlayerData.Brainrots) do
		if itemData.Name == brainrotName then
			count = count + 1
		end
	end

	return count >= requiredAmount
end

local function updateRequiredBrainrot()
	if not currentReqs or not currentReqs.Requirements then return end
	for template, fitter in pairs(module.Fitters) do
		if fitter.Destroy then
			fitter:Destroy()
		end
		module.Fitters[template] = nil
	end

	for _, child in ipairs(Requirements:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "UIListLayout" then
			child:Destroy()
		end
	end

	local playerInventory = PlayerData.Inventory


	for brainrotName, requiredAmount in pairs(currentReqs.Requirements) do
		if brainrotName ~= "Money" then
			local RequiredTemplate = script.RequiredTemplate:Clone()
			local Viewport = RequiredTemplate.ViewportFrame
			local WorldModel = Viewport.WorldModel

			-- Find the brainrot model in the Models folder
			local brainrotModel = Models:FindFirstChild(brainrotName)
			local Title = RequiredTemplate.Title

			Title.Text = brainrotModel.Name

			if brainrotModel then
	
				local rarity = brainrotModel:GetAttribute("Rarity")
				if rarity and RequiredTemplate.Rarity then

					local rarityGrad = RequiredTemplate.Rarity:FindFirstChild(rarity)
					if rarityGrad then
						rarityGrad.Enabled = true

						local val = rarityGrad.Color.Keypoints[2].Value
						local trueColor = Color3.new(val.R, val.G, val.B)

						-- Apply gradient to ImageLabels in BGEffects
						if RequiredTemplate.BGEffects then
							for _, v in RequiredTemplate.BGEffects:GetChildren() do
								if v.Name == "ImageLabel" then
									local newc = rarityGrad:Clone()
									newc.Parent = v
								end
							end
						end
					end
				end

		
				local newBrainrotModel = brainrotModel:Clone()
				newBrainrotModel.Parent = WorldModel
			

				-- Setup viewport camera
				local Camera = Instance.new("Camera")
				Camera.Parent = Viewport
				Viewport.CurrentCamera = Camera

	
				local viewportFitter = ViewportFitter.new(Viewport, Camera)
				module.Fitters[RequiredTemplate] = viewportFitter

				local modelCFrame, modelSize = newBrainrotModel:GetBoundingBox()
				viewportFitter:SetModel(newBrainrotModel)

				newBrainrotModel.Humanoid:LoadAnimation(brainrotModel.Idle):Play()
				local cameraDistance = viewportFitter:GetFitDistance(modelCFrame.Position) * 0.8
				Camera.CFrame = CFrame.new(modelCFrame.Position) * CFrame.fromEulerAnglesXYZ(0, -160, 0) * CFrame.new(0, 0, cameraDistance)
			end

			local hasBrainrot = checkIfOwned(brainrotName,playerInventory,requiredAmount)
			local Completed = RequiredTemplate.Completed
			
			if hasBrainrot then
				Completed.ImageTransparency = 0
				Viewport.ImageColor3 = Color3.fromRGB(0, 0, 0)
			else
			
				Completed.ImageTransparency = 1
				Viewport.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end

			RequiredTemplate.Name = brainrotName
			RequiredTemplate.Parent = Requirements
		end
	end
end

local UnlockIcons = {
	
	["Luck"] = {Icon = "rbxassetid://101514571511039",Color = Color3.new(0.4, 1, 0)};
	["Cash"] = {Icon = "rbxassetid://91360241186181",Color = Color3.new(0.4, 1, 0)}
	
	
}
local function updateRequiredUnlocks()
	if not currentReqs or not currentReqs.Unlocks then return end

	-- Clear existing unlock UI elements
	for _, child in ipairs(Unlocks:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "UIListLayout" then
			child:Destroy()
		end
	end

	-- Loop through each unlock
	for unlockName, unlockData in pairs(currentReqs.Unlocks) do
		local UnlockTemplate = script.UnlockTemplate:Clone()
		UnlockTemplate.Title.Text = unlockName
		local UnlockIcon = UnlockTemplate.Unlock

		-- Check if this is the "More Brainrot Pads!" unlock
		if unlockData.Icon == "NormalPadViewport" then
			-- Hide the regular icon
			UnlockIcon.Visible = false

			-- Create viewport setup
			local Viewport = UnlockTemplate.ViewportFrame
			Viewport.Visible = true
			local WorldModel = Viewport.WorldModel

			local newBrainrotModel = script.Assets["Normal Pad"]:Clone()
			newBrainrotModel.Parent = WorldModel

			-- Setup viewport camera
			local Camera = Instance.new("Camera")
			Camera.Parent = Viewport
			Viewport.CurrentCamera = Camera

			local viewportFitter = ViewportFitter.new(Viewport, Camera)

			local modelCFrame, modelSize = newBrainrotModel:GetBoundingBox()
			viewportFitter:SetModel(newBrainrotModel)

			local cameraDistance = viewportFitter:GetFitDistance(modelCFrame.Position) * 1
			local rotation = 0

			game:GetService("RunService").RenderStepped:Connect(function(dt)
				rotation = rotation + dt
				Camera.CFrame = CFrame.new(modelCFrame.Position) * CFrame.fromEulerAnglesXYZ(90, rotation, 0) * CFrame.new(0, 0, cameraDistance)
			end)
		elseif UnlockIcon and unlockData.Icon then
			-- Regular icon setup
			local tableData = UnlockIcons[unlockData.Icon]
			local Icon = tableData.Icon
			UnlockIcon.Image = Icon
			local RarityGrad = UnlockTemplate:FindFirstChild("UIGradient")
			RarityGrad.Color = ColorSequence.new(tableData.Color)
			if UnlockTemplate.BGEffects then
				for _, v in UnlockTemplate.BGEffects:GetChildren() do
					if v.Name == "ImageLabel" then
						local newc = RarityGrad:Clone()
						newc.Parent = v
					end
				end
			end
		end

		UnlockTemplate.Name = unlockName
		UnlockTemplate.Parent = Unlocks
	end
end


updateRequiredBrainrot()
updateRequiredUnlocks()



-- Check if max rebirth
local maxRebirthNumber = 0
for rebirthNum, _ in pairs(RebirthsData) do
	if tonumber(rebirthNum) and tonumber(rebirthNum) > maxRebirthNumber then
		maxRebirthNumber = tonumber(rebirthNum)
	end
end

if CurrentRebirth >= maxRebirthNumber then
	RebirthUI.Frame.RebirthText.Text = "MAX Rebirth"
else
	RebirthUI.Frame.RebirthText.Text = `Rebirth {CurrentRebirth + 1}`
end


-- Listen to ALL raw changes to the replica (catches everything including deletions)
PlayerReplica:ListenToRaw(function(action_name, path_array, ...)
	-- Check if the change affects Inventory
	if path_array[1] == "Inventory" then
		updateRequiredBrainrot()
	end

	-- Also check for Rebirths changes
	if path_array[1] == "Rebirths" then
		CurrentRebirth = PlayerData.Rebirths
		currentReqs = RebirthsData[CurrentRebirth + 1]

		-- Check if max rebirth
		if CurrentRebirth >= maxRebirthNumber then
			RebirthUI.Frame.RebirthText.Text = "MAX Rebirth"
		else
			RebirthUI.Frame.RebirthText.Text = `Rebirth {CurrentRebirth + 1}`
		end

		updateRequiredBrainrot()
		updateRequiredUnlocks()
	end
end)


RebirthUI.Rebirth.Button.MouseButton1Click:Connect(function()
	RebirthRemote:FireServer()
end)




return module