//
//  InputStateComponent.swift
//  GrimpossibleMission
//
//  Component that stores the current input state for an entity.
//

import RealityKit

/// Stores the current input state for player-controlled entities.
struct InputStateComponent: Component {
    // Movement inputs
    var moveLeft: Bool = false
    var moveRight: Bool = false
    var moveUp: Bool = false      // Used for searching items
    var moveDown: Bool = false

    // Action inputs
    var jump: Bool = false
    var interact: Bool = false    // X button - used for room restart when held
    var debugZoom: Bool = false   // R button - debug camera zoom to see all rooms

    // Restart tracking (X button hold)
    var restartHoldTime: Float = 0.0
    var restartTriggered: Bool = false

    /// Horizontal movement direction (-1 = left, 0 = none, 1 = right)
    var horizontalAxis: Float {
        if moveLeft && !moveRight {
            return -1.0
        } else if moveRight && !moveLeft {
            return 1.0
        }
        return 0.0
    }
}
