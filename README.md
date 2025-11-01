# GrimpossibleMission

A 2.5D platform game for tvOS 26 built with RealityKit and Entity Component System (ECS) architecture.

## Overview

GrimpossibleMission is an arcade-style platform game where players navigate through interconnected rooms, avoiding obstacles and collecting items. The game uses 3D models rendered in a 2.5D perspective, providing depth while maintaining classic platformer gameplay.

## Platform Requirements

- **Target Platform**: tvOS 26 (minimum)
- **Framework**: RealityKit
- **Language**: Swift
- **Architecture**: Entity Component System (ECS)

## Input Controls

### Game Controller (Xbox / PlayStation)
- **Left/Right**: Move character left/right
- **Up**: Interact with items
- **A/X Button**: Jump (directional based on facing)
- **B/Circle Button**: Captured (prevents exiting game)

### Siri Remote / Apple TV Remote
- **Swipe Left/Right**: Move character
- **Swipe Up**: Interact with items
- **Click/Select**: Jump

## Game Features

### Player Movement
- **Left**: Face left and move left
- **Right**: Face right and move right
- **Jump**: Arcade-style jumping (direction based on facing)
- **Elevator Controls**: Up/Down moves elevator between floors

### Level System
- World consists of connected rooms via elevator shafts
- Rooms defined in JSON format with:
  - 3D tile placement
  - Enemy spawn locations
  - Item spawn locations
- Modular level creation for easy content expansion

### Camera System
- **In Room**: Static camera showing entire room
- **In Elevator**: Smooth camera follow of player
- Seamless transitions between camera modes

## Architecture

### Entity Component System (ECS)
- **Composition over Inheritance**: All game objects built from reusable components
- **Systems**: Isolated logic processors for input, movement, rendering, camera
- **Components**: Pure data containers (Position, Velocity, Renderable, Input, etc.)

### Dependency Injection
- Protocol-based Swift native DI
- Decoupled systems for multi-platform support
- Testable and maintainable architecture

### Modular Design
- Reusable components for future projects
- Clear separation of concerns
- Easy to extend and modify

## Development

### Building from CLI
```bash
# Build for tvOS
xcodebuild -project GrimpossibleMission.xcodeproj -scheme GrimpossibleMission -destination 'platform=tvOS Simulator,name=Apple TV' build

# Run tests
xcodebuild test -project GrimpossibleMission.xcodeproj -scheme GrimpossibleMission -destination 'platform=tvOS Simulator,name=Apple TV'
```

### Project Structure
- Primitive shapes used during prototyping
- 3D models will replace primitives in production
- JSON-based level definitions for easy iteration

## Current Status

**POC Phase**: Building core gameplay mechanics with two-room prototype using primitive cubes.
