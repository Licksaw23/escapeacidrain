local vfx = {}
local VFXRemote = game.ReplicatedStorage.Remotes.FX
vfx.cachedModules = {}

for _, module in script:GetChildren() do
	if module:IsA("ModuleScript") then
		pcall(function()
			vfx.cachedModules[module.Name] = require(module)
		end)
	end
end

VFXRemote.OnClientEvent:Connect(function(call, information)
	if call == "Replicate" then
		if vfx.cachedModules[information.Call] then
			vfx.cachedModules[information.Call](information)
		end
	elseif call == "SprinklerStart" then
		-- Start sprinkler VFX
		if vfx.cachedModules["Sprinkler"] then
			vfx.cachedModules["Sprinkler"]:StartSprinkler(information.ID, information.Model, information.Type)
		end
	elseif call == "SprinklerStop" then
		-- Stop sprinkler VFX
		if vfx.cachedModules["Sprinkler"] then
			vfx.cachedModules["Sprinkler"]:StopSprinkler(information.ID)
		end
	end
end)

return vfx