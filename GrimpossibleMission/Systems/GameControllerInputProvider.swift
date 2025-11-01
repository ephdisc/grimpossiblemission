//
//  GameControllerInputProvider.swift
//  GrimpossibleMission
//
//  Implements input handling for game controllers (Xbox, PlayStation, etc).
//

import GameController
import Foundation

/// Provides input from game controllers.
class GameControllerInputProvider: InputProvider {

    private var currentInputState = InputState()
    private var connectedController: GCController?

    init() {
        setupControllerObservers()
    }

    // MARK: - InputProvider Protocol

    func getInputState() -> InputState {
        return currentInputState
    }

    func startListening() {
        // Connect to first available controller
        if let controller = GCController.controllers().first {
            connectToController(controller)
        }
    }

    func stopListening() {
        disconnectFromController()
    }

    // MARK: - Controller Management

    private func setupControllerObservers() {
        // Listen for controller connection events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @objc private func controllerDidConnect(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }

        if GameConfig.debugLogging {
            print("[Input] Controller connected: \(controller.vendorName ?? "Unknown")")
        }

        // Connect to the first controller if we don't have one yet
        if connectedController == nil {
            connectToController(controller)
        }
    }

    @objc private func controllerDidDisconnect(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }

        if GameConfig.debugLogging {
            print("[Input] Controller disconnected: \(controller.vendorName ?? "Unknown")")
        }

        if connectedController == controller {
            disconnectFromController()

            // Try to connect to another available controller
            if let newController = GCController.controllers().first {
                connectToController(newController)
            }
        }
    }

    private func connectToController(_ controller: GCController) {
        connectedController = controller

        // Set up extended gamepad handlers (Xbox, PlayStation, etc.)
        if let gamepad = controller.extendedGamepad {
            setupExtendedGamepadHandlers(gamepad)
        }

        if GameConfig.debugLogging {
            print("[Input] Using controller: \(controller.vendorName ?? "Unknown")")
        }
    }

    private func disconnectFromController() {
        connectedController = nil
        currentInputState = InputState() // Reset input state
    }

    // MARK: - Input Handlers

    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        // D-Pad Left (inverted to match camera perspective)
        gamepad.dpad.left.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.moveRight = pressed
        }

        // D-Pad Right (inverted to match camera perspective)
        gamepad.dpad.right.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.moveLeft = pressed
        }

        // D-Pad Up (Interact)
        gamepad.dpad.up.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.moveUp = pressed
            self?.currentInputState.interact = pressed
        }

        // D-Pad Down
        gamepad.dpad.down.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.moveDown = pressed
        }

        // Left Thumbstick (alternate movement)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            guard let self = self else { return }
            let deadzone = GameConfig.inputDeadzone

            // Horizontal axis (inverted to match camera perspective)
            if xValue < -deadzone {
                self.currentInputState.moveRight = true
                self.currentInputState.moveLeft = false
            } else if xValue > deadzone {
                self.currentInputState.moveLeft = true
                self.currentInputState.moveRight = false
            } else {
                // Reset if D-pad isn't being used
                if !gamepad.dpad.left.isPressed {
                    self.currentInputState.moveLeft = false
                }
                if !gamepad.dpad.right.isPressed {
                    self.currentInputState.moveRight = false
                }
            }

            // Vertical axis
            if yValue < -deadzone {
                self.currentInputState.moveDown = true
                self.currentInputState.moveUp = false
            } else if yValue > deadzone {
                self.currentInputState.moveUp = true
                self.currentInputState.moveDown = false
            } else {
                // Reset if D-pad isn't being used
                if !gamepad.dpad.up.isPressed {
                    self.currentInputState.moveUp = false
                }
                if !gamepad.dpad.down.isPressed {
                    self.currentInputState.moveDown = false
                }
            }
        }

        // A Button (Jump) - Xbox A, PlayStation X
        gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.jump = pressed
        }

        // B Button - CAPTURE this to prevent app exit
        // On Xbox this is B, on PlayStation this is Circle
        gamepad.buttonB.valueChangedHandler = { [weak self] (button, value, pressed) in
            // Handle B button for game logic (currently unused)
            // This handler prevents the default tvOS behavior of exiting the app
            if GameConfig.debugLogging && pressed {
                print("[Input] B button pressed (captured)")
            }
        }

        // X Button (Interact) - Xbox X, PlayStation Square
        gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.interact = pressed
        }

        // Y Button - Xbox Y, PlayStation Triangle
        gamepad.buttonY.valueChangedHandler = { [weak self] (button, value, pressed) in
            // Reserved for future use
        }

        // Left/Right Shoulder Buttons (alternate interact)
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.interact = self?.currentInputState.interact ?? false || pressed
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.currentInputState.interact = self?.currentInputState.interact ?? false || pressed
        }

        if GameConfig.debugLogging {
            print("[Input] Extended gamepad handlers configured")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
