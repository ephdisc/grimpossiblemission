//
//  MovementSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles arcade-style player movement.
//

import Foundation
import RealityKit

/// System that processes input and updates entity velocity and facing direction.
/// Implements arcade-style movement with immediate response and no physics.
class MovementSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        for entity in entities {
            // Only process entities that have the required components
            guard let inputState = entity.components[InputStateComponent.self],
                  var velocity = entity.components[VelocityComponent.self],
                  var facing = entity.components[FacingDirectionComponent.self],
                  entity.components[PlayerComponent.self] != nil else {
                continue
            }

            // Get horizontal input
            let horizontalInput = inputState.horizontalAxis

            // Update velocity based on input (arcade-style: immediate response)
            if horizontalInput < 0 {
                // Moving left
                velocity.dx = -GameConfig.playerMoveSpeed
                facing.direction = .left
            } else if horizontalInput > 0 {
                // Moving right
                velocity.dx = GameConfig.playerMoveSpeed
                facing.direction = .right
            } else {
                // Not moving horizontally
                velocity.dx = 0
            }

            // Vertical movement (for elevator - to be implemented)
            // For now, no vertical movement in rooms
            velocity.dy = 0

            // Update components
            entity.components.set(velocity)
            entity.components.set(facing)
        }
    }
}

/// System that applies velocity to position.
/// Separated from MovementSystem for modularity.
class PhysicsSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        for entity in entities {
            guard let velocity = entity.components[VelocityComponent.self],
                  var position = entity.components[PositionComponent.self] else {
                continue
            }

            // Apply velocity to position (discrete arcade-style movement)
            position.x += velocity.dx * Float(deltaTime)
            position.y += velocity.dy * Float(deltaTime)

            // Update position component
            entity.components.set(position)

            // Also update RealityKit's transform for rendering
            entity.position = position.simd
        }
    }
}
