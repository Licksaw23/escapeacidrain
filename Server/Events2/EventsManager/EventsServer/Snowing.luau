local SnowingServer = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local EventsManager = require(script.Parent.Parent)



function SnowingServer:StartWeather()
	EventsManager:AddLoopChanceFor("Chilled")
end


function SnowingServer:CleanupWeather()
	EventsManager:StopLoopFor("Chilled")
end

return SnowingServer