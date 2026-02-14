-- BaseSystem.lua
-- Tycoon base - store brainrots and generate passive income

local BaseSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Configuration
local CONFIG = {
    INCOME_TICK_RATE = 1, -- Seconds between income ticks
    BASE_SLOTS = 5,
    MAX_SLOTS = 40,
    UPGRADE_COST_BASE = 1000,
    UPGRADE_COST_MULTIPLIER = 1.3
}

-- Player bases
local playerBases = {} -- [player] = {slots = {}, level = 1, totalIncome = 0}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BaseUpdateEvent = Instance.new("RemoteEvent")
BaseUpdateEvent.Name = "BaseUpdateEvent"
BaseUpdateEvent.Parent = Remotes

local DepositBrainrotEvent = Instance.new("RemoteEvent")
DepositBrainrotEvent.Name = "DepositBrainrotEvent"
DepositBrainrotEvent.Parent = Remotes

function BaseSystem.Init()
    -- Setup deposit handler
    DepositBrainrotEvent.OnServerEvent:Connect(BaseSystem.OnDepositRequest)
    
    -- Start income loop
    spawn(BaseSystem.IncomeLoop)
    
    -- Create bases for joining players
    Players.PlayerAdded:Connect(BaseSystem.CreatePlayerBase)
    
    print("🏠 Base System initialized")
end

function BaseSystem.CreatePlayerBase(player)
    -- Initialize player base data
    playerBases[player] = {
        slots = {},
        level = 1,
        totalIncome = 0,
        position = BaseSystem.GetBasePosition(player)
    }
    
    -- Create physical base
    BaseSystem.BuildPhysicalBase(player)
    
    -- Send initial data to client
    BaseUpdateEvent:FireClient(player, {
        action = "init",
        level = 1,
        maxSlots = BaseSystem.GetMaxSlots(1),
        slots = {},
        totalIncome = 0
    })
end

function BaseSystem.GetBasePosition(player)
    -- Assign unique position for each player
    local playerNum = #Players:GetPlayers()
    local angle = (playerNum * 45) * (math.pi / 180)
    local radius = 50 + (playerNum * 10)
    
    return Vector3.new(
        math.cos(angle) * radius,
        0,
        math.sin(angle) * radius
    )
end

function BaseSystem.BuildPhysicalBase(player)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local position = baseData.position
    
    -- Create base model
    local baseModel = Instance.new("Model")
    baseModel.Name = player.Name .. "_Base"
    
    -- Platform
    local platform = Instance.new("Part")
    platform.Name = "Platform"
    platform.Size = Vector3.new(30, 2, 30)
    platform.Position = position
    platform.Anchored = true
    platform.Color = Color3.fromRGB(100, 100, 100)
    platform.Material = Enum.Material.Concrete
    platform.Parent = baseModel
    
    -- Sign with player name
    local sign = Instance.new("Part")
    sign.Name = "Sign"
    sign.Size = Vector3.new(8, 4, 1)
    sign.Position = position + Vector3.new(0, 5, -12)
    sign.Anchored = true
    sign.Color = Color3.fromRGB(50, 50, 50)
    sign.Parent = baseModel
    
    -- Sign text
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 0, 0.6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name .. "'s Base"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.Parent = billboard
    
    billboard.Parent = sign
    
    -- Upgrade pad
    local upgradePad = Instance.new("Part")
    upgradePad.Name = "UpgradePad"
    upgradePad.Size = Vector3.new(4, 0.5, 4)
    upgradePad.Position = position + Vector3.new(10, 1.25, 10)
    upgradePad.Anchored = true
    upgradePad.Color = Color3.fromRGB(0, 200, 100)
    upgradePad.Material = Enum.Material.Neon
    upgradePad.Parent = baseModel
    
    -- Upgrade pad click detector
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 10
    clickDetector.MouseClick:Connect(function(clickingPlayer)
        if clickingPlayer == player then
            BaseSystem.TryUpgradeBase(player)
        end
    end)
    clickDetector.Parent = upgradePad
    
    -- Upgrade text
    local upgradeBillboard = Instance.new("BillboardGui")
    upgradeBillboard.Size = UDim2.new(0, 150, 0, 40)
    upgradeBillboard.StudsOffset = Vector3.new(0, 3, 0)
    
    local upgradeLabel = Instance.new("TextLabel")
    upgradeLabel.Size = UDim2.new(1, 0, 1, 0)
    upgradeLabel.BackgroundTransparency = 1
    upgradeLabel.Text = "UPGRADE BASE"
    upgradeLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    upgradeLabel.TextStrokeTransparency = 0
    upgradeLabel.Font = Enum.Font.GothamBold
    upgradeLabel.TextSize = 14
    upgradeLabel.Parent = upgradeBillboard
    
    upgradeBillboard.Parent = upgradePad
    
    baseModel.Parent = workspace:FindFirstChild("Bases") or workspace
    baseData.model = baseModel
    
    -- Create initial slots
    BaseSystem.CreateSlots(player)
end

