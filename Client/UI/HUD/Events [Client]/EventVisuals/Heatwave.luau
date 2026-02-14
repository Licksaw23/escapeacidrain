local Heatwave = {}
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries
-- modules --
local NewTS = require(Utilities.Tweener)
local Spring = require(Utilities.Tweener.Spring)
local EventLighting = script.Parent.Parent.EventLighting
local SnowingLighting = EventLighting.Heatwave
local CollectionService = game:GetService("CollectionService")
local Connections = {}
local instances = {}
local activeTweens = {}
local MutationUtility = require(GameFolder.Modules.Libraries.MutationsData.MutationUtil)

function Heatwave:StartWeather()

	local colorCorrection = SnowingLighting:Clone()

	local brightness = colorCorrection.Brightness
	local contrast = colorCorrection.Contrast
	local tintColor = colorCorrection.TintColor
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Parent = game.Lighting
	colorCorrection.Enabled = true
	print(colorCorrection.Parent)
	-- Create blur effect for heat distortion
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = game.Lighting
	table.insert(instances, blur)

	-- Create depth of field for atmospheric haze
	local depthOfField = Instance.new("DepthOfFieldEffect")
	depthOfField.FarIntensity = 0
	depthOfField.FocusDistance = 0.05
	depthOfField.InFocusRadius = 50
	depthOfField.NearIntensity = 0
	depthOfField.Parent = game.Lighting
	table.insert(instances, depthOfField)

	-- Tween color correction
	local colorTween = TweenService:Create(
		colorCorrection,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{
			Brightness = brightness,
			Contrast = contrast,
			TintColor = tintColor
		}
	)
	colorTween:Play()
	table.insert(activeTweens, colorTween)

	-- Tween blur for subtle heat shimmer
	local blurTween = TweenService:Create(
		blur,
		TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Size = 3
		}
	)
	blurTween:Play()
	table.insert(activeTweens, blurTween)

	-- Tween depth of field for atmospheric haze
	local dofTween = TweenService:Create(
		depthOfField,
		TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			FarIntensity = 0.15,
			NearIntensity = 0.05
		}
	)
	dofTween:Play()
	table.insert(activeTweens, dofTween)

	table.insert(instances, colorCorrection)
end

function Heatwave:CleanupWeather()
	-- Cancel all active tweens
	for index, tween in activeTweens do
		if tween then
			tween:Cancel()
		end
	end
	table.clear(activeTweens)

	local colorCorrection = game.Lighting:FindFirstChild("Snowing")
	if colorCorrection then
		local cleanupTween = TweenService:Create(
			colorCorrection,
			TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Brightness = 0,
				Contrast = 0,
				TintColor = Color3.fromRGB(255, 255, 255)
			}
		)
		cleanupTween:Play()
		cleanupTween.Completed:Wait()
		colorCorrection:Destroy()
	end

	-- Fade out blur
	local blur = game.Lighting:FindFirstChild("BlurEffect")
	if blur then
		local blurCleanup = TweenService:Create(
			blur,
			TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = 0}
		)
		blurCleanup:Play()
		blurCleanup.Completed:Wait()
		blur:Destroy()
	end

	-- Fade out depth of field
	local dof = game.Lighting:FindFirstChild("DepthOfFieldEffect")
	if dof then
		local dofCleanup = TweenService:Create(
			dof,
			TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				FarIntensity = 0,
				NearIntensity = 0
			}
		)
		dofCleanup:Play()
		dofCleanup.Completed:Wait()
		dof:Destroy()
	end

	-- Destroy instances (use ipairs for array)
	for index = #instances, 1, -1 do
		if instances[index] then
			instances[index]:Destroy()
		end
	end
	table.clear(instances)

	-- Disconnect connections
	for index, connection in pairs(Connections) do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(Connections)
end

return Heatwave