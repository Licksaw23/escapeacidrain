local EventsManager = {}

local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameFolder = ReplicatedStorage.Game
local Libraries = GameFolder.Modules.Libraries
local EventsData = require(Libraries.EventsData)
local GearsData = require(Libraries.GearsData)
local BitBuffer = require(GameFolder.Modules.Utilities.BitBuffer)
local eventRemotes = ReplicatedStorage.Remotes.Events
local EventRemote = eventRemotes.Event
local MutationData = require(Libraries.MutationsData)

local EventsServerFolder = script:WaitForChild("EventsServer")

local GLOBAL_EVENT_SEED = 948372
EventsManager.ActiveEvents = {}

local function GetEventServerModule(eventName)
	local moduleScript = EventsServerFolder:FindFirstChild(eventName)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return nil
	end

	local success, eventModule = pcall(function()
		return require(moduleScript)
	end)

	if success then
		return eventModule
	else
		warn("[EventsManager] Failed to load server event module:", eventName, eventModule)
		return nil
	end
end

function EventsManager:GetDeterministicEvent(slot)
	local totalWeight = 0

	for _, eventData in pairs(EventsData) do
		totalWeight += (eventData.Chance or 0)
	end

	if totalWeight == 0 then
		return nil
	end

	local rng = Random.new(GLOBAL_EVENT_SEED + slot)
	local roll = rng:NextNumber(0, totalWeight)

	local cumulative = 0
	for eventName, eventData in pairs(EventsData) do
		cumulative += (eventData.Chance or 0)
		if roll <= cumulative then
			return eventName
		end
	end

	return next(EventsData)
end

function EventsManager:BeginEvent(eventName, duration)
	if self.ActiveEvents[eventName] then
		return
	end
	
	

	if not duration then
		local eventData = EventsData[eventName]
		if eventData then
			duration = eventData.Duration or 160
		else
			return
		end
	end

	EventRemote:FireAllClients(eventName, {
		Duration = duration,
		Begun = true
	}, "BeginEvent")

	local eventModule = GetEventServerModule(eventName)
	if eventModule and typeof(eventModule.StartWeather) == "function" then
		local success = pcall(function()
			eventModule:StartWeather()
		end)

		if success then
			self.ActiveEvents[eventName] = {
				Module = eventModule,
				Duration = duration,
				StartTime = os.time()
			}
		end
	end
end

function EventsManager:EndEvent(eventName)
	local eventData = self.ActiveEvents[eventName]
	if not eventData then
		return
	end

	EventRemote:FireAllClients(eventName, {
		Begun = false
	}, "EndEvent")

	if eventData.Module and typeof(eventData.Module.CleanupWeather) == "function" then
		pcall(function()
			eventData.Module:CleanupWeather()
		end)
	end

	self.ActiveEvents[eventName] = nil
end

local GetEventsRemote = ReplicatedStorage.Remotes.Events.GetEvents
-- On server, handle requests
GetEventsRemote.OnServerInvoke = function(player)
	local now = os.time()
	local activeEvents = {}

	for eventName, eventData in pairs(EventsManager.ActiveEvents) do
		local remaining = math.max(0, eventData.StartTime + eventData.Duration - now)
		if remaining > 0 then
			table.insert(activeEvents, {
				EventName = eventName,
				Duration = remaining
			})
		end
	end

	return activeEvents
end

local Mutations2Loop = {}

function EventsManager:GetPlots()
	local plotsList = {}
	local PlotModule = require(game.ServerScriptService.Server.Game.Plot)
	for _, plotSelf in pairs(PlotModule.Plots) do
		if plotSelf.Folder and plotSelf.Folder:FindFirstChild("Plants") then
			table.insert(plotsList, plotSelf)
		end
	end
	return plotsList
end

local function GetPlants(plotSelf)
	local plants = {}
	if not plotSelf.Folder or not plotSelf.Folder:FindFirstChild("Plants") then
		return plants
	end

	for _, plant in ipairs(plotSelf.Folder.Plants:GetChildren()) do
		if plant:IsA("Model") and plant.PrimaryPart and plant:GetAttribute("ID") then
			table.insert(plants, plant)
		end
	end
	return plants
end

local function GetHarvestableFruits(plant)
	local fruits = {}
	for _, fruit in ipairs(plant:GetDescendants()) do
		if fruit:GetAttribute("ReadyToHarvest") then
			local dataIndex = fruit:GetAttribute("DataIndex")
			if dataIndex then
				table.insert(fruits, {Fruit = fruit, DataIndex = dataIndex})
			end
		end
	end
	return fruits
end

local function chance(percent)
	return math.random(1, 10000) <= (percent * 100)
end

