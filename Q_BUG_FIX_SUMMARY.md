# FeedTheBrainrots - QA Bug Fix Summary

## Overview

This document summarizes the edge case analysis and bug fixes prepared by the Joint Chiefs of Staff - Quality Assurance team.

## Deliverables

1. **Q_EDGE_CASE_ANALYSIS.md** - Comprehensive edge case analysis document
2. **FIX_1_OrderPersistence.luau** - Fix for order loss on server shutdown
3. **FIX_2_RebirthPlantClearing.luau** - Fix for plants persisting through rebirth
4. **FIX_3_HarvestAtomicity.luau** - Fix for race conditions in harvesting
5. **FIX_4_MutationDeduplication.luau** - Fix for duplicate mutations
6. **FIX_5_SessionEndHandling.luau** - Fix for unnecessary player kicks
7. **FIX_6_ActivePlantsCleanup.luau** - Fix for memory leaks in plant tracking
8. **FIX_7_DebugCleanup.luau** - List of debug statements to remove

---

## Critical Issues (Immediate Action Required)

### 1. Order Persistence [CRITICAL]
**File:** `FIX_1_OrderPersistence.luau`

**Problem:** Active orders are not persisted to player data. When a player leaves or server shuts down, all active orders are lost but any fruits given to fulfill them were consumed.

**Impact:** Players lose progress and resources unfairly.

**Fix:**
- Add `ActiveOrders` to player data structure
- Save orders to data on player leave/shutdown
- Restore orders from data on player join
- Restart order timers appropriately

**Implementation:**
1. Update `Server/Data/StarterData.luau` to include `ActiveOrders = {}`
2. Add `plot:SaveOrdersToData()` and `plot:RestoreOrdersFromData()` functions
3. Call save in `plot:Terminate()` and restore during initialization

---

### 2. Rebirth Plant Clearing [CRITICAL]
**File:** `FIX_2_RebirthPlantClearing.luau`

**Problem:** When players rebirth, their plants are not cleared. Players keep high-value plants after rebirth, giving permanent unfair advantage.

**Impact:** Game economy balance broken, rebirth doesn't provide fresh start.

**Fix:**
- Clear all plants from `Plot` data on rebirth
- Remove plants from `ActivePlants` tracking table
- Destroy all plant models in player's plot folder
- Optionally compensate player for lost plants

**Implementation:**
1. Add `plot:ClearAllPlants()` function
2. Call it at the start of rebirth handler before clearing brainrots
3. Also clear `PlotGears` if desired

---

## Medium Priority Issues

### 3. Harvest Atomicity [MEDIUM]
**File:** `FIX_3_HarvestAtomicity.luau`

**Problem:** Race condition allows double-harvesting if two players click simultaneously or rapid clicks occur.

**Impact:** Players can duplicate items.

**Fix:**
- Add `HarvestingLocks` table to track in-progress harvests
- Set lock before processing harvest
- Check lock at start of harvest callback
- Clear lock after harvest completes or fails
- Disable proximity prompt immediately on click

**Implementation:**
1. Add `Utility.HarvestingLocks = {}`
2. Modify `SetupFruit` to use locks
3. Add periodic cleanup for stale locks

---

### 4. Mutation Deduplication [MEDIUM]
**File:** `FIX_4_MutationDeduplication.luau`

**Problem:** Same mutation can be applied multiple times to the same fruit/plant.

**Impact:** Visual glitches, potentially exploitable stat stacking.

**Fix:**
- Add `AddUniqueMutation()` helper function
- Add `DeduplicateMutations()` validation function
- Apply deduplication when loading existing fruit data
- Apply deduplication when adding new mutations

**Implementation:**
1. Add helper functions to `ServerUtility.luau`
2. Modify mutation application in `SetupFruit`
3. Add data migration for existing duplicates

---

### 5. Session End Handling [MEDIUM]
**File:** `FIX_5_SessionEndHandling.luau`

**Problem:** Players are kicked when session ends for any reason, including normal server operations.

**Impact:** Unnecessary player disruption, poor user experience.

