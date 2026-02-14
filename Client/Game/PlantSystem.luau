--[[
    PlantSystem.luau - Client-side plant visual system
    Handles all plant rendering, growth animations, and interactions
    
    Location: Client/Game/PlantSystem.luau
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Local player reference
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- RemoteEvents (assumed to exist in ReplicatedStorage.Remotes or similar)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlantRemotes = {
    RequestPlantData = Remotes:WaitForChild("RequestPlantData"),
    PlantAdded = Remotes:WaitForChild("PlantAdded"),
    PlantRemoved = Remotes:WaitForChild("PlantRemoved"),
    PlantHarvested = Remotes:WaitForChild("PlantHarvested"),
    HarvestFruit = Remotes:WaitForChild("HarvestFruit"),
    PlantSeed = Remotes:WaitForChild("PlantSeed")
}

-- Module
local PlantSystem = {}

-- State management
local activePlants = {} -- plantID -> {model, data, connection}
local activeFruits = {} -- fruitID -> {model, parentPlantID, data}
local growthConnections = {} -- plantID -> RunService connection

-- Constants
local GROWTH_CHECK_INTERVAL = 0.1 -- seconds between growth updates
local HARVEST_PROMPT_DISTANCE = 8
local PLANT_MODELS_PATH = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Models"):WaitForChild("Plants")
local FRUIT_MODELS_PATH = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Models"):WaitForChild("Fruits")

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
    Calculate growth progress (0-1) based on planted time and growth duration
--]]
local function calculateGrowthProgress(plantData)
    local currentTime = tick()
    local plantedAt = plantData.PlantedAt or currentTime
    local growthTime = plantData.GrowthTime or 60
    
    local elapsed = currentTime - plantedAt
    local progress = math.clamp(elapsed / growthTime, 0, 1)
    
    return progress
end

