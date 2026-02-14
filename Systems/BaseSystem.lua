-- BaseSystem.lua
-- Tycoon bases - cloned from template on server init
-- Physical parts use Touched, UI elements use Click events

local BaseSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Configuration
local CONFIG = {
    NUM_BASES = 6,
    BASE_SPACING = 60,
    INCOME_TICK_RATE = 1,
    TOUCH_COOLDOWN = 0.5,
    
    SLOT_COST_BASE = 100,
    SLOT_COST_MULTIPLIER = 1.15,
    FLOOR_COST_BASE = 500,
    FLOOR_COST_MULTIPLIER = 1.5,
    
    INCOME_RATES = {
        Common = 1,
        Rare = 3,
        Legendary = 10,
        Mythic = 25,
        Secret = 100
    }
}

-- State
local bases = {}
local playerData = {}
local touchDebounce = {}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BaseUpdateEvent = Instance.new("RemoteEvent")
BaseUpdateEvent.Name = "BaseUpdateEvent"
BaseUpdateEvent.Parent = Remotes

-- Client -> Server remote for UI interactions
local UISlotClaimEvent = Instance.new("RemoteEvent")
UISlotClaimEvent.Name = "UISlotClaimEvent"
UISlotClaimEvent.Parent = Remotes

local UISlotUpgradeEvent = Instance.new("RemoteEvent")
UISlotUpgradeEvent.Name = "UISlotUpgradeEvent"
UISlotUpgradeEvent.Parent = Remotes

function BaseSystem.Init()
    BaseSystem.SetupBases()
    
    Players.PlayerAdded:Connect(BaseSystem.OnPlayerJoin)
    Players.PlayerRemoving:Connect(BaseSystem.OnPlayerLeave)
    
    -- Handle UI interactions from client
    UISlotClaimEvent.OnServerEvent:Connect(BaseSystem.OnUISlotClaim)
    UISlotUpgradeEvent.OnServerEvent:Connect(BaseSystem.OnUISlotUpgrade)
    
    task.spawn(BaseSystem.IncomeLoop)
    
    print("🏠 Base System initialized - " .. CONFIG.NUM_BASES .. " bases ready")
end

