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
        // Only process if debug visualization is enabled
        guard GameConfig.debugJumpArc else {
            // Remove any existing visualizations if debug was turned off
            for entity in entities {
                removeJumpArc(from: entity)
            }
            return
        }

        for entity in entities {
            guard let jumpComponent = entity.components[JumpComponent.self],
                  let position = entity.components[PositionComponent.self],
                  let facing = entity.components[FacingDirectionComponent.self] else {
                continue
            }

            // Only show arc when grounded (shows where player would jump)
            if jumpComponent.state == .grounded {
                updateJumpArcVisualization(
                    on: entity,
                    position: position,
                    facing: facing,
                    arcWidth: jumpComponent.arcWidth,
                    arcHeight: jumpComponent.arcHeight
                )
            } else {
                // Don't update arc while jumping/falling - it stays frozen in world space
                // Arc will be removed when player lands (transitions back to grounded)
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
            playerBottomY,  // Land at same height
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

            // Calculate position along arc using parabolic formula: h = 4 * arcHeight * t * (1 - t)
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
    private func removeJumpArc(from entity: Entity) {
        // Look for arc in scene root (parent of player)
        guard let sceneRoot = entity.parent else {
            return
        }

        if let arcContainer = sceneRoot.children.first(where: { $0.name == "DebugJumpArc" }) {
            arcContainer.removeFromParent()
        }
    }
}
