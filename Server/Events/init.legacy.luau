local RunService = game:GetService("RunService")
local EventHandler = require(script.EventHandler)
local timeSinceLastEvent = 0
local eventDurationTimer = 0
local isMainServer = false

EventHandler:Initialize()
isMainServer = EventHandler:IsMainServer()


-- Main event loop using RunService and delta time
RunService.Heartbeat:Connect(function(deltaTime)
	if not isMainServer then return end
	timeSinceLastEvent = timeSinceLastEvent + deltaTime
	if not EventHandler.CurrentEvent and timeSinceLastEvent >= EventHandler.EVENT_INTERVAL then
		-- Reset timer
		timeSinceLastEvent = 0
		eventDurationTimer = 0


		local eventName = EventHandler:SelectRandomEvent()
		if eventName then
			EventHandler:BroadcastEvent("StartEvent", eventName)
			EventHandler:StartEvent(eventName)
		else
			warn("[Event Script] Failed to select event")
		end
	end

	-- Track event duration
	if EventHandler.CurrentEvent then
		eventDurationTimer = eventDurationTimer + deltaTime
		if eventDurationTimer >= EventHandler.EVENT_DURATION then
			EventHandler:BroadcastEvent("EndEvent")
			EventHandler:EndEvent()
			eventDurationTimer = 0
		end
	end
end)

