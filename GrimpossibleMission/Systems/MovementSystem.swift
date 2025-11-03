//
//  MovementSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles arcade-style player movement.
//

import Foundation
import RealityKit

/// System that processes input and updates entity velocity and facing direction.
///
/// RESPONSIBILITY:
/// - Converts player input to horizontal velocity (when grounded only)
/// - Updates facing direction based on input
/// - No air control - trajectory locked once airborne
class MovementSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        for entity in entities {
            guard let inputState = entity.components[InputStateComponent.self],
                  var velocity = entity.components[VelocityComponent.self],
                  var facing = entity.components[FacingDirectionComponent.self],
                  let jumpComponent = entity.components[JumpComponent.self],
                  entity.components[PlayerComponent.self] != nil else {
                continue
            }

            // Only allow horizontal control when grounded
            // Once airborne, trajectory is locked until landing
            if jumpComponent.state != .grounded {
                continue  // No air control
            }

            // Get horizontal input
            let horizontalInput = inputState.horizontalAxis

            // Player has full horizontal control when grounded
            let moveSpeed = GameConfig.playerMoveSpeed

            // Update velocity based on input (arcade-style: immediate response)
            if horizontalInput < 0 {
                velocity.dx = -moveSpeed
                facing.direction = .left
            } else if horizontalInput > 0 {
                velocity.dx = moveSpeed
                facing.direction = .right
            } else {
                velocity.dx = 0
            }

            // Update components
            entity.components.set(velocity)
            entity.components.set(facing)
        }
    }
}

