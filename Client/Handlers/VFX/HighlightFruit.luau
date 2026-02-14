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
	FlowUtil:QuickHighlight(info.Model,6,Enum.HighlightDepthMode.AlwaysOnTop)

end