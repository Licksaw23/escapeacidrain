-- BaseSystem.lua
-- Manages tycoon bases using the Workspace.Bases structure

local BaseSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Configuration
local CONFIG = {
    INCOME_TICK_RATE = 1,
    CLAIM_COOLDOWN = 0.5,
    
    -- Slot costs
    SLOT_COST_BASE = 100,
    SLOT_COST_MULTIPLIER = 1.15,
    
    -- Floor costs  
    FLOOR_COST_BASE = 500,
    FLOOR_COST_MULTIPLIER = 1.5,
    
    -- Brainrot income per second by rarity
    INCOME_RATES = {
        Common = 1,
        Rare = 3,
        Legendary = 10,
        Mythic = 25,
        Secret = 100
    }
}

-- Player data
local playerBases = {} -- [player] = {baseModel, slots = {}, floors = {}, earnings = 0}
local availableBases = {} -- List of unclaimed base models

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BaseUpdateEvent = Instance.new("RemoteEvent")
BaseUpdateEvent.Name = "BaseUpdateEvent"
BaseUpdateEvent.Parent = Remotes

function BaseSystem.Init()
    -- Find available bases
    BaseSystem.ScanAvailableBases()
    
    -- Setup player joining
    Players.PlayerAdded:Connect(BaseSystem.OnPlayerJoin)
    Players.PlayerRemoving:Connect(BaseSystem.OnPlayerLeave)
    
    -- Start income loop
    task.spawn(BaseSystem.IncomeLoop)
    
    print("🏠 Base System initialized - Found " .. #availableBases .. " available bases")
end

function BaseSystem.ScanAvailableBases()
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then return end
    
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") or base:IsA("Folder") then
            table.insert(availableBases, base)
        end
    end
end

function BaseSystem.OnPlayerJoin(player)
    -- Assign next available base
    if #availableBases == 0 then
        warn("No available bases for " .. player.Name)
        return
    end
    
    local baseModel = table.remove(availableBases, 1)
    
    playerBases[player] = {
        model = baseModel,
        owner = player,
        slots = {},
        floors = {},
        earnings = 0,
        offlineEarnings = 0,
        claimedSlots = 0,
        claimedFloors = 1
    }
    
    -- Setup the base structure
    BaseSystem.SetupBaseSlots(player, baseModel)
    BaseSystem.SetupBaseInteractions(player, baseModel)
    
    print(string.format("Assigned %s to %s", baseModel.Name, player.Name))
end

function BaseSystem.OnPlayerLeave(player)
    local baseData = playerBases[player]
    if baseData then
        -- Return base to available pool
        table.insert(availableBases, baseData.model)
        playerBases[player] = nil
    end
end

function BaseSystem.SetupBaseSlots(player, baseModel)
    local baseData = playerBases[player]
    if not baseData then return end
    
    -- Find Slots folder
    local slotsFolder = baseModel:FindFirstChild("Slots")
    if not slotsFolder then return end
    
    -- Setup each slot
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if slot:IsA("Model") or slot:IsA("Folder") then
            local slotId = tonumber(slot.Name)
            if slotId then
                baseData.slots[slotId] = {
                    id = slotId,
                    model = slot,
                    claimed = false,
                    brainrot = nil,
                    upgraded = false
                }
                
                -- Setup slot interactions
                BaseSystem.SetupSlotInteractions(player, slot, slotId)
            end
        end
    end
end

function BaseSystem.SetupSlotInteractions(player, slotModel, slotId)
    -- Find Button for claiming slot
    local button = slotModel:FindFirstChild("Button")
    if button then
        local basePart = button:FindFirstChild("Base") or button:FindFirstChildWhichIsA("BasePart")
        if basePart then
            local clickDetector = Instance.new("ClickDetector")
            clickDetector.MaxActivationDistance = 15
            clickDetector.MouseClick:Connect(function(clickingPlayer)
                if clickingPlayer == player then
                    BaseSystem.OnSlotButtonClick(player, slotId)
                end
            end})
            clickDetector.Parent = basePart
        end
    end
    
    -- Find Claim for collecting earnings
    local claim = slotModel:FindFirstChild("Claim")
    if claim then
        local claimPart = claim:FindFirstChildWhichIsA("BasePart")
        if claimPart then
            local clickDetector = Instance.new("ClickDetector")
            clickDetector.MaxActivationDistance = 15
            clickDetector.MouseClick:Connect(function(clickingPlayer)
                if clickingPlayer == player then
                    BaseSystem.OnClaimEarnings(player, slotId)
                end
            end})
            clickDetector.Parent = claimPart
        end
    end
    
    -- Find Upgrade button
    local upgrade = slotModel:FindFirstChild("Upgrade")
    if upgrade then
        local upgradeUi = upgrade:FindFirstChild("UpgradeUi")
        if upgradeUi then
            local upgradeButton = upgradeUi:FindFirstChild("UpgradeButton")
            if upgradeButton then
                -- Make the button clickable
                local clickPart = upgradeButton:FindFirstChild("1") or upgradeButton:FindFirstChildWhichIsA("BasePart")
                if clickPart then
                    local clickDetector = Instance.new("ClickDetector")
                    clickDetector.MaxActivationDistance = 10
                    clickDetector.MouseClick:Connect(function(clickingPlayer)
                        if clickingPlayer == player then
                            BaseSystem.OnUpgradeSlot(player, slotId)
                        end
                    end})
                    clickDetector.Parent = clickPart
                end
            end
        end
    end
