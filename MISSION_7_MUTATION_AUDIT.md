# Mission #7 - Mutation Systems & Fruit Mutations Audit Report

**Audit Date:** February 3, 2026  
**Auditor:** SubAgent - Mutation Systems Analysis  
**Scope:** Complete audit of mutation application, timing, and effects on plants/fruits

---

## Executive Summary

This audit identified **9 bugs/exploits** in the mutation systems, ranging from **CRITICAL** to **MEDIUM** severity. The mutation system has several vulnerabilities that could allow players to:
- Stack duplicate mutations for multiplicative benefits
- Bypass effect mutation limits
- Exploit timing issues to get guaranteed mutations
- Lose mutations due to data handling issues

---

## CRITICAL SEVERITY BUGS

### BUG #1: Duplicate Mutation Stacking Exploit
**Status:** Partially Fixed (FIX_4 exists but not fully implemented)  
**Files:** 
- `Server/Game/Plot/FruitSystem.luau` (lines 44-52)
- `Shared/Modules/Utilities/PickMutations.luau` (lines 34-52)

**Problem:**
The mutation rolling system doesn't prevent the same mutation from being added multiple times:

```lua
-- In FruitSystem.luau
local mutations = {}
local randomMutation = PickMutations.PickMutation(totalLuck, eventMultipliers or {})
if randomMutation then
    table.insert(mutations, randomMutation)  -- No duplicate check!
end
```

**Exploit:**
If a player can trigger fruit generation multiple times (through lag, packet manipulation, or rapid harvesting/respawning), they could theoretically stack the same high-value mutation (like "Rainbow" with 10x multiplier) multiple times for exponential value increase.

**Impact:**
- 10x * 10x = 100x value with duplicate Rainbow
- Infinite value scaling potential

**Fix Required:**
```lua
-- Add deduplication in FruitSystem.GenerateFruitData
local function addUniqueMutation(mutationsList, newMutation)
    if not newMutation then return end
    for _, existing in ipairs(mutationsList) do
        if existing == newMutation then return end
    end
    table.insert(mutationsList, newMutation)
end
```

---

### BUG #2: Nil Mutation Insertion Bug
**File:** `Server/Game/Plot/FruitSystem.luau` (line 48-50)

**Problem:**
```lua
local randomMutation = PickMutations.PickMutation(totalLuck, eventMultipliers or {})
if randomMutation then
    table.insert(mutations, randomMutation)
end
```

While there IS a nil check, the `PickMutation` function can return `nil` when rolling "Normal" mutation:

```lua
-- In PickMutations.luau
if name == "Normal" then
    return nil  -- Normal returns nil!
else
    return name, Mutations[name]
end
```

**Issue:** The code handles this correctly, BUT there's a logic issue - when no mutation is rolled (Normal), the mutations table stays empty. However, later code assumes mutations exist:

```lua
-- In Plot/init.luau, around line 2840
for _, mu in Info.Mutations do  -- If Mutations is nil or {}, this does nothing
    array[mu] = true
end
```

**Fix Status:** Currently handled but could be cleaner with explicit "Normal" mutation entry.

---

### BUG #3: Event Multipliers Not Passed Correctly
**File:** `Shared/Modules/Utilities/PickMutations.luau` (lines 17-22)

**Problem:**
```lua
module.PickMutation = function(luckMultiplier, eventMultipliers)
    if workspace:GetAttribute("GuaranteedMutation") then
        return workspace:GetAttribute("GuaranteedMutation")
    else
        return rollMutation(luckMultiplier, eventMultipliers);  -- eventMultipliers passed but NOT USED!
    end
end
```

The `eventMultipliers` parameter is passed to `PickMutation` but the `rollMutation` function signature doesn't accept it:

```lua
local function rollMutation(luckMultiplier)  -- Missing eventMultipliers parameter!
```

**Impact:** Event multipliers (like 2x mutation chance during events) are never actually applied.

**Exploit:** None (feature broken), but players miss out on intended bonuses during events.

**Fix Required:**
```lua
local function rollMutation(luckMultiplier, eventMultipliers)
    eventMultipliers = eventMultipliers or {}
    -- Apply event multipliers to mutation weights
    for name, mutation in pairs(Mutations) do
        local weight = mutation.Chance
        if name ~= "Normal" then
            weight = weight * luckMultiplier
            -- Apply event multipliers
            if mutation.Rarity and eventMultipliers[mutation.Rarity] then
                weight = weight * eventMultipliers[mutation.Rarity]
            end
        end
        -- ... rest of logic
    end
end
```

---

