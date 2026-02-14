# FeedTheBrainrots - Data & Purchase Systems Audit Report

**Auditor:** Subagent Mission #7  
**Date:** February 3, 2026  
**Scope:** Server/Data/, Server/Game/Purchases.luau, and all related data/purchase files

---

## Executive Summary

This audit identified **27 bugs** across the Data and Purchase systems, categorized as:
- **Critical (5):** Data loss, purchase exploits, race conditions
- **High (8):** Validation failures, memory leaks, security issues
- **Medium (9):** Data consistency issues, error handling gaps
- **Low (5):** Code quality, performance optimizations

---

## CRITICAL BUGS

### 1. Duplicate Purchase Vulnerability in Purchases.luau
**File:** `Server/Game/Purchases.luau`  
**Line:** 137-164 (processReceipt function)

**Issue:** The receipt processing does not use atomic operations when incrementing purchase counts. Multiple rapid purchase requests for the same product can result in duplicate granting before the first completion is recorded.

```lua
-- VULNERABLE CODE:
if not PlayerReplica.Data.Purchases[receipt.ProductId] then
    PlayerReplica:SetValue({"Purchases", receipt.ProductId}, 0)
end
PlayerReplica:SetValue({"Purchases", receipt.ProductId}, PlayerReplica.Data.Purchases[receipt.ProductId] + 1)
-- Race condition: Another purchase can sneak in between read and write
```

**Exploit:** Players can rapidly purchase the same developer product multiple times and receive duplicate rewards.

**Fix:** Use atomic increment operation or implement a purchase lock per player:
```lua
-- SUGGESTED FIX:
local PurchaseLocks = {}

local function processReceipt(receipt)
    -- Acquire lock
    if PurchaseLocks[receipt.PlayerId] then
        return PurchaseResult.NotProcessedYet -- Retry later
    end
    PurchaseLocks[receipt.PlayerId] = true
    
    -- Process purchase...
    
    -- Release lock
    PurchaseLocks[receipt.PlayerId] = nil
    return result
end
```

---

### 2. Data Loss on Server Shutdown - Orders Not Persisted
**File:** `Server/Game/Plot/init.luau`  
**Lines:** 1000-1100 (order system), 3100-3120 (Terminate function)

**Issue:** Active orders (self.Orders and self.CurrentOrder) are stored only in memory and lost when:
- Player leaves
- Server shuts down
- Player rebirths

**Impact:** Players lose in-progress orders, causing frustration and potential item loss.

**Fix:** Implement order persistence (see FIX_1_OrderPersistence.luau):
1. Add `ActiveOrders` to StarterData.luau
2. Call `SaveOrdersToData()` in Terminate() and before rebirth
3. Call `RestoreOrdersFromData()` in plot.new()

---

### 3. Race Condition in GlobalStore Purchase Lock
**File:** `Server/Game/GlobalStore.luau`  
**Line:** 383-418

**Issue:** The PurchaseLock mechanism has a race condition window between checking if locked and setting the lock:

```lua
-- VULNERABLE CODE:
if self.PurchaseLock[itemName] then
    task.wait(0.1)
    self:handlePurchase(plr, itemName)
    return
end
self.PurchaseLock[itemName] = true  -- Race window here!
```

**Exploit:** Two simultaneous requests for the same item can both pass the check before either sets the lock.

**Fix:** Use a single atomic operation:
```lua
-- SUGGESTED FIX:
if self.PurchaseLock[itemName] == plr.UserId then
    return -- Already processing for this player
end
if self.PurchaseLock[itemName] then
    task.wait(0.1)
    return self:handlePurchase(plr, itemName)
end
self.PurchaseLock[itemName] = plr.UserId
```

---

### 4. Unvalidated Client Input in OrderRemote
**File:** `Server/Game/Plot/init.luau`  
**Line:** 217-285 (OrderRemote handler)

