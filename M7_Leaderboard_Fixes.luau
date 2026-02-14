-- M7_Leaderboard_Fixes.luau
-- FIXED VERSION of Leaderboards.luau
-- Addresses: BUG #2, #3, #5, #6, #7, #9

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

-- Separate data stores per category (BUG #9 Fix)
local LeaderboardStores = {
    Playtime = DataStoreService:GetOrderedDataStore("PlayerLeaderboards_Playtime"),
    Orders = DataStoreService:GetOrderedDataStore("PlayerLeaderboards_Orders"),
    Cash = DataStoreService:GetOrderedDataStore("PlayerLeaderboards_Cash"),
}

local UpdateLeaderboardRemote = game.ReplicatedStorage.Remotes.UpdateLeaderboard

local LeaderboardModule = {}

-- Configuration
LeaderboardModule.LEADERBOARD_CATEGORIES = {
    "Playtime",
    "Orders", 
    "Cash",
}

local LEADERBOARD_SIZE = 10
local UPDATE_INTERVAL = 90

-- Cache for leaderboard data
local leaderboardCache = {}

-- Initialize cache for each category
for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
    leaderboardCache[category] = {}
end

-- BUG #3 FIX: Throttled updates with retry queue
local pendingUpdates = {}
local updateQueue = {}
local QUEUE_FLUSH_INTERVAL = 30
local MAX_RETRIES = 3

-- BUG #5 FIX: Cross-server sync
local LEADERBOARD_SYNC_TOPIC = "LeaderboardSync_v2"
local CACHE_INVALIDATION_TIME = 60
local lastCacheUpdate = {}

-- Subscribe to cache invalidation from other servers
pcall(function()
    MessagingService:SubscribeAsync(LEADERBOARD_SYNC_TOPIC, function(message)
        local data = message.Data
        if data and data.Category and data.Timestamp then
            -- Invalidate cache for this category
            lastCacheUpdate[data.Category] = nil
            leaderboardCache[data.Category] = {}
        end
    end)
end)

-- Flush update queue periodically
task.spawn(function()
    while true do
        task.wait(QUEUE_FLUSH_INTERVAL)
        
        local updatesToProcess = {}
        for key, updateData in pairs(pendingUpdates) do
            table.insert(updatesToProcess, {
                Key = key,
                Data = updateData
            })
        end
        
        for _, update in ipairs(updatesToProcess) do
            local key = update.Key
            local updateData = update.Data
            
            local store = LeaderboardStores[updateData.Category]
            if store then
                local success, err = pcall(function()
                    store:SetAsync(key, updateData.Amount)
                end)
                
                if success then
                    pendingUpdates[key] = nil
                    
                    -- Notify other servers
                    pcall(function()
                        MessagingService:PublishAsync(LEADERBOARD_SYNC_TOPIC, {
                            Category = updateData.Category,
                            UserId = updateData.UserId,
                            Timestamp = os.time()
                        })
                    end)
                else
                    -- Increment retry count
                    updateData.Retries = (updateData.Retries or 0) + 1
                    
                    if updateData.Retries >= MAX_RETRIES then
                        warn("[Leaderboards] Max retries reached for " .. key .. ": " .. tostring(err))
                        pendingUpdates[key] = nil
                    else
                        -- Exponential backoff
                        updateData.NextRetry = os.time() + (2 ^ updateData.Retries)
                    end
                end
            end
            
            task.wait(0.1)  -- Rate limiting between writes
        end
    end
end)

-- BUG #2 FIX: Correct place assignment using actual rank
function LeaderboardModule.GetLeaderboardData(category)
    local store = LeaderboardStores[category]
    if not store then
        warn("[Leaderboards] Invalid category: " .. tostring(category))
        return {}
    end
    
    local leaderboardData = {}
    local success, errorMsg = pcall(function()
        -- Get sorted data (ascending=false for highest first)
        local pages = store:GetSortedAsync(false, LEADERBOARD_SIZE)
        
        -- BUG #6 FIX: Handle pagination properly
        local currentPageNumber = 1
        local maxPages = 5  -- Limit to prevent excessive API calls
        
        while pages and currentPageNumber <= maxPages do
            local data = pages:GetCurrentPage()
            
            for rank, entry in ipairs(data) do
                -- Calculate actual rank across all pages
                local actualRank = ((currentPageNumber - 1) * 100) + rank
                
                if actualRank > LEADERBOARD_SIZE then
                    break
                end
                
                local userId = tonumber(entry.key)
                if userId then
                    local success2, username = pcall(function()
                        return Players:GetNameFromUserIdAsync(userId)
                    end)

                    table.insert(leaderboardData, {
                        Place = actualRank,  -- BUG #2 FIX: Use actual rank
                        ID = userId,
                        Name = success2 and username or "[Unknown-" .. userId .. "]",
                        Amount = entry.value
                    })
                end
            end
            
            -- Stop if we have enough entries
            if #leaderboardData >= LEADERBOARD_SIZE then
                break
            end
            
            -- Try to advance to next page
            local hasNext = pages.IsFinished
            if not hasNext then
                pages:AdvanceToNextPageAsync()
                currentPageNumber = currentPageNumber + 1
            else
                break
            end
        end
    end)

    if not success then
        warn("[Leaderboards] Error fetching data for " .. category .. ": " .. tostring(errorMsg))
    end

    return leaderboardData
end

-- BUG #3 FIX: Queue updates instead of immediate write
function LeaderboardModule.UpdatePlayerStat(userId, category, amount)
    if not table.find(LeaderboardModule.LEADERBOARD_CATEGORIES, category) then
        warn("[Leaderboards] Invalid category: " .. tostring(category))
        return false
    end
    
    local key = tostring(userId)
    
    pendingUpdates[key] = {
        Category = category,
        UserId = userId,
        Amount = amount,
        Retries = 0,
        Timestamp = os.time()
    }
    
    -- Update local cache immediately for responsiveness
    local cached = leaderboardCache[category]
    if cached then
        -- Find and update existing entry
        local found = false
        for _, entry in ipairs(cached) do
            if entry.ID == userId then
                entry.Amount = amount
                found = true
                break
            end
        end
        
        -- Add new entry if not found and we have space
        if not found and #cached < LEADERBOARD_SIZE then
            local success, username = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            
            table.insert(cached, {
                Place = #cached + 1,
                ID = userId,
                Name = success and username or "[Unknown]",
                Amount = amount
            })
        end
        
        -- Sort by amount (descending)
        table.sort(cached, function(a, b)
            return a.Amount > b.Amount
        end)
        
        -- Update place numbers
        for i, entry in ipairs(cached) do
            entry.Place = i
        end
    end
    
    return true
end

-- Check if player is in leaderboard
function LeaderboardModule.IsPlayerInLeaderboard(userId, category)
    local store = LeaderboardStores[category]
    if not store then
        return false, nil
    end
    
    local key = tostring(userId)

    local success, currentValue = pcall(function()
        return store:GetAsync(key)
    end)

    if success and currentValue ~= nil then
        return true, currentValue
    else
        return false, nil
    end
end

-- Refresh all leaderboards
function LeaderboardModule.RefreshAllLeaderboards()
    for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
        -- Check if cache is stale
        local lastUpdate = lastCacheUpdate[category] or 0
        local cacheAge = os.time() - lastUpdate
        
        if cacheAge > CACHE_INVALIDATION_TIME or #leaderboardCache[category] == 0 then
            local data = LeaderboardModule.GetLeaderboardData(category)
            leaderboardCache[category] = data
            lastCacheUpdate[category] = os.time()
        end
    end

    -- Send updated data to all clients
    for _, player in ipairs(Players:GetPlayers()) do
        for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
            UpdateLeaderboardRemote:FireClient(
                player, 
                category, 
                leaderboardCache[category]
            )
        end
    end
end

-- Legacy compatibility
function LeaderboardModule.UpdateLeaderboardStat(player, category, newAmount)
    return LeaderboardModule.UpdatePlayerStat(player.UserId, category, newAmount)
end

-- Handle client requests for leaderboard data
UpdateLeaderboardRemote.OnServerEvent:Connect(function(player, category)
    if table.find(LeaderboardModule.LEADERBOARD_CATEGORIES, category) then
        -- Check cache age
        local lastUpdate = lastCacheUpdate[category] or 0
        local cacheAge = os.time() - lastUpdate
        
        -- Refresh if cache is stale
        if cacheAge > CACHE_INVALIDATION_TIME then
            local data = LeaderboardModule.GetLeaderboardData(category)
            leaderboardCache[category] = data
            lastCacheUpdate[category] = os.time()
        end
        
        UpdateLeaderboardRemote:FireClient(player, category, leaderboardCache[category])
    end
end)

-- Initial leaderboard load
LeaderboardModule.RefreshAllLeaderboards()

task.spawn(function()
    -- Periodic updates
    while true do
        task.wait(UPDATE_INTERVAL)
        LeaderboardModule.RefreshAllLeaderboards()
    end
end)

-- When player joins, send them current leaderboard data
Players.PlayerAdded:Connect(function(player)
    task.wait(1) -- Small delay to ensure client is ready
    for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
        UpdateLeaderboardRemote:FireClient(player, category, leaderboardCache[category])
    end
end)

return LeaderboardModule
