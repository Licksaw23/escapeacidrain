--[[
    BUG FIX 3: Harvest Atomicity
    File: Server/Game/ServerUtility.luau
    Issue: Double-harvesting possible due to race conditions
    
    This fix adds atomic harvesting to prevent duplicate harvests.
--]]

-- STEP 1: Modify the SetupFruit function in ServerUtility.luau
-- Replace the existing Utility.ActiveFruit assignment with this:

Utility.ActiveFruit = {}
Utility.HarvestingLocks = {} -- NEW: Track harvesting locks

Utility.SetupFruit = function(player, plantObject, fruitObject, plantID, dataIndex, exists, mainCallback, p_mod)
    local PlayerData = PlayerReplica[player]
    local ActualData = PlayerData.Data
    local fruitWeight, mutations, favorited
    local fruitData = ActualData.Plot[plantID][dataIndex]

    if exists and fruitData and fruitData.Weight then
        local fruitData = ActualData.Plot[plantID][dataIndex]
        fruitWeight = fruitData.Weight
        mutations = fruitData.Mutations
        favorited = fruitData.Favorited or false

        fruitObject:SetAttribute("Weight", fruitWeight)
        Utility.ClientScale(fruitWeight, fruitObject)

        for _, mutationName in mutations do
            Utility.ClientMutate(mutationName, fruitObject)
        end
    else
        -- Generate new fruit properties
        fruitWeight = PickWeight.RandomizeWeight(Items[plantObject:GetAttribute("Product")].WeightPool)
        fruitObject:SetAttribute("Weight", fruitWeight)

        Utility.ClientScale(fruitWeight, fruitObject)

        mutations = {}
        favorited = false
        
        local mutationLuck = player:GetAttribute("MutationLuck") or 0
        local totalLuck = player:GetAttribute("Luck") or 0 
        
        local randomMutation = PickMutations.PickMutation(mutationLuck+totalLuck, {})

        if randomMutation then
            Utility.ClientMutate(randomMutation, fruitObject)
            table.insert(mutations, randomMutation)
        end

        PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
            Mutations = mutations,
            Weight = fruitWeight
        })
    end

    -- Fade in fruit parts
    for _, part in fruitObject:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "MUTATIONVFX" then
            part.Transparency = 1
            TweenService:Create(part, TweenInfo.new(0.2), {Transparency = 0}):Play()
        end
    end

    -- Create proximity prompt
    local productName = plantObject:GetAttribute("Product")
    local productHex = Items[productName].hex

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = plantID..dataIndex
    prompt.ActionText = "Collect " .. productName
    prompt.RequiresLineOfSight = false
    prompt:SetAttribute("PromptText", "Collect")
    prompt:SetAttribute("BoldText", productName)
    prompt:SetAttribute("BoldColor", productHex)
    prompt:SetAttribute("PromptName", plantID..dataIndex)

    prompt.Enabled = not favorited
    prompt.Parent = fruitObject:FindFirstChild("Part") or fruitObject.PrimaryPart

    fruitObject:SetAttribute("PlantID", plantID)
    fruitObject:SetAttribute("DataIndex", dataIndex)
    
    -- NEW: Add harvesting lock attribute
    fruitObject:SetAttribute("IsHarvesting", false)

    if favorited then
        RS.Remotes.FavoriteFruit:FireAllClients(fruitObject, true)
    end

    local function UpdatePromptState(isFavorited)
        if prompt and prompt.Parent then
            prompt.Enabled = not isFavorited
        end
        RS.Remotes.FavoriteFruit:FireAllClients(fruitObject, isFavorited)
    end

    -- NEW: Atomic harvest key
    local harvestKey = plantID..dataIndex..player.UserId
    
    Utility.ActiveFruit[plantID..dataIndex] = function(user, call, info)
        if call == nil then
            -- NEW: Atomic harvest check
            local lockKey = plantID..dataIndex
            if Utility.HarvestingLocks[lockKey] then
                -- Already being harvested
                return
            end
            
            -- Set lock
            Utility.HarvestingLocks[lockKey] = true
            
            -- Verify plot ownership
            if tostring(user:GetAttribute("Plot")) ~= plantObject.Parent.Parent.Name then
                Utility.HarvestingLocks[lockKey] = nil
                return
            end

            -- NEW: Double-check fruit still exists
            if not fruitObject or not fruitObject.Parent then
                Utility.HarvestingLocks[lockKey] = nil
                return
            end
            
            -- NEW: Check if already harvested
            if not Utility.ActiveFruit[plantID..dataIndex] then
                Utility.HarvestingLocks[lockKey] = nil
                return
            end

            local playerPlot
            for _, plot in p_mod.Plots do
                if plot.Owner == user then
                    playerPlot = plot
                    break
                end
            end

            if not playerPlot then 
                Utility.HarvestingLocks[lockKey] = nil
                return
            end
            
            -- Check inventory size
            local TotalInventorySize = 250
            if MarketplaceService:UserOwnsGamePassAsync(user.UserId, 1657482065) then 
                TotalInventorySize = 400 
            end

            local GetInventoryCount = 0
            for i, v in playerPlot.OwnerData.Inventory do 
                GetInventoryCount += 1 
            end

            if GetInventoryCount >= TotalInventorySize then
                UIRemote:FireClient(user, "TopNotification", {
                    Text = "Your inventory is full! ("..GetInventoryCount.."/"..TotalInventorySize..")";
                    Duration = 3;
                    ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
                    ["ShadowTransparency"] = 0.35;
                })
                Utility.HarvestingLocks[lockKey] = nil
                return
            end

            -- Play pickup sound
            RS.Remotes.FX:FireClient(user, "Replicate", {
                Call = "Sound",
                Sound = RS.Game.Sounds.GameSounds.pickup
            })

            -- Remove scale / mutate replicate calls
            Utility.HandleDestroy({
                ["Plot"] = playerPlot.PlotNumber;
                ["ID"] = plantID;
                ["Model"] = fruitObject;
            })

            -- Remove fruit and data
            fruitObject:Destroy()
            PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, nil)

            -- Give item to player
            playerPlot:GiveItem({
                ID = HttpService:GenerateGUID(false),
                Name = productName,
                Weight = fruitWeight,
                Mutations = mutations
            })

            -- Clear callback BEFORE triggering main callback
            Utility.ActiveFruit[plantID..dataIndex] = nil
            
            -- Clear lock
            Utility.HarvestingLocks[lockKey] = nil
            
            -- Trigger respawn callback
            mainCallback()
            
        elseif call == "UpdateMutations" then
            if not table.find(mutations, info) then
                table.insert(mutations, info)
                PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
                    Mutations = mutations,
                    Weight = fruitWeight
                })
                Utility.ClientMutate(info, fruitObject)
            end
        elseif call == "UpdateFavorited" then
            favorited = info
            UpdatePromptState(favorited)

            PlayerData:SetValue({"Plot", plantID, tostring(dataIndex)}, {
                Mutations = mutations,
                Weight = fruitWeight,
                Favorited = favorited,
                Name = productName
            })
        end
    end

    -- Handle fruit collection with additional safety
    local connection = prompt.Triggered:Connect(function(user)
        local fruitKey = plantID..dataIndex
        if Utility.ActiveFruit[fruitKey] then
            -- NEW: Disable prompt immediately to prevent double-clicks
            prompt.Enabled = false
            
            local success, err = pcall(function()
                Utility.ActiveFruit[fruitKey](user, nil, nil)
            end)
            
            if not success then
                warn("[Harvest Error] " .. tostring(err))
                -- Re-enable prompt on error
                prompt.Enabled = not favorited
            end
        end
    end)

    fruitObject:SetAttribute("ReadyToHarvest", true)

    if #mutations > 0 then
        SpawnRemote:FireAllClients("FruitMutationText", {
            ["Mutations"] = mutations;
            ["Name"] = plantID..dataIndex;
        })
    end

    return connection
end

-- STEP 2: Add cleanup for stale locks
-- Add this to your cleanup/terminate logic:

task.spawn(function()
    while true do
        task.wait(30) -- Check every 30 seconds
        local currentTime = tick()
        -- Locks older than 10 seconds are considered stale
        for key, lockTime in pairs(Utility.HarvestingLocks) do
            if type(lockTime) == "number" and currentTime - lockTime > 10 then
                Utility.HarvestingLocks[key] = nil
            end
        end
    end
end)

return {}