function BaseSystem.SetupBases()
    local template = workspace:FindFirstChild("Base 5")
    if not template then
        warn("⚠️ Base 5 template not found in workspace!")
        return
    end
    
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then
        basesFolder = Instance.new("Folder")
        basesFolder.Name = "Bases"
        basesFolder.Parent = workspace
    end
    
    for _, child in ipairs(basesFolder:GetChildren()) do
        child:Destroy()
    end
    
    local startX = -((CONFIG.NUM_BASES - 1) * CONFIG.BASE_SPACING) / 2
    
    for i = 1, CONFIG.NUM_BASES do
        local base = template:Clone()
        base.Name = "Base" .. i
        
        -- Start from far left, fill to the right
        local position = Vector3.new(startX + (i - 1) * CONFIG.BASE_SPACING, 0, 50)
        
        -- Move entire base
        -- Find a reference part to calculate offset (use Floor model's first BasePart)
        local defaultFolder = base:FindFirstChild("Default")
        local floorModel = defaultFolder and defaultFolder:FindFirstChild("Floor")
        local refPart = floorModel and floorModel:FindFirstChildWhichIsA("BasePart")
        
        if refPart then
            local offset = position - refPart.Position
            for _, part in ipairs(base:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Position = part.Position + offset
                end
            end
        end
        
        base.Parent = basesFolder
        
        bases[i] = {
            id = i,
            model = base,
            owner = nil,
            slots = {},
            floors = 1,
            claimedSlots = 0,
            earnings = 0,
            offlineEarnings = 0
        }
        
        BaseSystem.SetupBaseSlots(i)
        BaseSystem.SetupBaseInteractions(i)
    end
    
    -- Delete the template after cloning
    template:Destroy()
end

function BaseSystem.SetupBaseSlots(baseId)
    local base = bases[baseId]
    if not base then return end
    
    local slotsFolder = base.model:FindFirstChild("Slots")
    if not slotsFolder then return end
    
    for _, slotModel in ipairs(slotsFolder:GetChildren()) do
        local slotId = tonumber(slotModel.Name)
        if slotId then
            base.slots[slotId] = {
                id = slotId,
                model = slotModel,
                claimed = false,
                brainrot = nil,
                upgraded = false
            }
        end
    end
end

function BaseSystem.SetupBaseInteractions(baseId)
    local base = bases[baseId]
    if not base then return end
    
    -- Physical parts use Touched
    for slotId, slot in pairs(base.slots) do
        -- Button part (physical) - claim slot
        local button = slot.model:FindFirstChild("Button")
        if button then
            -- Try Bottom first (the green part), then Base
            local buttonPart = button:FindFirstChild("Bottom") or button:FindFirstChild("Base")
            if buttonPart and buttonPart:IsA("BasePart") then
                buttonPart.Touched:Connect(function(hit)
                    BaseSystem.HandleTouch(hit, baseId, function(player)
                        BaseSystem.OnSlotButtonTouched(player, baseId, slotId)
                    end)
                end)
            end
        end
        
        -- Claim part (physical) - collect earnings
        local claim = slot.model:FindFirstChild("Claim")
        if claim then
            local claimPart = claim:FindFirstChildWhichIsA("BasePart")
            if claimPart then
                claimPart.Touched:Connect(function(hit)
                    BaseSystem.HandleTouch(hit, baseId, function(player)
                        BaseSystem.OnClaimTouched(player, baseId, slotId)
                    end)
                end)
            end
        end
    end
    
    -- Floor purchase buttons (physical parts)
    BaseSystem.SetupFloorTouches(baseId)
    
    -- Offline earnings (physical part)
    BaseSystem.SetupOfflineEarningsTouch(baseId)
end

function BaseSystem.SetupFloorTouches(baseId)
    local base = bases[baseId]
    if not base then return end
    
    for _, child in ipairs(base.model:GetChildren()) do
        if child.Name:match("^PurchaseFloor%d+") then
            local floorNum = tonumber(child.Name:match("%d+"))
            if floorNum and child:IsA("BasePart") then
                child.Touched:Connect(function(hit)
                    BaseSystem.HandleTouch(hit, baseId, function(player)
                        BaseSystem.OnPurchaseFloor(player, baseId, floorNum)
                    end)
                end)
            end
        end
    end
end

function BaseSystem.SetupOfflineEarningsTouch(baseId)
    local base = bases[baseId]
    if not base then return end
    
    local offlinePart = base.model:FindFirstChild("Offline Earnings")
    if offlinePart and offlinePart:IsA("BasePart") then
        offlinePart.Touched:Connect(function(hit)
            BaseSystem.HandleTouch(hit, baseId, function(player)
                BaseSystem.OnClaimOfflineEarnings(player, baseId)
            end)
        end)
    end
end

function BaseSystem.HandleTouch(hit, baseId, callback)
    local character = hit.Parent
    if not character then return end
    
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    
    local base = bases[baseId]
    if not base then return end
    
    if base.owner ~= player then return end
    
    local key = player.UserId .. "_" .. baseId
    if touchDebounce[key] then return end
    
    touchDebounce[key] = true
    callback(player)
    task.wait(CONFIG.TOUCH_COOLDOWN)
    touchDebounce[key] = nil
end

function BaseSystem.OnPlayerJoin(player)
    for baseId, base in ipairs(bases) do
        if not base.owner then
            BaseSystem.AssignBaseToPlayer(player, baseId)
            return
        end
    end
    warn("No available bases for " .. player.Name)
end

function BaseSystem.OnPlayerLeave(player)
    local data = playerData[player]
    if data and data.baseId then
        local base = bases[data.baseId]
        if base then
            base.owner = nil
        end
    end
    playerData[player] = nil
end

function BaseSystem.AssignBaseToPlayer(player, baseId)
    local base = bases[baseId]
    if not base then return end
    
    base.owner = player
    
    playerData[player] = {
        baseId = baseId,
        earnings = base.earnings,
        offlineEarnings = base.offlineEarnings,
        inventory = {brainrots = {}, capacity = 3}
    }
    
    BaseUpdateEvent:FireClient(player, {
        action = "init",
        baseId = baseId,
        slots = base.slots,
        floors = base.floors
    })
    
    print(string.format("Assigned Base %d to %s", baseId, player.Name))
end

-- Physical part touched - claim slot
function BaseSystem.OnSlotButtonTouched(player, baseId, slotId)
    local base = bases[baseId]
    local slot = base.slots[slotId]
    if not slot then return end
    if slot.claimed then return end
    
    local cost = math.floor(CONFIG.SLOT_COST_BASE * (CONFIG.SLOT_COST_MULTIPLIER ^ base.claimedSlots))
    
    slot.claimed = true
    base.claimedSlots = base.claimedSlots + 1
    
    -- Visual feedback - turn button green
    local button = slot.model:FindFirstChild("Button")
    if button then
        local buttonPart = button:FindFirstChild("Bottom") or button:FindFirstChild("Base")
        if buttonPart and buttonPart:IsA("BasePart") then
            buttonPart.Color = Color3.fromRGB(0, 200, 0)
        end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "slotClaimed",
        slotId = slotId,
        cost = cost
    })
end

-- UI Button clicked - handled via remote
function BaseSystem.OnUISlotClaim(player, baseId, slotId)
    -- Same logic as touched, but called from client UI
    BaseSystem.OnSlotButtonTouched(player, baseId, slotId)
end

function BaseSystem.OnUISlotUpgrade(player, baseId, slotId)
    BaseSystem.OnUpgradeSlot(player, baseId, slotId)
