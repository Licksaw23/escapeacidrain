-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local ItemLibrary = require(Libraries.ItemsData)
local flowUtil = require(Utilities.flowUtil)
local ViewportFitter = require(Utilities.ViewportFitter)
local LerpMover = require(Utilities.LerpMover)
local MutationsData = require(Libraries.MutationsData)
local NumberShortener = require(Utilities.NumberShortener)
local CalculateMoney = require(Utilities.Calculator)
local GetScale = require(script.Parent.Parent.Parent.Handlers.VFX.Scale)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local VFX = require(script.Parent.Parent.Parent.Handlers.VFX)
local ItemsLibrary = require(Libraries.ItemsData)
local Registry = require(script.Parent.Parent.Parent.Registry)
local EventsData = require(Libraries.EventsData)

local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

-- waits for data
local module = {}

repeat task.wait() until Player:GetAttribute("Plot") -- Waits for plot

local Plot = Player:GetAttribute("Plot")
local PlotFolder = workspace.Plots:WaitForChild(Plot)
local AllPlots = workspace.Plots:GetChildren()
local WeatherModules = script.EventVisuals:GetChildren()

-- Store active weather modules and their connections
local ActiveWeathers = {}
local ActiveEventUI = {} -- Store UI elements and timers for each event

-- UI Components
local EffectsFrame = PlayerGui.MainUI:WaitForChild("Events")
local Template = EffectsFrame.Template

local eventRemotes = RS.Remotes.Events
local EventRemote = eventRemotes.Event
local GetEvents = eventRemotes.GetEvents

local eventModules = {}
for _, Module in pairs(script.EventVisuals:GetDescendants()) do
	if Module:IsA("ModuleScript") then
		eventModules[Module.Name] = require(Module)
	end
end

-- Utility function to format time (MM:SS)
local function FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", minutes, secs)
end

local function CreateEventUI(eventName, duration)
	local eventData = EventsData[eventName]
	if not eventData then
		warn("[Event System] No data found for event:", eventName)
		return
	end

	-- Clone template
	local eventFrame = Template:Clone()
	eventFrame.Name = eventName
	eventFrame.Visible = true
	eventFrame.Parent = EffectsFrame

	if eventData.Icon then
		local iconLabel = eventFrame:FindFirstChild("Icon") or eventFrame:FindFirstChild("ImageLabel")
		if iconLabel then
			iconLabel.Image = eventData.Icon
		end
	end

	local nameLabel = eventFrame:FindFirstChild("EventName") or eventFrame:FindFirstChild("TextLabel")
	if nameLabel then
		nameLabel.Text = eventData.Name or eventName
	end

	local timerLabel = eventFrame:FindFirstChild("Timer") or eventFrame:FindFirstChild("Duration")

	-- Add hover functionality using existing HUD system
	eventFrame.MouseEnter:Connect(function()
		local HUD = Registry.Registered["HUD"]
		if not HUD then return end

		local mutationData = eventData.MutationName and MutationsData[eventData.MutationName]

		HUD.MouseHover({
			Name = "Event_" .. eventName,
			Top = eventName,
			Bottom = eventData.Description or "No description available",
			TopColor = mutationData and mutationData.Color or Color3.fromRGB(0, 255, 75),
			Gradient = mutationData and mutationData.Gradient or nil
		})
	end)

	eventFrame.MouseLeave:Connect(function()
		local HUD = Registry.Registered["HUD"]
		if not HUD then return end
		HUD.CancelHover("Event_" .. eventName)
	end)

	-- Store UI data
	ActiveEventUI[eventName] = {
		Frame = eventFrame,
		TimerLabel = timerLabel,
		TimeRemaining = duration,
		StartTime = tick(),
		Connection = nil
	}

	if duration and timerLabel then
		timerLabel.Text = FormatTime(duration)
		local connection
		connection = RunService.Heartbeat:Connect(function(deltaTime)
			local uiData = ActiveEventUI[eventName]
			if not uiData then
				connection:Disconnect()
				return
			end
			uiData.TimeRemaining = uiData.TimeRemaining - deltaTime

			if uiData.TimeRemaining <= 0 then
				uiData.TimeRemaining = 0
				uiData.TimerLabel.Text = "00:00"
				connection:Disconnect()
			else
				uiData.TimerLabel.Text = FormatTime(uiData.TimeRemaining)
			end
		end)

		ActiveEventUI[eventName].Connection = connection
	elseif timerLabel then
		timerLabel.Text = "∞"
	end
end

-- Remove UI element for an event
local function RemoveEventUI(eventName)
	local uiData = ActiveEventUI[eventName]
	if not uiData then
		return
	end

	-- Cancel hover when removing event
	local HUD = Registry.Registered["HUD"]
	if HUD then
		HUD.CancelHover("Event_" .. eventName)
	end

	if uiData.Connection then
		uiData.Connection:Disconnect()
	end

	if uiData.Frame then
		uiData.Frame:Destroy()
	end

	ActiveEventUI[eventName] = nil
end

EventRemote.OnClientEvent:Connect(function(Event, Data, Call)
	local calledData = EventsData[Event]
	local calledModule = eventModules[Event]

	if not calledData or not calledModule then
		return
	end

	if Call == "BeginEvent" then
		calledModule:StartWeather()
		local duration = Data.Duration or calledData.Duration
		CreateEventUI(Event, duration)
		return
	end

	if Call == "EndEvent" then
		calledModule:CleanupWeather()
		RemoveEventUI(Event)
	end
end)

-- Request active events on join to sync up
task.spawn(function()
	local success, activeEvents = pcall(function()
		return GetEvents:InvokeServer()
	end)

	if success and activeEvents then
		for _, eventInfo in ipairs(activeEvents) do
			local eventName = eventInfo.EventName
			local duration = eventInfo.Duration
			local calledModule = eventModules[eventName]

			if calledModule then
				pcall(function()
					calledModule:StartWeather()
				end)

				CreateEventUI(eventName, duration)
				print("[Event System] Synced event on join:", eventName, "Remaining:", duration)
			end
		end
	else
		warn("[Event System] Failed to get active events on join:", activeEvents)
	end
end)

return module