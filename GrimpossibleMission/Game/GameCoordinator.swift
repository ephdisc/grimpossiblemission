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

    /// Reference to player entity
    private(set) var player: Entity?

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

        // 6. Debug visualization system (renders debug overlays like jump arcs)
        let debugSystem = DebugVisualizationSystem()
        systems.append(debugSystem)

        // 7. Camera system (updates camera based on player position)
        let cameraSystem = CameraManagementSystem(cameraController: cameraController)
        self.cameraManagementSystem = cameraSystem
        systems.append(cameraSystem)

        if GameConfig.debugLogging {
            print("[GameCoordinator] Systems initialized: \(systems.count)")
        }
    }

    private func setupWorld() {
        // Create rooms
        roomEntities = createPOCRooms()
        entities.append(contentsOf: roomEntities)

        // Register rooms with camera system
        cameraManagementSystem?.registerRoomEntities(roomEntities)

        // Create player
        player = createPlayerEntity(
            startX: GameConfig.playerStartX,
            startY: GameConfig.playerStartY
        )
        if let player = player {
            entities.append(player)
        }

        // Create searchable items for testing
        let item1 = createSearchableItem(x: 10, y: 1, searchDuration: 2.0)
        entities.append(item1)

        let item2 = createSearchableItem(x: 25, y: 1, searchDuration: 3.0)
        entities.append(item2)

        let item3 = createSearchableItem(x: 40, y: 1, searchDuration: 2.5)
        entities.append(item3)

        if GameConfig.debugLogging {
            print("[GameCoordinator] World created: \(entities.count) entities")
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
}
