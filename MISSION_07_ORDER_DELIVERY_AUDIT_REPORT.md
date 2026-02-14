# Mission 7: Order & Delivery Systems Audit Report

## Executive Summary

This audit examines the order generation, fulfillment, and reward systems in FeedTheBrainrots. Multiple critical vulnerabilities were identified including race conditions, validation bypasses, and duplication exploits.

**Critical Issues Found: 7**
**High Severity: 4**
**Medium Severity: 3**

---

## 1. ORDER GENERATION SYSTEM

### 1.1 Order Creation Flow

Location: `Server/Game/Plot/init.luau` - `plot:ReachedDesk()`

```lua
-- When brainrot reaches desk, order is generated
function plot:ReachedDesk(BrainrotID, CurrentCFrame)
    -- ... arrival detection ...
    
    task.delay(ThinkTime, function()
        -- Order generation based on rarity
        local FinalizedOrderArray = {}
        
        if BrainrotLibraryData.CustomOrder then
            -- Custom orders for specific brainrots
            for item, bounds in BrainrotLibraryData.CustomOrder do
                finalList[item] = math.random(bounds[1], bounds[2])
            end
        else
            -- Standard rarity-based order generation
            local maxItems = {
                ["Rare"] = 1; ["Epic"] = 2; ["Legendary"] = 2;
                ["Mythic"] = 3; ["Godly"] = 4; ["Secret"] = 4;
            }
            -- ... fruit selection logic ...
        end
    end)
end
```

### 1.2 Issues Found

#### 🔴 CRITICAL: Missing Brainrot Existence Check During Order Generation

**Location**: Line ~2590 in `ReachedDesk()`

**Issue**: After `task.delay(ThinkTime)`, there's only one check for `self.Active[BrainrotID]`, but this is insufficient for race conditions.

```lua
-- VULNERABLE CODE:
task.delay(ThinkTime, function()
    if not self.Active[BrainrotID] then
        return
    end
    -- Order continues to be created...
    -- But between the check and order creation, brainrot could be removed!
```

**Exploit**: Player can decline/remove brainrot during the thinking phase, but order may still be created.

**Fix**: Add continuous validation throughout order creation:
```lua
local function validateBrainrotActive()
    return self.Active[BrainrotID] ~= nil
end

-- Check before each critical operation
if not validateBrainrotActive() then return end
-- Create order UI
if not validateBrainrotActive() then return end
-- Set order requirements
if not validateBrainrotActive() then return end
-- Start timer
```

---

#### 🔴 CRITICAL: Timer Reference Race Condition

**Location**: Order timer in `ReachedDesk()`

**Issue**: The timer connection stores a reference that can become stale:

```lua
-- VULNERABLE CODE:
local timerConnection
timerConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
    if not self.Active[BrainrotID] or not self.Orders[OrderIndex] then
        if timerConnection then
            timerConnection:Disconnect()
        end
        return
    end
    -- Race: What if self.Orders[OrderIndex] is nilled between this check and usage?
    local orderCache = self.Orders[OrderIndex]  -- Could error here
    orderCache.TimeRemaining -= deltaTime
```

**Exploit**: Rapid order manipulation could cause nil reference errors or double-completion.

**Fix**: Cache orderCache with nil check:
```lua
timerConnection = RunService.Heartbeat:Connect(function(deltaTime)
    local activeBrainrot = self.Active[BrainrotID]
    local orderCache = self.Orders[OrderIndex]
    
    if not activeBrainrot or not orderCache then
        timerConnection:Disconnect()
        return
    end
    
    -- Now safe to use orderCache
    orderCache.TimeRemaining -= deltaTime
```

---

## 2. ORDER FULFILLMENT SYSTEM

### 2.1 GiveFruit Handler

Location: `Server/Game/Plot/init.luau` - OrderRemote handler

```lua
newPlot.Connections[2] = OrderRemote.OnServerEvent:Connect(function(user, call, ...)
    if user ~= newPlot.Owner then return end
    
    if call == "GiveFruit" then
        local path, itemID = ...
        
        -- Validation added in recent fix:
        if type(path) ~= "number" and type(path) ~= "string" then return end
        local pathNum = tonumber(path)
        if not pathNum or pathNum < 1 or pathNum > 3 then return end
        
        -- Check item exists in inventory
        if not newPlot.OwnerData.Inventory[itemID] then return end
        
        -- Get current order
        local currentOrder = newPlot.CurrentOrder[pathNum]
        if not currentOrder or not currentOrder.BrainrotID then return end
        
        -- Execute give fruit
        if newPlot.Functions[brainrotID] then
            newPlot.Functions[brainrotID](user, itemID)
        end
    end
end)
```

