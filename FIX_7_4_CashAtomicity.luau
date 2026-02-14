--[[
    BUG FIX 7.4: Cash Balance Atomic Operations
    File: Server/Game/Plot/init.luau
    Issue: GiveCash uses stale data reference (self.OwnerData.Cash)
    
    This fix ensures cash operations always use fresh data.
--]]

-- ============================================================================
-- REPLACE GiveCash function
-- ============================================================================

--[[ OLD CODE:
function plot:GiveCash(amount)
    local initialCash = amount 
    local multiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
    local finalCash = initialCash * (1 + multiplier)

    self.OwnerReplica:SetValue({"Cash"}, self.OwnerData.Cash + finalCash)
end
--]]

--[[ NEW CODE:
function plot:GiveCash(amount)
    -- Always read fresh from replica
    local currentCash = self.OwnerReplica.Data.Cash or 0
    local multiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
    local finalAmount = amount * (1 + multiplier)
    local newCash = currentCash + finalAmount
    
    -- Validate result
    if newCash < 0 then
        warn(string.format("[GiveCash] Attempted to set negative cash for %s: %f", 
            self.Owner.Name, newCash))
        newCash = 0
    end
    
    -- Clamp to reasonable maximum to prevent overflow
    local MAX_CASH = 9.22e18 -- Just under 2^63
    if newCash > MAX_CASH then
        newCash = MAX_CASH
    end
    
    self.OwnerReplica:SetValue({"Cash"}, newCash)
    
    -- Update stats if this is a new high
    local currentMost = self.OwnerReplica.Data.Stats.MostCash or 0
    if newCash > currentMost then
        self.OwnerReplica:SetValue({"Stats", "MostCash"}, newCash)
        -- Update leaderboard
        local Leaderboards = require(script.Parent.Leaderboards)
        Leaderboards.UpdatePlayerStat(self.Owner.UserId, "Cash", math.floor(newCash))
    end
    
    return newCash
end
--]]

-- ============================================================================
-- ADD DeductCash function for safe subtraction
-- ============================================================================

--[[ ADD after GiveCash: --]]

--[[
function plot:DeductCash(amount)
    -- Always read fresh from replica
    local currentCash = self.OwnerReplica.Data.Cash or 0
    
    -- Validate deduction
    if amount < 0 then
        warn(string.format("[DeductCash] Negative deduction attempted for %s: %f",
            self.Owner.Name, amount))
        return false, "Invalid amount"
    end
    
    if currentCash < amount then
        return false, "Insufficient funds"
    end
    
    local newCash = currentCash - amount
    self.OwnerReplica:SetValue({"Cash"}, newCash)
    
    return true, newCash
end
--]]

-- ============================================================================
-- UPDATE UnlockPlatform to use DeductCash
-- ============================================================================

--[[ In UIRemote.OnServerEvent handler for "UnlockPlatform", REPLACE: --]]

--[[ OLD CODE:
if totalCash >= platformPrice then
    -- remove cash --
    FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.sold})
    PlayerReplica:SetValue({"Cash"}, totalCash-platformPrice)
    -- ...
end
--]]

--[[ NEW CODE:
local deductSuccess, result = newPlot:DeductCash(platformPrice)
if deductSuccess then
    -- remove cash --
    FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.sold})
    -- ... rest of unlock code ...
else
    FXRemote:FireAllClients("Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error,['norandom'] = true})
    local difference = platformPrice - (newPlot.OwnerReplica.Data.Cash or 0)
    UIRemote:FireClient(newPlot.Owner, "TopNotification", {
        ["Text"] = "You need $"..NumberShortener.roundNumber(difference).." more to buy this platform.";
        ["Duration"] = 5;
        ["ShadowColor"] = Color3.fromRGB(255, 0, 0);
        ["ShadowTransparency"] = 0.35;
    })
end
--]]

-- ============================================================================
-- UPDATE Rebirth to use DeductCash
-- ============================================================================

--[[ In Rebirth handler, REPLACE: --]]

--[[ OLD CODE:
PlayerReplica:SetValue({"Cash"}, 0)
--]]

--[[ NEW CODE:
-- Set cash to 0 (rebirth resets money)
local currentCash = PlayerReplica.Data.Cash or 0
if currentCash > 0 then
    -- Optional: Track lifetime earnings before reset
    local lifetimeEarnings = PlayerReplica.Data.Stats.LifetimeEarnings or 0
    PlayerReplica:SetValue({"Stats", "LifetimeEarnings"}, lifetimeEarnings + currentCash)
end
PlayerReplica:SetValue({"Cash"}, 0)
--]]

return {}
