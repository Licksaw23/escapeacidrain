--[[
    BUG FIX 7: Debug Statement Cleanup
    File: Multiple files
    Issue: Debug print/warn statements cluttering output logs
    
    This file lists all debug statements that should be removed or converted.
--]]

-- ============================================
-- STATEMENTS TO REMOVE (Debug only)
-- ============================================

--[[
File: Server/Game/Plot/init.luau
Lines: ~340
Code:
    warn(' im giving you DIAMOND PLATFORM!!!')
Action: REMOVE - Debug message during platform setup

File: Server/Game/Plot/init.luau  
Lines: ~437
Code:
    print(getCurrentOrder)
Action: REMOVE - Prints table reference unnecessarily

File: Server/Game/Plot/init.luau
Lines: ~2200
Code:
    print(calculatedMPS)
Action: REMOVE - Debug output for money per second

File: Server/Game/Plot/init.luau
Lines: ~1728 (in PlaceGear)
Code:
    print('aww mane')
Action: REMOVE - Debug placeholder text

File: Server/Game/Plot/Plants/Carrot Seed.luau
Lines: 81
Code:
    warn("GROW STEM (STAGE 1)")
Action: REMOVE or CONVERT to debug mode only

File: Server/Game/Plot/Plants/Carrot Seed.luau
Lines: 103
Code:
    warn("GROW LEAVES (STAGE 2)")
Action: REMOVE or CONVERT to debug mode only

File: Server/Game/Plot/Plants/Carrot Seed.luau
Lines: 129
Code:
    warn("GROW CARROT ROOT (STAGE 3)")
Action: REMOVE or CONVERT to debug mode only

File: Server/Init.legacy.luau
Lines: 241
Code:
    warn('giving: '..totalMult)
Action: REMOVE - Debug for rebirth multiplier

File: Server/Init.legacy.luau
Lines: 360
Code:
    warn(ModulesCache["ServerUtility"].CustomerSpawns)
Action: REMOVE - Debug table dump
--]]

-- ============================================
-- STATEMENTS TO KEEP (Legitimate errors)
-- ============================================

--[[
File: Server/Game/Admin.luau
All warn() statements for admin commands
Action: KEEP - These indicate actual errors

File: Server/Game/Purchases.luau
Error logging in logError function
Action: KEEP - Purchase tracking errors

File: Server/Game/Plot/Plants/*.luau
Safety warnings like "Plant no longer exists"
Action: KEEP - Indicate edge cases and errors

File: Server/Events/*.luau
Event handler warnings
Action: KEEP - Event system errors
--]]

-- ============================================
-- RECOMMENDED DEBUG SYSTEM
-- ============================================

--[[
Create a shared Debug module to control logging:

-- Shared/Modules/Utilities/Debug.luau
local Debug = {}

Debug.Enabled = false -- Set to true for development
Debug.Categories = {
    Plants = false,
    Brainrots = false,
    Orders = false,
    Economy = false,
    Events = false
}

function Debug.Log(category, message, ...)
    if not Debug.Enabled then return end
    if category and not Debug.Categories[category] then return end
    
    local formatted = string.format(message, ...)
    print(string.format("[DEBUG][%s] %s", category or "General", formatted))
end

function Debug.Warn(category, message, ...)
    if not Debug.Enabled then return end
    if category and not Debug.Categories[category] then return end
    
    local formatted = string.format(message, ...)
    warn(string.format("[DEBUG][%s] %s", category or "General", formatted))
end

return Debug

-- Usage:
local Debug = require(path.to.Debug)
Debug.Log("Plants", "Growing stem for plant %s", plantID)
Debug.Warn("Orders", "Order timeout for brainrot %s", brainrotID)
--]]

return {}
