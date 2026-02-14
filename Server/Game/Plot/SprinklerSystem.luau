--[[
    SprinklerSystem.luau - Server-side sprinkler management
    Handles sprinkler placement, removal, VFX, and growth boost calculations
    
    Location: Server/Game/Plot/SprinklerSystem.luau
--]]

local SprinklerSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Module references
local Data = require(ReplicatedStorage:WaitForChild("ServerPlayerData"))
local GearsData = require(ReplicatedStorage.Game.Modules.Libraries.GearsData)
local ItemsData = require(ReplicatedStorage.Game.Modules.Libraries.ItemsData)
local BitBuffer = require(ReplicatedStorage.Game.Modules.Utilities.BitBuffer)
local NumberShortener = require(ReplicatedStorage.Game.Modules.Utilities.NumberShortener)

-- RemoteEvents
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlotRemote = Remotes.Plot
local UIRemote = Remotes.UI
local FXRemote = Remotes.FX

-- Configuration
local SPRINKLER_BOOST_MULTIPLIER = 1.5 -- Each sprinkler gives 1.5x growth speed
local MAX_SPRINKLER_BOOST = 3.375 -- Max 3 sprinklers worth of boost (1.5^3)

--[[
    Validate sprinkler placement
    Returns: success (boolean), errorMessage (string or nil)
]]
function SprinklerSystem:ValidatePlacement(player, position, gearID)
    local playerReplica = Data[player]
    if not playerReplica then
        return false, "Player data not found"
    end
    
    -- Check if player owns the gear
    local gearItem = playerReplica.Data.Inventory[gearID]
    if not gearItem then
        return false, "Gear not in inventory"
    end
    
    local gearData = GearsData[gearItem.Name]
    if not gearData then
        return false, "Invalid gear data"
    end
    
    -- Verify it's a placeable gear (sprinkler)
    if not gearData.Placeable then
        return false, "This item cannot be placed"
    end
    
    -- Check if it's a sprinkler (has Duration in PlaceableData)
    if not gearData.PlaceableData or not gearData.PlaceableData.Duration then
        return false, "This gear is not a sprinkler"
    end
    
    -- Validate position type
    if typeof(position) ~= "Vector3" then
        return false, "Invalid position"
    end
    
    -- Get player's plot
    local plotNumber = player:GetAttribute("Plot")
    if not plotNumber then
        return false, "Player has no plot"
    end
    
    local plot = workspace.Plots:FindFirstChild(tostring(plotNumber))
    if not plot then
        return false, "Plot not found"
    end
    
    -- Check if position is within plot bounds
    local origin = plot.All.Farm1.Origin.Position
    local offset = position - origin
    local maxDistance = 60 -- Maximum distance from plot origin
    
    if offset.Magnitude > maxDistance then
        return false, "Position too far from plot center"
    end
    
    -- Check for collision with existing gears
    for _, existingGear in pairs(playerReplica.Data.PlotGears or {}) do
        local posBuffer = BitBuffer.Create()
        posBuffer:FromBase64(existingGear.OffsetPosition)
        local existingOffset = Vector3.new(
            posBuffer:ReadFloat32(),
            posBuffer:ReadFloat32(),
            posBuffer:ReadFloat32()
        )
        local existingPos = origin + existingOffset
        
        if (position - existingPos).Magnitude < 3 then
            return false, "Too close to existing gear"
        end
    end
    
    return true, gearItem.Name, gearData
end

--[[
    Setup removal prompt for a sprinkler
]]
function SprinklerSystem:SetupRemovalPrompt(plot, gearID, gearModel, sprinklerName)
    local primaryPart = gearModel.PrimaryPart or gearModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[SprinklerSystem] No primary part found for sprinkler:", gearID)
        return
    end
    
    -- Create proximity prompt for removal
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "RemoveSprinklerPrompt"
    prompt.ActionText = "Remove Sprinkler"
    prompt.ObjectText = sprinklerName
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.Parent = primaryPart
    
    -- Handle removal
    prompt.Triggered:Connect(function(triggeringPlayer)
        if triggeringPlayer ~= plot.Owner then
            UIRemote:FireClient(triggeringPlayer, "TopNotification", {
                Text = "You don't own this sprinkler!";
                Duration = 3;
                ShadowColor = Color3.fromRGB(255, 0, 0);
                ShadowTransparency = 0.35;
            })
            return
        end
        
        self:RemoveGear(plot, gearID)
    end)
    
    return prompt
end

