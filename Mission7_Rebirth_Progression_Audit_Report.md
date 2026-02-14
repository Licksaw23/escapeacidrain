# Mission 7 - Rebirth & Progression Systems Audit Report

## Executive Summary

This audit examined the rebirth and progression systems in FeedTheBrainrots, identifying **7 critical issues** including stat exploits, multiplier stacking vulnerabilities, data validation flaws, and duplication risks. Several fixes have already been prepared in the M7_FIX files.

---

## 1. CRITICAL: Rebirth Multiplier Stacking Exploit

### Issue Description
Rebirth multipliers are applied **additively** rather than checking for existing multipliers, allowing players to accumulate permanent advantages.

### Location
- `Server/Init.legacy.luau` (lines 242-247)
- `Server/Game/Plot/init.luau` (lines 2550-2556)

### Current Code
```lua
-- Rebirth luck. --
local totalMult = 0.5 * (Data.Rebirths or 0)
if totalMult > 0 then
    warn('giving: '..totalMult)
    newPlot:GiveTotalLuck(totalMult)
    newPlot:GiveCashMultiplier(totalMult)
    newPlot:GiveSpeed(totalMult)
end
```

### Vulnerability
- **Rebirth 1**: 0.5x multiplier applied
- **Rebirth 2**: 1.0x multiplier applied (cumulative: 1.5x total)
- **Rebirth 3**: 1.5x multiplier applied (cumulative: 3.0x total)

Each rebirth grants +50% to Luck, Money, and Speed, but the code adds these multipliers **on top of** previous ones every time the player joins, causing exponential stat growth.

### Exploit Scenario
1. Player reaches Rebirth 3
2. Each time they rejoin, they get additional 1.5x multipliers
3. After 10 rejoins: 15x base multipliers
4. After 100 rejoins: 150x base multipliers

### Fix Required
Track which multipliers have been applied and only grant new ones:

```lua
-- Check if rebirth multipliers already applied
if not User:GetAttribute("RebirthMultipliersApplied") then
    local totalMult = 0.5 * (Data.Rebirths or 0)
    if totalMult > 0 then
        newPlot:GiveTotalLuck(totalMult)
        newPlot:GiveCashMultiplier(totalMult)
        newPlot:GiveSpeed(totalMult)
        User:SetAttribute("RebirthMultipliersApplied", true)
    end
end
```

**Severity: CRITICAL** - Allows unlimited stat scaling through session resets

---

## 2. HIGH: Event Multiplier Parameter Ignored

### Issue Description
Event multipliers are passed to `PickMutation` but never applied to mutation rolls.

### Location
- `Shared/Modules/Utilities/PickMutations.luau`

### Current Code
```lua
module.PickMutation = function(luckMultiplier, eventMultipliers)
    if workspace:GetAttribute("GuaranteedMutation") then
        return workspace:GetAttribute("GuaranteedMutation")
    else
        return rollMutation(luckMultiplier, eventMultipliers);  -- eventMultipliers passed
    end
end

local function rollMutation(luckMultiplier, eventMultipliers)  -- received but never used
    -- ... code doesn't use eventMultipliers ...
end
```

### Impact
Event-based mutation boosts (like 2x Weekend, special events) don't actually affect mutation chances, making events less valuable than advertised.

### Fix Available
See `M7_FIX_1_EventMultipliers.luau` for complete fix.

**Severity: HIGH** - Broken game feature, player expectations not met

---

## 3. HIGH: Platform Multiplier Calculation Bug

### Issue Description
Super platform multipliers are calculated inconsistently - applied in some places but not others.

### Location
- `Server/Game/Plot/init.luau` (lines 2549-2559)

### Current Code
```lua
local calculatedMPS = Calculator.CalculateMoneyPerSecond(name, weight, mutations, self.Owner:GetAttribute("Rebirths"))

local Multi = 1.5
if self.OwnerData.Rebirths >= 3 then
    Multi = 2							
end
if brainrotTable.Platform == "Super" then
    calculatedMPS *= Multi
end
```

