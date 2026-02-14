local Snowing = {}
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
local SnowingLighting = EventLighting.Snowing

local function horizontalCF(cframe) -- prob move this into helper func, gonna use this alot
	-- Get the horizontal look direction (remove Y component)
	local horizontalLook = (cframe.LookVector * Vector3.new(1, 0, 1)).Unit

	-- Create new CFrame with same position but only horizontal rotation
	local horizontalCFrame = CFrame.lookAt(cframe.Position, cframe.Position + horizontalLook)

	-- Handle edge cases where the result might be invalid
	if horizontalCFrame ~= horizontalCFrame then -- NaN check
		horizontalCFrame = CFrame.new(cframe.Position)
	end

	return horizontalCFrame
end

local CollectionService = game:GetService("CollectionService")
local Connections = {}
local instances = {}
local activeTweens = {}

local MutationUtility = require(GameFolder.Modules.Libraries.MutationsData.MutationUtil)

function Snowing:StartWeather()
	local snowCamera = script.Sandstorm:Clone()
	snowCamera.Parent = workspace

	-- Get the existing atmosphere in Lighting and the reference atmosphere
	local atmosphere = game.Lighting:FindFirstChild("Atmosphere")
	local snowAtmosphere = script.Snow

	if atmosphere and snowAtmosphere then
		-- Tween all atmosphere properties from script.Snow
		local atmosphereTween = TweenService:Create(
			atmosphere,
			TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
			{ 
				Density = snowAtmosphere.Density,
				Offset = snowAtmosphere.Offset,
				Color = snowAtmosphere.Color,
				Decay = snowAtmosphere.Decay,
				Glare = snowAtmosphere.Glare,
				Haze = snowAtmosphere.Haze
			}
		)
		atmosphereTween:Play()
		table.insert(activeTweens, atmosphereTween)
	end

	local colorCorrection = SnowingLighting:Clone()
	local brightness = colorCorrection.Brightness
	local contrast = colorCorrection.Contrast
	local tintColor = colorCorrection.TintColor

	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255) -- White/neutral tint

	print(colorCorrection.Brightness)
	colorCorrection.Parent = game.Lighting
	colorCorrection.Enabled = true

	local tween = TweenService:Create(
		colorCorrection,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{
			Brightness = brightness,
			Contrast = contrast,
			TintColor = tintColor
		}
	)
	tween:Play()
	table.insert(activeTweens, tween)

	Connections["VFX"] = game:GetService("RunService").Stepped:Connect(function()
		snowCamera.CFrame = CFrame.new((horizontalCF(workspace.CurrentCamera.CFrame) * CFrame.new(0, 0,-20)).Position)
	end)

	local snowColor = Color3.fromRGB(220, 230, 240) -- Snowy/white color

	for index, part in CollectionService:GetTagged("Grass") do
		if not part:GetAttribute("OriginalColor") then
			part:SetAttribute("OriginalColor", part.Color)
		end
		part.Color = snowColor
	end

	for index, part in CollectionService:GetTagged("Shrub") do
		if not part:GetAttribute("OriginalColor") then
			part:SetAttribute("OriginalColor", part.Color)
		end
		MutationUtility.TintPart(part,Color3.fromRGB(255, 255, 255),1.05)
	end

	table.insert(instances, snowCamera)
	table.insert(instances, colorCorrection)
end

function Snowing:CleanupWeather()
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

	-- Restore atmosphere to default settings
	local atmosphere = game.Lighting:FindFirstChild("Atmosphere")
	local defaultAtmosphere = game.Lighting.Default:FindFirstChild("Atmosphere")

	if atmosphere and defaultAtmosphere then
		local atmosphereCleanupTween = TweenService:Create(
			atmosphere,
			TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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
		atmosphereCleanupTween.Completed:Wait() -- Wait for tween to finish
	end

	-- Restore grass colors
	for index, part in CollectionService:GetTagged("Grass") do
		local originalColor = part:GetAttribute("OriginalColor")
		if originalColor then
			part.Color = originalColor
			part:SetAttribute("OriginalColor", nil)
		end
	end

	for index, part in CollectionService:GetTagged("Shrub") do
		local originalColor = part:GetAttribute("OriginalColor")
		if originalColor then
			part.Color = originalColor
			part:SetAttribute("OriginalColor", nil)
		end
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

return Snowing