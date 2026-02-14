local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local Strawberry = {}
Strawberry.Type = "Spawner"
Strawberry.GrowthTime = require(RS.Game.Modules.Libraries.ItemsData)["Strawberry Seed"].GrowthTime
Strawberry.ProductName = "Strawberry"
Strawberry.FruitRespawnTime = 17
Strawberry.FruitGrowthTime = 4
Strawberry.BranchPattern = "Branch"

function Strawberry.OnPlaced(plant)
	plant:PivotTo(plant:GetPivot() * CFrame.new(0,1.1,0))

	plant:SetAttribute("GrowthTime", Strawberry.GrowthTime)
	plant:SetAttribute("Product", Strawberry.ProductName)
	
	for _, p in plant:GetDescendants() do
		if p:IsA("Part") then
			p.CanCollide = false
		end
	end
end

function Strawberry.GetBranches(plant)
	local branches = {}
	for _, desc in plant:GetDescendants() do
		if desc:IsA("BasePart") and string.find(desc.Name, Strawberry.BranchPattern) then
			local branchIndex = string.split(desc.Name, Strawberry.BranchPattern)[2]
			if branchIndex and branchIndex ~= "" then
				table.insert(branches, {
					Part = desc,
					Index = branchIndex
				})
			end
		end
	end
	return branches
end

function Strawberry.UpdateGrowth(plant, percentCompleted, currentStage)
	local newStage = currentStage

	if currentStage == 0 and percentCompleted > 0 then
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
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
		for _, mdl in plant:GetChildren() do
			if mdl:IsA("Model") and mdl.Name == "main" then
				for _, p in mdl:GetChildren() do
					if p:IsA("Part") and p.Name ~= "Stem" then
						p.Transparency = 0
						p.CanCollide = true
					end
				end
			end
		end
		newStage = 2
	end
	
	if currentStage == 0 and percentCompleted >= 0.75 then
		for _, p in plant:GetChildren() do
			if p:IsA("Part") and p.Name ~= "Stem" then
				p.Transparency = 0
				p.CanCollide = true
			end
		end
		newStage = 3
	end

	if percentCompleted >= 0.25 and percentCompleted < 0.5 and newStage < 1 then
		newStage = 1
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
				p.Transparency = 1
				if p.Name == "Stem" then
					local savedPosition = p.Position
					local newPosition = Vector3.new(savedPosition.X, savedPosition.Y - 1.5, savedPosition.Z)
					p.Position = newPosition
					TweenService:Create(p, TweenInfo.new(1.5), {
						Position = savedPosition,
						Transparency = 0
					}):Play()
				end
			end
		end
	end

	if percentCompleted >= 0.5 and percentCompleted < 0.75 and newStage < 2 then
		newStage = 2
		for _, mdl in plant:GetChildren() do
			if mdl:IsA("Model") and mdl.Name == "main" and mdl.Name ~= "MUTATIONVFX" then
				for _, p in mdl:GetChildren() do
					if p.Name == "Stem" then continue end

					local savedPosition = p.Position
					local savedSize = p.Size

					p.Position = Vector3.new(
						savedPosition.X + math.random(-10, 10) / 10,
						savedPosition.Y + math.random(-10, 10) / 10,
						savedPosition.Z + math.random(-10, 10) / 10
					)
					p.Size = Vector3.new(0, 0, 0)

					TweenService:Create(p, TweenInfo.new(2.5), {
						Position = savedPosition,
						Size = savedSize,
						Transparency = 0
					}):Play()
				end
			end
		end
	end

	if percentCompleted >= 0.75 and percentCompleted < 1 and newStage < 3 then
		newStage = 3
		for _, p in plant:GetChildren() do
			if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
				if p.Name == "Stem" then continue end

				local savedPosition = p.Position
				local savedSize = p.Size

				p.Position = Vector3.new(
					savedPosition.X + math.random(-10, 10) / 10,
					savedPosition.Y + math.random(-10, 10) / 10,
					savedPosition.Z + math.random(-10, 10) / 10
				)
				p.Size = Vector3.new(0, 0, 0)

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
			if desc:IsA("Part") and desc.Name ~= "MUTATIONVFX" then
				desc.Transparency = 0
				desc.CanCollide = true
			end
		end
	end

	return newStage
end

-- CLIENT-SIDE ONLY: Server no longer spawns fruit models
function Strawberry.SpawnFruit(player, plant, branch, plantID, branchIndex, PlayerData, ServerUtility, Plot, randScale, exists)
	-- DEPRECATED: Fruit spawning is now handled client-side
end

return Strawberry
