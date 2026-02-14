--[[
    MISSION 7 - FIX: Platform Multiplier Calculation Bug
    File: Server/Game/Plot/init.luau
    
    BUG: Super platform multiplier uses undefined variable 'brainrotTable'
         and is not consistently applied to actual cash generation.
    
    FIX: Use correct variable name and ensure multiplier is applied consistently.
--]]

-- ============================================================================
-- REPLACE (around line 2549-2559 in PlaceBrainrot function)
-- ============================================================================

--[[ OLD CODE:
local calculatedMPS = Calculator.CalculateMoneyPerSecond(name, weight, mutations, self.Owner:GetAttribute("Rebirths"))

local Multi = 1.5
if self.OwnerData.Rebirths >= 3 then
    Multi = 2							
end
if brainrotTable.Platform == "Super" then
    calculatedMPS *= Multi
end
--]]

-- NEW CODE:
local calculatedMPS = Calculator.CalculateMoneyPerSecond(name, weight, mutations, self.Owner:GetAttribute("Rebirths"))

-- Apply Super platform multiplier
if platform == "Super" then
    local superMulti = (self.OwnerData.Rebirths >= 3) and 2 or 1.5
    calculatedMPS = math.floor(calculatedMPS * superMulti)
end

-- ============================================================================
-- ENSURE MPS is stored correctly in Brainrots cache
-- ============================================================================

--[[ VERIFY this section (around line 2560-2570) uses the calculatedMPS:

self.Brainrots[BrainrotID] = {
    ["ID"] = BrainrotID;
    ["Platform"] = platform;  -- Make sure this matches the variable name used above
    ["Money"] = money;
    ["OfflineMoney"] = OfflineMoneyEarned;
    ["Name"] = name;
    ["Weight"] = weight;
    ["Mutations"] = mutations;
    ["MPS"] = calculatedMPS;  -- This should use the value calculated above
}
--]]

-- ============================================================================
-- ALSO FIX in UpdatePlayerCPS function (if it exists)
-- ============================================================================

--[[ FIND and UPDATE any CPS calculation to include platform multipliers:

function plot:UpdatePlayerCPS()
    local totalCPS = 0
    for brainrotID, brainrotData in pairs(self.Brainrots) do
        local cps = Calculator.CalculateMoneyPerSecond(
            brainrotData.Name,
            brainrotData.Weight,
            brainrotData.Mutations,
            self.Owner:GetAttribute("Rebirths")
        )
        
        -- Apply platform multiplier
        if brainrotData.Platform == "Super" then
            local superMulti = (self.OwnerData.Rebirths >= 3) and 2 or 1.5
            cps = math.floor(cps * superMulti)
        end
        
        totalCPS = totalCPS + cps
    end
    self.Owner:SetAttribute("CPS", totalCPS)
end
--]]

-- ============================================================================
-- VERIFY DIAMOND PLATFORM VISUAL MATCHES MECHANIC
-- ============================================================================

--[[ Around line 470, verify that Rebirth 3+ gets the 2x multiplier visual:

if Platform.Name == "Super" then
    if newPlot.OwnerData.Rebirths >= 3 then
        warn('Diamond platform unlocked - 2x multiplier active')
        
        local baseColor = Color3.fromRGB(142, 200, 255)
        mutationUTIL.Tint(Platform, baseColor)
        
        local SurfaceGUI = Platform.Billboard.SurfaceGui
        local Title, Multi = SurfaceGUI.Title, SurfaceGUI.Multi
        Title.Text = "DIAMOND PAD"
        Title.TextColor3 = Color3.new(0, 123, 255)
        Multi.Text = "(2X MULTIPLIER)"  -- This matches the mechanic now
        
        -- ... rest of visual setup
    end
end
--]]

return {}
