//
//  JumpSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles committed jump arcs.
//

import Foundation
import RealityKit
import UIKit

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

            // Update timers
            updateTimers(&jumpComponent, deltaTime: Float(deltaTime), inputState: inputState)

            // Update debug arc visualization when grounded (shows where player would jump)
            if jumpComponent.state == .grounded && GameConfig.debugVisualization {
                // Calculate where player would land if they jumped right now
                let horizontalDistance = facing.direction == .right ? jumpComponent.arcWidth : -jumpComponent.arcWidth

                // Arc should start from player's bottom/center (feet position)
                let playerBottomY = position.y - (GameConfig.playerHeight / 2.0)
                let arcStartPos = SIMD3<Float>(position.x, playerBottomY, position.z)
                let targetPos = SIMD3<Float>(
                    position.x + horizontalDistance,
                    playerBottomY,  // Land at same height
                    position.z
                )

                createDebugArc(
                    on: entity,
                    startPos: arcStartPos,
                    targetPos: targetPos,
                    arcHeight: jumpComponent.arcHeight
                )
            }

            // Handle jump input
            if inputState.jump && !jumpComponent.jumpInputPressed {
                // Jump button pressed this frame
                jumpComponent.jumpInputPressed = true

                // Try to start jump if grounded or within coyote time
                if jumpComponent.canJump {
                    startJump(&jumpComponent, entity: entity, position: position, facing: facing)
                } else {
                    // Buffer the jump input
                    jumpComponent.jumpBufferTimer = GameConfig.jumpBufferTime
                }
            } else if !inputState.jump {
                // Jump button released
                jumpComponent.jumpInputPressed = false
            }

            // Check jump buffer when landing
            if jumpComponent.state == .grounded && jumpComponent.jumpBufferTimer > 0 {
                startJump(&jumpComponent, entity: entity, position: position, facing: facing)
            }

            // Update jump arc if currently jumping
            if jumpComponent.state == .jumping {
                updateJumpArc(&jumpComponent, velocity: &velocity, deltaTime: Float(deltaTime))
            }

            // Update component
            entity.components.set(jumpComponent)
            entity.components.set(velocity)
        }
    }

    /// Updates jump timers (buffer and coyote time)
    private func updateTimers(_ jump: inout JumpComponent, deltaTime: Float, inputState: InputStateComponent) {
        // Update jump buffer timer
        if jump.jumpBufferTimer > 0 {
            jump.jumpBufferTimer -= deltaTime
            if jump.jumpBufferTimer < 0 {
                jump.jumpBufferTimer = 0
            }
        }

        // Update coyote timer (only when falling)
        if jump.state == .falling {
            if jump.coyoteTimer > 0 {
                jump.coyoteTimer -= deltaTime
                if jump.coyoteTimer < 0 {
                    jump.coyoteTimer = 0
                }
            }
        } else if jump.state == .grounded {
            // Reset coyote timer when grounded
            jump.coyoteTimer = GameConfig.coyoteTime
        }
    }

    /// Starts a jump with committed arc
    private func startJump(_ jump: inout JumpComponent, entity: Entity, position: PositionComponent, facing: FacingDirectionComponent) {
        jump.state = .jumping
        jump.arcProgress = 0.0

        // Arc should start from player's bottom/center (feet position)
        let playerBottomY = position.y - (GameConfig.playerHeight / 2.0)
        jump.jumpStartPosition = SIMD3<Float>(position.x, playerBottomY, position.z)
        jump.jumpBufferTimer = 0.0

        // Calculate target landing position based on facing direction
        let horizontalDistance = facing.direction == .right ? jump.arcWidth : -jump.arcWidth
        jump.jumpTargetPosition = SIMD3<Float>(
            position.x + horizontalDistance,
            playerBottomY,  // Land at same height (feet level)
            position.z
        )

        if GameConfig.debugLogging {
            print("[Jump] Started jump from (\(position.x), \(playerBottomY)) to (\(jump.jumpTargetPosition.x), \(jump.jumpTargetPosition.y))")
            print("[Jump] Arc dimensions - Width: \(jump.arcWidth), Height: \(jump.arcHeight)")
        }
    }

    /// Updates velocity based on jump arc progress
    private func updateJumpArc(_ jump: inout JumpComponent, velocity: inout VelocityComponent, deltaTime: Float) {
        // Calculate how much progress to make this frame
        let totalDistance = jump.arcWidth
        let totalDuration = totalDistance / (GameConfig.jumpAscentSpeed * 0.5 + GameConfig.jumpDescentSpeed * 0.5)

        // Update arc progress
        jump.arcProgress += deltaTime / totalDuration
        jump.arcProgress = min(jump.arcProgress, 1.0)

        // Calculate position along arc
        let t = jump.arcProgress
        let startPos = jump.jumpStartPosition
        let targetPos = jump.jumpTargetPosition

        // Calculate velocity from arc trajectory
        // Horizontal velocity is constant (direction of jump)
        let direction: Float = (targetPos.x - startPos.x) > 0 ? 1.0 : -1.0
        velocity.dx = direction * totalDistance / totalDuration

        // Vertical velocity from derivative of parabola: dy/dt = 4 * h * (1 - 2t) / duration
        let arcHeight = jump.arcHeight
        velocity.dy = 4.0 * arcHeight * (1.0 - 2.0 * t) / totalDuration

        // Check if jump is complete
        if jump.arcProgress >= 1.0 {
            jump.state = .falling
            velocity.dx = 0  // Stop horizontal movement when arc completes

            if GameConfig.debugLogging {
                print("[Jump] Jump arc completed")
            }
        }
    }

    /// Creates a visual representation of the jump arc in world space
    private func createDebugArc(on entity: Entity, startPos: SIMD3<Float>, targetPos: SIMD3<Float>, arcHeight: Float) {
        // Remove any existing debug arc
        removeDebugArc(from: entity)

        // Find the scene root (player's parent, which is the scene/world)
        guard let sceneRoot = entity.parent else {
            return
        }

        // Create container for arc visualization
        let arcContainer = Entity()
        arcContainer.name = "DebugJumpArc"

        // Number of points along the arc
        let numPoints = 20

        // Create small spheres along the arc path in world space
        for i in 0..<numPoints {
            let t = Float(i) / Float(numPoints - 1)

            // Calculate position along arc in world space using same formula as jump
            let worldX = startPos.x + (targetPos.x - startPos.x) * t
            let heightOffset = 4.0 * arcHeight * t * (1.0 - t)
            let worldY = startPos.y + heightOffset
            let worldZ = startPos.z

            // Create small sphere at this point (world coordinates)
            let point = Entity()
            let mesh = MeshResource.generateSphere(radius: 0.1)
            let material = SimpleMaterial(color: .yellow, isMetallic: false)
            point.components.set(ModelComponent(mesh: mesh, materials: [material]))
            point.position = SIMD3<Float>(worldX, worldY, worldZ)

            arcContainer.addChild(point)
        }

        // Add arc to scene root (not as child of player) so it stays in world space
        sceneRoot.addChild(arcContainer)
    }

    /// Removes the debug arc visualization
    private func removeDebugArc(from entity: Entity) {
        // Look for arc in scene root (parent of player)
        guard let sceneRoot = entity.parent else {
            return
        }

        if let arcContainer = sceneRoot.children.first(where: { $0.name == "DebugJumpArc" }) {
            arcContainer.removeFromParent()
        }
    }
}
