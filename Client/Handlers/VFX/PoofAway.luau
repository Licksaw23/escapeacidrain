local MoneyFX = game.ReplicatedStorage.Game.VFX.Poof

local function emitFX(par)
	for _, desc in par:GetDescendants() do
		if desc:IsA("ParticleEmitter") and desc:GetAttribute("EmitCount") then
			desc:Emit(desc:GetAttribute("EmitCount"))
		end
	end
end

return function(info)
	local new = MoneyFX:Clone()
	new.Parent = workspace.Visuals
	new.CFrame = CFrame.new(info.CFrame) * CFrame.new(0,3,0)
	emitFX(new)
	game.Debris:AddItem(new, 5)
end