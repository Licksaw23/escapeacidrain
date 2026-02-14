-- EscapeAcidRain Main.server.lua
-- Game entry point - initializes all systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Create Remotes folder
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

-- Create workspace folders
local BrainrotsFolder = Instance.new("Folder")
BrainrotsFolder.Name = "Brainrots"
BrainrotsFolder.Parent = workspace

local SafeZonesFolder = Instance.new("Folder")
SafeZonesFolder.Name = "SafeZones"
SafeZonesFolder.Parent = workspace

local BasesFolder = Instance.new("Folder")
BasesFolder.Name = "Bases"
BasesFolder.Parent = workspace

-- Load shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

-- Load systems
local Systems = ServerStorage:WaitForChild("Systems")

-- Initialize Analytics
local AnalyticsService = require(Shared:WaitForChild("AnalyticsService"))
AnalyticsService.Init({
    baseUrl = "https://analytics.arcadias.games",
    apiKey = "flowandroadaregay1234567",
    gameId = "escapeacidrain"
})

-- Initialize Performance Monitor
local PerformanceMonitor = require(Systems:WaitForChild("PerformanceMonitor"))
PerformanceMonitor.SetupLOD()

-- Load game systems
local AcidRainSystem = require(Systems:WaitForChild("AcidRainSystem"))
local CollectionSystem = require(Systems:WaitForChild("CollectionSystem"))
local SafeZoneSystem = require(Systems:WaitForChild("SafeZoneSystem"))
local UpgradeSystem = require(Systems:WaitForChild("UpgradeSystem"))
local BaseSystem = require(Systems:WaitForChild("BaseSystem"))
local PlayerDataSystem = require(Systems:WaitForChild("PlayerDataSystem"))

-- Initialize all systems
AcidRainSystem.Init()
CollectionSystem.Init()
SafeZoneSystem.Init()
UpgradeSystem.Init()
BaseSystem.Init()
PlayerDataSystem.Init()

-- Track player joins
Players.PlayerAdded:Connect(function(player)
    AnalyticsService.TrackPlayerJoin(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
    AnalyticsService.TrackPlayerLeave(player.UserId)
end)

print("🧪 Escape Acid Rain initialized!")
print("🎮 Game ready for players!")
