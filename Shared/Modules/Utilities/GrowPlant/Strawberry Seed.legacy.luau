local timePlaced = script.Parent:GetAttribute("PlacedTick")
local plant = script.Parent
local player = game.Players:FindFirstChild(plant:GetAttribute("Owner"))

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local AllParts = {}
local StillGrowing = {}
local GrowthTime = require(game.ReplicatedStorage.Game.Modules.Libraries.ItemsData)[script.Name].GrowthTime
local Mutations = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)
local PickMutations = require(game.ReplicatedStorage.Game.Modules.Utilities.PickMutations)

-- data --

local PlayerReplica = require(RS:WaitForChild("ServerPlayerData"))
local PlayerData = PlayerReplica[player]
local ActualData = PlayerData.Data

local GrownPlants = false
local GrowingStage = 0
local PlantsGrown = 0

local PlantGrowthTime = 4
local PlantDebounce = 17 -- before it starts growing another fruit. --

plant:SetAttribute("GrowthTime", GrowthTime)
plant:SetAttribute("Product", "Strawberry")

local EndTime = timePlaced + GrowthTime

plant:PivotTo(plant:GetPivot() * CFrame.Angles(math.rad(math.random(-30,30)),math.rad(math.random(-90,90)),math.rad(-75 + math.random(-30, 30))) * CFrame.new(0,-0.2,0))

local Strawberry = game.ReplicatedStorage.Game.Models.Plants.Strawberry
local PlantID = plant:GetAttribute("ID")
local ServerUtility = require(game.ServerScriptService.Server.Game.ServerUtility)

local Plot = require(game.ServerScriptService.Server.Game.Plot)

function UpdateGrowth()
	-- first stem grows --
	-- then other parts slowly become visible --
	-- in final 1/4th, the branches become visible --
	local PercentCompleted = math.clamp((tick() - timePlaced) / (EndTime - timePlaced), 0, 1)

	--warn(PercentCompleted)
	
	local function stage1()
		if GrowingStage == 1 then return end -- already growing it --
		GrowingStage = 1
		-- stem grows. --
		warn("GROW STEM")

		for _, p in plant:GetDescendants() do 
			if p:IsA("Part") and  p.Name ~= "MUTATIONVFX" then 
				p.Transparency = 1 
				if p.Name == "Stem" then
					local savedPosition = p.Position
					local newPosition = Vector3.new(savedPosition.X,savedPosition.Y-1.5,savedPosition.Z)
					p.Position = newPosition
					TweenService:Create(p, TweenInfo.new(1.5), {Position = savedPosition, Transparency = 0}):Play()
				end
			end 
		end 
	end
	
	local function stage2()
		if GrowingStage == 2 then return end -- already growing it --
		GrowingStage = 2
		-- other parts slowly become visible. --
		for _, mdl in plant:GetChildren() do
			if mdl:IsA("Model") and mdl.Name == "main" and mdl.Name ~= "MUTATIONVFX"  then
				for _, p in mdl:GetChildren() do
					if p.Name == "Stem" then continue end
					local savedPosition = p.Position
					local savedSize = p.Size

					p.Position = Vector3.new(savedPosition.X + math.random(-10,10)/10, savedPosition.Y + math.random(-10,10)/10, savedPosition.Z + math.random(-10,10)/10)
					p.Size = Vector3.new(0,0,0)

					TweenService:Create(p, TweenInfo.new(2.5), {Position = savedPosition; Size = savedSize; Transparency = 0}):Play()
				end
			end
		end
		warn("GROW OTHER PARTS")
	end
	
	local function stage3()
		if GrowingStage == 3 then return end -- already growing it --
		GrowingStage = 3
		-- branches slowly become visible. --
		warn("GROW BRANCHES")
		for _, p in plant:GetChildren() do
			if p:IsA("Part")and  p.Name ~= "MUTATIONVFX"  then
				if p.Name == "Stem" then continue end
				local savedPosition = p.Position
				local savedSize = p.Size

				p.Position = Vector3.new(savedPosition.X + math.random(-10,10)/10, savedPosition.Y + math.random(-10,10)/10, savedPosition.Z + math.random(-10,10)/10)
				p.Size = Vector3.new(0,0,0)

				TweenService:Create(p, TweenInfo.new(2.5), {Position = savedPosition; Size = savedSize; Transparency = 0}):Play()
			end
		end
	end

	if PercentCompleted >= 1 then
		-- full plant just becomes visible --
		-- loop for each branch to spawn a fruit. check when that fruit is removed, and based on the cooldown, make it spawn again. --
		if not GrownPlants then
			GrownPlants = true
			
			task.spawn(function()
				for _, p in plant:GetDescendants() do
					if string.find(p.Name, "Branch") then
						local function spawnFruit(call)
							local getDataIndex = string.split(p.Name, "Branch")[2]
							
							if ActualData.Plot[PlantID][getDataIndex] ~= nil then
								local TBL = ActualData.Plot[PlantID][getDataIndex]
								local Weight = TBL.Weight
								local Mus = TBL.Mutations
								-- Load current fruit. --
								local newStrawberry = Strawberry:Clone()
								newStrawberry.Parent = plant
								newStrawberry:PivotTo(p.CFrame * CFrame.new(0,0,p.Size.Z))
								newStrawberry:ScaleTo(Weight)

								ServerUtility.SetupFruit(player, plant, newStrawberry, PlantID, getDataIndex, true, call, Plot)
							else
								-- Create new fruit, then save that to data. --
								local newStrawberry = Strawberry:Clone()
								newStrawberry.Parent = plant
								newStrawberry:PivotTo(p.CFrame * CFrame.new(0,0,p.Size.Z))
								
								ServerUtility.SetupFruit(player, plant, newStrawberry, PlantID, getDataIndex, false, call, Plot)
							end
						end
						
						local function callback()
							task.delay(PlantDebounce, function()
								spawnFruit(callback)
							end)
						end
						
						spawnFruit(callback)
					end
				end
			end)
		end
	else
		if GrowingStage == 0 then
			-- make everything invisible --

			for _, p in plant:GetDescendants() do
				if p:IsA("Part") and p.Name ~= "MUTATIONVFX"  then
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

-- make it invisible instnatly --

for _, desc in plant:GetDescendants() do
	if desc:IsA("Part") and desc.Name ~= "MUTATIONVFX"  then
		desc.Transparency = 1
	end
end

local PercentCompleted = math.clamp((tick() - timePlaced) / (EndTime - timePlaced), 0, 1)

if PercentCompleted >= 1 then
	for _, desc in plant:GetDescendants() do
		if desc:IsA("Part") and desc.Name ~= "MUTATIONVFX"  then
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