### 2.2 Issues Found

#### 🔴 CRITICAL: Duplicate Fruit Delivery Exploit

**Location**: `plot.Functions[BrainrotID]` in `ReachedDesk()`

**Issue**: The GiveFruit function doesn't validate that the fruit is being given to the correct order:

```lua
-- VULNERABLE CODE:
self.Functions[BrainrotID] = function(plr, itemID)
    local tempPlot
    for _, p in plot.Plots do if p.Owner == plr then tempPlot = p end end
    if not tempPlot then return end

    local orderCache = self.Orders[OrderIndex]
    local holdingItemData = tempPlot.OwnerData.Inventory[itemID]
    
    -- MISSING: Verify the itemID is still in inventory!
    -- A second request could arrive before first one removes item
```

**Exploit Scenario**:
1. Player has 1 Apple
2. Two orders need Apples (Desk 1 and Desk 2)
3. Player rapidly fires GiveFruit for both orders with same itemID
4. Both orders may accept the same fruit before inventory is updated

**Fix**: Add atomic inventory check:
```lua
self.Functions[BrainrotID] = function(plr, itemID)
    -- ATOMIC CHECK: Verify item is STILL in inventory
    if not tempPlot.OwnerData.Inventory[itemID] then
        return  -- Item already used
    end
    
    -- Check if order still needs this fruit
    local itemName = holdingItemData.Name
    local currentAmount = orderCache.Currents[itemName] and #orderCache.Currents[itemName] or 0
    if currentAmount >= orderCache.Requirements[itemName] then
        return  -- Order already fulfilled for this fruit
    end
    
    -- ... rest of logic ...
    
    -- REMOVE FROM INVENTORY IMMEDIATELY (before any other operations)
    tempPlot.OwnerReplica:SetValue({"Inventory", itemID}, nil)
    tempPlot:DestroyToolByID(itemID)
```

---

#### 🟠 HIGH: Path Parameter Manipulation

**Location**: OrderRemote "GiveFruit" handler

**Issue**: Path is validated but the `currentOrder.BrainrotID` check is incomplete:

```lua
-- VULNERABLE CODE:
local currentOrder = newPlot.CurrentOrder[pathNum]
if not currentOrder or not currentOrder.BrainrotID then return end

local brainrotID = currentOrder.BrainrotID

-- MISSING: Verify brainrotID matches the order at this path!
if newPlot.Functions[brainrotID] then
    newPlot.Functions[brainrotID](user, itemID)
end
```

**Issue**: `newPlot.Functions[brainrotID]` is a dynamic function table. If somehow a stale brainrotID exists, it could call wrong handler.

**Fix**: Validate brainrot exists in Active table:
```lua
if not newPlot.Active[brainrotID] then
    warn("[GiveFruit] Brainrot not active:", brainrotID)
    return
end

-- Verify the active brainrot is at the expected path
if newPlot.Active[brainrotID].Path ~= pathNum then
    warn("[GiveFruit] Path mismatch for brainrot:", brainrotID)
    return
end
```

---

## 3. ORDER COMPLETION SYSTEM

### 3.1 CompleteOrder Function

Location: `Server/Game/Plot/init.luau` - `newPlot.Functions["CompleteOrder"]`

```lua
newPlot.Functions["CompleteOrder"] = function(number, passChecks)
    local getCurrentOrder = newPlot.CurrentOrder[number]
    
    -- CRITICAL FIX: Check nil BEFORE accessing .Cache (Issue #5)
    if not getCurrentOrder or getCurrentOrder.Claiming then
        return
    end
    
    local orderCache = getCurrentOrder.Cache
    getCurrentOrder.Claiming = true
    
    -- Inventory check
    local TotalInventorySize = 250
    -- ... check inventory space ...
    
    -- Update stats
    local currentOrders = PlayerReplica.Data.Stats.Orders
    PlayerReplica:SetValue({"Stats", "Orders"}, currentOrders + 1)
    Leaderboards.UpdatePlayerStat(newPlot.Owner.UserId, "Orders", currentOrders + 1)
    
    -- Give brainrot
    newPlot:GiveItem({
        ["ID"] = HttpService:GenerateGUID(false);
        ["Name"] = getCurrentOrder.Brainrot;
        ["Weight"] = getCurrentOrder.Weight;
        ["Mutations"] = getCurrentOrder.Mutations or {};
    })
    
    -- Destroy customer
    if newPlot.Active[getCurrentOrder.BrainrotID] then
        newPlot:DestroyBrainrot(getCurrentOrder.BrainrotID, number, getCurrentOrder.Index, passChecks)
    end
end
```

