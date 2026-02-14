--[[
    MISSION 7 - FIX: Rebirth Multiplier Stacking Exploit
    File: Server/Init.legacy.luau
    
    BUG: Rebirth multipliers are applied every time a player joins,
         allowing unlimited stat accumulation through session resets.
    
    FIX: Track when multipliers have been applied and only grant them once.
--]]

-- ============================================================================
-- REPLACE (around line 242-247)
-- ============================================================================

--[[ OLD CODE:
-- Rebirth luck. --
local totalMult = 0.5 * (Data.Rebirths or 0)
if totalMult > 0 then
    warn('giving: '..totalMult)
    newPlot:GiveTotalLuck(totalMult)
    newPlot:GiveCashMultiplier(totalMult)
    newPlot:GiveSpeed(totalMult)
end
--]]

-- NEW CODE:
-- Rebirth multipliers - only apply once per session
local totalMult = 0.5 * (Data.Rebirths or 0)
if totalMult > 0 and not User:GetAttribute("RebirthMultipliersApplied") then
    warn('Applying rebirth multipliers: '..totalMult)
    newPlot:GiveTotalLuck(totalMult)
    newPlot:GiveCashMultiplier(totalMult)
    newPlot:GiveSpeed(totalMult)
    User:SetAttribute("RebirthMultipliersApplied", true)
    User:SetAttribute("BaseRebirthMultiplier", totalMult)
end

-- ============================================================================
-- ALTERNATIVE FIX: Store applied multipliers in player data
-- ============================================================================

--[[
If you want multipliers to persist properly across sessions and be recoverable:

1. Add to StarterData.luau:
   AppliedRebirthMultipliers = 0;

2. Use this code instead:

local totalMult = 0.5 * (Data.Rebirths or 0)
local alreadyApplied = Data.AppliedRebirthMultipliers or 0
local multToApply = totalMult - alreadyApplied

if multToApply > 0 then
    warn('Applying new rebirth multipliers: '..multToApply)
    newPlot:GiveTotalLuck(multToApply)
    newPlot:GiveCashMultiplier(multToApply)
    newPlot:GiveSpeed(multToApply)
    PlayerReplica:SetValue({"AppliedRebirthMultipliers"}, totalMult)
end
--]]

-- ============================================================================
-- ADDITIONAL FIX: Reset multipliers on player leave to prevent accumulation
-- ============================================================================

--[[ ADD to PlayerRemoving handler (if not already present):

PlayerService.PlayerRemoving:Connect(function(User)
    local PlayerReplica = Data[User]
    if PlayerReplica then
        PlayerReplica:SetValue({"LastLeave"}, tick())
    end
    
    -- Clear rebirth multiplier tracking
    User:SetAttribute("RebirthMultipliersApplied", nil)
    User:SetAttribute("BaseRebirthMultiplier", nil)
    
    if ModulesCache["Plot"] and ModulesCache["Plot"].PlayerDelays and ModulesCache["Plot"].PlayerDelays[User] then
        for _, delayer in ModulesCache["Plot"].PlayerDelays[User] do
            task.cancel(delayer)
        end
    end
end)
--]]

return {}
