//
//  GameCoordinator.swift
//  GrimpossibleMission
//
//  Main coordinator that manages the ECS lifecycle and game loop.
//

import Foundation
import SwiftUI
import RealityKit
import Combine

/// Coordinates the game loop, systems, and entities.
class GameCoordinator: ObservableObject {

    // MARK: - Properties

    /// All game systems that run each frame
    private var systems: [GameSystem] = []

    /// All entities in the game world
    private var entities: [Entity] = []

    /// Room entities for camera management
    private var roomEntities: [Entity] = []

    /// Level data for lazy room generation
    private var levelData: LevelData?

    /// Map of room index to generated room entity
    private var generatedRooms: [Int: Entity] = [:]

    /// Map of room index to searchable items in that room
    private var roomSearchables: [Int: [Entity]] = [:]

    /// Map of roomIndex to (gridRow, worldCol, roomId) for lazy generation
    /// Note: worldCol is mirrored from grid col (worldCol = cols - 1 - col)
    private var roomIndexToGridMap: [Int: (row: Int, worldCol: Int, roomId: Int)] = [:]

    /// RealityKit scene content reference
    private var sceneContent: (any RealityViewContentProtocol)?

    /// Input provider (injected)
    private let inputProvider: InputProvider

    /// Camera controller (injected)
    let cameraController: OrthographicCameraController

    /// Camera management system
    private var cameraManagementSystem: CameraManagementSystem?

    /// Room restart system
    private var roomRestartSystem: RoomRestartSystem?

    /// Reference to player entity
    private(set) var player: Entity?

