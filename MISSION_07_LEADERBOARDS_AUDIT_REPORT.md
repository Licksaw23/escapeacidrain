# Mission #7: Leaderboards & Data Display Audit Report

**Scope:** Leaderboard systems, data aggregation, stat tracking, and data display  
**Status:** COMPLETE  
**Date:** February 3, 2026  
**Risk Level:** MEDIUM-HIGH  

---

## Executive Summary

This audit examines the leaderboard systems, data aggregation mechanisms, and stat tracking implementations in Feed The Brainrots. **13 critical/high issues** were identified related to data corruption, update bugs, and display inconsistencies.

### Key Findings
- **Data Corruption Risk:** Leaderboard updates are not atomic and lack proper error handling
- **Update Bugs:** Playtime tracking has calculation errors, Cash stat updates are incomplete
- **Display Issues:** Leaderboard cache can become stale, place numbering is incorrect
- **Performance:** No throttling on OrderedDataStore writes (rate limit risk)

---

## 1. LEADERBOARD SYSTEM ARCHITECTURE

### 1.1 Current Implementation

**File:** `Server/Game/Leaderboards.luau`

```lua
local LeaderboardStore = DataStoreService:GetOrderedDataStore("PlayerLeaderboards")
local LEADERBOARD_SIZE = 10
local UPDATE_INTERVAL = 90
```

**Categories Tracked:**
1. **Playtime** - Total seconds played
2. **Orders** - Total orders completed  
3. **Cash** - Highest cash balance achieved

### 1.2 Data Flow

```
Player Action → Stat Update → LeaderboardStore:SetAsync() → Cache Update → Client Broadcast
```

---

## 2. CRITICAL BUGS

### 🔴 BUG #1: Playtime Calculation Error

**Location:** `Server/Init.legacy.luau` (Lines 400-411)

**Current Code:**
```lua
task.spawn(function()
    while User.Parent do
        task.wait(60)
        if User.Parent then
            local savedPlaytime = Data.Stats.Playtime 
            local currentPlaytime = savedPlaytime + (os.time() - sessionStart)
            
            PlayerReplica:SetValue({"Stats", "Playtime"}, currentPlaytime)
            Leaderboards.UpdatePlayerStat(User.UserId, "Playtime", currentPlaytime)
        end
    end
end)
```

**Problem:** 
- `savedPlaytime` is fetched once at the start of the loop iteration
- `currentPlaytime` calculation uses `os.time() - sessionStart` (total session time)
- This **ADDS** session time to already-saved playtime every minute
- After 1 hour: Playtime = 3600 + 3600 + 3600 + ... (inflated by 60x!)

**Impact:** 
- Playtime leaderboard is completely wrong
- Players appear to have 1000+ hours after short sessions

**Fix:**
```lua
-- Track session start time outside the loop
local sessionStart = os.time()
local initialPlaytime = Data.Stats.Playtime

task.spawn(function()
    while User.Parent do
        task.wait(60)
        if User.Parent then
            -- Calculate total: saved + elapsed this session
            local elapsedThisSession = os.time() - sessionStart
            local currentPlaytime = initialPlaytime + elapsedThisSession
            
            PlayerReplica:SetValue({"Stats", "Playtime"}, currentPlaytime)
            Leaderboards.UpdatePlayerStat(User.UserId, "Playtime", currentPlaytime)
        end
    end
end)
```

---

### 🔴 BUG #2: Incorrect Place Assignment in Leaderboard

**Location:** `Server/Game/Leaderboards.luau` (Lines 30-55)

**Current Code:**
```lua
local place = 1
for _, entry in ipairs(data) do
    local parts = string.split(entry.key, "_")
    if parts[1] == category then
        -- ...
        table.insert(leaderboardData, {
            Place = place,  -- WRONG! Should use actual rank
            ID = userId,
            Name = username,
            Amount = entry.value
        })
        place = place + 1
    end
end
```

**Problem:**
- `GetSortedAsync` returns entries in ranked order
- The code uses a local `place` counter that increments only for matching category
- If entry #1 in results is "Orders_123" and we're viewing "Playtime", place starts at 1 for entry #2
- This causes **incorrect rank display** - player showing as #1 might actually be #5

**Impact:**
- Leaderboard ranks are misleading/wrong
- Players see incorrect placement