--[[
    Apply visual state based on growth progress
--]]
local function applyGrowthVisuals(plantModel, progress, plantData)
    if not plantModel or not plantModel.PrimaryPart then
        return
    end
    
    -- Scale the plant based on growth progress
    local baseScale = plantData.BaseScale or 1
    local minScale = 0.2 -- Start at 20% size
    local targetScale = minScale + (baseScale - minScale) * progress
    
    -- Smooth scale transition
    local currentScale = plantModel:GetAttribute("CurrentScale") or minScale
    local smoothScale = currentScale + (targetScale - currentScale) * 0.1
    plantModel:SetAttribute("CurrentScale", smoothScale)
    
    -- Apply scale to all parts
    for _, part in ipairs(plantModel:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Use original size stored in attributes
            local originalSize = part:GetAttribute("OriginalSize")
            if not originalSize then
                originalSize = part.Size
                part:SetAttribute("OriginalSize", originalSize)
            end
            part.Size = originalSize * smoothScale
        end
    end
    
    -- Growth stage visualization
    local growthStage = math.floor(progress * 4) -- 0-4 stages
    plantModel:SetAttribute("GrowthStage", growthStage)
    
    -- Color shift from seedling (green) to mature
    for _, part in ipairs(plantModel:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("CanColorShift") then
            local seedlingColor = plantData.SeedlingColor or Color3.fromRGB(144, 238, 144)
            local matureColor = plantData.MatureColor or part.Color
            part.Color = seedlingColor:Lerp(matureColor, progress)
        end
    end
    
    -- Particle effects when growing
    if progress < 1 and plantModel:GetAttribute("LastProgress") ~= growthStage then
        plantModel:SetAttribute("LastProgress", growthStage)
        -- Trigger growth particle effect here if needed
    end
    
    return smoothScale >= baseScale * 0.99 -- Returns true if fully grown
end

--[[
    Create harvest proximity prompt for a fruit
--]]
local function createHarvestPrompt(fruitModel, plantID, fruitID)
    if fruitModel:FindFirstChild("HarvestPrompt") then
        return
    end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "HarvestPrompt"
    prompt.ActionText = "Harvest"
    prompt.ObjectText = fruitModel:GetAttribute("FruitName") or "Fruit"
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = HARVEST_PROMPT_DISTANCE
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Style = Enum.ProximityPromptStyle.Default
    
    -- Attach to primary part or create attachment point
    local attachmentParent = fruitModel:FindFirstChildWhichIsA("BasePart") or fruitModel.PrimaryPart
    if attachmentParent then
        prompt.Parent = attachmentParent
    else
        prompt.Parent = fruitModel
    end
    
    -- Handle harvest interaction
    prompt.Triggered:Connect(function(player)
        if player == LocalPlayer then
            PlantSystem.handleHarvest(plantID, fruitID)
        end
    end)
    
    return prompt
end

--[[
    Play harvest effects
--]]
local function playHarvestEffects(fruitPosition)
    -- Particle burst effect
    local burst = Instance.new("ParticleEmitter")
    burst.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
    burst.Size = NumberSequence.new(1, 0)
    burst.Lifetime = NumberRange.new(0.5, 1)
    burst.Speed = NumberRange.new(5, 10)
    burst.Rate = 0
    burst.Acceleration = Vector3.new(0, -20, 0)
    burst.SpreadAngle = Vector2.new(45, 45)
    burst.BurstCount = 20
    
    local attachment = Instance.new("Attachment")
    attachment.WorldPosition = fruitPosition
    attachment.Parent = workspace.Terrain
    burst.Parent = attachment
    
    burst:Emit(20)
    
    -- Clean up after effect plays
    task.delay(1.5, function()
        attachment:Destroy()
    end)
    
    -- Sound effect
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9114488953" -- Pop/harvest sound
    sound.Volume = 0.5
    sound.Parent = attachment
    sound:Play()
end

--[[
    Show error UI notification
--]]
local function showErrorUI(message)
    -- Check for existing error UI
    local errorGui = PlayerGui:FindFirstChild("PlantErrorUI")
    if not errorGui then
        errorGui = Instance.new("ScreenGui")
        errorGui.Name = "PlantErrorUI"
        errorGui.ResetOnSpawn = false
        errorGui.Parent = PlayerGui
        
        local frame = Instance.new("Frame")
        frame.Name = "ErrorFrame"
        frame.Size = UDim2.new(0, 300, 0, 60)
        frame.Position = UDim2.new(0.5, -150, 0.1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        frame.BackgroundTransparency = 0.2
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
    label.Text = message
    
    -- Animate in
    errorGui.ErrorFrame.Position = UDim2.new(0.5, -150, 0, -80)
    TweenService:Create(errorGui.ErrorFrame, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -150, 0.1, 0)
    }):Play()
    
    -- Auto hide
    task.delay(2.5, function()
        if errorGui and errorGui.Parent then
            TweenService:Create(errorGui.ErrorFrame, TweenInfo.new(0.3), {
                Position = UDim2.new(0.5, -150, 0, -80)
            }):Play()
            task.delay(0.3, function()
                if errorGui and errorGui.Parent then
                    errorGui:Destroy()
                end
            end)
        end
    end)
end

-- ============================================================================
-- MAIN FUNCTIONS
-- ============================================================================

--[[
    spawnPlant(plantID, plantData)
    Clones and positions a plant model with initial growth state
--]]
function PlantSystem.spawnPlant(plantID, plantData)
    -- Validate input
    if not plantID or not plantData then
        warn("[PlantSystem] Invalid plant data for ID:", plantID)
        return nil
    end
    
    -- Check if already exists
    if activePlants[plantID] then
        warn("[PlantSystem] Plant already exists:", plantID)
        return activePlants[plantID].model
    end
    
    -- Get plant model
    local plantType = plantData.PlantType or "DefaultPlant"
    local plantTemplate = PLANT_MODELS_PATH:FindFirstChild(plantType)
    
    if not plantTemplate then
        warn("[PlantSystem] Plant model not found:", plantType)
        return nil
    end
    
    -- Clone and setup
    local plantModel = plantTemplate:Clone()
    plantModel.Name = plantType .. "_" .. tostring(plantID)
    
    -- Position the plant
    local position = plantData.Position
    if typeof(position) == "Vector3" then
        if plantModel.PrimaryPart then
            plantModel:SetPrimaryPartCFrame(CFrame.new(position))
        else
            plantModel:PivotTo(CFrame.new(position))
        end
    end
    
    -- Parent to workspace
    plantModel.Parent = workspace:FindFirstChild("Plants") or workspace
    
    -- Calculate initial growth progress
    local progress = calculateGrowthProgress(plantData)
    
    -- Apply initial visual state
    local isMature = applyGrowthVisuals(plantModel, progress, plantData)
    
    -- Store plant data
    activePlants[plantID] = {
        model = plantModel,
        data = plantData,
        plantedAt = plantData.PlantedAt,
        growthTime = plantData.GrowthTime,
        isMature = isMature,
        fruits = {}
    }
    
    -- Start growth animation if not mature
    if not isMature then
        PlantSystem.updateGrowthVisuals(plantID)
    end
    
    -- If already mature, check for fruits
    if isMature and plantData.Fruits then
        for fruitID, fruitData in pairs(plantData.Fruits) do
            PlantSystem.spawnFruit(plantID, fruitData)
        end
    end
    
    return plantModel
end

--[[
    updateGrowthVisuals(plantID)
    Smoothly animates plant growth using RunService
--]]
function PlantSystem.updateGrowthVisuals(plantID)
    local plantEntry = activePlants[plantID]
    if not plantEntry then
        return
    end
    
    -- Clean up existing connection
    if growthConnections[plantID] then
        growthConnections[plantID]:Disconnect()
        growthConnections[plantID] = nil
    end
    
    -- Create new growth update connection
    growthConnections[plantID] = RunService.Heartbeat:Connect(function()
        local entry = activePlants[plantID]
        if not entry or entry.isMature then
            if growthConnections[plantID] then
                growthConnections[plantID]:Disconnect()
                growthConnections[plantID] = nil
            end
            return
        end
        
        -- Calculate current progress
        local progress = calculateGrowthProgress(entry.data)
        
        -- Apply visual updates
        local nowMature = applyGrowthVisuals(entry.model, progress, entry.data)
        
        -- Check if just reached maturity
        if nowMature and not entry.isMature then
            entry.isMature = true
            -- Trigger maturity effects
            PlantSystem.onPlantMatured(plantID)
        end
    end)
end

--[[
    Called when a plant reaches full maturity
--]]
function PlantSystem.onPlantMatured(plantID)
    local entry = activePlants[plantID]
    if not entry then
        return
    end
    
    -- Maturity particle effect
    local primaryPart = entry.model.PrimaryPart
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
    
    -- Request server to spawn fruits if applicable
    -- This is handled by server, but we can listen for fruit spawn events
end

--[[
    spawnFruit(plantID, fruitData)
    Spawns a harvestable fruit on a mature plant
--]]
function PlantSystem.spawnFruit(plantID, fruitData)
    local plantEntry = activePlants[plantID]
    if not plantEntry then
        warn("[PlantSystem] Cannot spawn fruit - plant not found:", plantID)
        return nil
    end
    
    local fruitID = fruitData.FruitID or (tostring(plantID) .. "_" .. tostring(tick()))
    
    -- Check if fruit already exists
    if activeFruits[fruitID] then
        return activeFruits[fruitID].model
    end
    
    -- Get fruit model
    local fruitType = fruitData.FruitType or "DefaultFruit"
    local fruitTemplate = FRUIT_MODELS_PATH:FindFirstChild(fruitType)
    
    if not fruitTemplate then
        warn("[PlantSystem] Fruit model not found:", fruitType)
        return nil
    end
    
    -- Clone fruit
    local fruitModel = fruitTemplate:Clone()
    fruitModel.Name = fruitType .. "_" .. tostring(fruitID)
    fruitModel:SetAttribute("FruitName", fruitData.Name or fruitType)
    fruitModel:SetAttribute("FruitID", fruitID)
    fruitModel:SetAttribute("PlantID", plantID)
    
    -- Position fruit on plant
    local fruitPosition = fruitData.Position
    if not fruitPosition and plantEntry.model then
        -- Find a spawn point on the plant
        local spawnPoints = {}
        for _, obj in ipairs(plantEntry.model:GetDescendants()) do
            if obj:IsA("Attachment") and obj.Name:find("FruitPoint") then
                table.insert(spawnPoints, obj)
            end
        end
        
        if #spawnPoints > 0 then
            local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
            fruitPosition = spawnPoint.WorldPosition
            fruitModel:PivotTo(CFrame.new(fruitPosition) * spawnPoint.WorldCFrame.Rotation)
        else
            -- Fallback: position near top of plant
            local primaryPart = plantEntry.model.PrimaryPart
            if primaryPart then
                fruitPosition = primaryPart.Position + Vector3.new(0, primaryPart.Size.Y * 0.5, 0)
            end
        end
    end
    
    if fruitPosition then
        fruitModel:PivotTo(CFrame.new(fruitPosition))
    end
    
    -- Parent fruit
    fruitModel.Parent = plantEntry.model
    
    -- Spawn animation (scale up)
    for _, part in ipairs(fruitModel:GetDescendants()) do
        if part:IsA("BasePart") then
            local originalSize = part.Size
            part:SetAttribute("OriginalSize", originalSize)
            part.Size = Vector3.zero
            
            TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = originalSize
            }):Play()
        end
    end
    
    -- Create harvest prompt
    createHarvestPrompt(fruitModel, plantID, fruitID)
    
    -- Store fruit data
    activeFruits[fruitID] = {
        model = fruitModel,
        parentPlantID = plantID,
        data = fruitData
    }
    
    -- Track in plant entry
    plantEntry.fruits[fruitID] = true
    
    return fruitModel
