# Sprinkler System Documentation

## Overview
The sprinkler system allows players to place sprinklers in their plots to boost plant growth speed. Sprinklers have a limited duration (5 minutes) and affect all plants within their radius.

## Files Modified/Created

### 1. Server-Side Changes

#### `/Server/Game/Plot/init.luau`
- **Enhanced `PlaceGear()` function**: Added sprinkler-specific functionality including:
  - VFX triggering when sprinklers are placed/loaded
  - Removal prompt setup for sprinklers
  - Proper duration scheduling with cleanup

- **Added `SetupSprinklerRemovalPrompt()` function**: Creates proximity prompts on sprinklers allowing players to remove them

- **Added `RemoveGear()` function**: Handles sprinkler/gear removal:
  - Stops VFX
  - Plays removal sound
  - Removes from data
  - Destroys model with fade effect
  - Returns gear to inventory

- **Added `RemoveGear` handler in PlotRemote**: Handles client removal requests

- **`GetSprinklerMultiplier()` function** (existing): Calculates growth boost based on sprinklers in range

### 2. Client-Side Changes

#### `/Client/Handlers/VFX/Sprinkler.luau` (NEW)
Client-side visual effects module for sprinklers:
- `StartSprinkler(id, model, type)` - Starts water particle effects
- `StopSprinkler(id)` - Stops and cleans up effects
- Creates water arc particles that spray from sprinkler to ground
- Shows splash effects on ground impact
- Displays wet ground area (faded cylinder)
- Rotates sprinkler head animation

#### `/Client/Handlers/VFX/init.luau`
- Added handlers for `"SprinklerStart"` and `"SprinklerStop"` remote events

#### `/Shared/Modules/Utilities/GearsPlacement.luau`
- Updated to use sprinkler-specific radius from `PlaceableData.Radius` instead of hardcoded value

### 3. Test Suite

#### `/Shared/Modules/Utilities/SprinklerTests.luau` (NEW)
Comprehensive test suite with 8 tests:
1. Sprinkler data structure validation
2. Placement data encoding/decoding
3. Range detection for plants
4. Growth boost calculation
5. Duration and expiration logic
6. VFX module verification
7. Gear removal functionality
8. Full lifecycle integration test

## How Sprinklers Work

### Placement
1. Player equips sprinkler tool
2. Client shows preview model with range indicator
3. Player clicks to place
4. Server validates and saves to `PlotGears` data with:
   - `Name`: Sprinkler type
   - `OffsetPosition`: Position relative to plot origin (Base64 encoded)
   - `ActivatedTime`: When sprinkler was placed (Base64 encoded)
5. Sprinkler model created in plot
6. VFX started on all clients
7. Removal prompt added

### Growth Boost
1. Plant growth system checks `GetSprinklerMultiplier()` every second
2. Function finds all active sprinklers within range of plant
3. Each unique sprinkler type provides 1.5x boost
4. Multiple different sprinklers stack multiplicatively
5. Growth time is adjusted by modifying the `PlacedTick` attribute

### Duration & Expiration
1. Sprinklers last 5 minutes (300 seconds) by default
2. Server schedules automatic destruction after duration
3. When expired:
   - VFX stopped
   - Removed from data
   - Model destroyed
   - No refund given

### Removal
1. Player approaches sprinkler and sees "Remove Sprinkler" prompt
2. Hold interaction for 0.5 seconds
3. Server validates ownership
4. Sprinkler removed and returned to inventory

## Sprinkler Types

### Starter Sprinkler
- **Radius**: 20 studs
- **Duration**: 5 minutes
- **Boost**: 1.5x growth speed
- **Price**: $5,000

### Bamboo Sprinkler
- **Radius**: 30 studs
- **Duration**: 5 minutes
- **Boost**: 1.5x growth speed
- **Price**: $1 (placeholder)

### Industrial Sprinkler
- **Radius**: 45 studs
- **Duration**: 5 minutes
- **Boost**: 1.5x growth speed
- **Price**: $1 (placeholder)

## Data Structure

### PlotGears Data Entry
```lua
{
    Name = "Starter Sprinkler",
    OffsetPosition = "base64_encoded_vector3",
    ActivatedTime = "base64_encoded_timestamp"
}
```

### Growth Calculation
```lua
-- Single sprinkler: 1.5x boost
-- Two different sprinklers: 1.5 * 1.5 = 2.25x boost
-- Three different sprinklers: 1.5 * 1.5 * 1.5 = 3.375x boost
```

## Remote Events

### Server → Client
- `FXRemote:FireAllClients("SprinklerStart", {ID, Model, Type})`
  - Starts VFX for a sprinkler
  
- `FXRemote:FireAllClients("SprinklerStop", {ID})`
  - Stops VFX for a sprinkler

### Client → Server
- `PlotRemote:FireServer("RemoveGear", gearID)`
  - Requests removal of a gear/sprinkler

## Configuration

Sprinkler properties are defined in `/Shared/Modules/Libraries/GearsData.luau`:
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
```

## Future Improvements

1. **Overlapping Sprinklers**: Currently same-type sprinklers don't stack - this could be changed
2. **Upgradable Sprinklers**: Allow players to upgrade sprinkler duration/radius
3. **Sprinkler Refills**: Allow refilling sprinklers with water instead of replacing
4. **Visual Improvements**: Add more particle effects, sound effects
5. **UI Indicator**: Show active sprinkler radius when hovering over them

## Debugging

To test the sprinkler system:
1. Run `/Shared/Modules/Utilities/SprinklerTests.luau`
2. Check server output for placement/removal logs
3. Verify VFX appears on client when placing sprinklers
4. Check plant growth speed with and without sprinklers
5. Test removal functionality and inventory refund
