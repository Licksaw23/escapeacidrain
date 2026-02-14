local event = {}

local TweenService = game:GetService("TweenService")

local UIRemote = game.ReplicatedStorage.Remotes.UI
local FXRemote = game.ReplicatedStorage.Remotes.FX

event.EVENT_TIME = 60

event.Connections = {}
event.Objects = {}
event.Threads = {}
event.Tweens = {}

event.Start = function(callback) -- start it all --
	UIRemote:FireAllClients("TopNotification", {
		["Text"] = 'A <font color="#FFD700">gold rush</font> has begun!';
		["Duration"] = 5;
		["RichText"] = true;
		["TextColor"] = Color3.fromRGB(255, 255, 255);
	})
	
	--FXRemote:FireAllClients("Replicate", {["Call"] = "ClaimMoney"})
	
	event.Threads["End"] = task.delay(event.EVENT_TIME, function()
		event.Threads["End"] = nil
		event.End(callback)
	end)
	
	workspace:SetAttribute("GuaranteedMutation", "Gold")
	workspace:SetAttribute("SpawnTick", 2)
end

event.End = function(callback) -- clear it all --
	workspace:SetAttribute("GuaranteedMutation", nil)
	workspace:SetAttribute("SpawnTick", 5)
end

return event