local ViewportModelCFrame = CFrame.new(0, -4, -9) * CFrame.Angles(math.rad(8), math.rad(-13), math.rad(0))
local ViewportPlantCFrame = CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), math.rad(20), math.rad(20))

-- player --

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera

-- services --

local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")

-- folders --

local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local Libraries = Modules.Libraries

-- modules --

local NewTS = require(Utilities.Tweener)
local ItemLibrary = require(Libraries.ItemsData)
local MutationsLibrary = require(Libraries.MutationsData)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local MutationsUtil = require(Libraries.MutationsData.MutationUtil)
local ViewportFitter = require(RS:WaitForChild("Game"):WaitForChild("Modules"):WaitForChild("Utilities").ViewportFitter)

local TotalBrainrots = 0
for _, v in BrainrotLibrary do TotalBrainrots += 1 end 

-- ui --

local MainUI = PlayerGui:WaitForChild("MainUI")
local Index = MainUI.Index
local IndexCategories = Index.Main.Categories
local BrainrotModels = RS.Game.Models.Brainrot3D

-- data --

local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data
local IndexData = PlayerData.Unlocks


-- // Code \\ --

local module = {}

module.Fitters = {}

module.ClearObjectOfType = function(par, typ)
	for _, c in par:GetChildren() do
		if c:IsA(typ) then
			c:Destroy()
		end
	end
end

-- Brainrots --
for _, model in BrainrotModels:GetChildren() do
	if model:IsA("Model") and model:GetAttribute("Rarity") then

		local getIndexCache = IndexData[model.Name]
		local newTemplate = script.IndexTemplate:Clone()
		newTemplate.Parent = Index.Main.ScrollingFrame
		newTemplate.Rarity.Text = model:GetAttribute("Rarity")
		newTemplate.Rarity:FindFirstChild(model:GetAttribute("Rarity")).Enabled = true
		newTemplate:SetAttribute("Type", "Brainrot")
		newTemplate.Name = model.Name
		
		local gradClone = newTemplate.Rarity:FindFirstChild(model:GetAttribute("Rarity"))
		newTemplate.BGEffects.TopLight.UIGradient.Color = gradClone.Color
		--gradClone.Parent = newTemplate.BGEffects.TopLight
		
		local val = gradClone.Color.Keypoints[2].Value
		-- trueColor will correctly store R, G, and B values in the range of 0 to 1.
		local trueColor = Color3.new(val.R, val.G, val.B) 
		
		for _, v in newTemplate.BGEffects:GetChildren() do
			if v.Name == "ImageLabel" then
				local newc = gradClone:Clone()
				newc.Parent = v
			end
		end
		
		local newc = gradClone:Clone()
		newc.Parent = newTemplate.ImageLabel
		
		-- Color3.fromRGB expects values between 0 and 255.
		-- You need to convert the 0-1 values from trueColor back to 0-255 range for fromRGB.
		newTemplate.BackgroundColor3 = Color3.fromRGB(trueColor.R * 255, trueColor.G * 255, trueColor.B * 255)
		--newTemplate.UIStroke.Color = Color3.fromRGB(trueColor.R * 255, trueColor.G * 255, trueColor.B * 255)
		
		local newBrainrotModel = model:Clone()
		newBrainrotModel.Parent = newTemplate.ViewportFrame.WorldModel
		newBrainrotModel.Name = "Normal"
		newBrainrotModel:SetAttribute("originalCFrame", newBrainrotModel:GetPivot())
		
		local Camera = Instance.new("Camera")
		Camera.Parent = newTemplate.ViewportFrame
		newTemplate.ViewportFrame.CurrentCamera = Camera
		module.Fitters[newTemplate] = ViewportFitter.new(newTemplate.ViewportFrame, Camera)
		local viewportFitter = module.Fitters[newTemplate]
		local modelCFrame, modelSize = newBrainrotModel:GetBoundingBox()
		viewportFitter:SetModel(newBrainrotModel)
		-- Offset the viewport
		local cameraDistance = viewportFitter:GetFitDistance(modelCFrame.Position) * 0.8
		Camera.CFrame = CFrame.new(modelCFrame.Position) * CFrame.fromEulerAnglesXYZ(0, -160, 0) * CFrame.new(0, 0, cameraDistance)
		
		local newBrainrotAnim = newBrainrotModel.Humanoid:LoadAnimation(newBrainrotModel.Idle)
		newBrainrotAnim:Play()
		
		local Unlocked = false
		local RarityToLayout = {["Rare"] = 1; ["Epic"] = 2; ["Legendary"] = 3; ["Mythic"] = 4; ["Godly"] = 5; ["Secret"] = 6}
		newTemplate.LayoutOrder = RarityToLayout[model:GetAttribute("Rarity")] or 1
		
		if getIndexCache and getIndexCache.Normal then
			Unlocked = true
		end
		
		if Unlocked then
			local actualName = ""
			for i, v in string.split(model.Name, "_") do if i ~= 1 then actualName = actualName.." "..v else actualName = v end end
			newTemplate.Title.Text = actualName
		else
			newTemplate.Title.Text = "???"
			newTemplate.ViewportFrame.LightColor = Color3.fromRGB(0,0,0)
			newTemplate.ViewportFrame.Ambient = Color3.fromRGB(0,0,0)
		end
	end
