//
//  CameraController.swift
//  GrimpossibleMission
//
//  Protocol for camera control abstraction.
//

import Foundation
import RealityKit

/// Camera mode for different gameplay scenarios
enum CameraMode {
    case staticRoom(roomIndex: Int)
    case followPlayer
}

/// Protocol for controlling camera behavior.
/// Allows dependency injection of different camera implementations.
protocol CameraController {
    /// Update camera position and orientation
    /// - Parameters:
    ///   - deltaTime: Time elapsed since last frame
    ///   - playerPosition: Current player position
    ///   - mode: Current camera mode
    ///   - debugZoom: Whether debug zoom is active (zooms out to see all rooms)
    func update(deltaTime: TimeInterval, playerPosition: SIMD3<Float>, mode: CameraMode, debugZoom: Bool)

    /// Get the camera entity
    var cameraEntity: Entity { get }
}