### 3.2 Issues Found

#### 🔴 CRITICAL: Double-Completion Exploit via Race Condition

**Issue**: The `Claiming` flag is set AFTER reading the order cache, but there's a race window:

```lua
-- RACE CONDITION WINDOW:
if not getCurrentOrder or getCurrentOrder.Claiming then  -- Check 1
    return
end

-- <-- ANOTHER REQUEST COULD ARRIVE HERE, PASS CHECK 1

local orderCache = getCurrentOrder.Cache  -- Both requests get same cache
getCurrentOrder.Claiming = true  -- Set too late!
```

**Exploit**: 
1. Player triggers CompleteOrder twice simultaneously (auto-complete purchase + manual click)
2. Both requests pass the `Claiming` check before either sets it
3. Both give rewards, resulting in double brainrot

**Fix**: Use atomic operation or earlier lock:
```lua
newPlot.Functions["CompleteOrder"] = function(number, passChecks)
    -- ATOMIC: Set claiming flag FIRST using table operation
    local order = newPlot.CurrentOrder[number]
    if not order then return end
    
    -- Use pcall for atomic test-and-set
    local success = pcall(function()
        if order.Claiming then
            error("Already claiming")
        end
        order.Claiming = true
    end)
    
    if not success then return end
    
    -- Now safe to proceed...
```

---

#### 🟠 HIGH: Inventory Check vs GiveItem Race Condition

**Issue**: Inventory is checked, but GiveItem could fail silently:

```lua
-- Current flow:
local GetInventoryCount = 0
for i, v in PlayerReplica.Data.Inventory do GetInventoryCount += 1 end

if GetInventoryCount >= TotalInventorySize then
    -- Show notification
    return
end

-- GAP: Between check and GiveItem, another item could be added!

newPlot:GiveItem({...})  -- Might exceed limit!
```

**Fix**: Make GiveItem return success/failure:
```lua
local success = newPlot:GiveItem({...})
if not success then
    getCurrentOrder.Claiming = false  -- Reset flag
    return
end
```

---

#### 🟠 HIGH: Stats Update Before Reward Confirmation

**Issue**: Stats are updated before confirming item was actually given:

```lua
-- Current order:
PlayerReplica:SetValue({"Stats", "Orders"}, currentOrders + 1)  -- Stat updated
Leaderboards.UpdatePlayerStat(...)  -- Leaderboard updated

-- If GiveItem fails, stats are wrong!
newPlot:GiveItem({...})  -- Could fail
```

**Fix**: Update stats only after successful reward:
```lua
local success = newPlot:GiveItem({...})
if success then
    -- NOW update stats
    PlayerReplica:SetValue({"Stats", "Orders"}, currentOrders + 1)
    Leaderboards.UpdatePlayerStat(...)
end
```

---

## 4. REWARD SYSTEM EXPLOITS

### 4.1 Brainrot Weight Manipulation

**Location**: Fruit-to-Brainrot weight transfer in GiveFruit

```lua
-- Weight gain calculation:
local function CalculateWeightGain(fruitWeight, mutation)
    local targetSmall = 0.25
    local bonusData = MutationBonuses[mutation or "Normal"]
    -- ... calculation ...
    return targetSmall + (scaleFactor * (targetLarge - targetSmall))
end

local weightGain = CalculateWeightGain(rawWeight, mutation)
self.Active[BrainrotID].Weight += weightGain
```

### 4.2 Issues Found

#### 🟡 MEDIUM: Weight Overflow Potential

**Issue**: No maximum weight cap:

```lua
self.Active[BrainrotID].Weight += weightGain  -- Can grow indefinitely!
```

**Exploit**: Player could theoretically feed a brainrot until weight becomes `inf` or causes numeric overflow.

