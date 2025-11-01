//
//  SearchProgressComponent.swift
//  GrimpossibleMission
//
//  Component that tracks search progress for an item being searched.
//

import RealityKit

/// Tracks the progress of searching an item.
struct SearchProgressComponent: Component {
    /// Current search progress (0.0 to 1.0)
    var progress: Float

    /// Whether the player is currently interacting with this item
    var isBeingSearched: Bool

    init(progress: Float = 0.0, isBeingSearched: Bool = false) {
        self.progress = progress
        self.isBeingSearched = isBeingSearched
    }
}