end

function BaseSystem.OnClaimTouched(player, baseId, slotId)
    local base = bases[baseId]
    local slot = base.slots[slotId]
    if not slot or not slot.brainrot then return end
    
    local rarity = slot.brainrot.rarity
    local rate = CONFIG.INCOME_RATES[rarity] or 1
    if slot.upgraded then rate = rate * 2 end
    
    local earnings = rate * 60
    base.earnings = base.earnings + earnings
    
    -- Particle effect
    local claim = slot.model:FindFirstChild("Claim")
    if claim then
        local emitter = claim:FindFirstChildOfClass("ParticleEmitter")
        if emitter then emitter:Emit(20) end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "earningsClaimed",
        slotId = slotId,
        amount = earnings
    })
end

function BaseSystem.OnUpgradeSlot(player, baseId, slotId)
    local base = bases[baseId]
    local slot = base.slots[slotId]
    if not slot or not slot.brainrot then return end
    if slot.upgraded then return end
    
    local cost = CONFIG.SLOT_COST_BASE * 2
    slot.upgraded = true
    
    BaseUpdateEvent:FireClient(player, {
        action = "slotUpgraded",
        slotId = slotId
    })
end

function BaseSystem.OnPurchaseFloor(player, baseId, floorNum)
    local base = bases[baseId]
    if base.floors >= floorNum then return end
    if base.floors + 1 ~= floorNum then return end
    
    local cost = math.floor(CONFIG.FLOOR_COST_BASE * (CONFIG.FLOOR_COST_MULTIPLIER ^ (floorNum - 2)))
    base.floors = floorNum
    
    local floorsFolder = base.model:FindFirstChild("Floors")
    if floorsFolder then
        local floor = floorsFolder:FindFirstChild(tostring(floorNum))
        if floor then
            for _, part in ipairs(floor:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 0
                end
            end
        end
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "floorPurchased",
        floor = floorNum,
        cost = cost
    })
end

function BaseSystem.OnClaimOfflineEarnings(player, baseId)
    local base = bases[baseId]
    local amount = base.offlineEarnings
    if amount <= 0 then return end
    
    base.earnings = base.earnings + amount
    base.offlineEarnings = 0
    
    BaseUpdateEvent:FireClient(player, {
        action = "offlineEarningsClaimed",
        amount = amount
    })
end

function BaseSystem.IncomeLoop()
    while true do
        task.wait(CONFIG.INCOME_TICK_RATE)
        
        for _, base in ipairs(bases) do
            if base.owner then
                local totalIncome = 0
                
                for _, slot in pairs(base.slots) do
                    if slot.claimed and slot.brainrot then
                        local rarity = slot.brainrot.rarity
                        local rate = CONFIG.INCOME_RATES[rarity] or 1
                        if slot.upgraded then rate = rate * 2 end
                        totalIncome = totalIncome + rate
                    end
                end
                
                if totalIncome > 0 then
                    base.offlineEarnings = base.offlineEarnings + totalIncome
                    BaseSystem.UpdateEarningsLabels(base)
                end
            end
        end
    end
end

function BaseSystem.UpdateEarningsLabels(base)
    for _, slot in pairs(base.slots) do
        if slot.claimed and slot.brainrot then
            local claim = slot.model:FindFirstChild("Claim")
            if claim then
                local label = claim:FindFirstChild("EarningsLabel")
                if label then
                    local billboard = label:FindFirstChildOfClass("BillboardGui")
                    if billboard then
                        local textLabel = billboard:FindFirstChildOfClass("TextLabel")
                        if textLabel then
                            textLabel.Text = "$" .. math.floor(base.offlineEarnings)
                        end
                    end
                end
            end
        end
    end
end

-- API
function BaseSystem.PlaceBrainrotInSlot(player, slotId, brainrotData)
    local data = playerData[player]
    if not data then return false end
    
    local base = bases[data.baseId]
    if not base then return false end
    
    local slot = base.slots[slotId]
    if not slot or not slot.claimed then return false end
    if slot.brainrot then return false end
    
    slot.brainrot = brainrotData
    
    local primary = slot.model:FindFirstChild("Primary")
    if primary and brainrotData.modelTemplate then
        local cloned = brainrotData.modelTemplate:Clone()
        if cloned:FindFirstChild("HumanoidRootPart") then
            cloned:SetPrimaryPartCFrame(primary.CFrame)
        else
            cloned:PivotTo(primary.CFrame)
        end
        cloned.Parent = primary
        slot.visual = cloned
    end
    
    BaseUpdateEvent:FireClient(player, {
        action = "brainrotPlaced",
        slotId = slotId,
        brainrot = brainrotData
    })
    
    return true
end

function BaseSystem.GetPlayerBase(player)
    local data = playerData[player]
    if data then
        return bases[data.baseId]
    end
    return nil
end

return BaseSystem