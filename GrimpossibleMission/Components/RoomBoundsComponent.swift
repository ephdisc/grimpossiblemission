//
//  RoomBoundsComponent.swift
//  GrimpossibleMission
//
//  Component that defines the boundaries of a room.
//

import RealityKit

/// Defines the spatial boundaries of a room.
struct RoomBoundsComponent: Component {
    var minX: Float
    var maxX: Float
    var minY: Float
    var maxY: Float

    /// Room index for identification
    var roomIndex: Int

    init(minX: Float, maxX: Float, minY: Float, maxY: Float, roomIndex: Int) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.roomIndex = roomIndex
    }

    /// Check if a point is within this room's bounds
    func contains(x: Float, y: Float) -> Bool {
        return x >= minX && x <= maxX && y >= minY && y <= maxY
    }

    /// Get the center point of the room
    var center: SIMD2<Float> {
        SIMD2<Float>((minX + maxX) / 2, (minY + maxY) / 2)
    }
}
