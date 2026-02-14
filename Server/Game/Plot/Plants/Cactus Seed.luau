local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local Cactus = {}
Cactus.Type = "Spawner"
Cactus.GrowthTime = require(RS.Game.Modules.Libraries.ItemsData)["Cactus Seed"].GrowthTime
Cactus.ProductName = "Cactus"
Cactus.FruitRespawnTime = 17
Cactus.FruitGrowthTime = 4
Cactus.BranchPattern = "Branch"

function Cactus.OnPlaced(plant)
	local plantSize = plant:GetExtentsSize()
	plant:PivotTo(plant:GetPivot() * CFrame.new(0, plantSize.Y/2, 0))

	plant:SetAttribute("GrowthTime", Cactus.GrowthTime)
	plant:SetAttribute("Product", Cactus.ProductName)

	for _, p in plant:GetDescendants() do
		if (p:IsA("Part") or p:IsA("MeshPart")) and p.Name ~= "MUTATIONVFX" then
			p:SetAttribute("OriginalTransparency", p.Transparency)
			p.Anchored = true
			
			if plant:GetAttribute("PlacedTick") then
				local percentCompleted = math.clamp((workspace:GetServerTimeNow() - plant:GetAttribute("PlacedTick")) / Cactus.GrowthTime, 0, 1)
				if percentCompleted >= 1 then
					p.CanCollide = true
				else
					p.CanCollide = false
				end
			else
				p.CanCollide = false
			end

			for _, decal in p:GetChildren() do
				if decal:IsA("Decal") then
					decal:SetAttribute("OriginalTransparency", decal.Transparency)
				end
			end
		end
	end
end

function Cactus.GetBranches(plant)
	local branches = {}
	for _, desc in plant:GetDescendants() do
		if desc:IsA("BasePart") and string.find(desc.Name, Cactus.BranchPattern) then
			local branchIndex = string.split(desc.Name, Cactus.BranchPattern)[2]
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

