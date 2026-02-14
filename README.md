# Escape Acid Rain

A Roblox survival/tycoon game where players collect brainrots while avoiding deadly acid rain storms.

## Game Concept

- **Survival**: Dodge acid rain and toxic puddles by hiding in safe zones
- **Collection**: Run into dangerous zones to grab rare brainrots
- **Tycoon**: Deposit brainrots in your base for passive income
- **Progression**: Upgrade speed and carry capacity to reach farther zones

## Core Mechanics

### Acid Rain System
- Waves every 45 seconds
- 5-second warning before rain starts
- Toxic puddles spawn on ground
- Players take damage if exposed

### Safe Zones
- Umbrella structures scattered across map
- Buildings/caves for cover
- Visual indicators show safe areas

### Brainrot Collection
- Spawn in zones based on distance from spawn
- Further zones = rarer brainrots
- Hold up to 7 brainrots (upgradable)

### Base System
- Each player has their own base
- Deposit brainrots for passive income
- Upgrade base for more slots (up to 40)

### Upgrade System
- **Speed**: Reach farther zones faster
- **Capacity**: Carry more brainrots per run

## File Structure

```
EscapeAcidRain/
├── ServerScripts/
│   └── Main.server.lua       # Entry point
├── Systems/
│   ├── AcidRainSystem.lua    # Rain mechanics
│   ├── CollectionSystem.lua  # Brainrot spawning/collection
│   ├── SafeZoneSystem.lua    # Safe areas
│   ├── UpgradeSystem.lua     # Speed/capacity upgrades
│   ├── BaseSystem.lua        # Tycoon base
│   ├── PlayerDataSystem.lua  # Data persistence
│   └── PerformanceMonitor.lua # Performance tracking
├── Shared/
│   ├── AnalyticsService.lua  # Analytics integration
│   └── Modules/
│       └── Libraries/
│           └── BrainrotsData.luau  # Brainrot definitions
├── ClientScripts/            # (UI code goes here)
└── UI/                       # (UI layouts go here)
```

## Analytics Integration

Connected to analytics.arcadias.games for tracking:
- Player joins/leaves
- Brainrot collection rates
- Upgrade purchases
- Session duration

## Setup Instructions

1. Install Rojo plugin in Roblox Studio
2. Run `rojo serve` in project folder
3. Connect Studio to localhost:34872
4. Sync project to Studio

## Credits

Built with modules from FeedTheBrainrots for consistency.
