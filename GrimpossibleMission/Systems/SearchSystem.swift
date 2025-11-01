//
//  SearchSystem.swift
//  GrimpossibleMission
//
//  ECS System that handles searching of items by the player.
//

import Foundation
import RealityKit

/// System that manages searching items
class SearchSystem: GameSystem {

    private let proximityDistance: Float = 2.0  // Distance to activate search

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Find player
        guard let player = entities.first(where: { $0.components[PlayerComponent.self] != nil }),
              let playerPos = player.components[PositionComponent.self],
              let playerInput = player.components[InputStateComponent.self] else {
            return
        }

        // Process all searchable items
        for entity in entities {
            guard var searchable = entity.components[SearchableComponent.self],
                  let itemPos = entity.components[PositionComponent.self] else {
                continue
            }

            // Skip if already searched
            if searchable.isSearched {
                continue
            }

            // Calculate distance to player
            let dx = itemPos.x - playerPos.x
            let dy = itemPos.y - playerPos.y
            let distance = sqrt(dx * dx + dy * dy)

            // Check if player is in proximity and holding Up
            if distance <= proximityDistance && playerInput.moveUp {
                // Start or continue searching
                if searchable.state == .searchable {
                    searchable.state = .searching
                    updateSearchableItemVisual(entity, state: .searching)

                    if GameConfig.debugLogging {
                        print("[Search] Started searching item at (\(itemPos.x), \(itemPos.y))")
                    }
                }

                // Increase search progress
                if searchable.state == .searching {
                    searchable.searchProgress += Float(deltaTime) / searchable.searchDuration
                    searchable.searchProgress = min(searchable.searchProgress, 1.0)

                    // Complete search when progress reaches 100%
                    if searchable.searchProgress >= 1.0 {
                        searchable.state = .searched
                        updateSearchableItemVisual(entity, state: .searched)

                        if GameConfig.debugLogging {
                            print("[Search] Completed searching item at (\(itemPos.x), \(itemPos.y))")
                        }
                    }
                }

                // Update component
                entity.components.set(searchable)

                // Update debug label
                updateDebugLabel(entity, searchable: searchable, distance: distance)

            } else {
                // Player moved away or released Up - reset to searchable if was searching
                if searchable.state == .searching {
                    searchable.state = .searchable
                    searchable.searchProgress = 0.0
                    updateSearchableItemVisual(entity, state: .searchable)
                    entity.components.set(searchable)

                    if GameConfig.debugLogging {
                        print("[Search] Search interrupted")
                    }
                }

                // Update debug label
                updateDebugLabel(entity, searchable: searchable, distance: distance)
            }
        }
    }

    private func updateDebugLabel(_ entity: Entity, searchable: SearchableComponent, distance: Float) {
        guard var debugLabel = entity.components[DebugLabelComponent.self] else {
            return
        }

        let statusText: String
        switch searchable.state {
        case .searchable:
            statusText = "SEARCHABLE"
        case .searching:
            statusText = "SEARCHING"
        case .searched:
            statusText = "SEARCHED"
        }

        let progressPercent = Int(searchable.searchProgress * 100)
        let distanceText = String(format: "%.1f units", distance)

        debugLabel.text = "\(statusText)\n\(progressPercent)%\nDist: \(distanceText)"
        entity.components.set(debugLabel)
    }
}
