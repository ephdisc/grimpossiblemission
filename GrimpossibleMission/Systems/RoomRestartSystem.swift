//
//  RoomRestartSystem.swift
//  GrimpossibleMission
//
//  ECS System that monitors X button hold to trigger room restart.
//

import Foundation
import RealityKit

/// System that monitors X button hold duration and triggers room restart after 2 seconds.
class RoomRestartSystem: GameSystem {

    // Threshold for triggering restart (2 seconds)
    private let restartHoldThreshold: Float = 2.0

    // Callback to trigger room restart
    var onRestartRequested: (() -> Void)?

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Find player entity
        for entity in entities {
            guard var inputState = entity.components[InputStateComponent.self],
                  entity.components[PlayerComponent.self] != nil else {
                continue
            }

            // Check if X button (interact) is being held
            if inputState.interact {
                // Increment hold time
                inputState.restartHoldTime += Float(deltaTime)

                // Check if threshold reached and not yet triggered
                if inputState.restartHoldTime >= restartHoldThreshold && !inputState.restartTriggered {
                    inputState.restartTriggered = true

                    if GameConfig.debugLogging {
                        print("[RoomRestart] X button held for \(restartHoldThreshold)s - triggering room restart")
                    }

                    // Trigger restart callback
                    onRestartRequested?()
                }
            } else {
                // Button released - reset timer and trigger flag
                inputState.restartHoldTime = 0.0
                inputState.restartTriggered = false
            }

            // Update component
            entity.components.set(inputState)
        }
    }
}
