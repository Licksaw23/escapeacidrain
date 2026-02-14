# Client-Server Plant System Architecture
## FeedTheBrainrots - DARPA Advanced Research Division

---

## Executive Summary

This document outlines a complete client-server architecture refactor for the plant system in FeedTheBrainrots. The goal is to shift from the current **server-authoritative instance model** to a **data-authoritative model** following Roblox tycoon genre best practices.

### Why This Matters
- **Current System**: Server creates/manages ~1000+ instances per active player (plants, fruits, prompts)
- **Target System**: Server manages ~50 data entries per player, client handles all visuals
- **Benefits**: Massive server performance gains, better client responsiveness, easier to maintain

---

## 1. Current Architecture Analysis

### 1.1 Server Responsibilities (Current - PROBLEMATIC)
```
Server/Game/Plot/init.luau
├── PlacePlant() - Creates Model instance, parents to workspace
├── ActivePlants[] - Tracks instances, runs growth logic every second
├── UpdateGrowth() - Modifies part transparency, positions
├── SetupFruit() - Creates fruit Model instances, proximity prompts
└── TweenService calls for growth animations
```

**Issues:**
- Server owns 3D instances → replication overhead
- Server runs RenderStepped-like logic (growth updates)
- ~50-200 instances per plot × 20 players = 1000-4000 server instances
- Proximity prompts recreated for every fruit spawn

### 1.2 Data Flow (Current)
```
[Player Places Seed]
    ↓
[Server] Create Tool → Validate → Create Model → Parent to Workspace
    ↓
[Server Heartbeat] Every 1s: Update transparency, check growth stage
    ↓
[Server] Tween parts, spawn fruit models, create prompts
    ↓
[Client] Receives FX events for visual polish only
```

---

## 2. Target Architecture

### 2.1 Server Responsibilities (Data Only)

```lua
-- Server ONLY stores this data structure:
type PlantData = {
    plantId: string,           -- UUID
    plantType: string,         -- "Strawberry Seed", "Carrot Seed", etc.
    position: Vector3,         -- World position
    timePlaced: number,        -- Unix timestamp
    growthDuration: number,    -- Seconds to full growth
    randomScale: number,       -- Visual variety
    randomRotation: number,    -- Visual variety
    
    -- Nested fruit data (only exists when grown)
    fruits: {
        [fruitIndex: string]: {
            weight: number,
            mutations: {string},
            favorited: boolean,
            respawnTime: number?  -- For picked fruits that regrow
        }
    }
}
```

**Server Jobs:**
1. **Placement Validation** - Position checks, collision, ownership
2. **Growth Time Tracking** - Store `timePlaced`, calculate progress on request
3. **Harvest Validation** - Check proximity, inventory space, favorited status
4. **Data Replication** - Replica:SetValue for plant/fruit data changes only

**Server Explicitly Does NOT:**
- Create Model instances
- Call TweenService
- Manage ProximityPrompts
- Check growth every second (event-driven only)

### 2.2 Client Responsibilities (Visuals Only)

```lua
-- Client maintains this visual state:
type PlantVisual = {
    model: Model,              -- Cloned from ReplicatedStorage
    plantId: string,
    currentStage: number,      -- 0-4 for growth phases
    targetStage: number,       -- Calculated from server time
    
    -- Growth animation handling
    growthTween: Tween?,
    lastUpdateTime: number,
    
    -- Fruit visuals
    fruits: {
        [fruitIndex: string]: {
            model: Model,
            prompt: ProximityPrompt,
            highlight: Highlight?
        }
    }
}
```

**Client Jobs:**
1. **Model Instantiation** - Clone from ReplicatedStorage templates
2. **Growth Animation** - Local tweens based on calculated progress
3. **Fruit Management** - Create/destroy fruit models locally
4. **Interaction Handling** - Proximity prompts, click detection
5. **Visual Sync** - Calculate current state from server timestamps

---

## 3. Data Contract

### 3.1 Server → Client (Replica Replication)

