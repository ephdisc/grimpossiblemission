//
//  SiriRemoteInputProvider.swift
//  GrimpossibleMission
//
//  Implements input handling for tvOS Siri Remote via gesture recognizers.
//  Priority 2 input method (after game controllers).
//

import UIKit
import Foundation

/// Provides input from Siri Remote gestures.
/// Uses UIGestureRecognizers that are added to the view hierarchy.
class SiriRemoteInputProvider: InputProvider {

    private var currentInputState = InputState()

    // Gesture recognizers (kept as strong references)
    private var swipeRightRecognizer: UISwipeGestureRecognizer?
    private var swipeLeftRecognizer: UISwipeGestureRecognizer?
    private var swipeUpRecognizer: UISwipeGestureRecognizer?
    private var swipeDownRecognizer: UISwipeGestureRecognizer?
    private var tapRecognizer: UITapGestureRecognizer?

    // State tracking for continuous input
    private var isSwipingLeft = false
    private var isSwipingRight = false
    private var isSwipingUp = false
    private var isSwipingDown = false

    // Swipe reset timers
    private var swipeResetTimer: Timer?
    private let swipeResetDelay: TimeInterval = 0.3  // How long swipe input stays active

    init() {
        if GameConfig.debugLogging {
            print("[SiriRemote] Input provider initialized")
        }
    }

    // MARK: - InputProvider Protocol

    func getInputState() -> InputState {
        return currentInputState
    }

    func startListening() {
        if GameConfig.debugLogging {
            print("[SiriRemote] Started listening for Siri Remote input")
        }
        // Gesture recognizers are set up externally via setupGestureRecognizers
        // This is called when the game starts
    }

    func stopListening() {
        if GameConfig.debugLogging {
            print("[SiriRemote] Stopped listening for Siri Remote input")
        }

        // Reset input state
        currentInputState = InputState()

        // Cancel any active timers
        swipeResetTimer?.invalidate()
        swipeResetTimer = nil
    }

    // MARK: - Gesture Recognizer Setup

    /// Creates and returns gesture recognizers that should be added to a view.
    /// Call this from your view controller/SwiftUI view and add recognizers to the view hierarchy.
    func createGestureRecognizers() -> [UIGestureRecognizer] {
        var recognizers: [UIGestureRecognizer] = []

        // Swipe Right (inverted: maps to moveLeft due to camera perspective)
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        swipeRightRecognizer = swipeRight
        recognizers.append(swipeRight)

        // Swipe Left (inverted: maps to moveRight due to camera perspective)
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        swipeLeftRecognizer = swipeLeft
        recognizers.append(swipeLeft)

        // Swipe Up (for searching/interacting)
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        swipeUpRecognizer = swipeUp
        recognizers.append(swipeUp)

        // Swipe Down
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        swipeDownRecognizer = swipeDown
        recognizers.append(swipeDown)

        // Tap (Select button - maps to jump)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        tapRecognizer = tap
        recognizers.append(tap)

        if GameConfig.debugLogging {
            print("[SiriRemote] Created \(recognizers.count) gesture recognizers")
        }

        return recognizers
    }

    // MARK: - Gesture Handlers

    @objc private func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .ended {
            // Swipe right = move left (inverted to match camera)
            if GameConfig.debugLogging {
                print("[SiriRemote] Swipe Right → Move Left")
            }

            currentInputState.moveLeft = true
            currentInputState.moveRight = false
            isSwipingLeft = true
            isSwipingRight = false

            // Reset after delay
            scheduleSwipeReset()
        }
    }

    @objc private func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .ended {
            // Swipe left = move right (inverted to match camera)
            if GameConfig.debugLogging {
                print("[SiriRemote] Swipe Left → Move Right")
            }

            currentInputState.moveRight = true
            currentInputState.moveLeft = false
            isSwipingRight = true
            isSwipingLeft = false

            // Reset after delay
            scheduleSwipeReset()
        }
    }

    @objc private func handleSwipeUp(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .ended {
            if GameConfig.debugLogging {
                print("[SiriRemote] Swipe Up → Interact (Search)")
            }

            currentInputState.moveUp = true
            currentInputState.moveDown = false
            isSwipingUp = true
            isSwipingDown = false

            // Keep interact active for longer to allow searching
            scheduleSwipeReset(delay: 1.0)
        }
    }

    @objc private func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .ended {
            if GameConfig.debugLogging {
                print("[SiriRemote] Swipe Down")
            }

            currentInputState.moveDown = true
            currentInputState.moveUp = false
            isSwipingDown = true
            isSwipingUp = false

            scheduleSwipeReset()
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if gesture.state == .ended {
            if GameConfig.debugLogging {
                print("[SiriRemote] Tap (Select) → Jump")
            }

            // For jump, we need a brief pulse
            currentInputState.jump = true

            // Reset jump after a brief moment (simulating button press/release)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.currentInputState.jump = false
            }
        }
    }

    // MARK: - Helper Methods

    private func scheduleSwipeReset(delay: TimeInterval? = nil) {
        // Cancel existing timer
        swipeResetTimer?.invalidate()

        let resetDelay = delay ?? swipeResetDelay

        // Schedule new timer to reset movement input
        swipeResetTimer = Timer.scheduledTimer(withTimeInterval: resetDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Reset all movement inputs
            self.currentInputState.moveLeft = false
            self.currentInputState.moveRight = false
            self.currentInputState.moveUp = false
            self.currentInputState.moveDown = false

            self.isSwipingLeft = false
            self.isSwipingRight = false
            self.isSwipingUp = false
            self.isSwipingDown = false

            if GameConfig.debugLogging {
                print("[SiriRemote] Swipe input reset")
            }
        }
    }

    deinit {
        swipeResetTimer?.invalidate()
        if GameConfig.debugLogging {
            print("[SiriRemote] Input provider deinitialized")
        }
    }
}
