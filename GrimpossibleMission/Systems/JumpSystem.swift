//
//  JumpSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles committed jump arcs.
//
//  RESPONSIBILITY:
//  - Detects jump input and initiates jumps
//  - Controls velocity during FULL parabolic arc (t=0 to t=1.0)
//  - Transitions to falling when arc completes OR interrupted by collision
//  - Manages jump buffering and coyote time
//

import Foundation
import RealityKit

/// System that manages jumping with committed arcs
class JumpSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        for entity in entities {
            guard var jumpComponent = entity.components[JumpComponent.self],
                  var velocity = entity.components[VelocityComponent.self],
                  let inputState = entity.components[InputStateComponent.self],
                  let facing = entity.components[FacingDirectionComponent.self],
                  let position = entity.components[PositionComponent.self] else {
                continue
            }

            // Update jump timers (buffer and coyote time)
            updateTimers(&jumpComponent, deltaTime: Float(deltaTime))

            // Handle jump input
            handleJumpInput(&jumpComponent, inputState: inputState, position: position, facing: facing)

            // Update jump arc if currently ascending
            if jumpComponent.state == .ascending {
                updateJumpArc(&jumpComponent, velocity: &velocity, deltaTime: Float(deltaTime))
            }

            // Update components
            entity.components.set(jumpComponent)
            entity.components.set(velocity)
        }
    }

    // MARK: - Jump Input Handling

    /// Handles jump button press and initiates jumps
    private func handleJumpInput(
        _ jump: inout JumpComponent,
        inputState: InputStateComponent,
        position: PositionComponent,
        facing: FacingDirectionComponent
    ) {
        // Detect jump button press (rising edge)
        if inputState.jump && !jump.jumpInputPressed {
            jump.jumpInputPressed = true

            // Try to start jump if grounded or within coyote time
            if jump.canJump {
                startJump(&jump, position: position, facing: facing)
            } else {
                // Buffer the jump input for when we land
                jump.jumpBufferTimer = GameConfig.jumpBufferTime
            }
        } else if !inputState.jump {
            jump.jumpInputPressed = false
        }

        // Check jump buffer when landing
        if jump.state == .grounded && jump.jumpBufferTimer > 0 {
            startJump(&jump, position: position, facing: facing)
        }
    }

    /// Initiates a jump with committed arc
    private func startJump(_ jump: inout JumpComponent, position: PositionComponent, facing: FacingDirectionComponent) {
        jump.state = .ascending
        jump.arcProgress = 0.0
        jump.jumpBufferTimer = 0.0

        // Arc starts from player's feet (bottom center)
        let playerBottomY = position.y - (GameConfig.playerHeight / 2.0)
        jump.jumpStartPosition = SIMD3<Float>(position.x, playerBottomY, position.z)

        // Calculate target landing position based on facing direction
        let horizontalDistance = facing.direction == .right ? jump.arcWidth : -jump.arcWidth
        jump.jumpTargetPosition = SIMD3<Float>(
            position.x + horizontalDistance,
            playerBottomY,
            position.z
        )

        if GameConfig.debugLogging {
            print("[Jump] Started jump - Arc: \(jump.arcWidth)w × \(jump.arcHeight)h")
        }
    }

    // MARK: - Jump Arc Physics

    /// Updates velocity based on jump arc progress (full parabolic arc)
    private func updateJumpArc(_ jump: inout JumpComponent, velocity: inout VelocityComponent, deltaTime: Float) {
        // Calculate total arc duration
        let totalDistance = jump.arcWidth
        let averageSpeed = (GameConfig.jumpAscentSpeed + GameConfig.jumpDescentSpeed) / 2.0
        let totalDuration = totalDistance / averageSpeed

        // Update arc progress
        jump.arcProgress += deltaTime / totalDuration
        jump.arcProgress = min(jump.arcProgress, 1.0)

        let t = jump.arcProgress
        let startPos = jump.jumpStartPosition
        let targetPos = jump.jumpTargetPosition

        // Check if we've completed the full arc (t >= 1.0)
        if t >= 1.0 {
            // Arc completed - transition to falling (gravity takes over)
            jump.state = .falling
            velocity.dx = 0  // Stop horizontal movement
            velocity.dy = 0  // Gravity will apply next frame

            if GameConfig.debugLogging {
                print("[Jump] Arc completed, transitioning to falling")
            }
            return
        }

        // Continue following the parabolic arc
        // Horizontal velocity (constant direction throughout arc)
        let direction: Float = (targetPos.x - startPos.x) > 0 ? 1.0 : -1.0
        velocity.dx = direction * totalDistance / totalDuration

        // Vertical velocity from derivative of parabola: dy/dt = 4 * h * (1 - 2t) / duration
        // This is positive when t < 0.5 (ascending) and negative when t > 0.5 (descending)
        let arcHeight = jump.arcHeight
        velocity.dy = 4.0 * arcHeight * (1.0 - 2.0 * t) / totalDuration
    }

    // MARK: - Timer Management

    /// Updates jump buffer and coyote timers
    private func updateTimers(_ jump: inout JumpComponent, deltaTime: Float) {
        // Update jump buffer timer
        if jump.jumpBufferTimer > 0 {
            jump.jumpBufferTimer -= deltaTime
            jump.jumpBufferTimer = max(jump.jumpBufferTimer, 0)
        }

        // Update coyote timer (only when falling)
        if jump.state == .falling {
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
