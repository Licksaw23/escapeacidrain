# ServerUtility & Helper Functions Audit Report

## Executive Summary

**Scope:** ServerUtility.luau, flowUtil.luau, MutationUtil.luau, PickScale.luau, PickMutations.luau, NumberShortener.luau, BezierPath.luau, Placement.luau, Tweener, ShinsLightning, Zone, ViewportFitter, and RainbowGradient.

**Bugs Found:** 8  
**Optimization Opportunities:** 14  
**Code Quality Issues:** 10

---

## 🐛 BUGS FOUND

### 1. **CRITICAL: HandleDestroy Bug - Wrong Table Reference** (ServerUtility.luau:315)
```lua
-- LINE 315: WRONG TABLE USED
local findRotIndex2 = table.find(Spawns, ID)  -- Should be Spawns, not CustomerSpawns
if findRotIndex2 then
    table.remove(CustomerSpawns, findRotIndex2)  -- BUG: Removing from wrong table!
end
```
**Impact:** Memory leak - Spawns table entries are never removed.  
**Fix:** Change `table.remove(CustomerSpawns, findRotIndex2)` to `table.remove(Spawns, findRotIndex2)`

---

### 2. **CRITICAL: GetExactBoundingBox Returns nil for Empty Models** (ServerUtility.luau:89)
```lua
-- If model has no descendants with BaseParts, function returns nil
-- but callers expect a table with Position and Size
```
**Impact:** Runtime errors when calling code tries to access `.Position` on nil.  
**Fix:** Return default bounds or add explicit nil check at call sites.

---

### 3. **MAJOR: PickMutations Ignores eventMultipliers** (PickMutations.luau)
```lua
module.PickMutation = function(luckMultiplier, eventMultipliers)
    if workspace:GetAttribute("GuaranteedMutation") then
        return workspace:GetAttribute("GuaranteedMutation")
    else
        return rollMutation(luckMultiplier, eventMultipliers);  -- Passed but NOT USED!
    end
end

-- rollMutation function signature only accepts luckMultiplier:
local function rollMutation(luckMultiplier)  -- MISSING eventMultipliers parameter!
```
**Impact:** Event multipliers for mutations are completely non-functional.  
**Fix:** Add `eventMultipliers` parameter to `rollMutation` and implement the logic.

---

### 4. **MAJOR: NumberShortener.roundNumber Returns "0" for Negative Numbers**
```lua
function module.roundNumber(no)
    if no and no > 0 then  -- BUG: Excludes negative numbers!
        -- ...
    end
    return "0"
end
```
**Impact:** Negative numbers incorrectly return "0".  
**Fix:** Change `no > 0` to `no ~= 0` or handle negative case properly.

---

### 5. **MAJOR: flowUtil.QuickHighlight Tween Reference Bug** (flowUtil.luau:56)
```lua
local Tween;Tween = TweenService:Create(Highlight, TweenInfo.new(length + 0.45, Enum.EasingStyle.Linear), {
    FillTransparency = 1, 
    OutlineTransparency = 1
}):Play()  -- :Play() returns nil, not the tween!
```
**Impact:** Function returns nil for Tween instead of the actual tween object.  
**Fix:**
```lua
local Tween = TweenService:Create(Highlight, TweenInfo.new(length + 0.45, Enum.EasingStyle.Linear), {
    FillTransparency = 1, 
    OutlineTransparency = 1
})
Tween:Play()
```

---

### 6. **MODERATE: ActiveFruit Handler Missing Validation** (ServerUtility.luau)
```lua
Utility.ActiveFruit[fruitKey] = function(user, call, info)
    -- No validation that 'user' is the plot owner!
    -- Any player could theoretically harvest another's fruit
```
**Impact:** Potential exploit - need to verify the user owns the plot.  
**Fix:** Add ownership validation before processing harvest.

---

### 7. **MODERATE: Utility.PickLowestNumberedArray Logic Error**
```lua
-- If ALL arrays are blacklisted, returns nil without handling
-- Could cause nil index errors downstream
```
**Impact:** Unhandled nil returns could cause crashes.  
**Fix:** Add explicit nil handling or return default value.

---

### 8. **MINOR: Placement.getGroundHit Returns nil Silently**
```lua
local function getGroundHit(screenX, screenY)
    -- ...
    if result and result.Instance then
        return result.Position
    end
    return nil  -- Silent failure, no warning
end
```
**Impact:** Hard to debug when placement fails.  
**Fix:** Add debug logging or return error reason.

---

## ⚡ OPTIMIZATION OPPORTUNITIES

### 1. **GetExactBoundingBox - Severe Inefficiency** (ServerUtility.luau:63-89)
**Problem:** Redundant Vector3 allocations in hot loop (8 iterations × many parts).

**Current:**
```lua
local minX = minBounds.X
local cornerX = cornerPosition.X
local newMinX = math.min(minX, cornerX)
-- ... repeated for Y, Z, then same for maxBounds
```

**Optimized:**
```lua
minBounds = Vector3.new(
    math.min(minBounds.X, cornerPosition.X),
    math.min(minBounds.Y, cornerPosition.Y),
    math.min(minBounds.Z, cornerPosition.Z)
)
```

**Estimated Savings:** ~50% reduction in Vector3 allocations.

---

### 2. **NumberShortener.roundNumber - Use Log10 Instead of Log**
```lua
local exponent = math.floor(math.log(no, 1e3))  -- SLOW
-- Should be:
local exponent = math.floor(math.log10(no) / 3)  -- FASTER
```

---

