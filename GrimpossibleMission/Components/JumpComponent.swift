//
//  JumpComponent.swift
//  GrimpossibleMission
//
//  Component for jump state tracking.
//
//  STATE MACHINE:
//  grounded -> airborne (jump button pressed, apply upward impulse)
//  airborne -> grounded (land on floor)
//
//  PHYSICS:
//  - Impulse-based jumping (apply velocity, gravity pulls down)
//  - Constant gravity always applies when airborne
//  - Committed trajectory (no air control - locked until landing)
//

import RealityKit

/// Jump state for the player
enum JumpState {
    case grounded   // Standing on floor
    case airborne   // In the air (jumping or falling)
}

/// Component for entities that can jump (primarily the player).
struct JumpComponent: Component {
    /// Current jump state
    var state: JumpState = .grounded

    /// Jump buffering - allows jump input slightly before landing
    var jumpBufferTimer: Float = 0.0

    /// Coyote time - grace period after walking off ledge
    var coyoteTimer: Float = 0.0

    /// Whether jump input is currently pressed (for input edge detection)
    var jumpInputPressed: Bool = false

    /// Check if entity can initiate a jump
    var canJump: Bool {
        state == .grounded || (state == .airborne && coyoteTimer > 0)
    }
}
