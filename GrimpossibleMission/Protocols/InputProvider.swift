//
//  InputProvider.swift
//  GrimpossibleMission
//
//  Protocol for input abstraction to support multiple input methods.
//

import Foundation

/// Input state structure returned by InputProvider
struct InputState {
    var moveLeft: Bool = false
    var moveRight: Bool = false
    var moveUp: Bool = false
    var moveDown: Bool = false
    var jump: Bool = false
    var interact: Bool = false
}

/// Protocol for providing input from various sources (game controller, remote, keyboard).
/// Allows dependency injection of different input implementations.
protocol InputProvider {
    /// Get the current input state
    func getInputState() -> InputState

    /// Start listening for input events
    func startListening()

    /// Stop listening for input events
    func stopListening()
}
