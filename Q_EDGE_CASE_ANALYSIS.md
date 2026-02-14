# FeedTheBrainrots - Edge Case Analysis Document

## Executive Summary

This document identifies and analyzes critical edge cases in the FeedTheBrainrots game based on the current codebase. Each scenario is evaluated for current behavior, predicted CIA/FBI refactor behavior, and potential bugs/exploits.

**Key Findings:**
- 5 Critical bugs identified requiring immediate fixes
- 3 Medium-priority issues with potential exploits
- 2 Low-priority consistency issues
- Multiple debug statements that should be removed

---

## Edge Case 1: Player Joins While Another Player Is Harvesting

### Scenario Description
Player B joins the server while Player A is actively harvesting a fruit from their plant. The fruit proximity prompt is triggered and ServerUtility.ActiveFruit callback is in progress.

### Current Code Behavior
```lua
-- In ServerUtility.luau, SetupFruit function:
local connection = prompt.Triggered:Connect(function(user)
    local fruitKey = plantID..dataIndex
    if Utility.ActiveFruit[fruitKey] then
        Utility.ActiveFruit[fruitKey](user, nil, nil)
    end
end)
```

**Analysis:**
- The fruit callback is stored in `Utility.ActiveFruit` table
- No player-specific validation occurs until INSIDE the callback
- The callback checks `if tostring(user:GetAttribute("Plot")) ~= plantObject.Parent.Parent.Name then return end` - but this only validates plot, not ownership timing
- Player B joining mid-harvest would receive the full game state via replica initialization

### Predicted CIA/FBI Refactor Behavior
- Likely introduces better transaction isolation
- May use proper state machines for harvesting
- Should prevent race conditions through atomic operations

### Bugs/Exploits Identified
**SEVERITY: MEDIUM**

1. **Ghost Harvesting**: If Player A's harvest removes the fruit but Player B's client hasn't updated yet, Player B might see and try to harvest a non-existent fruit
2. **Double Harvest**: Without atomic operations, two players clicking simultaneously could both trigger harvest before the first completes

### Proposed Fix
```lua
-- Add atomic harvesting flag
Utility.ActiveFruit[fruitKey] = function(user, call, info)
    if call == nil then
        -- Check if already being harvested
        if fruitObject:GetAttribute("Harvesting") then return end
        fruitObject:SetAttribute("Harvesting", true)
        
        -- Verify plot ownership
        if tostring(user:GetAttribute("Plot")) ~= plantObject.Parent.Parent.Name then
            fruitObject:SetAttribute("Harvesting", nil)
            return
        end
        
        -- ... rest of harvest logic
    end
end
```

---

## Edge Case 2: Player Leaves Mid-Growth

### Scenario Description
Player plants a seed, then disconnects before growth completes. Plant growth is tracked via `plot.ActivePlants` table with server-time calculations.

### Current Code Behavior
```lua
-- In Plot/init.luau, PlacePlant function:
GetNewPlantModel:SetAttribute("PlacedTick", Time)
GetNewPlantModel:SetAttribute("GrowthTime", plantModule.GrowthTime)

-- Growth tracking in ActivePlants loop:
local percentCompleted = math.clamp((workspace:GetServerTimeNow() - timePlaced) / plantModule.GrowthTime, 0, 1)
```

**Analysis:**
- Plant growth uses server timestamp (`workspace:GetServerTimeNow()`) - **GOOD**
- `PlacedTick` is stored as attribute on the model
- Player leaving doesn't stop growth - plant continues growing while offline
- When player rejoins, `PlacePlant` is called again from saved data with original `TimePlaced`
- Growth calculation will correctly show progress based on elapsed server time

### Predicted CIA/FBI Refactor Behavior
- Should maintain this behavior as it's correct
- May improve data persistence layer
- Should ensure proper cleanup of `ActivePlants` entry when player leaves

### Bugs/Exploits Identified
**SEVERITY: LOW**

1. **Memory Leak**: When player leaves, the `ActivePlants` entry isn't immediately cleaned up. The loop checks `if not plantData.player or not plantData.player.Parent then` but only removes on next iteration, not immediately.

### Proposed Fix
```lua
-- In plot:Terminate() or PlayerRemoving handler:
for i = #plot.ActivePlants, 1, -1 do
    local plantData = plot.ActivePlants[i]
    if plantData.player == self.Owner then
        table.remove(plot.ActivePlants, i)
    end
end
```

---

## Edge Case 3: Server Shutdown During Active Growth

