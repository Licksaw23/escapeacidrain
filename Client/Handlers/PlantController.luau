--[[
    PlantController.luau - Client-side plant visual controller
    Handles rendering plants based on server Replica data
    
    Location: Client/Handlers/PlantController.luau
    
    INTEGRATION NOTE: This works with Server/Game/Plot/PlantService.luau
    and Client/Game/PlantSystem.luau for visual management.
--]]

local PlantController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Module references (loaded on init)
local BitBuffer
local ItemsData
local PlantSystem -- Will be loaded from Client/Game

-- RemoteEvents
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlotRemote = Remotes.Plot
local FXRemote = Remotes.FX

-- Constants
local GROWTH_UPDATE_RATE = 0.1 -- seconds between growth checks
local PLANT_MODELS_PATH = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Models"):WaitForChild("Plants")

-- State
local activePlants = {} -- plantID -> {model, data, module, connections}
local plantConnections = {} -- plantID -> {growthConnection}
local replicaListener = nil
local plotFolder = nil

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Decode BitBuffer position
local function decodePosition(base64String, origin)
    if not BitBuffer then return origin end
    
    local buffer = BitBuffer.Create()
    buffer:FromBase64(base64String)
    local offset = Vector3.new(
        buffer:ReadFloat32(),
        buffer:ReadFloat32(),
        buffer:ReadFloat32()
    )
    return origin + offset
end

-- Decode BitBuffer rotation
local function decodeRotation(base64String)
    if not BitBuffer then return 0 end
    
    local buffer = BitBuffer.Create()
    buffer:FromBase64(base64String)
    return buffer:ReadFloat32()
end

-- Decode BitBuffer time
local function decodeTime(base64String)
    if not BitBuffer then return workspace:GetServerTimeNow() end
    
    local buffer = BitBuffer.Create()
    buffer:FromBase64(base64String)
    return buffer:ReadFloat64()
end

-- Calculate growth progress
local function calculateGrowthProgress(plantData)
    local timePlaced = decodeTime(plantData.TimePlaced)
    local growthTime = ItemsData[plantData.Name] and ItemsData[plantData.Name].GrowthTime or 60
    
    local elapsed = workspace:GetServerTimeNow() - timePlaced
    return math.clamp(elapsed / growthTime, 0, 1)
end

-- Get plant module
local function getPlantModule(plantName)
    local modulePath = ReplicatedStorage.Game.Modules.Utilities.GrowPlant:FindFirstChild(plantName)
    if modulePath then
        local success, result = pcall(function()
            return require(modulePath)
        end)
        if success then return result end
    end
    return nil
end

-- ============================================================================
-- PLANT VISUAL MANAGEMENT
-- ============================================================================

-- Create plant model
function PlantController.CreatePlantVisual(plantID, plantData)
    if activePlants[plantID] then
        return -- Already exists
    end
    
    local plantName = plantData.Name
    local template = PLANT_MODELS_PATH:FindFirstChild(plantName)
    if not template then
        warn("[PlantController] Plant template not found:", plantName)
        return
    end
    
    -- Get plot origin
    local plot = LocalPlayer:GetAttribute("Plot")
    if not plot then
        warn("[PlantController] Player has no plot assigned")
        return
    end
    
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return end
    
    local playerPlot = plotsFolder:FindFirstChild(tostring(plot))
    if not playerPlot then return end
    
    if not plotFolder then
        plotFolder = playerPlot:FindFirstChild("Plants")
        if not plotFolder then
            plotFolder = Instance.new("Folder")
            plotFolder.Name = "Plants"
            plotFolder.Parent = playerPlot
        end
    end
    
    local origin = playerPlot:FindFirstChild("All"):FindFirstChild("Farm1"):FindFirstChild("Origin")
    if not origin then return end
    
    -- Clone and position
    local model = template:Clone()
    model.Name = plantID
    
    local position = decodePosition(plantData.OffsetPosition, origin.Position)
    local rotation = decodeRotation(plantData.RandomRotation)
    
    model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0))
    
    -- Apply scale if spawner type
    local plantModule = getPlantModule(plantName)
    if plantModule and plantModule.Type == "Spawner" then
        model:ScaleTo(plantData.RandomScale or 1)
    end
    
    model.Parent = plotFolder
    
    -- Calculate initial growth
    local progress = calculateGrowthProgress(plantData)
    local isMature = progress >= 1
    
    -- Apply initial visibility based on growth
    if not isMature then
        -- Hide all parts initially
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name ~= "MUTATIONVFX" then
                desc.Transparency = 1
            end
        end
    else
        -- Show all parts
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name ~= "MUTATIONVFX" then
                desc.Transparency = 0
            end
        end
    end
    
    -- Store plant data
    activePlants[plantID] = {
        model = model;
        data = plantData;
        module = plantModule;
        currentStage = isMature and 4 or 0;
        isMature = isMature;
        fruits = {};
    }
    
    -- Start growth updates if not mature
    if not isMature then
        PlantController.StartGrowthUpdates(plantID)
    end
    
    return model
