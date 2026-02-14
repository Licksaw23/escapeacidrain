local MoneyFX = game.ReplicatedStorage.Game.VFX.Money

local function emitFX(par)
	for _, desc in par:GetDescendants() do
		if desc:IsA("ParticleEmitter") and desc:GetAttribute("EmitCount") then
			desc:Emit(desc:GetAttribute("EmitCount"))
		end
	end
end

local FlowUtil = require(game.ReplicatedStorage.Game.Modules.Utilities.flowUtil)

return function(info)
	FlowUtil:PlaySound(info.Sound,info.Parent or game.Players.LocalPlayer.PlayerGui, not info.norandom and true or false)
end