end

function BaseSystem.SetupBaseInteractions(player, baseModel)
    -- Setup floor purchase buttons
    local floorsFolder = baseModel:FindFirstChild("Floors")
    if floorsFolder then
        for _, floor in ipairs(floorsFolder:GetChildren()) do
            local floorNum = tonumber(floor.Name)
            if floorNum and floorNum > 1 then -- Floor 1 is default
                local clickDetector = Instance.new("ClickDetector")
                clickDetector.MaxActivationDistance = 15
                clickDetector.MouseClick:Connect(function(clickingPlayer)
                    if clickingPlayer == player then
                        BaseSystem.OnPurchaseFloor(player, floorNum)
                    end
                end})
                clickDetector.Parent = floor
            end
        end
    end
    
    -- Setup offline earnings claim
    local offlineEarnings = baseModel:FindFirstChild("Offline Earnings")
    if offlineEarnings and offlineEarnings:IsA("BasePart") then
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 15
        clickDetector.MouseClick:Connect(function(clickingPlayer)
            if clickingPlayer == player then
                BaseSystem.OnClaimOfflineEarnings(player)
            end
        end})
        clickDetector.Parent = offlineEarnings
    end
end

function BaseSystem.OnSlotButtonClick(player, slotId)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local slot = baseData.slots[slotId]
    if not slot then return end
    
    if slot.claimed then
        -- Already claimed - show message
        return
    end
    
    -- Calculate cost
    local cost = math.floor(CONFIG.SLOT_COST_BASE * (CONFIG.SLOT_COST_MULTIPLIER ^ (baseData.claimedSlots)))
    
    -- TODO: Check player money
    -- For now, auto-claim
    
    slot.claimed = true
    baseData.claimedSlots = baseData.claimedSlots + 1
    
    -- Visual feedback - change button color
    local button = slot.model:FindFirstChild("Button")
    if button then
        local basePart = button:FindFirstChild("Base")
        if basePart and basePart:IsA("BasePart") then
            basePart.Color = Color3.fromRGB(0, 200, 0) -- Green for claimed
        end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "slotClaimed",
        slotId = slotId,
        cost = cost
    })
    
    print(string.format("%s claimed slot %d for %d", player.Name, slotId, cost))
end

function BaseSystem.PlaceBrainrotInSlot(player, slotId, brainrotData)
    local baseData = playerBases[player]
    if not baseData then return false end
    
    local slot = baseData.slots[slotId]
    if not slot or not slot.claimed then return false end
    if slot.brainrot then return false end -- Already has brainrot
    
    -- Place brainrot
    slot.brainrot = brainrotData
    
    -- Create visual in Primary
    local primary = slot.model:FindFirstChild("Primary")
    if primary then
        local modelTemplate = brainrotData.modelTemplate
        if modelTemplate then
            local cloned = modelTemplate:Clone()
            cloned:SetPrimaryPartCFrame(primary.CFrame)
            cloned.Parent = primary
            slot.visual = cloned
        end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "brainrotPlaced",
        slotId = slotId,
        brainrot = brainrotData
    })
    
    return true
end

function BaseSystem.OnClaimEarnings(player, slotId)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local slot = baseData.slots[slotId]
    if not slot or not slot.brainrot then return end
    
    -- Calculate earnings for this slot
    local rarity = slot.brainrot.rarity
    local incomeRate = CONFIG.INCOME_RATES[rarity] or 1
    local slotEarnings = incomeRate * CONFIG.INCOME_TICK_RATE * 60 -- Last minute of earnings
    
    -- Add to player
    baseData.earnings = baseData.earnings + slotEarnings
    
    -- Particle effect
    local claim = slot.model:FindFirstChild("Claim")
    if claim then
        local particleEmitter = claim:FindFirstChildOfClass("ParticleEmitter")
        if particleEmitter then
            particleEmitter:Emit(20)
        end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "earningsClaimed",
        slotId = slotId,
        amount = slotEarnings,
        total = baseData.earnings
    })
