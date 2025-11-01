//
//  SearchableItemEntity.swift
//  GrimpossibleMission
//
//  Factory function for creating searchable item entities.
//

import Foundation
import RealityKit
import UIKit

/// Creates a searchable item entity.
/// - Parameters:
///   - x: X position in world units
///   - y: Y position in world units
///   - state: Initial search state (default: searchable)
/// - Returns: Configured searchable item entity
func createSearchableItemEntity(x: Float, y: Float, state: SearchState = .searchable) -> Entity {
    let item = Entity()

    // Item is a 1x1 cube
    let itemSize = SIMD3<Float>(1.0, 1.0, 1.0)

    // Create visual model - color based on state
    let mesh = MeshResource.generateBox(size: itemSize)
    let color: UIColor = state == .searchable ? .red : .darkGray
    let material = SimpleMaterial(color: color, isMetallic: false)
    let modelComponent = ModelComponent(mesh: mesh, materials: [material])

    // Position component (centered on the tile)
    let positionComponent = PositionComponent(
        x: x + 0.5, // Center of tile
        y: y + 0.5, // Center of tile
        z: 0
    )

    // Searchable item component
    let searchableComponent = SearchableItemComponent(
        state: state,
        searchDuration: GameConfig.searchDuration,
        interactionDistance: GameConfig.interactionDistance
    )

    // Search progress component (starts at 0)
    let searchProgressComponent = SearchProgressComponent()

    // Collision component
    let collisionShape = ShapeResource.generateBox(size: itemSize)
    let collisionComponent = CollisionComponent(shapes: [collisionShape])

    // Set all components
    item.components.set(modelComponent)
    item.components.set(positionComponent)
    item.components.set(searchableComponent)
    item.components.set(searchProgressComponent)
    item.components.set(collisionComponent)

    // Set initial transform
    item.position = positionComponent.simd

    // Name for debugging
    item.name = "SearchableItem_\(x)_\(y)"

    return item
}
