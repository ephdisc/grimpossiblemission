//
//  ContentView.swift
//  GrimpossibleMission
//
//  Main view for the 2.5D platform game.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    // Input providers (created outside of StateObject to access gesture recognizers)
    private static let gameControllerProvider = GameControllerInputProvider()
    private static let siriRemoteProvider = SiriRemoteInputProvider()
    private static let compositeInputProvider = CompositeInputProvider(
        providers: [gameControllerProvider, siriRemoteProvider]
    )

    // Game coordinator manages ECS lifecycle (uses @StateObject to persist across view updates)
    @StateObject private var gameCoordinator: GameCoordinator = {
        // Set up dependency injection
        let cameraController = OrthographicCameraController()

        // Create game coordinator with composite input (controller + Siri Remote)
        return GameCoordinator(
            inputProvider: compositeInputProvider,
            cameraController: cameraController
        )
    }()

    // Debug info for player velocity
    @State private var velocityInfo: String = ""
    @State private var updateTimer: Timer?

    // Track if initialization has run
    @State private var hasInitialized: Bool = false

    var body: some View {
        ZStack {
            // Gesture recognizer view for Siri Remote input (invisible, captures gestures)
            GestureRecognizerView(
                gestureRecognizers: Self.siriRemoteProvider.createGestureRecognizers()
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(true)

            // Main game view
            RealityView { content in
                // Only run initialization once (SwiftUI may call this closure multiple times)
                if !hasInitialized {
                    if GameConfig.debugLogging {
                        print("[ContentView] RealityKit scene created - starting structured initialization")
                    }

                    // Phase 3: Add all game entities to the RealityKit scene
                    gameCoordinator.addEntitiesToScene(content)

                    // Phase 4: Start initialization sequence (event-driven, will start physics when ready)
                    gameCoordinator.startInitialization()

                    if GameConfig.debugLogging {
                        print("[ContentView] Initialization sequence started - physics will begin when world is ready")
                    }

                    hasInitialized = true
                } else {
                    if GameConfig.debugLogging {
                        print("[ContentView] ⚠️ RealityView content closure called again - skipping duplicate initialization")
                    }
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