    /// Player entrance position for current room (captured when entering)
    private var roomEntrancePosition: SIMD3<Float> = SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)

    /// Current room index
    private var currentRoomIndex: Int = 0

    /// World initialization manager (event-based initialization coordination)
    private let worldInitManager: WorldInitializationManager

    /// Track if all rooms have been generated for debug zoom
    private var allRoomsGenerated: Bool = false

    /// Timer for update loop
    private var updateTimer: Timer?

    /// Last update time for delta time calculation
    private var lastUpdateTime: TimeInterval = 0

    /// Velocity tracking for debug
    private var minVelocityX: Float = 0
    private var maxVelocityX: Float = 0
    private var minVelocityY: Float = 0
    private var maxVelocityY: Float = 0
    private var lastJumpTime: TimeInterval = 0
    private var wasJumping: Bool = false

    // MARK: - Initialization

    init(inputProvider: InputProvider, cameraController: OrthographicCameraController) {
        self.inputProvider = inputProvider
        self.cameraController = cameraController
        self.worldInitManager = WorldInitializationManager()

        setupSystems()
        setupWorld()

        // Configure world initialization callback
        worldInitManager.onWorldReady = { [weak self] in
            self?.onWorldReady()
        }
    }

    // MARK: - Setup

    private func setupSystems() {
        // Create systems in order of execution

        // 1. Input system (reads controller input)
        let inputSystem = InputSystem(inputProvider: inputProvider)
        systems.append(inputSystem)

        // 2. Jump system (handles jump logic and arc calculation)
        let jumpSystem = JumpSystem()
        systems.append(jumpSystem)

        // 3. Movement system (converts input to velocity)
        let movementSystem = MovementSystem()
        systems.append(movementSystem)

        // 4. Physics system (applies gravity, velocity, and collision)
        let physicsSystem = PhysicsSystem()
        systems.append(physicsSystem)

        // 5. Search system (handles searchable item interactions)
        let searchSystem = SearchSystem()
        systems.append(searchSystem)

        // 6. Room restart system (monitors X button hold for restart)
        let restartSystem = RoomRestartSystem()
        restartSystem.onRestartRequested = { [weak self] in
            self?.restartRoom()
        }
        self.roomRestartSystem = restartSystem
        systems.append(restartSystem)

        // 7. Debug visualization system (renders debug overlays like jump arcs)
        let debugSystem = DebugVisualizationSystem()
        systems.append(debugSystem)

        // 8. Camera system (updates camera based on player position)
        let cameraSystem = CameraManagementSystem(cameraController: cameraController)
        cameraSystem.onRoomChanged = { [weak self] roomIndex, playerPosition in
            self?.onPlayerEnteredRoom(roomIndex: roomIndex, entryPosition: playerPosition)
        }
        cameraSystem.onDebugZoomActivated = { [weak self] in
            self?.generateAllRooms()
        }
        self.cameraManagementSystem = cameraSystem
        systems.append(cameraSystem)

        if GameConfig.debugLogging {
            print("[GameCoordinator] Systems initialized: \(systems.count)")
        }
    }

    private func setupWorld() {
        if GameConfig.debugLogging {
            print("[GameCoordinator] ===== PHASE 1: Lightweight Setup =====")
        }

        var spawnPosition: SIMD3<Float>? = nil
        var spawnRoomIndex: Int = 0

        // Load level from JSON (lightweight - just parsing)
        if let data = LevelLoader.loadLevel(filename: "level_001") {
            self.levelData = data

            if GameConfig.debugLogging {
                print("[GameCoordinator] Loaded level 'level_001' with \(data.rooms.count) room definitions")
            }

            // Build room index mapping (mirrors the iteration order used in spawn finding)
            buildRoomIndexMapping()

            // Find spawn position from level data (lightweight, just scans JSON)
            if let spawn = findSpawnPosition(levelData: data) {
                spawnPosition = spawn.position
                spawnRoomIndex = spawn.roomIndex

                if GameConfig.debugLogging {
                    print("[GameCoordinator] Found spawn point in room \(spawnRoomIndex) at position (\(spawn.position.x), \(spawn.position.y))")
                }
            } else {
                print("[GameCoordinator] Warning: No spawn point found in level, using default position")
                spawnPosition = SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)
            }

            // LAZY LOADING: Only generate the spawn room initially
            if GameConfig.debugLogging {
                print("[GameCoordinator] ===== PHASE 2: Entity Creation =====")
                print("[GameCoordinator] Generating only spawn room \(spawnRoomIndex)...")
            }

            generateRoom(spawnRoomIndex)

            if GameConfig.debugLogging {
                print("[GameCoordinator] Spawn room generated. Ready to start game.")
            }

            // Set camera to spawn room (room already registered by generateRoom)
            if GameConfig.debugLogging {
                print("[GameCoordinator] Setting initial camera to spawn room \(spawnRoomIndex)")
            }
            cameraManagementSystem?.setInitialRoom(spawnRoomIndex)
        } else {
            // Fallback to hardcoded POC rooms if JSON loading fails
            print("[GameCoordinator] Warning: Failed to load level JSON, using POC rooms")
            roomEntities = createPOCRooms()
            entities.append(contentsOf: roomEntities)
            spawnPosition = SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)

            // Register rooms with camera system (POC path only)
            cameraManagementSystem?.registerRoomEntities(roomEntities)

            // Set camera to spawn room
            cameraManagementSystem?.setInitialRoom(spawnRoomIndex)
        }

        // Use spawn position for player creation (or fall back to default)
        let finalSpawnPosition = spawnPosition ?? SIMD3<Float>(GameConfig.playerStartX, GameConfig.playerStartY, 0)

        // Create player at spawn position
        player = createPlayerEntity(
            startX: finalSpawnPosition.x,
            startY: finalSpawnPosition.y
        )
        if let player = player {
            entities.append(player)

            // Set initial entrance position to spawn position
            roomEntrancePosition = finalSpawnPosition

            // Set initial room index to spawn room
            currentRoomIndex = spawnRoomIndex
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] World created: \(entities.count) entities")
            print("[GameCoordinator] Initial spawn position: (\(finalSpawnPosition.x), \(finalSpawnPosition.y)) in room \(spawnRoomIndex)")
            print("[GameCoordinator] Initial entrance position: (\(roomEntrancePosition.x), \(roomEntrancePosition.y))")
            print("[GameCoordinator] ⚠️  Physics NOT started yet - waiting for scene initialization")
        }
    }

    // MARK: - Room Generation

    /// Generate all rooms (for debug zoom visualization)
    func generateAllRooms() {
        guard !allRoomsGenerated else { return }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Debug zoom activated - generating all rooms...")
        }

        // Generate all rooms in the mapping
        for roomIndex in roomIndexToGridMap.keys.sorted() {
            generateRoom(roomIndex)
        }

        allRoomsGenerated = true

        if GameConfig.debugLogging {
            print("[GameCoordinator] ✅ All \(roomIndexToGridMap.count) rooms generated for debug zoom")
        }
    }

    // MARK: - Lazy Room Generation

    /// Build mapping from roomIndex to grid coordinates (mirrors iteration order of spawn finding)
    private func buildRoomIndexMapping() {
        guard let levelData = levelData else { return }
        guard let floorLayouts = levelData.floorLayouts, !floorLayouts.isEmpty else { return }

        var roomIndexCounter = 0

        for floorLayout in floorLayouts {
            for row in 0..<floorLayout.rows {
                for col in 0..<floorLayout.cols {
                    guard row < floorLayout.grid.count,
                          col < floorLayout.grid[row].count else {
                        continue
                    }

                    let roomId = floorLayout.grid[row][col]
                    if roomId != 0 {
                        // Grid columns are mirrored to world columns (matches spawn finding logic)
                        let worldCol = floorLayout.cols - 1 - col
                        roomIndexToGridMap[roomIndexCounter] = (row: row, worldCol: worldCol, roomId: roomId)
                        roomIndexCounter += 1
                    }
                }
            }
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Built room index mapping: \(roomIndexToGridMap.count) rooms")
        }
    }

    /// Generate a single room on-demand
    private func generateRoom(_ roomIndex: Int) {
        // Bounds check: ignore negative or invalid indices
        if roomIndex < 0 {
            return  // Silently ignore negative indices
        }

        // Check if already generated
        if generatedRooms[roomIndex] != nil {
            if GameConfig.debugLogging {
                print("[GameCoordinator] Room \(roomIndex) already generated, skipping")
            }
            return
        }

        // Look up grid coordinates from mapping
        guard let gridInfo = roomIndexToGridMap[roomIndex] else {
            // Room index not in mapping (out of range)
            return
        }

        let gridRow = gridInfo.row
        let worldCol = gridInfo.worldCol  // Already mirrored in mapping
        let roomId = gridInfo.roomId

        guard let levelData = levelData else {
            print("[GameCoordinator] Error: No level data available for lazy generation")
            return
        }

        guard let floorLayouts = levelData.floorLayouts, !floorLayouts.isEmpty else {
            print("[GameCoordinator] Error: No floor layouts available")
            return
        }

        let floorLayout = floorLayouts[0]  // Assume single floor for now

        guard let roomData = LevelLoader.getRoom(id: roomId, from: levelData) else {
            print("[GameCoordinator] Error: Room data not found for ID \(roomId)")
            return
        }

        // Convert worldCol back to gridCol for connection checking
        let gridCol = floorLayout.cols - 1 - worldCol

        // Determine door connections (uses grid coordinates)
        var hasLeftDoor = false
        var hasRightDoor = false
        var hasTopDoor = false
        var hasBottomDoor = false
        var leftDoorPosition: String? = nil
        var rightDoorPosition: String? = nil
        var topDoorPosition: String? = nil
        var bottomDoorPosition: String? = nil

        for connection in floorLayout.connections {
            // Check if this room is the "from" side of the connection
            if connection.from.row == gridRow && connection.from.col == gridCol {
                // Determine which wall based on relative positions
                // Note: Grid is horizontally mirrored, so left/right are flipped
                if connection.from.row == connection.to.row {
                    // Horizontal connection (same row)
                    if connection.from.col < connection.to.col {
                        // From has lower col index in grid, which means FROM is to the RIGHT in world
                        hasLeftDoor = true
                        leftDoorPosition = connection.doorPosition
                    } else {
                        // From has higher col index in grid, which means FROM is to the LEFT in world
                        hasRightDoor = true
                        rightDoorPosition = connection.doorPosition
                    }
                } else if connection.from.col == connection.to.col {
                    // Vertical connection (same column)
                    if connection.from.row < connection.to.row {
                        // From is above To
                        hasBottomDoor = true
                        bottomDoorPosition = connection.doorPosition
                    } else {
                        // From is below To
                        hasTopDoor = true
                        topDoorPosition = connection.doorPosition
                    }
                }
            }

            // Check if this room is the "to" side of the connection
            if connection.to.row == gridRow && connection.to.col == gridCol {
                // Determine which wall based on relative positions
                if connection.from.row == connection.to.row {
                    // Horizontal connection (same row)
                    if connection.from.col < connection.to.col {
                        // To has higher col index, which means TO is to the LEFT in world
                        hasRightDoor = true
                        rightDoorPosition = connection.doorPosition
                    } else {
                        // To has lower col index, which means TO is to the RIGHT in world
                        hasLeftDoor = true
                        leftDoorPosition = connection.doorPosition
                    }
                } else if connection.from.col == connection.to.col {
                    // Vertical connection (same column)
                    if connection.from.row < connection.to.row {
                        // To is below From
                        hasTopDoor = true
                        topDoorPosition = connection.doorPosition
                    } else {
                        // To is above From
                        hasBottomDoor = true
                        bottomDoorPosition = connection.doorPosition
                    }
                }
            }
        }

        // Generate the room (createRoomFromJSONWithConnections expects worldCol as gridCol parameter)
        let result = createRoomFromJSONWithConnections(
            roomData: roomData,
            roomIndex: roomIndex,
            gridRow: gridRow,
            gridCol: worldCol,  // Pass worldCol as gridCol (function expects world coordinates)
            hasLeftDoor: hasLeftDoor,
            hasRightDoor: hasRightDoor,
            hasTopDoor: hasTopDoor,
            hasBottomDoor: hasBottomDoor,
            leftDoorPosition: leftDoorPosition,
            rightDoorPosition: rightDoorPosition,
            topDoorPosition: topDoorPosition,
            bottomDoorPosition: bottomDoorPosition
        )

        // Store generated room and searchables
        generatedRooms[roomIndex] = result.room
        roomSearchables[roomIndex] = result.searchables

        // Add room to entities and scene
        roomEntities.append(result.room)
        entities.append(result.room)
        entities.append(contentsOf: result.searchables)

        // Add to scene if available
        if let content = sceneContent {
            content.add(result.room)
            for searchable in result.searchables {
                content.add(searchable)
            }
        }

        // Register with camera system
        cameraManagementSystem?.registerRoomEntity(result.room, at: roomIndex)

        if GameConfig.debugLogging {
            print("[GameCoordinator] ✅ Generated room \(roomIndex) (ID: \(roomId), worldCol: \(worldCol)) with \(result.searchables.count) searchables")
            if let bounds = result.room.components[RoomBoundsComponent.self] {
                print("[GameCoordinator]    Room bounds: X[\(bounds.minX)-\(bounds.maxX)] Y[\(bounds.minY)-\(bounds.maxY)]")
            }
        }
    }

    // MARK: - Lifecycle

    /// Called when world initialization is complete and physics can start
    private func onWorldReady() {
        if GameConfig.debugLogging {
            print("[GameCoordinator] 🚀 World ready - starting game loop with physics")
        }

        // Start input listening
        inputProvider.startListening()

        // Start update loop (includes physics)
        lastUpdateTime = CACurrentMediaTime()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Game loop started")
        }
    }

    /// Start the initialization process (called from ContentView after scene setup)
    func startInitialization() {
        if GameConfig.debugLogging {
            print("[GameCoordinator] Phase 4: Starting initialization sequence...")
        }

        // Mark scene as initialized (entities already registered in addEntitiesToScene)
        worldInitManager.markSceneInitialized()

        if GameConfig.debugLogging {
            print("[GameCoordinator] Initialization sequence started - awaiting world ready event")
        }
    }

    /// Stop the game loop
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil

        inputProvider.stopListening()

        if GameConfig.debugLogging {
            print("[GameCoordinator] Game stopped")
        }
    }

    /// Update all systems (called each frame)
    private func update() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Track velocity min/max and detect jumps
        updateVelocityTracking(currentTime: currentTime)

        // Update all systems
        for system in systems {
            system.update(deltaTime: deltaTime, entities: entities)
        }
    }

    /// Track velocity min/max values and reset after 5s from last jump
    private func updateVelocityTracking(currentTime: TimeInterval) {
        guard let player = player,
              let velocity = player.components[VelocityComponent.self],
              let jump = player.components[JumpComponent.self] else {
            return
        }

        // Detect jump start (transition to airborne from grounded)
        let isJumping = jump.state == .airborne
        if isJumping && !wasJumping {
            // Jump just started - reset tracking
            minVelocityX = velocity.dx
            maxVelocityX = velocity.dx
            minVelocityY = velocity.dy
            maxVelocityY = velocity.dy
            lastJumpTime = currentTime
        }
        wasJumping = isJumping

        // Reset after 5 seconds from last jump
        if currentTime - lastJumpTime > 5.0 {
            minVelocityX = velocity.dx
            maxVelocityX = velocity.dx
            minVelocityY = velocity.dy
            maxVelocityY = velocity.dy
            lastJumpTime = currentTime
        }

        // Update min/max
        minVelocityX = min(minVelocityX, velocity.dx)
        maxVelocityX = max(maxVelocityX, velocity.dx)
        minVelocityY = min(minVelocityY, velocity.dy)
        maxVelocityY = max(maxVelocityY, velocity.dy)
    }

    // MARK: - Scene Management

    /// Add all entities to a RealityKit scene
    func addEntitiesToScene(_ content: some RealityViewContentProtocol) {
        // Store scene content reference for lazy room generation
        self.sceneContent = content

        if GameConfig.debugLogging {
            print("[GameCoordinator] Phase 3: Adding entities to RealityKit scene...")
        }

        // IMPORTANT: Register entities with initialization manager BEFORE adding to scene
        if GameConfig.debugLogging {
            print("[GameCoordinator] Registering \(roomEntities.count) room entities and player with WorldInitializationManager")
        }
        if let player = player {
            worldInitManager.registerPlayerEntity(player)
        }
        worldInitManager.registerRoomEntities(roomEntities)

        // Add camera
        content.add(cameraController.cameraEntity)

        // Add all game entities
        for entity in entities {
            content.add(entity)
        }

        // Add lighting
        let light = PointLight()
        light.light.intensity = 10000
        light.position = SIMD3<Float>(16, 15, -10)
        content.add(light)

        // Add ambient light
        let ambient = PointLight()
        ambient.light.intensity = 5000
        ambient.position = SIMD3<Float>(48, 15, -10)
        content.add(ambient)

        if GameConfig.debugLogging {
            print("[GameCoordinator] Entities added to scene")
        }

        // Notify initialization manager that entities have been added (manager now monitors them)
        worldInitManager.markRoomEntitiesAdded()
        if player != nil {
            worldInitManager.markPlayerEntityAdded()
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Waiting for entities to be properly anchored before starting physics...")
        }
    }

    // MARK: - Debug

    /// Print debug information about current game state
    func printDebugInfo() {
        print("=== Game State ===")
        print("Entities: \(entities.count)")
        print("Systems: \(systems.count)")

        if let player = player,
           let position = player.components[PositionComponent.self],
           let velocity = player.components[VelocityComponent.self] {
            print("Player Position: (\(position.x), \(position.y))")
            print("Player Velocity: (\(velocity.dx), \(velocity.dy))")
        }

        print("==================")
    }

    /// Get debug information about the nearest searchable item
    func getNearestSearchableItemInfo() -> String {
        guard let player = player,
              let playerPos = player.components[PositionComponent.self] else {
            return "No Player"
        }

        var nearestDistance: Float = .infinity
        var nearestInfo: String = "No items nearby"

        for entity in entities {
            guard let searchable = entity.components[SearchableComponent.self],
                  let progress = entity.components[ProgressComponent.self],
                  let itemPos = entity.components[PositionComponent.self] else {
                continue
            }

            let dx = itemPos.x - playerPos.x
            let dy = itemPos.y - playerPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < nearestDistance {
                nearestDistance = distance
                let statusText: String
                switch searchable.state {
                case .searchable:
                    statusText = "SEARCHABLE"
                case .searching:
                    statusText = "SEARCHING"
                case .searched:
                    statusText = "SEARCHED"
                }

                let progressPercent = Int(progress.progress * 100)
                nearestInfo = String(format: "%@\n%d%%\nDistance: %.1f units", statusText, progressPercent, distance)
            }
        }

        return nearestInfo
    }

    /// Get player velocity debug information
    func getPlayerVelocityInfo() -> String {
        guard let player = player,
              let velocity = player.components[VelocityComponent.self] else {
            return "No Player"
        }

        return String(format: """
            vX: %.1f (min: %.1f, max: %.1f)
            vY: %.1f (min: %.1f, max: %.1f)
            """,
            velocity.dx, minVelocityX, maxVelocityX,
            velocity.dy, minVelocityY, maxVelocityY)
    }

    // MARK: - Room Management

    /// Called when player enters a new room
    private func onPlayerEnteredRoom(roomIndex: Int, entryPosition: SIMD3<Float>) {
        currentRoomIndex = roomIndex
        roomEntrancePosition = entryPosition

        if GameConfig.debugLogging {
            print("[GameCoordinator] Player entered room \(roomIndex) at position (\(entryPosition.x), \(entryPosition.y))")
            print("[GameCoordinator] Room entrance position captured for restart")
        }

        // LAZY LOADING: Generate this room if not already generated
        generateRoom(roomIndex)

        // Pre-generate adjacent rooms (left and right)
        generateRoom(roomIndex - 1)  // Left room
        generateRoom(roomIndex + 1)  // Right room
    }

    // MARK: - Room Restart

    /// Restart the current room by resetting player to entrance position and searchable items
    private func restartRoom() {
        guard let player = player else {
            return
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Restarting room \(currentRoomIndex)...")
        }

        // Reset player position to room entrance
        var position = player.components[PositionComponent.self] ?? PositionComponent(
            x: roomEntrancePosition.x,
            y: roomEntrancePosition.y,
            z: 0
        )
        position.x = roomEntrancePosition.x
        position.y = roomEntrancePosition.y
        position.z = roomEntrancePosition.z
        player.components.set(position)
        player.position = position.simd

        // Reset player velocity
        var velocity = player.components[VelocityComponent.self] ?? VelocityComponent(dx: 0, dy: 0)
        velocity.dx = 0
        velocity.dy = 0
        player.components.set(velocity)

        // Reset jump state to airborne (will become grounded on next physics update)
        var jump = player.components[JumpComponent.self] ?? JumpComponent()
        jump.state = .airborne
        player.components.set(jump)

        // Reset all searchable items in the current room
        for entity in entities {
            guard var searchable = entity.components[SearchableComponent.self],
                  var progress = entity.components[ProgressComponent.self] else {
                continue
            }

            // Reset searchable state
            if searchable.isSearched || searchable.state == .searching {
                searchable.state = .searchable
                searchable.timeSinceLastSearch = 0.0
                entity.components.set(searchable)

                // Reset progress
                progress.progress = 0.0
                entity.components.set(progress)

                // Remove progress bar bubble if it exists
                if let bubble = entity.children.first(where: { $0.name == "ProgressBarBubble" }) {
                    bubble.removeFromParent()
                }

                // Update visual state
                updateSearchableItemVisual(entity, state: .searchable)
            }
        }

        if GameConfig.debugLogging {
            print("[GameCoordinator] Room restarted - player at (\(position.x), \(position.y))")
        }
    }
}
