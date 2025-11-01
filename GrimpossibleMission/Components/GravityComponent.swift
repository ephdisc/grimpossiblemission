//
//  GravityComponent.swift
//  GrimpossibleMission
//
//  Component for entities affected by gravity.
//

import RealityKit

/// Component that marks entities as affected by gravity.
/// Entities with this component will fall when not grounded.
struct GravityComponent: Component {
    /// Fall speed in units per second
    var fallSpeed: Float = 12.0

    /// Whether gravity is currently being applied
    var isActive: Bool = true
}
