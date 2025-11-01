//
//  JumpComponent.swift
//  GrimpossibleMission
//
//  Component for jump state and arc tracking.
//

import RealityKit

/// Jump state for the player
enum JumpState {
    case grounded       // Standing on floor, can jump
    case jumping        // Ascending in jump arc
    case falling        // Descending (from jump or walked off ledge)
}

/// Component for entities that can jump (primarily the player).
struct JumpComponent: Component {
    /// Current jump state
    var state: JumpState = .grounded

    /// Jump arc parameters (in tiles)
    var arcWidth: Float = 3.0
    var arcHeight: Float = 2.0

    /// Progress through jump arc (0.0 = start, 1.0 = end)
    var arcProgress: Float = 0.0

    /// Starting position of current jump
    var jumpStartPosition: SIMD3<Float> = .zero

    /// Target landing position of current jump
    var jumpTargetPosition: SIMD3<Float> = .zero

    /// Jump buffering - time remaining in buffer window
    var jumpBufferTimer: Float = 0.0

    /// Coyote time - time remaining after walking off ledge
    var coyoteTimer: Float = 0.0

    /// Whether jump input is currently pressed
    var jumpInputPressed: Bool = false

    /// Check if entity is airborne
    var isAirborne: Bool {
        state == .jumping || state == .falling
    }

    /// Check if entity can jump (grounded or within coyote time)
    var canJump: Bool {
        state == .grounded || (state == .falling && coyoteTimer > 0)
    }
}
