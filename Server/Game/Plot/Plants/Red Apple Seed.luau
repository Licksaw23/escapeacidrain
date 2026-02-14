local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local RedApple = {}
RedApple.Type = "Spawner"
RedApple.GrowthTime = require(RS.Game.Modules.Libraries.ItemsData)["Red Apple Seed"].GrowthTime
RedApple.ProductName = "Red Apple"
RedApple.FruitRespawnTime = 17
RedApple.FruitGrowthTime = 4
RedApple.BranchPattern = "Branch"

function RedApple.OnPlaced(plant)
	plant:PivotTo(plant:GetPivot() * CFrame.new(0, 0.5, 0))

	plant:SetAttribute("GrowthTime", RedApple.GrowthTime)
	plant:SetAttribute("Product", RedApple.ProductName)

	for _, p in plant:GetDescendants() do
		if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
			p:SetAttribute("OriginalTransparency", p.Transparency)
			
			if plant:GetAttribute("PlacedTick") then
				local percentCompleted = math.clamp((workspace:GetServerTimeNow() - plant:GetAttribute("PlacedTick")) / RedApple.GrowthTime, 0, 1)
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

function RedApple.GetBranches(plant)
	local branches = {}
	for _, desc in plant:GetDescendants() do
		if desc:IsA("BasePart") and string.find(desc.Name, RedApple.BranchPattern) then
			local branchIndex = string.split(desc.Name, RedApple.BranchPattern)[2]
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

function RedApple.UpdateGrowth(plant, percentCompleted, currentStage)
	local newStage = currentStage

	if currentStage == 0 and percentCompleted > 0 then
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
				p.Transparency = 1
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
					if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
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
			for _, mdl in mainSectionContainer:GetChildren() do
				if mdl:IsA("Model") then
					for _, p in mdl:GetDescendants() do
						if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
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
		end
		newStage = 2
	end
	
	if currentStage == 0 and percentCompleted >= 0.65 then
		for _, desc in plant:GetDescendants() do
			if desc:IsA("Model") and desc.Name == "Top" then
				for _, p in desc:GetDescendants() do
					if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
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
					if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
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
		local mainSectionContainer = plant:FindFirstChild("Middle")
		if mainSectionContainer then
			local numberedModels = {}
			for _, mdl in mainSectionContainer:GetChildren() do
				if mdl:IsA("Model") then
					local modelNumber = tonumber(mdl.Name)
					if modelNumber then
						table.insert(numberedModels, {Model = mdl, Number = modelNumber})
					end
				end
			end

			table.sort(numberedModels, function(a, b)
				return a.Number < b.Number
			end)

			local allMainSectionParts = {}
			for _, data in ipairs(numberedModels) do
				for _, p in data.Model:GetDescendants() do
					if p:IsA("Part") and p.Name ~= "MUTATIONVFX" then
						table.insert(allMainSectionParts, p)
					end
				end
			end

			local TotalTime = (RedApple.GrowthTime - (RedApple.GrowthTime*0.25))
			local timePerIteration = TotalTime / #allMainSectionParts

			for i, p in ipairs(allMainSectionParts) do
				task.delay(timePerIteration * i, function()
					local savedPosition = p.Position
					local savedSize = p.Size
					local originalTransparency = p:GetAttribute("OriginalTransparency") or 0

					p.Position = Vector3.new(
						savedPosition.X + math.random(-10, 10) / 10,
						savedPosition.Y + math.random(-10, 10) / 10,
						savedPosition.Z + math.random(-10, 10) / 10
					)
					p.Size = Vector3.new(0, 0, 0)

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
		end
	end

	if percentCompleted >= 0.65 and percentCompleted < 1 and newStage < 3 then
		newStage = 3
		local topLeafParts = {}
		for _, desc in plant:GetDescendants() do
			if desc:IsA("Model") and desc.Name == "Top" then
				for _, p in desc:GetDescendants() do
					if p:IsA("Part") then
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
			if desc:IsA("Part") and desc.Name ~= "MUTATIONVFX" then
				local originalTransparency = desc:GetAttribute("OriginalTransparency") or 0
				desc.Transparency = originalTransparency
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
function RedApple.SpawnFruit(player, plant, branch, plantID, branchIndex, PlayerData, ServerUtility, Plot, randScale, exists)
	-- DEPRECATED: Fruit spawning is now handled client-side
end

return RedApple
