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

        // 2. Movement system (converts input to velocity)
        let movementSystem = MovementSystem()
        systems.append(movementSystem)

        // 3. Physics system (applies velocity to position)
        let physicsSystem = PhysicsSystem()
        systems.append(physicsSystem)

        // 4. Camera system (updates camera based on player position)
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

        // Update all systems
        for system in systems {
            system.update(deltaTime: deltaTime, entities: entities)
        }
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
}
