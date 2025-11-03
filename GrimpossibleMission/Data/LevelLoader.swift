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

        let roomIds = Set(level.rooms.map { $0.id })

        // Check that layout references valid rooms
        for layoutEntry in level.layout {
            if !roomIds.contains(layoutEntry.roomId) {
                return "Layout references undefined room ID: \(layoutEntry.roomId)"
            }
        }

        // Validate floor_layouts if present
        if let floorLayouts = level.floorLayouts {
            for (floorIndex, floorLayout) in floorLayouts.enumerated() {
                // Check grid dimensions
                if floorLayout.rows <= 0 || floorLayout.cols <= 0 {
                    return "Floor layout \(floorIndex) has invalid dimensions: \(floorLayout.rows)x\(floorLayout.cols)"
                }

                // Check grid array dimensions
                if floorLayout.grid.count != floorLayout.rows {
                    return "Floor layout \(floorIndex) grid has \(floorLayout.grid.count) rows, expected \(floorLayout.rows)"
                }

                for (rowIndex, row) in floorLayout.grid.enumerated() {
                    if row.count != floorLayout.cols {
                        return "Floor layout \(floorIndex) row \(rowIndex) has \(row.count) columns, expected \(floorLayout.cols)"
                    }

                    // Check that all room IDs in grid are valid
                    for roomId in row {
                        if !roomIds.contains(roomId) {
                            return "Floor layout \(floorIndex) grid references undefined room ID: \(roomId)"
                        }
                    }
                }

                // Validate connections
                for (connIndex, connection) in floorLayout.connections.enumerated() {
                    // Check that connection positions are within grid bounds
                    if connection.from.row < 0 || connection.from.row >= floorLayout.rows {
                        return "Floor layout \(floorIndex) connection \(connIndex) from.row \(connection.from.row) is out of bounds"
                    }
                    if connection.from.col < 0 || connection.from.col >= floorLayout.cols {
                        return "Floor layout \(floorIndex) connection \(connIndex) from.col \(connection.from.col) is out of bounds"
                    }
                    if connection.to.row < 0 || connection.to.row >= floorLayout.rows {
                        return "Floor layout \(floorIndex) connection \(connIndex) to.row \(connection.to.row) is out of bounds"
                    }
                    if connection.to.col < 0 || connection.to.col >= floorLayout.cols {
                        return "Floor layout \(floorIndex) connection \(connIndex) to.col \(connection.to.col) is out of bounds"
                    }

                    // Check that connection is between adjacent rooms
                    let rowDiff = abs(connection.from.row - connection.to.row)
                    let colDiff = abs(connection.from.col - connection.to.col)
                    if (rowDiff == 0 && colDiff == 1) || (rowDiff == 1 && colDiff == 0) {
                        // Valid: adjacent horizontally or vertically
                    } else {
                        return "Floor layout \(floorIndex) connection \(connIndex) connects non-adjacent rooms: (\(connection.from.row),\(connection.from.col)) to (\(connection.to.row),\(connection.to.col))"
                    }
                }
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
