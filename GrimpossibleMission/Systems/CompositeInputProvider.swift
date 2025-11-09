//
//  CompositeInputProvider.swift
//  GrimpossibleMission
//
//  Combines multiple input providers (game controller + Siri Remote).
//  Returns OR'd input state from all active providers.
//

import Foundation

/// Aggregates input from multiple sources.
/// Useful for supporting both game controllers and Siri Remote simultaneously.
class CompositeInputProvider: InputProvider {

    private let providers: [InputProvider]

    init(providers: [InputProvider]) {
        self.providers = providers

        if GameConfig.debugLogging {
            print("[CompositeInput] Initialized with \(providers.count) input provider(s)")
        }
    }

    // MARK: - InputProvider Protocol

    func getInputState() -> InputState {
        // Start with empty state
        var compositeState = InputState()

        // OR together all provider inputs
        for provider in providers {
            let state = provider.getInputState()

            compositeState.moveLeft = compositeState.moveLeft || state.moveLeft
            compositeState.moveRight = compositeState.moveRight || state.moveRight
            compositeState.moveUp = compositeState.moveUp || state.moveUp
            compositeState.moveDown = compositeState.moveDown || state.moveDown
            compositeState.jump = compositeState.jump || state.jump
            compositeState.interact = compositeState.interact || state.interact
            compositeState.debugZoom = compositeState.debugZoom || state.debugZoom
        }

        return compositeState
    }

    func startListening() {
        if GameConfig.debugLogging {
            print("[CompositeInput] Starting all input providers")
        }

        for provider in providers {
            provider.startListening()
        }
    }

    func stopListening() {
        if GameConfig.debugLogging {
            print("[CompositeInput] Stopping all input providers")
        }

        for provider in providers {
            provider.stopListening()
        }
    }
}
