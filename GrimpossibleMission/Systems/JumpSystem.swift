//
//  JumpSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles impulse-based jumping.
//
//  RESPONSIBILITY:
//  - Detects jump input and applies velocity impulse (upward + horizontal)
//  - Always jumps at full speed in facing direction (even when standing still)
//  - Manages jump buffering and coyote time
//  - Simple and predictable jump physics
//

import Foundation
import RealityKit

/// System that manages impulse-based jumping
class JumpSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        for entity in entities {
            guard var jumpComponent = entity.components[JumpComponent.self],
                  var velocity = entity.components[VelocityComponent.self],
                  let inputState = entity.components[InputStateComponent.self],
                  let facing = entity.components[FacingDirectionComponent.self] else {
                continue
            }

            // Update jump timers (buffer and coyote time)
            updateTimers(&jumpComponent, deltaTime: Float(deltaTime))

            // Handle jump input
            handleJumpInput(&jumpComponent, velocity: &velocity, inputState: inputState, facing: facing)

            // Update components
            entity.components.set(jumpComponent)
            entity.components.set(velocity)
        }
    }

    // MARK: - Jump Input Handling

    /// Handles jump button press and applies upward impulse
    private func handleJumpInput(
        _ jump: inout JumpComponent,
        velocity: inout VelocityComponent,
        inputState: InputStateComponent,
        facing: FacingDirectionComponent
    ) {
        // Detect jump button press (rising edge)
        if inputState.jump && !jump.jumpInputPressed {
            jump.jumpInputPressed = true

            // Try to start jump if grounded or within coyote time
            if jump.canJump {
                applyJumpImpulse(&jump, velocity: &velocity, facing: facing)
            } else {
                // Buffer the jump input for when we land
                jump.jumpBufferTimer = GameConfig.jumpBufferTime
            }
        } else if !inputState.jump {
            jump.jumpInputPressed = false
        }

        // Check jump buffer when landing
        if jump.state == .grounded && jump.jumpBufferTimer > 0 {
            applyJumpImpulse(&jump, velocity: &velocity, facing: facing)
        }
    }

    /// Applies upward and horizontal velocity impulse for jump
    private func applyJumpImpulse(_ jump: inout JumpComponent, velocity: inout VelocityComponent, facing: FacingDirectionComponent) {
        jump.state = .airborne
        jump.jumpBufferTimer = 0.0

        // Apply upward impulse
        velocity.dy = GameConfig.jumpVelocity

        // Apply full horizontal speed in facing direction
        velocity.dx = facing.direction == .right ? GameConfig.playerMoveSpeed : -GameConfig.playerMoveSpeed

        if GameConfig.debugLogging {
            let direction = facing.direction == .right ? "right" : "left"
            print("[Jump] Applied jump impulse: dy=\(GameConfig.jumpVelocity), dx=\(velocity.dx) (\(direction))")
        }
    }

    // MARK: - Timer Management

    /// Updates jump buffer and coyote timers
    private func updateTimers(_ jump: inout JumpComponent, deltaTime: Float) {
        // Update jump buffer timer
        if jump.jumpBufferTimer > 0 {
            jump.jumpBufferTimer -= deltaTime
            jump.jumpBufferTimer = max(jump.jumpBufferTimer, 0)
        }

        // Update coyote timer (only when airborne)
        if jump.state == .airborne {
            if jump.coyoteTimer > 0 {
                jump.coyoteTimer -= deltaTime
                jump.coyoteTimer = max(jump.coyoteTimer, 0)
            }
        } else if jump.state == .grounded {
            // Reset coyote timer when grounded
            jump.coyoteTimer = GameConfig.coyoteTime
        }
    }
}
