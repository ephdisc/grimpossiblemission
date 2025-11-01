//
//  PositionComponent.swift
//  GrimpossibleMission
//
//  Component that stores entity position in world space.
//

import RealityKit

/// Stores the position of an entity in 3D world space.
/// Note: This complements RealityKit's Transform component for game logic.
struct PositionComponent: Component {
    var x: Float
    var y: Float
    var z: Float

    init(x: Float = 0, y: Float = 0, z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Convert to SIMD3 for RealityKit usage
    var simd: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}
