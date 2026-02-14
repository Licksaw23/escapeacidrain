local RunService = game:GetService("RunService")
local EventsManager = require(script.EventsManager)
local EventsData = require(game.ReplicatedStorage.Game.Modules.Libraries.EventsData)

local EVENT_INTERVAL = 30 * 60
local currentSlot = math.floor(os.time() / EVENT_INTERVAL)
local startedSlot = {}


RunService.Heartbeat:Connect(function()
	local now = os.time()
	local slot = math.floor(now / EVENT_INTERVAL)
	local slotStart = slot * EVENT_INTERVAL

	if slot ~= currentSlot then
		currentSlot = slot
	end

	if not startedSlot[slot] then
		local eventName = EventsManager:GetDeterministicEvent(slot)
		if eventName then
			local fullDuration = EventsData[eventName].Duration
			local eventEnd = slotStart + fullDuration
			local remaining = eventEnd - now

			if remaining > 0 then
				startedSlot[slot] = true
				EventsManager:BeginEvent(eventName, remaining)
			end
		end
	end

	for eventName, eventData in pairs(EventsManager.ActiveEvents) do
		if now >= eventData.StartTime + eventData.Duration then
			EventsManager:EndEvent(eventName)
		end
	end
end)