**Fix**: Add weight cap:
```lua
local MAX_BRAINROT_WEIGHT = 10000  -- 10,000 kg cap
self.Active[BrainrotID].Weight = math.min(
    self.Active[BrainrotID].Weight + weightGain,
    MAX_BRAINROT_WEIGHT
)
```

---

#### 🟡 MEDIUM: Mutation Transfer Without Validation

**Location**: Mutation transfer in GiveFruit

```lua
if holdingItemData.Mutations then
    for index, Mutation in holdingItemData.Mutations do
        if table.find(brainrotstuff.Mutations, Mutation) then
            continue
        end

        local checkMutation = MutationsData[Mutation]
        if checkMutation.IsEffect then
            local effectCount = 0
            for _, existingMutation in brainrotstuff.Mutations do
                if MutationsData[existingMutation].IsEffect then
                    effectCount += 1
                end
            end

            if effectCount < 6 then
                table.insert(brainrotstuff.Mutations, Mutation)  -- No validation!
            end
        end
    end
end
```

**Issue**: `MutationsData[Mutation]` is accessed without nil check.

**Fix**:
```lua
local checkMutation = MutationsData[Mutation]
if not checkMutation then
    warn("[GiveFruit] Invalid mutation:", Mutation)
    continue
end
```

---

## 5. PURCHASE-BASED ORDER COMPLETION

### 5.1 Auto-Complete Purchase Handler

Location: `Server/Game/Purchases.luau`

```lua
for rarity, ID in Plot.AutoCompletes do -- AUTO FINISH ORDER FOR ___ RARITY --
    PurchaseHandler:RegisterProduct(ID, function(receipt, player, PlayerReplica, getPlot)
        local getOrder = getPlot.CurrentOrder[player:GetAttribute("CompletedPurchaseData")]
        
        if getOrder then
            local brainrotModel = game.ReplicatedStorage.Game.Models.Brainrot3D[getOrder.Brainrot]
            
            if Plot.AutoCompletes[brainrotModel:GetAttribute("Rarity")] == ID then
                getPlot.Functions["CompleteOrder"](player:GetAttribute("CompletedPurchaseData"), true)
            end
        end
        
        return true
    end)
end
```

### 5.2 Issues Found

#### 🔴 CRITICAL: Race Condition in Purchase Completion

**Issue**: The `CompletedPurchaseData` attribute is set when prompting purchase, but there's no validation that the order is still the same when purchase completes:

```lua
-- Player clicks accept button:
Player:SetAttribute("CompletedPurchaseData", number)  -- Sets desk number
MarketplaceService:PromptProductPurchase(newPlot.Owner, plot.AutoCompletes[BrainrotRarity])

-- Player waits 30 seconds, order expires, new customer sits
-- Purchase completes - completes WRONG order!
```

**Exploit**: Player can start purchase for high-value order, wait for it to expire, get cheap order, and auto-complete gets cheap order rewards.

**Fix**: Store order signature, not just desk number:
```lua
-- When prompting:
local orderSignature = {
    Desk = number,
    BrainrotID = getCurrentOrder.BrainrotID,
    Timestamp = os.time()
}
Player:SetAttribute("PendingOrderSignature", HttpService:JSONEncode(orderSignature))

-- When completing purchase:
local signature = HttpService:JSONDecode(player:GetAttribute("PendingOrderSignature") or "{}")
local currentOrder = getPlot.CurrentOrder[signature.Desk]

if not currentOrder or currentOrder.BrainrotID ~= signature.BrainrotID then
    -- Order changed, refund or reject
    return false
end
```

---

#### 🟠 HIGH: Missing Order Completion Validation

**Issue**: Auto-complete doesn't verify order requirements are actually met:

```lua
-- VULNERABLE CODE:
if Plot.AutoCompletes[brainrotModel:GetAttribute("Rarity")] == ID then
    getPlot.Functions["CompleteOrder"](player:GetAttribute("CompletedPurchaseData"), true)
    -- passChecks = true skips requirement validation!
end
```

The `passChecks = true` is intentional for auto-complete, but should require payment verification.

**Fix**: Already mitigated by purchase system, but add comment:
```lua
-- NOTE: passChecks=true is intentional - player paid to skip requirements
-- The purchase itself is the validation
```

---

