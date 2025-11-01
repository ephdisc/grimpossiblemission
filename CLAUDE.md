# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GrimpossibleMission is a 2.5D platform game for tvOS 26 built with RealityKit using a strict Entity Component System (ECS) architecture. The game features arcade-style movement, multiple input methods, and JSON-based level design.

## Critical Development Rules

### Planning and Execution
1. **Always create a plan first** - Do not make code changes without a written plan in the todo list
2. **Track progress** - Use TodoWrite to maintain an ongoing task list
3. **No deviation without approval** - Do not deviate from the plan without explicit human input
4. **Build verification required** - After code changes, verify CLI build/deployment works before marking tasks complete
5. **Never remove features** - Do not drop support or remove features because something is difficult or time-consuming
6. **Research when stuck** - Use web search to find best practices and current API documentation

### Code Quality Standards
- **Composition over inheritance** - Always prefer component composition
- **Clean implementation** - Code should make it easy to determine where changes are needed
- **Reusable components** - Build components that can be used in future projects
- **No shortcuts** - Maintain architectural integrity even under time pressure

## Architecture

### Entity Component System (ECS)

The game follows a strict ECS architecture where:

1. **Entities**: Containers for components (use RealityKit's Entity class)
2. **Components**: Pure data structures conforming to RealityKit's Component protocol
3. **Systems**: Logic processors that operate on entities with specific component combinations

**Key Principle**: Components store data, Systems contain logic. Never put behavior in components.

### Dependency Injection

Use protocol-based Swift native dependency injection:

```swift
// Define protocols for dependencies
protocol InputProvider {
    func getInput() -> InputState
}

protocol CameraController {
    func updateCamera(for entity: Entity, in scene: Scene)
}

// Inject dependencies through initializers
class MovementSystem {
    private let inputProvider: InputProvider

    init(inputProvider: InputProvider) {
        self.inputProvider = inputProvider
    }
}
```

This approach:
- Enables testing with mock implementations
- Supports future multi-platform expansion
- Maintains clean separation of concerns
- Requires no third-party dependencies

### Project Structure

```
GrimpossibleMission/
├── Components/          # ECS Components (data only)
│   ├── PositionComponent.swift
│   ├── VelocityComponent.swift
│   ├── RenderableComponent.swift
│   └── InputComponent.swift
├── Systems/            # ECS Systems (logic only)
│   ├── InputSystem.swift
│   ├── MovementSystem.swift
│   ├── CameraSystem.swift
│   └── RenderSystem.swift
├── Protocols/          # DI and architecture protocols
│   ├── InputProvider.swift
│   ├── CameraController.swift
│   └── SystemProtocol.swift
├── Entities/           # Entity factory functions
│   ├── PlayerEntity.swift
│   └── TileEntity.swift
├── Models/             # Data models (level JSON, etc.)
│   └── LevelData.swift
└── Game/              # Game coordinator and main logic
    └── GameCoordinator.swift
```

## Platform-Specific Requirements

### tvOS 26 Targeting
- **Minimum version**: tvOS 26 (RealityKit requirement)
- **Never downgrade** the tvOS version - RealityKit is not supported on earlier versions
- Use latest RealityKit APIs available in tvOS 26

### Input Handling

#### Game Controller (Priority 1)
```swift
// Capture B button to prevent game exit
controller.extendedGamepad?.buttonB?.pressedChangedHandler = { (button, value, pressed) in
    // Handle B button, prevents default tvOS behavior
}
```

#### Siri Remote (Priority 2)
- Map swipe gestures to directional input
- Click/Select for jump action
- Ensure full game playability with remote only

## Game Design Specifications

### 2.5D Gameplay
- Use full 3D RealityKit models for visual depth
- Constrain player movement to 2D plane (X and Y axes)
- Camera positioned to show side-scrolling perspective
- Z-axis used for visual layering only

### Movement System (Arcade-Style)
- **No physics-based movement** - Use discrete, predictable movement
- **Grid-based or fixed velocity** - Consistent, arcade feel
- Left/Right: Immediate direction change and movement
- Jump: Fixed arc/height (to be implemented later)
- No momentum, no acceleration curves

### Camera Behavior
- **In Room**: Static orthographic or fixed perspective showing entire room bounds
- **In Elevator Shaft**: Smooth follow camera tracking player position
- **Transitions**: Smooth interpolation between camera modes when crossing boundaries

### Level Structure
- World made of discrete "rooms" connected by elevator shaft
- Rooms defined in JSON with:
  ```json
  {
    "rooms": [
      {
        "id": "room_1",
        "tiles": [{"x": 0, "y": 0, "z": 0, "type": "floor"}],
        "enemies": [{"x": 5, "y": 1, "type": "basic"}],
        "items": [{"x": 10, "y": 2, "type": "coin"}]
      }
    ]
  }
  ```
- Elevator shaft connects rooms vertically

## Building and Testing

### Build from CLI
```bash
# Build for tvOS simulator
xcodebuild -project GrimpossibleMission.xcodeproj \
  -scheme GrimpossibleMission \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  build

# Run on specific tvOS version
xcodebuild -project GrimpossibleMission.xcodeproj \
  -scheme GrimpossibleMission \
  -destination 'platform=tvOS Simulator,name=Apple TV,OS=18.0' \
  build

# Run tests
xcodebuild test -project GrimpossibleMission.xcodeproj \
  -scheme GrimpossibleMission \
  -destination 'platform=tvOS Simulator,name=Apple TV'
```

### Testing Requirements
- All systems must be unit testable via dependency injection
- Use Swift Testing framework (@Test macro, #expect assertions)
- Mock implementations for all protocol-based dependencies

## POC Scope (Current Phase)

### Goal
Create a minimal playable prototype to validate:
1. Game controller input works smoothly
2. Player can move left/right with arcade-style controls
3. Two side-by-side rooms with primitive cube tiles
4. Camera transitions between rooms at boundaries

### Out of Scope for POC
- Jumping mechanics
- Gravity/physics
- Elevator shaft
- JSON level loading
- Siri Remote support
- Enemy AI
- Items/collectibles

### Success Criteria
- Player (primitive cube) responds to game controller
- Player moves between two rooms made of primitive cubes
- Camera changes appropriately when crossing room boundary
- Game builds and deploys via CLI to tvOS simulator
- B button captured and doesn't exit game

## Component Examples

### Creating a Component
```swift
import RealityKit

struct PositionComponent: Component {
    var x: Float
    var y: Float
    var z: Float
}

struct VelocityComponent: Component {
    var dx: Float
    var dy: Float
}
```

### Creating a System
```swift
protocol GameSystem {
    func update(deltaTime: TimeInterval, entities: [Entity])
}

class MovementSystem: GameSystem {
    func update(deltaTime: TimeInterval, entities: [Entity]) {
        for entity in entities {
            guard let position = entity.components[PositionComponent.self],
                  let velocity = entity.components[VelocityComponent.self] else {
                continue
            }

            // Update position based on velocity
            var newPosition = position
            newPosition.x += velocity.dx * Float(deltaTime)
            newPosition.y += velocity.dy * Float(deltaTime)
            entity.components.set(newPosition)
        }
    }
}
```

## Common Patterns

### Entity Creation
```swift
func createPlayer() -> Entity {
    let entity = Entity()
    entity.components.set(PositionComponent(x: 0, y: 0, z: 0))
    entity.components.set(VelocityComponent(dx: 0, dy: 0))
    entity.components.set(ModelComponent(/* ... */))
    return entity
}
```

### System Update Loop
```swift
class GameCoordinator {
    private var systems: [GameSystem] = []
    private var entities: [Entity] = []

    func update(deltaTime: TimeInterval) {
        for system in systems {
            system.update(deltaTime: deltaTime, entities: entities)
        }
    }
}
```
