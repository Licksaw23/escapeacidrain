-- CollectionSystem.lua
-- Spawns brainrots from ReplicatedStorage into rarity zones

local CollectionSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Configuration
local CONFIG = {
    MAX_SPAWNED = 50,
    SPAWN_INTERVAL = 8,
    DESPAWN_TIME = 180,
    
    -- Spawn counts per cycle
    SPAWN_BATCH = {
        min = 3,
        max = 6
    }
}

-- State
local spawnedBrainrots = {}
local playerInventory = {}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdateEvent = Instance.new("RemoteEvent")
InventoryUpdateEvent.Name = "InventoryUpdateEvent"
InventoryUpdateEvent.Parent = Remotes

function CollectionSystem.Init()
    -- Wait for zones to exist
    local zones = CollectionSystem.GetRarityZones()
    if not zones or #zones == 0 then
        warn("⚠️ No rarity zones found! Create parts named Common, Rare, Legendary, Mythic, Secret in workspace")
    end
    
    -- Start spawn cycle
    task.spawn(CollectionSystem.SpawnCycle)
    
    print("🧠 Collection System initialized")
end

function CollectionSystem.GetRarityZones()
    local zones = {}
    local rarityNames = {"Common", "Rare", "Legendary", "Mythic", "Secret"}
    
    for _, name in ipairs(rarityNames) do
        local zone = workspace:FindFirstChild(name)
        if zone and zone:IsA("BasePart") then
            table.insert(zones, {
                name = name,
                part = zone,
                rarity = name
            })
        end
    end
    
    return zones
end

function CollectionSystem.GetBrainrotModels()
    local modelsFolder = ReplicatedStorage:FindFirstChild("Shared")
        and ReplicatedStorage.Shared:FindFirstChild("Models")
        and ReplicatedStorage.Shared.Models:FindFirstChild("Brainrots")
    
    if not modelsFolder then
        return {}
    end
    
    local models = {}
    for _, model in ipairs(modelsFolder:GetChildren()) do
        if model:IsA("Model") then
            local rarity = model:GetAttribute("Rarity") or "Common"
            table.insert(models, {
                model = model,
                name = model.Name,
                rarity = rarity
            })
        end
    end
    
    return models
end

function CollectionSystem.SpawnCycle()
    while true do
        task.wait(CONFIG.SPAWN_INTERVAL)
        
        local currentCount = #spawnedBrainrots
        if currentCount < CONFIG.MAX_SPAWNED then
            local toSpawn = math.random(CONFIG.SPAWN_BATCH.min, CONFIG.SPAWN_BATCH.max)
            toSpawn = math.min(toSpawn, CONFIG.MAX_SPAWNED - currentCount)
            
            for i = 1, toSpawn do
                CollectionSystem.SpawnRandomBrainrot()
                task.wait(0.3)
            end
        end
        
        CollectionSystem.CleanupOldBrainrots()
    end
end

