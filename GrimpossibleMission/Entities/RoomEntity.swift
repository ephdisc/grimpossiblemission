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

/// Creates a room entity from JSON room data with connection-based doors.
/// - Parameters:
///   - roomData: Room data loaded from JSON
///   - roomIndex: Index of the room in the level layout
///   - gridRow: Row in the grid layout
///   - gridCol: Column in the grid layout
///   - hasLeftDoor: Whether this room has a door on the left wall
///   - hasRightDoor: Whether this room has a door on the right wall
///   - hasTopDoor: Whether this room has a door on the top wall
///   - hasBottomDoor: Whether this room has a door on the bottom wall
///   - leftDoorPosition: Position of door on left wall ("top" or "bot"), or nil
///   - rightDoorPosition: Position of door on right wall ("top" or "bot"), or nil
///   - topDoorPosition: Position of door on top wall ("left" or "right"), or nil
///   - bottomDoorPosition: Position of door on bottom wall ("left" or "right"), or nil
/// - Returns: Tuple containing (room entity, array of searchable item entities)
func createRoomFromJSONWithConnections(
    roomData: RoomData,
    roomIndex: Int,
    gridRow: Int,
    gridCol: Int,
    hasLeftDoor: Bool,
    hasRightDoor: Bool,
    hasTopDoor: Bool,
    hasBottomDoor: Bool,
    leftDoorPosition: String? = nil,
    rightDoorPosition: String? = nil,
    topDoorPosition: String? = nil,
    bottomDoorPosition: String? = nil
) -> (room: Entity, searchables: [Entity]) {
    let room = Entity()
    room.name = "Room_\(roomData.id)_r\(gridRow)c\(gridCol)"

    // Collect searchable items separately
    var searchableItems: [Entity] = []

    // Calculate room bounds based on grid position
    // For now, use horizontal layout (col determines X position)
    // In future, could support vertical stacking (row determines Y position)
    let minX = Float(gridCol) * GameConfig.roomWidth
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

    // Determine doorway heights (use standard player height + 2 tiles)
    let doorwayHeight = GameConfig.playerHeightTiles + 2

    // Calculate door Y ranges for vertical walls (left/right)
    let doorYStart: (String?) -> Int = { position in
        switch position {
        case "top":
            return roomData.height - 1 - doorwayHeight  // Top of wall
        case "bot", _:  // Default to bottom for compatibility
            return 1  // Bottom of wall (above floor)
        }
    }

    let leftDoorYStart = hasLeftDoor ? doorYStart(leftDoorPosition) : -1
    let rightDoorYStart = hasRightDoor ? doorYStart(rightDoorPosition) : -1

    // Get theme colors
    let wallColor = roomData.theme?.wallColor.flatMap { UIColor.from(string: $0) } ?? .darkGray
    let floorColor = roomData.theme?.floorColor.flatMap { UIColor.from(string: $0) } ?? .gray
    let ceilingColor = roomData.theme?.ceilingColor.flatMap { UIColor.from(string: $0) } ?? .gray

    // Create floor tiles (bottom row)
    for x in 0..<roomData.width {
        // Skip floor tiles where bottom door exists
        if hasBottomDoor {
            // For now, skip creating floor door tiles
            // TODO: Implement bottom doors properly
        }

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
        // Skip ceiling tiles where top door exists
        if hasTopDoor {
            // For now, skip creating ceiling door tiles
            // TODO: Implement top doors properly
        }

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
        // Skip door area if left door exists
        if hasLeftDoor && y >= leftDoorYStart && y < (leftDoorYStart + doorwayHeight) {
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
        // Skip door area if right door exists
        if hasRightDoor && y >= rightDoorYStart && y < (rightDoorYStart + doorwayHeight) {
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
    let maxInteriorRows = roomData.height - 2
    let maxInteriorCols = roomData.width - 2

    for (interiorY, row) in roomData.interior.enumerated() {
        if interiorY >= maxInteriorRows {
            break
        }

        for (interiorX, tileId) in row.enumerated() {
            if interiorX >= maxInteriorCols {
                break
            }

            // Skip empty tiles
            guard let tileType = TileType(rawValue: tileId),
                  tileType != .empty else {
                continue
            }

            // Convert interior coordinates to world coordinates
            let worldX = Float(row.count - interiorX) * GameConfig.tileSize + minX
            let worldY = Float(roomData.interior.count - interiorY) * GameConfig.tileSize

            // Handle searchable items separately
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

    if GameConfig.debugLogging {
        print("[RoomEntity] Created room \(roomData.id) at grid(\(gridRow),\(gridCol)) with doors: L=\(hasLeftDoor) R=\(hasRightDoor) T=\(hasTopDoor) B=\(hasBottomDoor)")
    }

    return (room: room, searchables: searchableItems)
}

/// Creates rooms from a loaded level and layout.
/// - Parameter levelData: Level data loaded from JSON
/// - Returns: Tuple containing (array of room entities, array of all searchable items)
func createRoomsFromLevel(levelData: LevelData) -> (rooms: [Entity], searchables: [Entity]) {
    // Use floor_layouts if available, otherwise fall back to old layout system
    if let floorLayouts = levelData.floorLayouts, !floorLayouts.isEmpty {
        // Use new grid-based layout system
        return createRoomsFromFloorLayouts(floorLayouts: floorLayouts, levelData: levelData)
    } else {
        // Use old linear layout system
        return createRoomsFromLinearLayout(levelData: levelData)
    }
}

/// Creates rooms from the old linear layout system (backwards compatibility)
/// - Parameter levelData: Level data loaded from JSON
/// - Returns: Tuple containing (array of room entities, array of all searchable items)
private func createRoomsFromLinearLayout(levelData: LevelData) -> (rooms: [Entity], searchables: [Entity]) {
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
        print("[RoomEntity] Created \(rooms.count) rooms with \(allSearchables.count) searchable items from linear layout")
    }

    return (rooms: rooms, searchables: allSearchables)
}

/// Creates rooms from the new grid-based floor layout system
/// - Parameters:
///   - floorLayouts: Array of floor layouts from JSON
///   - levelData: Level data containing room definitions
/// - Returns: Tuple containing (array of room entities, array of all searchable items)
private func createRoomsFromFloorLayouts(floorLayouts: [FloorLayout], levelData: LevelData) -> (rooms: [Entity], searchables: [Entity]) {
    var rooms: [Entity] = []
    var allSearchables: [Entity] = []
    var roomIndexCounter = 0

    // Process each floor layout (typically just one, but support multiple)
    for (floorIndex, floorLayout) in floorLayouts.enumerated() {
        if GameConfig.debugLogging {
            print("[RoomEntity] Processing floor layout \(floorIndex): \(floorLayout.rows)x\(floorLayout.cols) grid")
        }

        // Build a map of grid positions to their connections
        var connectionMap: [String: [(direction: String, doorPosition: String)]] = [:]

        for connection in floorLayout.connections {
            let fromKey = "\(connection.from.row),\(connection.from.col)"
            let toKey = "\(connection.to.row),\(connection.to.col)"

            // Determine direction of connection
            // Note: Grid is horizontally mirrored, so left/right are flipped
            if connection.from.row == connection.to.row {
                // Horizontal connection (same row)
                if connection.from.col < connection.to.col {
                    // From has lower col index in grid, which means FROM is to the RIGHT in world
                    connectionMap[fromKey, default: []].append((direction: "left", doorPosition: connection.doorPosition))
                    connectionMap[toKey, default: []].append((direction: "right", doorPosition: connection.doorPosition))
                } else {
                    // From has higher col index in grid, which means FROM is to the LEFT in world
                    connectionMap[fromKey, default: []].append((direction: "right", doorPosition: connection.doorPosition))
                    connectionMap[toKey, default: []].append((direction: "left", doorPosition: connection.doorPosition))
                }
            } else if connection.from.col == connection.to.col {
                // Vertical connection (same column)
                if connection.from.row < connection.to.row {
                    // From is above To
                    connectionMap[fromKey, default: []].append((direction: "bottom", doorPosition: connection.doorPosition))
                    connectionMap[toKey, default: []].append((direction: "top", doorPosition: connection.doorPosition))
                } else {
                    // From is below To
                    connectionMap[fromKey, default: []].append((direction: "top", doorPosition: connection.doorPosition))
                    connectionMap[toKey, default: []].append((direction: "bottom", doorPosition: connection.doorPosition))
                }
            }
        }

        // Create rooms for each grid position
        for row in 0..<floorLayout.rows {
            for col in 0..<floorLayout.cols {
                guard row < floorLayout.grid.count,
                      col < floorLayout.grid[row].count else {
                    continue
                }

                let roomId = floorLayout.grid[row][col]

                // Find the room data
                guard let roomData = LevelLoader.getRoom(id: roomId, from: levelData) else {
                    print("[RoomEntity] Warning: Could not find room with ID \(roomId) at grid position (\(row), \(col))")
                    continue
                }

                // Get connections for this grid position
                let gridKey = "\(row),\(col)"
                let connections = connectionMap[gridKey] ?? []

                // Determine which walls have doorways and their positions
                let hasLeftDoor = connections.contains { $0.direction == "left" }
                let hasRightDoor = connections.contains { $0.direction == "right" }
                let hasTopDoor = connections.contains { $0.direction == "top" }
                let hasBottomDoor = connections.contains { $0.direction == "bottom" }

                // Extract door positions
                let leftDoorPosition = connections.first { $0.direction == "left" }?.doorPosition
                let rightDoorPosition = connections.first { $0.direction == "right" }?.doorPosition
                let topDoorPosition = connections.first { $0.direction == "top" }?.doorPosition
                let bottomDoorPosition = connections.first { $0.direction == "bottom" }?.doorPosition

                // Create the room with connections
                // Note: Grid columns are mirrored horizontally to match level editor
                // grid[row][0] = rightmost room in world, grid[row][last] = leftmost room in world
                // This matches how room interiors are mirrored
                let worldCol = floorLayout.cols - 1 - col
                let result = createRoomFromJSONWithConnections(
                    roomData: roomData,
                    roomIndex: roomIndexCounter,
                    gridRow: row,
                    gridCol: worldCol,
                    hasLeftDoor: hasLeftDoor,
                    hasRightDoor: hasRightDoor,
                    hasTopDoor: hasTopDoor,
                    hasBottomDoor: hasBottomDoor,
                    leftDoorPosition: leftDoorPosition,
                    rightDoorPosition: rightDoorPosition,
                    topDoorPosition: topDoorPosition,
                    bottomDoorPosition: bottomDoorPosition
                )

                rooms.append(result.room)
                allSearchables.append(contentsOf: result.searchables)
                roomIndexCounter += 1
            }
        }
    }

    if GameConfig.debugLogging {
        print("[RoomEntity] Created \(rooms.count) rooms with \(allSearchables.count) searchable items from floor layouts")
    }

    return (rooms: rooms, searchables: allSearchables)
}

// MARK: - Spawn Point Detection

/// Find the spawn point in the level data
/// - Parameter levelData: Level data to search
/// - Returns: Tuple of (world position, room index) or nil if no spawn found
func findSpawnPosition(levelData: LevelData) -> (position: SIMD3<Float>, roomIndex: Int)? {
    // Use floor_layouts if available, otherwise fall back to old layout system
    if let floorLayouts = levelData.floorLayouts, !floorLayouts.isEmpty {
        return findSpawnInFloorLayouts(floorLayouts: floorLayouts, levelData: levelData)
    } else {
        return findSpawnInLinearLayout(levelData: levelData)
    }
}

/// Find spawn in the old linear layout system
private func findSpawnInLinearLayout(levelData: LevelData) -> (position: SIMD3<Float>, roomIndex: Int)? {
    let sortedLayout = levelData.layout.sorted { $0.position < $1.position }

    for layoutEntry in sortedLayout {
        guard let roomData = LevelLoader.getRoom(id: layoutEntry.roomId, from: levelData) else {
            continue
        }

        if let spawnPos = findSpawnInRoom(roomData: roomData, roomIndex: layoutEntry.position) {
            return (position: spawnPos, roomIndex: layoutEntry.position)
        }
    }

    return nil
}

/// Find spawn in the new grid-based floor layout system
private func findSpawnInFloorLayouts(floorLayouts: [FloorLayout], levelData: LevelData) -> (position: SIMD3<Float>, roomIndex: Int)? {
    var roomIndexCounter = 0

    for floorLayout in floorLayouts {
        for row in 0..<floorLayout.rows {
            for col in 0..<floorLayout.cols {
                guard row < floorLayout.grid.count,
                      col < floorLayout.grid[row].count else {
                    continue
                }

                let roomId = floorLayout.grid[row][col]
                guard let roomData = LevelLoader.getRoom(id: roomId, from: levelData) else {
                    continue
                }

                // Grid columns are mirrored, so convert to world column
                let worldCol = floorLayout.cols - 1 - col

                if let spawnPos = findSpawnInRoom(roomData: roomData, roomIndex: roomIndexCounter, gridCol: worldCol) {
                    return (position: spawnPos, roomIndex: roomIndexCounter)
                }

                roomIndexCounter += 1
            }
        }
    }

    return nil
}

/// Find spawn tile in a specific room and convert to world coordinates
private func findSpawnInRoom(roomData: RoomData, roomIndex: Int, gridCol: Int? = nil) -> SIMD3<Float>? {
    let maxInteriorRows = roomData.height - 2
    let maxInteriorCols = roomData.width - 2

    // Calculate room's world X position
    let roomMinX: Float
    if let col = gridCol {
        // Grid-based layout
        roomMinX = Float(col) * GameConfig.roomWidth
    } else {
        // Linear layout
        roomMinX = Float(roomIndex) * GameConfig.roomWidth
    }

    // Scan interior for spawn tile
    for (interiorY, row) in roomData.interior.enumerated() {
        if interiorY >= maxInteriorRows {
            break
        }

        for (interiorX, tileId) in row.enumerated() {
            if interiorX >= maxInteriorCols {
                break
            }

            // Check if this is a spawn tile
            guard let tileType = TileType(rawValue: tileId),
                  tileType == .spawn else {
                continue
            }

            // Convert interior coordinates to world coordinates
            // X is flipped: interior[y][0] maps to RIGHT side, interior[y][last] maps to LEFT side
            // Y is flipped: interior[0] maps to top of interior, interior[last] maps to bottom
            let worldX = Float(row.count - interiorX) * GameConfig.tileSize + roomMinX
            let worldY = Float(roomData.interior.count - interiorY) * GameConfig.tileSize

            // Return position at center of tile, adjusted for player pivot
            return SIMD3<Float>(
                worldX + GameConfig.tileSize / 2.0,
                worldY + GameConfig.tileSize / 2.0 + GameConfig.playerHeight / 2.0,
                0
            )
        }
    }

    return nil
}
