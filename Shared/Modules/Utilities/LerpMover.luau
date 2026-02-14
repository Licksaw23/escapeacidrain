local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LerpMover = {}
LerpMover.__index = LerpMover

function LerpMover.new(startCFrame,speed,Model,linkedPlayer)
	local self = setmetatable({}, LerpMover)

	self.StartCFrame = startCFrame
	self.CurrentCFrame = startCFrame
	self.TargetCFrame = startCFrame
	
	if RunService:IsClient() then
		self.AnimationController = Model:FindFirstChild("Humanoid")
		self.WalkTrack = self.AnimationController:LoadAnimation(Model:FindFirstChild("Walk"))
		self.IdleTrack = self.AnimationController:LoadAnimation(Model:FindFirstChild("Idle"))
	end
	
	-- SPEED / SPEED MULTIPLIERS --
	linkedPlayer:GetAttributeChangedSignal("Speed"):Connect(function()
		local speedMultiplier = 1
		local addMultiplier = linkedPlayer:GetAttribute("Speed")
		speedMultiplier += addMultiplier
		
		self.Speed = self.InitialSpeed * speedMultiplier
	end)
	
	self.InitialSpeed = speed or 10
	
	local speedMultiplier = 1
	local addMultiplier = linkedPlayer:GetAttribute("Speed") or 0
	---------------------------
	speedMultiplier += addMultiplier
	
	self.Speed = self.InitialSpeed * speedMultiplier
	self.Alpha = 0

	self._conn = nil
	self._moving = false

	return self
end

function LerpMover:_startLoop(onStep, onFinish)
	if self._conn then
		self._conn:Disconnect()
	end

	self._moving = true
	self.Alpha = 0

	self._conn = RunService.Heartbeat:Connect(function(dt)
		if not self._moving then return end
		
		if RunService:IsClient() and not self.WalkTrack.IsPlaying then
			self.WalkTrack:Play(0.2)
		end
		

		local distance = (self.StartCFrame.Position - self.TargetCFrame.Position).Magnitude
		if distance == 0 then
		
			self:Cancel()
	
			if RunService:IsClient() then
				self.WalkTrack:Stop(0.2)
				self.IdleTrack:Play(0.2)
			end
			
			return
		end

		self.Alpha += (self.Speed * dt) / distance
		self.Alpha = math.clamp(self.Alpha, 0, 1)

		self.CurrentCFrame = self.StartCFrame:Lerp(self.TargetCFrame, self.Alpha)

		if onStep then
			onStep(self.CurrentCFrame)
		end

		if self.Alpha >= 1 then
			if onFinish then onFinish(self.CurrentCFrame) end
			
			if RunService:IsClient() then
				self.WalkTrack:Stop(0.2)
				self.IdleTrack:Play(0.2)
			end
			
			self:Cancel()
		end
	end)
end

function LerpMover:MoveTo(newTargetCFrame, onStep, onFinish)
	self.StartCFrame = self.CurrentCFrame
	self.TargetCFrame = newTargetCFrame

	self:_startLoop(onStep, onFinish)
end

function LerpMover:Cancel()
	self._moving = false
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function LerpMover:GetCFrame()
	return self.CurrentCFrame
end

return LerpMover