//
//  HitboxComponent.swift
//  GrimpossibleMission
//
//  Component for defining custom collision bounds (separate from visual bounds).
//

import RealityKit

/// Defines custom collision bounds for an entity.
/// When present, collision detection uses this instead of the full entity bounds.
struct HitboxComponent: Component {
    /// Width of the hitbox
    var width: Float

    /// Height of the hitbox
    var height: Float

    /// Vertical offset from entity center (positive = up, negative = down)
    /// For example, if player is 2.0 tall and hitbox is 1.0 tall:
    /// - offsetY = -0.5 places hitbox at bottom tile
    /// - offsetY = 0.0 centers hitbox on player
    /// - offsetY = 0.5 places hitbox at top tile
    var offsetY: Float

    /// Horizontal offset from entity center (positive = right, negative = left)
    var offsetX: Float

    init(width: Float, height: Float, offsetX: Float = 0, offsetY: Float = 0) {
        self.width = width
        self.height = height
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    /// Get the hitbox bounds in world space given an entity position
    func getBounds(entityPosition: SIMD3<Float>) -> (minX: Float, maxX: Float, minY: Float, maxY: Float) {
        let centerX = entityPosition.x + offsetX
        let centerY = entityPosition.y + offsetY

        let halfWidth = width / 2.0
        let halfHeight = height / 2.0

        return (
            minX: centerX - halfWidth,
            maxX: centerX + halfWidth,
            minY: centerY - halfHeight,
            maxY: centerY + halfHeight
        )
    }
}
