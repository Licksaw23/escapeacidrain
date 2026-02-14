--[[
    BUG FIX 5: Session End Handling
    File: Server/Data/init.legacy.luau
    Issue: Players are kicked unnecessarily when session ends
    
    This fix improves session end handling to only kick when appropriate.
--]]

-- STEP 1: Modify the Profile.OnSessionEnd handler
-- REPLACE the existing OnSessionEnd handler in Data/init.legacy.luau:

--[[ EXISTING CODE:
Profile.OnSessionEnd:Connect(function()
    Replica:Destroy()
    Profiles[plr] = nil
    PlayerReplicas[plr] = nil
    plr:Kick()
end)
--]]

-- WITH THIS IMPROVED VERSION:
Profile.OnSessionEnd:Connect(function(reason)
    -- Log the session end reason for debugging
    warn(string.format("[Data] Session ended for %s | Reason: %s | Still in game: %s",
        tostring(plr.Name),
        tostring(reason or "unknown"),
        tostring(plr.Parent == Players)
    ))
    
    -- Clean up replica
    if Replica then
        Replica:Destroy()
        Replica = nil
    end
    
    -- Clean up tracking tables
    Profiles[plr] = nil
    PlayerReplicas[plr] = nil
    
    -- Only kick if:
    -- 1. Player is still in the game
    -- 2. Reason is NOT "Close" (server shutdown already handles this)
    -- 3. Reason indicates a problem, not normal session end
    if plr.Parent == Players then
        local shouldKick = false
        local kickMessage = ""
        
        if reason == "Release" then
            -- Session was stolen or released - this is a problem
            shouldKick = true
            kickMessage = "Data session released. Please rejoin."
        elseif reason == "Steal" then
            -- Session was stolen by another server
            shouldKick = true
            kickMessage = "Session conflict detected. Please rejoin."
        elseif reason == "Close" then
            -- Server is shutting down - let server handle kick
            shouldKick = false
        elseif reason == nil or reason == "" then
            -- Unknown reason - be cautious
            shouldKick = true
            kickMessage = "Data session ended unexpectedly. Please rejoin."
        end
        
        if shouldKick then
            -- Delay slightly to allow any final saves
            task.delay(0.5, function()
                if plr and plr.Parent == Players then
                    plr:Kick(kickMessage)
                end
            end)
        end
    end
end)

-- STEP 2: Add graceful shutdown handling
-- At the end of Data/init.legacy.luau, add:

game:BindToClose(function()
    warn("[Data] Server shutting down, saving all profiles...")
    
    local saveTasks = {}
    
    for plr, profile in pairs(Profiles) do
        table.insert(saveTasks, task.spawn(function()
            local success, err = pcall(function()
                profile:EndSession()
            end)
            if not success then
                warn(string.format("[Data] Failed to end session for %s: %s",
                    tostring(plr.Name), tostring(err)))
            end
        end))
    end
    
    -- Wait for all saves with timeout
    local startTime = tick()
    local timeout = 10 -- 10 second timeout
    
    while #saveTasks > 0 and (tick() - startTime) < timeout do
        for i = #saveTasks, 1, -1 do
            if coroutine.status(saveTasks[i]) == "dead" then
                table.remove(saveTasks, i)
            end
        end
        task.wait(0.1)
    end
    
    if #saveTasks > 0 then
        warn(string.format("[Data] Shutdown timed out with %d pending saves", #saveTasks))
    else
        warn("[Data] All profiles saved successfully")
    end
end)

-- STEP 3: Add data validation on load
-- After Profile:Reconcile(), add:

--[[ In the PlayerAdded handler, after Profile:Reconcile(): --]]

-- Validate and fix data issues
local function validatePlayerData(data)
    local needsSave = false
    
    -- Ensure required tables exist
    if not data.Brainrots then
        data.Brainrots = {}
        needsSave = true
    end
    if not data.Plot then
        data.Plot = {}
        needsSave = true
    end
    if not data.PlotGears then
        data.PlotGears = {}
        needsSave = true
    end
    if not data.Inventory then
        data.Inventory = {}
        needsSave = true
    end
    if not data.Unlocks then
        data.Unlocks = {}
        needsSave = true
    end
    if not data.Settings then
        data.Settings = {AutoSell = {}}
        needsSave = true
    end
    if not data.Stats then
        data.Stats = {Orders = 0, Playtime = 0, MostCash = 0}
        needsSave = true
    end
    if not data.Codes then
        data.Codes = {}
        needsSave = true
    end
    if not data.Boosts then
        data.Boosts = {}
        needsSave = true
    end
    if not data.Purchases then
        data.Purchases = {}
        needsSave = true
    end
    if not data.ActiveOrders then
        data.ActiveOrders = {}
        needsSave = true
    end
    
    -- Validate numeric fields
    if type(data.Cash) ~= "number" then
        data.Cash = 100000 -- Default starting cash
        needsSave = true
    end
    if type(data.Rebirths) ~= "number" then
        data.Rebirths = 0
        needsSave = true
    end
    
    -- Ensure Cash is not negative
    if data.Cash < 0 then
        data.Cash = 0
        needsSave = true
    end
    
    return needsSave
end

-- Call validation after reconcile
if validatePlayerData(Profile.Data) then
    warn(string.format("[Data] Fixed data issues for %s", plr.Name))
end

return {}
