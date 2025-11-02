//
//  LevelData.swift
//  GrimpossibleMission
//
//  Data structures for loading levels from JSON.
//

import Foundation
import UIKit

// MARK: - Level Data

/// Complete level definition loaded from JSON
struct LevelData: Codable {
    let rooms: [RoomData]
    let layout: [RoomLayoutEntry]
    let tileTypes: [String: TileTypeDefinition]?  // Optional tile type customization

    enum CodingKeys: String, CodingKey {
        case rooms
        case layout
        case tileTypes = "tile_types"
    }
}

/// Definition of a tile type (for customization)
struct TileTypeDefinition: Codable {
    let name: String
    let color: String?  // Hex color like "#FF5733" or system color name
    let solidType: String  // "block", "platform", "wall", "floor", "ceiling"
}

/// Single room definition
struct RoomData: Codable {
    let id: Int
    let width: Int
    let height: Int
    let interior: [[Int]]  // 2D array of tile type IDs (width-2 by height-2)
    let exits: RoomExits
    let theme: RoomTheme?  // Optional theme/styling
}

/// Exit/entry configuration for a room
struct RoomExits: Codable {
    let left: ExitDefinition?
    let right: ExitDefinition?
}

/// Definition of a single exit/doorway
struct ExitDefinition: Codable {
    let type: String  // "doorway" or "none"

    /// Height of doorway in tiles (optional - defaults to player height + 2)
    var heightTiles: Int? {
        // Always return player height + 2 tiles
        GameConfig.playerHeightTiles + 2
    }

    enum CodingKeys: String, CodingKey {
        case type
    }
}

/// Optional theme/styling for a room
struct RoomTheme: Codable {
    let backgroundColor: String?  // Hex color or system color name
    let wallColor: String?
    let floorColor: String?
    let ceilingColor: String?
    let platformColor: String?

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case wallColor = "wall_color"
        case floorColor = "floor_color"
        case ceilingColor = "ceiling_color"
        case platformColor = "platform_color"
    }
}

/// Room placement in level layout
struct RoomLayoutEntry: Codable {
    let roomId: Int
    let position: Int  // Horizontal position (0 = first room, 1 = second, etc.)

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case position
    }
}

// MARK: - Tile Type Mapping

/// Maps tile IDs to solid types
enum TileType: Int {
    case empty = 0
    case block = 1
    case platform = 2
    case searchable = 9

    /// Convert tile type to solid type for collision
    var solidType: SolidType? {
        switch self {
        case .empty, .searchable:
            return nil
        case .block:
            return .block
        case .platform:
            return .platform
        }
    }

    /// Default color for this tile type
    var defaultColor: UIColor {
        switch self {
        case .empty, .searchable:
            return .clear
        case .block:
            return .systemBrown
        case .platform:
            return .systemGreen
        }
    }
}

// MARK: - Color Parsing

extension UIColor {
    /// Parse color from string (hex or system color name)
    static func from(string: String) -> UIColor {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Check for hex color
        if trimmed.hasPrefix("#") {
            return UIColor.fromHex(trimmed) ?? .gray
        }

        // System color names
        switch trimmed.lowercased() {
        case "red": return .systemRed
        case "green": return .systemGreen
        case "blue": return .systemBlue
        case "brown": return .systemBrown
        case "gray", "grey": return .systemGray
        case "darkgray", "darkgrey": return .darkGray
        case "lightgray", "lightgrey": return .lightGray
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "pink": return .systemPink
        case "purple": return .systemPurple
        case "teal": return .systemTeal
        case "indigo": return .systemIndigo
        default: return .gray
        }
    }

    /// Parse hex color string (e.g., "#FF5733")
    static func fromHex(_ hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
