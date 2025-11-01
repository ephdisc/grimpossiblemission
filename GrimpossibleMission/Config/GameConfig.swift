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
    static let entryHeightTiles: Int = 3

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
    static let playerMoveSpeed: Float = 6.0

    /// Jump height in tiles (player can jump 3 tiles high)
    static let jumpHeightTiles: Int = 3

    /// Jump distance in tiles (player can jump 2 tiles forward)
    static let jumpDistanceTiles: Int = 2

    /// Jump height in world units
    static var jumpHeight: Float { Float(jumpHeightTiles) * tileSize }

    /// Jump distance in world units
    static var jumpDistance: Float { Float(jumpDistanceTiles) * tileSize }

    // MARK: - Camera Configuration

    /// Camera distance from the scene (closer = only one room visible)
    static let cameraDistance: Float = 25.0

    /// Camera Z offset (negative value positions camera in front of scene)
    static var cameraZOffset: Float { -cameraDistance }

    /// Camera transition duration in seconds
    static let cameraTransitionDuration: TimeInterval = 0.2

    // MARK: - Input Configuration

    /// Deadzone for analog stick input (ignore small movements)
    static let inputDeadzone: Float = 0.2

    /// Input polling rate in seconds
    static let inputPollRate: TimeInterval = 1.0 / 60.0

    // MARK: - Room Configuration

    /// Starting room index
    static let startingRoomIndex: Int = 0

    /// Player starting position in room (in tiles from room origin)
    static let playerStartX: Float = 5.0
    static let playerStartY: Float = 0.0

    // MARK: - Debug Configuration

    /// Enable debug visualization (boundaries, collision boxes, etc.)
    static let debugVisualization: Bool = true

    /// Enable debug logging
    static let debugLogging: Bool = true
}
