//
//  LevelLoader.swift
//  GrimpossibleMission
//
//  Loads level data from JSON files.
//

import Foundation

/// Loads and parses level JSON files
class LevelLoader {

    /// Load a level from a JSON file in the bundle
    /// - Parameter filename: Name of the JSON file (e.g., "level_001")
    /// - Returns: Parsed level data, or nil if loading failed
    static func loadLevel(filename: String) -> LevelData? {
        // Find the file in the bundle
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("[LevelLoader] Error: Could not find file '\(filename).json' in bundle")
            return nil
        }

        do {
            // Read the file data
            let data = try Data(contentsOf: url)

            // Parse JSON
            let decoder = JSONDecoder()
            let levelData = try decoder.decode(LevelData.self, from: data)

            // Validate the level data
            if let error = validate(levelData) {
                print("[LevelLoader] Validation error: \(error)")
                return nil
            }

            print("[LevelLoader] Successfully loaded level '\(filename)' with \(levelData.rooms.count) rooms")
            return levelData

        } catch {
            print("[LevelLoader] Error loading level: \(error)")
            return nil
        }
    }

    /// Validate level data for common errors
    /// - Parameter level: Level data to validate
    /// - Returns: Error message if invalid, nil if valid
    private static func validate(_ level: LevelData) -> String? {
        // Check that we have rooms
        if level.rooms.isEmpty {
            return "No rooms defined in level"
        }

        // Check that layout references valid rooms
        let roomIds = Set(level.rooms.map { $0.id })
        for layoutEntry in level.layout {
            if !roomIds.contains(layoutEntry.roomId) {
                return "Layout references undefined room ID: \(layoutEntry.roomId)"
            }
        }

        // Validate each room
        for room in level.rooms {
            // Check dimensions
            if room.width <= 0 || room.height <= 0 {
                return "Room \(room.id) has invalid dimensions: \(room.width)x\(room.height)"
            }

            // Check interior tile array dimensions
            // Should be (height - 2) rows by (width - 2) columns
            let expectedRows = room.height - 2
            let expectedCols = room.width - 2

            if room.interior.count != expectedRows {
                return "Room \(room.id) has \(room.interior.count) rows, expected \(expectedRows) (height - 2)"
            }

            for (rowIndex, row) in room.interior.enumerated() {
                if row.count != expectedCols {
                    return "Room \(room.id) row \(rowIndex) has \(row.count) columns, expected \(expectedCols) (width - 2)"
                }
            }
        }

        return nil
    }

    /// Get a room by ID from level data
    /// - Parameters:
    ///   - id: Room ID to find
    ///   - level: Level data to search
    /// - Returns: Room data if found, nil otherwise
    static func getRoom(id: Int, from level: LevelData) -> RoomData? {
        return level.rooms.first { $0.id == id }
    }
}
