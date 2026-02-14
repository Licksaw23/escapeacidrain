local HeatwaveServer = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local EventsManager = require(script.Parent.Parent)



function HeatwaveServer:StartWeather()
	EventsManager:AddLoopChanceFor("Burning")
end


function HeatwaveServer:CleanupWeather()
	EventsManager:StopLoopFor("Burning")
end

return HeatwaveServer