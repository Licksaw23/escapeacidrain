--[[
    PlantService.luau - Server-side plant data management
    Handles all plant data operations, validation, and replication
    
    INTEGRATION NOTE: This module works with Client/Game/PlantSystem.luau
    All visual operations are handled client-side; server manages data only.
--]]

local PlantService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Module references
local Data = require(ReplicatedStorage:WaitForChild("ServerPlayerData"))
local ItemsData = require(ReplicatedStorage.Game.Modules.Libraries.ItemsData)
local GearsData = require(ReplicatedStorage.Game.Modules.Libraries.GearsData)
local BitBuffer = require(ReplicatedStorage.Game.Modules.Utilities.BitBuffer)
local FruitSystem = require(script.Parent.FruitSystem)
local ServerUtility = require(script.Parent.Parent.ServerUtility)

-- RemoteEvents
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlotRemote = Remotes.Plot
local UIRemote = Remotes.UI
local FXRemote = Remotes.FX

-- Cache for plant modules
local PlantModules = {}

-- Initialize plant module cache
function PlantService:InitializeModules()
    local PlantsFolder = script.Parent.Plants
    for _, moduleScript in ipairs(PlantsFolder:GetChildren()) do
        if moduleScript:IsA("ModuleScript") then
            local success, result = pcall(function()
                return require(moduleScript)
            end)
            if success then
                PlantModules[moduleScript.Name] = result
            else
                warn("[PlantService] Failed to load plant module:", moduleScript.Name, result)
            end
        end
    end
end

-- Get plant module by name
function PlantService:GetPlantModule(plantName)
    return PlantModules[plantName]
end

-- Get player's plot instance
function PlantService:GetPlayerPlot(player)
    local Plot = require(script.Parent)
    for _, plot in ipairs(Plot.Plots) do
        if plot.Owner == player then
            return plot
        end
    end
    return nil
end

-- Calculate growth progress (0-1)
function PlantService:CalculateGrowthProgress(plantData)
    if not plantData or not plantData.PlantTimestamp then return 0 end
    
    local timeBuffer = BitBuffer.Create()
    timeBuffer:FromBase64(plantData.PlantTimestamp)
    local timePlaced = timeBuffer:ReadFloat64()
    
    local plantModule = self:GetPlantModule(plantData.Name)
    if not plantModule then return 0 end
    
    local elapsed = workspace:GetServerTimeNow() - timePlaced
    return math.clamp(elapsed / plantModule.GrowthTime, 0, 1)
end

-- Check if plant is fully grown
function PlantService:IsPlantMature(plantData)
    return self:CalculateGrowthProgress(plantData) >= 1
end

-- Get sprinkler multiplier for a position
function PlantService:GetSprinklerMultiplier(player, position)
    local plot = self:GetPlayerPlot(player)
    if not plot then return 1 end
    
    local multiplier = 1
    local sprinklerTypesSeen = {}
    
    for gearID, gearData in pairs(plot.OwnerData.PlotGears or {}) do
        local gearInfo = GearsData[gearData.Name]
        
        if gearInfo and gearInfo.PlaceableData and gearInfo.PlaceableData.Duration then
            -- Decode position
            local posBuffer = BitBuffer.Create()
            posBuffer:FromBase64(gearData.OffsetPosition)
            local offset = Vector3.new(
                posBuffer:ReadFloat32(),
                posBuffer:ReadFloat32(),
                posBuffer:ReadFloat32()
            )
            
            local origin = plot.Folder.All.Farm1.Origin.Position
            local sprinklerPos = origin + offset
            
            -- Check if still active
            if gearData.ActivatedTime then
                local timeBuffer = BitBuffer.Create()
                timeBuffer:FromBase64(gearData.ActivatedTime)
                local activatedTime = timeBuffer:ReadFloat64()
                local endTime = activatedTime + gearInfo.PlaceableData.Duration
                
                if workspace:GetServerTimeNow() <= endTime then
                    local distance = (position - sprinklerPos).Magnitude
                    if distance <= gearInfo.PlaceableData.Radius then
                        if not sprinklerTypesSeen[gearData.Name] then
                            sprinklerTypesSeen[gearData.Name] = true
                            multiplier = multiplier * 1.5
                        end
                    end
                end
            end
        end
    end
    
    return multiplier