end

-- Plants --
for item, itemData in ItemLibrary do
	if itemData.Type == "Plant" then
		local getIndexCache = IndexData[item] or IndexData[itemData.Product]
		
		local newTemplate = script.IndexTemplate:Clone()
		newTemplate.Parent = Index.Main.ScrollingFrame
		newTemplate.Rarity.Text = itemData.Rarity
		newTemplate.Rarity:FindFirstChild(itemData.Rarity).Enabled = true
		newTemplate:SetAttribute("Type", "Plant")
		newTemplate.Name = itemData.Product

		local gradClone = newTemplate.Rarity:FindFirstChild(itemData.Rarity)
		newTemplate.BGEffects.TopLight.UIGradient.Color = gradClone.Color
		--gradClone.Parent = newTemplate.BGEffects.TopLight

		local val = gradClone.Color.Keypoints[2].Value
		-- trueColor will correctly store R, G, and B values in the range of 0 to 1.
		local trueColor = Color3.new(val.R, val.G, val.B) 

		for _, v in newTemplate.BGEffects:GetChildren() do
			if v.Name == "ImageLabel" then
				local newc = gradClone:Clone()
				newc.Parent = v
			end
		end

		local newc = gradClone:Clone()
		newc.Parent = newTemplate.ImageLabel

		-- Color3.fromRGB expects values between 0 and 255.
		-- You need to convert the 0-1 values from trueColor back to 0-255 range for fromRGB.
		newTemplate.BackgroundColor3 = Color3.fromRGB(trueColor.R * 255, trueColor.G * 255, trueColor.B * 255)
		--newTemplate.UIStroke.Color = Color3.fromRGB(trueColor.R * 255, trueColor.G * 255, trueColor.B * 255)

		local newPlantModel = Plants:FindFirstChild(itemData.Product):Clone()
		newPlantModel.Parent = newTemplate.ViewportFrame.WorldModel
		newPlantModel.Name = "Normal"
		newPlantModel:SetAttribute("originalCFrame", newPlantModel:GetPivot())
		local Camera = Instance.new("Camera")
		Camera.Parent = newTemplate.ViewportFrame
		newTemplate.ViewportFrame.CurrentCamera = Camera
		module.Fitters[newTemplate] = ViewportFitter.new(newTemplate.ViewportFrame, Camera)
		local viewportFitter = module.Fitters[newTemplate]
		local modelCFrame, modelSize = newPlantModel:GetBoundingBox()
		viewportFitter:SetModel(newPlantModel)
		-- Offset the viewport
		local cameraDistance = viewportFitter:GetFitDistance(modelCFrame.Position) * 1
		Camera.CFrame = CFrame.new(modelCFrame.Position) * CFrame.fromEulerAnglesXYZ(0, 110, 0) * CFrame.new(0, 0, cameraDistance)

		local Unlocked = false
		local RarityToLayout = {["Rare"] = 1; ["Epic"] = 2; ["Legendary"] = 3; ["Mythic"] = 4; ["Godly"] = 5; ["Secret"] = 6}
		newTemplate.LayoutOrder = RarityToLayout[itemData.Rarity] or 1

		if getIndexCache and getIndexCache.Normal then
			Unlocked = true
		end

		if Unlocked then
			newTemplate.Title.Text = itemData.Product
		else
			newTemplate.Title.Text = "???"
			newTemplate.ViewportFrame.LightColor = Color3.fromRGB(0,0,0)
			newTemplate.ViewportFrame.Ambient = Color3.fromRGB(0,0,0)
		end
	end
end

local currVis

-- Buttons --
IndexCategories.Brainrots.Button.MouseButton1Click:Connect(function()
	for _, v in Index.Main.ScrollingFrame:GetChildren() do
		if v:IsA("Frame") and v.Name ~= "IndexTemplate" and v.Name ~= "Padding" then
			if v:GetAttribute("Type") == "Brainrot" then
				v.Visible = true
			else
				v.Visible = false
			end
		end
	end
end)