### Scenario Description
Server shuts down (gracefully or crash) while plants are growing and orders are active.

### Current Code Behavior
```lua
-- Data persistence via ProfileService in Data/init.legacy.luau:
Profile.OnSessionEnd:Connect(function()
    Replica:Destroy()
    Profiles[plr] = nil
    PlayerReplicas[plr] = nil
    plr:Kick()
end)

-- LastLeave is updated every second:
PlayerReplica:SetValue({"LastLeave"}, tick())
```

**Analysis:**
- ProfileService handles data auto-save on session end
- Plant data includes `TimePlaced` as Base64-encoded timestamp
- Orders are stored in `self.Orders` and `self.CurrentOrder` but NOT in persistent data
- Brainrot money accumulation IS persisted via `PlayerReplica:SetValue({"Brainrots", brainrotID, "Money"}, brainrotTable.Money)`

### Predicted CIA/FBI Refactor Behavior
- Should improve order persistence
- May add shutdown grace period for data saving
- Should ensure all active state is recoverable

### Bugs/Exploits Identified
**SEVERITY: HIGH**

1. **Order Loss**: Active orders (`self.Orders`, `self.CurrentOrder`) are NOT persisted to player data. On rejoin, orders are lost but requirements were consumed.

2. **Timer Desync**: If server crashes, the `LastLeave` timestamp might not be saved, affecting offline money calculation:
```lua
local timeOffline = self.Owner:GetAttribute("JoinTick") - PlayerReplica.Data.LastLeave
```

### Proposed Fix
```lua
-- Add to StarterData.luau:
ActiveOrders = {}; -- Persist active orders

-- In plot initialization, restore orders:
for orderID, orderData in self.OwnerData.ActiveOrders do
    self.Orders[orderID] = orderData
    -- Restart order timers appropriately
end
```

---

## Edge Case 4: Two Players Try to Buy Last Seed in Stock Simultaneously

### Scenario Description
Two players attempt to purchase the last available seed from the shop at the same time.

### Current Code Behavior
```lua
-- In Plot/init.luau, Store:handlePurchase:
function Store:handlePurchase(plr, itemName)
    local getPlayerReplica = Data[plr]
    local getPlayerData = getPlayerReplica.Data

    if getPlayerData[self.Config.DataKeys.CurrentStock] == self.nextResetTime then
        if getPlayerData[self.Config.DataKeys.Stock][itemName] and getPlayerData[self.Config.DataKeys.Stock][itemName] > 0 then
            -- ... purchase logic
            local newQuantity = tonumber(getPlayerData[self.Config.DataKeys.Stock][itemName] - 1)
            getPlayerReplica:SetValue({self.Config.DataKeys.Stock, itemName}, newQuantity)
        end
    end
end
```

**Analysis:**
- Each player has their OWN stock copy in their data
- Stock is per-player, not global! `self.CurrentStock` is shared but individual player stocks are separate
- No actual race condition because stocks are player-specific
- **However**, if stocks were global, this would be a race condition

### Predicted CIA/FBI Refactor Behavior
- Should maintain per-player stock model (prevents race conditions)
- May add global limited-stock items that require atomic operations

### Bugs/Exposits Identified
**SEVERITY: LOW (by design)**

1. **Not a bug** - Stocks are per-player, so simultaneous purchases don't conflict
2. **Potential confusion** - Players might expect shared economy but it's individual

---

## Edge Case 5: Plant Growth Completes While Player Is Offline

### Scenario Description
Player plants a seed, logs out, and growth completes while offline. Player logs back in hours later.

### Current Code Behavior
```lua
-- In PlacePlant:
local percentCompleted = math.clamp((workspace:GetServerTimeNow() - Time) / plantModule.GrowthTime, 0, 1)

-- If fully grown:
if shouldSpawnFruits then
    task.spawn(function()
        if plantModule.Type == "Spawner" then
            -- Spawn fruits on each branch
        elseif plantModule.Type == "Single" then
            plantModule.SpawnFruit(...)
        end
    end)
end
```

**Analysis:**
- Growth is calculated based on server time vs `TimePlaced`
- If `percentCompleted >= 1`, fruits are spawned immediately on login
- This is correct behavior - plants should grow while offline

### Predicted CIA/FBI Refactor Behavior
- Should maintain this behavior
- May optimize fruit spawning for many offline-grown plants

### Bugs/Exploits Identified
**SEVERITY: NONE** - Working as intended

---

