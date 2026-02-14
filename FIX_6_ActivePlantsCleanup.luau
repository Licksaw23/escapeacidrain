--[[
    BUG FIX 6: ActivePlants Immediate Cleanup
    File: Server/Game/Plot/init.luau
    Issue: ActivePlants entries aren't cleaned up immediately when player leaves
    
    This fix adds immediate cleanup to prevent memory leaks.
--]]

-- STEP 1: Add immediate cleanup function
-- Add this function to the plot table:

--[[
    Immediately removes all active plant tracking for this player
    Call this in Terminate()
--]]
function plot:CleanupActivePlants()
    local removedCount = 0
    
    -- Iterate backwards to safely remove
    for i = #plot.ActivePlants, 1, -1 do
        local plantData = plot.ActivePlants[i]
        
        -- Check if this plant belongs to this player
        if plantData.player == self.Owner then
            -- Cancel any pending operations on this plant
            if plantData.plant then
                -- Clear any attributes that might trigger further processing
                plantData.plant:SetAttribute("ProcessingGrowth", nil)
            end
            
            table.remove(plot.ActivePlants, i)
            removedCount += 1
        end
    end
    
    if removedCount > 0 then
        warn(string.format("[Plot %d] Cleaned up %d active plants for %s",
            self.PlotNumber,
            removedCount,
            self.Owner.Name
        ))
    end
    
    return removedCount
end

-- STEP 2: Modify plot:Terminate() to call cleanup
-- At the BEGINNING of plot:Terminate(), add:

--[[
function plot:Terminate()
    -- NEW: Immediate cleanup of active plants
    self:CleanupActivePlants()
    
    -- ... rest of existing Terminate() code ...
end
--]]

-- STEP 3: Alternative - Cleanup by player on PlayerRemoving
-- Add this to Server/Init.legacy.luau in the PlayerRemoving handler:

--[[
PlayerService.PlayerRemoving:Connect(function(User)
    local PlayerReplica = Data[User]
    if PlayerReplica then
        PlayerReplica:SetValue({"LastLeave"}, tick())
    end
    
    -- NEW: Clean up plot ActivePlants immediately
    local PlotModule = ModulesCache["Plot"]
    if PlotModule then
        for i = #PlotModule.ActivePlants, 1, -1 do
            local plantData = PlotModule.ActivePlants[i]
            if plantData.player == User then
                table.remove(PlotModule.ActivePlants, i)
            end
        end
    end
    
    if ModulesCache["Plot"].PlayerDelays and ModulesCache["Plot"].PlayerDelays[User] then
        for _, delayer in ModulesCache["Plot"].PlayerDelays[User] do
            task.cancel(delayer)
        end
        ModulesCache["Plot"].PlayerDelays[User] = nil
    end
    
    -- End profile session
    local Profile = Profiles[User]
    if Profile then
        Profile:EndSession()
    end
end)
--]]

-- STEP 4: Add periodic cleanup for orphaned entries
-- Add this to the end of Plot/init.luau:

--[[
-- Periodic cleanup task for orphaned ActivePlants entries
task.spawn(function()
    while true do
        task.wait(60) -- Check every minute
        
        local orphanedCount = 0
        local currentTime = tick()
        
        for i = #plot.ActivePlants, 1, -1 do
            local plantData = plot.ActivePlants[i]
            local isOrphaned = false
            
            -- Check if player no longer exists
            if not plantData.player or not plantData.player.Parent then
                isOrphaned = true
            else
                -- Check if player has a different plot now (reassigned)
                local playerPlotNumber = plantData.player:GetAttribute("Plot")
                if playerPlotNumber and plantData.Plot then
                    -- This would require tracking plot number in plantData
                end
            end
            
            if isOrphaned then
                -- Safely destroy plant if it exists
                if plantData.plant and plantData.plant.Parent then
                    plantData.plant:Destroy()
                end
                table.remove(plot.ActivePlants, i)
                orphanedCount += 1
            end
        end
        
        if orphanedCount > 0 then
            warn(string.format("[ActivePlants] Cleaned up %d orphaned entries", orphanedCount))
        end
    end
end)
--]]

return {}
