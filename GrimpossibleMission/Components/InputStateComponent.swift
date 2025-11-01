//
//  InputStateComponent.swift
//  GrimpossibleMission
//
//  Component that stores the current input state for an entity.
//

import RealityKit

/// Stores the current input state for player-controlled entities.
struct InputStateComponent: Component {
    var moveLeft: Bool = false
    var moveRight: Bool = false
    var moveUp: Bool = false
    var moveDown: Bool = false
    var jump: Bool = false
    var interact: Bool = false

    /// Horizontal movement direction (-1 = left, 0 = none, 1 = right)
    var horizontalAxis: Float {
        if moveLeft && !moveRight {
            return -1.0
        } else if moveRight && !moveLeft {
            return 1.0
        }
        return 0.0
    }

    /// Vertical movement direction (-1 = down, 0 = none, 1 = up)
    var verticalAxis: Float {
        if moveDown && !moveUp {
            return -1.0
        } else if moveUp && !moveDown {
            return 1.0
        }
        return 0.0
    }
}
