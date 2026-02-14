local timePlaced = script.Parent:GetAttribute("PlacedTick")
local plant = script.Parent
local player = game.Players:FindFirstChild(plant:GetAttribute("Owner"))

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local GrowthTime = require(game.ReplicatedStorage.Game.Modules.Libraries.ItemsData)[script.Name].GrowthTime
local Mutations = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)
local PickMutations = require(game.ReplicatedStorage.Game.Modules.Utilities.PickMutations)

-- data --

local PlayerReplica = require(RS:WaitForChild("ServerPlayerData"))
local PlayerData = PlayerReplica[player]
local ActualData = PlayerData.Data

local GrownPlant = false
local GrowingStage = 0

local PlantGrowthTime = 4

plant:SetAttribute("GrowthTime", GrowthTime)
plant:SetAttribute("Product", "Carrot")

local EndTime = timePlaced + GrowthTime

plant:PivotTo(plant:GetPivot() * CFrame.new(0,-0.2,0))

local Carrot = game.ReplicatedStorage.Game.Models.Plants.Carrot
local PlantID = plant:GetAttribute("ID")
local ServerUtility = require(game.ServerScriptService.Server.Game.ServerUtility)

local Plot = require(game.ServerScriptService.Server.Game.Plot)

function UpdateGrowth()
	-- Carrot growth stages:
	-- Stage 1: Leaves grow
	-- Stage 2: Leaves expand
	-- Stage 3: Carrot (root) grows underground
	local PercentCompleted = math.clamp((tick() - timePlaced) / (EndTime - timePlaced), 0, 1)

	local function stage1()
		if GrowingStage == 1 then return end
		GrowingStage = 1
		warn("GROW STEM (STAGE 1)")

		-- Grow the stem first
		for _, p in plant:GetDescendants() do 
			if p:IsA("Part") and p.Name == "Stem" then
				local savedPosition = p.Position
				local savedSize = p.Size

				p.Position = Vector3.new(savedPosition.X, savedPosition.Y - 1, savedPosition.Z)
				p.Size = Vector3.new(savedSize.X * 0.1, savedSize.Y * 0.1, savedSize.Z * 0.1)

				TweenService:Create(p, TweenInfo.new(1.5), {
					Position = savedPosition, 
					Size = savedSize,
					Transparency = 0
				}):Play()
			end 
		end 
	end

	local function stage2()
		if GrowingStage == 2 then return end
		GrowingStage = 2
		warn("GROW LEAVES (STAGE 2)")

		-- Grow all the leaf parts
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Leaf" then
				local savedPosition = p.Position
				local savedSize = p.Size

				p.Position = Vector3.new(
					savedPosition.X,
					savedPosition.Y - 0.5, 
					savedPosition.Z
				)
				p.Size = Vector3.new(0, 0, 0)

				TweenService:Create(p, TweenInfo.new(2), {
					Position = savedPosition, 
					Size = savedSize, 
					Transparency = 0
				}):Play()
			end
		end
	end

	local function stage3()
		if GrowingStage == 3 then return end
		GrowingStage = 3
		warn("GROW CARROT ROOT (STAGE 3)")

		-- Grow the carrot parts (the orange root)
		for _, p in plant:GetDescendants() do
			if p:IsA("Part") and p.Name == "Part" and p.Parent.Name == "Carrot" then
				local savedPosition = p.Position
				local savedSize = p.Size

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

	
	if PercentCompleted >= 1 then
	
		-- Carrot is fully grown and ready to harvest
		if not GrownPlant then
			GrownPlant = true
			task.spawn(function()
		
				-- Check if carrot data already exists (reloading saved carrot)
				if ActualData.Plot[PlantID] and ActualData.Plot[PlantID].Weight then
				
				
					-- Load existing carrot
					local newCarrot = plant
					newCarrot:PivotTo(plant:GetPivot() * CFrame.new(0, 0, 0))
			
					ServerUtility.SetupFruit(player, plant, newCarrot, PlantID, "1", true, function() 
					
						PlayerData:SetValue({"Plot", PlantID, nil})
						
					end, Plot)
				else
					local newCarrot = plant
					newCarrot:PivotTo(plant:GetPivot() * CFrame.new(0, 0, 0))
					
					ServerUtility.SetupFruit(player, plant, newCarrot, PlantID, "1", false, function() 
					
						PlayerData:SetValue({"Plot", PlantID, nil})

					end, Plot)
				end
			end)	
		end
	else
		if GrowingStage == 0 then
			-- Make everything invisible initially
			for _, p in plant:GetDescendants() do
				if p:IsA("Part") then
					p.Transparency = 1
				end
			end
		end

		if PercentCompleted >= 0.25 and PercentCompleted < 0.5 then
			stage1()
		elseif PercentCompleted >= 0.5 and PercentCompleted < 0.75 then
			stage2()
		elseif PercentCompleted >= 0.75 and PercentCompleted < 1 then
			stage3()
		end
	end
end

-- Make plant invisible initially
for _, desc in plant:GetDescendants() do
	if desc:IsA("Part") then
		desc.Transparency = 1
	end
end

local PercentCompleted = math.clamp((tick() - timePlaced) / (EndTime - timePlaced), 0, 1)

-- If already fully grown (rejoin scenario), make visible
if PercentCompleted >= 1 then
	for _, desc in plant:GetDescendants() do
		if desc:IsA("Part") then
			desc.Transparency = 0
		end
	end
end

local cancelled = false
game.Players.PlayerRemoving:Connect(function(u)
	if u == player then cancelled = true end
end)

while wait(1) do
	if cancelled then break end
	UpdateGrowth()
	if cancelled then break end
end