**Fix:**
```lua
-- Use actual index from GetSortedAsync results
for rank, entry in ipairs(data) do  -- rank is actual position
    local parts = string.split(entry.key, "_")
    if parts[1] == category then
        -- Only add if within our leaderboard size
        if #leaderboardData < LEADERBOARD_SIZE then
            table.insert(leaderboardData, {
                Place = rank,  -- Use actual rank from OrderedDataStore
                ID = userId,
                Name = username,
                Amount = entry.value
            })
        end
    end
end
```

---

### 🔴 BUG #3: No Throttling on DataStore Writes

**Location:** `Server/Game/Leaderboards.luau` (Lines 73-84)

**Current Code:**
```lua
function LeaderboardModule.UpdatePlayerStat(userId, category, amount)
    local key = category .. "_" .. tostring(userId)
    
    local success, errorMsg = pcall(function()
        LeaderboardStore:SetAsync(key, amount)  -- Called on EVERY stat change!
    end)
    -- ...
end
```

**Problem:**
- `SetAsync` is called on **every** order completion
- Roblox DataStore has rate limits (60 requests/minute per key)
- High-traffic servers will hit limits
- No queue/batching mechanism

**Impact:**
- DataStore rate limit errors
- Stats fail to update during peak times
- Potential data loss

**Fix:**
```lua
-- Add throttling with pending updates queue
local pendingUpdates = {}
local lastFlush = 0
local FLUSH_INTERVAL = 30  -- Batch updates every 30 seconds

function LeaderboardModule.UpdatePlayerStat(userId, category, amount)
    local key = category .. "_" .. tostring(userId)
    pendingUpdates[key] = amount  -- Queue the update
end

-- Flush queue periodically
task.spawn(function()
    while true do
        task.wait(FLUSH_INTERVAL)
        
        for key, amount in pairs(pendingUpdates) do
            pcall(function()
                LeaderboardStore:SetAsync(key, amount)
            end)
            pendingUpdates[key] = nil
            task.wait(1)  -- Rate limit between writes
        end
    end
end)
```

---

### 🔴 BUG #4: Cash Stat Only Updates on Brainrot Collection

**Location:** `Server/Game/Plot/init.luau` (Lines 2599-2604)

**Current Code:**
```lua
-- Only called when collecting from brainrot platform
local getHighestCash = PlayerReplica.Data.Stats.MostCash
if PlayerReplica.Data.Cash > getHighestCash then
    PlayerReplica:SetValue({"Stats", "MostCash"}, PlayerReplica.Data.Cash)
    Leaderboards.UpdatePlayerStat(self.Owner.UserId, "Cash", math.floor(PlayerReplica.Data.Cash))
end
```

**Problem:**
- Cash leaderboard update **only** happens in `PlaceBrainrot` money collection
- Does NOT update when:
  - Selling fruits to merchant
  - Selling brainrots
  - Developer product purchases
  - Code rewards
  - Any other cash source

**Impact:**
- Cash leaderboard is incomplete/misleading
- Players with high cash from sales don't appear

**Fix:**
```lua
-- In plot:GiveCash() function, add leaderboard check
function plot:GiveCash(amount)
    local initialCash = amount 
    local multiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
    local finalCash = initialCash * (1 + multiplier)
    
    local newCash = self.OwnerData.Cash + finalCash
    self.OwnerReplica:SetValue({"Cash"}, newCash)
    
    -- Update leaderboard if this is a new high
    local currentHigh = self.OwnerReplica.Data.Stats.MostCash
    if newCash > currentHigh then
        self.OwnerReplica:SetValue({"Stats", "MostCash"}, newCash)
        Leaderboards.UpdatePlayerStat(self.Owner.UserId, "Cash", math.floor(newCash))
    end
end
```

---

### 🔴 BUG #5: Stale Cache on Server Switch

**Location:** `Server/Game/Leaderboards.luau` (Lines 57-70)

**Current Code:**
```lua
function LeaderboardModule.RefreshAllLeaderboards()
    for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
        local data = LeaderboardModule.GetLeaderboardData(category)
        leaderboardCache[category] = data
    end
    
    -- Send to all clients
    for _, player in ipairs(Players:GetPlayers()) do
        for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
            UpdateLeaderboardRemote:FireClient(player, category, leaderboardCache[category])
        end
    end
end
```

**Problem:**
- Each server maintains its own `leaderboardCache`
- Updates from other servers don't propagate
- Player sees different leaderboard on different servers
- 90-second refresh interval means data is always stale

