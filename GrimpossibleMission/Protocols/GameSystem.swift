//
//  GameSystem.swift
//  GrimpossibleMission
//
//  Base protocol for all ECS systems.
//

import Foundation
import RealityKit

/// Base protocol that all game systems must conform to.
/// Systems process entities with specific component combinations each frame.
protocol GameSystem {
    /// Update the system for the current frame.
    /// - Parameters:
    ///   - deltaTime: Time elapsed since last frame in seconds
    ///   - entities: All entities in the game world
    func update(deltaTime: TimeInterval, entities: [Entity])
}
