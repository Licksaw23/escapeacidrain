local EventHandler = {}

-- Services
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptService = game:GetService("ServerScriptService")
-- Folders
local GameFolder = ReplicatedStorage.Game
local Libraries = GameFolder.Modules.Libraries
local Utilities = GameFolder.Modules.Utilities

-- Modules
local EventsData = require(Libraries.EventsData)
local ServerUtil = require(ScriptService.Server.Game.ServerUtility)

EventHandler.EVENT_INTERVAL = 3 * 60 -- every 30
EventHandler.EVENT_DURATION = 30 




local MESSAGING_TOPIC = "GlobalEventSync"

-- State
EventHandler.CurrentEvent = nil
EventHandler.EventEndTime = nil
local ActiveEventModules = {} -- Store loaded event modules
local EventsServerFolder = script.Parent:WaitForChild("EventsServer")

-- Get all event server modules
local function GetEventServerModules()
	local modules = {}
	for _, moduleScript in ipairs(EventsServerFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			local success, eventModule = pcall(function()
				return require(moduleScript)
			end)
			if success then
				modules[moduleScript.Name] = eventModule
			else
				warn("[EventHandler] Failed to load server event module:", moduleScript.Name, eventModule)
			end
		end
	end
	return modules
end

function EventHandler:SelectRandomEvent()
	local totalWeight = 0
	for eventName, eventData in pairs(EventsData) do
		totalWeight = totalWeight + (eventData.Chance or 0)
	end
	if totalWeight == 0 then
		warn("[EventHandler] No events with valid chances!")
		return nil
	end
	local randomValue = math.random() * totalWeight
	local cumulativeWeight = 0
	for eventName, eventData in pairs(EventsData) do
		cumulativeWeight = cumulativeWeight + (eventData.Chance or 0)
		if randomValue <= cumulativeWeight then
			return eventName
		end
	end
	return next(EventsData)
end

-- Start an event locally
function EventHandler:StartEvent(eventName)
	
	
	if self.CurrentEvent then
		print("[EventHandler] Cleaning up current event:", self.CurrentEvent)
		workspace:SetAttribute(self.CurrentEvent, nil)
		
		local previousModule = ActiveEventModules[self.CurrentEvent]
		if previousModule and typeof(previousModule.CleanupWeather) == "function" then
			pcall(function()
				previousModule:CleanupWeather()
			end)
		end
	end

	self.CurrentEvent = eventName
	workspace:SetAttribute(eventName, true)
	self.EventEndTime = os.time() + self.EVENT_DURATION

	
	local eventServerModules = GetEventServerModules()
	local eventModule = eventServerModules[eventName]

	if eventModule and typeof(eventModule.StartWeather) == "function" then
		local success, err = pcall(function()
			eventModule:StartWeather()
		end)

		if success then
			ActiveEventModules[eventName] = eventModule
		else
			warn("[EventHandler] Error starting server event:", eventName, err)
		end
	else
		print("[EventHandler] No server module found for:", eventName)
	end
end

-- End the current event
function EventHandler:EndEvent()
	if self.CurrentEvent then
	

		-- Cleanup server-side event
		local eventModule = ActiveEventModules[self.CurrentEvent]
		if eventModule and typeof(eventModule.CleanupWeather) == "function" then
			local success, err = pcall(function()
				eventModule:CleanupWeather()
			end)

			if not success then
				warn("[EventHandler] Error cleaning up server event:", self.CurrentEvent, err)
			end
		end

		workspace:SetAttribute(self.CurrentEvent, nil)
		ActiveEventModules[self.CurrentEvent] = nil
		self.CurrentEvent = nil
		self.EventEndTime = nil
	end
end

-- Handle incoming messages from other servers
local function OnEventMessage(message)
	local data = message.Data

	if data.Action == "StartEvent" then
		local eventName = data.EventName
		print("[EventHandler] Received global event start:", eventName)
		EventHandler:StartEvent(eventName)

	elseif data.Action == "EndEvent" then
		print("[EventHandler] Received global event end")
		EventHandler:EndEvent()
	end
end

-- Broadcast event to all servers
function EventHandler:BroadcastEvent(action, eventName)
	local success, err = pcall(function()
		MessagingService:PublishAsync(MESSAGING_TOPIC, {
			Action = action,
			EventName = eventName,
			Timestamp = os.time()
		})
	end)

	if not success then
		warn("[EventHandler] Failed to broadcast event:", err)
	else
	
	end
end


function EventHandler:IsMainServer()
	local isMainServer = false
	local success, err = pcall(function()
		local data = game:GetService("DataStoreService"):GetDataStore("EventSystem"):GetAsync("MainServerJobId")

		if not data or data == game.JobId then
			game:GetService("DataStoreService"):GetDataStore("EventSystem"):SetAsync("MainServerJobId", game.JobId)
			isMainServer = true
		end
	end)

	if not success then
		warn("[EventHandler] Failed to determine main server:", err)
		-- Fallback: Use server with lowest JobId (deterministic)
		isMainServer = true
	end

	return isMainServer
end


function EventHandler:Initialize()
	local success, connection = pcall(function()
		return MessagingService:SubscribeAsync(MESSAGING_TOPIC, OnEventMessage)
	end)

	if success then
		print("[EventHandler] Successfully subscribed to global events")
	else
		warn("[EventHandler] Failed to subscribe to MessagingService:", connection)
	end

	print("[EventHandler] Event system initialized")
end

return EventHandler