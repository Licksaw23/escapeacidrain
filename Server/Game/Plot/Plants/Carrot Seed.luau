local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Carrot = {}
Carrot.Type = "Single"
Carrot.GrowthTime = require(RS.Game.Modules.Libraries.ItemsData)["Carrot Seed"].GrowthTime
Carrot.ProductName = "Carrot"
Carrot.FruitRespawnTime = 17

function Carrot.OnPlaced(plant)
	plant:PivotTo(plant:GetPivot() * CFrame.new(0, -0.2, 0))

	plant:SetAttribute("GrowthTime", Carrot.GrowthTime)
	plant:SetAttribute("Product", Carrot.ProductName)
	
	for _, p in plant:GetDescendants() do
		if p:IsA("Part") then
			p.CanCollide = false
		end
	end
end

function Carrot.GetBranches(plant)
	return {}
end

function Carrot.UpdateGrowth(plant, percentCompleted, currentStage)
	local newStage = currentStage

	if currentStage == 0 and percentCompleted > 0 then
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") then
				p.Transparency = 1
				p.CanCollide = false
			end
		end
	end
	
	if currentStage == 0 and percentCompleted >= 0.25 then
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Stem" then
				p.Transparency = 0
				p.CanCollide = true
			end
		end
		newStage = 1
	end
	
	if currentStage == 0 and percentCompleted >= 0.5 then
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Leaf" then
				p.Transparency = 0
				p.CanCollide = true
			end
		end
		newStage = 2
	end
	
	if currentStage == 0 and percentCompleted >= 0.75 then
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Carrot" then
				p.Transparency = 0
				p.CanCollide = true
			end
		end
		newStage = 3
	end

	if percentCompleted >= 0.25 and percentCompleted < 0.5 and newStage < 1 then
		newStage = 1
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Stem" then
				local savedPosition = p.Position
				local savedSize = p.Size

				p.Position = Vector3.new(savedPosition.X, savedPosition.Y - 1, savedPosition.Z)
				p.Size = Vector3.new(savedSize.X * 0.1, savedSize.Y * 0.1, savedSize.Z * 0.1)
				p.CanCollide = true
				TweenService:Create(p, TweenInfo.new(1.5), {
					Position = savedPosition,
					Size = savedSize,
					Transparency = 0
				}):Play()
			end
		end
	end

	if percentCompleted >= 0.5 and percentCompleted < 0.75 and newStage < 2 then
		newStage = 2
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Leaf" then
				local savedPosition = p.Position
				local savedSize = p.Size
				p.CanCollide = true
				p.Position = Vector3.new(
					savedPosition.X,
					savedPosition.Y - 0.5,
					savedPosition.Z
				)
				p.Size = Vector3.new(0, 0, 0)
				p.CanCollide = true
				TweenService:Create(p, TweenInfo.new(2), {
					Position = savedPosition,
					Size = savedSize,
					Transparency = 0
				}):Play()
			end
		end
	end

	if percentCompleted >= 0.75 and percentCompleted < 1 and newStage < 3 then
		newStage = 3
		local targetScale = plant:GetAttribute("Weight") or 1

		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Part" and p.Parent.Name == "Carrot" then
				local savedPosition = p.Position
				local savedSize = p.Size * targetScale
				p.CanCollide = true
				p.Position = Vector3.new(savedPosition.X, savedPosition.Y + 4.5, savedPosition.Z)
				p.Size = Vector3.new(savedSize.X * 0.1, savedSize.Y * 0.1, savedSize.Z * 0.1)

				TweenService:Create(p, TweenInfo.new(2.5), {
					Position = savedPosition,
					Size = savedSize,
					Transparency = 0
				}):Play()
			end
		end
	end

	if percentCompleted >= 1 and currentStage < 4 then
		newStage = 4
		for _, desc in plant:GetDescendants() do
			if desc:IsA("Part") then
				desc.Transparency = 0
				desc.CanCollide = true
			end
		end
		plant:SetAttribute("ReadyToHarvest", true)
	end

	return newStage
end

-- CLIENT-SIDE ONLY: Server no longer spawns fruit models
-- Single plants are the whole plant as harvestable
function Carrot.SpawnFruit(player, plant, branch, plantID, branchIndex, PlayerData, ServerUtility, Plot)
	-- DEPRECATED: For "Single" type plants, the entire plant is the fruit
	-- Server stores fruit data in PlayerReplica.Data.Plot[plantID].Fruits["1"]
	-- Client reads this data and handles harvest interaction
end

return Carrot
