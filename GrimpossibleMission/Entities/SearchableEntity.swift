//
//  SearchableEntity.swift
//  GrimpossibleMission
//
//  Factory for creating searchable item entities.
//

import Foundation
import RealityKit
import UIKit

/// Creates a searchable item entity.
/// - Parameters:
///   - x: X position in world units
///   - y: Y position in world units
///   - searchDuration: Time in seconds to complete search
/// - Returns: Searchable item entity with visual representation
func createSearchableItem(x: Float, y: Float, searchDuration: Float = 2.0) -> Entity {
    let item = Entity()
    item.name = "SearchableItem"

    // Visual representation: small cube
    let itemSize = SIMD3<Float>(0.5, 0.5, 0.5)
    let mesh = MeshResource.generateBox(size: itemSize)

    // Start as red (searchable state)
    let material = SimpleMaterial(color: .red, isMetallic: false)
    let modelComponent = ModelComponent(mesh: mesh, materials: [material])

    // Position
    let positionComponent = PositionComponent(x: x, y: y, z: 0)

    // Searchable component
    var searchableComponent = SearchableComponent()
    searchableComponent.searchDuration = searchDuration

    // Collision for proximity detection
    let collisionShape = ShapeResource.generateBox(size: itemSize)
    let collisionComponent = CollisionComponent(shapes: [collisionShape])

    // Debug label component
    let debugLabel = DebugLabelComponent(text: "SEARCHABLE\n0%", offsetY: 1.0)

    // Set all components
    item.components.set(modelComponent)
    item.components.set(positionComponent)
    item.components.set(searchableComponent)
    item.components.set(collisionComponent)
    item.components.set(debugLabel)

    // Set transform
    item.position = positionComponent.simd

    return item
}

/// Update the visual appearance of a searchable item based on its state
func updateSearchableItemVisual(_ entity: Entity, state: SearchableState) {
    guard var modelComponent = entity.components[ModelComponent.self] else { return }

    let color: UIColor
    switch state {
    case .searchable:
        color = .red
    case .searching:
        color = .orange
    case .searched:
        color = .darkGray
    }

    let material = SimpleMaterial(color: color, isMetallic: false)
    modelComponent.materials = [material]
    entity.components.set(modelComponent)
}