end

--[[
    handleHarvest(plantID, fruitID)
    Sends harvest request to server and handles response
--]]
function PlantSystem.handleHarvest(plantID, fruitID)
    local fruitEntry = activeFruits[fruitID]
    if not fruitEntry then
        showErrorUI("Fruit no longer available!")
        return
    end
    
    local plantEntry = activePlants[plantID]
    if not plantEntry then
        showErrorUI("Plant no longer exists!")
        return
    end
    
    -- Get fruit position for effects
    local fruitModel = fruitEntry.model
    local fruitPosition = fruitModel:GetPivot().Position
    
    -- Send harvest request to server
    local success, result = pcall(function()
        return PlantRemotes.HarvestFruit:InvokeServer(plantID, fruitID)
    end)
    
    if success and result then
        -- Server approved harvest
        
        -- Play harvest effects
        playHarvestEffects(fruitPosition)
        
        -- Remove fruit visual
        if fruitModel and fruitModel.Parent then
            -- Shrink animation
            for _, part in ipairs(fruitModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    TweenService:Create(part, TweenInfo.new(0.2), {
                        Size = Vector3.zero
                    }):Play()
                end
            end
            
            task.delay(0.2, function()
                if fruitModel and fruitModel.Parent then
                    fruitModel:Destroy()
                end
            end)
        end
        
        -- Clean up tracking
        activeFruits[fruitID] = nil
        plantEntry.fruits[fruitID] = nil
        
    else
        -- Server rejected harvest
        local errorMsg = typeof(result) == "string" and result or "Harvest failed!"
        showErrorUI(errorMsg)
    end
end

--[[
    setupInteractions()
    Sets up tool equipping and interaction handling
--]]
function PlantSystem.setupInteractions()
    -- Handle seed tool equipping
    LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        
        -- Listen for tool equip
        humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.GettingUp then
                -- Check if holding seed tool
                local tool = character:FindFirstChildOfClass("Tool")
                if tool and tool:GetAttribute("IsSeedTool") then
                    PlantSystem.onSeedToolEquipped(tool)
                end
            end
        end)
        
        -- Tool equipped event
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child:GetAttribute("IsSeedTool") then
                PlantSystem.onSeedToolEquipped(child)
            end
        end)
    end)
    
    -- Setup click-to-plant detection
    local mouse = LocalPlayer:GetMouse()
    
    mouse.Button1Down:Connect(function()
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool or not tool:GetAttribute("IsSeedTool") then
            return
        end
        
        -- Raycast to find plantable surface
        local target = mouse.Target
        if not target then
            return
        end
        
        -- Check if valid plant location
        local plantableRegion = target:FindFirstAncestor("PlantableRegions") or target:GetAttribute("Plantable")
        if not plantableRegion and not target:GetAttribute("Plantable") then
            return
        end
        
        local plantPosition = mouse.Hit.Position
        local seedType = tool:GetAttribute("SeedType") or "DefaultSeed"
        
        -- Send plant request to server
        PlantRemotes.PlantSeed:FireServer(seedType, plantPosition)
    end)
