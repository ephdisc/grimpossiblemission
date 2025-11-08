//
//  WorldInitializationManager.swift
//  GrimpossibleMission
//
//  Event-driven world initialization manager.
//  Ensures all entities and collision components are ready before starting physics.
//

import Foundation
import RealityKit
import Combine
import QuartzCore

/// Manages the event-driven initialization of the game world
class WorldInitializationManager {

    // MARK: - Initialization State

    private var sceneInitialized: Bool = false
    private var roomEntitiesAdded: Bool = false
    private var playerEntityAdded: Bool = false
    private var entitiesAnchored: Bool = false

    // MARK: - Tracked Entities

    private var roomEntitiesToTrack: [Entity] = []
    private var playerEntity: Entity?
    private var anchoredRoomEntities: Set<ObjectIdentifier> = []
    private var isPlayerAnchored: Bool = false

    // MARK: - Subscriptions

    private var sceneSubscriptions: Set<AnyCancellable> = []
    private var timeoutTimer: Timer?
    private var initializationStartTime: TimeInterval = 0

    // MARK: - Callbacks

    var onWorldReady: (() -> Void)?

    // MARK: - Initialization

    init() {
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Initialized")
        }
    }

    // MARK: - State Management

    /// Mark scene as initialized
    func markSceneInitialized() {
        sceneInitialized = true
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Scene initialized")
        }
        checkIfWorldReady()
    }

    /// Register room entities that need to be tracked
    func registerRoomEntities(_ entities: [Entity]) {
        roomEntitiesToTrack = entities
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Registered \(entities.count) room entities to track")
        }
    }

    /// Register player entity that needs to be tracked
    func registerPlayerEntity(_ entity: Entity) {
        playerEntity = entity
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Registered player entity to track")
        }
    }

    /// Mark room entities as added to scene and start monitoring
    func markRoomEntitiesAdded() {
        roomEntitiesAdded = true
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Room entities added to scene")
        }

        // Start timeout timer (safety mechanism)
        if timeoutTimer == nil {
            initializationStartTime = CACurrentMediaTime()
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if !self.entitiesAnchored {
                    print("[WorldInitializationManager] ⚠️ Timeout reached - forcing world ready")
                    self.forceWorldReady()
                }
            }
        }

        // Start monitoring room entities for scene anchoring
        monitorRoomEntitiesAnchored()
    }

    /// Mark player entity as added to scene and start monitoring
    func markPlayerEntityAdded() {
        playerEntityAdded = true
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Player entity added to scene")
        }

        // Start monitoring player entity for scene anchoring
        monitorPlayerEntityAnchored()
    }

    // MARK: - Scene Anchoring Monitoring

    /// Monitor room entities until they're properly anchored in the scene
    private func monitorRoomEntitiesAnchored() {
        // Check immediately
        checkRoomEntitiesAnchored()

        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Initial room check: \(anchoredRoomEntities.count)/\(roomEntitiesToTrack.count) anchored")
        }

        // If already all anchored, trigger ready check immediately
        if allRoomEntitiesAnchored() {
            if GameConfig.debugLogging {
                print("[WorldInitializationManager] All room entities already anchored")
            }
            checkIfWorldReady()
            return
        }

        // If not all anchored yet, set up a timer to periodically check
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Starting timer to monitor room entities")
        }

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.checkRoomEntitiesAnchored()

            if self.allRoomEntitiesAnchored() {
                timer.invalidate()
                if GameConfig.debugLogging {
                    print("[WorldInitializationManager] All room entities anchored")
                }
                self.checkIfWorldReady()
            } else if GameConfig.debugLogging {
                print("[WorldInitializationManager] Room entities: \(self.anchoredRoomEntities.count)/\(self.roomEntitiesToTrack.count) anchored")
            }
        }
    }

    /// Monitor player entity until it's properly anchored in the scene
    private func monitorPlayerEntityAnchored() {
        // Check immediately
        checkPlayerEntityAnchored()

        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Initial player check: anchored=\(isPlayerAnchored)")
        }

        // If already anchored, trigger ready check immediately
        if isPlayerAnchored {
            if GameConfig.debugLogging {
                print("[WorldInitializationManager] Player entity already anchored")
            }
            checkIfWorldReady()
            return
        }

        // If not anchored yet, set up a timer to check when it becomes anchored
        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Starting timer to monitor player entity")
        }

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.checkPlayerEntityAnchored()

            if self.isPlayerAnchored {
                timer.invalidate()
                if GameConfig.debugLogging {
                    print("[WorldInitializationManager] Player entity anchored")
                }
                self.checkIfWorldReady()
            } else if GameConfig.debugLogging {
                print("[WorldInitializationManager] Player not yet anchored")
            }
        }
    }

    /// Check if room entities are anchored to the scene
    private func checkRoomEntitiesAnchored() {
        for entity in roomEntitiesToTrack {
            let id = ObjectIdentifier(entity)

            // Check if entity has a scene (means it's properly added)
            // Room parent entities might not have collision components themselves,
            // but being added to scene means they and their children are being processed
            if entity.scene != nil {
                anchoredRoomEntities.insert(id)

                if GameConfig.debugLogging {
                    let hasCollision = entity.components.has(CollisionComponent.self)
                    print("[WorldInitializationManager] Room entity \(entity.name) anchored (hasCollision: \(hasCollision), children: \(entity.children.count))")
                }
            }
        }
    }

    /// Check if player entity is anchored to the scene
    private func checkPlayerEntityAnchored() {
        guard let player = playerEntity else { return }

        // Check if player has a scene - player should have collision component
        let hasScene = player.scene != nil
        let hasCollision = player.components.has(CollisionComponent.self)

        if GameConfig.debugLogging && hasScene != isPlayerAnchored {
            print("[WorldInitializationManager] Player check: scene=\(hasScene), collision=\(hasCollision)")
        }

        if hasScene && hasCollision {
            isPlayerAnchored = true
        }
    }

    /// Check if all room entities are anchored
    private func allRoomEntitiesAnchored() -> Bool {
        return anchoredRoomEntities.count == roomEntitiesToTrack.count
    }

    /// Check if all initialization conditions are met
    private func checkIfWorldReady() {
        let roomsReady = roomEntitiesAdded && allRoomEntitiesAnchored()
        let playerReady = playerEntityAdded && isPlayerAnchored
        let allReady = sceneInitialized && roomsReady && playerReady

        if GameConfig.debugLogging {
            let elapsed = initializationStartTime > 0 ? CACurrentMediaTime() - initializationStartTime : 0
            print("[WorldInitializationManager] Readiness check (\(String(format: "%.2f", elapsed))s elapsed):")
            print("  - Scene: \(sceneInitialized)")
            print("  - Rooms added: \(roomEntitiesAdded)")
            print("  - Rooms anchored: \(allRoomEntitiesAnchored()) (\(anchoredRoomEntities.count)/\(roomEntitiesToTrack.count))")
            print("  - Player added: \(playerEntityAdded)")
            print("  - Player anchored: \(isPlayerAnchored)")
            print("  - World ready: \(allReady)")
        }

        if allReady && !entitiesAnchored {
            // All entities are in the scene, but RealityKit needs a few frames to fully
            // process and initialize collision geometry. Wait 3 frames before starting physics.
            if GameConfig.debugLogging {
                print("[WorldInitializationManager] All entities anchored - waiting for RealityKit to process collision (3 frames)")
            }

            var frameCount = 0
            Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                frameCount += 1

                if frameCount >= 3 {
                    timer.invalidate()
                    self.entitiesAnchored = true
                    self.timeoutTimer?.invalidate()

                    let elapsed = self.initializationStartTime > 0 ? CACurrentMediaTime() - self.initializationStartTime : 0
                    if GameConfig.debugLogging {
                        print("[WorldInitializationManager] ✅ World is ready - all entities properly initialized (\(String(format: "%.2f", elapsed))s, waited \(frameCount) frames)")
                    }
                    self.onWorldReady?()
                }
            }
        }
    }

    /// Force world to be ready (called on timeout)
    private func forceWorldReady() {
        let elapsed = CACurrentMediaTime() - initializationStartTime
        print("[WorldInitializationManager] ⚠️ Forcing world ready after \(String(format: "%.2f", elapsed))s timeout")
        print("  - Scene: \(sceneInitialized)")
        print("  - Rooms added: \(roomEntitiesAdded), anchored: \(anchoredRoomEntities.count)/\(roomEntitiesToTrack.count)")
        print("  - Player added: \(playerEntityAdded), anchored: \(isPlayerAnchored)")

        entitiesAnchored = true
        timeoutTimer?.invalidate()
        onWorldReady?()
    }

    // MARK: - Reset

    /// Reset the initialization state (for testing or restarting)
    func reset() {
        sceneInitialized = false
        roomEntitiesAdded = false
        playerEntityAdded = false
        entitiesAnchored = false
        roomEntitiesToTrack.removeAll()
        playerEntity = nil
        anchoredRoomEntities.removeAll()
        isPlayerAnchored = false
        sceneSubscriptions.removeAll()
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        initializationStartTime = 0

        if GameConfig.debugLogging {
            print("[WorldInitializationManager] Reset")
        }
    }
}