--[[
    Remove a gear/sprinkler from the plot
]]
function SprinklerSystem:RemoveGear(plot, gearID)
    local playerReplica = Data[plot.Owner]
    if not playerReplica then
        warn("[SprinklerSystem] No player replica found for:", plot.Owner.Name)
        return false
    end
    
    local gearData = playerReplica.Data.PlotGears[tostring(gearID)]
    if not gearData then
        warn("[SprinklerSystem] No gear data found for:", gearID)
        return false
    end
    
    local gearModel = plot.Objects[gearID]
    
    -- Stop VFX on all clients
    FXRemote:FireAllClients("SprinklerStop", {
        ID = gearID;
    })
    
    -- Play removal sound
    FXRemote:FireClient(plot.Owner, "Replicate", {
        Call = "Sound";
        Sound = ReplicatedStorage.Game.Sounds.GameSounds.remove;
    })
    
    -- Remove from data
    playerReplica:SetValue({"PlotGears", tostring(gearID)}, nil)
    
    -- Remove from Objects cache
    if plot.Objects[gearID] then
        plot.Objects[gearID] = nil
    end
    
    -- Destroy model with fade effect
    if gearModel and gearModel.Parent then
        -- Notify clients to play removal effect
        FXRemote:FireAllClients("Replicate", {
            Call = "PoofAway";
            Model = gearModel;
            Duration = 0.3;
        })
        
        task.delay(0.3, function()
            if gearModel and gearModel.Parent then
                gearModel:Destroy()
            end
        end)
    end
    
    -- Return gear to inventory
    local gearName = gearData.Name
    local existingGearID = nil
    
    -- Check if player already has this gear type
    for invID, invItem in pairs(playerReplica.Data.Inventory) do
        if invItem.Name == gearName then
            existingGearID = invID
            break
        end
    end
    
    if existingGearID then
        -- Increment quantity
        local currentQty = playerReplica.Data.Inventory[existingGearID].Quantity or 1
        playerReplica:SetValue({"Inventory", existingGearID, "Quantity"}, currentQty + 1)
    else
        -- Add as new item
        local newItemID = HttpService:GenerateGUID(false)
        playerReplica:SetValue({"Inventory", newItemID}, {
            Name = gearName;
            Quantity = 1;
        })
    end
    
    -- Notify player
    UIRemote:FireClient(plot.Owner, "TopNotification", {
        Text = gearName .. " returned to inventory!";
        Duration = 3;
        ShadowColor = Color3.fromRGB(0, 255, 100);
        ShadowTransparency = 0.35;
    })
    
    return true
end

--[[
    Calculate growth boost multiplier from sprinklers for a specific position
]]
function SprinklerSystem:GetGrowthBoost(plot, position)
    if not plot or not position then
        return 1
    end
    
    local playerReplica = Data[plot.Owner]
    if not playerReplica then
        return 1
    end
    
    local multiplier = 1
    local sprinklerTypesSeen = {}
    local currentTime = workspace:GetServerTimeNow()
    
    for gearID, gearData in pairs(playerReplica.Data.PlotGears or {}) do
        local gearInfo = GearsData[gearData.Name]
        
        -- Check if it's a sprinkler (has Duration)
        if gearInfo and gearInfo.PlaceableData and gearInfo.PlaceableData.Duration then
            -- Check if still active
            local isActive = true
            if gearData.ActivatedTime then
                local timeBuffer = BitBuffer.Create()
                timeBuffer:FromBase64(gearData.ActivatedTime)
                local activatedTime = timeBuffer:ReadFloat64()
                local endTime = activatedTime + gearInfo.PlaceableData.Duration
                isActive = currentTime <= endTime
            end
            
            if isActive then
                -- Decode sprinkler position
                local posBuffer = BitBuffer.Create()
                posBuffer:FromBase64(gearData.OffsetPosition)
                local offset = Vector3.new(
                    posBuffer:ReadFloat32(),
                    posBuffer:ReadFloat32(),
                    posBuffer:ReadFloat32()
                )
                
                local origin = plot.Folder.All.Farm1.Origin.Position
                local sprinklerPos = origin + offset
                
                -- Check if plant is within range
                local distance = (position - sprinklerPos).Magnitude
                local radius = gearInfo.PlaceableData.Radius or 20
                
                if distance <= radius then
                    -- Only stack different sprinkler types
                    if not sprinklerTypesSeen[gearData.Name] then
                        sprinklerTypesSeen[gearData.Name] = true
                        multiplier = multiplier * SPRINKLER_BOOST_MULTIPLIER
                    end
                end
            end
        end
    end
    
    -- Cap at maximum boost
    return math.min(multiplier, MAX_SPRINKLER_BOOST)
end

