//
//  DebugLabelComponent.swift
//  GrimpossibleMission
//
//  Component for debug text labels attached to entities.
//

import RealityKit

/// Component that marks an entity as having debug text display
struct DebugLabelComponent: Component {
    var text: String = ""
    var offsetY: Float = 2.0  // Offset above parent entity
}