end

-- Remove plant visual
function PlantController.RemovePlantVisual(plantID)
    local plantEntry = activePlants[plantID]
    if not plantEntry then return end
    
    -- Stop growth updates
    if plantConnections[plantID] then
        plantConnections[plantID]:Disconnect()
        plantConnections[plantID] = nil
    end
    
    -- Remove fruits
    for fruitID, _ in pairs(plantEntry.fruits) do
        PlantController.RemoveFruitVisual(plantID, fruitID)
    end
    
    -- Fade out and destroy
    local model = plantEntry.model
    if model then
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") then
                TweenService:Create(desc, TweenInfo.new(0.3), {
                    Transparency = 1
                }):Play()
            end
        end
        
        task.delay(0.3, function()
            if model and model.Parent then
                model:Destroy()
            end
        end)
    end
    
    activePlants[plantID] = nil
end

-- Start growth update loop for a plant
function PlantController.StartGrowthUpdates(plantID)
    local plantEntry = activePlants[plantID]
    if not plantEntry then return end
    
    if plantConnections[plantID] then
        plantConnections[plantID]:Disconnect()
    end
    
    plantConnections[plantID] = RunService.Heartbeat:Connect(function()
        local entry = activePlants[plantID]
        if not entry or entry.isMature then
            if plantConnections[plantID] then
                plantConnections[plantID]:Disconnect()
                plantConnections[plantID] = nil
            end
            return
        end
        
        local progress = calculateGrowthProgress(entry.data)
        local stage = math.floor(progress * 4)
        
        if stage > entry.currentStage then
            entry.currentStage = stage
            PlantController.ApplyGrowthStage(plantID, stage, progress)
        end
        
        if progress >= 1 then
            entry.isMature = true
            PlantController.OnPlantMatured(plantID)
        end
    end)
end

-- Apply growth stage visuals
function PlantController.ApplyGrowthStage(plantID, stage, progress)
    local entry = activePlants[plantID]
    if not entry then return end
    
    local model = entry.model
    if not model then return end
    
    -- Use plant module's UpdateGrowth if available
    if entry.module and entry.module.UpdateGrowth then
        entry.module.UpdateGrowth(model, progress, stage - 1)
        return
    end
    
    -- Fallback growth visualization
    -- Stage 1: Show stem
    if stage >= 1 then
        local stem = model:FindFirstChild("Stem", true)
        if stem and stem:IsA("BasePart") then
            TweenService:Create(stem, TweenInfo.new(1.5), {
                Transparency = 0
            }):Play()
        end
    end
    
    -- Stage 2-4: Gradually show more parts
    if stage >= 2 then
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name ~= "MUTATIONVFX" then
                local currentTrans = desc.Transparency
                if currentTrans > 0 then
                    TweenService:Create(desc, TweenInfo.new(2), {
                        Transparency = 0
                    }):Play()
                end
            end
        end
    end
end

