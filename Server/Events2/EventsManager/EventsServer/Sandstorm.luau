local SandstormServer = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local EventsManager = require(script.Parent.Parent)



function SandstormServer:StartWeather()
	EventsManager:AddLoopChanceFor("Sandy")
end


function SandstormServer:CleanupWeather()
	EventsManager:StopLoopFor("Sandy")
end

return SandstormServer