```lua
-- Plant placement (one-time on place OR initial sync)
Replica:SetValue({"Plot", plantId}, {
    Name = "Strawberry Seed",
    Position = bufferedPosition,      -- BitBuffer encoded
    TimePlaced = bufferedTimestamp,   -- BitBuffer encoded  
    GrowthTime = 20,                  -- From ItemsData
    RandomScale = 1.15,
    RandomRotation = 45
})

-- Fruit spawn (when plant reaches maturity)
Replica:SetValue({"Plot", plantId, "1"}, {  -- "1" = fruit index
    Weight = 0.35,
    Mutations = {"Gold"},
    Favorited = false
})

-- Fruit removal (on harvest)
Replica:SetValue({"Plot", plantId, "1"}, nil)

-- Plant removal
Replica:SetValue({"Plot", plantId}, nil)
```

**Frequency:**
- Initial sync: Once on player join (all existing plants)
- New plants: On each placement
- Fruit spawns: When growth completes (one-time per fruit)
- Harvest: On each pick

### 3.2 Client → Server (RemoteEvents)

```lua
-- Request plant placement
PlotRemote:FireServer("RequestPlacePlant", {
    Position = hitPosition,
    SeedId = "uuid-of-seed-in-inventory"
})

-- Server responds:
-- SUCCESS: Replica update (above)
-- FAIL: UI notification only

-- Request harvest
PlotRemote:FireServer("RequestHarvest", {
    PlantId = "plant-uuid",
    FruitIndex = "1"
})

-- Server responds:
-- SUCCESS: Replica removes fruit data, adds to inventory
-- FAIL: Error notification
```

**Frequency:**
- Placement: User-initiated (low frequency)
- Harvest: User-initiated (moderate frequency)

### 3.3 Client ↔ Client (Never)

Clients never communicate directly. All state changes flow through server data.

---

## 4. Code Architecture

### 4.1 New File Structure

```
Server/
├── Game/
│   └── Plot/
│       ├── init.luau              # Plot management (brainrots, orders)
│       ├── PlantService.luau      # NEW: Data-only plant logic
│       └── PlantValidator.luau    # NEW: Placement validation

Client/
├── Handlers/
│   ├── PlantController.luau       # NEW: Visual plant management
│   ├── FruitController.luau       # NEW: Visual fruit management
│   └── GrowthAnimator.luau        # NEW: Growth stage animations

ReplicatedStorage/
├── Game/
│   ├── Modules/
│   │   └── Libraries/
│   │       └── PlantData.luau     # Shared plant data types
│   └── Models/
│       └── Plants/
│           ├── Strawberry/        # Template models (unchanged)
│           ├── Carrot/
│           └── ...
```

### 4.2 Server Implementation (PlantService.luau)

