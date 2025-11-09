//
//  GestureRecognizerView.swift
//  GrimpossibleMission
//
//  UIViewRepresentable wrapper to attach gesture recognizers to SwiftUI view hierarchy.
//  Enables Siri Remote gesture capture in tvOS.
//

import SwiftUI
import UIKit

/// A transparent view that captures gestures for tvOS Siri Remote input.
/// Used to bridge UIKit gesture recognizers into SwiftUI.
struct GestureRecognizerView: UIViewRepresentable {

    let gestureRecognizers: [UIGestureRecognizer]

    func makeUIView(context: Context) -> UIView {
        let view = GestureCapturingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        // Add all gesture recognizers to the view
        for recognizer in gestureRecognizers {
            view.addGestureRecognizer(recognizer)
        }

        if GameConfig.debugLogging {
            print("[GestureView] Created gesture capturing view with \(gestureRecognizers.count) recognizers")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

/// Custom UIView that can capture focus and gestures on tvOS.
private class GestureCapturingView: UIView {

    override var canBecomeFocused: Bool {
        return true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedView == self {
            if GameConfig.debugLogging {
                print("[GestureView] View gained focus - ready to capture gestures")
            }
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Allow gesture recognizers to handle presses first
        super.pressesBegan(presses, with: event)

        // Log press events for debugging
        if GameConfig.debugLogging {
            for press in presses {
                var pressName = "Unknown"
                switch press.type {
                case .select:
                    pressName = "Select"
                case .menu:
                    pressName = "Menu"
                case .playPause:
                    pressName = "Play/Pause"
                case .upArrow:
                    pressName = "Up Arrow"
                case .downArrow:
                    pressName = "Down Arrow"
                case .leftArrow:
                    pressName = "Left Arrow"
                case .rightArrow:
                    pressName = "Right Arrow"
                default:
                    pressName = "Type \(press.type.rawValue)"
                }
                print("[GestureView] Press began: \(pressName)")
            }
        }
    }
}
