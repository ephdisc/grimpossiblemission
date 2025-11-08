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
    fileprivate var rooms: [RoomBoundsComponent] = []  // fileprivate for CameraManagementSystem access
    private var debugZoomActive: Bool = false
    private var currentZoomDistance: Float = GameConfig.cameraDistance

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

    func update(deltaTime: TimeInterval, playerPosition: SIMD3<Float>, mode: CameraMode, debugZoom: Bool = false) {
        // Update mode if changed
        if !modesEqual(currentMode, mode) {
            currentMode = mode
            updateTargetPosition(for: mode)
        }

        // Handle debug zoom
        if debugZoom != debugZoomActive {
            debugZoomActive = debugZoom
            if GameConfig.debugLogging {
                print("[CameraController] Debug zoom \(debugZoom ? "activated" : "deactivated")")
            }
        }

        // Calculate target zoom distance
        let targetZoomDistance: Float
        if debugZoomActive {
            // Zoom out to see all rooms (calculate based on number of rooms)
            // Assuming rooms are laid out horizontally
            let totalRooms = max(rooms.count, 1)
            let totalWidth = Float(totalRooms) * GameConfig.roomWidth
            // Camera needs to be far enough to see the full width (rough calculation)
            targetZoomDistance = totalWidth * 0.6  // Adjust multiplier as needed
        } else {
            targetZoomDistance = GameConfig.cameraDistance
        }

        // Smoothly interpolate zoom distance
        let zoomLerpFactor = min(Float(deltaTime) * 3.0, 1.0)  // Faster zoom transition
        currentZoomDistance = simd_mix(currentZoomDistance, targetZoomDistance, zoomLerpFactor)

        // Update target position Z based on current zoom
        targetPosition.z = -currentZoomDistance

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
            // Find the room by its roomIndex field, not by array position
            let roomCenterX: Float
            if let room = rooms.first(where: { $0.roomIndex == roomIndex }) {
                roomCenterX = room.center.x
            } else {
                // Fallback: assume horizontal layout (should not happen with proper registration)
                roomCenterX = Float(roomIndex) * GameConfig.roomWidth + GameConfig.roomWidth / 2.0
                if GameConfig.debugLogging {
                    print("[CameraController] ⚠️ Room \(roomIndex) not found in registered rooms, using fallback position")
                }
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
    private var lastDebugZoomState: Bool = false

    // Callback when player enters a new room
    var onRoomChanged: ((Int, SIMD3<Float>) -> Void)?

    // Callback when debug zoom is activated (to generate all rooms)
    var onDebugZoomActivated: (() -> Void)?

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

    /// Register a single room entity (for lazy loading)
    func registerRoomEntity(_ roomEntity: Entity, at index: Int) {
        // Append to rooms array if not already present
        if !rooms.contains(where: { $0 === roomEntity }) {
            rooms.append(roomEntity)
        }

        // Update camera controller's room bounds
        if let roomBounds = roomEntity.components[RoomBoundsComponent.self] {
            var allBounds = cameraController.rooms
            // Replace or add the bounds for this room index
            if let existingIndex = allBounds.firstIndex(where: { $0.roomIndex == index }) {
                allBounds[existingIndex] = roomBounds
            } else {
                allBounds.append(roomBounds)
                allBounds.sort { $0.roomIndex < $1.roomIndex }
            }
            cameraController.registerRooms(allBounds)
        }
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

        // Get debug zoom state from player input
        let debugZoom = player.components[InputStateComponent.self]?.debugZoom ?? false

        // Detect debug zoom activation (transition from false to true)
        if debugZoom && !lastDebugZoomState {
            if GameConfig.debugLogging {
                print("[CameraSystem] Debug zoom activated - requesting all rooms generation")
            }
            onDebugZoomActivated?()
        }
        lastDebugZoomState = debugZoom

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

        // Update camera with debug zoom state
        cameraController.update(
            deltaTime: deltaTime,
            playerPosition: playerPosition.simd,
            mode: cameraMode,
            debugZoom: debugZoom
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