```lua
-- PlantService.luau - Data-only plant management

local PlantService = {}

-- Minimal state - just data tables
PlantService.ActivePlants = {} -- [player] = {[plantId] = PlantData}

-- Load plant modules for growth times
local PlantModules = {}
for name, data in ItemsData do
    if data.Type == "Plant" then
        PlantModules[name] = require(script.Parent.Plants[name])
    end
end

-- Player requests plant placement
function PlantService:RequestPlacePlant(player, position, seedItemId)
    local plot = self:GetPlayerPlot(player)
    if not plot then return false, "No plot" end
    
    -- Validation
    local seedItem = plot.OwnerData.Inventory[seedItemId]
    if not seedItem then return false, "Invalid seed" end
    
    local plantData = ItemsData[seedItem.Name]
    if not plantData or plantData.Type ~= "Plant" then 
        return false, "Not a plant" 
    end
    
    -- Position validation (collision, bounds, etc.)
    if not PlantValidator:IsValidPosition(plot, position) then
        return false, "Invalid position"
    end
    
    -- Generate plant ID
    local plantId = HttpService:GenerateGUID(false)
    
    -- Encode position relative to plot origin
    local origin = plot.Folder.All.Farm1.Origin.Position
    local offset = position - origin
    local posBuffer = BitBuffer.Create()
    posBuffer:WriteFloat32(offset.X)
    posBuffer:WriteFloat32(offset.Y)
    posBuffer:WriteFloat32(offset.Z)
    
    -- Random visual variety
    local rotationBuffer = BitBuffer.Create()
    rotationBuffer:WriteFloat32(math.random(-180, 180))
    
    -- Store data (NOT instances!)
    local now = workspace:GetServerTimeNow()
    local plantRecord = {
        Name = seedItem.Name,
        OffsetPosition = posBuffer:ToBase64(),
        TimePlaced = self:EncodeTime(now),
        GrowthTime = plantData.GrowthTime,
        RandomScale = Random.new():NextNumber(0.75, 1.4),
        RandomRotation = rotationBuffer:ToBase64()
    }
    
    -- Save to replica (triggers client visual creation)
    plot.OwnerReplica:SetValue({"Plot", plantId}, plantRecord)
    
    -- Consume seed
    self:ConsumeSeed(player, seedItemId)
    
    -- Schedule fruit spawn (server-side timer, NOT instance creation)
    task.delay(plantData.GrowthTime, function()
        self:SpawnFruitData(player, plantId, "1")
    end)
    
    return true, plantId
end

-- Spawn fruit data (not visual model!)
function PlantService:SpawnFruitData(player, plantId, fruitIndex)
    local plot = self:GetPlayerPlot(player)
    if not plot then return end
    
    -- Check plant still exists
    local plantData = plot.OwnerData.Plot[plantId]
    if not plantData then return end
    
    -- Generate fruit properties
    local productName = ItemsData[plantData.Name].Product
    local weight = PickScale.RandomizeWeight(ItemsData[productName].WeightPool)
    local mutations = self:GenerateMutations(player)
    
    -- Save fruit data to replica
    plot.OwnerReplica:SetValue({"Plot", plantId, fruitIndex}, {
        Weight = weight,
        Mutations = mutations,
        Favorited = false
    })
end

-- Handle harvest request
function PlantService:RequestHarvest(player, plantId, fruitIndex)
    local plot = self:GetPlayerPlot(player)
    if not plot then return false end
    
    local fruitData = plot.OwnerData.Plot[plantId]?.[fruitIndex]
    if not fruitData then return false end
    
    if fruitData.Favorited then return false end
    
    -- Check inventory space
    if not self:HasInventorySpace(player) then
        return false, "Inventory full"
    end
    
    local plantData = plot.OwnerData.Plot[plantId]
    local productName = ItemsData[plantData.Name].Product
    
    -- Remove fruit data
    plot.OwnerReplica:SetValue({"Plot", plantId, fruitIndex}, nil)
    
    -- Add to inventory
    plot:GiveItem({
        ID = HttpService:GenerateGUID(false),
        Name = productName,
        Weight = fruitData.Weight,
        Mutations = fruitData.Mutations
    })
    
    -- Schedule respawn if applicable
    local plantModule = PlantModules[plantData.Name]
    if plantModule.FruitRespawnTime then
        task.delay(plantModule.FruitRespawnTime, function()
            self:SpawnFruitData(player, plantId, fruitIndex)
        end)
    end
    
    return true
end

-- Calculate growth progress (for client sync on join)
function PlantService:GetGrowthProgress(plantData)
    local timePlaced = self:DecodeTime(plantData.TimePlaced)
    local elapsed = workspace:GetServerTimeNow() - timePlaced
    return math.clamp(elapsed / plantData.GrowthTime, 0, 1)
end

return PlantService
```

### 4.3 Client Implementation (PlantController.luau)