### BUG #4: Mutation Luck Calculation Bug
**File:** `Server/Game/Plot/FruitSystem.luau` (line 40)

**Problem:**
```lua
local totalLuck = (playerMutationLuck or 0) + (playerLuck or 0)
```

**Issue:** Both luck values are added together and passed as a single multiplier. However, looking at `PickMutations.luau`:

```lua
if name ~= "Normal" then
    weight = weight * luckMultiplier
end
```

The luck multiplier is applied uniformly to all non-Normal mutations. This means:
- If player has 2x mutation luck and 2x regular luck, they get 4x total
- This may be intentional, but could be overpowered

**Potential Exploit:** If luck buffs stack multiplicatively from different sources, players could achieve extremely high mutation rates.

---

## HIGH SEVERITY BUGS

### BUG #5: Effect Mutation Limit Bypass
**File:** `Server/Game/Plot/init.luau` (lines 2848-2862)

**Problem:**
The 6-effect limit check has a race condition:

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
                table.insert(brainrotstuff.Mutations, Mutation)
            end
        end
    end
end
```

**Race Condition:** If a player gives multiple fruits simultaneously (through lag/packet manipulation), each check could see `effectCount < 6` and all get added, bypassing the limit.

**Exploit:** Unlimited effect mutations on a single brainrot.

**Fix Required:**
```lua
-- Add atomic lock
if not brainrotstuff.MutationLock then
    brainrotstuff.MutationLock = true
    
    -- Count effects atomically
    local effectCount = 0
    for _, existingMutation in brainrotstuff.Mutations do
        if MutationsData[existingMutation].IsEffect then
            effectCount += 1
        end
    end
    
    -- Apply mutations with limit
    for _, Mutation in holdingItemData.Mutations do
        if effectCount >= 6 then break end
        -- ... check and add mutation
        if added then effectCount += 1 end
    end
    
    brainrotstuff.MutationLock = nil
end
```

---

### BUG #6: Mutation Data Lost on Harvest→Respawn Cycle
**File:** `Server/Game/Plot/init.luau` (lines 2267-2283)

**Problem:**
When a fruit is harvested and respawns, new mutations are rolled:

```lua
function plot:RespawnFruit(PlantID, FruitIndex)
    -- ...
    -- Generate new fruit data
    local newFruitData = ServerUtility.GenerateFruitData(productName, playerLuck, playerMutationLuck, plot.EventMultipliers)
    -- This rolls NEW mutations, losing old fruit's mutation info
```

**Issue:** This is likely intentional (new fruit = new mutations), BUT there's no guarantee the player's current luck stats are the same as when the plant was first created.

**Exploit:** A player could:
1. Plant with high luck
2. Lose the luck buff
3. Harvest and respawn fruit - new fruit uses current (lower) luck

**Or reverse:**
1. Plant with low luck
2. Gain high luck buff
3. Harvest and respawn - new fruit uses higher luck (this is beneficial, not an exploit)

**Status:** Working as designed, but design may be flawed.

---

### BUG #7: Mutation Application Missing Validation
**File:** `Shared/Modules/Libraries/MutationsData/init.luau` (lines 1-35)

**Problem:**
The `applyParticle` function doesn't validate if the model exists or is valid:

```lua
local function applyParticle(model, particle)
    if model:IsA("Tool") then
        model.PrimaryPart = model:FindFirstChild("Handle")  -- Could fail if no Handle
    end

    if not model.PrimaryPart then
        if model:FindFirstChild("RootPart") then
            model.PrimaryPart = model.RootPart
        end
        return  -- Silent return, no warning!
    end
```

**Issue:** If a model has no Handle or RootPart, the function silently returns without applying the mutation VFX. The mutation data exists but visual doesn't show.

**Impact:** Players confused why mutations aren't visible.

---

## MEDIUM SEVERITY BUGS

### BUG #8: Mutation Table Type Inconsistency
**Files:** Multiple files

**Problem:**
Mutations are stored as arrays in most places:
```lua
-- FruitSystem.luau
Mutations = mutations,  -- Array: {"Gold", "Rainbow"}
```

But in some places treated as dictionaries:
```lua
-- In Plot/init.luau line 2835
for oldMutation,_ in currentIndexData or {} do
    array[oldMutation] = true  -- Treating as dictionary!