end

--[[
    onSeedToolEquipped(tool)
    Called when player equips a seed planting tool
--]]
function PlantSystem.onSeedToolEquipped(tool)
    -- Visual feedback for planting mode
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlantingModeHighlight"
    highlight.FillColor = Color3.fromRGB(100, 255, 100)
    highlight.OutlineColor = Color3.fromRGB(50, 200, 50)
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0.3
    
    -- Show highlight on plantable areas
    local plantableRegions = workspace:FindFirstChild("PlantableRegions")
    if plantableRegions then
        for _, region in ipairs(plantableRegions:GetDescendants()) do
            if region:IsA("BasePart") and region:GetAttribute("Plantable") then
                local regionHighlight = highlight:Clone()
                regionHighlight.Parent = region
                
                -- Clean up when tool unequipped
                tool.Unequipped:Connect(function()
                    regionHighlight:Destroy()
                end)
            end
        end
    end
end

--[[
    onPlayerJoin()
    Requests and spawns all existing plants for this player's plot
--]]
function PlantSystem.onPlayerJoin()
    -- Request plant data from server
    local success, plantData = pcall(function()
        return PlantRemotes.RequestPlantData:InvokeServer()
    end)
    
    if not success or not plantData then
        warn("[PlantSystem] Failed to fetch plant data:", plantData)
        return
    end
    
    -- Spawn all existing plants
    for plantID, data in pairs(plantData) do
        PlantSystem.spawnPlant(plantID, data)
    end
    
    print("[PlantSystem] Spawned", #plantData, "plants for player")
end

--[[
    handleServerUpdates()
    Listens for server-side plant events
--]]
function PlantSystem.handleServerUpdates()
    -- Plant added event
    PlantRemotes.PlantAdded.OnClientEvent:Connect(function(plantID, plantData)
        print("[PlantSystem] Server added plant:", plantID)
        PlantSystem.spawnPlant(plantID, plantData)
    end)
    
    -- Plant removed event (died, harvested, etc.)
    PlantRemotes.PlantRemoved.OnClientEvent:Connect(function(plantID)
        print("[PlantSystem] Server removed plant:", plantID)
        
        local entry = activePlants[plantID]
        if entry then
            -- Clean up growth connection
            if growthConnections[plantID] then
                growthConnections[plantID]:Disconnect()
                growthConnections[plantID] = nil
            end
            
            -- Remove associated fruits
            for fruitID, _ in pairs(entry.fruits) do
                local fruitEntry = activeFruits[fruitID]
                if fruitEntry and fruitEntry.model then
                    fruitEntry.model:Destroy()
                end
                activeFruits[fruitID] = nil
            end
            
            -- Remove plant model
            if entry.model then
                -- Fade out animation
                for _, part in ipairs(entry.model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        TweenService:Create(part, TweenInfo.new(0.3), {
                            Transparency = 1
                        }):Play()
                    end
                end
                
                task.delay(0.3, function()
                    if entry.model and entry.model.Parent then
                        entry.model:Destroy()
                    end
                end)
            end
            
            activePlants[plantID] = nil
        end
    end)
    
    -- Plant harvested event (someone else harvested)
    PlantRemotes.PlantHarvested.OnClientEvent:Connect(function(plantID, harvesterID, fruitID)
        -- If another player harvested, update visuals
        if harvesterID ~= LocalPlayer.UserId and fruitID then
            local fruitEntry = activeFruits[fruitID]
            if fruitEntry and fruitEntry.model then
                -- Quick removal (someone else harvested)
                fruitEntry.model:Destroy()
                activeFruits[fruitID] = nil
                
                local plantEntry = activePlants[plantID]
                if plantEntry then
                    plantEntry.fruits[fruitID] = nil
                end
            end
        end
    end)
    
    -- Fruit spawned event (server-initiated fruit spawn)
    PlantRemotes.PlantAdded.OnClientEvent:Connect(function(plantID, fruitData)
        if fruitData and fruitData.IsFruit then
            PlantSystem.spawnFruit(plantID, fruitData)
        end
    end)
end

--[[
    Initialize the plant system
--]]
function PlantSystem.initialize()
    -- Create plants folder in workspace if not exists
    if not workspace:FindFirstChild("Plants") then
        local plantsFolder = Instance.new("Folder")
        plantsFolder.Name = "Plants"
        plantsFolder.Parent = workspace
    end
    
    -- Setup server update listeners
    PlantSystem.handleServerUpdates()
    
    -- Setup interactions
    PlantSystem.setupInteractions()
    
    -- Load existing plants
    PlantSystem.onPlayerJoin()
    
    print("[PlantSystem] Initialized successfully")
end

-- Auto-initialize on module load
PlantSystem.initialize()

-- Cleanup on player leaving
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        -- Clean up all connections
        for _, conn in pairs(growthConnections) do
            conn:Disconnect()
        end
        table.clear(growthConnections)
        table.clear(activePlants)
        table.clear(activeFruits)
    end
end)

return PlantSystem
