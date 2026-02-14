# Sprinkler System - Implementation Complete

## Overview

The sprinkler system is now fully implemented and allows players to place sprinklers in their plots to boost plant growth speed. Sprinklers have a limited duration (5 minutes) and affect all plants within their radius.

## Architecture

### Server-Side Components

#### 1. `/Server/Game/Plot/SprinklerSystem.luau` (NEW)
Core sprinkler management module handling:
- **Placement validation**: Checks player owns plot, valid position, collision detection
- **Removal prompts**: Creates ProximityPrompt on sprinklers for easy removal
- **Gear removal**: Handles cleanup of VFX, data, models, and inventory return
- **Growth boost calculation**: Calculates 1.5x multiplier per unique sprinkler type
- **VFX management**: Triggers start/stop VFX on clients
- **Expiration handling**: Automatic cleanup when sprinklers expire

Key Functions:
```lua
SprinklerSystem:ValidatePlacement(player, position, gearID) -> success, message
SprinklerSystem:SetupRemovalPrompt(plot, gearID, gearModel, sprinklerName)
SprinklerSystem:RemoveGear(plot, gearID) -> success
SprinklerSystem:GetGrowthBoost(plot, position) -> multiplier
SprinklerSystem:OnSprinklerPlaced(plot, gearID, gearModel, gearName)
SprinklerSystem:OnSprinklerExpired(plot, gearID)
SprinklerSystem:HandleRemoveRequest(player, gearID) -> success, message
```

#### 2. `/Server/Game/Plot/init.luau` (MODIFIED)
Integrated SprinklerSystem into main Plot class:
- Added `require(script.SprinklerSystem)`
- Enhanced `PlaceGear()` to validate placement via SprinklerSystem
- Added `GetSprinklerMultiplier(position)` method to Plot
- Added `RemoveGear` handler in PlotRemote
- Added VFX triggering for existing sprinklers on player join

#### 3. `/Server/Game/Plot/PlantService.luau` (MODIFIED)
Updated for sprinkler growth boost integration:
- Modified `CalculateGrowthProgress()` to apply sprinkler boost
- Modified `IsPlantMature()` to pass player parameter
- Updated growth calculations to use `ActualTime = BaseTime / Boost`

### Client-Side Components

#### 1. `/Client/Handlers/VFX/Sprinkler.luau` (EXISTING)
Client-side visual effects for sprinklers:
- `StartSprinkler(id, model, type)` - Water particle effects
- `StopSprinkler(id)` - Cleanup effects
- Water arc particles, splash effects, wet ground indicator
- Rotating sprinkler head animation

#### 2. `/Client/Handlers/VFX/init.luau` (EXISTING)
VFX handler routing:
- Routes `"SprinklerStart"` events to Sprinkler module
- Routes `"SprinklerStop"` events to Sprinkler module

#### 3. `/Shared/Modules/Utilities/GearsPlacement.luau` (MODIFIED)
Client placement system:
- Shows preview model with transparency
- Displays range indicator (rotating ring)
- Validates gear still in inventory before placing
- Raycast-based position detection on Farm1/Farm2

### Data & Configuration

#### 1. `/Shared/Modules/Libraries/GearsData.luau` (EXISTING)
Sprinkler configurations:
```lua
["Starter Sprinkler"] = {
    Placeable = true,
    Type = "Gear",
    Rarity = "Rare",
    BuyPrice = 5000,
    ManualOffset = 0.875,
    PlaceableData = {
        Radius = 20,
        Duration = 5*60, -- 5 minutes
    }
}

["Bamboo Sprinkler"] = {
    Placeable = true,
    Type = "Gear",
    Rarity = "Epic",
    BuyPrice = 1, -- Placeholder
    ManualOffset = 0.2,
    PlaceableData = {
        Radius = 30,
        Duration = 5*60,
    }
}

["Industrial Sprinkler"] = {
    Placeable = true,
    Type = "Gear",
    Rarity = "Legendary",
    BuyPrice = 1, -- Placeholder
    ManualOffset = 0.875,
    PlaceableData = {
        Radius = 45,
        Duration = 5*60,
    }
}
```

## How It Works

### Placement Flow
1. Player equips sprinkler tool from inventory
2. Client shows preview model with range indicator
3. Player clicks to place on valid farm surface
4. Client validates gear still exists in inventory
5. Server validates:
   - Player owns the plot
   - Position is within bounds
   - No collision with existing gears
   - Gear exists in inventory
6. Server saves to `PlotGears` with encoded position and timestamp
7. Server deducts gear from inventory
8. Server creates sprinkler model in plot
9. Server triggers VFX on all clients via `FXRemote:FireAllClients("SprinklerStart", ...)`
10. Server schedules automatic expiration after duration

