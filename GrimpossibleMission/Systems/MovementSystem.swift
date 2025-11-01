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

/// System that applies physics: gravity, velocity to position, and collision detection.
class PhysicsSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Collect solid entities for collision detection (search recursively through children)
        let solidEntities = collectSolidEntities(from: entities)

        for entity in entities {
            guard var velocity = entity.components[VelocityComponent.self],
                  var position = entity.components[PositionComponent.self] else {
                continue
            }

            // Get jump component if entity has one (for gravity and collision)
            var jumpComponent = entity.components[JumpComponent.self]

            // Check if standing on ground or touching walls BEFORE applying movement
            var isCurrentlyGrounded = false
            var isTouchingLeftWall = false
            var isTouchingRightWall = false

            if let playerComponent = entity.components[PlayerComponent.self] {
                isCurrentlyGrounded = checkGrounded(
                    position: position,
                    solids: solidEntities
                )

                let wallCheck = checkWalls(
                    position: position,
                    solids: solidEntities
                )
                isTouchingLeftWall = wallCheck.left
                isTouchingRightWall = wallCheck.right
            }

            // Apply gravity if entity has GravityComponent
            if let gravity = entity.components[GravityComponent.self],
               let jump = jumpComponent,
               gravity.isActive {

                // Only apply gravity when not grounded and not jumping
                if !isCurrentlyGrounded && jump.state != .jumping {
                    velocity.dy = -gravity.fallSpeed
                } else {
                    // No vertical velocity when grounded
                    velocity.dy = 0
                }

                // Update jump state based on grounded check
                if var jump = jumpComponent {
                    if isCurrentlyGrounded && jump.state != .jumping {
                        jump.state = .grounded
                    } else if !isCurrentlyGrounded && jump.state == .grounded {
                        jump.state = .falling
                    }
                    jumpComponent = jump
                }
            }

            // Cancel horizontal movement if touching wall in that direction
            if isTouchingLeftWall && velocity.dx < 0 {
                velocity.dx = 0
            }
            if isTouchingRightWall && velocity.dx > 0 {
                velocity.dx = 0
            }

            // Calculate new position
            let newX = position.x + velocity.dx * Float(deltaTime)
            let newY = position.y + velocity.dy * Float(deltaTime)

            // Apply collision detection and response if entity has collision
            if let playerComponent = entity.components[PlayerComponent.self] {
                let result = resolveCollisions(
                    entity: entity,
                    currentPosition: position,
                    newPosition: SIMD3<Float>(newX, newY, position.z),
                    velocity: velocity,
                    solids: solidEntities
                )

                position = result.position
                velocity = result.velocity
            } else {
                // No collision, just apply velocity
                position.x = newX
                position.y = newY
            }

            // Update components
            entity.components.set(velocity)
            entity.components.set(position)
            if let jump = jumpComponent {
                entity.components.set(jump)
            }

            // Also update RealityKit's transform for rendering
            entity.position = position.simd
        }
    }

    /// Resolves collisions between an entity and solid objects
    private func resolveCollisions(
        entity: Entity,
        currentPosition: PositionComponent,
        newPosition: SIMD3<Float>,
        velocity: VelocityComponent,
        solids: [Entity]
    ) -> (position: PositionComponent, velocity: VelocityComponent) {

        var finalPosition = newPosition
        var finalVelocity = velocity

        // Get player bounds (assuming 1x2x1 for now)
        let playerHalfWidth: Float = GameConfig.playerWidth / 2.0
        let playerHalfHeight: Float = GameConfig.playerHeight / 2.0

        // Check collision with each solid
        for solid in solids {
            guard let solidComponent = solid.components[SolidComponent.self],
                  solidComponent.isActive else {
                continue
            }

            let solidPos = solid.position
            let solidBounds = solidComponent.bounds

            // Calculate AABB bounds
            let playerLeft = finalPosition.x - playerHalfWidth
            let playerRight = finalPosition.x + playerHalfWidth
            let playerBottom = finalPosition.y - playerHalfHeight
            let playerTop = finalPosition.y + playerHalfHeight

            let solidLeft = solidPos.x - solidBounds.x / 2.0
            let solidRight = solidPos.x + solidBounds.x / 2.0
            let solidBottom = solidPos.y - solidBounds.y / 2.0
            let solidTop = solidPos.y + solidBounds.y / 2.0

            // Check for AABB overlap
            if playerRight > solidLeft && playerLeft < solidRight &&
               playerTop > solidBottom && playerBottom < solidTop {

                // Collision detected - resolve based on solid type
                switch solidComponent.type {
                case .floor, .platform:
                    // Hit floor from above
                    if velocity.dy < 0 {  // Moving down
                        finalPosition.y = solidTop + playerHalfHeight + GameConfig.collisionTolerance
                        finalVelocity.dy = 0
                    }

                case .ceiling:
                    // Hit ceiling from below
                    if velocity.dy > 0 {  // Moving up
                        finalPosition.y = solidBottom - playerHalfHeight - GameConfig.collisionTolerance
                        finalVelocity.dy = 0
                    }

                case .wall:
                    // Hit wall from side
                    if velocity.dx != 0 {
                        // Determine which side we hit
                        let playerCenterX = currentPosition.x
                        if playerCenterX < solidPos.x {
                            // Hit from left
                            finalPosition.x = solidLeft - playerHalfWidth - GameConfig.collisionTolerance
                        } else {
                            // Hit from right
                            finalPosition.x = solidRight + playerHalfWidth + GameConfig.collisionTolerance
                        }
                        finalVelocity.dx = 0
                    }
                }
            }
        }

        return (
            position: PositionComponent(x: finalPosition.x, y: finalPosition.y, z: finalPosition.z),
            velocity: finalVelocity
        )
    }

    /// Checks if player is currently standing on ground
    private func checkGrounded(position: PositionComponent, solids: [Entity]) -> Bool {
        let playerHalfWidth: Float = GameConfig.playerWidth / 2.0
        let playerHalfHeight: Float = GameConfig.playerHeight / 2.0

        // Check slightly below the player's feet
        let checkDistance: Float = 0.1
        let feetY = position.y - playerHalfHeight

        // Check for floor beneath player
        for solid in solids {
            guard let solidComponent = solid.components[SolidComponent.self],
                  solidComponent.isActive,
                  solidComponent.type == .floor || solidComponent.type == .platform else {
                continue
            }

            let solidPos = solid.position
            let solidBounds = solidComponent.bounds

            let solidLeft = solidPos.x - solidBounds.x / 2.0
            let solidRight = solidPos.x + solidBounds.x / 2.0
            let solidTop = solidPos.y + solidBounds.y / 2.0

            // Check if player is horizontally aligned with floor
            let playerLeft = position.x - playerHalfWidth
            let playerRight = position.x + playerHalfWidth

            if playerRight > solidLeft && playerLeft < solidRight {
                // Check if player's feet are just above the floor
                let distanceToFloor = feetY - solidTop
                if distanceToFloor >= 0 && distanceToFloor <= checkDistance {
                    return true
                }
            }
        }

        return false
    }

    /// Checks if player is currently touching walls
    private func checkWalls(position: PositionComponent, solids: [Entity]) -> (left: Bool, right: Bool) {
        let playerHalfWidth: Float = GameConfig.playerWidth / 2.0
        let playerHalfHeight: Float = GameConfig.playerHeight / 2.0

        // Check slightly to the sides of the player
        let checkDistance: Float = 0.1
        let playerLeft = position.x - playerHalfWidth
        let playerRight = position.x + playerHalfWidth

        var touchingLeft = false
        var touchingRight = false

        // Check for walls beside player
        for solid in solids {
            guard let solidComponent = solid.components[SolidComponent.self],
                  solidComponent.isActive,
                  solidComponent.type == .wall else {
                continue
            }

            let solidPos = solid.position
            let solidBounds = solidComponent.bounds

            let solidLeft = solidPos.x - solidBounds.x / 2.0
            let solidRight = solidPos.x + solidBounds.x / 2.0
            let solidBottom = solidPos.y - solidBounds.y / 2.0
            let solidTop = solidPos.y + solidBounds.y / 2.0

            // Check if player is vertically aligned with wall
            let playerBottom = position.y - playerHalfHeight
            let playerTop = position.y + playerHalfHeight

            if playerTop > solidBottom && playerBottom < solidTop {
                // Check if player's left side is touching wall's right side
                let distanceToWallRight = playerLeft - solidRight
                if distanceToWallRight >= 0 && distanceToWallRight <= checkDistance {
                    touchingLeft = true
                }

                // Check if player's right side is touching wall's left side
                let distanceToWallLeft = solidLeft - playerRight
                if distanceToWallLeft >= 0 && distanceToWallLeft <= checkDistance {
                    touchingRight = true
                }
            }
        }

        return (left: touchingLeft, right: touchingRight)
    }

    /// Recursively collects all entities with SolidComponent from the entity hierarchy
    private func collectSolidEntities(from entities: [Entity]) -> [Entity] {
        var solids: [Entity] = []

        for entity in entities {
            // Check if this entity has a SolidComponent
            if entity.components[SolidComponent.self] != nil {
                solids.append(entity)
            }

            // Recursively check children
            if !entity.children.isEmpty {
                solids.append(contentsOf: collectSolidEntities(from: Array(entity.children)))
            }
        }

        return solids
    }
}
