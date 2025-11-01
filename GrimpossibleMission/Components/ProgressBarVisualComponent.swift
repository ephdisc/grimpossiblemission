//
//  ProgressBarVisualComponent.swift
//  GrimpossibleMission
//
//  Component that marks an entity as a progress bar visualization.
//

import RealityKit

/// Component for progress bar visual entities.
/// These are child entities that display progress from a parent's ProgressComponent.
struct ProgressBarVisualComponent: Component {
    /// Text to display (e.g., "searching...")
    var text: String = "searching..."

    /// Offset above the parent entity
    var offsetY: Float = 1.5

    /// Alpha value for fade out animation
    var alpha: Float = 1.0

    /// Fade out speed when completing
    var fadeSpeed: Float = 2.0  // Alpha units per second
}