**Issue:** While some validation was added (Issue #2 fix), the `itemID` parameter is still not validated to exist in the player's inventory before being used:

```lua
-- PARTIAL FIX APPLIED - but still vulnerable:
if not newPlot.OwnerData.Inventory[itemID] then
    warn("[OrderRemote] Item not in inventory: " .. itemID)
    return
end
-- This check happens AFTER accessing CurrentOrder which could be nil
```

**Exploit:** Malicious clients can send crafted packets to manipulate orders.

**Fix:** Complete validation refactoring with early returns and type checking.

---

### 5. Memory Leak in PlayerDelays
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2880-2920 (GiveTotalLuck and similar functions)

**Issue:** `plot.PlayerDelays` stores task.delay references but never cleans up completed delays:

```lua
plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
    self.Owner:SetAttribute("Luck", self.Owner:GetAttribute("Luck") - amount)
end)
-- No cleanup of the table entry after task completes!
```

**Impact:** Unbounded memory growth per player session, especially with frequent boost activations.

**Fix:** Clean up after delay completes:
```lua
local delayId = HttpService:GenerateGUID(false)
plot.PlayerDelays[self.Owner][delayId] = task.delay(Time, function()
    self.Owner:SetAttribute("Luck", self.Owner:GetAttribute("Luck") - amount)
    if plot.PlayerDelays[self.Owner] then
        plot.PlayerDelays[self.Owner][delayId] = nil
    end
end)
```

---

## HIGH SEVERITY BUGS

### 6. Missing Receipt Validation for Starter Pack
**File:** `Server/Game/Purchases.luau`  
**Line:** 489-520 (Starter Pack handler)

**Issue:** The starter pack purchase validation only checks `tick() > PlayerReplica.Data.FirstJoin + 36400` (note: 36400 is wrong - should be 86400 for 24 hours). Additionally, it returns `true` even when validation fails:

```lua
if tick() > PlayerReplica.Data.FirstJoin + 36400 then 
    warn("Passed day limit- Not doing.") 
    return true  -- BUG: Returns success even when failing!
end
```

**Impact:** Players can be charged but receive nothing, OR the limit check is wrong (10 hours instead of 24).

**Fix:** 
1. Change to `86400` (24 hours)
2. Return `false` when validation fails
3. Log failed attempts for audit

---

### 7. ProcessReceipt Not Handling All Error Cases
**File:** `Server/Game/Purchases.luau`  
**Line:** 78-164

**Issue:** The `processReceipt` function returns `NotProcessedYet` for ALL errors, which can cause infinite retry loops for permanent failures:

```lua
if not Data[player] then
    warn("[PurchaseHandler] Data timeout...")
    return false  -- BUG: Returns false instead of PurchaseResult enum
end
```

**Impact:** Roblox will keep retrying failed purchases indefinitely in some cases.

**Fix:** Distinguish between temporary and permanent failures:
```lua
-- For permanent failures (invalid product, player banned, etc.)
return PurchaseResult.PurchaseDenied  -- or just return true to stop retries

-- For temporary failures (data loading, player not found)
return PurchaseResult.NotProcessedYet
```

---

### 8. Unvalidated Gear Removal Request
**File:** `Server/Game/Plot/SprinklerSystem.luau`  
**Line:** 380-410 (HandleRemoveRequest)

**Issue:** The gear removal request doesn't validate that the player actually owns the plot where the gear is placed:

```lua
function SprinklerSystem:HandleRemoveRequest(player, gearID)
    -- Only checks if player has a plot, not if gear is on THEIR plot
    local playerPlot = nil
    for _, p in ipairs(Plot.Plots) do
        if p.Owner == player then
            playerPlot = p
            break
        end
    end
    -- Missing: Verify gearID is actually on playerPlot!
```

**Exploit:** Players might be able to remove gears from other players' plots.

**Fix:** Verify gear ownership before removal.

---

### 9. Leaderboard DataStore Key Collision
**File:** `Server/Game/Leaderboards.luau`  
**Line:** 22-35

**Issue:** The leaderboard uses a simple key format `category .. "_" .. userId` which could theoretically collide with other systems. More importantly, it doesn't handle DataStore throttling:

```lua
local success, errorMsg = pcall(function()
    LeaderboardStore:SetAsync(key, amount)
end)
-- No retry logic for throttling!
```

**Impact:** Lost leaderboard updates during high traffic.

**Fix:** Implement exponential backoff retry for DataStore operations.

---

### 10. Duplicate Mutation Application
**File:** `Server/Game/Plot/init.luau`  
**Line:** 1800-1850 (GiveToolForItem mutations)

**Issue:** Mutations can be applied multiple times if the function is called repeatedly:

```lua
for _, mutation in Info.Mutations do
    ServerUtility.ClientMutate(mutation, getTool:FindFirstChildOfClass("Model"))
end
-- No check if mutation already applied!
```

**Impact:** Visual glitches and potentially inflated stats from duplicate mutations.

**Fix:** Implement deduplication (see FIX_4_MutationDeduplication.luau).

---

### 11. Unbounded ActiveFruit Growth
**File:** `Server/Game/ServerUtility.luau`  
**Line:** 130-180 (SetupFruit)

**Issue:** The `Utility.ActiveFruit` table grows unbounded as plants are placed and harvested:

```lua
Utility.ActiveFruit[fruitKey] = function(user, call, info)
    -- Handler function
end
-- Only cleaned up when plant is removed, but what about abandoned fruits?
```

**Impact:** Memory leak over long server sessions with many plant interactions.

**Fix:** Implement periodic cleanup of stale fruit handlers.

---

### 12. MessagingService Subscription Failure Not Handled
**File:** `Server/Game/GlobalStore.luau`  
**Line:** 240-250

**Issue:** If MessagingService subscription fails, the store continues running without cross-server sync:

```lua
local success, connection = pcall(function()
    return MessagingService:SubscribeAsync(self.Type .. "StoreUpdate", function(message)
        self:updateStore()
    end)
end)

if not success then
    warn("[" .. self.Type .. " Store] Failed to setup MessagingService:", connection)
    -- No fallback or retry mechanism!
end
```

**Impact:** Inconsistent store state across servers.

**Fix:** Implement retry logic or alert mechanism for MessagingService failures.

---

## MEDIUM SEVERITY BUGS

### 13. Fruit Harvest Race Condition
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2000-2050 (RequestFruitHarvest)

**Issue:** No lock prevents simultaneous harvest attempts on the same fruit:

```lua
-- Check if on cooldown
if fruitData.HarvestedAt then
    local isOnCooldown = ServerUtility.IsFruitOnCooldown(fruitData)
    if isOnCooldown then
        return false, "Fruit on cooldown"
    end
end
-- Race window: Another request can sneak in here!
```

**Fix:** Add harvest lock per fruit.

---

### 14. Data Loading Timeout Too Short
**File:** `Server/Game/Purchases.luau`  
**Line:** 118-138

**Issue:** The 10-second timeout for data loading may be insufficient during server lag:

```lua
repeat 
    task.wait(0.1)
    timeout += 0.1
    -- Check if player is still in game
    if not player.Parent then
        warn("[PurchaseHandler] Player left during data loading")
        return false
    end
until Data[player] or timeout > 10
```

**Fix:** Increase to 30 seconds and add exponential backoff.

---

### 15. Unvalidated Brainrot Placement Position
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2700-2750 (PlaceBrainrot)

**Issue:** The platform/position for brainrot placement is not validated - it trusts the client-provided Slot parameter:

```lua
function plot:PlaceBrainrot(BrainrotID, Slot, tool)
    local brainrotCache = self.OwnerData.Inventory[BrainrotID]
    local platform = Slot
    -- No validation that Slot is a valid, unoccupied platform!
```

**Fix:** Validate platform exists and is unoccupied.

---

### 16. Gear Data Missing Validation
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2150-2200 (PlaceGear)

**Issue:** Gear placement doesn't validate the gear is still in inventory after position validation:

```lua
-- Position is validated first
local GetItemCache = self.OwnerData.Inventory[ItemID]
-- But what if ItemID was just consumed by another request?
```

**Fix:** Validate inventory again before consuming, or use atomic operations.

---

### 17. Order Timer Disconnect on Cleanup
**File:** `Server/Game/Plot/init.luau`  
**Line:** 1150-1200 (order timer heartbeat)

**Issue:** The order timer connection may not disconnect properly in all edge cases, causing errors after order completion:

```lua
if not self.Active[BrainrotID] or not self.Orders[OrderIndex] then
    if timerConnection then
        timerConnection:Disconnect()
    end
    return
end
```

**Fix:** Use `task.cancel()` with stored task instead of Heartbeat for better cleanup.

---

### 18. Cash Multiplication via Offline Earnings Exploit
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2740-2770 (PlaceBrainrot offline calculation)

**Issue:** Offline earnings calculation doesn't cap the maximum time:

```lua
local timeOffline = self.Owner:GetAttribute("JoinTick") - PlayerReplica.Data.LastLeave
local offlinePerSecond = Calculator.CalculateMoneyPerSecond(...)
local totalOfflineMoney = prevOfflineMoney + (offlinePerSecond * timeOffline * offlineMulti)
```

**Exploit:** Players who haven't played for weeks/months could receive massive unfair payouts.

**Fix:** Cap offline time at reasonable maximum (e.g., 24 hours).

---

### 19. Unvalidated Remote Event Parameters
**File:** `Server/Game/Plot/init.luau`  
**Multiple locations**

**Issue:** Many remote event handlers lack comprehensive parameter validation:

```lua
-- Example: PlotRemote handler for PlacePlant
newPlot.Connections[4] = PlotRemote.OnServerEvent:Connect(function(user, call, info)
    -- info.RawPosition and info.ID are not validated before use!
    newPlot:PlacePlant(uniqueID, info.RawPosition, info.ID)
```

**Fix:** Add comprehensive type and bounds checking for all remote inputs.

---

### 20. Seed Store Race Condition
**File:** `Server/Game/GlobalStore.luau`  
**Line:** 200-250

**Issue:** Stock updates are broadcast AFTER modifying data, creating a brief window where clients see stale data:

```lua
-- 1. Decrement global stock FIRST
local newQuantity = self.CurrentStock[itemName] - 1
self.CurrentStock[itemName] = newQuantity

-- 2. Release the lock
self.PurchaseLock[itemName] = nil

-- 3. Give item to player (yields!)
playerPlot:GiveItem({...})

-- 4. Broadcast (happens late)
self.RemoteEvent:FireAllClients("UpdateStock", itemName, newQuantity)
```

**Fix:** Broadcast BEFORE yielding operations.

---

### 21. Boost Timer Desync on Server Lag
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2880+ (Give* functions)

**Issue:** Boost timers use `task.delay()` which is wall-clock time, not game time. Server lag can cause desync:

```lua
plot.PlayerDelays[self.Owner][delayId] = task.delay(Time, function()
    -- If server was lagging, this might run much later than intended
    self.Owner:SetAttribute("Luck", self.Owner:GetAttribute("Luck") - amount)
end)
```

**Fix:** Track absolute expiration timestamps instead of relative delays.

---

## LOW SEVERITY BUGS

### 22. StarterData Cash Too High for Testing
**File:** `Server/Data/StarterData.luau`  
**Line:** 19

**Issue:** Starting cash is set to 100,000 which may be for testing but should be lower for production:

```lua
Cash = 100000;  -- Should probably be 100 or 0 for production
```

---

### 23. Typo in Offline Time Calculation
**File:** `Server/Game/Plot/init.luau`  
**Line:** 2750

**Issue:** `36400` should be `86400` (24 hours in seconds):

```lua
-- Line 489 in Purchases.luau has same issue
if tick() > PlayerReplica.Data.FirstJoin + 36400 then  -- WRONG!
```

---

### 24. Debug Print Statements Left In
**File:** `Server/Game/Plot/init.luau`  
**Multiple locations**

**Issue:** Debug prints like `warn(' im giving you DIAMOND PLATFORM!!!')` and `print(calculatedMPS)` remain in production code.

**Fix:** Remove or conditionally compile debug statements.

---

### 25. Unused Code in Purchases.luau
**File:** `Server/Game/Purchases.luau`  
**Line:** 178-190

**Issue:** Empty if blocks and unused variables:

```lua
if registeredProducts[productId] then
    -- Empty block!
end
```

---

### 26. Hardcoded GamePass IDs
**File:** Multiple files

**Issue:** GamePass IDs (1657482065, 1666032504) are hardcoded throughout instead of being centralized constants.

---

### 27. Magic Numbers Throughout
**File:** Multiple files

**Issue:** Many magic numbers without constants:
- Inventory sizes (250, 400)
- Growth times
- Cooldown durations
- Rarity weights

---

## SUMMARY TABLE

| Severity | Count | Categories |
|----------|-------|------------|
| Critical | 5 | Data loss, exploits, race conditions |
| High | 8 | Validation failures, memory leaks |
| Medium | 9 | Consistency, timing issues |
| Low | 5 | Code quality, cleanup |
| **TOTAL** | **27** | |

---

## RECOMMENDED PRIORITY FIXES

1. **Immediate (Critical):**
   - Fix #1: Duplicate purchase vulnerability
   - Fix #2: Data loss on server shutdown
   - Fix #5: Memory leak in PlayerDelays

2. **This Sprint (High):**
   - Fix #6: Starter pack validation
   - Fix #8: Gear removal validation
   - Fix #10: Mutation deduplication

3. **Next Sprint (Medium):**
   - Fix #13: Fruit harvest race condition
   - Fix #18: Offline earnings cap
   - Fix #21: Boost timer desync

4. **Backlog (Low):**
   - Fix #22-27: Code cleanup and constants

---

## FILES REQUIRING CHANGES

1. `Server/Game/Purchases.luau` - 5 bugs
2. `Server/Game/Plot/init.luau` - 14 bugs
3. `Server/Game/GlobalStore.luau` - 3 bugs
4. `Server/Game/ServerUtility.luau` - 2 bugs
5. `Server/Game/Leaderboards.luau` - 1 bug
6. `Server/Game/Plot/SprinklerSystem.luau` - 1 bug
7. `Server/Data/StarterData.luau` - 1 bug

---

## TESTING RECOMMENDATIONS

1. **Stress Testing:** Simulate 100+ concurrent purchase attempts
2. **Chaos Testing:** Kill server mid-transaction, verify data integrity
3. **Network Testing:** Test with high latency/packet loss
4. **Long-running Test:** Run server for 24+ hours, monitor memory
5. **Cross-server Testing:** Verify GlobalStore sync across multiple servers
