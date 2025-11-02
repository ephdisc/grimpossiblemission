//
//  RoomEntity.swift
//  GrimpossibleMission
//
//  Factory functions for creating room entities with tiles.
//

import Foundation
import RealityKit
import UIKit

/// Creates a room entity with floor, ceiling, and wall tiles.
/// - Parameters:
///   - roomIndex: Index of the room (0 for first room, 1 for second, etc.)
///   - hasLeftWall: Whether to create left wall tiles
///   - hasRightWall: Whether to create right wall tiles
///   - leftEntryHeight: Height of entry/doorway on left wall (tiles will not be created in this area)
///   - rightEntryHeight: Height of entry/doorway on right wall (tiles will not be created in this area)
/// - Returns: Room entity containing all tiles and room bounds component
func createRoomEntity(
    roomIndex: Int,
    hasLeftWall: Bool = true,
    hasRightWall: Bool = true,
    leftEntryHeight: Int = 0,
    rightEntryHeight: Int = 0
) -> Entity {
    let room = Entity()
    room.name = "Room_\(roomIndex)"

    // Calculate room bounds
    let minX = Float(roomIndex) * GameConfig.roomWidth
    let maxX = minX + GameConfig.roomWidth
    let minY: Float = 0
    let maxY = GameConfig.roomHeight

    // Add room bounds component
    let roomBounds = RoomBoundsComponent(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        roomIndex: roomIndex
    )
    room.components.set(roomBounds)

    // Create floor tiles (bottom row)
    for x in 0..<GameConfig.roomWidthTiles {
        let tile = createTileEntity(
            x: Float(x) * GameConfig.tileSize + minX,
            y: 0,
            color: .gray,
            solidType: .floor
        )
        room.addChild(tile)
    }

    // Create ceiling tiles (top row)
    for x in 0..<GameConfig.roomWidthTiles {
        let tile = createTileEntity(
            x: Float(x) * GameConfig.tileSize + minX,
            y: Float(GameConfig.roomHeightTiles - 1) * GameConfig.tileSize,
            color: .gray,
            solidType: .ceiling
        )
        room.addChild(tile)
    }

    // Create left wall tiles
    if hasLeftWall {
        for y in 1..<(GameConfig.roomHeightTiles - 1) {
            // Skip entry area if specified
            if y < leftEntryHeight {
                continue
            }

            let tile = createTileEntity(
                x: minX,
                y: Float(y) * GameConfig.tileSize,
                color: .darkGray,
                solidType: .wall
            )
            room.addChild(tile)
        }
    }

    // Create right wall tiles
    if hasRightWall {
        for y in 1..<(GameConfig.roomHeightTiles - 1) {
            // Skip entry area if specified
            if y < rightEntryHeight {
                continue
            }

            let tile = createTileEntity(
                x: maxX - GameConfig.tileSize,
                y: Float(y) * GameConfig.tileSize,
                color: .darkGray,
                solidType: .wall
            )
            room.addChild(tile)
        }
    }

    // Add some platform tiles for visual interest
    addPlatformTiles(to: room, roomIndex: roomIndex, minX: minX)

    // Add searchable items
    addSearchableItems(to: room, roomIndex: roomIndex, minX: minX)

    return room
}

/// Creates a single tile entity.
/// - Parameters:
///   - x: X position in world units
///   - y: Y position in world units
///   - color: Color of the tile
///   - solidType: Type of solid for collision response
/// - Returns: Tile entity with solid component
private func createTileEntity(x: Float, y: Float, color: UIColor, solidType: SolidType) -> Entity {
    let tile = Entity()

    let tileSize = SIMD3<Float>(
        GameConfig.tileSize,
        GameConfig.tileSize,
        GameConfig.tileSize
    )

    let mesh = MeshResource.generateBox(size: tileSize)
    let material = SimpleMaterial(color: color, isMetallic: false)
    let modelComponent = ModelComponent(mesh: mesh, materials: [material])

    // Position tile (tiles are centered on their position)
    tile.position = SIMD3<Float>(
        x + GameConfig.tileSize / 2.0,
        y + GameConfig.tileSize / 2.0,
        0
    )

    tile.components.set(modelComponent)

    // Add collision
    let collisionShape = ShapeResource.generateBox(size: tileSize)
    let collisionComponent = CollisionComponent(shapes: [collisionShape])
    tile.components.set(collisionComponent)

    // Add solid component for physics collision
    var solidComponent = SolidComponent()
    solidComponent.type = solidType
    solidComponent.bounds = tileSize
    tile.components.set(solidComponent)

    return tile
}