-- NEW: Get sprinkler mutation chance multiplier for a fruit position
local function GetSprinklerMutationMultiplier(plotSelf, fruitPosition)
	local multiplier = 1
	local sprinklerTypesSeen = {}

	if not plotSelf.OwnerData or not plotSelf.OwnerData.PlotGears then
		return 1
	end

	-- Check all gears in the plot
	for gearID, gearData in pairs(plotSelf.OwnerData.PlotGears) do
		local gearInfo = GearsData[gearData.Name]

		-- Check if it's a sprinkler with duration
		if gearInfo and gearInfo.PlaceableData and gearInfo.PlaceableData.Duration then
			-- Decode position
			local PositionBuffer = BitBuffer.Create()
			PositionBuffer:FromBase64(gearData.OffsetPosition)
			local x = PositionBuffer:ReadFloat32()
			local y = PositionBuffer:ReadFloat32()
			local z = PositionBuffer:ReadFloat32()
			local OffsetPosition = Vector3.new(x, y, z)
			local sprinklerPosition = plotSelf.Folder.All.Farm1.Origin.Position + OffsetPosition

			-- Check if still active
			if gearData.ActivatedTime then
				local TimeBuffer = BitBuffer.Create()
				TimeBuffer:FromBase64(gearData.ActivatedTime)
				local activatedTime = TimeBuffer:ReadFloat64()
				local sprinklerEndTime = activatedTime + gearInfo.PlaceableData.Duration

				-- Only check if sprinkler hasn't expired yet
				if tick() <= sprinklerEndTime then
					local distance = (fruitPosition - sprinklerPosition).Magnitude

					if distance <= gearInfo.PlaceableData.Radius then
						if not sprinklerTypesSeen[gearData.Name] then
							sprinklerTypesSeen[gearData.Name] = true
							multiplier = multiplier * 1.25 -- 25% boost per unique sprinkler type
						end
					end
				end
			end
		end
	end

	return multiplier
end

local function ApplyMutationToFruit(plotSelf, plantID, fruitData, mutationName)
	local ServerUtil = require(game.ServerScriptService.Server.Game.ServerUtility)
	if ServerUtil.ActiveFruit[plantID..fruitData.DataIndex] then
		ServerUtil.ActiveFruit[plantID..fruitData.DataIndex](nil, "UpdateMutations", mutationName)
		local Gradient = MutationData[mutationName].Gradient
		local shadowColor = Gradient and Gradient.Color.Keypoints[1].Value or Color3.fromRGB(251, 251, 251)

		ReplicatedStorage.Remotes.UI:FireClient(plotSelf.Owner, "TopNotification", {
			Text = "A plant in your garden has mutated to "..mutationName.."!";
			Duration = 5;
			["ShadowColor"] = shadowColor;
			["ShadowTransparency"] = 0.35;
		})
		ReplicatedStorage.Remotes.FX:FireAllClients("Replicate", {["Call"] = "HighlightFruit", ["Model"] = fruitData.Fruit})
	end
end

local function ProcessMutationForPlots(mutationName, loopData)
	local plots = EventsManager:GetPlots()

	for _, plotSelf in ipairs(plots) do
		local plants = GetPlants(plotSelf)

		for _, plant in ipairs(plants) do
			local plantID = plant:GetAttribute("ID")
			local fruits = GetHarvestableFruits(plant)
			for _, fruitData in ipairs(fruits) do
				-- Get sprinkler boost for this fruit
				local fruitPosition = fruitData.Fruit:IsA("BasePart") and fruitData.Fruit.Position or fruitData.Fruit:GetPivot().Position
				local sprinklerMultiplier = GetSprinklerMutationMultiplier(plotSelf, fruitPosition)

				-- Apply chance with sprinkler multiplier
				local boostedChance = loopData.Chance * sprinklerMultiplier

				if chance(boostedChance) then
					ApplyMutationToFruit(plotSelf, plantID, fruitData, mutationName)
				end
			end
		end
	end
end

function EventsManager:AddLoopChanceFor(MutationName, Chance)
	if Mutations2Loop[MutationName] then
		return
	end

	Mutations2Loop[MutationName] = {
		Chance = Chance or 0.35, -- chance
		Active = true -- isActive?
	}
end

function EventsManager:StopLoopFor(MutationName)
	if Mutations2Loop[MutationName] then
		Mutations2Loop[MutationName] = nil -- remove out of pool
	end
end

local Interval = 1 -- check every second
local lastCheck = 0
RunService.Heartbeat:Connect(function(deltaTime)
	if EventsManager.ActiveEvents == {} then
		return
	end

	for mutationName, loopData in pairs(Mutations2Loop) do
		if not loopData.Active then continue end

		lastCheck += deltaTime

		if lastCheck >= Interval then
			lastCheck = 0
			ProcessMutationForPlots(mutationName, loopData)
		end
	end
end)

return EventsManager