IndexCategories.Plants.Button.MouseButton1Click:Connect(function()
	for _, v in Index.Main.ScrollingFrame:GetChildren() do
		if v:IsA("Frame") and v.Name ~= "IndexTemplate" and v.Name ~= "Padding" then
			if v:GetAttribute("Type") == "Plant" then
				v.Visible = true
			else
				v.Visible = false
			end
		end
	end
end)

module.PickMutationCategory = function(mutation)
	IndexData = PlayerData.Unlocks

	-- discovered --
	local AllBrainrots = BrainrotLibrary
	local TypeDiscovered = 0

	for unlock, unlockData in IndexData do
		if BrainrotLibrary[unlock] and unlockData[mutation] then
			TypeDiscovered += 1
		end
	end

	Index.Discovered.DiscoveredText.Text = TypeDiscovered.."/"..TotalBrainrots.." Discovered"

	TS:Create(Index.Discovered.Inner.ProgressBar, TweenInfo.new(0.1), {Size = UDim2.new(TypeDiscovered/TotalBrainrots, 0, 1, 0)}):Play()

	module.ClearObjectOfType(Index.Discovered.Inner.ProgressBar, "UIGradient")
	module.ClearObjectOfType(Index.Discovered.Inner, "UIGradient")

	local newGrad = MutationsLibrary[mutation].Gradient:Clone()
	newGrad.Parent = Index.Discovered.Inner.ProgressBar
	local newGrad2 = MutationsLibrary[mutation].Gradient:Clone()
	newGrad2.Parent = Index.Discovered.Inner

	-- update templates
	for _, v in Index.Main.ScrollingFrame:GetChildren() do
		if v:IsA("Frame") and v.Name ~= "IndexTemplate" and v.Name ~= "Frame" then
			local thingName = v.Name

			local getIndexCache = IndexData[thingName] or IndexData[thingName.Product]

			if getIndexCache and getIndexCache[mutation] == true then
				-- clone the viewport, tint it gold using module, make old viewport invisible --
				local WorldModel = v.ViewportFrame.WorldModel

				v.Title.Text = thingName
				v.ViewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
				v.ViewportFrame.Ambient = Color3.fromRGB(255, 255, 255)

				if not WorldModel:FindFirstChild(mutation) then
					local newModel = WorldModel.Normal:Clone()
					newModel.Parent = WorldModel
					newModel.Name = mutation

					if v:GetAttribute("Type") == "Brainrot" then
						local newBrainrotAnim = newModel.Humanoid:LoadAnimation(newModel.Idle)
						newBrainrotAnim:Play()
					end

					if MutationsLibrary[mutation] and MutationsLibrary[mutation].Apply then
						MutationsLibrary[mutation].Apply(newModel, newModel.Parent)
					end
				end

				local old = WorldModel.Normal
				local new = WorldModel[mutation]

				local down = 20

				if v:GetAttribute("Type") == "Plant" then
					for _, model in WorldModel:GetChildren() do
						if model:IsA("Model") then
							model:PivotTo(model:GetPivot() * CFrame.new(0, -down, 0))
						end
					end

					new:PivotTo(new:GetAttribute("originalCFrame"))
				else
					for _, model in WorldModel:GetChildren() do
						if model:IsA("Model") then
							model:PivotTo(model:GetPivot() * CFrame.new(0, -down, 0))
						end
					end

					new:PivotTo(new:GetAttribute("originalCFrame"))
				end
			else
				if v.Name == "Padding" then continue end

				-- make it invisible with ??? and blacked out --
				v.Title.Text = "???"
				v.ViewportFrame.LightColor = Color3.fromRGB(0,0,0)
				v.ViewportFrame.Ambient = Color3.fromRGB(0,0,0)
			end
		end
	end
end

for _,mutationButton in IndexCategories.Parent.Type:GetChildren() do
	if mutationButton:IsA("Frame") and mutationButton.Name ~= "Padding" then
		local button = mutationButton:FindFirstChild("Button")
		local mutation = mutationButton.Name
		
		button.MouseButton1Click:Connect(function()
			module.PickMutationCategory(mutation)
		end)	
	end
end

module.PickMutationCategory("Normal")

for _, v in Index.Main.ScrollingFrame:GetChildren() do
	if v:IsA("Frame") and v.Name ~= "IndexTemplate" and v.Name ~= "Padding" then
		if v:GetAttribute("Type") == "Brainrot" then
			v.Visible = true
		else
			v.Visible = false
		end
	end
end

return module