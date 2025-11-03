//
//  GameCoordinator.swift
//  GrimpossibleMission
//
//  Main coordinator that manages the ECS lifecycle and game loop.
//

import Foundation
import SwiftUI
import RealityKit
import Combine

/// Coordinates the game loop, systems, and entities.
@Observable
class GameCoordinator {

    // MARK: - Properties

    /// All game systems that run each frame
    private var systems: [GameSystem] = []

    /// All entities in the game world
    private var entities: [Entity] = []

    /// Room entities for camera management
    private var roomEntities: [Entity] = []

    /// Input provider (injected)
    private let inputProvider: InputProvider

    /// Camera controller (injected)
    let cameraController: OrthographicCameraController

    /// Camera management system
    private var cameraManagementSystem: CameraManagementSystem?

    /// Room restart system
    private var roomRestartSystem: RoomRestartSystem?

    /// Reference to player entity
    private(set) var player: Entity?

    /// Player entrance position for current room (captured when entering)
    private var roomEntrancePosition: SIMD3<Float> = SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)

    /// Current room index
    private var currentRoomIndex: Int = 0

    /// Timer for update loop
    private var updateTimer: Timer?

    /// Last update time for delta time calculation
    private var lastUpdateTime: TimeInterval = 0

    /// Velocity tracking for debug
    private var minVelocityX: Float = 0
    private var maxVelocityX: Float = 0
    private var minVelocityY: Float = 0
    private var maxVelocityY: Float = 0
    private var lastJumpTime: TimeInterval = 0
    private var wasJumping: Bool = false

    // MARK: - Initialization

    init(inputProvider: InputProvider, cameraController: OrthographicCameraController) {
        self.inputProvider = inputProvider
        self.cameraController = cameraController

        setupSystems()
        setupWorld()
    }

    // MARK: - Setup

    private func setupSystems() {
        // Create systems in order of execution

        // 1. Input system (reads controller input)
        let inputSystem = InputSystem(inputProvider: inputProvider)
        systems.append(inputSystem)

        // 2. Jump system (handles jump logic and arc calculation)
        let jumpSystem = JumpSystem()
        systems.append(jumpSystem)

        // 3. Movement system (converts input to velocity)
        let movementSystem = MovementSystem()
        systems.append(movementSystem)

        // 4. Physics system (applies gravity, velocity, and collision)
        let physicsSystem = PhysicsSystem()
        systems.append(physicsSystem)

        // 5. Search system (handles searchable item interactions)
        let searchSystem = SearchSystem()
        systems.append(searchSystem)

        // 6. Room restart system (monitors X button hold for restart)
        let restartSystem = RoomRestartSystem()
        restartSystem.onRestartRequested = { [weak self] in
            self?.restartRoom()
        }
        self.roomRestartSystem = restartSystem
        systems.append(restartSystem)

        // 7. Debug visualization system (renders debug overlays like jump arcs)
        let debugSystem = DebugVisualizationSystem()
        systems.append(debugSystem)

        // 8. Camera system (updates camera based on player position)
        let cameraSystem = CameraManagementSystem(cameraController: cameraController)
        cameraSystem.onRoomChanged = { [weak self] roomIndex, playerPosition in
            self?.onPlayerEnteredRoom(roomIndex: roomIndex, entryPosition: playerPosition)
        }
        self.cameraManagementSystem = cameraSystem
        systems.append(cameraSystem)

        if GameConfig.debugLogging {
            print("[GameCoordinator] Systems initialized: \(systems.count)")
        }
    }

    private func setupWorld() {
        var spawnPosition: SIMD3<Float>? = nil
        var spawnRoomIndex: Int = 0

        // Load level from JSON
        if let levelData = LevelLoader.loadLevel(filename: "level_001") {
            // Create rooms and searchable items from level data
            let result = createRoomsFromLevel(levelData: levelData)
            roomEntities = result.rooms
            entities.append(contentsOf: roomEntities)

            // Add searchable items to entities (not room children)
            entities.append(contentsOf: result.searchables)

            // Find spawn position from level data
            if let spawn = findSpawnPosition(levelData: levelData) {
                spawnPosition = spawn.position
                spawnRoomIndex = spawn.roomIndex

                if GameConfig.debugLogging {
                    print("[GameCoordinator] Found spawn point in room \(spawnRoomIndex) at position (\(spawn.position.x), \(spawn.position.y))")
                }
            } else {
                print("[GameCoordinator] Warning: No spawn point found in level, using default position")
                spawnPosition = SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)
            }

            if GameConfig.debugLogging {
                print("[GameCoordinator] Loaded level with \(roomEntities.count) rooms and \(result.searchables.count) searchable items")
            }
        } else {
            // Fallback to hardcoded POC rooms if JSON loading fails
            print("[GameCoordinator] Warning: Failed to load level JSON, using POC rooms")
            roomEntities = createPOCRooms()
            entities.append(contentsOf: roomEntities)
            spawnPosition = SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)
        }

        // Register rooms with camera system
        cameraManagementSystem?.registerRoomEntities(roomEntities)

        // Set camera to spawn room
        cameraManagementSystem?.setInitialRoom(spawnRoomIndex)

        // Use spawn position for player creation (or fall back to default)
        let finalSpawnPosition = spawnPosition ?? SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)

        // Create player at spawn position
        player = createPlayerEntity(
            startX: finalSpawnPosition.x,
            startY: finalSpawnPosition.y
        )
        if let player = player {
            entities.append(player)

            // Set initial entrance position to spawn position
            roomEntrancePosition = finalSpawnPosition

            // Set initial room index to spawn room
            currentRoomIndex = spawnRoomIndex
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] World created: \(entities.count) entities")
            print("[GameCoordinator] Initial spawn position: (\(finalSpawnPosition.x), \(finalSpawnPosition.y)) in room \(spawnRoomIndex)")
            print("[GameCoordinator] Initial entrance position: (\(roomEntrancePosition.x), \(roomEntrancePosition.y))")
        }
    }

    // MARK: - Lifecycle

    /// Start the game loop
    func start() {
        // Start input listening
        inputProvider.startListening()

        // Start update loop
        lastUpdateTime = CACurrentMediaTime()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Game started")
        }
    }

    /// Stop the game loop
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil

        inputProvider.stopListening()

        if GameConfig.debugLogging {
            print("[GameCoordinator] Game stopped")
        }
    }

    /// Update all systems (called each frame)
    private func update() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Track velocity min/max and detect jumps
        updateVelocityTracking(currentTime: currentTime)

        // Update all systems
        for system in systems {
            system.update(deltaTime: deltaTime, entities: entities)
        }
    }

    /// Track velocity min/max values and reset after 5s from last jump
    private func updateVelocityTracking(currentTime: TimeInterval) {
        guard let player = player,
              let velocity = player.components[VelocityComponent.self],
              let jump = player.components[JumpComponent.self] else {
            return
        }

        // Detect jump start (transition to airborne from grounded)
        let isJumping = jump.state == .airborne
        if isJumping && !wasJumping {
            // Jump just started - reset tracking
            minVelocityX = velocity.dx
            maxVelocityX = velocity.dx
            minVelocityY = velocity.dy
            maxVelocityY = velocity.dy
            lastJumpTime = currentTime
        }
        wasJumping = isJumping

        // Reset after 5 seconds from last jump
        if currentTime - lastJumpTime > 5.0 {
            minVelocityX = velocity.dx
            maxVelocityX = velocity.dx
            minVelocityY = velocity.dy
            maxVelocityY = velocity.dy
            lastJumpTime = currentTime
        }

        // Update min/max
        minVelocityX = min(minVelocityX, velocity.dx)
        maxVelocityX = max(maxVelocityX, velocity.dx)
        minVelocityY = min(minVelocityY, velocity.dy)
        maxVelocityY = max(maxVelocityY, velocity.dy)
    }

    // MARK: - Scene Management

    /// Add all entities to a RealityKit scene
    func addEntitiesToScene(_ content: some RealityViewContentProtocol) {
        // Add camera
        content.add(cameraController.cameraEntity)

        // Add all game entities
        for entity in entities {
            content.add(entity)
        }

        // Add lighting
        let light = PointLight()
        light.light.intensity = 10000
        light.position = SIMD3<Float>(16, 15, -10)
        content.add(light)

        // Add ambient light
        let ambient = PointLight()
        ambient.light.intensity = 5000
        ambient.position = SIMD3<Float>(48, 15, -10)
        content.add(ambient)

        if GameConfig.debugLogging {
            print("[GameCoordinator] Entities added to scene")
        }
    }

    // MARK: - Debug

    /// Print debug information about current game state
    func printDebugInfo() {
        print("=== Game State ===")
        print("Entities: \(entities.count)")
        print("Systems: \(systems.count)")

        if let player = player,
           let position = player.components[PositionComponent.self],
           let velocity = player.components[VelocityComponent.self] {
            print("Player Position: (\(position.x), \(position.y))")
            print("Player Velocity: (\(velocity.dx), \(velocity.dy))")
        }

        print("==================")
    }

    /// Get debug information about the nearest searchable item
    func getNearestSearchableItemInfo() -> String {
        guard let player = player,
              let playerPos = player.components[PositionComponent.self] else {
            return "No Player"
        }

        var nearestDistance: Float = .infinity
        var nearestInfo: String = "No items nearby"

        for entity in entities {
            guard let searchable = entity.components[SearchableComponent.self],
                  let progress = entity.components[ProgressComponent.self],
                  let itemPos = entity.components[PositionComponent.self] else {
                continue
            }

            let dx = itemPos.x - playerPos.x
            let dy = itemPos.y - playerPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < nearestDistance {
                nearestDistance = distance
                let statusText: String
                switch searchable.state {
                case .searchable:
                    statusText = "SEARCHABLE"
                case .searching:
                    statusText = "SEARCHING"
                case .searched:
                    statusText = "SEARCHED"
                }

                let progressPercent = Int(progress.progress * 100)
                nearestInfo = String(format: "%@\n%d%%\nDistance: %.1f units", statusText, progressPercent, distance)
            }
        }

        return nearestInfo
    }

    /// Get player velocity debug information
    func getPlayerVelocityInfo() -> String {
        guard let player = player,
              let velocity = player.components[VelocityComponent.self] else {
            return "No Player"
        }

        return String(format: """
            vX: %.1f (min: %.1f, max: %.1f)
            vY: %.1f (min: %.1f, max: %.1f)
            """,
            velocity.dx, minVelocityX, maxVelocityX,
            velocity.dy, minVelocityY, maxVelocityY)
    }

    // MARK: - Room Management

    /// Called when player enters a new room
    private func onPlayerEnteredRoom(roomIndex: Int, entryPosition: SIMD3<Float>) {
        currentRoomIndex = roomIndex
        roomEntrancePosition = entryPosition

        if GameConfig.debugLogging {
            print("[GameCoordinator] Player entered room \(roomIndex) at position (\(entryPosition.x), \(entryPosition.y))")
            print("[GameCoordinator] Room entrance position captured for restart")
        }
    }

    // MARK: - Room Restart

    /// Restart the current room by resetting player to entrance position and searchable items
    private func restartRoom() {
        guard let player = player else {
            return
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Restarting room \(currentRoomIndex)...")
        }

        // Reset player position to room entrance
        var position = player.components[PositionComponent.self] ?? PositionComponent(
            x: roomEntrancePosition.x,
            y: roomEntrancePosition.y,
            z: 0
        )
        position.x = roomEntrancePosition.x
        position.y = roomEntrancePosition.y
        position.z = roomEntrancePosition.z
        player.components.set(position)
        player.position = position.simd

        // Reset player velocity
        var velocity = player.components[VelocityComponent.self] ?? VelocityComponent(dx: 0, dy: 0)
        velocity.dx = 0
        velocity.dy = 0
        player.components.set(velocity)

        // Reset jump state to airborne (will become grounded on next physics update)
        var jump = player.components[JumpComponent.self] ?? JumpComponent()
        jump.state = .airborne
        player.components.set(jump)

        // Reset all searchable items in the current room
        for entity in entities {
            guard var searchable = entity.components[SearchableComponent.self],
                  var progress = entity.components[ProgressComponent.self] else {
                continue
            }

            // Reset searchable state
            if searchable.isSearched || searchable.state == .searching {
                searchable.state = .searchable
                searchable.timeSinceLastSearch = 0.0
                entity.components.set(searchable)

                // Reset progress
                progress.progress = 0.0
                entity.components.set(progress)

                // Remove progress bar bubble if it exists
                if let bubble = entity.children.first(where: { $0.name == "ProgressBarBubble" }) {
                    bubble.removeFromParent()
                }

                // Update visual state
                updateSearchableItemVisual(entity, state: .searchable)
            }
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Room restarted - player at (\(position.x), \(position.y))")
        }
    }
}
