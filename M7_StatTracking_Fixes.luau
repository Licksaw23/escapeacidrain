-- M7_StatTracking_Fixes.luau
-- FIXED stat tracking code for Init.legacy.luau and Plot/init.luau

--[[
    INSTRUCTIONS:
    
    1. In Server/Init.legacy.luau, replace the Playtime Handler section (lines 400-411)
       with the code below marked [PLAYTIME_FIX]
       
    2. In Server/Game/Plot/init.luau, replace the GiveCash function (around line 1650)
       with the code below marked [GIVECASH_FIX]
       
    3. In Server/Game/Plot/init.luau, replace the initial leaderboard setup (around line 278)
       with the code below marked [INIT_FIX]
]]

-- ============================================================
-- [PLAYTIME_FIX] - Replace Playtime Handler in Init.legacy.luau
-- ============================================================
--[[
    ADD AT TOP OF HandlePlayer function:
    local sessionStartTimes = {}  -- Add this outside HandlePlayer (module level)
]]

-- CORRECTED PLAYTIME TRACKING:
--[[
task.spawn(function()
    sessionStartTimes[User.UserId] = os.time()  -- Track when session started
    local initialPlaytime = Data.Stats.Playtime or 0  -- Save initial value once
    
    while User.Parent do
        task.wait(60)
        if User.Parent then
            -- Calculate correctly: initial + elapsed this session
            local elapsedThisSession = os.time() - sessionStartTimes[User.UserId]
            local currentPlaytime = initialPlaytime + elapsedThisSession
            
            pcall(function()
                PlayerReplica:SetValue({"Stats", "Playtime"}, currentPlaytime)
                ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", currentPlaytime)
            end)
        end
    end
end)
]]

-- ALSO ADD TO PlayerRemoving (for final save):
--[[
PlayerService.PlayerRemoving:Connect(function(User)
    local PlayerReplica = Data[User]
    if PlayerReplica and PlayerReplica.Data and sessionStartTimes[User.UserId] then
        -- Final playtime save
        local initialPlaytime = PlayerReplica.Data.Stats.Playtime or 0
        local elapsedThisSession = os.time() - sessionStartTimes[User.UserId]
        local finalPlaytime = initialPlaytime + elapsedThisSession
        
        PlayerReplica:SetValue({"Stats", "Playtime"}, finalPlaytime)
        ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", finalPlaytime)
        
        sessionStartTimes[User.UserId] = nil  -- Clean up
    end
    -- ... rest of existing code
end)
]]

-- ============================================================
-- [GIVECASH_FIX] - Replace GiveCash function in Plot/init.luau
-- ============================================================

-- CORRECTED GIVECASH WITH LEADERBOARD UPDATE:
--[[
function plot:GiveCash(amount)
    -- Always read fresh from replica (fix stale data bug)
    local currentCash = self.OwnerReplica.Data.Cash or 0
    
    local multiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
    local finalCash = amount * (1 + multiplier)
    local newCash = currentCash + finalCash
    
    self.OwnerReplica:SetValue({"Cash"}, newCash)
    
    -- Update Cash leaderboard if this is a new high (BUG #4 FIX)
    local currentHigh = self.OwnerReplica.Data.Stats.MostCash or 0
    if newCash > currentHigh then
        self.OwnerReplica:SetValue({"Stats", "MostCash"}, newCash)
        Leaderboards.UpdatePlayerStat(self.Owner.UserId, "Cash", math.floor(newCash))
    end
end
]]

-- ============================================================
-- [INIT_FIX] - Replace initial leaderboard setup in Init.legacy.luau
-- ============================================================

-- CORRECTED INITIAL SETUP (remove artificial defaults):
--[[
if not ModulesCache["Leaderboards"].IsPlayerInLeaderboard(User.UserId, "Playtime") then
    -- BUG #10 FIX: Start at 0, not artificial values
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", 0)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Orders", 0)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Cash", 0)
end
]]

-- ============================================================
-- [ORDERS_FIX] - Add idempotency check for order completion
-- ============================================================

-- In Plot/init.luau, modify CompleteOrder function:
--[[
newPlot.Functions["CompleteOrder"] = function(number, passChecks)
    local getCurrentOrder = newPlot.CurrentOrder[number]
    
    if not getCurrentOrder or getCurrentOrder.Claiming then
        return
    end
    
    -- BUG FIX: Add idempotency check
    if getCurrentOrder.AlreadyCounted then
        return  -- Prevent double-counting
    end
    getCurrentOrder.AlreadyCounted = true
    
    getCurrentOrder.Claiming = true
    
    -- ... rest of existing code ...
    
    -- Update orders stat with idempotency
    local currentOrders = PlayerReplica.Data.Stats.Orders or 0
    PlayerReplica:SetValue({"Stats", "Orders"}, currentOrders + 1)
    Leaderboards.UpdatePlayerStat(newPlot.Owner.UserId, "Orders", currentOrders + 1)
    
    -- ... rest of existing code ...
end
]]

-- ============================================================
-- COMPLETE REPLACEMENT CODE FOR Init.legacy.luau
-- ============================================================

-- Add at module level (top of file after requires):
local sessionStartTimes = {}

-- REPLACE HandlePlayer's Playtime section with:
--[[
    sessionStartTimes[User.UserId] = os.time()
    local initialPlaytime = Data.Stats.Playtime or 0
    
    task.spawn(function()
        while User.Parent do
            task.wait(60)
            if User.Parent then
                local elapsedThisSession = os.time() - sessionStartTimes[User.UserId]
                local currentPlaytime = initialPlaytime + elapsedThisSession
                
                pcall(function()
                    PlayerReplica:SetValue({"Stats", "Playtime"}, currentPlaytime)
                    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", currentPlaytime)
                end)
            end
        end
    end)
]]

-- REPLACE PlayerRemoving with:
--[[
PlayerService.PlayerRemoving:Connect(function(User)
    local PlayerReplica = Data[User]
    
    -- Final playtime save
    if PlayerReplica and PlayerReplica.Data and sessionStartTimes[User.UserId] then
        local initialPlaytime = PlayerReplica.Data.Stats.Playtime or 0
        local elapsedThisSession = os.time() - sessionStartTimes[User.UserId]
        local finalPlaytime = initialPlaytime + elapsedThisSession
        
        PlayerReplica:SetValue({"Stats", "Playtime"}, finalPlaytime)
        ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", finalPlaytime)
        sessionStartTimes[User.UserId] = nil
    end
    
    PlayerReplica:SetValue({"LastLeave"}, tick())

    if ModulesCache["Plot"].PlayerDelays and ModulesCache["Plot"].PlayerDelays[User] then
        for _, delayer in ModulesCache["Plot"].PlayerDelays[User] do
            task.cancel(delayer)
        end
    end
end)
]]

-- REPLACE initial leaderboard setup with:
--[[
if not ModulesCache["Leaderboards"].IsPlayerInLeaderboard(User.UserId, "Playtime") then
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", 0)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Orders", 0)
    ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Cash", 0)
end
]]

print("[M7_StatTracking_Fixes] Module loaded - apply fixes as instructed above")
