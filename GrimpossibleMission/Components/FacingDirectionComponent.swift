//
//  FacingDirectionComponent.swift
//  GrimpossibleMission
//
//  Component that tracks which direction an entity is facing.
//

import RealityKit

/// Direction an entity is facing
enum Direction {
    case left
    case right
}

/// Stores which direction an entity is facing.
/// Used for movement and animation logic.
struct FacingDirectionComponent: Component {
    var direction: Direction

    init(direction: Direction = .right) {
        self.direction = direction
    }
}