### Growth Boost Flow
1. Plant is placed with `TimePlaced` timestamp
2. When calculating growth progress, server:
   - Decodes plant position from `OffsetPosition`
   - Calls `GetSprinklerMultiplier(position)`
   - Finds all active sprinklers within range
   - Applies 1.5x boost per unique sprinkler type
   - Calculates: `EffectiveGrowthTime = BaseGrowthTime / Boost`
3. Growth progress uses effective time for calculations

### Removal Flow
1. Player approaches sprinkler and sees "Remove Sprinkler" prompt
2. Player holds interaction for 0.5 seconds
3. Server validates ownership
4. Server stops VFX on all clients
5. Server plays removal sound
6. Server removes from `PlotGears` data
7. Server destroys model with fade effect
8. Server returns gear to inventory (incrementing quantity)

### Expiration Flow
1. Sprinkler placed with `ActivatedTime` timestamp
2. Server schedules `task.delay(duration, ...)`
3. When duration expires:
   - Server stops VFX on all clients
   - Server removes from `PlotGears` data
   - Server destroys model
   - No refund given

## Remote Events

### Server → Client
```lua
-- Start sprinkler VFX
FXRemote:FireAllClients("SprinklerStart", {
    ID = gearID,
    Model = gearModel,
    Type = sprinklerName
})

-- Stop sprinkler VFX
FXRemote:FireAllClients("SprinklerStop", {
    ID = gearID
})
```

### Client → Server
```lua
-- Place gear/sprinkler
PlotRemote:FireServer("PlaceGear", {
    RawPosition = position,
    ID = gearID
})

-- Remove gear/sprinkler
PlotRemote:FireServer("RemoveGear", gearID)
```

## Data Structure

### PlotGears Entry
```lua
{
    Name = "Starter Sprinkler",
    OffsetPosition = "base64_encoded_vector3", -- Relative to plot origin
    ActivatedTime = "base64_encoded_timestamp" -- When placed
}
```

### Growth Calculation
```lua
-- Single sprinkler: 1.5x boost (33% faster growth)
-- Two different sprinklers: 1.5 * 1.5 = 2.25x boost (55% faster)
-- Three different sprinklers: 1.5 * 1.5 * 1.5 = 3.375x boost (70% faster)
-- Max boost capped at 3.375x
```

## Sprinkler Types

| Type | Radius | Duration | Boost | Price |
|------|--------|----------|-------|-------|
| Starter Sprinkler | 20 studs | 5 min | 1.5x | $5,000 |
| Bamboo Sprinkler | 30 studs | 5 min | 1.5x | $1 |
| Industrial Sprinkler | 45 studs | 5 min | 1.5x | $1 |

## Testing

Run the test suite:
```lua
local SprinklerTests = require(game.ReplicatedStorage.Game.Modules.Utilities.SprinklerTests)
SprinklerTests.RunAll()
```

Tests cover:
1. Sprinkler data structure validation
2. Placement data encoding/decoding
3. Range detection for plants
4. Growth boost calculation
5. Duration and expiration logic
6. VFX module verification
7. Gear removal functionality
8. Full lifecycle integration
9. SprinklerSystem module completeness

## Visual Effects

The sprinkler VFX includes:
- Water arc particles spraying from sprinkler to ground
- Splash effects on ground impact
- Wet ground area indicator (faded cylinder)
- Rotating sprinkler head animation
- Particle colors matching sprinkler type:
  - Starter: Blue (100, 150, 255)
  - Bamboo: Green (120, 180, 100)
  - Industrial: Dark Blue (80, 120, 200)

## Future Enhancements

1. **Overlapping Sprinklers**: Currently same-type sprinklers don't stack - could be changed
2. **Upgradable Sprinklers**: Allow players to upgrade duration/radius
3. **Sprinkler Refills**: Allow refilling sprinklers with water instead of replacing
4. **Visual Improvements**: Add more particle effects, sound effects
5. **UI Indicator**: Show active sprinkler radius when hovering over them
6. **Sprinkler Crafting**: Allow crafting better sprinklers from components

## Debugging

To debug the sprinkler system:
1. Check server output for placement/removal logs
2. Verify VFX appears on client when placing sprinklers
3. Check plant growth speed with and without sprinklers
4. Test removal functionality and inventory refund
5. Verify expiration after 5 minutes

Common issues:
- **VFX not showing**: Check FXRemote is firing, Sprinkler.luau is loaded
- **No growth boost**: Verify GetSprinklerMultiplier is being called
- **Can't place**: Check ValidatePlacement error messages
- **Not saving**: Verify PlotGears data structure in PlayerData