## 6. ORDER PERSISTENCE ISSUES

### 6.1 SaveOrdersToData / RestoreOrdersFromData

Location: `FIX_1_OrderPersistence.luau`

### 6.2 Issues Found

#### 🟡 MEDIUM: Incomplete Order Persistence

**Issue**: The persistence system saves orders but not the full timer state:

```lua
ordersToSave[orderID] = {
    Requirements = orderData.Requirements,
    Currents = orderData.Currents,
    Mutations = orderData.Mutations,
    Weight = orderData.Weight,
    TimeRemaining = orderData.TimeRemaining,  -- This becomes stale!
    MaxTime = orderData.MaxTime,
    -- ...
}
```

**Issue**: `TimeRemaining` is saved, but when restored, the timer doesn't account for time offline.

**Exploit**: Player can save game with 1 second left, leave, rejoin with full time restored.

**Fix**: Save timestamp, not remaining time:
```lua
-- Save:
ordersToSave[orderID] = {
    -- ...
    ExpiresAt = workspace:GetServerTimeNow() + orderData.TimeRemaining,
    -- ...
}

-- Restore:
local timeRemaining = orderData.ExpiresAt - workspace:GetServerTimeNow()
if timeRemaining <= 0 then
    -- Order already expired, destroy it
    self:DestroyBrainrot(orderID, path, index, nil, true)
    return
end
```

---

## 7. SUMMARY OF EXPLOITS

| Exploit | Severity | Location | Description |
|---------|----------|----------|-------------|
| Double Completion | 🔴 CRITICAL | CompleteOrder | Race condition allows duplicate rewards |
| Duplicate Fruit | 🔴 CRITICAL | GiveFruit | Same fruit used for multiple orders |
| Order Persistence | 🔴 CRITICAL | RestoreOrders | Timer reset on rejoin |
| Purchase Race | 🔴 CRITICAL | Purchases.luau | Wrong order completed after swap |
| Brainrot Check Race | 🔴 CRITICAL | ReachedDesk | Order created for removed brainrot |
| Path Manipulation | 🟠 HIGH | GiveFruit handler | Wrong path could target wrong order |
| Stats Desync | 🟠 HIGH | CompleteOrder | Stats updated before reward confirmed |
| Weight Overflow | 🟡 MEDIUM | GiveFruit | No maximum weight limit |
| Mutation Nil Access | 🟡 MEDIUM | GiveFruit | Missing mutation validation |

---

## 8. RECOMMENDED FIXES

### 8.1 Immediate Priority (Critical)

1. **Add Atomic Claiming**: Use pcall test-and-set pattern in CompleteOrder
2. **Fix Fruit Duplication**: Remove from inventory BEFORE adding to order
3. **Validate Purchase Orders**: Store order signature, not just desk number
4. **Fix Timer Persistence**: Save expiry timestamp, not remaining time

### 8.2 High Priority

1. **Add Inventory Check Atomicity**: Make GiveItem return success/failure
2. **Validate Path Consistency**: Ensure brainrot path matches expected
3. **Stats After Reward**: Move stat updates after successful GiveItem

### 8.3 Medium Priority

1. **Add Weight Cap**: Maximum brainrot weight limit
2. **Validate Mutations**: Nil-check mutation data
3. **Add Order Validation**: Continuous checks during order creation

---

## 9. CODE REVIEW CHECKLIST

- [ ] All order operations are atomic
- [ ] No race conditions between check and operation
- [ ] Inventory modifications happen before reward grants
- [ ] Purchase completions validate order hasn't changed
- [ ] Timers use absolute timestamps, not relative time
- [ ] All dynamic table access has nil checks
- [ ] Stats only update after confirmed successful operation
- [ ] Weight/mutation transfers have validation

---

## 10. TESTING RECOMMENDATIONS

1. **Race Condition Testing**: Use multiple rapid requests to test all race conditions
2. **Timer Testing**: Test order behavior across server restarts and player leaves
3. **Purchase Testing**: Test auto-complete with order swaps mid-purchase
4. **Inventory Testing**: Test simultaneous fruit gives to multiple orders
5. **Boundary Testing**: Test maximum weight, inventory limits, timer boundaries

---

*Report generated: Mission 7 - Order & Delivery Systems Audit*
*Focus Areas: Order Generation, Fulfillment, Rewards, Validation Gaps*
