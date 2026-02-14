local SprinklerVFX = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Replicated = game:GetService("ReplicatedStorage")

-- Cache for active sprinkler effects
SprinklerVFX.ActiveSprinklers = {}

-- Configuration for different sprinkler types
local SprinklerConfigs = {
	["Starter Sprinkler"] = {
		ParticleCount = 20,
		ArcHeight = 8,
		Radius = 20,
		Color = Color3.fromRGB(100, 150, 255),
		Rate = 0.05,
	},
	["Bamboo Sprinkler"] = {
		ParticleCount = 30,
		ArcHeight = 10,
		Radius = 30,
		Color = Color3.fromRGB(120, 180, 100),
		Rate = 0.04,
	},
	["Industrial Sprinkler"] = {
		ParticleCount = 50,
		ArcHeight = 12,
		Radius = 45,
		Color = Color3.fromRGB(80, 120, 200),
		Rate = 0.03,
	},
}

-- Default config for unknown sprinklers
local DefaultConfig = {
	ParticleCount = 25,
	ArcHeight = 8,
	Radius = 20,
	Color = Color3.fromRGB(100, 150, 255),
	Rate = 0.05,
}

--[[
	Create a water particle that arcs from the sprinkler to the ground
]]
local function CreateWaterArc(startPos, endPos, config)
	local particle = Instance.new("Part")
	particle.Name = "WaterParticle"
	particle.Shape = Enum.PartType.Ball
	particle.Size = Vector3.new(0.3, 0.3, 0.3)
	particle.Color = config.Color
	particle.Material = Enum.Material.Glass
	particle.Transparency = 0.3
	particle.CanCollide = false
	particle.Anchored = true
	particle.Parent = workspace.Visuals
	
	-- Calculate arc path
	local midPoint = (startPos + endPos) / 2
	midPoint = midPoint + Vector3.new(0, config.ArcHeight, 0)
	
	local distance = (startPos - endPos).Magnitude
	local duration = math.clamp(distance / 15, 0.5, 1.5)
	
	-- Animate along bezier curve
	local startTime = tick()
	local connection
	
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local t = elapsed / duration
		
		if t >= 1 then
			particle:Destroy()
			connection:Disconnect()
			return
		end
		
		-- Quadratic bezier curve
		local pos = (1 - t) * (1 - t) * startPos + 2 * (1 - t) * t * midPoint + t * t * endPos
		particle.Position = pos
		
		-- Scale down as it falls
		local scale = 1 - (t * 0.5)
		particle.Size = Vector3.new(0.3, 0.3, 0.3) * scale
	end)
	
	return particle
end

--[[
	Create a splash effect when water hits the ground
]]
local function CreateSplashEffect(position, config)
	local splash = Instance.new("Part")
	splash.Name = "Splash"
	splash.Shape = Enum.PartType.Ball
	splash.Size = Vector3.new(0.1, 0.1, 0.1)
	splash.Color = config.Color
	splash.Material = Enum.Material.Glass
	splash.Transparency = 0.5
	splash.CanCollide = false
	splash.Anchored = true
	splash.Position = position
	splash.Parent = workspace.Visuals
	
	-- Expand and fade
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {
		Size = Vector3.new(1.5, 0.3, 1.5),
		Transparency = 1,
	}
	
	local tween = TweenService:Create(splash, tweenInfo, goal)
	tween:Play()
	
	tween.Completed:Connect(function()
		splash:Destroy()
	end)
end

--[[
	Create ground wetness indicator
]]
local function CreateWetGroundEffect(sprinklerPosition, radius, config)
	local wetPart = Instance.new("Part")
	wetPart.Name = "WetGround"
	wetPart.Size = Vector3.new(radius * 2, 0.1, radius * 2)
	wetPart.Color = Color3.fromRGB(80, 100, 130)
	wetPart.Material = Enum.Material.SmoothPlastic
	wetPart.Transparency = 0.9
	wetPart.CanCollide = false
	wetPart.Anchored = true
	wetPart.Position = sprinklerPosition - Vector3.new(0, 0.5, 0)
	wetPart.Parent = workspace.Visuals
	wetPart.Shape = Enum.PartType.Cylinder
	
	-- Rotate to lay flat
	wetPart.CFrame = CFrame.new(wetPart.Position) * CFrame.Angles(0, 0, math.rad(90))
	
	return wetPart
