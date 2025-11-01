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
        // Note: RealityKit doesn't have built-in orthographic camera on tvOS
        // We'll use a perspective camera positioned far back to minimize distortion
        let cameraComponent = PerspectiveCameraComponent()
        cameraEntity.components.set(cameraComponent)

        // Calculate initial camera position
        // Position camera to view Room 0 (x: 0-32, y: 0-18)
        let roomCenterX: Float = GameConfig.roomWidth / 2.0
        let roomCenterY: Float = GameConfig.roomHeight / 2.0

        // Camera positioned in front (negative Z) and above, tilted down
        let distance = GameConfig.cameraDistance
        let tiltRadians = GameConfig.cameraTiltDegrees * .pi / 180.0

        // Calculate camera position with tilt
        let cameraX = roomCenterX
        let cameraY = roomCenterY + distance * sin(tiltRadians)
        let cameraZ = -distance * cos(tiltRadians)

        currentPosition = SIMD3<Float>(cameraX, cameraY, cameraZ)
        targetPosition = currentPosition
        cameraEntity.position = currentPosition

        // Look at room center
        cameraEntity.look(at: SIMD3<Float>(roomCenterX, roomCenterY, 0), from: currentPosition, relativeTo: nil)
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

        // Smoothly interpolate to target position
        let lerpFactor = min(Float(deltaTime / GameConfig.cameraTransitionDuration), 1.0)
        currentPosition = simd_mix(currentPosition, targetPosition, SIMD3<Float>(repeating: lerpFactor))

        cameraEntity.position = currentPosition

        // Update look-at target based on mode
        let lookAtTarget: SIMD3<Float>
        switch mode {
        case .staticRoom(let roomIndex):
            if roomIndex < rooms.count {
                let room = rooms[roomIndex]
                lookAtTarget = SIMD3<Float>(room.center.x, room.center.y, 0)
            } else {
                lookAtTarget = SIMD3<Float>(GameConfig.roomWidth / 2, GameConfig.roomHeight / 2, 0)
            }
        case .followPlayer:
            lookAtTarget = playerPosition
        }

        cameraEntity.look(at: lookAtTarget, from: currentPosition, relativeTo: nil)
    }

    private func updateTargetPosition(for mode: CameraMode) {
        let distance = GameConfig.cameraDistance
        let tiltRadians = GameConfig.cameraTiltDegrees * .pi / 180.0

        switch mode {
        case .staticRoom(let roomIndex):
            // Position camera to view entire room
            let roomCenterX: Float
            let roomCenterY: Float = GameConfig.roomHeight / 2.0

            if roomIndex < rooms.count {
                let room = rooms[roomIndex]
                roomCenterX = room.center.x
            } else {
                // Default to room index calculation
                roomCenterX = Float(roomIndex) * GameConfig.roomWidth + GameConfig.roomWidth / 2.0
            }

            let cameraX = roomCenterX
            let cameraY = roomCenterY + distance * sin(tiltRadians)
            let cameraZ = -distance * cos(tiltRadians)

            targetPosition = SIMD3<Float>(cameraX, cameraY, cameraZ)

        case .followPlayer:
            // For follow mode, position camera behind and above player
            // This will be used for elevator shafts in future
            let cameraX: Float = 0.0 // Will track player X later
            let cameraY = distance * sin(tiltRadians)
            let cameraZ = -distance * cos(tiltRadians)

            targetPosition = SIMD3<Float>(cameraX, cameraY, cameraZ)
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

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Find player entity
        guard let player = entities.first(where: { $0.components[PlayerComponent.self] != nil }),
              let playerPosition = player.components[PositionComponent.self] else {
            return
        }

        // Determine which room the player is in
        let currentRoom = determinePlayerRoom(playerPosition: playerPosition)

        // Set camera mode based on player location
        let cameraMode: CameraMode = .staticRoom(roomIndex: currentRoom)

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
