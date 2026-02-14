-- AcidRainSystem.lua
-- Core acid rain mechanics - waves of toxic rain with safe zones

local AcidRainSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Configuration
local CONFIG = {
    WAVE_INTERVAL = 45, -- Seconds between waves
    WAVE_DURATION = 20, -- Seconds of acid rain
    WARNING_TIME = 5,   -- Seconds of warning before rain
    DAMAGE_PER_SECOND = 10,
    RAIN_TYPES = {
        "Light",    -- Small damage, short duration
        "Medium",   -- Normal damage
        "Heavy",    -- High damage, longer duration
        "AcidStorm" -- Chaos mode (admin events)
    }
}

-- State
local isRaining = false
local currentWaveType = nil
local nextWaveTime = 0
local acidPuddles = {}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AcidRainEvent = Instance.new("RemoteEvent")
AcidRainEvent.Name = "AcidRainEvent"
AcidRainEvent.Parent = Remotes

local SafeZoneEvent = Instance.new("RemoteEvent")
SafeZoneEvent.Name = "SafeZoneEvent"
SafeZoneEvent.Parent = Remotes

function AcidRainSystem.Init()
    -- Start the wave cycle
    spawn(AcidRainSystem.WaveCycle)
    
    -- Monitor players in acid
    RunService.Heartbeat:Connect(AcidRainSystem.CheckPlayerDamage)
    
    print("🌧️ Acid Rain System initialized")
end

function AcidRainSystem.WaveCycle()
    while true do
        -- Wait until next wave
        wait(CONFIG.WAVE_INTERVAL)
        
        -- Warning phase
        AcidRainSystem.BroadcastWarning()
        wait(CONFIG.WARNING_TIME)
        
        -- Start acid rain
        AcidRainSystem.StartRain()
        wait(CONFIG.WAVE_DURATION)
        
        -- Stop acid rain
        AcidRainSystem.StopRain()
    end
end

function AcidRainSystem.BroadcastWarning()
    -- Tell all clients to show warning UI
    AcidRainEvent:FireAllClients({
        action = "warning",
        message = "ACID RAIN INCOMING!",
        duration = CONFIG.WARNING_TIME
    })
    
    -- Play warning sound
    for _, player in ipairs(Players:GetPlayers()) do
        -- Sound played client-side
    end
end

function AcidRainSystem.StartRain()
    isRaining = true
    currentWaveType = AcidRainSystem.GetRandomWaveType()
    
    -- Spawn acid puddles
    AcidRainSystem.SpawnAcidPuddles()
    
    -- Notify clients
    AcidRainEvent:FireAllClients({
        action = "start",
        type = currentWaveType,
        duration = CONFIG.WAVE_DURATION
    })
    
    print("🌧️ Acid rain started! Type:", currentWaveType)
end

function AcidRainSystem.StopRain()
    isRaining = false
    currentWaveType = nil
    
    -- Clear acid puddles
    AcidRainSystem.ClearAcidPuddles()
    
    -- Notify clients
    AcidRainEvent:FireAllClients({
        action = "stop"
    })
    
    print("☀️ Acid rain stopped")
end

function AcidRainSystem.GetRandomWaveType()
    local rand = math.random()
    if rand < 0.5 then
        return "Light"
    elseif rand < 0.8 then
        return "Medium"
    else
        return "Heavy"
    end
end

function AcidRainSystem.SpawnAcidPuddles()
    -- Get spawn locations from workspace
    local puddleSpawns = workspace:FindFirstChild("AcidPuddleSpawns")
    if not puddleSpawns then return end
    
    for _, spawnPoint in ipairs(puddleSpawns:GetChildren()) do
        if math.random() < 0.7 then -- 70% chance to spawn
            local puddle = AcidRainSystem.CreateAcidPuddle(spawnPoint.Position)
            table.insert(acidPuddles, puddle)
        end
    end
end

function AcidRainSystem.CreateAcidPuddle(position)
    local puddle = Instance.new("Part")
    puddle.Name = "AcidPuddle"
    puddle.Shape = Enum.PartType.Cylinder
    puddle.Size = Vector3.new(0.1, math.random(8, 16), math.random(8, 16))
    puddle.Position = position
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.Material = Enum.Material.Neon
    puddle.Color = Color3.fromRGB(0, 255, 100) -- Toxic green
    puddle.Parent = workspace
    
    -- Add point light for glow
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(0, 255, 100)
    light.Brightness = 2
    light.Range = 10
    light.Parent = puddle
    
    -- Scale up animation
    puddle.Size = Vector3.new(0.1, 1, 1)
    TweenService:Create(puddle, TweenInfo.new(2), {
        Size = Vector3.new(0.1, puddle.Size.Y, puddle.Size.Z)
    }):Play()
    
    return puddle
end

function AcidRainSystem.ClearAcidPuddles()
    for _, puddle in ipairs(acidPuddles) do
        if puddle and puddle.Parent then
            -- Shrink animation
            TweenService:Create(puddle, TweenInfo.new(1), {
                Size = Vector3.new(0.1, 0.1, 0.1)
            }):Play()
            
            -- Destroy after animation
            delay(1, function()
                if puddle and puddle.Parent then
                    puddle:Destroy()
                end
            end)
        end
    end
    acidPuddles = {}
end

function AcidRainSystem.CheckPlayerDamage()
    if not isRaining then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if rootPart and humanoid then
                -- Check if in safe zone
                if not AcidRainSystem.IsInSafeZone(rootPart.Position) then
                    -- Check if touching acid puddle
                    if AcidRainSystem.IsTouchingAcid(rootPart.Position) then
                        humanoid:TakeDamage(CONFIG.DAMAGE_PER_SECOND * RunService.Heartbeat.Interval)
                    end
                end
            end
        end
    end
end

function AcidRainSystem.IsInSafeZone(position)
    -- Check safe zones (umbrellas, buildings, caves)
    local safeZones = workspace:FindFirstChild("SafeZones")
    if not safeZones then return false end
    
    for _, zone in ipairs(safeZones:GetChildren()) do
        if zone:IsA("BasePart") then
            local distance = (position - zone.Position).Magnitude
            if distance < (zone.Size.X / 2) then
                return true
            end
        end
    end
    
    return false
end

function AcidRainSystem.IsTouchingAcid(position)
    -- Check if player is over an acid puddle
    for _, puddle in ipairs(acidPuddles) do
        if puddle and puddle.Parent then
            local dx = math.abs(position.X - puddle.Position.X)
            local dz = math.abs(position.Z - puddle.Position.Z)
            if dx < (puddle.Size.Y / 2) and dz < (puddle.Size.Z / 2) then
                return true
            end
        end
    end
    
    -- Check if raining directly on player (not under cover)
    if isRaining then
        local rayOrigin = position + Vector3.new(0, 50, 0)
        local rayDirection = Vector3.new(0, -100, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {workspace:FindFirstChild("SafeZones") or Instance.new("Model")}
        
        local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        if not result then
            return true -- No cover above
        end
    end
    
    return false
end

-- Admin command to force acid storm
function AcidRainSystem.TriggerAcidStorm()
    AcidRainSystem.StopRain()
    wait(1)
    isRaining = true
    currentWaveType = "AcidStorm"
    AcidRainSystem.SpawnAcidPuddles()
    AcidRainEvent:FireAllClients({
        action = "start",
        type = "AcidStorm",
        duration = 60,
        isAdmin = true
    })
end

return AcidRainSystem
