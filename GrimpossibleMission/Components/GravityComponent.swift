//
//  GravityComponent.swift
//  GrimpossibleMission
//
//  Component for entities affected by gravity.
//

import RealityKit

/// Component that marks entities as affected by gravity.
/// The presence of this component indicates gravity acceleration should be applied when airborne.
/// Gravity value is configured in GameConfig.gravity
struct GravityComponent: Component {
    // No fields needed - component presence is the flag
}
