local flowUtil = {}
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
function flowUtil:PlaySound(Path, Parent, randomizePitch,cloneCFrame)
	local clone = Path:Clone()
	local attachment
	if cloneCFrame then
		attachment = Instance.new("Attachment")
		attachment.WorldCFrame = Parent.CFrame
		attachment.Parent = workspace
		attachment.Name = "soundClone"
		Parent = attachment
		Debris:AddItem(attachment,10)
	end
	
	clone.Parent = Parent
	
	

	clone.SoundGroup = game:GetService("SoundService").SFX
	if randomizePitch then
		clone.PlaybackSpeed += math.random(-15, 15) / 100
	end


	clone:Play()
	Debris:AddItem(clone, 10)

	
	return clone
end

function flowUtil:Emit(Object:Instance)
	for _,particle in Object:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			task.delay(particle:GetAttribute("EmitDuration") or 0,function()
				particle:Emit(particle:GetAttribute("EmitCount"))
			end)
		end
	end
end

function flowUtil:resizeParticle(particle:ParticleEmitter, scale:number)
	local property = "Size"
	for _, target in pairs({ particle }) do
		local newKeypoints = {}
		for _, keypoint in pairs(target[property].Keypoints) do
			table.insert(newKeypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope))
		end
		target[property] = NumberSequence.new(newKeypoints)
	end
	return
end


function flowUtil:resizeAllParticle(object:Instance, scale:number)
	for _,particle in object:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			flowUtil:resizeParticle(particle,scale)
		end
	end
end

function flowUtil:QuickHighlight(Model : Model,Length : number,DepthMode : Enum.HighlightDepthMode)
	local length = Length or 1.15
	local Model = Model or game.Players.LocalPlayer.Character
	local Highlight = Instance.new("Highlight")
	Highlight.Adornee = Model
	Highlight.FillColor = Color3.new(1, 1, 1)
	Highlight.FillTransparency = 0
	Highlight.OutlineTransparency = 0
	Highlight.Parent = Model
	Highlight.Enabled = true
	Highlight.DepthMode = DepthMode or Enum.HighlightDepthMode.Occluded
	
	task.delay(length + 0.45,function()
		Highlight:Destroy()
	end)
	
	local Tween;Tween = TweenService:Create(Highlight, TweenInfo.new(length + 0.45, Enum.EasingStyle.Linear), {
		FillTransparency = 1, 
		OutlineTransparency = 1
	}):Play()
	
	return Highlight,Tween
end

function flowUtil:Ray(Origin: Vector3, Direction: Vector3, Whitelist, RayParams)
	RayParams = RayParams or RaycastParams.new()
	RayParams.FilterDescendantsInstances = Whitelist
	RayParams.FilterType = Enum.RaycastFilterType.Include

	local Raycast = workspace:Raycast(Origin, Direction, RayParams)
	return Raycast and {
		Hit = Raycast.Position,
		Instance = Raycast.Instance,
		Material = Raycast.Material,
		Normal = Raycast.Normal
	}
end

return flowUtil
