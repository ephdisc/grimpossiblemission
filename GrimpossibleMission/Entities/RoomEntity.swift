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
            x: Float(x) + minX,
            y: 0,
            color: .gray
        )
        room.addChild(tile)
    }

    // Create ceiling tiles (top row)
    for x in 0..<GameConfig.roomWidthTiles {
        let tile = createTileEntity(
            x: Float(x) + minX,
            y: Float(GameConfig.roomHeightTiles - 1),
            color: .gray
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
                y: Float(y),
                color: .darkGray
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
                y: Float(y),
                color: .darkGray
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
/// - Returns: Tile entity
private func createTileEntity(x: Float, y: Float, color: UIColor) -> Entity {
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

    return tile
}

/// Adds platform tiles to a room for visual interest.
/// - Parameters:
///   - room: Room entity to add platforms to
///   - roomIndex: Index of the room
///   - minX: Minimum X coordinate of the room
private func addPlatformTiles(to room: Entity, roomIndex: Int, minX: Float) {
    // Room 0: Add a platform at mid-height
    if roomIndex == 0 {
        // Platform at y=6, spanning tiles 10-15
        for x in 10...15 {
            let tile = createTileEntity(
                x: Float(x) + minX,
                y: 6,
                color: .systemGreen
            )
            room.addChild(tile)
        }
    }

    // Room 1: Add a different platform layout
    if roomIndex == 1 {
        // Platform at y=8, spanning tiles 5-10
        for x in 5...10 {
            let tile = createTileEntity(
                x: Float(x) + minX,
                y: 8,
                color: .systemGreen
            )
            room.addChild(tile)
        }

        // Platform at y=12, spanning tiles 20-25
        for x in 20...25 {
            let tile = createTileEntity(
                x: Float(x) + minX,
                y: 12,
                color: .systemGreen
            )
            room.addChild(tile)
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
        let item1 = createSearchableItem(x: 8 + minX, y: 1)
        room.addChild(item1)

        // Item on platform at y=7 (on top of platform at y=6)
        let item2 = createSearchableItem(x: 12 + minX, y: 7)
        room.addChild(item2)
    }

    // Room 1: Add items on platforms
    if roomIndex == 1 {
        // Item on first platform at y=9 (on top of platform at y=8)
        let item3 = createSearchableItem(x: 7 + minX, y: 9)
        room.addChild(item3)

        // Item on second platform at y=13 (on top of platform at y=12)
        let item4 = createSearchableItem(x: 22 + minX, y: 13)
        room.addChild(item4)
    }
}

/// Creates two side-by-side rooms for the POC.
/// - Returns: Array containing Room 0 and Room 1 entities
func createPOCRooms() -> [Entity] {
    // Room 0: Full left wall, right wall with 3-tile doorway at bottom
    let room0 = createRoomEntity(
        roomIndex: 0,
        hasLeftWall: true,
        hasRightWall: true,
        leftEntryHeight: 0, // No doorway on left
        rightEntryHeight: GameConfig.entryHeightTiles // 3-tile doorway on right
    )

    // Room 1: Left wall with 3-tile doorway at bottom, full right wall
    let room1 = createRoomEntity(
        roomIndex: 1,
        hasLeftWall: true,
        hasRightWall: true,
        leftEntryHeight: GameConfig.entryHeightTiles, // 3-tile doorway on left
        rightEntryHeight: 0 // No doorway on right
    )

    return [room0, room1]
}
