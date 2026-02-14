local RainServer = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local EventsManager = require(script.Parent.Parent)



function RainServer:StartWeather()
	EventsManager:AddLoopChanceFor("Wet")
end


function RainServer:CleanupWeather()
	EventsManager:StopLoopFor("Wet")
end

return RainServer