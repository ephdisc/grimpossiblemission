//
//  ProgressBarEntity.swift
//  GrimpossibleMission
//
//  Factory for creating progress bar bubble visuals.
//

import Foundation
import RealityKit
import UIKit

/// Creates a progress bar bubble entity that displays above an item.
/// - Parameters:
///   - text: Text to display (e.g., "searching...")
///   - offsetY: Y offset above parent entity
/// - Returns: Progress bar bubble entity with visual components
func createProgressBarBubble(text: String = "searching...", offsetY: Float = 1.5) -> Entity {
    let bubble = Entity()
    bubble.name = "ProgressBarBubble"

    // Progress bar dimensions
    let barWidth: Float = 2.0
    let barHeight: Float = 0.3
    let barDepth: Float = 0.1

    // Background bar (dark gray, full width)
    let backgroundMesh = MeshResource.generateBox(
        width: barWidth,
        height: barHeight,
        depth: barDepth
    )
    let backgroundMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
    let backgroundBar = Entity()
    backgroundBar.name = "ProgressBarBackground"
    backgroundBar.components.set(ModelComponent(mesh: backgroundMesh, materials: [backgroundMaterial]))
    backgroundBar.position = SIMD3<Float>(0, offsetY, 0)

    // Foreground bar (green, scales with progress)
    let foregroundMesh = MeshResource.generateBox(
        width: barWidth,
        height: barHeight,
        depth: barDepth
    )
    let foregroundMaterial = SimpleMaterial(color: .green, isMetallic: false)
    let foregroundBar = Entity()
    foregroundBar.name = "ProgressBarForeground"
    foregroundBar.components.set(ModelComponent(mesh: foregroundMesh, materials: [foregroundMaterial]))

    // Start with zero width (scale on X axis)
    foregroundBar.scale = SIMD3<Float>(0.0, 1.0, 1.0)
    foregroundBar.position = SIMD3<Float>(0, offsetY, 0.1)  // Slightly in front

    // Add component to track this as a progress bar visual
    let visualComponent = ProgressBarVisualComponent(text: text, offsetY: offsetY)
    bubble.components.set(visualComponent)

    // Add background and foreground as children
    bubble.addChild(backgroundBar)
    bubble.addChild(foregroundBar)

    // Add debug label with text
    let debugLabel = DebugLabelComponent(text: text, offsetY: offsetY + 0.5)
    bubble.components.set(debugLabel)

    return bubble
}

/// Updates the progress bar visual based on progress value (0.0 to 1.0)
func updateProgressBarVisual(_ bubbleEntity: Entity, progress: Float) {
    guard let foregroundBar = bubbleEntity.findEntity(named: "ProgressBarForeground") else {
        return
    }

    // Scale the foreground bar on X axis to show progress
    let clampedProgress = max(0.0, min(1.0, progress))
    foregroundBar.scale.x = clampedProgress

    // Shift position so bar grows from left to right
    let barWidth: Float = 2.0
    let offset = (barWidth * clampedProgress - barWidth) / 2.0
    foregroundBar.position.x = offset
}