```lua
-- PlantController.luau - Visual plant management

local PlantController = {}

-- Visual state tracking
PlantController.Plants = {} -- [plantId] = PlantVisual

-- Plant modules for growth stage logic
local PlantModules = {}

function PlantController:Init()
    -- Load plant modules
    for name, data in ItemsData do
        if data.Type == "Plant" then
            PlantModules[name] = require(Replicated.Game.Modules.Plants[name])
        end
    end
    
    -- Listen to replica changes
    PlayerReplica:ListenToRaw(function(action, path, newValue, oldValue)
        if path[1] ~= "Plot" then return end
        
        local plantId = path[2]
        
        if #path == 2 then
            -- Plant added/removed
            if newValue then
                self:CreatePlantVisual(plantId, newValue)
            else
                self:RemovePlantVisual(plantId)
            end
        elseif #path == 3 then
            -- Fruit added/removed
            local fruitIndex = path[3]
            if newValue then
                self:CreateFruitVisual(plantId, fruitIndex, newValue)
            else
                self:RemoveFruitVisual(plantId, fruitIndex)
            end
        end
    end)
    
    -- Sync existing plants on join
    self:SyncExistingPlants()
    
    -- Start growth update loop
    self:StartGrowthLoop()
end

function PlantController:CreatePlantVisual(plantId, plantData)
    local plantModule = PlantModules[plantData.Name]
    if not plantModule then return end
    
    -- Decode position
    local pos = self:DecodePosition(plantData.OffsetPosition)
    local origin = self:GetPlotOrigin()
    local worldPos = origin + pos
    
    -- Clone template model
    local template = Replicated.Game.Models.Plants:FindFirstChild(plantData.Name)
    if not template then return end
    
    local model = template:Clone()
    model.Name = plantId
    
    -- Apply transforms
    local rotation = self:DecodeRotation(plantData.RandomRotation)
    model:PivotTo(CFrame.new(worldPos) * CFrame.Angles(0, math.rad(rotation), 0))
    
    if plantModule.Type == "Spawner" then
        model:ScaleTo(plantData.RandomScale)
    end
    
    -- Parent to workspace
    model.Parent = self:GetPlotFolder().Plants
    
    -- Calculate initial growth stage
    local timePlaced = self:DecodeTime(plantData.TimePlaced)
    local elapsed = workspace:GetServerTimeNow() - timePlaced
    local progress = math.clamp(elapsed / plantData.GrowthTime, 0, 1)
    local stage = self:CalculateStage(plantModule, progress)
    
    -- Store visual state
    self.Plants[plantId] = {
        model = model,
        plantId = plantId,
        currentStage = 0,
        targetStage = stage,
        plantData = plantData,
        module = plantModule,
        fruits = {}
    }
    
    -- Apply initial visibility
    self:ApplyGrowthStage(model, stage, plantModule, true) -- true = instant
    
    -- If already grown, check for existing fruit data
    if progress >= 1 then
        self:CheckForExistingFruits(plantId)
    end
end

function PlantController:StartGrowthLoop()
    -- Run at 10fps for smooth growth updates
    RunService.Heartbeat:Connect(function(dt)
        for plantId, visual in pairs(self.Plants) do
            local plantData = visual.plantData
            local timePlaced = self:DecodeTime(plantData.TimePlaced)
            local elapsed = workspace:GetServerTimeNow() - timePlaced
            local progress = math.clamp(elapsed / plantData.GrowthTime, 0, 1)
            local targetStage = self:CalculateStage(visual.module, progress)
            
            if targetStage > visual.currentStage then
                visual.targetStage = targetStage
                self:AnimateGrowthStage(visual)
            end
        end
    end)
end

function PlantController:CreateFruitVisual(plantId, fruitIndex, fruitData)
    local visual = self.Plants[plantId]
    if not visual then return end
    
    local plantModule = visual.module
    local productName = ItemsData[visual.plantData.Name].Product
    
    -- Get spawn position from plant
    local spawnCFrame = self:GetFruitSpawnCFrame(visual.model, fruitIndex, plantModule)
    
    -- Clone fruit model
    local template = Replicated.Game.Models.Plants:FindFirstChild(productName)
    if not template then return end
    
    local fruitModel = template:Clone()
    fruitModel:PivotTo(spawnCFrame)
    fruitModel.Parent = visual.model
    
    -- Apply scale/mutations
    self:ApplyFruitProperties(fruitModel, fruitData)
    
    -- Create proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect " .. productName
    prompt.RequiresLineOfSight = false
    prompt.Parent = fruitModel:FindFirstChild("Part") or fruitModel.PrimaryPart
    
    prompt.Triggered:Connect(function(player)
        if player ~= Players.LocalPlayer then return end
        self:RequestHarvest(plantId, fruitIndex)
    end)
    
    -- Store reference
    visual.fruits[fruitIndex] = {
        model = fruitModel,
        prompt = prompt
    }
    
    -- Fade in animation
    self:FadeInFruit(fruitModel)
end

function PlantController:RequestHarvest(plantId, fruitIndex)
    -- Fire to server, visual removal happens via replica callback
    PlotRemote:FireServer("RequestHarvest", {
        PlantId = plantId,
        FruitIndex = fruitIndex
    })
end

function PlantController:RemoveFruitVisual(plantId, fruitIndex)
    local visual = self.Plants[plantId]
    if not visual then return end
    
    local fruit = visual.fruits[fruitIndex]
    if fruit then
        -- Play pickup effect
        self:PlayHarvestEffect(fruit.model)
        
        -- Destroy visual
        fruit.model:Destroy()
        visual.fruits[fruitIndex] = nil
    end
end

return PlantController
```

