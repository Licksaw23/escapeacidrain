# FeedTheBrainrots Codebase Security & Quality Audit Report

**Audit Date:** February 2, 2026  
**Auditor:** Pentagon - Strategic Analysis  
**Scope:** Full codebase review for conflicts, security vulnerabilities, and code quality issues

---

## Executive Summary

This audit identified **CRITICAL** and **HIGH** severity issues that require immediate attention, primarily around:
1. **RemoteEvent security vulnerabilities** - Missing server-side validation
2. **Nil reference risks** - Potential crashes from missing WaitForChild/nil checks
3. **Event connection leaks** - Undisconnected connections causing memory leaks
4. **Race conditions** - Timing issues between client/server data loading

---

## Critical Severity Issues

### 1. CRITICAL: Duplicate Data Module Loading (Nil Reference Risk)
**File:** `Server/Game/Plot/init.luau`  
**Line:** 11-12  
**Severity:** CRITICAL

```luau
local Data = require(Replicated:WaitForChild("ServerPlayerData"))  -- Line 11
-- ... other code ...
local Data = require(Replicated:WaitForChild("ServerPlayerData"))  -- Line 12 (DUPLICATE)
```

**Problem:** The `Data` module is required twice with the same name. This is:
1. Wasteful (loads module twice)
2. The second assignment overwrites the first, potentially causing confusion
3. If `ServerPlayerData` doesn't exist, this will cause a nil reference error

**Fix:** Remove the duplicate line (line 12).

---

### 2. CRITICAL: Missing Player Validation in OrderRemote Handler
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~350-420  
**Severity:** CRITICAL

```luau
newPlot.Connections[2] = OrderRemote.OnServerEvent:Connect(function(user, call, ...)
    if user ~= newPlot.Owner then return end
    -- ... validation happens here but ...
    if call == "GiveFruit" then
        local path, itemID = ...
        if not path or not itemID then return end
        -- No validation that path is 1-3!
        -- No validation that itemID exists in user's inventory!
```

**Problem:** The `GiveFruit` handler doesn't validate:
1. That `path` is a valid number (1-3)
2. That the `itemID` actually exists in the player's inventory before processing
3. That the brainrot at that path is still waiting for the order

**Exploit Risk:** A malicious client could send arbitrary itemIDs or invalid paths.

**Fix:** Add comprehensive validation (see modified file).

---

### 3. CRITICAL: Connection Index Overwrite - Event Leak
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~1180 and ~1202  
**Severity:** CRITICAL

```luau
newPlot.Connections[7] = Remotes.Rebirth.OnServerEvent:Connect(...)  -- Line ~1180
-- ... later ...
newPlot.Connections[7] = Remotes.FavoriteFruit.OnServerEvent:Connect(...)  -- Line ~1202
```

**Problem:** `Connections[7]` is assigned twice. The first connection (Rebirth) is overwritten by the second (FavoriteFruit), causing:
1. The Rebirth connection is lost from the tracking table
2. When `Terminate()` is called, the Rebirth connection won't be disconnected
3. Memory leak and potential ghost event handling

**Fix:** Use unique indices or table.insert() for connections.

---

### 4. CRITICAL: Infinite Yield Risk in plot.new()
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~80-90  
**Severity:** CRITICAL

```luau
repeat wait() until Player.Character or Player.CharacterAdded:Wait()
Player.Character.PrimaryPart:PivotTo(PlotsFolder[i].Spawn.CFrame)
```

**Problem:** 
1. If `Player.CharacterAdded:Wait()` returns nil (rare edge case), the code continues but `Player.Character` might be nil
2. No timeout mechanism - could hang forever
3. `PrimaryPart` might not exist yet

**Fix:** Add timeout and nil checks.

---

## High Severity Issues

### 5. HIGH: Missing nil check in CompleteOrder
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~460  
**Severity:** HIGH

```luau
newPlot.Functions["CompleteOrder"] = function(number, passChecks)
    local getCurrentOrder = newPlot.CurrentOrder[number]
    local orderCache = getCurrentOrder.Cache  -- CRASH: if getCurrentOrder is nil
```

**Problem:** If `getCurrentOrder` is nil (order already completed/cancelled), this will error.

**Fix:** Add nil check before accessing `.Cache`.

---

### 6. HIGH: Unsafe table.find in HandleDestroy
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~1450-1480  
**Severity:** HIGH

```luau
for _, spawnID in ServerUtility.CustomerSpawns[self.PlotNumber] or {} do
    -- ...
    SpawnRemote:FireAllClients("DeleteBrainrot", {
        ["ID"] = spawnID;
        ["Plot"] = self.PlotNumber;
        ["Path"] = self.Active[spawnID].Path;  -- CRASH: Active[spawnID] might be nil
    })
```