end
```

This happens to work because Lua `pairs()` iterates over both array and dictionary elements, but it's inconsistent and fragile.

**Fix Required:** Standardize on array format throughout codebase.

---

### BUG #9: Guaranteed Mutation Exploit
**File:** `Shared/Modules/Utilities/PickMutations.luau` (lines 17-22)

**Problem:**
```lua
module.PickMutation = function(luckMultiplier, eventMultipliers)
    if workspace:GetAttribute("GuaranteedMutation") then
        return workspace:GetAttribute("GuaranteedMutation")
    else
        return rollMutation(luckMultiplier, eventMultipliers);
    end
end
```

**Exploit:** A malicious client (if they have exploit access) could potentially set workspace attributes to force specific mutations:

```lua
-- Exploit code (if client has script injection)
workspace:SetAttribute("GuaranteedMutation", "Rainbow")
-- All subsequent mutations would be Rainbow!
```

**Fix Required:** Server-side validation of the guaranteed mutation attribute:
```lua
-- Server should set this, not rely on workspace attribute
local GuaranteedMutation = workspace:GetAttribute("GuaranteedMutation")
if GuaranteedMutation and MutationsData[GuaranteedMutation] then
    -- Validate it's from a legitimate source (event, admin, etc.)
    if IsLegitimateSource() then
        return GuaranteedMutation
    end
end
```

---

## ADDITIONAL FINDINGS

### Issue #10: Mutation Data Not Deep-Copied
**File:** `Server/Game/Plot/init.luau` (line 2783)

When giving items, mutations are passed by reference:
```lua
self:GiveItem({
    ID = HttpService:GenerateGUID(false);
    Name = productName;
    Weight = fruitData.Weight;
    Mutations = fruitData.Mutations;  -- Reference, not copy!
})
```

If the mutations table is later modified, it could affect the original fruit data.

**Fix:** Create a shallow copy:
```lua
Mutations = table.clone(fruitData.Mutations) or {},
```

---

### Issue #11: Empty Mutations Array vs Nil
**File:** `Server/Game/Plot/FruitSystem.luau`

When no mutation is rolled, the mutations array is empty `{}`. However, some code checks for nil:
```lua
-- In GiveItem
["Mutations"] = Info.Mutations or nil;  -- Empty array would be truthy
```

An empty array `{}` is truthy in Lua, so it won't be converted to nil. This is inconsistent.

**Fix:** Use `if #Info.Mutations > 0 then` to check for empty arrays.

---

## SUMMARY TABLE

| Bug | Severity | File | Exploitable | Fixed |
|-----|----------|------|-------------|-------|
| #1 Duplicate Mutation Stack | CRITICAL | FruitSystem.luau | Yes | Partial |
| #2 Nil Mutation Insertion | LOW | FruitSystem.luau | No | Yes (handled) |
| #3 Event Multipliers Broken | CRITICAL | PickMutations.luau | No | No |
| #4 Luck Calculation | HIGH | FruitSystem.luau | Partial | No |
| #5 Effect Limit Bypass | HIGH | Plot/init.luau | Yes | No |
| #6 Mutation Lost on Respawn | MEDIUM | Plot/init.luau | No | Design Issue |
| #7 Missing Model Validation | MEDIUM | MutationsData.luau | No | No |
| #8 Type Inconsistency | LOW | Multiple | No | No |
| #9 Guaranteed Mutation Exploit | HIGH | PickMutations.luau | Yes | No |
| #10 Reference Not Copy | MEDIUM | Plot/init.luau | Potential | No |
| #11 Empty Array vs Nil | LOW | Multiple | No | No |

---

## RECOMMENDATIONS

### Immediate Fixes (Today)
1. Fix BUG #3 - Event multipliers not being applied
2. Fix BUG #9 - Add server validation for GuaranteedMutation
3. Implement complete FIX_4 - Mutation deduplication

### Short Term (This Week)
1. Fix BUG #5 - Add atomic lock for effect mutation limit
2. Fix BUG #7 - Add model validation in applyParticle
3. Fix BUG #1 - Complete duplicate mutation prevention

### Long Term (This Month)
1. Standardize mutation data types (arrays everywhere)
2. Add comprehensive mutation system unit tests
3. Document mutation lifecycle clearly
4. Add mutation rollback capability for failed operations

---

## TESTING RECOMMENDATIONS

1. **Duplicate Mutation Test:**
   - Harvest and respawn same fruit 100 times
   - Verify no duplicate mutations in any fruit

2. **Event Multiplier Test:**
   - Start an event with 2x mutation chance
   - Verify mutation rates actually increase

3. **Effect Limit Test:**
   - Rapidly give 20+ effect-mutated fruits to a brainrot
   - Verify only 6 effects are applied

4. **Luck Calculation Test:**
   - Test with various luck combinations
   - Verify intended multipliers

---

*End of Mission #7 Audit Report*
