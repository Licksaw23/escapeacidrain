local SnowingServer = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local EventsManager = require(script.Parent.Parent)



function SnowingServer:StartWeather()
	EventsManager:AddLoopChanceFor("Haunted")
end


function SnowingServer:CleanupWeather()
	EventsManager:StopLoopFor("Haunted")
end

return SnowingServer