function CollectionSystem.SpawnRandomBrainrot()
    local zones = CollectionSystem.GetRarityZones()
    local models = CollectionSystem.GetBrainrotModels()
    
    if #models == 0 then
        warn("⚠️ No brainrot models in ReplicatedStorage.Shared.Models.Brainrots")
        return
    end
    
    if #zones == 0 then
        warn("⚠️ No rarity zones found in workspace")
        return
    end
    
    -- Pick random model
    local modelData = models[math.random(1, #models)]
    local targetRarity = modelData.rarity
    
    -- Find matching zone
    local targetZone = nil
    for _, zone in ipairs(zones) do
        if zone.rarity == targetRarity then
            targetZone = zone
            break
        end
    end
    
    -- Fallback to random zone if no match
    if not targetZone then
        targetZone = zones[math.random(1, #zones)]
    end
    
    CollectionSystem.SpawnBrainrotInZone(modelData, targetZone)
end

function CollectionSystem.SpawnBrainrotInZone(modelData, zone)
    local brainrotsFolder = workspace:FindFirstChild("Brainrots")
    if not brainrotsFolder then
        brainrotsFolder = Instance.new("Folder")
        brainrotsFolder.Name = "Brainrots"
        brainrotsFolder.Parent = workspace
    end
    
    -- Clone the model
    local clonedModel = modelData.model:Clone()
    clonedModel.Name = modelData.name
    
    -- Random position within zone bounds
    local zonePart = zone.part
    local size = zonePart.Size
    local cframe = zonePart.CFrame
    
    -- Generate random position inside the part
    local randomX = (math.random() - 0.5) * size.X * 0.8
    local randomZ = (math.random() - 0.5) * size.Z * 0.8
    local position = cframe.Position + Vector3.new(randomX, size.Y/2 + 2, randomZ)
    
    -- Set position
    local primaryPart = clonedModel:FindFirstChild("HumanoidRootPart") or clonedModel:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        clonedModel:PivotTo(CFrame.new(position))
    end
    
    -- Add click detector for collection
    local clickPart = primaryPart or clonedModel:FindFirstChildWhichIsA("BasePart")
    if clickPart then
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 20
        clickDetector.MouseClick:Connect(function(player)
            CollectionSystem.OnBrainrotClicked(player, clonedModel, modelData)
        end)
        clickDetector.Parent = clickPart
        
        -- Highlight when player gets close
        CollectionSystem.SetupProximityHighlight(clonedModel, clickPart)
    end
    
    clonedModel.Parent = brainrotsFolder
    
    -- Play idle animation if available
    CollectionSystem.PlayIdleAnimation(clonedModel)
    
    -- Track spawned brainrot
    table.insert(spawnedBrainrots, {
        model = clonedModel,
        data = modelData,
        spawnTime = tick()
    })
end

function CollectionSystem.PlayIdleAnimation(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Look for Idle animation
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
    if torso then
        local idle = torso:FindFirstChild("Idle")
        if idle and idle:IsA("Animation") then
            humanoid:LoadAnimation(idle):Play()
        end
    end
    
    -- Also check AnimSaves folder
    local animSaves = model:FindFirstChild("AnimSaves")
    if animSaves then
        for _, anim in ipairs(animSaves:GetChildren()) do
            if anim:IsA("Animation") and anim.Name:lower():find("idle") then
                local track = humanoid:LoadAnimation(anim)
                track:Play()
                break
            end
        end
    end
end

function CollectionSystem.SetupProximityHighlight(model, part)
    -- Add BillboardGui for name
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 50
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = model.Name
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard
    
    billboard.Parent = part
    
    -- Highlight effect when nearby
    local highlight = Instance.new("Highlight")
    highlight.Name = "CollectionHighlight"
    highlight.FillColor = Color3.fromRGB(0, 255, 100)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Parent = model
end

function CollectionSystem.OnBrainrotClicked(player, model, modelData)
    -- Check inventory
    if not playerInventory[player] then
        playerInventory[player] = {brainrots = {}, capacity = 3}
    end
    
    local inventory = playerInventory[player]
    if #inventory.brainrots >= inventory.capacity then
        -- Inventory full - notify player
        return
    end
    
    -- Add to inventory
    table.insert(inventory.brainrots, {
        name = modelData.name,
        rarity = modelData.rarity,
        modelTemplate = modelData.model
    })
    
    -- Remove from world
    model:Destroy()
    
    -- Remove from tracking
    for i, data in ipairs(spawnedBrainrots) do
        if data.model == model then
            table.remove(spawnedBrainrots, i)
            break
        end
    end
    
    -- Update client
    InventoryUpdateEvent:FireClient(player, inventory)
    
    print(string.format("%s collected %s (%s)", player.Name, modelData.name, modelData.rarity))
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

function CollectionSystem.RemoveFromInventory(player, index)
    if playerInventory[player] and playerInventory[player].brainrots[index] then
        table.remove(playerInventory[player].brainrots, index)
        InventoryUpdateEvent:FireClient(player, playerInventory[player])
        return true
    end
    return false
end

return CollectionSystem