/// Adds platform tiles to a room for visual interest.
/// - Parameters:
///   - room: Room entity to add platforms to
///   - roomIndex: Index of the room
///   - minX: Minimum X coordinate of the room
private func addPlatformTiles(to room: Entity, roomIndex: Int, minX: Float) {
    // Room 0: Classic platformer layout with multiple levels
    if roomIndex == 0 {
        // Bottom left platform (2 tiles high, 8 tiles wide)
        for x in 2...9 {
            for y in 4...5 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBrown,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Middle center platform (2 tiles high, 10 tiles wide)
        for x in 20...29 {
            for y in 12...13 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBrown,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Top right platform (2 tiles high, 8 tiles wide)
        for x in 45...52 {
            for y in 24...25 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBrown,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Small stepping platform (2 tiles high, 4 tiles wide)
        for x in 38...41 {
            for y in 18...19 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBrown,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }
    }

    // Room 1: Staircase ascending layout
    if roomIndex == 1 {
        // First step (3 tiles high, 6 tiles wide)
        for x in 5...10 {
            for y in 4...6 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemRed,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Second step (3 tiles high, 6 tiles wide)
        for x in 15...20 {
            for y in 10...12 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemRed,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Third step (3 tiles high, 6 tiles wide)
        for x in 28...33 {
            for y in 16...18 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemRed,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Top platform (3 tiles high, 8 tiles wide)
        for x in 42...49 {
            for y in 24...26 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemRed,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }
    }

    // Room 2: Gap-jumping challenge layout
    if roomIndex == 2 {
        // Left platform (4 tiles high, 7 tiles wide)
        for x in 3...9 {
            for y in 8...11 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBlue,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Middle-left platform (4 tiles high, 5 tiles wide)
        for x in 18...22 {
            for y in 14...17 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBlue,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Middle-right platform (4 tiles high, 5 tiles wide)
        for x in 35...39 {
            for y in 14...17 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBlue,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }

        // Right platform (4 tiles high, 7 tiles wide)
        for x in 52...58 {
            for y in 8...11 {
                let tile = createTileEntity(
                    x: Float(x) * GameConfig.tileSize + minX,
                    y: Float(y) * GameConfig.tileSize,
                    color: .systemBlue,
                    solidType: .block
                )
                room.addChild(tile)
            }
        }
    }
}

/// Adds searchable items to a room.
/// - Parameters:
///   - room: Room entity to add items to
///   - roomIndex: Index of the room
///   - minX: Minimum X coordinate of the room
private func addSearchableItems(to room: Entity, roomIndex: Int, minX: Float) {
    // Room 0: Add items on the floor and on the platform
    if roomIndex == 0 {
        // Item on floor at x=8
        let item1 = createSearchableItem(x: 8 * GameConfig.tileSize + minX, y: 1 * GameConfig.tileSize)
        room.addChild(item1)

        // Item on platform at y=7 (on top of platform at y=6)
        let item2 = createSearchableItem(x: 12 * GameConfig.tileSize + minX, y: 7 * GameConfig.tileSize)
        room.addChild(item2)
    }

    // Room 1: Add items on platforms
    if roomIndex == 1 {
        // Item on first platform at y=9 (on top of platform at y=8)
        let item3 = createSearchableItem(x: 7 * GameConfig.tileSize + minX, y: 9 * GameConfig.tileSize)
        room.addChild(item3)

        // Item on second platform at y=13 (on top of platform at y=12)
        let item4 = createSearchableItem(x: 22 * GameConfig.tileSize + minX, y: 13 * GameConfig.tileSize)
        room.addChild(item4)
    }
}

/// Creates three side-by-side rooms for the POC.
/// - Returns: Array containing Room 0, Room 1, and Room 2 entities
func createPOCRooms() -> [Entity] {
    // Room 0: Full left wall, right wall with doorway at bottom
    let room0 = createRoomEntity(
        roomIndex: 0,
        hasLeftWall: true,
        hasRightWall: true,
        leftEntryHeight: 0, // No doorway on left
        rightEntryHeight: GameConfig.entryHeightTiles // doorway on right
    )

    // Room 1: Left wall with doorway at bottom, right wall with doorway
    let room1 = createRoomEntity(
        roomIndex: 1,
        hasLeftWall: true,
        hasRightWall: true,
        leftEntryHeight: GameConfig.entryHeightTiles, // doorway on left
        rightEntryHeight: GameConfig.entryHeightTiles // doorway on right
    )

    // Room 2: Left wall with doorway at bottom, full right wall
    let room2 = createRoomEntity(
        roomIndex: 2,
        hasLeftWall: true,
        hasRightWall: true,
        leftEntryHeight: GameConfig.entryHeightTiles, // doorway on left
        rightEntryHeight: 0 // No doorway on right
    )

    return [room0, room1, room2]
}

// MARK: - JSON-based Room Creation

/// Creates a room entity from JSON room data.
/// - Parameters:
///   - roomData: Room data loaded from JSON
///   - roomIndex: Index of the room in the level layout (0 for first room, 1 for second, etc.)
/// - Returns: Tuple containing (room entity, array of searchable item entities)
func createRoomFromJSON(roomData: RoomData, roomIndex: Int) -> (room: Entity, searchables: [Entity]) {
    let room = Entity()
    room.name = "Room_\(roomData.id)"

    // Collect searchable items separately (not added as room children)
    var searchableItems: [Entity] = []

    // Calculate room bounds
    let minX = Float(roomIndex) * GameConfig.roomWidth
    let maxX = minX + GameConfig.roomWidth
    let minY: Float = 0
    let maxY = GameConfig.roomHeight

    // Add room bounds component
    let roomBounds = RoomBoundsComponent(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        roomIndex: roomIndex
    )
    room.components.set(roomBounds)

    // Determine doorway heights from exits
    let leftEntryHeight: Int
    if let leftExit = roomData.exits.left, leftExit.type == "doorway" {
        leftEntryHeight = leftExit.heightTiles ?? (GameConfig.playerHeightTiles + 2)
    } else {
        leftEntryHeight = 0
    }

    let rightEntryHeight: Int
    if let rightExit = roomData.exits.right, rightExit.type == "doorway" {
        rightEntryHeight = rightExit.heightTiles ?? (GameConfig.playerHeightTiles + 2)
    } else {
        rightEntryHeight = 0
    }

    // Get theme colors
    let wallColor = roomData.theme?.wallColor.flatMap { UIColor.from(string: $0) } ?? .darkGray
    let floorColor = roomData.theme?.floorColor.flatMap { UIColor.from(string: $0) } ?? .gray
    let ceilingColor = roomData.theme?.ceilingColor.flatMap { UIColor.from(string: $0) } ?? .gray

    // Create floor tiles (bottom row)
    for x in 0..<roomData.width {
        let tile = createTileEntity(
            x: Float(x) * GameConfig.tileSize + minX,
            y: 0,
            color: floorColor,
            solidType: .floor
        )
        room.addChild(tile)
    }

    // Create ceiling tiles (top row)
    for x in 0..<roomData.width {
        let tile = createTileEntity(
            x: Float(x) * GameConfig.tileSize + minX,
            y: Float(roomData.height - 1) * GameConfig.tileSize,
            color: ceilingColor,
            solidType: .ceiling
        )
        room.addChild(tile)
    }

    // Create left wall tiles
    for y in 1..<(roomData.height - 1) {
        // Skip entry area if specified
        if y < leftEntryHeight {
            continue
        }

        let tile = createTileEntity(
            x: minX,
            y: Float(y) * GameConfig.tileSize,
            color: wallColor,
            solidType: .wall
        )
        room.addChild(tile)
    }

    // Create right wall tiles
    for y in 1..<(roomData.height - 1) {
        // Skip entry area if specified
        if y < rightEntryHeight {
            continue
        }

        let tile = createTileEntity(
            x: maxX - GameConfig.tileSize,
            y: Float(y) * GameConfig.tileSize,
            color: wallColor,
            solidType: .wall
        )
        room.addChild(tile)
    }

    // Create interior tiles from JSON data
    // Interior array is (height - 2) rows by (width - 2) columns
    // Coordinate system: interior[0] is TOP row (visually), interior[last] is BOTTOM row
    let maxInteriorRows = roomData.height - 2
    let maxInteriorCols = roomData.width - 2

    for (interiorY, row) in roomData.interior.enumerated() {
        // Stop if we exceed expected row count
        if interiorY >= maxInteriorRows {
            if GameConfig.debugLogging {
                print("[RoomEntity] Warning: Room \(roomData.id) has more interior rows than expected (stopping at row \(interiorY))")
            }
            break
        }

        for (interiorX, tileId) in row.enumerated() {
            // Stop if we exceed expected column count
            if interiorX >= maxInteriorCols {
                if GameConfig.debugLogging {
                    print("[RoomEntity] Warning: Room \(roomData.id) row \(interiorY) has more columns than expected (stopping at column \(interiorX))")
                }
                break
            }

            // Skip empty tiles
            guard let tileType = TileType(rawValue: tileId),
                  tileType != .empty else {
                continue
            }

            // Convert interior coordinates to world coordinates
            // X is flipped: interior[y][0] maps to RIGHT side, interior[y][last] maps to LEFT side
            // Y is flipped: interior[0] maps to top of interior, interior[last] maps to bottom
            let worldX = Float(row.count - interiorX) * GameConfig.tileSize + minX
            let worldY = Float(roomData.interior.count - interiorY) * GameConfig.tileSize

            // Handle searchable items separately (add to searchables array, not room children)
            if tileType == .searchable {
                let item = createSearchableItem(x: worldX, y: worldY)
                searchableItems.append(item)
            } else if let solidType = tileType.solidType {
                // Create solid tile
                let tile = createTileEntity(
                    x: worldX,
                    y: worldY,
                    color: tileType.defaultColor,
                    solidType: solidType
                )
                room.addChild(tile)
            }
        }
    }

    return (room: room, searchables: searchableItems)
}

/// Creates rooms from a loaded level and layout.
/// - Parameter levelData: Level data loaded from JSON
/// - Returns: Tuple containing (array of room entities, array of all searchable items)
func createRoomsFromLevel(levelData: LevelData) -> (rooms: [Entity], searchables: [Entity]) {
    var rooms: [Entity] = []
    var allSearchables: [Entity] = []

    // Sort layout by position
    let sortedLayout = levelData.layout.sorted { $0.position < $1.position }

    for layoutEntry in sortedLayout {
        // Find the room data
        guard let roomData = LevelLoader.getRoom(id: layoutEntry.roomId, from: levelData) else {
            print("[RoomEntity] Warning: Could not find room with ID \(layoutEntry.roomId)")
            continue
        }

        // Create the room entity and collect searchable items
        let result = createRoomFromJSON(roomData: roomData, roomIndex: layoutEntry.position)
        rooms.append(result.room)
        allSearchables.append(contentsOf: result.searchables)
    }

    if GameConfig.debugLogging {
        print("[RoomEntity] Created \(rooms.count) rooms with \(allSearchables.count) searchable items from level data")
    }

    return (rooms: rooms, searchables: allSearchables)
}
