-- CollectionSystem.lua
-- Handles brainrot spawning, collection, and rarity zones

local CollectionSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Load brainrot data
local BrainrotsData = require(ReplicatedStorage.Shared.Modules.Libraries.BrainrotsData)

-- Configuration
local CONFIG = {
    SPAWN_INTERVAL = 10, -- Seconds between spawn cycles
    MAX_SPAWNED = 50,    -- Max brainrots in world at once
    DESPAWN_TIME = 120,  -- Seconds before despawn
    
    -- Zone distances from spawn
    ZONES = {
        {name = "Common", distance = 0, rarities = {"Common"}, color = Color3.fromRGB(169, 169, 169)},
        {name = "Uncommon", distance = 50, rarities = {"Uncommon"}, color = Color3.fromRGB(0, 255, 0)},
        {name = "Rare", distance = 100, rarities = {"Rare"}, color = Color3.fromRGB(0, 100, 255)},
        {name = "Epic", distance = 200, rarities = {"Epic"}, color = Color3.fromRGB(150, 0, 255)},
        {name = "Legendary", distance = 350, rarities = {"Legendary"}, color = Color3.fromRGB(255, 215, 0)},
        {name = "Mythical", distance = 500, rarities = {"Mythical"}, color = Color3.fromRGB(255, 0, 100)}
    }
}

-- Rarity weights
local RARITY_WEIGHTS = {
    Common = 50,
    Uncommon = 30,
    Rare = 15,
    Epic = 4,
    Legendary = 0.9,
    Mythical = 0.1
}

-- State
local spawnedBrainrots = {}
local playerInventory = {} -- [player] = {brainrots = {}, capacity = 3}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CollectBrainrotEvent = Instance.new("RemoteEvent")
CollectBrainrotEvent.Name = "CollectBrainrotEvent"
CollectBrainrotEvent.Parent = Remotes

local InventoryUpdateEvent = Instance.new("RemoteEvent")
InventoryUpdateEvent.Name = "InventoryUpdateEvent"
InventoryUpdateEvent.Parent = Remotes

function CollectionSystem.Init()
    -- Start spawn cycle
    spawn(CollectionSystem.SpawnCycle)
    
    -- Setup collection remote
    CollectBrainrotEvent.OnServerEvent:Connect(CollectionSystem.OnCollectRequest)
    
    print("🧠 Collection System initialized")
end

function CollectionSystem.SpawnCycle()
    while true do
        wait(CONFIG.SPAWN_INTERVAL)
        
        if #spawnedBrainrots < CONFIG.MAX_SPAWNED then
            CollectionSystem.SpawnBrainrotBatch()
        end
        
        -- Clean up old brainrots
        CollectionSystem.CleanupOldBrainrots()
    end
end

