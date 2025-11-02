//
//  ContentView.swift
//  GrimpossibleMission
//
//  Main view for the 2.5D platform game.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    // Game coordinator manages ECS lifecycle
    private let gameCoordinator: GameCoordinator

    // Debug info for player velocity
    @State private var velocityInfo: String = ""
    @State private var updateTimer: Timer?

    init() {
        // Set up dependency injection
        let inputProvider = GameControllerInputProvider()
        let cameraController = OrthographicCameraController()

        // Create game coordinator with dependencies
        self.gameCoordinator = GameCoordinator(
            inputProvider: inputProvider,
            cameraController: cameraController
        )
    }

    var body: some View {
        ZStack {
            // Main game view
            RealityView { content in
                // Add all game entities to the scene
                gameCoordinator.addEntitiesToScene(content)

                // Start game loop
                gameCoordinator.start()

                if GameConfig.debugLogging {
                    print("[ContentView] Game scene initialized")
                }
            }
            .ignoresSafeArea()

            // Player velocity debug overlay
            VStack {
                HStack {
                    Text(velocityInfo)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    Spacer()
                }
                Spacer()
            }
            .padding()

            // Debug overlay (if enabled)
            if GameConfig.debugVisualization {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Debug Info") {
                            gameCoordinator.printDebugInfo()
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            // Start timer to update player velocity info
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                velocityInfo = gameCoordinator.getPlayerVelocityInfo()
            }
        }
        // IMPORTANT: Prevents menu/home button from exiting the app
        // This is required for tvOS games to capture B button and menu button
        .onExitCommand {
            // Empty handler prevents default exit behavior
            // Game stays running when user presses B or menu button
        }
        .onDisappear {
            // Stop update timer
            updateTimer?.invalidate()
            updateTimer = nil

            // Stop game loop when view disappears
            gameCoordinator.stop()
        }
    }
}

#Preview {
    ContentView()
}