**Fix:**
- Check session end reason before kicking
- Only kick for actual problems (steal, release, unknown)
- Don't kick for normal shutdown ("Close")
- Add graceful shutdown handling with `game:BindToClose()`
- Add data validation on load

**Implementation:**
1. Modify `Profile.OnSessionEnd` handler in `Data/init.legacy.luau`
2. Add `game:BindToClose()` for graceful shutdown
3. Add `validatePlayerData()` function

---

## Low Priority Issues

### 6. ActivePlants Cleanup [LOW]
**File:** `FIX_6_ActivePlantsCleanup.luau`

**Problem:** `ActivePlants` entries aren't cleaned up immediately when player leaves, causing minor memory leak.

**Impact:** Memory grows over long server uptime; cleaned up lazily but not immediately.

**Fix:**
- Add `plot:CleanupActivePlants()` function
- Call it in `plot:Terminate()`
- Add periodic cleanup task for orphaned entries

---

### 7. Debug Statement Cleanup [LOW]
**File:** `FIX_7_DebugCleanup.luau`

**Problem:** Multiple debug `print()` and `warn()` statements clutter output logs.

**Impact:** Makes log analysis harder; unprofessional in production.

**Fix:**
- Remove or convert debug statements
- Consider implementing a proper debug system with categories

**Statements to Remove:**
- `warn(' im giving you DIAMOND PLATFORM!!!')`
- `print(getCurrentOrder)`
- `print(calculatedMPS)`
- `print('aww mane')`
- `warn('giving: '..totalMult)`
- Plant stage warnings (or convert to debug mode)

---

## Implementation Priority

### Phase 1 (Immediate - Before Next Release)
1. FIX_1_OrderPersistence - Critical data loss issue
2. FIX_2_RebirthPlantClearing - Critical economy exploit
3. FIX_3_HarvestAtomicity - Duplication exploit

### Phase 2 (Next Sprint)
4. FIX_5_SessionEndHandling - User experience improvement
5. FIX_4_MutationDeduplication - Data integrity

### Phase 3 (Maintenance)
6. FIX_6_ActivePlantsCleanup - Performance optimization
7. FIX_7_DebugCleanup - Code quality

---

## Testing Recommendations

For each fix, test the following scenarios:

### Order Persistence
- [ ] Start order, leave, rejoin - order should persist
- [ ] Start order, server shutdown simulation, rejoin - order should persist
- [ ] Complete order normally - should work as before
- [ ] Let order timeout - should properly clean up

### Rebirth Plant Clearing
- [ ] Plant seeds, rebirth - all plants should be gone
- [ ] Verify no plants in data after rebirth
- [ ] Verify no plant models remain in workspace
- [ ] Verify compensation is given (if implemented)

### Harvest Atomicity
- [ ] Rapid click harvesting - should only harvest once
- [ ] Two players clicking same fruit - should only harvest once
- [ ] Normal harvesting - should work as before

### Mutation Deduplication
- [ ] Load fruit with duplicate mutations - should deduplicate
- [ ] Apply same mutation twice - should only apply once
- [ ] Normal mutation application - should work as before

### Session End Handling
- [ ] Normal leave - should not kick
- [ ] Server shutdown - should save data gracefully
- [ ] Session steal simulation - should kick appropriately

---

## CIA/FBI Refactor Considerations

The identified bugs suggest these architectural improvements for the refactor:

1. **State Management**: Implement proper state machines for all game objects (orders, plants, harvests)

2. **Transaction System**: All operations that modify multiple data points should be atomic

3. **Data Layer**: 
   - Centralize persistence logic
   - Ensure ALL game state is persistable
   - Implement data versioning for migrations

4. **Event System**:
   - Use proper event sourcing for order lifecycle
   - Ensure events are processed exactly once

5. **Validation Layer**:
   - All operations should validate permissions at entry
   - Defense in depth - validate at multiple layers

---

*Analysis completed: 2026-02-02*
*Analyst: Joint Chiefs of Staff - Quality Assurance*