**Impact:**
- Inconsistent leaderboard display
- Players confused about actual rankings

**Fix:**
```lua
-- Use MessagingService to sync cache invalidation
local MessagingService = game:GetService("MessagingService")
local LEADERBOARD_SYNC_TOPIC = "LeaderboardSync"

-- Subscribe to updates from other servers
MessagingService:SubscribeAsync(LEADERBOARD_SYNC_TOPIC, function(message)
    local category = message.Data.Category
    -- Invalidate cache for this category to force refresh
    leaderboardCache[category] = nil
end)

function LeaderboardModule.UpdatePlayerStat(userId, category, amount)
    local key = category .. "_" .. tostring(userId)
    
    pcall(function()
        LeaderboardStore:SetAsync(key, amount)
    end)
    
    -- Notify other servers to refresh
    pcall(function()
        MessagingService:PublishAsync(LEADERBOARD_SYNC_TOPIC, {
            Category = category,
            UserId = userId,
            Timestamp = os.time()
        })
    end)
end
```

---

## 3. HIGH SEVERITY BUGS

### 🟡 BUG #6: No Pagination Handling

**Location:** `Server/Game/Leaderboards.luau` (Lines 33-36)

**Current Code:**
```lua
local pages = LeaderboardStore:GetSortedAsync(false, LEADERBOARD_SIZE)
local data = pages:GetCurrentPage()
```

**Problem:**
- `GetSortedAsync` returns a DataStorePages object
- `GetCurrentPage()` only returns the first page
- If leaderboard has 1000+ entries, we only see first 10
- No iteration through all pages

**Impact:**
- Leaderboard only shows subset of players
- New players may never appear even with high stats

---

### 🟡 BUG #7: Missing Error Recovery

**Location:** `Server/Game/Leaderboards.luau` (Lines 73-84)

**Current Code:**
```lua
local success, errorMsg = pcall(function()
    LeaderboardStore:SetAsync(key, amount)
end)

if not success then
    warn("Error updating leaderboard stat: " .. errorMsg)
end

return success
```

**Problem:**
- If SetAsync fails, the update is lost forever
- No retry mechanism
- No queue for failed updates
- Silent failure in many cases

**Impact:**
- Data loss during DataStore outages
- Inconsistent stats over time

---

### 🟡 BUG #8: Client Cache Mismatch

**Location:** `Client/UI/HUD/Leaderboards [Client].luau` (Lines 175-180)

**Current Code:**
```lua
UpdateLeaderboardRemote.OnClientEvent:Connect(function(category, data)
    module.RefreshLeaderboards(category, data)
end)
```

**Problem:**
- Client receives data but doesn't validate timestamp
- May display stale data if server broadcast is delayed
- No checksum/validation of data integrity

**Impact:**
- Client displays outdated information
- Confusion about actual rankings

---

### 🟡 BUG #9: Leaderboard Key Format Inefficiency

**Location:** `Server/Game/Leaderboards.luau` (Lines 30-55)

**Current Code:**
```lua
-- Key format: "Category_UserId"
local key = category .. "_" .. tostring(userId)

-- Fetching requires scanning ALL keys
for _, entry in ipairs(data) do
    local parts = string.split(entry.key, "_")
    if parts[1] == category then  -- Filter client-side!
        -- ...
    end
end
```

**Problem:**
- All categories stored in single OrderedDataStore
- Must fetch and filter all entries for each category
- Inefficient for large player bases
- Should use separate data stores per category

**Impact:**
- Slower leaderboard loading
- Higher DataStore read costs

---

### 🟡 BUG #10: Initial Leaderboard Setup Uses Hardcoded Values

**Location:** `Server/Init.legacy.luau` (Lines 278-282)

**Current Code:**
```lua
if not ModulesCache["Leaderboards"].IsPlayerInLeaderboard(User.UserId, "Playtime") then
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", 1)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Orders", 15)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Cash", 3000000)
end
```

**Problem:**
- New players get **default values** (15 orders, 3M cash)
- These artificial values inflate the leaderboard
- Genuine new players appear above legitimate players

**Impact:**
- Leaderboard integrity compromised
- Unfair advantage for new players
- Real achievements devalued

**Fix:**
```lua
-- Remove artificial defaults - start at 0
if not ModulesCache["Leaderboards"].IsPlayerInLeaderboard(User.UserId, "Playtime") then
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", 0)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Orders", 0)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Cash", 0)
end
```