--[[
    Get all active sprinklers and their positions for a plot
]]
function SprinklerSystem:GetActiveSprinklers(plot)
    if not plot then
        return {}
    end
    
    local playerReplica = Data[plot.Owner]
    if not playerReplica then
        return {}
    end
    
    local sprinklers = {}
    local currentTime = workspace:GetServerTimeNow()
    
    for gearID, gearData in pairs(playerReplica.Data.PlotGears or {}) do
        local gearInfo = GearsData[gearData.Name]
        
        if gearInfo and gearInfo.PlaceableData and gearInfo.PlaceableData.Duration then
            local isActive = true
            local timeRemaining = gearInfo.PlaceableData.Duration
            
            if gearData.ActivatedTime then
                local timeBuffer = BitBuffer.Create()
                timeBuffer:FromBase64(gearData.ActivatedTime)
                local activatedTime = timeBuffer:ReadFloat64()
                local endTime = activatedTime + gearInfo.PlaceableData.Duration
                isActive = currentTime <= endTime
                timeRemaining = math.max(0, endTime - currentTime)
            end
            
            if isActive then
                -- Decode position
                local posBuffer = BitBuffer.Create()
                posBuffer:FromBase64(gearData.OffsetPosition)
                local offset = Vector3.new(
                    posBuffer:ReadFloat32(),
                    posBuffer:ReadFloat32(),
                    posBuffer:ReadFloat32()
                )
                
                table.insert(sprinklers, {
                    ID = gearID;
                    Name = gearData.Name;
                    Offset = offset;
                    Radius = gearInfo.PlaceableData.Radius or 20;
                    TimeRemaining = timeRemaining;
                })
            end
        end
    end
    
    return sprinklers
end

--[[
    Handle sprinkler placement - called from Plot:PlaceGear
]]
function SprinklerSystem:OnSprinklerPlaced(plot, gearID, gearModel, gearName)
    local gearData = GearsData[gearName]
    if not gearData or not gearData.PlaceableData or not gearData.PlaceableData.Duration then
        return -- Not a sprinkler
    end
    
    -- Start VFX on all clients
    FXRemote:FireAllClients("SprinklerStart", {
        ID = gearID;
        Model = gearModel;
        Type = gearName;
    })
    
    -- Setup removal prompt
    self:SetupRemovalPrompt(plot, gearID, gearModel, gearName)
    
    -- Schedule automatic destruction when duration expires
    local duration = gearData.PlaceableData.Duration
    task.delay(duration, function()
        self:OnSprinklerExpired(plot, gearID)
    end)
    
    -- Notify player
    UIRemote:FireClient(plot.Owner, "TopNotification", {
        Text = gearName .. " placed! (" .. math.floor(duration / 60) .. " min duration)";
        Duration = 3;
        ShadowColor = Color3.fromRGB(100, 150, 255);
        ShadowTransparency = 0.35;
    })
end

--[[
    Handle sprinkler expiration
]]
function SprinklerSystem:OnSprinklerExpired(plot, gearID)
    local playerReplica = Data[plot.Owner]
    if not playerReplica then
        return
    end
    
    -- Check if sprinkler still exists
    if not playerReplica.Data.PlotGears[tostring(gearID)] then
        return -- Already removed
    end
    
    -- Stop VFX
    FXRemote:FireAllClients("SprinklerStop", {
        ID = gearID;
    })
    
    -- Remove from data
    playerReplica:SetValue({"PlotGears", tostring(gearID)}, nil)
    
    -- Destroy model
    local gearModel = plot.Objects[gearID]
    if gearModel and gearModel.Parent then
        FXRemote:FireAllClients("Replicate", {
            Call = "PoofAway";
            Model = gearModel;
            Duration = 0.5;
        })
        
        task.delay(0.5, function()
            if gearModel and gearModel.Parent then
                gearModel:Destroy()
            end
        end)
    end
    
    if plot.Objects[gearID] then
        plot.Objects[gearID] = nil
    end
    
    -- Notify player
    UIRemote:FireClient(plot.Owner, "TopNotification", {
        Text = "Your sprinkler has expired!";
        Duration = 5;
        ShadowColor = Color3.fromRGB(255, 150, 0);
        ShadowTransparency = 0.35;
    })
end

--[[
    Handle client request to remove gear
]]
function SprinklerSystem:HandleRemoveRequest(player, gearID)
    -- Find player's plot
    local Plot = require(script.Parent)
    local playerPlot = nil
    
    for _, p in ipairs(Plot.Plots) do
        if p.Owner == player then
            playerPlot = p
            break
        end
    end
    
    if not playerPlot then
        return false, "No plot found"
    end
    
    -- Verify ownership of the gear
    local playerReplica = Data[player]
    if not playerReplica or not playerReplica.Data.PlotGears[tostring(gearID)] then
        return false, "Gear not found"
    end
    
    -- Remove the gear
    local success = self:RemoveGear(playerPlot, gearID)
    return success, success and "Gear removed" or "Failed to remove gear"
end

return SprinklerSystem