end

-- Request plant placement (called by client)
function PlantService:RequestPlacePlant(player, seedID, position)
    local plot = self:GetPlayerPlot(player)
    if not plot then return false, "No plot found" end
    
    local playerReplica = Data[player]
    if not playerReplica then return false, "No data found" end
    
    -- Validate seed exists in inventory
    local seedItem = playerReplica.Data.Inventory[seedID]
    if not seedItem then return false, "Seed not in inventory" end
    
    local itemData = ItemsData[seedItem.Name]
    if not itemData or itemData.Type ~= "Plant" then
        return false, "Invalid seed"
    end
    
    -- Validate position (basic bounds check)
    if typeof(position) ~= "Vector3" then
        return false, "Invalid position"
    end
    
    -- Check if position is within plot bounds
    local origin = plot.Folder.All.Farm1.Origin.Position
    local offset = position - origin
    local maxDistance = 50 -- Adjust based on plot size
    if offset.Magnitude > maxDistance then
        return false, "Position out of bounds"
    end
    
    -- Generate unique plant ID
    local plantID = HttpService:GenerateGUID(false)
    
    -- Encode position
    local posBuffer = BitBuffer.Create()
    posBuffer:WriteFloat32(offset.X)
    posBuffer:WriteFloat32(offset.Y)
    posBuffer:WriteFloat32(offset.Z)
    
    -- Encode rotation
    local rotBuffer = BitBuffer.Create()
    rotBuffer:WriteFloat32(math.random(-180, 180))
    
    -- Encode time
    local timeBuffer = BitBuffer.Create()
    timeBuffer:WriteFloat64(workspace:GetServerTimeNow())
    
    -- Generate random scale
    local randomScale = math.random() * 0.65 + 0.75 -- 0.75 to 1.4
    if math.random(1, 100) <= 3 then
        randomScale = math.random() * 0.7 + 1.5 -- 1.5 to 2.2 (lucky huge)
        UIRemote:FireClient(player, "TopNotification", {
            Text = "You just grew a HUGE plant!",
            Duration = 3,
            ShadowColor = Color3.fromRGB(235, 0, 180),
            ShadowTransparency = 0.35,
        })
    end
    
    -- Get plant module for growth time
    local plantModule = PlantModules[seedItem.Name]
    local growthTime = plantModule and plantModule.GrowthTime or 60

    -- NEW DATA STRUCTURE: Timestamp-based with Fruits table
    playerReplica:SetValue({"Plot", plantID}, {
        Name = seedItem.Name,
        OffsetPosition = posBuffer:ToBase64(),
        PlantTimestamp = timeBuffer:ToBase64(), -- When the plant was placed
        GrowthDuration = growthTime, -- How long it takes to grow
        RandomScale = randomScale,
        RandomRotation = rotBuffer:ToBase64(),
        -- NEW: Fruit data structure using timestamps
        Fruits = {},
    })
    
    -- Remove seed from inventory
    local quantity = seedItem.Quantity or 1
    if quantity <= 1 then
        playerReplica:SetValue({"Inventory", seedID}, nil)
    else
        playerReplica:SetValue({"Inventory", seedID, "Quantity"}, quantity - 1)
    end
    
    -- Remove tool if equipped
    if player.Character then
        for _, child in ipairs(player.Character:GetChildren()) do
            if child:IsA("Tool") and child:GetAttribute("ID") == seedID then
                child:Destroy()
                break
            end
        end
    end
    
    -- Schedule fruit spawn when plant matures
    local plantModule = self:GetPlantModule(seedItem.Name)
    if plantModule then
        task.delay(plantModule.GrowthTime, function()
            self:SpawnFruitWhenMature(player, plantID)
        end)
    end
    
    -- Notify client of successful placement
    PlotRemote:FireClient(player, "PlantPlaced", {
        PlantID = plantID,
        SeedName = seedItem.Name,
        Position = position,
    })
    
    return true, plantID