function CollectionSystem.SpawnBrainrotBatch()
    local batchSize = math.min(5, CONFIG.MAX_SPAWNED - #spawnedBrainrots)
    
    for i = 1, batchSize do
        CollectionSystem.SpawnRandomBrainrot()
        wait(0.5) -- Stagger spawns
    end
end

function CollectionSystem.SpawnRandomBrainrot()
    -- Pick random spawn point based on zones
    local spawnPoints = workspace:FindFirstChild("BrainrotSpawnPoints")
    if not spawnPoints or #spawnPoints:GetChildren() == 0 then
        -- Fallback: spawn near center with random offset
        CollectionSystem.SpawnAtPosition(Vector3.new(0, 5, 0))
        return
    end
    
    -- Pick random spawn point
    local spawnPointsList = spawnPoints:GetChildren()
    local spawnPoint = spawnPointsList[math.random(1, #spawnPointsList)]
    
    CollectionSystem.SpawnAtPosition(spawnPoint.Position)
end

function CollectionSystem.SpawnAtPosition(position)
    -- Determine rarity based on zone distance from spawn
    local distanceFromSpawn = (position - Vector3.new(0, 0, 0)).Magnitude
    local rarity = CollectionSystem.GetRarityForDistance(distanceFromSpawn)
    
    -- Pick random brainrot of that rarity
    local brainrotName = CollectionSystem.GetRandomBrainrotByRarity(rarity)
    if not brainrotName then return end
    
    local brainrotData = BrainrotsData[brainrotName]
    
    -- Create brainrot model
    local brainrot = CollectionSystem.CreateBrainrotModel(brainrotName, rarity, position)
    
    -- Track spawned brainrot
    table.insert(spawnedBrainrots, {
        model = brainrot,
        name = brainrotName,
        rarity = rarity,
        data = brainrotData,
        spawnTime = tick()
    })
end

function CollectionSystem.GetRarityForDistance(distance)
    -- Further from spawn = higher chance of rare
    local rand = math.random(1, 1000) / 10
    
    -- Adjust weights based on distance
    local adjustedWeights = {}
    for rarity, weight in pairs(RARITY_WEIGHTS) do
        adjustedWeights[rarity] = weight
    end
    
    -- Boost rare chances for far zones
    if distance > 400 then
        adjustedWeights.Mythical = adjustedWeights.Mythical * 5
        adjustedWeights.Legendary = adjustedWeights.Legendary * 3
    elseif distance > 250 then
        adjustedWeights.Legendary = adjustedWeights.Legendary * 2
        adjustedWeights.Epic = adjustedWeights.Epic * 1.5
    elseif distance > 150 then
        adjustedWeights.Epic = adjustedWeights.Epic * 1.3
        adjustedWeights.Rare = adjustedWeights.Rare * 1.2
    end
    
    -- Weighted random selection
    local totalWeight = 0
    for _, weight in pairs(adjustedWeights) do
        totalWeight = totalWeight + weight
    end
    
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for rarity, weight in pairs(adjustedWeights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return rarity
        end
    end
    
    return "Common"
end

function CollectionSystem.GetRandomBrainrotByRarity(rarity)
    -- Filter brainrots by rarity (for now, all are treated similarly)
    -- In a real implementation, you'd tag brainrots with rarities
    local brainrotNames = {}
    for name, _ in pairs(BrainrotsData) do
        table.insert(brainrotNames, name)
    end
    
    if #brainrotNames == 0 then return nil end
    return brainrotNames[math.random(1, #brainrotNames)]
end

function CollectionSystem.CreateBrainrotModel(name, rarity, position)
    -- Create placeholder model (replace with actual assets later)
    local model = Instance.new("Model")
    model.Name = name
    
    local part = Instance.new("Part")
    part.Name = "BrainrotPart"
    part.Size = Vector3.new(3, 3, 3)
    part.Position = position + Vector3.new(0, 3, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Shape = Enum.PartType.Ball
    
    -- Color based on rarity
    local colors = {
        Common = Color3.fromRGB(169, 169, 169),
        Uncommon = Color3.fromRGB(0, 255, 0),
        Rare = Color3.fromRGB(0, 100, 255),
        Epic = Color3.fromRGB(150, 0, 255),
        Legendary = Color3.fromRGB(255, 215, 0),
        Mythical = Color3.fromRGB(255, 0, 100)
    }
    part.Color = colors[rarity] or colors.Common
    part.Material = Enum.Material.Neon
    
    -- Add glow
    local light = Instance.new("PointLight")
    light.Color = part.Color
    light.Brightness = 2
    light.Range = 8
    light.Parent = part
    
    -- Floating animation
    local floatTween = TweenService:Create(part, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Position = position + Vector3.new(0, 4, 0)
    })
    floatTween:Play()
    
    -- Spin animation
    local spinTween = TweenService:Create(part, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {
        Orientation = Vector3.new(0, 360, 0)
    })
    spinTween:Play()
    
    -- Click detector for collection
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 15
    clickDetector.MouseClick:Connect(function(player)
        CollectionSystem.CollectBrainrot(player, model)
    end)
    clickDetector.Parent = part
    
    -- Billboard GUI for name
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = false
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = part.Color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard
    
    billboard.Parent = part
    
    part.Parent = model
    model.Parent = workspace.Brainrots
    
    return model
end

function CollectionSystem.OnCollectRequest(player, brainrotModel)
    CollectionSystem.CollectBrainrot(player, brainrotModel)
end

function CollectionSystem.CollectBrainrot(player, brainrotModel)
    -- Check player inventory capacity
    if not playerInventory[player] then
        playerInventory[player] = {brainrots = {}, capacity = 3}
    end
    
    local inventory = playerInventory[player]
    if #inventory.brainrots >= inventory.capacity then
        -- Inventory full
        return
    end
    
    -- Find brainrot data
    local brainrotData = nil
    local index = nil
    for i, data in ipairs(spawnedBrainrots) do
        if data.model == brainrotModel then
            brainrotData = data
            index = i
            break
        end
    end
    
    if not brainrotData then return end
    
    -- Add to inventory
    table.insert(inventory.brainrots, {
        name = brainrotData.name,
        rarity = brainrotData.rarity,
        data = brainrotData.data
    })
    
    -- Remove from world
    brainrotModel:Destroy()
    table.remove(spawnedBrainrots, index)
    
    -- Update client
    InventoryUpdateEvent:FireClient(player, inventory)
    
    -- Track analytics
    -- AnalyticsService.TrackEvent("BrainrotCollected", {rarity = brainrotData.rarity})
end

function CollectionSystem.CleanupOldBrainrots()
    local now = tick()
    for i = #spawnedBrainrots, 1, -1 do
        local data = spawnedBrainrots[i]
        if now - data.spawnTime > CONFIG.DESPAWN_TIME then
            if data.model and data.model.Parent then
                data.model:Destroy()
            end
            table.remove(spawnedBrainrots, i)
        end
    end
end

function CollectionSystem.GetPlayerInventory(player)
    if not playerInventory[player] then
        playerInventory[player] = {brainrots = {}, capacity = 3}
    end
    return playerInventory[player]
end

function CollectionSystem.ClearPlayerInventory(player)
    if playerInventory[player] then
        playerInventory[player].brainrots = {}
        InventoryUpdateEvent:FireClient(player, playerInventory[player])
    end
end

return CollectionSystem
