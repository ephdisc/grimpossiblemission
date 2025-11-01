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
///   - entryHeight: Height of entry/doorway at edges (tiles will not be created in this area)
/// - Returns: Room entity containing all tiles and room bounds component
func createRoomEntity(
    roomIndex: Int,
    hasLeftWall: Bool = true,
    hasRightWall: Bool = true,
    entryHeight: Int = 0
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
            if y < entryHeight {
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
            if y < entryHeight {
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

/// Creates two side-by-side rooms for the POC.
/// - Returns: Array containing Room 0 and Room 1 entities
func createPOCRooms() -> [Entity] {
    // Room 0: Has right wall with 3-tile entry at bottom
    let room0 = createRoomEntity(
        roomIndex: 0,
        hasLeftWall: true,
        hasRightWall: false, // Open right side for connection
        entryHeight: GameConfig.entryHeightTiles
    )

    // Room 1: Has left wall with 3-tile entry at bottom
    let room1 = createRoomEntity(
        roomIndex: 1,
        hasLeftWall: false, // Open left side for connection
        hasRightWall: true,
        entryHeight: GameConfig.entryHeightTiles
    )

    return [room0, room1]
}