end

-- Spawn fruit when plant reaches maturity
function PlantService:SpawnFruitWhenMature(player, plantID)
    local playerReplica = Data[player]
    if not playerReplica then return end
    
    local plantData = playerReplica.Data.Plot[plantID]
    if not plantData then return end
    
    local plantModule = self:GetPlantModule(plantData.Name)
    if not plantModule then return end
    
    -- Check if plant still exists and is mature
    if not self:IsPlantMature(plantData) then
        -- Not mature yet, wait and check again
        local remainingTime = plantModule.GrowthTime * (1 - self:CalculateGrowthProgress(plantData))
        task.delay(remainingTime, function()
            self:SpawnFruitWhenMature(player, plantID)
        end)
        return
    end
    
    local productName = plantModule.ProductName or ItemsData[plantData.Name].Product
    if not productName then return end
    
    -- Use ServerUtility to initialize plant fruits (data-only)
    local plot = self:GetPlayerPlot(player)
    if plot then
        -- For Single type plants
        if plantModule.Type == "Single" then
            ServerUtility.SetupFruit(player, plantID, "1", playerReplica, plot, productName, plantModule)
        elseif plantModule.Type == "Spawner" then
            -- For Spawner type, we need to wait for client to provide branch count
            -- Store pending initialization
            if not plot.PendingFruitInit then
                plot.PendingFruitInit = {}
            end
            plot.PendingFruitInit[plantID] = true
            
            -- Notify client to request initialization with branch count
            PlotRemote:FireClient(player, "PlantReadyForFruits", plantID)
        end
    end
end

-- Initialize spawner fruits with known branch count
function PlantService:InitializeSpawnerFruits(player, plantID, branchCount)
    local playerReplica = Data[player]
    if not playerReplica then return end
    
    local plantData = playerReplica.Data.Plot[plantID]
    if not plantData then return end
    
    local plantModule = self:GetPlantModule(plantData.Name)
    if not plantModule or plantModule.Type ~= "Spawner" then return end
    
    local plot = self:GetPlayerPlot(player)
    if not plot then return end
    
    local productName = plantModule.ProductName
    
    -- Ensure Fruits table exists
    if not plantData.Fruits then
        plantData.Fruits = {}
    end
    
    -- Initialize each branch's fruit
    for i = 1, branchCount do
        local index = tostring(i)
        if not plantData.Fruits[index] then
            ServerUtility.SetupFruit(player, plantID, i, playerReplica, plot, productName, plantModule)
        end
    end
    
    -- Clear pending flag
    if plot.PendingFruitInit then
        plot.PendingFruitInit[plantID] = nil
    end
    
    -- Send all fruit data to client
    local clientFruitData = {}
    for index, fruitData in pairs(plantData.Fruits) do
        clientFruitData[index] = ServerUtility.GetClientFruitData(fruitData)
    end
    
    PlotRemote:FireClient(player, "FruitDataSync", {
        PlantID = plantID,
        Fruits = clientFruitData,
    })
end

-- Request fruit harvest
function PlantService:RequestHarvest(player, plantID, fruitIndex)
    if not player or not plantID or not fruitIndex then
        return false, "Invalid parameters"
    end
    
    local plot = self:GetPlayerPlot(player)
    if not plot then return false, "No plot found" end
    
    -- Delegate to plot's harvest function
    return plot:RequestFruitHarvest(plantID, fruitIndex)
end

-- Toggle favorite status
function PlantService:ToggleFavorite(player, plantID, fruitIndex)
    local playerReplica = Data[player]
    if not playerReplica then return false end
    
    local plantData = playerReplica.Data.Plot[plantID]
    if not plantData then return false end
    
    local fruitData = plantData.Fruits[tostring(fruitIndex)]
    if not fruitData then return false end
    
    local newStatus = not fruitData.Favorited
    playerReplica:SetValue({"Plot", plantID, "Fruits", tostring(fruitIndex), "Favorited"}, newStatus)
    
    return true, newStatus
end

