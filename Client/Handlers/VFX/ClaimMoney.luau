local MoneyFX = game.ReplicatedStorage.Game.VFX.Money

local function emitFX(par)
	for _, desc in par:GetDescendants() do
		if desc:IsA("ParticleEmitter") and desc:GetAttribute("EmitCount") then
			desc:Emit(desc:GetAttribute("EmitCount"))
		end
	end
end

return function(info)
	local targPos = info.Position
	
	local new = MoneyFX:Clone()
	new.Parent = workspace
	new.WorldCFrame = targPos
	emitFX(new)
	game.Debris:AddItem(new, 5)
end