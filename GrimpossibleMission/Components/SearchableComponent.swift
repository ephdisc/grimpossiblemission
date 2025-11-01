//
//  SearchableComponent.swift
//  GrimpossibleMission
//
//  Component for items that can be searched by the player.
//

import RealityKit

/// State of a searchable item
enum SearchableState {
    case searchable  // Not yet searched
    case searching   // Currently being searched
    case searched    // Already searched
}

/// Component for items that can be searched by the player.
struct SearchableComponent: Component {
    var state: SearchableState = .searchable
    var searchProgress: Float = 0.0  // 0.0 to 1.0
    var searchDuration: Float = 2.0  // Seconds to complete search

    /// Check if item is fully searched
    var isSearched: Bool {
        state == .searched
    }

    /// Check if currently being searched
    var isSearching: Bool {
        state == .searching
    }
}
