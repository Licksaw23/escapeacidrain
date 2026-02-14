# Mission #7 - Leaderboards & Data Display Audit

**Status:** COMPLETE  
**Date:** February 3, 2026  
**Auditor:** Subagent  

---

## Summary

Audited the leaderboard systems, data aggregation, and stat tracking in Feed The Brainrots. Found **13 bugs** including **4 critical** issues causing data corruption and incorrect displays.

---

## Bugs Found

### Critical (4)
1. **Playtime Calculation Error** - Playtime inflates by 60x due to incorrect cumulative calculation
2. **Incorrect Place Assignment** - Leaderboard ranks are calculated locally, not from actual OrderedDataStore position
3. **No Throttling on DataStore** - Rate limit risk from unthrottled SetAsync calls
4. **Cash Stat Incomplete** - Only updates on brainrot collection, misses sales/rewards

### High (3)
5. **Stale Cache on Server Switch** - Each server maintains separate cache, causing inconsistent displays
6. **No Pagination Handling** - Only fetches first page of results
7. **Missing Error Recovery** - Failed updates are lost forever

### Medium (6)
8. **Client Cache Mismatch** - No validation of data freshness
9. **Inefficient Key Format** - All categories in single store requires filtering
10. **Artificial Default Values** - New players get 15 orders / 3M cash artificially
11. **Orders Double-Count Risk** - No idempotency on order completion
12. **Playtime Not Saved on Leave** - Last minute of playtime lost
13. **Time Display Not Human-Readable** - Shows raw seconds instead of "2h 34m"

---

## Files Created

| File | Purpose |
|------|---------|
| `MISSION_07_LEADERBOARDS_AUDIT_REPORT.md` | Full audit report with code analysis |
| `M7_Leaderboard_Fixes.luau` | Fixed Leaderboards.luau with throttling, retry, cross-server sync |
| `M7_StatTracking_Fixes.luau` | Fixes for playtime calculation, cash updates, init defaults |
| `M7_ClientDisplay_Fixes.luau` | Client-side fixes for time formatting, data validation |

---

## Quick Fix Guide

### Immediate (Apply Today)

1. **Fix Playtime Calculation** (Init.legacy.luau)
   ```lua
   -- Change from:
   local currentPlaytime = savedPlaytime + (os.time() - sessionStart)
   -- To:
   local currentPlaytime = initialPlaytime + (os.time() - sessionStart)
   ```

2. **Fix Cash Stat Updates** (Plot/init.luau)
   - Add leaderboard update check in `GiveCash()` function

3. **Remove Artificial Defaults** (Init.legacy.luau)
   - Change initial Orders from 15 to 0
   - Change initial Cash from 3000000 to 0

### This Week
- Apply M7_Leaderboard_Fixes.luau for throttling and cross-server sync
- Apply M7_ClientDisplay_Fixes.luau for human-readable time display

---

## Impact Assessment

| Bug | Player Impact | Data Integrity |
|-----|--------------|----------------|
| Playtime Calculation | High - Wrong stats | Corrupted |
| Incorrect Place | High - Wrong ranks | Misleading |
| No Throttling | Medium - Failed updates | At Risk |
| Cash Stat Incomplete | Medium - Missing from LB | Incomplete |
| Stale Cache | Low-Medium - Inconsistent | Inconsistent |

---

## Testing Recommendations

1. Verify playtime tracks correctly over multiple sessions
2. Confirm cash leaderboard updates on all cash sources
3. Test leaderboard consistency across server switches
4. Validate rate limiting doesn't drop updates during peak load

---

*Mission Complete*