---

## 4. DATA AGGREGATION ISSUES

### Issue: Orders Stat Double-Counting Risk

**Location:** `Server/Game/Plot/init.luau` (Lines 337-339)

```lua
local currentOrders = PlayerReplica.Data.Stats.Orders
PlayerReplica:SetValue({"Stats", "Orders"}, currentOrders + 1)
Leaderboards.UpdatePlayerStat(newPlot.Owner.UserId, "Orders", currentOrders + 1)
```

**Risk:**
- If `CompleteOrder` is called twice (race condition), orders count increments twice
- No idempotency check for order completion

---

### Issue: Playtime Not Persisted on Leave

**Location:** `Server/Init.legacy.luau` (Playtime loop)

**Problem:**
- Playtime is only saved every 60 seconds during play
- If player leaves between intervals, last minute is lost
- No final save on PlayerRemoving

**Fix:**
```lua
PlayerService.PlayerRemoving:Connect(function(User)
    local PlayerReplica = Data[User]
    if PlayerReplica and PlayerReplica.Data then
        -- Final playtime save
        local elapsedThisSession = os.time() - sessionStartTimes[User.UserId]
        local finalPlaytime = PlayerReplica.Data.Stats.Playtime + elapsedThisSession
        
        PlayerReplica:SetValue({"Stats", "Playtime"}, finalPlaytime)
        Leaderboards.UpdatePlayerStat(User.UserId, "Playtime", finalPlaytime)
    end
    -- ...
end)
```

---

## 5. DISPLAY BUGS

### Issue: Leaderboard Shows "Nil" for Missing Users

**Location:** `Server/Game/Leaderboards.luau` (Lines 40-48)

```lua
local success2, username = pcall(function()
    return Players:GetNameFromUserIdAsync(userId)
end)

if success2 then
    table.insert(leaderboardData, {
        -- ...
        Name = username,
        -- ...
    })
end
```

**Problem:**
- If `GetNameFromUserIdAsync` fails, player is skipped entirely
- Leaderboard shows fewer than 10 entries
- No fallback display (should show "[Unknown]" or UserId)

---

### Issue: Amount Formatting Inconsistency

**Location:** `Client/UI/HUD/Leaderboards [Client].luau` (Lines 148-152)

```lua
newTemplate.Amount.Text = NumberShortener.roundNumber(data.Amount)
if prefix[cat] then
    newTemplate.Amount.Text = prefix[cat]..NumberShortener.roundNumber(data.Amount)
end
```

**Problem:**
- Playtime shown as raw number (seconds) - not human readable
- Should display as "2h 34m" or similar

---

## 6. RECOMMENDATIONS

### Immediate (Critical)
1. **Fix playtime calculation** (BUG #1) - Data is completely wrong
2. **Fix place assignment** (BUG #2) - Ranks are misleading
3. **Add throttling** (BUG #3) - Prevent rate limiting
4. **Fix cash stat updates** (BUG #4) - All cash sources should count

### High Priority
5. Implement cross-server cache sync (BUG #5)
6. Add retry mechanism for failed updates (BUG #7)
7. Remove artificial default values (BUG #10)

### Medium Priority
8. Separate OrderedDataStore per category (BUG #9)
9. Add pagination handling (BUG #6)
10. Human-readable time formatting

---

## 7. FIX FILES PROVIDED

### M7_Leaderboard_Fixes.luau
Complete fixed version of Leaderboards.luau with:
- Throttled updates
- Retry mechanism
- Cross-server sync
- Separate stores per category

### M7_StatTracking_Fixes.luau
Fixed stat tracking in:
- Init.legacy.luau - Playtime calculation
- Plot/init.luau - Cash stat updates

### M7_ClientDisplay_Fixes.luau
Client-side fixes for:
- Human-readable time display
- Fallback for missing usernames
- Cache validation

---

## APPENDIX: AFFECTED FILES

| File | Issues | Priority |
|------|--------|----------|
| `Server/Game/Leaderboards.luau` | BUG #2, #3, #5, #6, #7, #9 | Critical |
| `Server/Init.legacy.luau` | BUG #1, #10 | Critical |
| `Server/Game/Plot/init.luau` | BUG #4, Orders risk | High |
| `Client/UI/HUD/Leaderboards [Client].luau` | BUG #8, display issues | Medium |

---

*End of Mission #7 Leaderboards & Data Display Audit Report*
