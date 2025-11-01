//
//  SolidComponent.swift
//  GrimpossibleMission
//
//  Component for collidable/solid objects.
//

import RealityKit

/// Type of solid object for collision handling
enum SolidType {
    case floor      // Blocks downward movement
    case wall       // Blocks horizontal movement
    case ceiling    // Blocks upward movement
    case platform   // Future: one-way platform (can pass through from below)
}

/// Component that marks entities as solid/collidable.
/// Entities without this component can be passed through (enemies, items, background).
struct SolidComponent: Component {
    /// Type of solid for collision response
    var type: SolidType = .floor

    /// Bounds for collision detection
    var bounds: SIMD3<Float> = SIMD3<Float>(1, 1, 1)

    /// Whether this solid is currently active
    var isActive: Bool = true
}