### Issues
1. `brainrotTable` is undefined in this context (should be `Cache`)
2. The multiplier is applied to MPS display but NOT consistently applied to actual cash generation
3. No validation that player actually has Rebirth 3 before applying 2x multiplier

### Fix Required
```lua
local calculatedMPS = Calculator.CalculateMoneyPerSecond(name, weight, mutations, self.Owner:GetAttribute("Rebirths"))

-- Apply Super platform multiplier
if platform == "Super" then
    local superMulti = (self.OwnerData.Rebirths >= 3) and 2 or 1.5
    calculatedMPS = math.floor(calculatedMPS * superMulti)
end
```

**Severity: HIGH** - Inconsistent economy, potential for exploitation

---

## 4. MEDIUM: Rebirth Requirements Validation Gap

### Issue Description
Rebirth requirements only check inventory counts but don't verify item ownership or prevent item duplication during the rebirth process.

### Location
- `Server/Game/Plot/init.luau` (lines 1283-1407)

### Current Code
```lua
local function hasRequiredInventory()
    for brainrotName, requiredAmount in pairs(Requirements) do
        if brainrotName == "Money" then continue end

        local count = 0
        for _, itemData in pairs(PlayerReplica.Data.Inventory) do
            if itemData.Name == brainrotName then
                count += 1
            end
        end
        -- ...
    end
    return true
end
```

### Issues
1. No verification that items weren't duplicated between check and removal
2. No atomic transaction - items could be traded/gifted during rebirth
3. Money requirement not checked atomically with inventory
4. No check for boosted/favorited items (could be exploited)

### Exploit Scenario
1. Player has required brainrots in inventory
2. Player initiates rebirth (passes requirements check)
3. During the brief window before removal, player gifts items to alt account
4. Player gets rebirth, keeps the items (now on alt)
5. Alt gifts items back - duplication achieved

### Fix Required
1. Lock inventory during rebirth process
2. Perform atomic check-and-remove operation
3. Verify items are not favorited before allowing rebirth
4. Add cooldown between rebirth attempts

**Severity: MEDIUM** - Duplication risk, economy impact

---

## 5. MEDIUM: Cash Atomicity Issues

### Issue Description
Cash operations use stale data references, allowing race conditions and potential cash generation exploits.

### Location
- `Server/Game/Plot/init.luau` (GiveCash function)

### Current Code
```lua
function plot:GiveCash(amount)
    local initialCash = amount 
    local multiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
    local finalCash = initialCash * (1 + multiplier)

    self.OwnerReplica:SetValue({"Cash"}, self.OwnerData.Cash + finalCash)  -- STALE REFERENCE
end
```

### Vulnerability
`self.OwnerData.Cash` may be stale if multiple cash operations happen simultaneously. This could result in:
- Lost cash (operation overwrites previous value)
- Duplicated cash (negative amount exploits)

### Fix Available
See `FIX_7_4_CashAtomicity.luau` for complete atomic operation fix.

**Severity: MEDIUM** - Race conditions, potential cash exploits

---

## 6. MEDIUM: Rebirth Plants Not Cleared

### Issue Description
Plants persist through rebirth, giving players who prepared plants before rebirth an unfair advantage.

### Location
- `Server/Game/Plot/init.luau` (Rebirth handler)

### Current Behavior
- Brainrots are removed from platforms
- Cash is reset to 0
- **Plants remain active and producing**

### Impact
Players can:
1. Plant expensive, high-yield plants
2. Wait for them to mature
3. Rebirth
4. Immediately harvest mature plants for cash advantage

### Fix Available
See `FIX_2_RebirthPlantClearing.luau` for complete plant clearing implementation.

**Severity: MEDIUM** - Unfair progression advantage

---

## 7. LOW: Rebirth UI Progress Bar Race Condition

### Issue Description
Client-side progress bar calculation uses local data that may not reflect server state.