/// System that applies physics: gravity, velocity to position, and collision detection.
///
/// RESPONSIBILITY:
/// - Applies constant gravity acceleration when airborne
/// - Detects and resolves all collisions via AABB
/// - Updates jump states based on COLLISION RESULTS (collision is source of truth)
/// - Applies velocity to position
///
/// COLLISION-BASED STATE TRANSITIONS:
/// - hitFloor detected → grounded
/// - No hitFloor when grounded → airborne (walked off edge)
class PhysicsSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Collect solid entities for collision detection (search recursively)
        let solidEntities = collectSolidEntities(from: entities)

        for entity in entities {
            guard var velocity = entity.components[VelocityComponent.self],
                  var position = entity.components[PositionComponent.self] else {
                continue
            }

            var jumpComponent = entity.components[JumpComponent.self]

            // STEP 1: Check wall proximity (for pre-collision horizontal cancellation)
            var isTouchingLeftWall = false
            var isTouchingRightWall = false

            if entity.components[PlayerComponent.self] != nil {
                let wallCheck = checkWalls(position: position, solids: solidEntities)
                isTouchingLeftWall = wallCheck.left
                isTouchingRightWall = wallCheck.right
            }

            // STEP 2: Apply gravity acceleration (constant downward pull when airborne)
            if entity.components[GravityComponent.self] != nil,
               let jump = jumpComponent {

                if jump.state == .grounded {
                    velocity.dy = 0  // No vertical velocity when grounded
                } else {
                    // Apply gravity acceleration (downward pull)
                    velocity.dy -= GameConfig.gravity * Float(deltaTime)

                    // Clamp to terminal velocity
                    velocity.dy = max(velocity.dy, -GameConfig.maxFallSpeed)
                }
            }

            // STEP 3: Cancel horizontal movement if touching wall
            if isTouchingLeftWall && velocity.dx < 0 {
                velocity.dx = 0
            }
            if isTouchingRightWall && velocity.dx > 0 {
                velocity.dx = 0
            }

            // STEP 4: Calculate new position from velocity
            let newX = position.x + velocity.dx * Float(deltaTime)
            let newY = position.y + velocity.dy * Float(deltaTime)

            // STEP 5: Apply collision detection and response
            if entity.components[PlayerComponent.self] != nil {
                let result = resolveCollisions(
                    entity: entity,
                    currentPosition: position,
                    newPosition: SIMD3<Float>(newX, newY, position.z),
                    velocity: velocity,
                    solids: solidEntities
                )

                position = result.position
                velocity = result.velocity

                // STEP 6: Update jump state based on collision results (collision is source of truth)
                if var jump = jumpComponent {
                    // Hit floor/platform from above → grounded
                    if result.hitFloor {
                        if jump.state == .airborne {
                            if GameConfig.debugLogging {
                                print("[Physics] Landed on floor - airborne -> grounded")
                            }
                            jump.state = .grounded
                        }
                    }
                    // No floor collision but was grounded → walked off edge
                    else if !result.hitFloor && jump.state == .grounded {
                        if GameConfig.debugLogging {
                            print("[Physics] No floor contact - grounded -> airborne")
                        }
                        jump.state = .airborne
                    }

                    jumpComponent = jump
                }
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
    ) -> (position: PositionComponent, velocity: VelocityComponent, hitCeiling: Bool, hitWall: Bool, hitFloor: Bool) {

        var finalPosition = newPosition
        var finalVelocity = velocity
        var hitCeiling = false
        var hitWall = false
        var hitFloor = false

        // Get player bounds - use hitbox if available, otherwise use full entity bounds
        let playerHalfWidth: Float
        let playerHalfHeight: Float
        let playerCenterOffsetY: Float

        if let hitbox = entity.components[HitboxComponent.self] {
            // Use hitbox bounds
            playerHalfWidth = hitbox.width / 2.0
            playerHalfHeight = hitbox.height / 2.0
            playerCenterOffsetY = hitbox.offsetY
        } else {
            // Use full entity bounds
            playerHalfWidth = GameConfig.playerWidth / 2.0
            playerHalfHeight = GameConfig.playerHeight / 2.0
            playerCenterOffsetY = 0
        }

        // Check collision with each solid
        for solid in solids {
            guard let solidComponent = solid.components[SolidComponent.self],
                  solidComponent.isActive else {
                continue
            }

            let solidPos = solid.position
            let solidBounds = solidComponent.bounds

            // Calculate AABB bounds (account for hitbox offset)
            let hitboxCenterY = finalPosition.y + playerCenterOffsetY
            let playerLeft = finalPosition.x - playerHalfWidth
            let playerRight = finalPosition.x + playerHalfWidth
            let playerBottom = hitboxCenterY - playerHalfHeight
            let playerTop = hitboxCenterY + playerHalfHeight

            let solidLeft = solidPos.x - solidBounds.x / 2.0
            let solidRight = solidPos.x + solidBounds.x / 2.0
            let solidBottom = solidPos.y - solidBounds.y / 2.0
            let solidTop = solidPos.y + solidBounds.y / 2.0

            // For floor/platform detection, expand vertical bounds to catch resting state
            // When player is resting on floor, they're positioned ABOVE solidTop by collisionTolerance
            // So we need to detect "near the floor from above" as well as actual overlap
            let floorDetectionTolerance: Float = GameConfig.collisionTolerance * 2.0
            let isHorizontallyAligned = playerRight > solidLeft && playerLeft < solidRight

            // Handle each solid type with appropriate collision checks
            switch solidComponent.type {
            case .floor, .platform:
                // Check if player is above the floor/platform (expanded check for resting state)
                let isNearOrOnFloor = playerTop > solidBottom && playerBottom < solidTop + floorDetectionTolerance

                if isHorizontallyAligned && isNearOrOnFloor {
                    // Check if player is approaching from above (or resting from above)
                    let currentHitboxCenterY = currentPosition.y + playerCenterOffsetY
                    let playerBottomEdge = currentHitboxCenterY - playerHalfHeight
                    let isFromAbove = playerBottomEdge >= solidTop - GameConfig.collisionTolerance

                    // Hit floor/platform from above OR resting on it
                    if velocity.dy <= 0 && isFromAbove {
                        // Position entity so hitbox bottom is at solidTop
                        finalPosition.y = solidTop + playerHalfHeight + GameConfig.collisionTolerance - playerCenterOffsetY
                        finalVelocity.dy = 0
                        hitFloor = true  // Mark that we hit floor (this means grounded)
                    }
                }

            case .ceiling:
                // Standard AABB overlap check for ceiling
                if isHorizontallyAligned && playerTop > solidBottom && playerBottom < solidTop {
                    // Hit ceiling from below
                    if velocity.dy > 0 {  // Moving up
                        // Position entity so hitbox top is at solidBottom
                        finalPosition.y = solidBottom - playerHalfHeight - GameConfig.collisionTolerance - playerCenterOffsetY
                        finalVelocity.dy = 0
                        hitCeiling = true
                    }
                }

            case .wall:
                // Standard AABB overlap check for walls
                if playerRight > solidLeft && playerLeft < solidRight &&
                   playerTop > solidBottom && playerBottom < solidTop {
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
                        hitWall = true
                    }
                }

            case .block:
                // Blocks all directions - check for collision from any side
                // For floor detection, use expanded bounds like floor/platform
                let isNearOrOnBlock = playerTop > solidBottom && playerBottom < solidTop + floorDetectionTolerance

                if isHorizontallyAligned && isNearOrOnBlock {
                    // Check if approaching from above (landing on top)
                    let currentHitboxCenterY = currentPosition.y + playerCenterOffsetY
                    let playerBottomEdge = currentHitboxCenterY - playerHalfHeight
                    let isFromAbove = playerBottomEdge >= solidTop - GameConfig.collisionTolerance

                    if velocity.dy <= 0 && isFromAbove {
                        // Position entity so hitbox bottom is at solidTop
                        finalPosition.y = solidTop + playerHalfHeight + GameConfig.collisionTolerance - playerCenterOffsetY
                        finalVelocity.dy = 0
                        hitFloor = true
                    }
                }

                // Standard AABB for other directions
                if playerRight > solidLeft && playerLeft < solidRight &&
                   playerTop > solidBottom && playerBottom < solidTop {

                    // Hit from below (ceiling collision)
                    if velocity.dy > 0 && currentPosition.y < solidPos.y {
                        // Position entity so hitbox top is at solidBottom
                        finalPosition.y = solidBottom - playerHalfHeight - GameConfig.collisionTolerance - playerCenterOffsetY
                        finalVelocity.dy = 0
                        hitCeiling = true
                    }

                    // Hit from side (wall collision)
                    if velocity.dx != 0 {
                        let playerCenterX = currentPosition.x
                        if playerCenterX < solidPos.x {
                            // Hit from left
                            finalPosition.x = solidLeft - playerHalfWidth - GameConfig.collisionTolerance
                        } else {
                            // Hit from right
                            finalPosition.x = solidRight + playerHalfWidth + GameConfig.collisionTolerance
                        }
                        finalVelocity.dx = 0
                        hitWall = true
                    }
                }
            }
        }

        return (
            position: PositionComponent(x: finalPosition.x, y: finalPosition.y, z: finalPosition.z),
            velocity: finalVelocity,
            hitCeiling: hitCeiling,
            hitWall: hitWall,
            hitFloor: hitFloor
        )
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
