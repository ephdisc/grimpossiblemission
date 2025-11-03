//
//  CameraSystem.swift
//  GrimpossibleMission
//
//  ECS System and Controller for camera management with room transitions.
//

import Foundation
import RealityKit

/// Manages camera positioning and transitions between rooms.
class OrthographicCameraController: CameraController {

    let cameraEntity: Entity
    private var currentMode: CameraMode = .staticRoom(roomIndex: 0)
    private var targetPosition: SIMD3<Float>
    private var currentPosition: SIMD3<Float>
    private var rooms: [RoomBoundsComponent] = []

    init() {
        // Create camera entity
        cameraEntity = Entity()

        // Set up perspective camera component
        let cameraComponent = PerspectiveCameraComponent()
        cameraEntity.components.set(cameraComponent)

        // Calculate initial camera position for Room 0
        let roomCenterX = GameConfig.roomWidth / 2.0
        let roomCenterY = GameConfig.roomHeight / 2.0

        // Camera positioned in front (negative Z), no tilt
        currentPosition = SIMD3<Float>(
            roomCenterX,
            roomCenterY,
            GameConfig.cameraZOffset
        )
        targetPosition = currentPosition
        cameraEntity.position = currentPosition

        // Set camera to look at room center
        cameraEntity.look(
            at: SIMD3<Float>(roomCenterX, roomCenterY, 0),
            from: currentPosition,
            relativeTo: nil
        )
    }

    /// Set the initial camera position to a specific room
    func setInitialRoom(_ roomIndex: Int) {
        currentMode = .staticRoom(roomIndex: roomIndex)
        updateTargetPosition(for: currentMode)

        // Set current position to target immediately (no lerp on initialization)
        currentPosition = targetPosition
        cameraEntity.position = currentPosition

        // Update look-at target
        let roomCenterY = Float(GameConfig.roomHeight) / 2.0
        let lookAtTarget = SIMD3<Float>(currentPosition.x, roomCenterY, 0)
        cameraEntity.look(at: lookAtTarget, from: currentPosition, relativeTo: nil)
    }

    /// Register room bounds for camera management
    func registerRooms(_ roomBounds: [RoomBoundsComponent]) {
        self.rooms = roomBounds.sorted { $0.roomIndex < $1.roomIndex }
    }

    func update(deltaTime: TimeInterval, playerPosition: SIMD3<Float>, mode: CameraMode) {
        // Update mode if changed
        if !modesEqual(currentMode, mode) {
            currentMode = mode
            updateTargetPosition(for: mode)
        }

        // Smoothly interpolate to target position (lateral translation only)
        let lerpFactor = min(Float(deltaTime / GameConfig.cameraTransitionDuration), 1.0)
        currentPosition = simd_mix(currentPosition, targetPosition, SIMD3<Float>(repeating: lerpFactor))

        // Update position
        cameraEntity.position = currentPosition

        // Update look-at target to keep camera centered on current X position
        let roomCenterY = Float(GameConfig.roomHeight) / 2.0
        let lookAtTarget = SIMD3<Float>(currentPosition.x, roomCenterY, 0)
        cameraEntity.look(at: lookAtTarget, from: currentPosition, relativeTo: nil)
    }

    private func updateTargetPosition(for mode: CameraMode) {
        switch mode {
        case .staticRoom(let roomIndex):
            // Position camera to view entire room
            let roomCenterX: Float
            if roomIndex < rooms.count {
                let room = rooms[roomIndex]
                roomCenterX = room.center.x
            } else {
                // Default to room index calculation
                roomCenterX = Float(roomIndex) * GameConfig.roomWidth + GameConfig.roomWidth / 2.0
            }

            targetPosition = SIMD3<Float>(
                roomCenterX,
                GameConfig.roomHeight / 2.0,
                GameConfig.cameraZOffset
            )

        case .followPlayer:
            // For follow mode, position camera behind and above player
            // This will be used for elevator shafts in future
            targetPosition = SIMD3<Float>(
                0.0,
                GameConfig.roomHeight / 2.0,
                GameConfig.cameraZOffset
            )
        }
    }

    private func modesEqual(_ mode1: CameraMode, _ mode2: CameraMode) -> Bool {
        switch (mode1, mode2) {
        case (.staticRoom(let room1), .staticRoom(let room2)):
            return room1 == room2
        case (.followPlayer, .followPlayer):
            return true
        default:
            return false
        }
    }
}

/// System that manages camera behavior and room transitions.
class CameraManagementSystem: GameSystem {

    private let cameraController: OrthographicCameraController
    private var rooms: [Entity] = []
    private var currentRoomIndex: Int = 0

    // Callback when player enters a new room
    var onRoomChanged: ((Int, SIMD3<Float>) -> Void)?

    init(cameraController: OrthographicCameraController) {
        self.cameraController = cameraController
    }

    /// Register room entities for boundary checking
    func registerRoomEntities(_ roomEntities: [Entity]) {
        self.rooms = roomEntities

        // Extract room bounds and register with camera controller
        let roomBounds = roomEntities.compactMap { $0.components[RoomBoundsComponent.self] }
        cameraController.registerRooms(roomBounds)
    }

    /// Set the initial room index (for spawn positioning)
    func setInitialRoom(_ roomIndex: Int) {
        currentRoomIndex = roomIndex
        cameraController.setInitialRoom(roomIndex)

        if GameConfig.debugLogging {
            print("[CameraSystem] Initial room set to \(roomIndex)")
        }
    }

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Find player entity
        guard let player = entities.first(where: { $0.components[PlayerComponent.self] != nil }),
              let playerPosition = player.components[PositionComponent.self] else {
            return
        }

        // Determine which room the player is in
        let roomIndex = determinePlayerRoom(playerPosition: playerPosition)

        // Check if player entered a new room
        if roomIndex != currentRoomIndex {
            if GameConfig.debugLogging {
                print("[CameraSystem] Player entered room \(roomIndex) from room \(currentRoomIndex)")
            }

            currentRoomIndex = roomIndex

            // Notify delegate with room index and player position
            onRoomChanged?(roomIndex, playerPosition.simd)
        }

        // Set camera mode based on player location
        let cameraMode: CameraMode = .staticRoom(roomIndex: roomIndex)

        // Update camera
        cameraController.update(
            deltaTime: deltaTime,
            playerPosition: playerPosition.simd,
            mode: cameraMode
        )
    }

    private func determinePlayerRoom(playerPosition: PositionComponent) -> Int {
        // Check each room to see if player is within bounds
        for room in rooms {
            if let bounds = room.components[RoomBoundsComponent.self],
               bounds.contains(x: playerPosition.x, y: playerPosition.y) {
                return bounds.roomIndex
            }
        }

        // Default to room 0 if not in any registered room
        return 0
    }
}