-- Remove plant
function PlantService:RemovePlant(player, plantID)
    local playerReplica = Data[player]
    if not playerReplica then return false end
    
    local plantData = playerReplica.Data.Plot[plantID]
    if not plantData then return false end
    
    -- Clean up ActiveFruit handlers for this plant
    if plantData.Fruits then
        for fruitIndex, _ in pairs(plantData.Fruits) do
            local fruitKey = plantID .. tostring(fruitIndex)
            if ServerUtility.ActiveFruit[fruitKey] then
                ServerUtility.ActiveFruit[fruitKey] = nil
            end
        end
    end
    
    -- Get seed name to return
    local seedName = plantData.Name
    
    -- Remove all plant data
    playerReplica:SetValue({"Plot", plantID}, nil)
    
    -- Return seed to inventory (optional, based on game design)
    local newItemID = HttpService:GenerateGUID(false)
    playerReplica:SetValue({"Inventory", newItemID}, {
        ID = newItemID,
        Name = seedName,
        Quantity = 1,
    })
    
    -- Notify client
    PlotRemote:FireClient(player, "PlantRemoved", {
        PlantID = plantID,
    })
    
    return true
end

-- Handle existing plants on player join
function PlantService:HandlePlayerJoin(player)
    local playerReplica = Data[player]
    if not playerReplica then return end
    
    -- Schedule fruit spawns for any mature plants that need them
    for plantID, plantData in pairs(playerReplica.Data.Plot or {}) do
        if typeof(plantData) == "table" and plantData.Name then
            local plantModule = self:GetPlantModule(plantData.Name)
            if plantModule then
                -- Check if plant is mature but has no fruits
                if self:IsPlantMature(plantData) then
                    local hasFruits = plantData.Fruits and next(plantData.Fruits) ~= nil
                    
                    if not hasFruits then
                        self:SpawnFruitWhenMature(player, plantID)
                    end
                else
                    -- Schedule fruit spawn when it matures
                    local progress = self:CalculateGrowthProgress(plantData)
                    local remainingTime = plantModule.GrowthTime * (1 - progress)
                    task.delay(remainingTime, function()
                        self:SpawnFruitWhenMature(player, plantID)
                    end)
                end
            end
        end
    end
end

-- Initialize RemoteEvent handlers
function PlantService:InitializeRemotes()
    -- Handle plant placement requests
    PlotRemote.OnServerEvent:Connect(function(player, action, data)
        if action == "RequestPlacePlant" then
            local success, result = self:RequestPlacePlant(
                player, 
                data and data.SeedID, 
                data and data.Position
            )
            -- Send result back to client
            PlotRemote:FireClient(player, "PlacePlantResult", {
                Success = success,
                PlantID = success and result or nil,
                Error = not success and result or nil,
            })
            
        elseif action == "RequestHarvest" then
            local success, result = self:RequestHarvest(
                player,
                data and data.PlantID,
                data and data.FruitIndex
            )
            PlotRemote:FireClient(player, "HarvestResult", {
                Success = success,
                Data = success and result or nil,
                Error = not success and result or nil,
            })
            
        elseif action == "RequestRemovePlant" then
            local success = self:RemovePlant(player, data and data.PlantID)
            PlotRemote:FireClient(player, "RemovePlantResult", {
                Success = success,
                PlantID = data and data.PlantID,
            })
            
        elseif action == "RequestInitializeFruits" then
            -- Client is ready to initialize fruits for a spawner plant
            local plantID = data and data.PlantID
            local branchCount = data and data.BranchCount
            if plantID and branchCount then
                self:InitializeSpawnerFruits(player, plantID, branchCount)
            end
        end
    end)
    
    -- Handle favorite toggles
    local favoriteRemote = Remotes:FindFirstChild("FavoriteFruit")
    if favoriteRemote then
        favoriteRemote.OnServerEvent:Connect(function(player, plantID, fruitIndex)
            self:ToggleFavorite(player, plantID, fruitIndex)
        end)
    end
end

-- Initialize the service
function PlantService:Initialize()
    self:InitializeModules()
    self:InitializeRemotes()
    
    print("[PlantService] Initialized successfully with timestamp-based fruit system")
end

return PlantService
