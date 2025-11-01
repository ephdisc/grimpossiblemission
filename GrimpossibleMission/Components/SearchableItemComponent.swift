//
//  SearchableItemComponent.swift
//  GrimpossibleMission
//
//  Component that marks an entity as a searchable item with state.
//

import RealityKit

/// State of a searchable item
enum SearchState {
    case searchable  // Not yet searched (red)
    case searched    // Already searched (dark red)
}

/// Component for items that can be searched by the player.
struct SearchableItemComponent: Component {
    /// Current state of the item
    var state: SearchState

    /// How long the player must hold "up" to complete the search (in seconds)
    var searchDuration: Float

    /// Proximity distance required for interaction (in world units)
    var interactionDistance: Float

    init(state: SearchState = .searchable,
         searchDuration: Float = 2.0,
         interactionDistance: Float = 2.0) {
        self.state = state
        self.searchDuration = searchDuration
        self.interactionDistance = interactionDistance
    }
}
