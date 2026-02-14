-- FeedTheBrainrots
-- Main game entry point
-- Place this in ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Load core systems
local Systems = ServerStorage:WaitForChild("Systems")
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Initialize Analytics
local AnalyticsService = require(Shared:WaitForChild("AnalyticsService"))
AnalyticsService.Init({
    baseUrl = "https://analytics.arcadias.games",
    apiKey = "flowandroadaregay1234567",
    gameId = "feedthebrainrots"
})

-- Initialize Performance Monitor
local PerformanceMonitor = require(Systems:WaitForChild("PerformanceMonitor"))
PerformanceMonitor.SetupLOD()

print("🌱 FeedTheBrainrots initialized")