function Cactus.UpdateGrowth(plant, percentCompleted, currentStage)
	local newStage = currentStage

	if currentStage == 0 and percentCompleted > 0 then
		for _, p in plant:GetDescendants() do
			if (p:IsA("Part") or p:IsA("MeshPart")) and p.Name ~= "MUTATIONVFX" then
				p.Transparency = 1
				p.Anchored = true
				p.CanCollide = false
				for _, decal in p:GetChildren() do
					if decal:IsA("Decal") then
						decal.Transparency = 1
					end
				end
			end
		end
	end
	
	if currentStage == 0 and percentCompleted >= 0.25 then
		for _, mdl in plant:GetDescendants() do
			if mdl:IsA("Model") and mdl.Name == "Bottom" then
				for _, p in mdl:GetDescendants() do
					if (p:IsA("Part") or p:IsA("MeshPart")) and p.Name ~= "MUTATIONVFX" then
						p.Transparency = p:GetAttribute("OriginalTransparency") or 0
						p.CanCollide = true
						for _, decal in p:GetChildren() do
							if decal:IsA("Decal") then
								decal.Transparency = decal:GetAttribute("OriginalTransparency") or 0
							end
						end
					end
				end
			end
		end
		newStage = 1
	end
	
	if currentStage == 0 and percentCompleted >= 0.60 then
		local mainSectionContainer = plant:FindFirstChild("Middle")
		if mainSectionContainer then
			for _, child in mainSectionContainer:GetDescendants() do
				if (child:IsA("Part") or child:IsA("MeshPart")) and child.Name ~= "MUTATIONVFX" then
					child.Transparency = child:GetAttribute("OriginalTransparency") or 0
					child.CanCollide = true
					for _, decal in child:GetChildren() do
						if decal:IsA("Decal") then
							decal.Transparency = decal:GetAttribute("OriginalTransparency") or 0
						end
					end
				end
			end
		end
		newStage = 2
	end
	
	if currentStage == 0 and percentCompleted >= 0.65 then
		for _, desc in plant:GetDescendants() do
			if desc:IsA("Model") and desc.Name == "Top" then
				for _, p in desc:GetDescendants() do
					if (p:IsA("Part") or p:IsA("MeshPart")) and p.Name ~= "MUTATIONVFX" then
						p.Transparency = p:GetAttribute("OriginalTransparency") or 0
						p.CanCollide = true
						for _, decal in p:GetChildren() do
							if decal:IsA("Decal") then
								decal.Transparency = decal:GetAttribute("OriginalTransparency") or 0
							end
						end
					end
				end
			end
		end
		newStage = 3
	end

	if percentCompleted >= 0 and percentCompleted < 0.25 and newStage < 1 then
		newStage = 1
		local leafBottomParts = {}
		for _, mdl in plant:GetDescendants() do
			if mdl:IsA("Model") and mdl.Name == "Bottom" then
				for _, p in mdl:GetDescendants() do
					if (p:IsA("Part") or p:IsA("MeshPart")) and p.Name ~= "MUTATIONVFX" then
						table.insert(leafBottomParts, p)
					end
				end
			end
		end

		for i, p in ipairs(leafBottomParts) do
			task.delay((i - 1) * 0.15, function()
				local savedPosition = p.Position
				local savedSize = p.Size
				local originalTransparency = p:GetAttribute("OriginalTransparency") or 0

				p.Position = Vector3.new(
					savedPosition.X + math.random(-10, 10) / 10,
					savedPosition.Y + math.random(-10, 10) / 10,
					savedPosition.Z + math.random(-10, 10) / 10
				)
				p.Size = Vector3.new(0, 0, 0)
				p.CanCollide = true
				
				local decalData = {}
				for _, decal in p:GetChildren() do
					if decal:IsA("Decal") then
						local originalDecalTransparency = decal:GetAttribute("OriginalTransparency") or 0
						table.insert(decalData, {Decal = decal, OriginalTransparency = originalDecalTransparency})
						decal.Transparency = 1
					end
				end

				local partTween = TweenService:Create(p, TweenInfo.new(1.5), {
					Position = savedPosition,
					Size = savedSize,
					Transparency = originalTransparency
				})
				partTween:Play()

				partTween.Completed:Connect(function()
					for _, data in ipairs(decalData) do
						TweenService:Create(data.Decal, TweenInfo.new(0.3), {
							Transparency = data.OriginalTransparency
						}):Play()
					end
				end)
			end)
		end
	end

	if percentCompleted >= 0.25 and percentCompleted < 0.60 and newStage < 2 then
		newStage = 2
		local middleContainer = plant:FindFirstChild("Middle")
		if middleContainer then
			local numberedGroups = {}
			
			for _, desc in middleContainer:GetDescendants() do
				if (desc:IsA("Part") or desc:IsA("MeshPart")) and desc.Name ~= "MUTATIONVFX" then
					local partNumber = tonumber(desc.Name)
					if partNumber then
						if not numberedGroups[partNumber] then
							numberedGroups[partNumber] = {}
						end
						table.insert(numberedGroups[partNumber], desc)
					end
				end
			end

			local sortedGroups = {}
			for number, parts in pairs(numberedGroups) do
				table.insert(sortedGroups, {Number = number, Parts = parts})
			end
			
			table.sort(sortedGroups, function(a, b)
				return a.Number < b.Number
			end)

			local TotalTime = (Cactus.GrowthTime - (Cactus.GrowthTime * 0.25))
			local timePerGroup = TotalTime / #sortedGroups

			for groupIndex, groupData in ipairs(sortedGroups) do
				task.delay(timePerGroup * (groupIndex - 1), function()
					for _, p in ipairs(groupData.Parts) do
						task.spawn(function()
							local savedPosition = p.Position
							local savedSize = p.Size
							local originalTransparency = p:GetAttribute("OriginalTransparency") or 0

							p.Position = Vector3.new(
								savedPosition.X + math.random(-10, 10) / 10,
								savedPosition.Y + math.random(-10, 10) / 10,
								savedPosition.Z + math.random(-10, 10) / 10
							)
							p.Size = Vector3.new(0, 0, 0)
							p.CanCollide = true
							
							local decalData = {}
							for _, decal in p:GetChildren() do
								if decal:IsA("Decal") then
									local originalDecalTransparency = decal:GetAttribute("OriginalTransparency") or 0
									table.insert(decalData, {Decal = decal, OriginalTransparency = originalDecalTransparency})
									decal.Transparency = 1
								end
							end

							local partTween = TweenService:Create(p, TweenInfo.new(1.0), {
								Position = savedPosition,
								Size = savedSize,
								Transparency = originalTransparency
							})
							partTween:Play()

							partTween.Completed:Connect(function()
								for _, data in ipairs(decalData) do
									TweenService:Create(data.Decal, TweenInfo.new(0.3), {
										Transparency = data.OriginalTransparency
									}):Play()
								end
							end)
						end)
					end
				end)
			end
		end
	end

	if percentCompleted >= 0.65 and percentCompleted < 1 and newStage < 3 then
		newStage = 3
		local topLeafParts = {}
		for _, desc in plant:GetDescendants() do
			if desc:IsA("Model") and desc.Name == "Top" then
				for _, p in desc:GetDescendants() do
					if p:IsA("Part") or p:IsA("MeshPart") then
						table.insert(topLeafParts, p)
					end
				end
			end
		end

		for i, p in ipairs(topLeafParts) do
			task.delay((i - 1) * 0.12, function()
				local savedPosition = p.Position
				local savedSize = p.Size
				local originalTransparency = p:GetAttribute("OriginalTransparency") or 0

				p.Transparency = 1
				p.Size = Vector3.new(0, 0, 0)
				p.Position = Vector3.new(
					savedPosition.X + math.random(-10, 10) / 10,
					savedPosition.Y + math.random(-10, 10) / 10,
					savedPosition.Z + math.random(-10, 10) / 10
				)
				p.CanCollide = true
				
				local decalData = {}
				for _, decal in p:GetChildren() do
					if decal:IsA("Decal") then
						local originalDecalTransparency = decal:GetAttribute("OriginalTransparency") or 0
						table.insert(decalData, {Decal = decal, OriginalTransparency = originalDecalTransparency})
						decal.Transparency = 1
					end
				end

				local partTween = TweenService:Create(p, TweenInfo.new(1.5), {
					Position = savedPosition,
					Size = savedSize,
					Transparency = originalTransparency
				})
				partTween:Play()

				partTween.Completed:Connect(function()
					for _, data in ipairs(decalData) do
						TweenService:Create(data.Decal, TweenInfo.new(0.3), {
							Transparency = data.OriginalTransparency
						}):Play()
					end
				end)
			end)
		end
	end

	if percentCompleted >= 1 and currentStage < 4 then
		newStage = 4
		for _, desc in plant:GetDescendants() do
			if (desc:IsA("Part") or desc:IsA("MeshPart")) and desc.Name ~= "MUTATIONVFX" then
				local originalTransparency = desc:GetAttribute("OriginalTransparency") or 0
				desc.Transparency = originalTransparency
				desc.Anchored = true
				desc.CanCollide = true
				for _, decal in desc:GetChildren() do
					if decal:IsA("Decal") then
						local originalDecalTransparency = decal:GetAttribute("OriginalTransparency") or 0
						decal.Transparency = originalDecalTransparency
					end
				end
			end
		end
	end

	return newStage
end

-- CLIENT-SIDE ONLY: Server no longer spawns fruit models
-- Fruit data is stored in PlayerReplica.Data.Plot[plantID].Fruits
-- Client renders fruit visuals based on server timestamps
function Cactus.SpawnFruit(player, plant, branch, plantID, branchIndex, PlayerData, ServerUtility, Plot, randScale, exists)
	-- DEPRECATED: Fruit spawning is now handled client-side
	-- Server only manages fruit data timestamps
	-- This function is kept for backward compatibility but does nothing on server
	-- Client reads fruit data from PlayerReplica and renders visuals accordingly
end

return Cactus
