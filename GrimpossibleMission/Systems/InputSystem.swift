//
//  InputSystem.swift
//  GrimpossibleMission
//
//  ECS System that updates entity input components from input providers.
//

import Foundation
import RealityKit

/// System that reads input from an InputProvider and updates entity InputStateComponents.
class InputSystem: GameSystem {

    private let inputProvider: InputProvider

    init(inputProvider: InputProvider) {
        self.inputProvider = inputProvider
    }

    func update(deltaTime: TimeInterval, entities: [Entity]) {
        // Get current input state from provider
        let inputState = inputProvider.getInputState()

        // Update all entities that have InputStateComponent
        for entity in entities {
            if var inputComponent = entity.components[InputStateComponent.self] {
                // Update input component with current state
                inputComponent.moveLeft = inputState.moveLeft
                inputComponent.moveRight = inputState.moveRight
                inputComponent.moveUp = inputState.moveUp
                inputComponent.moveDown = inputState.moveDown
                inputComponent.jump = inputState.jump
                inputComponent.interact = inputState.interact

                // Write back to entity
                entity.components.set(inputComponent)
            }
        }
    }
}