function BaseSystem.CreateSlots(player)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local maxSlots = BaseSystem.GetMaxSlots(baseData.level)
    local position = baseData.position
    
    -- Clear existing slots
    for _, slot in ipairs(baseData.slots) do
        if slot.visual then
            slot.visual:Destroy()
        end
    end
    baseData.slots = {}
    
    -- Create slot platforms in grid
    local slotsPerRow = 5
    local spacing = 5
    local startX = -((slotsPerRow - 1) * spacing) / 2
    local startZ = 5
    
    for i = 1, maxSlots do
        local row = math.floor((i - 1) / slotsPerRow)
        local col = (i - 1) % slotsPerRow
        
        local slotPosition = position + Vector3.new(
            startX + (col * spacing),
            2,
            startZ + (row * spacing)
        )
        
        local slot = {
            id = i,
            position = slotPosition,
            brainrot = nil,
            visual = nil
        }
        
        -- Create slot visual
        local slotPart = Instance.new("Part")
        slotPart.Name = "Slot_" .. i
        slotPart.Size = Vector3.new(3, 0.5, 3)
        slotPart.Position = slotPosition
        slotPart.Anchored = true
        slotPart.Color = Color3.fromRGB(150, 150, 150)
        slotPart.Material = Enum.Material.SmoothPlastic
        slotPart.Transparency = 0.5
        slotPart.Parent = baseData.model
        
        slot.visual = slotPart
        table.insert(baseData.slots, slot)
    end
end

function BaseSystem.GetMaxSlots(level)
    return CONFIG.BASE_SLOTS + ((level - 1) * 5)
end

function BaseSystem.OnDepositRequest(player, brainrotIndex)
    local baseData = playerBases[player]
    if not baseData then return end
    
    -- Get player's held brainrots (from CollectionSystem)
    local CollectionSystem = require(game.ServerStorage.Systems.CollectionSystem)
    local inventory = CollectionSystem.GetPlayerInventory(player)
    
    if not inventory.brainrots[brainrotIndex] then
        return -- Invalid index
    end
    
    -- Find empty slot
    local emptySlot = nil
    for _, slot in ipairs(baseData.slots) do
        if not slot.brainrot then
            emptySlot = slot
            break
        end
    end
    
    if not emptySlot then
        BaseUpdateEvent:FireClient(player, {
            action = "error",
            message = "Base is full! Upgrade to add more slots."
        })
        return
    end
    
    -- Move brainrot from inventory to base
    local brainrot = table.remove(inventory.brainrots, brainrotIndex)
    emptySlot.brainrot = brainrot
    
    -- Create visual
    BaseSystem.CreateBrainrotVisual(player, emptySlot, brainrot)
    
    -- Update income
    baseData.totalIncome = baseData.totalIncome + (brainrot.data.MoneyPerSecond or 1)
    
    -- Notify client
    BaseUpdateEvent:FireClient(player, {
        action = "deposit",
        slotId = emptySlot.id,
        brainrot = brainrot,
        totalIncome = baseData.totalIncome
    })
    
    -- Update inventory UI
    CollectionSystem.ClearPlayerInventory(player)
end

function BaseSystem.CreateBrainrotVisual(player, slot, brainrot)
    local part = Instance.new("Part")
    part.Name = brainrot.name
    part.Size = Vector3.new(2, 2, 2)
    part.Position = slot.position + Vector3.new(0, 1.5, 0)
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
    part.Color = colors[brainrot.rarity] or colors.Common
    part.Material = Enum.Material.Neon
    
    -- Float animation
    TweenService:Create(part, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Position = slot.position + Vector3.new(0, 2.5, 0)
    }):Play()
    
    -- Spin animation
    TweenService:Create(part, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {
        Orientation = Vector3.new(0, 360, 0)
    }):Play()
    
    part.Parent = playerBases[player].model
    slot.visualPart = part
end

function BaseSystem.TryUpgradeBase(player)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local nextLevel = baseData.level + 1
    if nextLevel > CONFIG.MAX_SLOTS then
        BaseUpdateEvent:FireClient(player, {
            action = "error",
            message = "Base is at maximum level!"
        })
        return
    end
    
    local cost = BaseSystem.CalculateUpgradeCost(baseData.level)
    
    -- Check money (would integrate with UpgradeSystem/PlayerData)
    -- For now, just upgrade
    baseData.level = nextLevel
    BaseSystem.CreateSlots(player)
    
    BaseUpdateEvent:FireClient(player, {
        action = "upgrade",
        level = baseData.level,
        maxSlots = BaseSystem.GetMaxSlots(baseData.level)
    })
end

function BaseSystem.CalculateUpgradeCost(currentLevel)
    return math.floor(CONFIG.UPGRADE_COST_BASE * (CONFIG.UPGRADE_COST_MULTIPLIER ^ currentLevel))
end

function BaseSystem.IncomeLoop()
    while true do
        wait(CONFIG.INCOME_TICK_RATE)
        
        for player, baseData in pairs(playerBases) do
            if baseData.totalIncome > 0 then
                -- Give money to player
                -- Would integrate with currency system
                local earned = baseData.totalIncome * CONFIG.INCOME_TICK_RATE
                
                BaseUpdateEvent:FireClient(player, {
                    action = "income",
                    earned = earned,
                    totalIncome = baseData.totalIncome
                })
            end
        end
    end
end

return BaseSystem
