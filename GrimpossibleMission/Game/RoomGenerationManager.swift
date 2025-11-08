//
//  RoomGenerationManager.swift
//  GrimpossibleMission
//
//  Manages progressive, on-demand room generation to prevent frame drops.
//  Generates rooms in batches with yielding to prevent blocking the main thread.
//

import Foundation
import SwiftUI
import RealityKit
import UIKit

/// Manages lazy, progressive room generation
class RoomGenerationManager {

    // MARK: - Types

    enum RoomState {
        case notGenerated
        case generating
        case generated(Entity)
    }

    // MARK: - Properties

    private var levelData: LevelData?
    private var roomStates: [Int: RoomState] = [:] // roomIndex -> state
    private var generationQueue: [(roomIndex: Int, priority: Int)] = []
    private var isGenerating: Bool = false

    /// Scene content reference for adding entities
    private var sceneContent: (any RealityViewContentProtocol)?

    /// Callback when a room finishes generating
    var onRoomGenerated: ((Int, Entity) -> Void)?

    // MARK: - Initialization

    init() {
        if GameConfig.debugLogging {
            print("[RoomGenerationManager] Initialized")
        }
    }

    // MARK: - Setup

    /// Load level data (lightweight, just JSON parsing)
    func loadLevel(filename: String) -> Bool {
        guard let data = LevelLoader.loadLevel(filename: filename) else {
            print("[RoomGenerationManager] Failed to load level: \(filename)")
            return false
        }

        self.levelData = data

        // Initialize all rooms as not generated
        if let floorLayouts = data.floorLayouts {
            for layout in floorLayouts {
                for (row, rowData) in layout.grid.enumerated() {
                    for (col, roomId) in rowData.enumerated() {
                        if roomId != 0 {  // 0 means empty cell
                            let position = row * layout.cols + col
                            roomStates[position] = .notGenerated
                        }
                    }
                }
            }
        }

        if GameConfig.debugLogging {
            print("[RoomGenerationManager] Loaded level '\(filename)' with \(roomStates.count) rooms")
        }

        return true
    }

    /// Set scene content reference
    func setSceneContent(_ content: some RealityViewContentProtocol) {
        self.sceneContent = content
    }

    // MARK: - Room Generation

    /// Request generation of a specific room (high priority)
    func generateRoom(_ roomIndex: Int, completion: ((Entity?) -> Void)? = nil) {
        // Check if already generated
        if case .generated(let entity) = roomStates[roomIndex] {
            completion?(entity)
            return
        }

        // Check if already generating
        if case .generating = roomStates[roomIndex] {
            if GameConfig.debugLogging {
                print("[RoomGenerationManager] Room \(roomIndex) already generating")
            }
            return
        }

        // Mark as generating
        roomStates[roomIndex] = .generating

        if GameConfig.debugLogging {
            print("[RoomGenerationManager] Generating room \(roomIndex)...")
        }

        // Generate room asynchronously (yields to main thread between tile batches)
        generateRoomProgressive(roomIndex: roomIndex) { [weak self] entity in
            guard let self = self else { return }

            if let entity = entity {
                self.roomStates[roomIndex] = .generated(entity)

                // Add to scene
                self.sceneContent?.add(entity)

                if GameConfig.debugLogging {
                    print("[RoomGenerationManager] ✅ Room \(roomIndex) generated and added to scene")
                }

                self.onRoomGenerated?(roomIndex, entity)
                completion?(entity)
            } else {
                self.roomStates[roomIndex] = .notGenerated
                print("[RoomGenerationManager] ❌ Failed to generate room \(roomIndex)")
                completion?(nil)
            }
        }
    }

    /// Pre-generate adjacent rooms in the background
    func preGenerateAdjacentRooms(to currentRoomIndex: Int) {
        guard let levelData = levelData else { return }

        // Find adjacent rooms
        let adjacentIndices = findAdjacentRooms(to: currentRoomIndex, in: levelData)

        for adjacentIndex in adjacentIndices {
            // Skip if already generated or generating
            if case .notGenerated = roomStates[adjacentIndex] {
                if GameConfig.debugLogging {
                    print("[RoomGenerationManager] Pre-generating adjacent room \(adjacentIndex)")
                }
                generateRoom(adjacentIndex)
            }
        }
    }

    /// Find adjacent room indices
    private func findAdjacentRooms(to roomIndex: Int, in levelData: LevelData) -> [Int] {
        var adjacent: [Int] = []

        // Simple adjacency: previous and next room indices
        if roomIndex > 0 {
            adjacent.append(roomIndex - 1)
        }
        if roomIndex < roomStates.count - 1 {
            adjacent.append(roomIndex + 1)
        }

        return adjacent
    }

    // MARK: - Progressive Generation

