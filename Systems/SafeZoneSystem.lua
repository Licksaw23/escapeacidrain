-- SafeZoneSystem.lua
-- Manages safe zones where players are protected from acid rain

local SafeZoneSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    SAFE_ZONE_CHECK_INTERVAL = 0.5
}

-- State
local safeZones = {}
local zoneConnections = {}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SafeZoneUpdateEvent = Instance.new("RemoteEvent")
SafeZoneUpdateEvent.Name = "SafeZoneUpdateEvent"
SafeZoneUpdateEvent.Parent = Remotes

function SafeZoneSystem.Init()
    -- Load existing safe zones from workspace
    SafeZoneSystem.LoadSafeZones()
    
    -- Start monitoring
    spawn(SafeZoneSystem.MonitorPlayers)
    
    print("☂️ Safe Zone System initialized")
end

function SafeZoneSystem.LoadSafeZones()
    local zonesFolder = workspace:FindFirstChild("SafeZones")
    if not zonesFolder then
        -- Create default safe zones if none exist
        SafeZoneSystem.CreateDefaultSafeZones()
        return
    end
    
    for _, zone in ipairs(zonesFolder:GetChildren()) do
        if zone:IsA("BasePart") then
            SafeZoneSystem.SetupSafeZone(zone)
        end
    end
end

function SafeZoneSystem.CreateDefaultSafeZones()
    -- Create starter safe zone near spawn
    local safeZonesFolder = Instance.new("Folder")
    safeZonesFolder.Name = "SafeZones"
    safeZonesFolder.Parent = workspace
    
    -- Umbrella safe zones scattered around
    local positions = {
        Vector3.new(0, 0, 0),      -- Spawn
        Vector3.new(50, 0, 0),     -- Common zone
        Vector3.new(0, 0, 50),     -- Uncommon zone
        Vector3.new(-50, 0, 0),    -- Rare zone side
        Vector3.new(100, 5, 100),  -- Far rare zone
        Vector3.new(-100, 10, -50) -- Epic zone
    }
    
    for i, pos in ipairs(positions) do
        SafeZoneSystem.CreateUmbrellaSafeZone(pos, "SafeZone_" .. i)
    end
end

function SafeZoneSystem.CreateUmbrellaSafeZone(position, name)
    local umbrella = Instance.new("Model")
    umbrella.Name = name
    
    -- Canopy
    local canopy = Instance.new("Part")
    canopy.Name = "Canopy"
    canopy.Shape = Enum.PartType.Cylinder
    canopy.Size = Vector3.new(2, 20, 20)
    canopy.Position = position + Vector3.new(0, 8, 0)
    canopy.Anchored = true
    canopy.CanCollide = true
    canopy.Color = Color3.fromRGB(100, 200, 255)
    canopy.Material = Enum.Material.Plastic
    canopy.Rotation = Vector3.new(0, 0, 90)
    canopy.Parent = umbrella
    
    -- Pole
    local pole = Instance.new("Part")
    pole.Name = "Pole"
    pole.Size = Vector3.new(1, 10, 1)
    pole.Position = position
    pole.Anchored = true
    pole.CanCollide = true
    pole.Color = Color3.fromRGB(100, 100, 100)
    pole.Material = Enum.Material.Metal
    pole.Parent = umbrella
    
    -- Safe zone indicator (invisible part for detection)
    local safeZone = Instance.new("Part")
    safeZone.Name = "SafeZone"
    safeZone.Size = Vector3.new(18, 15, 18)
    safeZone.Position = position + Vector3.new(0, 5, 0)
    safeZone.Anchored = true
    safeZone.CanCollide = false
    safeZone.Transparency = 0.8
    safeZone.Color = Color3.fromRGB(0, 255, 100)
    safeZone.Material = Enum.Material.ForceField
    safeZone.Parent = umbrella
    
    -- Add attributes
    safeZone:SetAttribute("IsSafeZone", true)
    safeZone:SetAttribute("ZoneType", "Umbrella")
    
    -- Glow effect
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(0, 255, 100)
    light.Brightness = 1
    light.Range = 15
    light.Parent = safeZone
    
    umbrella.Parent = workspace.SafeZones
    
    SafeZoneSystem.SetupSafeZone(safeZone)
    
    return umbrella
end

function SafeZoneSystem.SetupSafeZone(zone)
    table.insert(safeZones, zone)
    
    -- Visual pulse animation
    spawn(function()
        while zone and zone.Parent do
            local tween = TweenService:Create(zone, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.6
            })
            tween:Play()
            tween.Completed:Wait()
            
            local tween2 = TweenService:Create(zone, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.9
            })
            tween2:Play()
            tween2.Completed:Wait()
        end
    end)
end

function SafeZoneSystem.MonitorPlayers()
    local Players = game:GetService("Players")
    
    while true do
        wait(CONFIG.SAFE_ZONE_CHECK_INTERVAL)
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local isSafe = SafeZoneSystem.IsInSafeZone(rootPart.Position)
                    SafeZoneUpdateEvent:FireClient(player, {isSafe = isSafe})
                end
            end
        end
    end
end

function SafeZoneSystem.IsInSafeZone(position)
    for _, zone in ipairs(safeZones) do
        if zone and zone.Parent then
            local dx = math.abs(position.X - zone.Position.X)
            local dy = math.abs(position.Y - zone.Position.Y)
            local dz = math.abs(position.Z - zone.Position.Z)
            
            if dx < zone.Size.X/2 and dy < zone.Size.Y/2 and dz < zone.Size.Z/2 then
                return true
            end
        end
    end
    
    -- Also check buildings/caves
    local buildings = workspace:FindFirstChild("Buildings")
    if buildings then
        for _, building in ipairs(buildings:GetChildren()) do
            -- Simple bounding box check
            -- More complex checks would use Region3 or ZonePlus
        end
    end
    
    return false
end

function SafeZoneSystem.CreateBuildingSafeZone(buildingModel)
    -- Mark building interior as safe
    local interior = buildingModel:FindFirstChild("Interior") or buildingModel
    
    local safeZone = Instance.new("Part")
    safeZone.Name = "BuildingSafeZone"
    safeZone.Size = interior.Size
    safeZone.CFrame = interior.CFrame
    safeZone.Anchored = true
    safeZone.CanCollide = false
    safeZone.Transparency = 1
    safeZone:SetAttribute("IsSafeZone", true)
    safeZone:SetAttribute("ZoneType", "Building")
    safeZone.Parent = workspace.SafeZones
    
    SafeZoneSystem.SetupSafeZone(safeZone)
end

return SafeZoneSystem
