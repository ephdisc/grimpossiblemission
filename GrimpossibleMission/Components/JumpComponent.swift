//
//  JumpComponent.swift
//  GrimpossibleMission
//
//  Component for jump state and arc tracking.
//
//  STATE MACHINE:
//  grounded -> ascending (jump button pressed)
//  ascending -> falling (complete arc t=1.0, land on floor, or hit ceiling/wall)
//  falling -> grounded (land on floor)
//
//  GRAVITY RULES:
//  - grounded: no vertical velocity
//  - ascending: follows parabolic arc (no gravity)
//  - falling: consistent gravity applied
//

import RealityKit

/// Jump state for the player
enum JumpState {
    case grounded       // Standing on floor, full movement control
    case ascending      // Following committed jump arc (t=0 to t=1.0), arc controls velocity
    case falling        // Free fall with gravity (after arc completes, walked off edge, or interrupted)
}

/// Component for entities that can jump (primarily the player).
struct JumpComponent: Component {
    /// Current jump state
    var state: JumpState = .grounded

    /// Jump arc dimensions (configured from GameConfig)
    var arcWidth: Float = 2.0
    var arcHeight: Float = 3.0

    /// Progress through jump arc (0.0 = start, 0.5 = peak, 1.0 = landing)
    /// Only used during ascending state
    var arcProgress: Float = 0.0

    /// Starting position of current jump (feet position)
    var jumpStartPosition: SIMD3<Float> = .zero

    /// Target landing position of current jump (feet position)
    var jumpTargetPosition: SIMD3<Float> = .zero

    /// Jump buffering - allows jump input slightly before landing
    var jumpBufferTimer: Float = 0.0

    /// Coyote time - grace period after walking off ledge
    var coyoteTimer: Float = 0.0

    /// Whether jump input is currently pressed (for input edge detection)
    var jumpInputPressed: Bool = false

    /// Check if entity is airborne (ascending or falling)
    var isAirborne: Bool {
        state == .ascending || state == .falling
    }

    /// Check if entity can initiate a jump
    var canJump: Bool {
        state == .grounded || (state == .falling && coyoteTimer > 0)
    }
}
