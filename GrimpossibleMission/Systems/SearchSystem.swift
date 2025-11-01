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
                  var progress = entity.components[ProgressComponent.self],
                  let itemPos = entity.components[PositionComponent.self] else {
                continue
            }

            // Skip if already searched and grace period done
            if searchable.isSearched {
                handleCompletedSearch(entity, searchable: &searchable, deltaTime: Float(deltaTime))
                entity.components.set(searchable)
                continue
            }

            // Calculate distance to player
            let dx = itemPos.x - playerPos.x
            let dy = itemPos.y - playerPos.y
            let distance = sqrt(dx * dx + dy * dy)

            // Check if player is in proximity and holding Up
            let isSearching = distance <= proximityDistance && playerInput.moveUp

            if isSearching {
                // Player is actively searching
                handleActiveSearch(entity, searchable: &searchable, progress: &progress,
                                 itemPos: itemPos, deltaTime: Float(deltaTime))
            } else {
                // Player stopped searching or not in range
                handleInactiveSearch(entity, searchable: &searchable, progress: &progress,
                                   deltaTime: Float(deltaTime))
            }

            // Update components
            entity.components.set(searchable)
            entity.components.set(progress)

            // Update progress bar visual if it exists
            if let bubble = entity.children.first(where: { $0.name == "ProgressBarBubble" }) {
                updateProgressBarVisual(bubble, progress: progress.progress)
            }
        }
    }

    private func handleActiveSearch(_ entity: Entity, searchable: inout SearchableComponent,
                                   progress: inout ProgressComponent, itemPos: PositionComponent,
                                   deltaTime: Float) {
        // Reset grace period timer when actively searching
        searchable.timeSinceLastSearch = 0.0

        // Start searching if not already
        if searchable.state == .searchable {
            searchable.state = .searching
            updateSearchableItemVisual(entity, state: .searching)

            if GameConfig.debugLogging {
                print("[Search] Started searching item at (\(itemPos.x), \(itemPos.y))")
            }
        }

        // Create progress bar bubble if it doesn't exist
        if entity.children.first(where: { $0.name == "ProgressBarBubble" }) == nil {
            let bubble = createProgressBarBubble()
            entity.addChild(bubble)

            if GameConfig.debugLogging {
                print("[Search] Created progress bar bubble")
            }
        }

        // Increase progress
        progress.progress += deltaTime / progress.duration
        progress.progress = min(progress.progress, 1.0)

        // Check if complete
        if progress.isComplete {
            searchable.state = .searched
            updateSearchableItemVisual(entity, state: .searched)

            if GameConfig.debugLogging {
                print("[Search] Completed searching item at (\(itemPos.x), \(itemPos.y))")
            }
        }
    }

    private func handleInactiveSearch(_ entity: Entity, searchable: inout SearchableComponent,
                                     progress: inout ProgressComponent, deltaTime: Float) {
        // Only process if there's progress to manage
        if !progress.hasStarted {
            return
        }

        // Increment grace period timer
        searchable.timeSinceLastSearch += deltaTime

        // Change state to searchable but keep progress
        if searchable.state == .searching {
            searchable.state = .searchable
        }

        // Check if grace period expired
        if searchable.isGracePeriodExpired {
            // Reset progress
            progress.progress = 0.0

            // Remove progress bar bubble
            if let bubble = entity.children.first(where: { $0.name == "ProgressBarBubble" }) {
                bubble.removeFromParent()

                if GameConfig.debugLogging {
                    print("[Search] Removed progress bar bubble (grace period expired)")
                }
            }

            // Reset timer
            searchable.timeSinceLastSearch = 0.0
        }
    }

    private func handleCompletedSearch(_ entity: Entity, searchable: inout SearchableComponent, deltaTime: Float) {
        // Fade out and remove bubble
        if let bubble = entity.children.first(where: { $0.name == "ProgressBarBubble" }),
           var visualComponent = bubble.components[ProgressBarVisualComponent.self] {

            // Fade out
            visualComponent.alpha -= deltaTime * visualComponent.fadeSpeed

            if visualComponent.alpha <= 0 {
                bubble.removeFromParent()

                if GameConfig.debugLogging {
                    print("[Search] Removed progress bar bubble (fade complete)")
                }
            } else {
                bubble.components.set(visualComponent)
                // TODO: Apply alpha to visual materials if needed
            }
        }
    }
}
