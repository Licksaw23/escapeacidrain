local Spooky = {}
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


local Connections = {}
local instances = {}
local activeTweens = {}

-- Default values
local DEFAULT_OUTDOOR_AMBIENT = Color3.fromRGB(210, 145, 110)
local DEFAULT_AMBIENT = Color3.fromRGB(8, 8, 255)
local DEFAULT_BRIGHTNESS = 2.75
local DEFAULT_COLORSHIFT_BOTTOM = Color3.fromRGB(255, 172, 28)
local DEFAULT_COLORSHIFT_TOP = Color3.fromRGB(220, 184, 150)
local DEFAULT_ENVIRONMENT_DIFFUSE_SCALE = 0.5

-- Spooky values
local SPOOKY_OUTDOOR_AMBIENT = Color3.fromRGB(56, 56, 56)
local SPOOKY_AMBIENT = Color3.fromRGB(68, 121, 103)
local SPOOKY_BRIGHTNESS = 4
local SPOOKY_COLORSHIFT_BOTTOM = Color3.fromRGB(0, 0, 0)
local SPOOKY_COLORSHIFT_TOP = Color3.fromRGB(0, 0, 0)
local SPOOKY_ENVIRONMENT_DIFFUSE_SCALE = 0.754

function Spooky:StartWeather()
	-- Get the existing atmosphere in Lighting and the reference atmosphere
	local atmosphere = game.Lighting:FindFirstChild("Atmosphere")
	local spookyAtmosphere = script.Spooky

	if atmosphere and spookyAtmosphere then
		local atmosphereTween = TweenService:Create(
			atmosphere,
			TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
			{ 
				Density = spookyAtmosphere.Density,
				Offset = spookyAtmosphere.Offset,
				Color = spookyAtmosphere.Color,
				Decay = spookyAtmosphere.Decay,
				Glare = spookyAtmosphere.Glare,
				Haze = spookyAtmosphere.Haze
			}
		)
		atmosphereTween:Play()
		table.insert(activeTweens, atmosphereTween)
	end

	-- Tween lighting properties
	local lighting = game.Lighting
	local lightingTween = TweenService:Create(
		lighting,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{
			OutdoorAmbient = SPOOKY_OUTDOOR_AMBIENT,
			Ambient = SPOOKY_AMBIENT,
			Brightness = SPOOKY_BRIGHTNESS,
			ColorShift_Bottom = SPOOKY_COLORSHIFT_BOTTOM,
			ColorShift_Top = SPOOKY_COLORSHIFT_TOP,
			EnvironmentDiffuseScale = SPOOKY_ENVIRONMENT_DIFFUSE_SCALE
		}
	)
	lightingTween:Play()
	table.insert(activeTweens, lightingTween)




end

function Spooky:CleanupWeather()
	-- Cancel all active tweens
	for index, tween in activeTweens do
		if tween then
			tween:Cancel()
		end
	end
	table.clear(activeTweens)



	-- Restore atmosphere to default settings
	local atmosphere = game.Lighting:FindFirstChild("Atmosphere")
	local defaultAtmosphere = game.Lighting.Default:FindFirstChild("Atmosphere")

	if atmosphere and defaultAtmosphere then
		local atmosphereCleanupTween = TweenService:Create(
			atmosphere,
			TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{
				Density = defaultAtmosphere.Density,
				Offset = defaultAtmosphere.Offset,
				Color = defaultAtmosphere.Color,
				Decay = defaultAtmosphere.Decay,
				Glare = defaultAtmosphere.Glare,
				Haze = defaultAtmosphere.Haze
			}
		)
		atmosphereCleanupTween:Play()
	end

	-- Restore lighting properties to default values
	local lighting = game.Lighting
	local lightingCleanupTween = TweenService:Create(
		lighting,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{
			OutdoorAmbient = DEFAULT_OUTDOOR_AMBIENT,
			Ambient = DEFAULT_AMBIENT,
			Brightness = DEFAULT_BRIGHTNESS,
			ColorShift_Bottom = DEFAULT_COLORSHIFT_BOTTOM,
			ColorShift_Top = DEFAULT_COLORSHIFT_TOP,
			EnvironmentDiffuseScale = DEFAULT_ENVIRONMENT_DIFFUSE_SCALE
		}
	)
	lightingCleanupTween:Play()

	-- Destroy other instances
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

return Spooky