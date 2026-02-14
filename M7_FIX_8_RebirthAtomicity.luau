--[[
    MISSION 7 - FIX: Rebirth Atomic Requirements Check
    File: Server/Game/Plot/init.luau
    
    BUG: Rebirth requirements are checked non-atomically, allowing item
         duplication through gifting during the rebirth process.
    
    FIX: Implement atomic check-and-remove with inventory locking.
--]]

-- ============================================================================
-- ADD at the top of the Plot module (after local declarations)
-- ============================================================================

--[[ ADD:
local RebirthLock = {}  -- Track players currently rebirthing
local REBIRTH_COOLDOWN = 300  -- 5 minutes between rebirths
local LastRebirthTime = {}
--]]

-- ============================================================================
-- REPLACE Rebirth handler (around line 1283-1407)
-- ============================================================================

--[[ OLD CODE:
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
    
    -- ... rest of rebirth logic
--]]

-- NEW CODE:
newPlot.Connections[7] = Remotes.Rebirth.OnServerEvent:Connect(function(user)
    if newPlot.Owner ~= user then
        return
    end
    
    -- Check cooldown
    local lastRebirth = LastRebirthTime[user.UserId] or 0
    if tick() - lastRebirth < REBIRTH_COOLDOWN then
        local remaining = math.ceil(REBIRTH_COOLDOWN - (tick() - lastRebirth))
        UIRemote:FireClient(newPlot.Owner, "TopNotification", {
            Text = "You must wait " .. remaining .. " seconds before rebirthing again!";
            Duration = 5;
            ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
            ["ShadowTransparency"] = 0.35;
        })
        return
    end
    
    -- Check for existing lock
    if RebirthLock[user.UserId] then
        UIRemote:FireClient(newPlot.Owner, "TopNotification", {
            Text = "Rebirth already in progress!";
            Duration = 3;
            ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
            ["ShadowTransparency"] = 0.35;
        })
        return
    end
    
    -- Set lock
    RebirthLock[user.UserId] = true

    local Rebirth = PlayerReplica.Data.Rebirths
    local RebirthGoal = Rebirth + 1
    
    -- Check if max rebirth reached
    if not RebirthsData[RebirthGoal] then
        UIRemote:FireClient(newPlot.Owner, "TopNotification", {
            Text = "You have reached the maximum rebirth level!";
            Duration = 5;
            ["ShadowColor"] = Color3.fromRGB(0, 241, 108);
            ["ShadowTransparency"] = 0.35;
        })
        RebirthLock[user.UserId] = nil
        return
    end

    local Requirements = RebirthsData[RebirthGoal].Requirements
    
    -- ATOMIC REQUIREMENTS CHECK
    -- Collect all required items before removing anything
    local itemsToRemove = {}
    local hasRequirements = true
    local missingItems = {}

    for brainrotName, requiredAmount in pairs(Requirements) do
        if brainrotName == "Money" then
            -- Check money separately
            if PlayerReplica.Data.Cash < requiredAmount then
                hasRequirements = false
                missingItems["Money"] = requiredAmount - PlayerReplica.Data.Cash
            end
            continue
        end

        local count = 0
        local foundItems = {}
        
        -- Search inventory
        for itemID, itemData in pairs(PlayerReplica.Data.Inventory) do
            if itemData.Name == brainrotName then
                -- Check if favorited (can't use favorited items)
                if itemData.Favorited then
                    continue
                end
                count += 1
                table.insert(foundItems, {ID = itemID, Location = "Inventory"})
                if count >= requiredAmount then
                    break
                end
            end
        end

        -- Search placed brainrots
        if count < requiredAmount then
            for itemID, itemData in pairs(PlayerReplica.Data.Brainrots) do
                if itemData.Name == brainrotName then
                    count += 1
                    table.insert(foundItems, {ID = itemID, Location = "Brainrots"})
                    if count >= requiredAmount then
                        break
                    end
                end
            end
        end

        if count < requiredAmount then
            hasRequirements = false
            missingItems[brainrotName] = requiredAmount - count
        else
            -- Store items to remove
            for i = 1, requiredAmount do
                table.insert(itemsToRemove, foundItems[i])
            end
        end
    end

    if not hasRequirements then
        -- Build error message
        local errorMsg = "Missing requirements: "
        for item, amount in pairs(missingItems) do
            errorMsg = errorMsg .. amount .. " " .. item .. ", "
        end
        
        UIRemote:FireClient(newPlot.Owner, "TopNotification", {
            Text = errorMsg:sub(1, -3);  -- Remove trailing ", "
            Duration = 5;
            ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
            ["ShadowTransparency"] = 0.35;
        })
        RebirthLock[user.UserId] = nil
        return
    end

    -- ATOMIC REMOVAL - Remove all items at once
    for _, itemInfo in ipairs(itemsToRemove) do
        if itemInfo.Location == "Inventory" then
            PlayerReplica:SetValue({"Inventory", itemInfo.ID}, nil)
            -- Remove tool if equipped
            newPlot:DestroyToolByID(itemInfo.ID)
        elseif itemInfo.Location == "Brainrots" then
            -- Remove from platform if placed
            if newPlot.Brainrots[itemInfo.ID] then
                newPlot:RemoveBrainrot(itemInfo.ID)
            end
            PlayerReplica:SetValue({"Brainrots", itemInfo.ID}, nil)
        end
    end

    -- Clear all plants before proceeding
    newPlot:ClearAllPlants()  -- Requires FIX_2_RebirthPlantClearing

    -- Continue with existing brainrot removal logic...
    -- (Remove remaining brainrots from platforms)
    local FullBrainrotsList = {}

    for BrainrotID, BrainrotTable in newPlot.Brainrots do
        FullBrainrotsList[BrainrotID] = true
        newPlot:RemoveBrainrot(BrainrotID)
    end

    for BrainrotID, _ in pairs(FullBrainrotsList) do
        newPlot.OwnerReplica:SetValue({"Inventory", BrainrotID}, nil)
    end

    -- Destroy all brainrot tools
    local FullToolsList = {}
    for _, tool in newPlot.Owner.Backpack:GetChildren() do
        if tool:IsA("Tool") then
            local toolID = tool:GetAttribute("ID")
            if toolID and newPlot.OwnerData.Inventory[toolID] then
                local invCache = newPlot.OwnerData.Inventory[toolID]
                if require(Replicated.Game.Modules.Libraries.BrainrotsData)[invCache.Name] then
                    FullToolsList[tool] = toolID
                end
            end
        end
    end

    if newPlot.Owner.Character then
        for _, tool in newPlot.Owner.Character:GetChildren() do
            if tool:IsA("Tool") then
                local toolID = tool:GetAttribute("ID")
                if toolID and newPlot.OwnerData.Inventory[toolID] then
                    local invCache = newPlot.OwnerData.Inventory[toolID]
                    if require(Replicated.Game.Modules.Libraries.BrainrotsData)[invCache.Name] then
                        FullToolsList[tool] = toolID
                    end
                end
            end
        end
    end

    for Tool, _ in pairs(FullToolsList) do
        Tool:Destroy()
    end

    -- Apply rebirth
    PlayerReplica:SetValue({"Rebirths"}, RebirthGoal)
    Player:SetAttribute("Rebirths", RebirthGoal)
    LastRebirthTime[user.UserId] = tick()
    
    -- Reset cash
    PlayerReplica:SetValue({"Cash"}, 0)

    -- Apply visual/functionality changes
    if newPlot.Functions["Rebirth" .. RebirthGoal] then
        newPlot.Functions["Rebirth" .. RebirthGoal]()
    end

    -- Unlock new platforms if applicable
    for _, StoredButton in Replicated.PlotStorage[i]:GetChildren() do
        if StoredButton:GetAttribute("Rebirth") and StoredButton:GetAttribute("Rebirth") <= newPlot.OwnerData.Rebirths then
            StoredButton.Parent = newPlot.Folder.Platforms
            SetupButton(StoredButton)
        end
    end

    -- Notifications
    if RebirthGoal == 2 or RebirthGoal == 3 then
        UIRemote:FireClient(newPlot.Owner, "TopNotification", {
            Text = "You have unlocked a new line!";
            Duration = 5;
            ["ShadowColor"] = Color3.fromRGB(187, 49, 227);
            ["ShadowTransparency"] = 0.35;
        })
    end

    UIRemote:FireClient(newPlot.Owner, "TopNotification", {
        Text = "You have rebirthed to level " .. RebirthGoal .. "!";
        Duration = 5;
        ["ShadowColor"] = Color3.fromRGB(0, 241, 108);
        ["ShadowTransparency"] = 0.35;
    })

    -- Release lock
    RebirthLock[user.UserId] = nil
end)

-- ============================================================================
-- ADD ClearAllPlants function if not already present from FIX_2
-- ============================================================================

--[[
function plot:ClearAllPlants()
    local PlayerReplica = Data[self.Owner]
    
    -- Clear all plant data
    for plantID, _ in pairs(self.OwnerData.Plot or {}) do
        PlayerReplica:SetValue({"Plot", plantID}, nil)
    end
    
    -- Clear all gear data
    for gearID, _ in pairs(self.OwnerData.PlotGears or {}) do
        PlayerReplica:SetValue({"PlotGears", gearID}, nil)
    end
    
    -- Clear physical objects
    for _, child in ipairs(self.Folder.Plants:GetChildren()) do
        if child:IsA("Model") then
            child:Destroy()
        end
    end
    
    for _, child in ipairs(self.Folder.Gears:GetChildren()) do
        if child:IsA("Model") then
            child:Destroy()
        end
    end
    
    -- Clear tracking
    self.Objects = {}
end
--]]

return {}