-- Called when plant reaches maturity
function PlantController.OnPlantMatured(plantID)
    local entry = activePlants[plantID]
    if not entry then return end
    
    -- Sparkle effect
    local primaryPart = entry.model.PrimaryPart or entry.model:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        local sparkles = Instance.new("Sparkles")
        sparkles.Color = Color3.fromRGB(255, 255, 100)
        sparkles.Parent = primaryPart
        
        task.delay(2, function()
            if sparkles and sparkles.Parent then
                sparkles:Destroy()
            end
        end)
    end
end

-- ============================================================================
-- FRUIT VISUAL MANAGEMENT
-- ============================================================================

-- Create fruit visual
function PlantController.CreateFruitVisual(plantID, fruitIndex, fruitData)
    local plantEntry = activePlants[plantID]
    if not plantEntry then return end
    
    -- Get product name
    local plantData = plantEntry.data
    local itemData = ItemsData[plantData.Name]
    local productName = itemData and itemData.Product
    if not productName then return end
    
    -- Get fruit model
    local fruitTemplate = PLANT_MODELS_PATH:FindFirstChild(productName)
    if not fruitTemplate then
        -- Try in a Fruits folder
        local fruitsFolder = ReplicatedStorage.Game.Models:FindFirstChild("Fruits")
        if fruitsFolder then
            fruitTemplate = fruitsFolder:FindFirstChild(productName)
        end
    end
    if not fruitTemplate then return end
    
    -- Clone fruit
    local fruitModel = fruitTemplate:Clone()
    fruitModel.Name = productName .. "_" .. tostring(fruitIndex)
    
    -- Find spawn position
    local spawnPosition = nil
    local spawnCFrame = nil
    
    if plantEntry.module and plantEntry.module.GetBranches then
        local branches = plantEntry.module.GetBranches(plantEntry.model)
        for _, branch in ipairs(branches) do
            if tostring(branch.Index) == tostring(fruitIndex) then
                spawnCFrame = branch.Part.CFrame
                break
            end
        end
    end
    
    if not spawnCFrame then
        -- Fallback: use plant position
        local primary = plantEntry.model.PrimaryPart
        if primary then
            spawnCFrame = primary.CFrame + Vector3.new(0, 2, 0)
        end
    end
    
    if spawnCFrame then
        fruitModel:PivotTo(spawnCFrame)
    end
    
    fruitModel.Parent = plantEntry.model
    
    -- Scale fruit based on weight
    if fruitData.Weight then
        local scale = 0.8 + (fruitData.Weight / 10) -- Adjust formula as needed
        fruitModel:ScaleTo(math.clamp(scale, 0.5, 2))
    end
    
    -- Create harvest prompt (not for favorited fruits)
    local prompt = nil
    if not fruitData.Favorited then
        local part = fruitModel:FindFirstChild("Part") or fruitModel.PrimaryPart
        if part then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name = "HarvestPrompt"
            prompt.ActionText = "Collect"
            prompt.ObjectText = productName
            prompt.HoldDuration = 0.5
            prompt.MaxActivationDistance = 8
            prompt.RequiresLineOfSight = false
            prompt.Parent = part
            
            prompt.Triggered:Connect(function(player)
                if player == LocalPlayer then
                    PlantController.RequestHarvest(plantID, fruitIndex)
                end
            end)
        end
    end
    
    -- Apply mutation visuals
    if fruitData.Mutations then
        for _, mutationName in ipairs(fruitData.Mutations) do
            FXRemote:FireServer("ApplyMutation", {
                Model = fruitModel;
                Mutation = mutationName;
            })
        end
    end
    
    -- Spawn animation
    for _, desc in ipairs(fruitModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            local originalSize = desc.Size
            desc.Size = Vector3.zero
            TweenService:Create(desc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = originalSize
            }):Play()
        end
    end
    
    -- Store fruit reference
    plantEntry.fruits[tostring(fruitIndex)] = {
        model = fruitModel;
        prompt = prompt;
        data = fruitData;
    }
end

