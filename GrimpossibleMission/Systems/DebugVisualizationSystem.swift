//
//  DebugVisualizationSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles debug visualization (jump arcs, collision boxes, etc.)
//  Can be toggled on/off via GameConfig.
//

import Foundation
import RealityKit
import UIKit

/// System that manages debug visualizations
class DebugVisualizationSystem: GameSystem {

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Check if debug visualization is enabled
        if !GameConfig.debugVisualization {
            // Clean up any existing debug visuals
            for entity in entities {
                removeJumpArc(from: entity)
                removeHitboxVisualization(from: entity)
            }
            return
        }

        // Update hitbox visualizations for all entities with hitboxes
        for entity in entities {
            if let hitbox = entity.components[HitboxComponent.self],
               let position = entity.components[PositionComponent.self] {
                updateHitboxVisualization(on: entity, hitbox: hitbox, position: position)
            } else {
                removeHitboxVisualization(from: entity)
            }
        }
    }

    /// Updates or creates the jump arc visualization for a grounded player
    private func updateJumpArcVisualization(
        on entity: Entity,
        position: PositionComponent,
        facing: FacingDirectionComponent,
        arcWidth: Float,
        arcHeight: Float
    ) {
        // Calculate where player would land if they jumped right now
        let horizontalDistance = facing.direction == .right ? arcWidth : -arcWidth

        // Arc should start from player's bottom/center (feet position)
        let playerBottomY = position.y - (GameConfig.playerHeight / 2.0)
        let arcStartPos = SIMD3<Float>(position.x, playerBottomY, position.z)
        let targetPos = SIMD3<Float>(
            position.x + horizontalDistance,
            playerBottomY - GameConfig.roomHeight,  // Land 1 room height below
            position.z
        )

        createJumpArc(
            on: entity,
            startPos: arcStartPos,
            targetPos: targetPos,
            arcHeight: arcHeight
        )
    }

    /// Creates a visual representation of the jump arc in world space
    private func createJumpArc(on entity: Entity, startPos: SIMD3<Float>, targetPos: SIMD3<Float>, arcHeight: Float) {
        // Remove any existing debug arc
        removeJumpArc(from: entity)

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

            // Calculate position along arc using extended parabola that ends below start
            // Arc goes from startY at t=0, peaks at startY + arcHeight at t=0.5, ends at targetY at t=1.0
            // Formula: h(t) = (-4*arcHeight - 2*roomHeight)t² + (4*arcHeight + roomHeight)t
            let worldX = startPos.x + (targetPos.x - startPos.x) * t
            let roomHeight = GameConfig.roomHeight
            let heightOffset = (-4.0 * arcHeight - 2.0 * roomHeight) * t * t + (4.0 * arcHeight + roomHeight) * t
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
    private func removeJumpArc(from entity: Entity) {
        // Look for arc in scene root (parent of player)
        guard let sceneRoot = entity.parent else {
            return
        }

        if let arcContainer = sceneRoot.children.first(where: { $0.name == "DebugJumpArc" }) {
            arcContainer.removeFromParent()
        }
    }

    /// Updates or creates the hitbox visualization for an entity
    private func updateHitboxVisualization(on entity: Entity, hitbox: HitboxComponent, position: PositionComponent) {
        // Check if debug visual already exists
        let debugName = "DebugHitbox"
        var debugBox = entity.children.first(where: { $0.name == debugName })

        if debugBox == nil {
            // Create new debug box
            debugBox = Entity()
            debugBox?.name = debugName

            // Create a wireframe-style box
            let boxSize = SIMD3<Float>(hitbox.width, hitbox.height, hitbox.width)
            let mesh = MeshResource.generateBox(size: boxSize)

            // Semi-transparent green material
            var material = SimpleMaterial(color: .green, isMetallic: false)
            material.color = SimpleMaterial.BaseColor(tint: UIColor.green.withAlphaComponent(0.3))

            debugBox?.components.set(ModelComponent(mesh: mesh, materials: [material]))

            entity.addChild(debugBox!)
        }

        // Update position (hitbox may have offset)
        debugBox?.position = SIMD3<Float>(hitbox.offsetX, hitbox.offsetY, 0)
    }

    /// Removes the hitbox visualization from an entity
    private func removeHitboxVisualization(from entity: Entity) {
        if let debugBox = entity.children.first(where: { $0.name == "DebugHitbox" }) {
            debugBox.removeFromParent()
        }
    }
}
