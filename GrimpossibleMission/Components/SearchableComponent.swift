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
    case searched    // Already searched (complete)
}

/// Component for items that can be searched by the player.
/// Use with ProgressComponent to track search progress.
struct SearchableComponent: Component {
    var state: SearchableState = .searchable

    /// Grace period in seconds - how long the bubble stays visible after stopping
    var gracePeriod: Float = 2.0

    /// Time elapsed since user stopped searching (for grace period timeout)
    var timeSinceLastSearch: Float = 0.0

    /// Check if item is fully searched
    var isSearched: Bool {
        state == .searched
    }

    /// Check if currently being searched
    var isSearching: Bool {
        state == .searching
    }

    /// Check if grace period has expired
    var isGracePeriodExpired: Bool {
        timeSinceLastSearch >= gracePeriod
    }
}
