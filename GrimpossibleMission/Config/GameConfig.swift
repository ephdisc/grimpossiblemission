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

    /// Size of a single tile in world units
    static let tileSize: Float = 1.0

    /// Room width in tiles (16:9 aspect ratio)
    static let roomWidthTiles: Int = 32

    /// Room height in tiles (16:9 aspect ratio)
    static let roomHeightTiles: Int = 18

    /// Room width in world units
    static var roomWidth: Float { Float(roomWidthTiles) * tileSize }

    /// Room height in world units
    static var roomHeight: Float { Float(roomHeightTiles) * tileSize }

    /// Height of entry/doorway between rooms in tiles
    static let entryHeightTiles: Int = 6

    // MARK: - Player Configuration

    /// Player height in tiles
    static let playerHeightTiles: Int = 2

    /// Player width in tiles
    static let playerWidthTiles: Int = 1

    /// Player height in world units
    static var playerHeight: Float { Float(playerHeightTiles) * tileSize }

    /// Player width in world units
    static var playerWidth: Float { Float(playerWidthTiles) * tileSize }

    /// Player movement speed in units per second (Mario-ish feel)
    /// Tuned so player can traverse 2 tiles in a reasonable time
    static let playerMoveSpeed: Float = 8.0

    // MARK: - Physics Configuration

    /// Jump arc width in tiles (horizontal distance)
    static let jumpArcWidthTiles: Float = 100.0

    /// Jump arc height in tiles (vertical peak above start position)
    static let jumpArcHeightTiles: Float = 2.0

    /// Jump arc width in world units
    static var jumpArcWidth: Float { jumpArcWidthTiles * tileSize }

    /// Jump arc height in world units
    static var jumpArcHeight: Float { jumpArcHeightTiles * tileSize }

    /// Jump ascent speed in units per second (rise speed)
    /// DEBUG: Symmetric speed for easier debugging
    static let jumpAscentSpeed: Float = 8.0

    /// Jump descent speed in units per second (fall speed from jump)
    /// DEBUG: Symmetric speed for easier debugging (same as ascent)
    static let jumpDescentSpeed: Float = 8.0

    /// Fall speed when not jumping (walking off ledge)
    /// Calculated to match the AVERAGE vertical velocity during arc descent
    /// During descent (t=0.5 to t=1.0), velocity goes from 0 to max, so average is max/2
    /// Formula: 2 * arcHeight * averageSpeed / arcWidth
    static var fallSpeed: Float {
        let averageSpeed = (jumpAscentSpeed + jumpDescentSpeed) / 2.0
        return 2.0 * jumpArcHeight * averageSpeed / jumpArcWidth
    }

    /// Lateral movement speed while falling (reduced control)
    static let fallLateralSpeed: Float = 1.0

    /// Jump buffer time in seconds (press jump before landing)
    static let jumpBufferTime: Float = 0.1

    /// Coyote time in seconds (can jump after walking off ledge)
    static let coyoteTime: Float = 0.15

    /// Collision tolerance for snapping to surfaces
    static let collisionTolerance: Float = 0.1

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
    static let playerStartX: Float = 5.0
    static let playerStartY: Float = 10.0  // Mid-air to test gravity and collision

    // MARK: - Debug Configuration

    /// Enable debug visualization (boundaries, collision boxes, etc.)
    static let debugVisualization: Bool = true

    /// Enable jump arc visualization (yellow spheres showing jump trajectory)
    static let debugJumpArc: Bool = true

    /// Enable debug logging
    static let debugLogging: Bool = true
}
