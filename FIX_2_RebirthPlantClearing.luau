--[[
    BUG FIX 2: Rebirth Plant Clearing
    File: Server/Game/Plot/init.luau
    Issue: Plants persist through rebirth, giving unfair advantage
    
    This fix ensures all plants are cleared when a player rebirths.
--]]

-- STEP 1: Add the ClearAllPlants function to the plot module
-- Insert this function into the plot table in Plot/init.luau

--[[
    Clears all plants from the plot - used during rebirth
--]]
function plot:ClearAllPlants()
    local PlayerReplica = Data[self.Owner]
    
    -- Clear from ActivePlants tracking
    for i = #plot.ActivePlants, 1, -1 do
        local plantData = plot.ActivePlants[i]
        if plantData.player == self.Owner then
            -- Destroy the plant model
            if plantData.plant and plantData.plant.Parent then
                plantData.plant:Destroy()
            end
            table.remove(plot.ActivePlants, i)
        end
    end
    
    -- Clear all plant objects
    for objectID, object in pairs(self.Objects) do
        if object and object.Parent and object:IsA("Model") then
            -- Check if it's a plant by looking for plant attributes
            if object:GetAttribute("GrowthTime") then
                object:Destroy()
                self.Objects[objectID] = nil
            end
        end
    end
    
    -- Clear all plant data from player data
    local plantsToRemove = {}
    for plantID, _ in pairs(self.OwnerData.Plot) do
        table.insert(plantsToRemove, plantID)
    end
    
    for _, plantID in ipairs(plantsToRemove) do
        PlayerReplica:SetValue({"Plot", plantID}, nil)
    end
    
    -- Clear any remaining plant models in the folder
    for _, child in ipairs(self.Folder.Plants:GetChildren()) do
        if child:IsA("Model") then
            child:Destroy()
        end
    end
    
    -- Clear gear placements too (optional - remove if gears should persist)
    local gearsToRemove = {}
    for gearID, _ in pairs(self.OwnerData.PlotGears) do
        table.insert(gearsToRemove, gearID)
    end
    
    for _, gearID in ipairs(gearsToRemove) do
        PlayerReplica:SetValue({"PlotGears", gearID}, nil)
    end
    
    for _, child in ipairs(self.Folder.Gears:GetChildren()) do
        if child:IsA("Model") then
            child:Destroy()
        end
    end
end

-- STEP 2: Modify the Rebirth handler to call ClearAllPlants
--[[ 
In Plot/init.luau, find the rebirth handler (around line with Remotes.Rebirth.OnServerEvent)
Replace the rebirth logic with this enhanced version:
--]]

--[[ EXISTING CODE (keep requirements check):
newPlot.Connections[7] = Remotes.Rebirth.OnServerEvent:Connect(function(user)
    if newPlot.Owner ~= user then
        return
    end

    local Rebirth = PlayerReplica.Data.Rebirths
    local RebirthGoal = Rebirth + 1

    local Requirements = RebirthsData[RebirthGoal].Requirements
    local hasRequirements = false

    local function hasRequiredInventory()
        for brainrotName, requiredAmount in pairs(Requirements) do
            if brainrotName == "Money" then
                continue
            end

            local count = 0
            for _, itemData in pairs(PlayerReplica.Data.Inventory) do
                if itemData.Name == brainrotName then
                    count += 1
                end
            end

            for _, itemData in pairs(PlayerReplica.Data.Brainrots) do
                if itemData.Name == brainrotName then
                    count += 1
                end
            end

            if count < requiredAmount then
                return false
            end
        end

        return true
    end

    hasRequirements = hasRequiredInventory()

    if not hasRequirements then	
        UIRemote:FireClient(newPlot.Owner, "TopNotification", {
            Text = "You are missing requirements to rebirth!";
            Duration = 5;
            ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
            ["ShadowTransparency"] = 0.35;
        })
        return
    end
--]]

    -- NEW: Clear all plants before proceeding
    newPlot:ClearAllPlants()
    
    -- Continue with existing brainrot removal logic...
    -- (keep existing code for removing brainrots from platforms)

--[[ EXISTING CODE (rest of rebirth handler):
    -- remove all brainrots from platforms --
    local FullBrainrotsList = {}

    for BrainrotID, BrainrotTable in newPlot.Brainrots do
        FullBrainrotsList[BrainrotID] = true
        newPlot:RemoveBrainrot(BrainrotID)
    end

    for BrainrotID, MPS in FullBrainrotsList do
        newPlot.OwnerReplica:SetValue({"Inventory", BrainrotID}, nil)
    end

    -- ... rest of existing code ...
--]]

-- STEP 3: Alternative - Compensate for plants instead of clearing
--[[ 
If you want to compensate players for their plants instead of just clearing them,
use this alternative function:
--]]

function plot:CompensateAndClearPlants()
    local PlayerReplica = Data[self.Owner]
    local totalCompensation = 0
    local ItemsData = require(Replicated.Game.Modules.Libraries.ItemsData)
    
    -- Calculate compensation value
    for plantID, plantData in pairs(self.OwnerData.Plot) do
        if plantData.Name and ItemsData[plantData.Name] then
            local seedValue = ItemsData[plantData.Name].BuyPrice or 0
            totalCompensation += math.floor(seedValue * 0.5) -- 50% refund
        end
    end
    
    -- Give compensation
    if totalCompensation > 0 then
        self:GiveCash(totalCompensation)
        UIRemote:FireClient(self.Owner, "TopNotification", {
            Text = "Received $" .. totalCompensation .. " for your plants!";
            Duration = 5;
            ["ShadowColor"] = Color3.fromRGB(0, 241, 108);
            ["ShadowTransparency"] = 0.35;
        })
    end
    
    -- Now clear all plants
    self:ClearAllPlants()
end

return {}
