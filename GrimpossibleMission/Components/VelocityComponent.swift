//
//  VelocityComponent.swift
//  GrimpossibleMission
//
//  Component that stores entity velocity for movement.
//

import RealityKit

/// Stores the velocity of an entity in units per second.
struct VelocityComponent: Component {
    var dx: Float
    var dy: Float

    init(dx: Float = 0, dy: Float = 0) {
        self.dx = dx
        self.dy = dy
    }

    /// Check if entity is moving
    var isMoving: Bool {
        dx != 0 || dy != 0
    }
}
