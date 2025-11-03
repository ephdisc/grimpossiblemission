//
//  GameConfig.swift
//  GrimpossibleMission
//
//  Centralized configuration for all tuneable gameplay values.
//

import Foundation

/// Centralized configuration for all game parameters.
/// Modify these values to tune gameplay feel without changing core logic.
struct GameConfig {

    // MARK: - World Dimensions

    /// Size of a single tile in world units (halved for double resolution)
    static let tileSize: Float = 0.5

    /// Room width in tiles (16:9 aspect ratio, doubled resolution)
    static let roomWidthTiles: Int = 64

    /// Room height in tiles (16:9 aspect ratio, doubled resolution)
    static let roomHeightTiles: Int = 36

    /// Room width in world units (stays 32.0)
    static var roomWidth: Float { Float(roomWidthTiles) * tileSize }

    /// Room height in world units (stays 18.0)
    static var roomHeight: Float { Float(roomHeightTiles) * tileSize }

    /// Height of entry/doorway between rooms in tiles (doubled)
    static let entryHeightTiles: Int = 12

    // MARK: - Player Configuration

    /// Player height in tiles (doubled for same world size)
    static let playerHeightTiles: Int = 4

    /// Player width in tiles (doubled for same world size)
    static let playerWidthTiles: Int = 2

    /// Player height in world units
    static var playerHeight: Float { Float(playerHeightTiles) * tileSize }

    /// Player width in world units
    static var playerWidth: Float { Float(playerWidthTiles) * tileSize }

    /// Player movement speed in units per second (grounded only)
    /// Trajectory is locked when airborne (committed jumps)
    static let playerMoveSpeed: Float = 6.0

    // MARK: - Jump & Physics Configuration

    /// Jump velocity (upward impulse when jump is pressed)
    static let jumpVelocity: Float = 14.0

    /// Gravity acceleration (constant downward pull when airborne)
    static let gravity: Float = 28.0

    /// Maximum fall speed (terminal velocity)
    static let maxFallSpeed: Float = 30.0

    /// Jump buffer time in seconds (press jump before landing)
    static let jumpBufferTime: Float = 0.1

    /// Coyote time in seconds (can jump after walking off ledge)
    static let coyoteTime: Float = 0.15

    /// Collision tolerance for snapping to surfaces
    static let collisionTolerance: Float = 0.01

    // MARK: - Camera Configuration

    /// Camera distance from the scene (closer = only one room visible)
    static let cameraDistance: Float = 17.0

    /// Camera Z offset (negative value positions camera in front of scene)
    static var cameraZOffset: Float { -cameraDistance }

    /// Camera transition duration in seconds
    static let cameraTransitionDuration: TimeInterval = 0.2

    // MARK: - Input Configuration

    /// Deadzone for analog stick input (ignore small movements)
    static let inputDeadzone: Float = 0.2

    /// Input polling rate in seconds
    static let inputPollRate: TimeInterval = 1.0 / 60.0

    // MARK: - Searchable Item Configuration

    /// How long player must hold "up" to search an item (in seconds)
    static let searchDuration: Float = 2.0

    /// Distance required to interact with an item (in world units)
    static let interactionDistance: Float = 2.0

    // MARK: - Room Configuration

    /// Starting room index
    static let startingRoomIndex: Int = 0

    /// Player starting position in room (in tiles from room origin)
    static let playerStartX: Float = 67.0  // Room 1 (rightmost room)
    static let playerStartY: Float = 10.0  // Mid-air to test gravity and collision

    // MARK: - Debug Configuration

    /// Enable debug visualization (boundaries, collision boxes, etc.)
    static let debugVisualization: Bool = true

    /// Enable jump arc visualization (yellow spheres showing jump trajectory)
    static let debugJumpArc: Bool = true

    /// Enable debug logging
    static let debugLogging: Bool = true
}