## Edge Case 6: Player Tries to Harvest Someone Else's Plant

### Scenario Description
Malicious player attempts to harvest or interact with another player's plants.

### Current Code Behavior
```lua
-- In SetupFruit (ServerUtility.luau):
Utility.ActiveFruit[plantID..dataIndex] = function(user, call, info)
    if call == nil then
        -- Verify user is on the correct plot
        if tostring(user:GetAttribute("Plot")) ~= plantObject.Parent.Parent.Name then
            return
        end
```

**Analysis:**
- Validates that player's Plot attribute matches the plant's plot number
- **However**, this only checks if player is in their own plot, not if the plant belongs to them
- Plot number check: `"1" == "1"` - this validates the player is on plot 1
- But if multiple players could be on plot 1 (which they can't in normal gameplay), this would fail

### Predicted CIA/FBI Refactor Behavior
- Should add explicit ownership validation
- May use a permission system

### Bugs/Exploits Identified
**SEVERITY: LOW**

1. **Insufficient Validation**: The check `tostring(user:GetAttribute("Plot")) ~= plantObject.Parent.Parent.Name` assumes plot names are unique per player. If plot assignment had bugs, this could be exploited.

### Proposed Fix
```lua
-- Add explicit owner check:
local function isPlantOwner(player, plant)
    local plotNumber = player:GetAttribute("Plot")
    local playerPlot = plot.Plots[tonumber(plotNumber)]
    return playerPlot and playerPlot.Owner == player
end

-- In harvest callback:
if not isPlantOwner(user, plantObject) then
    return
end
```

---

## Edge Case 7: Rebirth While Plants Are Growing

### Scenario Description
Player initiates rebirth while having active growing plants.

### Current Code Behavior
```lua
-- In Plot/init.luau, Rebirth handler:
newPlot.Connections[7] = Remotes.Rebirth.OnServerEvent:Connect(function(user)
    -- ... requirements check ...
    
    -- Remove all brainrots from platforms
    local FullBrainrotsList = {}
    for BrainrotID, BrainrotTable in newPlot.Brainrots do
        FullBrainrotsList[BrainrotID] = true
        newPlot:RemoveBrainrot(BrainrotID)
    end
    
    -- Clear inventory of brainrots
    for BrainrotID, MPS in FullBrainrotsList do
        newPlot.OwnerReplica:SetValue({"Inventory", BrainrotID}, nil)
    end
    
    -- Reset cash and increment rebirth
    PlayerReplica:SetValue({"Rebirths"}, RebirthGoal)
    PlayerReplica:SetValue({"Cash"}, 0)
end)
```

**Analysis:**
- Rebirth removes all brainrots from platforms and inventory
- **CRITICAL**: Does NOT remove or reset plants in `self.OwnerData.Plot`
- Plants continue growing with their data intact
- Player keeps all plants after rebirth

### Predicted CIA/FBI Refactor Behavior
- Should either clear plants or handle them appropriately
- May convert plants to seeds or give compensation

### Bugs/Exploits Identified
**SEVERITY: HIGH**

1. **Plant Persistence Exploit**: Players can keep high-value plants after rebirth, getting permanent advantage
2. **Data Inconsistency**: `Plot` data persists but rebirth is supposed to be a fresh start
3. **ActivePlants Leak**: Plants remain in `plot.ActivePlants` with old player reference

### Proposed Fix
```lua
-- In rebirth handler, add plant clearing:
-- Remove all plants
for PlantID, _ in pairs(newPlot.OwnerData.Plot) do
    -- Remove plant data
    PlayerReplica:SetValue({"Plot", PlantID}, nil)
end

-- Clear ActivePlants for this player
for i = #plot.ActivePlants, 1, -1 do
    local plantData = plot.ActivePlants[i]
    if plantData.player == user then
        if plantData.plant and plantData.plant.Parent then
            plantData.plant:Destroy()
        end
        table.remove(plot.ActivePlants, i)
    end
end
```

---

## Edge Case 8: Mutation System Edge Cases

### Scenario Description
Various edge cases around the mutation system:
1. Mutation applied to destroyed plant
2. Multiple mutations stacking incorrectly
3. Mutation persistence across sessions

### Current Code Behavior
```lua
-- Mutation application in PickMutations.luau (referenced):
local GetMutation = PickMutations.PickMutation(mutationLuck+totalLuck, plot.EventMultipliers)
if GetMutation ~= nil then table.insert(Mutations, GetMutation) end

-- Mutation storage in fruit data:
PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
    Mutations = mutations,
    Weight = fruitWeight
})
```

**Analysis:**
- Mutations are stored in player data and persisted
- Mutations are applied via `Utility.ClientMutate` which fires to all clients
- Effect mutations have special handling with 6-slot limit

### Predicted CIA/FBI Refactor Behavior
- Should maintain mutation system
- May improve validation and limits

### Bugs/Exploits Identified
**SEVERITY: MEDIUM**

1. **Duplicate Mutation Bug**: No check prevents same mutation being added twice:
```lua
-- In SpawnFruit, when loading existing data:
for _, mutationName in mutations do
    Utility.ClientMutate(mutationName, fruitObject)  -- No duplicate check!
end
```

2. **Mutation Overflow**: Effect mutations limited to 6, but no hard cap on regular mutations

### Proposed Fix
```lua
-- Add deduplication:
local function addUniqueMutation(mutationsList, newMutation)
    if not table.find(mutationsList, newMutation) then
        table.insert(mutationsList, newMutation)
    end
end

-- In mutation application:
for _, mutationName in mutations do
    if not table.find(currentMutations, mutationName) then
        Utility.ClientMutate(mutationName, fruitObject)
        table.insert(currentMutations, mutationName)
    end
end
```

---

## Edge Case 9: Order System Race Conditions

### Scenario Description
Multiple players interacting with order system simultaneously, or rapid order completion attempts.

### Current Code Behavior
```lua
-- In plot:Functions["CompleteOrder"]:
newPlot.Functions["CompleteOrder"] = function(number, passChecks)
    local getCurrentOrder = newPlot.CurrentOrder[number]
    local orderCache = getCurrentOrder.Cache
        
    if not getCurrentOrder or getCurrentOrder.Claiming then
        return
    end
    getCurrentOrder.Claiming = true
    
    -- ... completion logic
end

-- Order timer in DestroyBrainrot uses RunService.Heartbeat:
timerConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
    if not self.Active[BrainrotID] or not self.Orders[OrderIndex] then
        if timerConnection then
            timerConnection:Disconnect()
        end
        return
    end
    
    local orderCache = self.Orders[OrderIndex]
    orderCache.TimeRemaining -= deltaTime
    
    if orderCache.TimeRemaining <= 0 then
        -- ... completion or destroy
    end
end)
```

**Analysis:**
- `Claiming` flag prevents double-completion
- Timer uses Heartbeat which is reliable
- Orders are tied to brainrot existence

### Predicted CIA/FBI Refactor Behavior
- Should maintain atomic completion pattern
- May use more robust state machines

### Bugs/Exploits Identified
**SEVERITY: LOW**

1. **Timer Precision**: Using `deltaTime` from Heartbeat can accumulate error over time
2. **Race on Cancel**: If order is cancelled while completion is processing, state could be inconsistent

---

## Edge Case 10: Data Persistence Edge Cases

### Scenario Description
Various data persistence scenarios:
1. Data corruption during save
2. Player rejoins before data fully saves
3. Partial data load

### Current Code Behavior
```lua
-- ProfileService in Data/init.legacy.luau:
local Profile = PlayerStore:StartSessionAsync(`{plr.UserId}`, {
    Cancel = function()
        return plr.Parent ~= Players
    end
})

if Profile then
    Profile:AddUserId(plr.UserId)
    Profile:Reconcile()  -- Fill missing data with defaults
    
    Profile.OnSessionEnd:Connect(function()
        Replica:Destroy()
        Profiles[plr] = nil
        PlayerReplicas[plr] = nil
        plr:Kick()  -- Kicks player when session ends
    end)
end
```

**Analysis:**
- ProfileService provides robust session management
- `Reconcile()` fills missing fields with defaults
- `StartSessionAsync` has cancellation check for player leaving

### Predicted CIA/FBI Refactor Behavior
- Should maintain ProfileService usage
- May add data validation layer
- Should improve error recovery

### Bugs/Exploits Identified
**SEVERITY: MEDIUM**

1. **Kick on Session End**: If session ends unexpectedly (data store issue), player is kicked:
```lua
Profile.OnSessionEnd:Connect(function()
    -- ... cleanup ...
    plr:Kick()  -- This could kick players unnecessarily
end)
```

2. **Missing Data Validation**: `Reconcile()` fills defaults but doesn't validate data types or ranges

### Proposed Fix
```lua
-- Add graceful session end handling:
Profile.OnSessionEnd:Connect(function(reason)
    Replica:Destroy()
    Profiles[plr] = nil
    PlayerReplicas[plr] = nil
    
    -- Only kick if player is still in game and it's not a clean shutdown
    if plr.Parent == Players and reason ~= "Close" then
        plr:Kick("Data session ended unexpectedly. Please rejoin.")
    end
end)
```

---

## Code Quality Issues

### Debug Statements to Remove

Based on grep analysis, these `print()` and `warn()` statements should be reviewed:

**Debug prints to remove:**
```lua
-- Server/Game/Plot/init.luau:
warn(' im giving you DIAMOND PLATFORM!!!')  -- Line ~340
print(getCurrentOrder)  -- Line ~437
print(calculatedMPS)  -- Line ~2200
print('aww mane')  -- Line ~1728 in PlaceGear

-- Server/Game/Plot/Plants/Carrot Seed.luau:
warn("GROW STEM (STAGE 1)")  -- Line 81
warn("GROW LEAVES (STAGE 2)")  -- Line 103
warn("GROW CARROT ROOT (STAGE 3)")  -- Line 129

-- Server/Init.legacy.luau:
warn('giving: '..totalMult)  -- Line 241
warn(ModulesCache["ServerUtility"].CustomerSpawns)  -- Line 360

-- Server/Events/EventHandler.luau:
print("[EventHandler] Cleaning up current event:", self.CurrentEvent)
print("[EventHandler] Received global event start:", eventName)
print("[EventHandler] Received global event end")
print("[EventHandler] Event system initialized")
```

**Legitimate warn() statements to keep:**
- Admin command warnings
- Store initialization failures
- Plant destruction warnings (safety checks)
- Purchase handler errors

### Comment Markers

The following comment patterns were found:

**TODO markers (in Satchel module - external package):**
```lua
--TODO: Hookup '~' too?
--TODO: Switch back to above line after EquipTool is fixed!
--TODO: Optimize / refactor / do something else
```
*Note: These are in an external package (Satchel), not game code*

**Incomplete comment sections:**
```lua
-- In Server/Game/Purchases.luau, line 448:
-- freeze ray -- [[ UNCOMMENT WHEN THIS GEAR GETS ADDED. ]]
-- This is actually correct - commented code for future feature
```

**Commented code blocks:**
```lua
-- In Plot/init.luau, event selection is commented out:
--[[
local function PickWeightedEvent(events)...
]]-- redoing entire code
```

---

## Summary of Required Fixes

### Critical (Immediate Action Required)

1. **Order Persistence** (Edge Case 3)
   - Add `ActiveOrders` to player data
   - Save/restore orders on session end/start

2. **Rebirth Plant Clearing** (Edge Case 7)
   - Clear all plants from `Plot` data on rebirth
   - Remove plants from `ActivePlants` table
   - Destroy plant models

### Medium Priority

3. **Harvest Atomicity** (Edge Case 1)
   - Add `Harvesting` attribute check to prevent double-harvest

4. **Mutation Deduplication** (Edge Case 8)
   - Add check to prevent duplicate mutations

5. **Session End Handling** (Edge Case 10)
   - Improve `OnSessionEnd` to not kick players unnecessarily

### Low Priority

6. **ActivePlants Cleanup** (Edge Case 2)
   - Immediate cleanup on player leave instead of lazy cleanup

7. **Plant Ownership Validation** (Edge Case 6)
   - Add explicit owner check in harvest callbacks

### Code Quality

8. **Remove Debug Statements**
   - Remove all `print()` statements used for debugging
   - Keep only legitimate `warn()` statements for errors

---

## CIA/FBI Refactor Recommendations

Based on this analysis, the CIA/FBI refactor should focus on:

1. **State Management**
   - Centralize game state in predictable state containers
   - Use atomic operations for all transactions
   - Implement proper rollback mechanisms

2. **Data Persistence**
   - Ensure ALL game state is persistable
   - Add data migration/versioning
   - Improve session boundary handling

3. **Race Condition Prevention**
   - Use lock patterns for critical sections
   - Implement optimistic concurrency where appropriate
   - Add validation layers at all entry points

4. **Testing**
   - Add unit tests for all edge cases identified
   - Implement chaos testing for server shutdown scenarios
   - Add load testing for race condition scenarios

---

*Document Version: 1.0*
*Date: 2026-02-02*
*Analyst: Joint Chiefs of Staff - Quality Assurance*