    /// Generate a room progressively (yields between tile batches)
    private func generateRoomProgressive(roomIndex: Int, completion: @escaping (Entity?) -> Void) {
        guard let levelData = levelData else {
            completion(nil)
            return
        }

        // Create room entity immediately
        let roomEntity = Entity()
        roomEntity.name = "Room_\(roomIndex)_Progressive"

        // Find room data
        guard let roomData = findRoomData(for: roomIndex, in: levelData) else {
            completion(nil)
            return
        }

        // Calculate room position
        let roomMinX = Float(roomIndex) * GameConfig.roomWidth

        // Generate tiles in batches (e.g., 50 tiles at a time)
        let batchSize = 50
        var allTiles: [(x: Int, y: Int, tileId: Int)] = []

        // Collect all tile positions
        for (interiorY, row) in roomData.interior.enumerated() {
            for (interiorX, tileId) in row.enumerated() {
                if tileId != 0 { // Skip empty tiles
                    allTiles.append((x: interiorX, y: interiorY, tileId: tileId))
                }
            }
        }

        if GameConfig.debugLogging {
            print("[RoomGenerationManager] Room \(roomIndex) has \(allTiles.count) tiles to generate in batches of \(batchSize)")
        }

        // Generate tiles in batches
        var currentBatch = 0
        let totalBatches = (allTiles.count + batchSize - 1) / batchSize

        func generateNextBatch() {
            let startIdx = currentBatch * batchSize
            let endIdx = min(startIdx + batchSize, allTiles.count)

            if startIdx >= allTiles.count {
                // All batches complete
                if GameConfig.debugLogging {
                    print("[RoomGenerationManager] Room \(roomIndex) generation complete (\(allTiles.count) tiles)")
                }
                completion(roomEntity)
                return
            }

            // Generate this batch
            for idx in startIdx..<endIdx {
                let tile = allTiles[idx]

                // Create tile entity (simplified - you'll need to use your actual tile creation logic)
                let tileEntity = createTileEntity(
                    x: tile.x,
                    y: tile.y,
                    tileId: tile.tileId,
                    roomMinX: roomMinX,
                    roomData: roomData
                )

                roomEntity.addChild(tileEntity)
            }

            currentBatch += 1

            if GameConfig.debugLogging && currentBatch % 5 == 0 {
                print("[RoomGenerationManager] Room \(roomIndex) progress: \(currentBatch)/\(totalBatches) batches")
            }

            // Yield to main thread and continue with next batch
            DispatchQueue.main.async {
                generateNextBatch()
            }
        }

        // Start generation
        DispatchQueue.main.async {
            generateNextBatch()
        }
    }

    /// Create a single tile entity (helper method)
    private func createTileEntity(x: Int, y: Int, tileId: Int, roomMinX: Float, roomData: RoomData) -> Entity {
        // This is a simplified version - integrate with your existing tile creation logic
        let entity = Entity()

        // Convert interior coordinates to world coordinates
        let worldX = Float(roomData.interior[0].count - x) * GameConfig.tileSize + roomMinX
        let worldY = Float(roomData.interior.count - y) * GameConfig.tileSize

        entity.position = SIMD3<Float>(worldX, worldY, 0)

        // Add mesh and collision (simplified - use your actual implementation)
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(GameConfig.tileSize, GameConfig.tileSize, GameConfig.tileSize))
        let material = SimpleMaterial(color: .gray, isMetallic: false)
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))

        let collisionShape = ShapeResource.generateBox(size: SIMD3<Float>(GameConfig.tileSize, GameConfig.tileSize, GameConfig.tileSize))
        entity.components.set(CollisionComponent(shapes: [collisionShape]))

        return entity
    }

    /// Find room data by index
    private func findRoomData(for roomIndex: Int, in levelData: LevelData) -> RoomData? {
        guard let floorLayouts = levelData.floorLayouts else { return nil }

        for layout in floorLayouts {
            // Convert linear index back to row/col
            let row = roomIndex / layout.cols
            let col = roomIndex % layout.cols

            // Check if this position is valid in the grid
            guard row < layout.grid.count,
                  col < layout.grid[row].count else {
                continue
            }

            let roomId = layout.grid[row][col]
            if roomId != 0 {
                return LevelLoader.getRoom(id: roomId, from: levelData)
            }
        }

        return nil
    }

    // MARK: - Query

    /// Check if a room is generated
    func isRoomGenerated(_ roomIndex: Int) -> Bool {
        if case .generated = roomStates[roomIndex] {
            return true
        }
        return false
    }

    /// Get generated room entity
    func getRoomEntity(_ roomIndex: Int) -> Entity? {
        if case .generated(let entity) = roomStates[roomIndex] {
            return entity
        }
        return nil
    }
}
