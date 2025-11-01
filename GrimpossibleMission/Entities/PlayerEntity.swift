//
//  PlayerEntity.swift
//  GrimpossibleMission
//
//  Factory function for creating player entities.
//

import Foundation
import RealityKit
import UIKit

/// Creates a player entity with all required components.
/// - Parameters:
///   - startX: Starting X position in world units
///   - startY: Starting Y position in world units (typically floor level)
/// - Returns: Configured player entity
func createPlayerEntity(startX: Float, startY: Float) -> Entity {
    let player = Entity()

    // Player is 1 tile wide, 2 tiles tall
    let playerSize = SIMD3<Float>(
        GameConfig.playerWidth,
        GameConfig.playerHeight,
        GameConfig.playerWidth // Depth same as width for cube appearance
    )

    // Create visual model (blue cube to distinguish from environment)
    let mesh = MeshResource.generateBox(size: playerSize)
    let material = SimpleMaterial(color: .blue, isMetallic: false)
    let modelComponent = ModelComponent(mesh: mesh, materials: [material])

    // Position component (game logic)
    // Player pivot is at bottom center, so offset Y by half height
    let positionComponent = PositionComponent(
        x: startX,
        y: startY + GameConfig.playerHeight / 2.0,
        z: 0
    )

    // Velocity component
    let velocityComponent = VelocityComponent(dx: 0, dy: 0)

    // Input state component
    let inputStateComponent = InputStateComponent()

    // Facing direction component (start facing right)
    let facingComponent = FacingDirectionComponent(direction: .right)

    // Player tag component
    let playerComponent = PlayerComponent()

    // Collision component (for future collision detection)
    let collisionShape = ShapeResource.generateBox(size: playerSize)
    let collisionComponent = CollisionComponent(shapes: [collisionShape])

    // Set all components
    player.components.set(modelComponent)
    player.components.set(positionComponent)
    player.components.set(velocityComponent)
    player.components.set(inputStateComponent)
    player.components.set(facingComponent)
    player.components.set(playerComponent)
    player.components.set(collisionComponent)

    // Set initial transform
    player.position = positionComponent.simd

    // Name for debugging
    player.name = "Player"

    return player
}