-- Remove fruit visual
function PlantController.RemoveFruitVisual(plantID, fruitIndex)
    local plantEntry = activePlants[plantID]
    if not plantEntry then return end
    
    local fruit = plantEntry.fruits[tostring(fruitIndex)]
    if not fruit then return end
    
    local model = fruit.model
    if model then
        -- Shrink animation
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") then
                TweenService:Create(desc, TweenInfo.new(0.2), {
                    Size = Vector3.zero
                }):Play()
            end
        end
        
        task.delay(0.2, function()
            if model and model.Parent then
                model:Destroy()
            end
        end)
    end
    
    plantEntry.fruits[tostring(fruitIndex)] = nil
end

-- Request harvest from server
function PlantController.RequestHarvest(plantID, fruitIndex)
    PlotRemote:FireServer("RequestHarvest", {
        PlantID = plantID;
        FruitIndex = fruitIndex;
    })
end

-- ============================================================================
-- REPLICA DATA LISTENERS
-- ============================================================================

-- Setup replica listeners for plant data changes
function PlantController.SetupReplicaListeners()
    -- Wait for PlayerReplica to be available
    local PlayerReplica = nil
    local retries = 0
    
    repeat
        PlayerReplica = ReplicatedStorage:FindFirstChild("PlayerReplica")
        if not PlayerReplica then
            -- Try alternative path
            local success, result = pcall(function()
                return require(ReplicatedStorage:WaitForChild("ServerPlayerData"))
            end)
            if success and result and result[LocalPlayer] then
                PlayerReplica = result[LocalPlayer]
            end
        end
        if not PlayerReplica then
            task.wait(0.1)
            retries = retries + 1
        end
    until PlayerReplica or retries > 50
    
    if not PlayerReplica then
        warn("[PlantController] Could not find PlayerReplica")
        return
    end
    
    -- Get replica for local player
    local playerReplica = nil
    if typeof(PlayerReplica) == "table" and PlayerReplica[LocalPlayer] then
        playerReplica = PlayerReplica[LocalPlayer]
    elseif PlayerReplica:IsA("ModuleScript") then
        local dataModule = require(PlayerReplica)
        playerReplica = dataModule[LocalPlayer]
    end
    
    if not playerReplica then
        warn("[PlantController] Could not get player replica")
        return
    end
    
    -- Wait for data to be ready
    if not playerReplica.Data then
        local dataReady = false
        local connection = playerReplica:ListenToWrite("DataReady", function()
            dataReady = true
        end)
        
        retries = 0
        repeat
            task.wait(0.1)
            retries = retries + 1
        until (playerReplica.Data and playerReplica.Data.Plot) or retries > 100
        
        if connection then connection:Disconnect() end
    end
    
    if not playerReplica.Data or not playerReplica.Data.Plot then
        warn("[PlantController] No plot data available")
        return
    end
    
    -- Sync existing plants
    for plantID, plantData in pairs(playerReplica.Data.Plot) do
        if typeof(plantData) == "table" and plantData.Name then
            PlantController.CreatePlantVisual(plantID, plantData)
            
            -- Check for existing fruits
            for key, value in pairs(plantData) do
                if tonumber(key) or (tostring(key):match("^%d+$")) then
                    PlantController.CreateFruitVisual(plantID, key, value)
                end
            end
        end
    end
    
    -- Listen for data changes
    replicaListener = playerReplica:ListenToRaw(function(action, path, newValue, oldValue)
        if path[1] ~= "Plot" then return end
        
        local plantID = path[2]
        if not plantID then return end
        
        if #path == 2 then
            -- Plant added or removed
            if newValue and typeof(newValue) == "table" and newValue.Name then
                -- Plant added
                PlantController.CreatePlantVisual(plantID, newValue)
            elseif oldValue then
                -- Plant removed
                PlantController.RemovePlantVisual(plantID)
            end
            
        elseif #path == 3 then
            -- Fruit added or removed
            local fruitIndex = path[3]
            
            if newValue and typeof(newValue) == "table" then
                -- Fruit added
                PlantController.CreateFruitVisual(plantID, fruitIndex, newValue)
            elseif oldValue then
                -- Fruit removed
                PlantController.RemoveFruitVisual(plantID, fruitIndex)
            end
            
            -- Check for favorite status change
            if newValue and typeof(newValue) == "boolean" and fruitIndex == "Favorited" then
                -- Handle favorite toggle
                local plantEntry = activePlants[plantID]
                if plantEntry then
                    local fruit = plantEntry.fruits[tostring(path[2])]
                    if fruit and fruit.prompt then
                        fruit.prompt.Enabled = not newValue
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- REMOTE EVENT HANDLERS
-- ============================================================================

-- Setup remote event handlers
function PlantController.SetupRemoteHandlers()
    -- Handle server notifications
    PlotRemote.OnClientEvent:Connect(function(action, data)
        if action == "PlantPlaced" then
            -- Server confirmed plant placement
            -- Visual was already created via replica, this is just confirmation
            
        elseif action == "HarvestResult" then
            if not data.Success then
                -- Show error notification
                local errorGui = PlayerGui:FindFirstChild("PlantErrorUI")
                if not errorGui then
                    errorGui = Instance.new("ScreenGui")
                    errorGui.Name = "PlantErrorUI"
                    errorGui.ResetOnSpawn = false
                    errorGui.Parent = PlayerGui
                    
                    local frame = Instance.new("Frame")
                    frame.Name = "ErrorFrame"
                    frame.Size = UDim2.new(0, 300, 0, 60)
                    frame.Position = UDim2.new(0.5, -150, 0, -80)
                    frame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                    frame.BorderSizePixel = 0
                    frame.Parent = errorGui
                    
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 8)
                    corner.Parent = frame
                    
                    local label = Instance.new("TextLabel")
                    label.Name = "ErrorLabel"
                    label.Size = UDim2.new(1, -20, 1, 0)
                    label.Position = UDim2.new(0, 10, 0, 0)
                    label.BackgroundTransparency = 1
                    label.TextColor3 = Color3.new(1, 1, 1)
                    label.TextScaled = true
                    label.Font = Enum.Font.GothamBold
                    label.Parent = frame
                end
                
                local label = errorGui.ErrorFrame.ErrorLabel
                label.Text = data.Error or "Harvest failed!"
                
                TweenService:Create(errorGui.ErrorFrame, TweenInfo.new(0.3), {
                    Position = UDim2.new(0.5, -150, 0.1, 0)
                }):Play()
                
                task.delay(2.5, function()
                    if errorGui and errorGui.Parent then
                        TweenService:Create(errorGui.ErrorFrame, TweenInfo.new(0.3), {
                            Position = UDim2.new(0.5, -150, 0, -80)
                        }):Play()
                    end
                end)
            end
        end
    end)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Initialize the controller
function PlantController.Initialize()
    -- Load dependencies
    local success, result = pcall(function()
        BitBuffer = require(ReplicatedStorage.Game.Modules.Utilities.BitBuffer)
        ItemsData = require(ReplicatedStorage.Game.Modules.Libraries.ItemsData)
    end)
    
    if not success then
        warn("[PlantController] Failed to load dependencies:", result)
        return
    end
    
    -- Try to load PlantSystem for additional functionality
    success, result = pcall(function()
        return require(game:GetService("ReplicatedFirst").Client.Game.PlantSystem)
    end)
    if success then
        PlantSystem = result
    end
    
    -- Setup handlers
    PlantController.SetupRemoteHandlers()
    
    -- Setup replica listeners (delayed to ensure data is loaded)
    task.delay(1, function()
        PlantController.SetupReplicaListeners()
    end)
    
    -- Cleanup on player leaving
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if player == LocalPlayer then
            -- Clean up connections
            if replicaListener then
                replicaListener:Disconnect()
            end
            for _, conn in pairs(plantConnections) do
                conn:Disconnect()
            end
            table.clear(plantConnections)
            table.clear(activePlants)
        end
    end)
    
    print("[PlantController] Initialized")
end

return PlantController