end

function BaseSystem.OnUpgradeSlot(player, slotId)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local slot = baseData.slots[slotId]
    if not slot or not slot.brainrot then return end
    if slot.upgraded then return end
    
    -- Calculate upgrade cost (2x base slot cost)
    local upgradeCost = math.floor(CONFIG.SLOT_COST_BASE * 2)
    
    -- TODO: Check player money
    
    slot.upgraded = true
    
    -- Boost income
    local rarity = slot.brainrot.rarity
    CONFIG.INCOME_RATES[rarity] = (CONFIG.INCOME_RATES[rarity] or 1) * 2
    
    BaseUpdateEvent:FireClient(player, {
        action = "slotUpgraded",
        slotId = slotId
    })
    
    print(string.format("%s upgraded slot %d", player.Name, slotId))
end

function BaseSystem.OnPurchaseFloor(player, floorNum)
    local baseData = playerBases[player]
    if not baseData then return end
    
    if baseData.claimedFloors >= floorNum then
        return -- Already have this floor
    end
    
    if baseData.claimedFloors + 1 ~= floorNum then
        return -- Must buy in order
    end
    
    local cost = math.floor(CONFIG.FLOOR_COST_BASE * (CONFIG.FLOOR_COST_MULTIPLIER ^ (floorNum - 2)))
    
    -- TODO: Check player money
    
    baseData.claimedFloors = floorNum
    
    -- Make floor visible
    local floorsFolder = baseData.model:FindFirstChild("Floors")
    if floorsFolder then
        local floor = floorsFolder:FindFirstChild(tostring(floorNum))
        if floor then
            floor.Transparency = 0
        end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "floorPurchased",
        floor = floorNum,
        cost = cost
    })
    
    print(string.format("%s purchased floor %d for %d", player.Name, floorNum, cost))
end

function BaseSystem.OnClaimOfflineEarnings(player)
    local baseData = playerBases[player]
    if not baseData then return end
    
    local amount = baseData.offlineEarnings
    if amount <= 0 then return end
    
    baseData.earnings = baseData.earnings + amount
    baseData.offlineEarnings = 0
    
    BaseUpdateEvent:FireClient(player, {
        action = "offlineEarningsClaimed",
        amount = amount,
        total = baseData.earnings
    })
end

function BaseSystem.IncomeLoop()
    while true do
        task.wait(CONFIG.INCOME_TICK_RATE)
        
        for player, baseData in pairs(playerBases) do
            local totalIncome = 0
            
            -- Calculate income from all slots
            for _, slot in pairs(baseData.slots) do
                if slot.claimed and slot.brainrot then
                    local rarity = slot.brainrot.rarity
                    local rate = CONFIG.INCOME_RATES[rarity] or 1
                    if slot.upgraded then
                        rate = rate * 2
                    end
                    totalIncome = totalIncome + rate
                end
            end
            
            -- Add to offline earnings (accumulates over time)
            if totalIncome > 0 then
                baseData.offlineEarnings = baseData.offlineEarnings + totalIncome
                
                -- Update earnings label
                BaseSystem.UpdateEarningsLabel(baseData)
            end
        end
    end
end

function BaseSystem.UpdateEarningsLabel(baseData)
    -- Update all slot earnings labels
    for _, slot in pairs(baseData.slots) do
        if slot.claimed and slot.brainrot then
            local claim = slot.model:FindFirstChild("Claim")
            if claim then
                local earningsLabel = claim:FindFirstChild("EarningsLabel")
                if earningsLabel then
                    local billboard = earningsLabel:FindFirstChildOfClass("BillboardGui")
                    if billboard then
                        local amountLabel = billboard:FindFirstChild("Amount")
                        if amountLabel and amountLabel:IsA("TextLabel") then
                            amountLabel.Text = "$" .. math.floor(baseData.offlineEarnings)
                        end
                    end
                end
            end
        end
    end
end

-- API for other systems
function BaseSystem.GetPlayerBase(player)
    return playerBases[player]
end

function BaseSystem.GetPlayerEarnings(player)
    local baseData = playerBases[player]
    return baseData and baseData.earnings or 0
end

function BaseSystem.AddPlayerEarnings(player, amount)
    local baseData = playerBases[player]
    if baseData then
        baseData.earnings = baseData.earnings + amount
    end
end

return BaseSystem