### 3. **BezierPath - Cache Section Calculations**
```lua
-- CalculateSectionPosition is called repeatedly with same values
-- Could memoize based on Section and T
```

---

### 4. **ServerUtility.FireWhenLoaded - Use CharacterAdded Event**
```lua
-- Current: polling with wait()
repeat wait() until client.Character ~= nil

-- Better: use event-based approach
client.CharacterAdded:Wait()
```

---

### 5. **flowUtil.ResizeAllParticles - Redundant Table Creation**
```lua
for _, target in pairs({ particle }) do  -- Creates new table every call!
```

**Fix:** Pass particle directly or make single-element table reusable.

---

### 6. **Placement Module - Use Heartbeat Instead of RenderStepped**
```lua
placement.CurrentPlacing.Connections["Mouse"] = RunService.RenderStepped:Connect(...)
-- Should be Heartbeat for non-visual updates
```

---

### 7. **Zone Module - OverlapParams Recreation**
```lua
-- Creates new OverlapParams on every update
-- Could be reused/cached
```

---

### 8. **PickMutations - Precompute Weighted Pool**
```lua
-- Currently rebuilds weighted pool on every roll
-- Could cache and only rebuild when MutationsData changes
```

---

### 9. **MutationUtil.GetTintableParts - Sorting Unnecessary for Tinting**
```lua
table.sort(parts, function(a, b)
    return a:GetFullName() < b:GetFullName()
end)
-- Sorting adds O(n log n) overhead for no functional benefit
```

---

### 10. **ServerUtility.BrainrotsByRarity - Build Once**
```lua
-- Currently rebuilds table on every module load
-- Could be moved to a lazy-loading pattern
```

---

### 11. **FastWait - Use task.wait Instead**
```lua
-- Custom FastWait implementation exists
-- Roblox's task.wait is now optimized and should be used instead
```

---

### 12. **FlowUtil.Emit - No Early Exit**
```lua
function flowUtil:Emit(Object:Instance)
    for _,particle in Object:GetDescendants() do
        -- If no ParticleEmitters, still iterates all descendants
```

---

### 13. **Spring Library - typeMetadata Table Lookup**
```lua
-- typeMetadata[typeof(propTarget)] on every property
-- Could cache type lookups
```

---

### 14. **ViewportFitter - Precompute Corner Indices**
```lua
-- getIndices called for every part on every frame
-- Part types rarely change, could cache
```

---

## 🔧 CODE QUALITY ISSUES

### 1. **Duplicate GetExactBoundingBox Implementation**
Both `ServerUtility.luau` and `MutationUtil.luau` have identical implementations.

**Recommendation:** Move to shared utility module.

---

### 2. **Duplicate ResizeParticle Functions**
Both `flowUtil.luau` and `MutationUtil.luau` have nearly identical implementations.

---

### 3. **Magic Numbers Throughout**
- `ServerUtility.luau`: `17` (respawn time), `4` (growth time) - use constants
- `flowUtil.luau`: `10` (debris time), `1.15` (default length)
- `PickScale.luau`: `10` (rounding precision)

---

### 4. **Inconsistent Error Handling**
Some functions return `nil, errorMsg`, others just `nil`, others `warn()`.

---

### 5. **Global State Without Cleanup**
```lua
Utility.ActiveFruit = {}  -- Never cleaned up, grows indefinitely
Utility.ActiveMovements = {}  -- Same issue
```

---

### 6. **Unused Variables**
```lua
-- ServerUtility.luau
local TweenService = game:GetService("TweenService")  -- Never used
local UpdateRemote = Remotes.Update  -- Used only in CustomMovement
```

---

### 7. **Type Safety Issues**
```lua
-- NumberShortener doesn't validate input types properly
function module.roundNumber(no)
    if no and type(no) == "string" then return no end 
    -- Doesn't handle nil, table, etc.
```

---

### 8. **ShinsLightning Uses Deprecated spawn()**
```lua
spawn(function()  -- Deprecated, use task.spawn
```

---

### 9. **Commented Code Left In**
```lua
-- ShinsLightning/init.luau has large commented blocks
-- [[ ... ]]
```

---

### 10. **Inconsistent Module Naming**
- `flowUtil` (camelCase)
- `MutationUtil` (PascalCase)
- `module` (generic)
- `Utility` (PascalCase)

---

## 📋 PRIORITY FIXES

| Priority | Issue | File | Effort |
|----------|-------|------|--------|
| 🔴 Critical | HandleDestroy wrong table | ServerUtility.luau | 5 min |
| 🔴 Critical | PickMutations ignores eventMultipliers | PickMutations.luau | 15 min |
| 🟠 High | GetExactBoundingBox nil return | ServerUtility.luau | 10 min |
| 🟠 High | NumberShortener negative numbers | NumberShortener.luau | 5 min |
| 🟠 High | flowUtil tween nil return | flowUtil.luau | 5 min |
| 🟡 Medium | GetExactBoundingBox optimization | ServerUtility.luau | 15 min |
| 🟡 Medium | Duplicate code consolidation | Multiple | 30 min |
| 🟢 Low | Code style consistency | Multiple | 1 hour |

---

## 💡 RECOMMENDATIONS

1. **Create a shared `BoundingBoxUtil`** to consolidate the duplicate GetExactBoundingBox implementations
2. **Add unit tests** for NumberShortener, PickScale, and PickMutations
3. **Implement proper cleanup** for ActiveFruit and ActiveMovements
4. **Use strict mode** (`--!strict`) in all utility modules
5. **Document all public API** with proper Luau type annotations