### 4.4 Growth Stage Animation (GrowthAnimator.luau)

```lua
-- GrowthAnimator.luau - Handles smooth growth transitions

local GrowthAnimator = {}

function GrowthAnimator:AnimateStageTransition(model, fromStage, toStage, plantModule)
    -- Stage definitions:
    -- 0 = Invisible (just planted)
    -- 1 = Stem only
    -- 2 = Main model
    -- 3 = Branches
    -- 4 = Fully grown
    
    if plantModule.Type == "Spawner" then
        return self:AnimateSpawnerStages(model, fromStage, toStage, plantModule)
    else
        return self:AnimateSingleStages(model, fromStage, toStage, plantModule)
    end
end

function GrowthAnimator:AnimateSpawnerStages(model, fromStage, toStage, plantModule)
    -- Stage 0→1: Stem grows up
    if fromStage < 1 and toStage >= 1 then
        local stem = model:FindFirstChild("Stem", true)
        if stem then
            stem.Transparency = 0
            local targetPos = stem.Position
            stem.Position = targetPos - Vector3.new(0, 1.5, 0)
            TweenService:Create(stem, TweenInfo.new(1.5), {
                Position = targetPos
            }):Play()
        end
    end
    
    -- Stage 1→2: Main model parts pop in
    if fromStage < 2 and toStage >= 2 then
        local main = model:FindFirstChild("main")
        if main then
            for _, part in main:GetChildren() do
                if part:IsA("BasePart") and part.Name ~= "Stem" then
                    self:PopInPart(part)
                end
            end
        end
    end
    
    -- Stage 2→3: Branches extend
    if fromStage < 3 and toStage >= 3 then
        for _, part in model:GetChildren() do
            if part:IsA("BasePart") and part.Name ~= "Stem" and 
               string.find(part.Name, plantModule.BranchPattern or "Branch") then
                self:PopInPart(part)
            end
        end
    end
end

function GrowthAnimator:PopInPart(part)
    part.Transparency = 0
    local targetPos = part.Position
    local targetSize = part.Size
    
    part.Position = targetPos + Vector3.new(
        math.random(-10, 10) / 10,
        math.random(-10, 10) / 10,
        math.random(-10, 10) / 10
    )
    part.Size = Vector3.zero
    
    TweenService:Create(part, TweenInfo.new(2.5, Enum.EasingStyle.Quad), {
        Position = targetPos,
        Size = targetSize
    }):Play()
end

return GrowthAnimator
```

---

## 5. Migration Strategy

### Phase 1: Data Layer (Week 1)
1. **Create PlantService.luau** with data-only functions
2. **Create PlantData types** in Shared
3. **Update Replica data structure** (backward compatible)
4. **Test server-side** with no client changes

### Phase 2: Client Layer (Week 2)
1. **Create PlantController.luau** with visual management
2. **Create GrowthAnimator.luau** for smooth transitions
3. **Create FruitController.luau** for fruit interactions
4. **Test locally** with 1-2 plants

### Phase 3: Integration (Week 3)
1. **Hook up replica listeners** in PlantController
2. **Remove old instance creation** from Plot/init.luau
3. **Migrate existing plants** on player join
4. **Test full cycle**: Place → Grow → Harvest

### Phase 4: Cleanup (Week 4)
1. **Remove ServerUtility.SetupFruit** references
2. **Delete old plant spawning code** from Plot/init.luau
3. **Remove ActivePlants loop** from server
4. **Performance testing** with 20+ players

---

## 6. What Gets Deleted

