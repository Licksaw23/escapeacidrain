-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries

-- remotes --
local orderRemote = RS.Remotes.Order
local spawnRemote = RS.Remotes.Spawn
local UpdateSetting = RS.Remotes.Setting

-- modules --
local NewTS = require(Utilities.Tweener)
local Spring = require(Utilities.Tweener.Spring)
local ItemLibrary = require(Libraries.ItemsData)
local flowUtil = require(Utilities.flowUtil)
local ViewportFitter = require(Utilities.ViewportFitter)
local LerpMover = require(Utilities.LerpMover)
local MutationsData = require(Libraries.MutationsData)
local CalculateMoney = require(Utilities.Calculator)
local GetScale = require(script.Parent.Parent.Parent.Handlers.VFX.Scale)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local VFX = require(script.Parent.Parent.Parent.Handlers.VFX)
local Zone = require(Utilities.Zone)
local NumberShortener = require(Utilities.NumberShortener)
local Icon = require(Utilities.Satchel.Packages.topbarplus)

-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
local SettingsUI = MainUI:WaitForChild("Settings")

-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

-- module --
local module = {}

-- settings icon setup --
local settingsIcon = Icon.new()
settingsIcon:setImage(3687980595)
settingsIcon:oneClick()

local isVisible = false
SettingsUI.Position = UDim2.fromScale(0.5, 0.6)
SettingsUI.Visible = false

local BrainrotHandler = require(script.Parent["Plot [Client]"])
local Registry = require(script.Parent.Parent.Parent.Registry)

-- performance mode cache --
local Connections = {}
local TracksAffected = {}
local ParticlesAffected = {}
local PartsAffected = {}
local Reduction = 5
local CHOP_DISTANCE = 50
local LOW_FPS = 3 -- animations will update 6 times per second

local settingFunctions = {
	["SoundEffects"] = function(toggled)
		SoundService.SFX.Volume = toggled and 0.5 or 0
	end,
	["Music"] = function(toggled)
		SoundService.Music.Volume = toggled and 0.5 or 0
	end,
	["PerformanceMode"] = function(toggled)
		local function applyChoppyAnimation(trackList)
			for _, track in trackList do
				track:SetAttribute("ChoppyLOD", true)
				track:AdjustSpeed(0)

				if not table.find(TracksAffected, track) then
					table.insert(TracksAffected, track)
				end
			end
		end

		local function restoreSmoothAnimation(trackList)
			for _, track in trackList do
				track:SetAttribute("ChoppyLOD", nil)
				track:AdjustSpeed(1)
			end
		end

		if toggled then
			-- reduce all particle rates --
			local function handleThing(thing)
				if thing:IsA("ParticleEmitter") then
					if thing.Enabled == true then
						thing.Enabled = false
						ParticlesAffected[thing] = true
					end
				elseif thing:IsA("BasePart") then
					if thing.CastShadow == true then
						thing.CastShadow = false
						PartsAffected[thing] = true
					end
				end
			end
			
			for _, thing in workspace:GetDescendants() do
				handleThing(thing)
			end
			
			Connections["DescendantAdded"] = workspace.DescendantAdded:Connect(function(thing)
				handleThing(thing)
			end)

			-- should make all animations sine --
			local accumulator = 0
			local STEP_TIME = 1 / LOW_FPS

			Connections["LowPerformanceAnimationLoop"] = RunService.RenderStepped:Connect(function(dt)
				accumulator += dt
				if accumulator < STEP_TIME then return end
				accumulator = 0

				local animTracksToChange = {}

				local function Update()
					for rotID, rotInfo in BrainrotHandler.CurrentBrainrots do
						--if rotInfo.PlotNumber == Player:GetAttribute("Plot") then continue end

						if rotInfo.Idle then
							table.insert(animTracksToChange, rotInfo.Idle)
						elseif rotInfo.Mover and rotInfo.Mover.IdleTrack ~= nil then
							table.insert(animTracksToChange, rotInfo.Mover.IdleTrack)
							table.insert(animTracksToChange, rotInfo.Mover.WalkTrack)
						end
					end

					applyChoppyAnimation(animTracksToChange)
				end

				Update()

				for _, track in animTracksToChange do
					track.TimePosition += STEP_TIME
				end
			end)
		else
			if Connections["LowPerformanceAnimationLoop"] then Connections["LowPerformanceAnimationLoop"]:Disconnect() end
			if Connections["DescendantAdded"] then Connections["DescendantAdded"]:Disconnect() end
			restoreSmoothAnimation(TracksAffected)

			for particle, _ in ParticlesAffected do
				particle.Enabled = true
			end
			
			for shadowPart, _ in PartsAffected do
				shadowPart.CastShadow = true
			end

			ParticlesAffected = {}; TracksAffected = {}
		end
	end,
	["ShowBrainrots"] = function(toggled)
		
	end,
	["TopNotifications"] = function(toggled)
		Player:SetAttribute("TopNotifications", toggled)
	end,
	["ItemNotifications"] = function(toggled)
		Player:SetAttribute("ItemNotifications", toggled)
	end,
	["GiftNotifications"] = function(toggled)
		Player:SetAttribute("GiftNotifications", toggled)
	end,
}

local OnColor = script.On.Color
local OffColor = script.Off.Color
local OnShadow = Color3.fromRGB(7, 135, 0)
local OffShadow = Color3.fromRGB(106, 0, 0)

local function updateSettingUI(settingFrame, button, value)
	settingFrame.Garden.TextLabel.Text = value == true and "On" or "Off"
	
	if value then settingFrame.Garden.Inner.UIGradient.Color = OnColor; settingFrame.Garden.Shadow.BackgroundColor3 = OnShadow; settingFrame.Garden.ImageLabel.ImageColor3 = OnShadow; else settingFrame.Garden.Inner.UIGradient.Color = OffColor; settingFrame.Garden.Shadow.BackgroundColor3 = OffShadow; settingFrame.Garden.ImageLabel.ImageColor3 = OffShadow; end

	if settingFunctions[settingFrame.Name] then
		settingFunctions[settingFrame.Name](value)
	end
end


local playerSettings = PlayerData.Settings or {}

for settingName, settingValue in playerSettings do
	local settingFrame = SettingsUI.SettingsList.ScrollingFrame:FindFirstChild(settingName)

	if settingFrame and type(settingValue) == "boolean" then
		updateSettingUI(settingFrame, settingFrame.Garden.Button, settingValue)


		PlayerReplica:ListenToChange({"Settings", settingName}, function(newValue)
			updateSettingUI(settingFrame, settingFrame.Garden.Button, newValue)
		end)


		settingFrame.Garden:WaitForChild("Button").MouseButton1Click:Connect(function()
			warn("Clicked: "..settingName)

			local newValue = not playerSettings[settingName]
			local settingData = {
				["Setting"] = settingName,
				["Value"] = newValue
			}

			--updateSettingUI(settingFrame, settingFrame.Garden.Button, newValue)
			UpdateSetting:FireServer("UpdateSetting",settingData)
		end)
	end
end


settingsIcon.selected:Connect(function()
	--isVisible = not isVisible
	--SettingsUI.Visible = isVisible

	--NewTS:TweenBounce(SettingsUI, {
	--	["Position"] = isVisible and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 0.6)
	--}, 0.5, 3)
	
	Registry.Registered["HUD"].OpenFrame(MainUI["Settings"])
end)

return module