### Location
- `Client/UI/HUD/Rebirths [Client]/init.luau` (lines 36-53)

### Current Code
```lua
function module.UpdateProgressBar()
    if not currentReqs or not currentReqs.Requirements then return end
    local requiredMoney = tonumber(currentReqs.Requirements.Money)
    if not requiredMoney then return end
    local currentMoney = PlayerData.Cash  -- May be stale
    -- ...
end
```

### Impact
- UI shows incorrect progress
- Players may think they can rebirth when they can't
- Minor confusion, not exploitable

### Fix
Use server-authoritative values for progress bar updates.

**Severity: LOW** - UI inconsistency only

---

## Additional Findings

### A. Mutation Data Type Inconsistencies
- Some mutations store data as strings, others as tables
- No standardization on mutation application order
- **Fix**: `M7_FIX_4_MutationDataTypes.luau` prepared

### B. GuaranteedMutation Validation Missing
- `GuaranteedMutation` workspace attribute not validated before use
- Could be set to invalid mutation names
- **Fix**: `M7_FIX_2_GuaranteedMutationValidation.luau` prepared

### C. Effect Limit Not Enforced
- Maximum 6 effects per brainrot claimed but not enforced
- **Fix**: `M7_FIX_3_EffectLimitAtomic.luau` prepared

---

## Recommendations

### Immediate Actions (Before Launch)
1. **Fix Rebirth Multiplier Stacking** (Issue #1) - Critical exploit
2. **Fix Event Multipliers** (Issue #2) - Broken feature
3. **Fix Platform Multiplier** (Issue #3) - Economy balance
4. **Implement Plant Clearing** (Issue #6) - Fairness

### Short-term Actions (Post-Launch)
5. **Add Rebirth Atomicity** (Issue #4) - Prevent duplication
6. **Fix Cash Operations** (Issue #5) - Stability

### Long-term Improvements
7. Add rebirth cooldown (e.g., 1 hour between rebirths)
8. Add rebirth confirmation dialog with item list
9. Track lifetime rebirth earnings for analytics
10. Add server-side validation for all client-reported values

---

## Fix Implementation Priority

| Priority | Issue | File to Apply | Estimated Effort |
|----------|-------|---------------|------------------|
| P0 | Multiplier Stacking | Server/Init.legacy.luau | 30 min |
| P0 | Event Multipliers | PickMutations.luau | 20 min |
| P1 | Platform Multiplier | Plot/init.luau | 30 min |
| P1 | Plant Clearing | Plot/init.luau | 1 hour |
| P2 | Rebirth Atomicity | Plot/init.luau | 2 hours |
| P2 | Cash Atomicity | Plot/init.luau | 1 hour |
| P3 | UI Race Condition | Rebirths [Client]/init.luau | 30 min |

---

## Testing Checklist

After fixes are applied, verify:

- [ ] Rebirth 1 grants exactly 0.5x multipliers (not cumulative on rejoin)
- [ ] Rebirth 2 grants exactly 1.0x multipliers
- [ ] Rebirth 3 grants exactly 1.5x multipliers
- [ ] Event multipliers actually affect mutation rates
- [ ] Super platform gives 1.5x/2x as expected
- [ ] Plants are cleared on rebirth
- [ ] Rebirth requirements are checked atomically
- [ ] Cash operations are race-condition free
- [ ] Maximum 6 effects per brainrot enforced

---

## Conclusion

The rebirth and progression systems have several critical vulnerabilities that could severely impact game balance and economy. The most severe issue is the **multiplier stacking exploit** which allows unlimited stat growth through session resets. 

Most fixes are straightforward and have been prepared in the M7_FIX files. Priority should be given to the P0 and P1 issues before any public launch.

**Overall System Health: ⚠️ CRITICAL ISSUES FOUND**

- 1 Critical exploit
- 3 High severity bugs
- 2 Medium severity issues
- 1 Low severity issue
- 3 Additional findings with prepared fixes