### From Server/Game/Plot/init.luau:
```lua
-- DELETE: Instance tracking
plot.ActivePlants = {}  -- Entire table and all references

-- DELETE: Growth update loop (lines ~880-980)
task.spawn(function()
    while true do
        task.wait(1)
        for i = #plot.ActivePlants, 1, -1 do
            -- ALL OF THIS
        end
    end
end)

-- DELETE: PlacePlant function body (replace with PlantService call)
function plot:PlacePlant(uniqueID, rawPosition, itemID)
    -- Replace entire body with:
    return PlantService:RequestPlacePlace(self.Owner, rawPosition, itemID)
end

-- DELETE: GetSprinklerMultiplier (move to PlantService)

-- DELETE: All TweenService calls in plant context

-- DELETE: Physical prompt creation for fruits
```

### From Server/Game/ServerUtility.luau:
```lua
-- DELETE: SetupFruit function (entirely)
-- DELETE: ActiveFruit table
-- DELETE: Fruit-related callbacks
-- DELETE: Proximity prompt creation in fruit context
```

---

## 7. Backward Compatibility

### Data Migration (One-time)
Existing plants in player data will work immediately - same data structure:
```lua
-- Old data format (still valid):
Plot = {
    [plantId] = {
        Name = "Strawberry Seed",
        OffsetPosition = "...",  -- Base64
        TimePlaced = "...",      -- Base64
        -- Same structure!
    }
}
```

### Fallback for Missing Features
If PlantController fails to load:
- Server still manages data correctly
- Plants just won't be visible (graceful degradation)

---

## 8. Performance Projections

| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| Server instances/player | ~150 | ~20 | 7.5× reduction |
| Server Heartbeat usage | ~5ms | ~0.5ms | 10× reduction |
| Network replication | High (instance changes) | Low (data only) | 5× reduction |
| Client memory | ~50MB | ~60MB | Slight increase |
| Client CPU | Low | Medium | Acceptable tradeoff |

---

## 9. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Desync between client/server | Server authoritative for all state changes |
| Client exploits | Validate ALL actions server-side |
| Join mid-growth | Calculate stage from timestamp, don't rely on events |
| Plant module errors | pcall around all module calls, graceful fallback |
| Memory leaks | Destroy visual objects on plant removal, track in table |

---

## 10. Testing Checklist

- [ ] Place plant → appears visually
- [ ] Growth stages animate smoothly
- [ ] Plant reaches full growth → fruit spawns
- [ ] Fruit shows correct weight/mutations visually
- [ ] Harvest fruit → inventory updated
- [ ] Rejoin mid-growth → correct stage shown
- [ ] Rejoin with grown plants → fruits visible
- [ ] 20 plants growing simultaneously
- [ ] Sprinkler boost applies correctly
- [ ] Favorite fruit disables prompt
- [ ] Remove plant → all cleanup happens

---

## Appendix: Key Pseudocode Patterns

### Pattern 1: Server Data Update
```lua
-- OLD (server creates instance):
local model = template:Clone()
model.Parent = workspace
model:SetAttribute("Progress", 0.5)

-- NEW (server updates data):
Replica:SetValue({"Plot", plantId, "TimePlaced"}, encodedTime)
-- Client reads TimePlaced, calculates progress locally
```

### Pattern 2: Harvest Request
```lua
-- OLD (server handles everything):
prompt.Triggered:Connect(function(player)
    fruit:Destroy()  -- Server destroys instance
    GiveItem()       -- Server gives item
end)

-- NEW (client requests, server validates):
-- Client:
prompt.Triggered:Connect(function()
    Remote:FireServer("Harvest", plantId, fruitIndex)
end)

-- Server:
Remote.OnServerEvent:Connect(function(player, plantId, fruitIndex)
    if Validate(player, plantId, fruitIndex) then
        Replica:SetValue({"Plot", plantId, fruitIndex}, nil)  -- Remove data
        GiveItem(player)
    end
end)

-- Client (replica listener):
Replica:ListenToRaw(function(action, path)
    if path[3] == fruitIndex and action == "Set" and newValue == nil then
        -- Fruit data removed, destroy visual
        DestroyFruitVisual(plantId, fruitIndex)
    end
end)
```

---

*Document Version: 1.0*
*Author: DARPA Architecture Division*
*Date: 2026-02-02*
