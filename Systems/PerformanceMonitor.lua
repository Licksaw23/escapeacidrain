-- PerformanceMonitor.lua
-- Place in ServerScriptService
-- Sends performance metrics to analytics dashboard

local PerformanceMonitor = {}

local CONFIG = {
    BASE_URL = "https://analytics.arcadias.games",
    API_KEY = "flowandroadaregay1234567",
    GAME_ID = "feedthebrainrots",
    REPORT_INTERVAL = 60 -- Send stats every 60 seconds
}

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Performance tracking
local performanceStats = {
    fps = {},
    memory = {},
    heartbeat = {},
    physics = {}
}

-- Calculate average FPS over last minute
local function calculateFPS()
    local total = 0
    local count = #performanceStats.fps
    if count == 0 then return 60 end
    
    for _, fps in ipairs(performanceStats.fps) do
        total += fps
    end
    return math.round(total / count)
end

-- Get memory usage
local function getMemoryUsage()
    return math.round(game:GetService("Stats").GetTotalMemoryUsageMb())
end

-- Get heartbeat time (script performance)
local function getHeartbeatTime()
    return math.round(RunService.HeartbeatTimeMs * 100) / 100
end

-- Get physics step time
local function getPhysicsTime()
    return math.round(RunService.PhysicsStepTimeMs * 100) / 100
end

-- Send performance data to analytics
local function sendPerformanceData()
    local playerCount = #Players:GetPlayers()
    if playerCount == 0 then return end
    
    local data = {
        apiKey = CONFIG.API_KEY,
        gameId = CONFIG.GAME_ID,
        timestamp = os.time() * 1000,
        playerCount = playerCount,
        fps = calculateFPS(),
        memory = getMemoryUsage(),
        heartbeat = getHeartbeatTime(),
        physics = getPhysicsTime(),
        -- Platform detection
        platform = "Unknown"
    }
    
    -- Detect platform from players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId then
            -- Check if mobile
            if player:GetAttribute("Platform") == "Mobile" then
                data.platform = "Mobile"
            elseif player:GetAttribute("Platform") == "Console" then
                data.platform = "Console"
            else
                data.platform = "PC"
            end
            break
        end
    end
    
    pcall(function()
        HttpService:PostAsync(
            CONFIG.BASE_URL .. "/api/performance/report",
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
end

-- Track FPS
local lastFrameTime = tick()
RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    local delta = currentTime - lastFrameTime
    lastFrameTime = currentTime
    
    local fps = math.min(60, math.round(1 / delta))
    table.insert(performanceStats.fps, fps)
    
    -- Keep only last 60 frames
    if #performanceStats.fps > 60 then
        table.remove(performanceStats.fps, 1)
    end
end)

-- Periodic reporting
spawn(function()
    while true do
        wait(CONFIG.REPORT_INTERVAL)
        sendPerformanceData()
    end
end)

-- Client-side performance (optional)
function PerformanceMonitor.SendClientPerformance(player, clientData)
    local data = {
        apiKey = CONFIG.API_KEY,
        gameId = CONFIG.GAME_ID,
        timestamp = os.time() * 1000,
        playerId = tostring(player.UserId),
        clientFps = clientData.fps,
        clientMemory = clientData.memory,
        deviceType = clientData.deviceType,
        graphicsQuality = clientData.graphicsQuality
    }
    
    pcall(function()
        HttpService:PostAsync(
            CONFIG.BASE_URL .. "/api/performance/client",
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
end

-- LOD System
function PerformanceMonitor.SetupLOD()
    local function updateLOD()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    -- Iterate all plants/brainrots
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and obj:GetAttribute("LOD") then
                            local distance = (obj.Position - root.Position).Magnitude
                            local lodLevel = obj:GetAttribute("LODLevel") or 1
                            
                            if distance > 50 then
                                -- Far away: simple mesh or invisible
                                obj.Transparency = 0.5
                                if obj:FindFirstChild("DetailMesh") then
                                    obj.DetailMesh.Enabled = false
                                end
                            elseif distance > 30 then
                                -- Medium: reduced detail
                                obj.Transparency = 0
                                if obj:FindFirstChild("DetailMesh") then
                                    obj.DetailMesh.Enabled = false
                                end
                            else
                                -- Close: full detail
                                obj.Transparency = 0
                                if obj:FindFirstChild("DetailMesh") then
                                    obj.DetailMesh.Enabled = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Update LOD every 2 seconds
    spawn(function()
        while true do
            wait(2)
            pcall(updateLOD)
        end
    end)
end

-- Initialize
PerformanceMonitor.SetupLOD()

return PerformanceMonitor
