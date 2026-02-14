-- UpgradeSystem.lua
-- Handles speed and carry capacity upgrades with exponential costs

local UpgradeSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Configuration
local CONFIG = {
    SPEED = {
        baseCost = 100,
        multiplier = 1.17,
        baseSpeed = 16,
        speedPerLevel = 2,
        maxLevel = 150
    },
    CAPACITY = {
        baseCost = 500,
        multiplier = 1.5,
        baseCapacity = 3,
        capacityPerLevel = 1,
        maxLevel = 5 -- Max 7 brainrots (3 + 5 levels)
    }
}

-- Player data
local playerUpgrades = {} -- [player] = {speedLevel = 0, capacityLevel = 0}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeRequestEvent = Instance.new("RemoteEvent")
UpgradeRequestEvent.Name = "UpgradeRequestEvent"
UpgradeRequestEvent.Parent = Remotes

local UpgradeResponseEvent = Instance.new("RemoteEvent")
UpgradeResponseEvent.Name = "UpgradeResponseEvent"
UpgradeResponseEvent.Parent = Remotes

function UpgradeSystem.Init()
    -- Setup remote handlers
    UpgradeRequestEvent.OnServerEvent:Connect(UpgradeSystem.OnUpgradeRequest)
    
    -- Apply upgrades on character spawn
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            UpgradeSystem.ApplyPlayerUpgrades(player)
        end)
    end)
    
    print("⬆️ Upgrade System initialized")
end

function UpgradeSystem.OnUpgradeRequest(player, upgradeType, amount)
    amount = amount or 1
    
    -- Validate
    if upgradeType ~= "speed" and upgradeType ~= "capacity" then
        return
    end
    
    if amount ~= 1 and amount ~= 5 and amount ~= 10 then
        return
    end
    
    -- Get current data
    if not playerUpgrades[player] then
        playerUpgrades[player] = {speedLevel = 0, capacityLevel = 0, money = 0}
    end
    
    local data = playerUpgrades[player]
    local currentLevel = data[upgradeType .. "Level"] or 0
    
    -- Calculate total cost
    local totalCost = UpgradeSystem.CalculateTotalCost(upgradeType, currentLevel, amount)
    
    -- Check if player has enough money
    if data.money < totalCost then
        UpgradeResponseEvent:FireClient(player, {
            success = false,
            message = "Not enough money!",
            required = totalCost,
            have = data.money
        })
        return
    end
    
    -- Check max level
    local maxLevel = CONFIG[upgradeType:upper()].maxLevel
    if currentLevel + amount > maxLevel then
        UpgradeResponseEvent:FireClient(player, {
            success = false,
            message = "Max level reached!"
        })
        return
    end
    
    -- Deduct money and apply upgrade
    data.money = data.money - totalCost
    data[upgradeType .. "Level"] = currentLevel + amount
    
    -- Apply immediately
    UpgradeSystem.ApplyPlayerUpgrades(player)
    
    -- Send success
    UpgradeResponseEvent:FireClient(player, {
        success = true,
        type = upgradeType,
        newLevel = data[upgradeType .. "Level"],
        spent = totalCost,
        remaining = data.money
    })
    
    -- Track analytics
    -- AnalyticsService.TrackPurchase(player.UserId, totalCost, upgradeType .. "_upgrade", amount)
end

function UpgradeSystem.CalculateTotalCost(upgradeType, currentLevel, amount)
    local config = CONFIG[upgradeType:upper()]
    local total = 0
    
    for i = 1, amount do
        local level = currentLevel + i
        local cost = config.baseCost * (config.multiplier ^ level)
        total = total + cost
    end
    
    return math.floor(total)
end

function UpgradeSystem.CalculateCostForNextLevel(upgradeType, currentLevel)
    return UpgradeSystem.CalculateTotalCost(upgradeType, currentLevel, 1)
end

function UpgradeSystem.ApplyPlayerUpgrades(player)
    if not playerUpgrades[player] then return end
    
    local data = playerUpgrades[player]
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Apply speed
    local speedLevel = data.speedLevel or 0
    local speedConfig = CONFIG.SPEED
    local newSpeed = speedConfig.baseSpeed + (speedLevel * speedConfig.speedPerLevel)
    humanoid.WalkSpeed = newSpeed
    
    -- Update client with new stats
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StatsUpdateEvent = ReplicatedStorage.Remotes:FindFirstChild("StatsUpdateEvent")
    if StatsUpdateEvent then
        StatsUpdateEvent:FireClient(player, {
            walkSpeed = newSpeed,
            capacity = UpgradeSystem.GetPlayerCapacity(player),
            speedLevel = speedLevel,
            capacityLevel = data.capacityLevel or 0
        })
    end
end

function UpgradeSystem.GetPlayerSpeed(player)
    if not playerUpgrades[player] then
        return CONFIG.SPEED.baseSpeed
    end
    local level = playerUpgrades[player].speedLevel or 0
    return CONFIG.SPEED.baseSpeed + (level * CONFIG.SPEED.speedPerLevel)
end

function UpgradeSystem.GetPlayerCapacity(player)
    if not playerUpgrades[player] then
        return CONFIG.CAPACITY.baseCapacity
    end
    local level = playerUpgrades[player].capacityLevel or 0
    return CONFIG.CAPACITY.baseCapacity + (level * CONFIG.CAPACITY.capacityPerLevel)
end

function UpgradeSystem.GetPlayerUpgrades(player)
    if not playerUpgrades[player] then
        playerUpgrades[player] = {speedLevel = 0, capacityLevel = 0, money = 0}
    end
    return playerUpgrades[player]
end

function UpgradeSystem.AddMoney(player, amount)
    if not playerUpgrades[player] then
        playerUpgrades[player] = {speedLevel = 0, capacityLevel = 0, money = 0}
    end
    playerUpgrades[player].money = playerUpgrades[player].money + amount
end

function UpgradeSystem.GetUpgradeInfo(upgradeType)
    return CONFIG[upgradeType:upper()]
end

return UpgradeSystem