**Problem:** `self.Active[spawnID]` might be nil if the brainrot was already destroyed.

**Fix:** Add nil check.

---

### 7. HIGH: Event Connection Leak in SetupPlatform
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~620-680  
**Severity:** HIGH

```luau
newPlot.Connections["PlatformPlace"..Platform.Name] = newProximityPrompt.Triggered:Connect(...)
```

**Problem:** If a platform is destroyed and recreated (rebirth/reset), the old connection isn't disconnected. The connection key uses platform name which could collide.

**Fix:** Track connections per-platform and disconnect old ones.

---

### 8. HIGH: Unsafe Data Access in Purchase Handler
**File:** `Server/Game/Purchases.luau`  
**Line:** ~170-200  
**Severity:** HIGH

```luau
repeat wait() until Data[player]
local PlayerReplica = Data[player]
repeat wait() until PlayerReplica.Data
-- Race condition: Player could leave between these lines!
```

**Problem:** No check if player is still in game after waiting.

**Fix:** Add player validity checks.

---

### 9. HIGH: Memory Leak in Admin Module (MessagingService)
**File:** `Server/Game/Admin.luau`  
**Severity:** HIGH

```luau
MessagingService:SubscribeAsync(GlobalMessageChannel, function(messageData)
    -- No error boundary for malformed messages
    -- No timeout on processing
```

**Problem:** Malformed messages could cause repeated errors.

---

### 10. HIGH: Unsafe Property Access in Client
**File:** `Client/UI/HUD/Plot [Client].luau`  
**Line:** ~1100-1150  
**Severity:** HIGH

```luau
local getPlayerForRot
for _, PLR in game.Players:GetChildren() do 
    if PLR:GetAttribute("Plot") == info.Plot then 
        getPlayerForRot = PLR 
    end 
end
-- If no player found, getPlayerForRot is nil and passed to LerpMover
```

---

## Medium Severity Issues

### 11. MEDIUM: Unused Variables
**File:** `Server/Game/Plot/init.luau`
**Examples:**
- Line ~40: `local PlantScripts = ...` (never used)
- Line ~52: `local UpdateRemote = ...` (referenced but not significantly used)
- Multiple unused imports throughout codebase

### 12. MEDIUM: Deprecated wait() Usage
**File:** Multiple files  
**Problem:** Using deprecated `wait()` instead of `task.wait()`

### 13. MEDIUM: Potential Race Condition in Data Loading
**File:** `Server/Game/Plot/init.luau`  
**Line:** ~85-95  
**Problem:** `repeat wait() until Data[Player]` could hang if data never loads.

### 14. MEDIUM: Missing type checks in Remote handlers
**File:** Multiple files  
**Problem:** Most remotes don't validate parameter types (e.g., checking if a parameter is actually a number)

### 15. MEDIUM: Duplicate Code for Tool Removal
**File:** `Server/Game/Plot/init.luau`  
**Problem:** Same tool removal pattern repeated 5+ times. Should be centralized.

---

## Low Severity Issues

### 16. LOW: Inconsistent Variable Naming
**Examples:**
- `newPlot` vs `plotSelf` vs `self`
- `BrainrotID` vs `brainrotID` vs `ID`

### 17. LOW: Missing Comments on Complex Logic
**File:** Weight calculation, mutation rolling

### 18. LOW: Hardcoded Magic Numbers
**Examples:** 
- `MaxPerLine = 6` (should be configurable)
- `OffsetPerBrainrot = 2.5`

---

## Security Vulnerabilities Summary

| Vulnerability | Risk Level | Exploitability |
|--------------|------------|----------------|
| RemoteEvent parameter injection | HIGH | Easy |
| Missing inventory validation | CRITICAL | Easy |
| Connection tracking failures | HIGH | Moderate |
| Nil reference crashes | HIGH | Easy |
| Race condition exploits | MEDIUM | Difficult |

---

## Recommendations

1. **Immediate (Fix Today):**
   - Fix connection index overwrite (Issue #3)
   - Add validation to OrderRemote handler (Issue #2)
   - Remove duplicate Data require (Issue #1)

2. **Short Term (This Week):**
   - Add comprehensive nil checks
   - Fix event connection leaks
   - Add player validity checks after yield operations

3. **Long Term (This Month):**
   - Centralize duplicate code patterns
   - Implement proper error boundaries
   - Add comprehensive type checking to all remotes
   - Consider using a validation library for remote inputs

---

## Files Modified

1. `Server/Game/Plot/init.luau` - Fixed critical issues #1, #2, #3, #4, #5, #6, #7
2. `Server/Game/Purchases.luau` - Fixed issue #8

---

*End of Audit Report*