end

--[[
	Start water effects for a sprinkler
]]
function SprinklerVFX:StartSprinkler(sprinklerId, sprinklerModel, sprinklerType)
	if self.ActiveSprinklers[sprinklerId] then
		return -- Already active
	end
	
	local config = SprinklerConfigs[sprinklerType] or DefaultConfig
	local emitterPart = sprinklerModel:FindFirstChild("Emitter") or sprinklerModel:FindFirstChild("WaterEmitter") or sprinklerModel.PrimaryPart
	
	if not emitterPart then
		warn("No emitter part found for sprinkler:", sprinklerId)
		return
	end
	
	-- Create wet ground effect
	local wetGround = CreateWetGroundEffect(emitterPart.Position, config.Radius, config)
	
	-- Store active sprinkler data
	local sprinklerData = {
		Model = sprinklerModel,
		Config = config,
		EmitterPart = emitterPart,
		WetGround = wetGround,
		Active = true,
		ParticleCount = 0,
	}
	
	self.ActiveSprinklers[sprinklerId] = sprinklerData
	
	-- Start particle emission loop
	task.spawn(function()
		while self.ActiveSprinklers[sprinklerId] and self.ActiveSprinklers[sprinklerId].Active do
			-- Emit particles in a circle pattern
			local particleCount = math.random(3, 6)
			
			for i = 1, particleCount do
				if not self.ActiveSprinklers[sprinklerId] then break end
				
				local angle = math.random() * math.pi * 2
				local distance = math.random() * config.Radius * 0.8
				local endPos = emitterPart.Position + Vector3.new(
					math.cos(angle) * distance,
					0,
					math.sin(angle) * distance
				)
				
				-- Raycast to find ground
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Include
				raycastParams.FilterDescendantsInstances = {workspace.Plots}
				
				local result = workspace:Raycast(endPos + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), raycastParams)
				if result then
					endPos = result.Position
				end
				
				CreateWaterArc(emitterPart.Position, endPos, config)
				
				-- Occasional splash at destination
				if math.random() < 0.3 then
					task.delay(math.random() * 0.5 + 0.3, function()
						CreateSplashEffect(endPos, config)
					end)
				end
			end
			
			task.wait(config.Rate)
		end
	end)
	
	-- Add subtle rotation animation to sprinkler head if it exists
	local head = sprinklerModel:FindFirstChild("Head") or sprinklerModel:FindFirstChild("Top")
	if head then
		task.spawn(function()
			while self.ActiveSprinklers[sprinklerId] and self.ActiveSprinklers[sprinklerId].Active do
				local tween = TweenService:Create(head, TweenInfo.new(2, Enum.EasingStyle.Linear), {
					Rotation = head.Rotation + Vector3.new(0, 45, 0)
				})
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end
end

--[[
	Stop water effects for a sprinkler
]]
function SprinklerVFX:StopSprinkler(sprinklerId)
	local sprinklerData = self.ActiveSprinklers[sprinklerId]
	if not sprinklerData then
		return
	end
	
	sprinklerData.Active = false
	
	-- Fade out wet ground
	if sprinklerData.WetGround and sprinklerData.WetGround.Parent then
		local tween = TweenService:Create(sprinklerData.WetGround, TweenInfo.new(2), {
			Transparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function()
			if sprinklerData.WetGround then
				sprinklerData.WetGround:Destroy()
			end
		end)
	end
	
	self.ActiveSprinklers[sprinklerId] = nil
end

--[[
	Update all active sprinklers (called periodically)
]]
function SprinklerVFX:Update()
	for sprinklerId, data in pairs(self.ActiveSprinklers) do
		-- Check if sprinkler still exists
		if not data.Model or not data.Model.Parent then
			self:StopSprinkler(sprinklerId)
		end
	end
end

--[[
	Clean up all sprinkler effects
]]
function SprinklerVFX:Cleanup()
	for sprinklerId, _ in pairs(self.ActiveSprinklers) do
		self:StopSprinkler(sprinklerId)
	end
	self.ActiveSprinklers = {}
end

-- Auto-cleanup on player leave
Players.PlayerRemoving:Connect(function(plr)
	if plr == Player then
		SprinklerVFX:Cleanup()
	end
end)

-- Periodically update
RunService.Heartbeat:Connect(function()
	SprinklerVFX:Update()
end)

return SprinklerVFX
