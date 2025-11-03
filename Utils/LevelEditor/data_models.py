"""
Data models for GrimpossibleMission Level Editor.

Defines the core data structures for rooms, levels, and tile types.
"""

import json
from typing import Dict, List, Optional, Any
from copy import deepcopy


class TileType:
    """Constants for tile type IDs."""
    EMPTY = 0
    BLOCK = 1
    PLATFORM = 2
    SPAWN = 8
    SEARCHABLE = 9

    @staticmethod
    def get_name(tile_id: int) -> str:
        """Get the name of a tile type."""
        names = {
            TileType.EMPTY: "Empty",
            TileType.BLOCK: "Block",
            TileType.PLATFORM: "Platform",
            TileType.SPAWN: "Spawn",
            TileType.SEARCHABLE: "Searchable"
        }
        return names.get(tile_id, "Unknown")

    @staticmethod
    def get_all_types() -> List[int]:
        """Get all valid tile type IDs."""
        return [TileType.EMPTY, TileType.BLOCK, TileType.PLATFORM, TileType.SPAWN, TileType.SEARCHABLE]


class Room:
    """Represents a single room in the level."""

    def __init__(self, room_id: int = 1, width: int = 64, height: int = 36):
        """
        Initialize a room.

        Args:
            room_id: Unique identifier for the room
            width: Total room width (including walls)
            height: Total room height (including walls)
        """
        self.id = room_id
        self.width = width
        self.height = height

        # Interior dimensions exclude perimeter walls
        interior_width = width - 2
        interior_height = height - 2

        # Initialize interior as empty tiles
        # interior[0] = TOP row, interior[last] = BOTTOM row
        self.interior: List[List[int]] = [
            [TileType.EMPTY for _ in range(interior_width)]
            for _ in range(interior_height)
        ]

        # Exit configuration
        self.exits: Dict[str, Optional[Dict]] = {
            "left": None,
            "right": None
        }

        # Theme colors
        self.theme: Dict[str, str] = {
            "wall_color": "darkgray",
            "floor_color": "gray",
            "ceiling_color": "gray"
        }

    def get_interior_width(self) -> int:
        """Get the interior width (excluding walls)."""
        return self.width - 2

    def get_interior_height(self) -> int:
        """Get the interior height (excluding walls)."""
        return self.height - 2

    def resize(self, new_width: int, new_height: int):
        """
        Resize the room, preserving as much of the interior as possible.

        Args:
            new_width: New total width
            new_height: New total height
        """
        old_interior = self.interior
        self.width = new_width
        self.height = new_height

        new_interior_width = new_width - 2
        new_interior_height = new_height - 2

        # Create new interior
        self.interior = [
            [TileType.EMPTY for _ in range(new_interior_width)]
            for _ in range(new_interior_height)
        ]

        # Copy old tiles where they fit
        for y in range(min(len(old_interior), new_interior_height)):
            for x in range(min(len(old_interior[0]), new_interior_width)):
                self.interior[y][x] = old_interior[y][x]

    def get_tile(self, x: int, y: int) -> int:
        """
        Get the tile at interior coordinates (x, y).

        Args:
            x: X coordinate (0 = rightmost in mirrored coords)
            y: Y coordinate (0 = topmost)

        Returns:
            Tile type ID
        """
        if 0 <= y < len(self.interior) and 0 <= x < len(self.interior[0]):
            return self.interior[y][x]
        return TileType.EMPTY

    def set_tile(self, x: int, y: int, tile_type: int):
        """
        Set the tile at interior coordinates (x, y).

        Args:
            x: X coordinate (0 = rightmost in mirrored coords)
            y: Y coordinate (0 = topmost)
            tile_type: Tile type ID to set
        """
        if 0 <= y < len(self.interior) and 0 <= x < len(self.interior[0]):
            self.interior[y][x] = tile_type

    def to_dict(self) -> Dict[str, Any]:
        """Convert room to dictionary for JSON export."""
        return {
            "id": self.id,
            "width": self.width,
            "height": self.height,
            "interior": self.interior,  # Will be formatted specially during JSON export
            "exits": self.exits,
            "theme": self.theme
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Room':
        """Create a room from a dictionary."""
        room = cls(
            room_id=data["id"],
            width=data["width"],
            height=data["height"]
        )
        room.interior = data["interior"]
        room.exits = data["exits"]
        room.theme = data["theme"]
        return room

    def clone(self) -> 'Room':
        """Create a deep copy of this room."""
        new_room = Room(self.id, self.width, self.height)
        new_room.interior = deepcopy(self.interior)
        new_room.exits = deepcopy(self.exits)
        new_room.theme = deepcopy(self.theme)
        return new_room


class LayoutEntry:
    """Represents a room's position in the level layout."""

    def __init__(self, room_id: int, position: int):
        """
        Initialize a layout entry.

        Args:
            room_id: ID of the room
            position: Sequential position in the layout
        """
        self.room_id = room_id
        self.position = position

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON export."""
        return {
            "room_id": self.room_id,
            "position": self.position
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'LayoutEntry':
        """Create from dictionary."""
        return cls(data["room_id"], data["position"])


class Level:
    """Represents a complete level with rooms and layout."""

    def __init__(self):
        """Initialize an empty level."""
        self.tile_types = {
            "0": {"name": "empty", "solidType": "none"},
            "1": {"name": "block", "color": "brown", "solidType": "block"},
            "2": {"name": "platform", "color": "green", "solidType": "platform"},
            "8": {"name": "spawn", "color": "magenta", "solidType": "none"},
            "9": {"name": "searchable", "solidType": "none"}
        }
        self.rooms: List[Room] = []
        self.layout: List[LayoutEntry] = []  # Legacy layout system
        self.floor_layouts: List[FloorLayout] = []  # New grid-based layout system

    def add_room(self, room: Room) -> bool:
        """
        Add a room to the level.

        Args:
            room: Room to add

        Returns:
            True if added successfully, False if ID already exists
        """
        if any(r.id == room.id for r in self.rooms):
            return False
        self.rooms.append(room)
        return True

    def remove_room(self, room_id: int):
        """Remove a room and its layout entries."""
        self.rooms = [r for r in self.rooms if r.id != room_id]
        self.layout = [le for le in self.layout if le.room_id != room_id]
        # Resequence positions
        self.layout.sort(key=lambda le: le.position)
        for i, le in enumerate(self.layout):
            le.position = i

    def get_room(self, room_id: int) -> Optional[Room]:
        """Get a room by its ID."""
        for room in self.rooms:
            if room.id == room_id:
                return room
        return None

    def get_next_room_id(self) -> int:
        """Get the next available room ID."""
        if not self.rooms:
            return 1
        return max(r.id for r in self.rooms) + 1

    def add_to_layout(self, room_id: int):
        """Add a room to the end of the layout."""
        if not any(r.id == room_id for r in self.rooms):
            return False
        position = len(self.layout)
        self.layout.append(LayoutEntry(room_id, position))
        return True

    def remove_from_layout(self, position: int):
        """Remove a room from the layout at the given position."""
        self.layout = [le for le in self.layout if le.position != position]
        # Resequence
        self.layout.sort(key=lambda le: le.position)
        for i, le in enumerate(self.layout):
            le.position = i

    def move_in_layout(self, old_position: int, new_position: int):
        """Move a layout entry from old_position to new_position."""
        if old_position < 0 or old_position >= len(self.layout):
            return
        if new_position < 0 or new_position >= len(self.layout):
            return

        entry = self.layout[old_position]
        self.layout.pop(old_position)
        self.layout.insert(new_position, entry)

        # Resequence all positions
        for i, le in enumerate(self.layout):
            le.position = i

    def validate(self) -> List[str]:
        """
        Validate the level structure.

        Returns:
            List of error messages (empty if valid)
        """
        errors = []

        # Check room ID uniqueness
        room_ids = [r.id for r in self.rooms]
        if len(room_ids) != len(set(room_ids)):
            errors.append("Duplicate room IDs found")

        # Check interior dimensions
        for room in self.rooms:
            expected_height = room.height - 2
            expected_width = room.width - 2
            if len(room.interior) != expected_height:
                errors.append(f"Room {room.id}: Interior height mismatch")
            for row in room.interior:
                if len(row) != expected_width:
                    errors.append(f"Room {room.id}: Interior width mismatch")
                    break

        # Check layout references
        for entry in self.layout:
            if not any(r.id == entry.room_id for r in self.rooms):
                errors.append(f"Layout references non-existent room {entry.room_id}")

        # Check layout position sequence
        positions = sorted([le.position for le in self.layout])
        expected = list(range(len(self.layout)))
        if positions != expected:
            errors.append("Layout positions are not sequential")

        # Check for spawn points (only 1 allowed per layout)
        spawn_count = 0
        spawn_locations = []
        for room in self.rooms:
            for y, row in enumerate(room.interior):
                for x, tile_id in enumerate(row):
                    if tile_id == TileType.SPAWN:
                        spawn_count += 1
                        spawn_locations.append(f"Room {room.id} at ({x}, {y})")

        if spawn_count == 0:
            errors.append("No spawn point found in level (place exactly 1 spawn tile)")
        elif spawn_count > 1:
            errors.append(f"Multiple spawn points found ({spawn_count}). Only 1 spawn allowed. Locations: {', '.join(spawn_locations)}")

        return errors

    def to_json(self, filepath: str):
        """
        Export level to JSON file with correct formatting.

        Args:
            filepath: Path to output JSON file
        """
        def format_interior(interior: List[List[int]]) -> str:
            """Format interior array as compact single-line rows."""
            lines = []
            for row in interior:
                lines.append("[" + ",".join(str(x) for x in row) + "]")
            return "[\n        " + ",\n        ".join(lines) + "\n      ]"

        # Build the JSON structure manually for proper formatting
        output = "{\n"
        output += '  "tile_types": ' + json.dumps(self.tile_types, indent=4) + ',\n'
        output += '  "rooms": [\n'

        for i, room in enumerate(self.rooms):
            output += '    {\n'
            output += f'      "id": {room.id},\n'
            output += f'      "width": {room.width},\n'
            output += f'      "height": {room.height},\n'
            output += '      "interior": ' + format_interior(room.interior) + ',\n'
            output += '      "exits": ' + json.dumps(room.exits) + ',\n'
            output += '      "theme": ' + json.dumps(room.theme) + '\n'
            output += '    }'
            if i < len(self.rooms) - 1:
                output += ','
            output += '\n'

        output += '  ],\n'
        output += '  "layout": ' + json.dumps([le.to_dict() for le in self.layout], indent=4) + ',\n'
        output += '  "floor_layouts": ' + json.dumps([fl.to_dict() for fl in self.floor_layouts], indent=4) + '\n'
        output += '}\n'

        with open(filepath, 'w') as f:
            f.write(output)

    @classmethod
    def from_json(cls, filepath: str) -> 'Level':
        """
        Import level from JSON file.

        Args:
            filepath: Path to JSON file

        Returns:
            Level object
        """
        with open(filepath, 'r') as f:
            data = json.load(f)

        level = cls()
        level.tile_types = data.get("tile_types", level.tile_types)

        for room_data in data.get("rooms", []):
            room = Room.from_dict(room_data)
            level.rooms.append(room)

        for layout_data in data.get("layout", []):
            entry = LayoutEntry.from_dict(layout_data)
            level.layout.append(entry)

        for floor_layout_data in data.get("floor_layouts", []):
            floor_layout = FloorLayout.from_dict(floor_layout_data)
            level.floor_layouts.append(floor_layout)

        return level


class DoorPosition:
    """Constants for door positions on walls."""
    NONE = "none"
    TOP = "top"
    MID = "mid"
    BOT = "bot"

    @staticmethod
    def get_all_positions() -> List[str]:
        """Get all valid door positions."""
        return [DoorPosition.NONE, DoorPosition.TOP, DoorPosition.MID, DoorPosition.BOT]

    @staticmethod
    def get_name(position: str) -> str:
        """Get the display name of a door position."""
        names = {
            DoorPosition.NONE: "None",
            DoorPosition.TOP: "Top",
            DoorPosition.MID: "Middle",
            DoorPosition.BOT: "Bottom"
        }
        return names.get(position, "Unknown")


class GridPosition:
    """Represents a position in the floor layout grid."""

    def __init__(self, row: int, col: int):
        """
        Initialize a grid position.

        Args:
            row: Row in the grid (0-indexed)
            col: Column in the grid (0-indexed)
        """
        self.row = row
        self.col = col

    def __eq__(self, other):
        if not isinstance(other, GridPosition):
            return False
        return self.row == other.row and self.col == other.col

    def __hash__(self):
        return hash((self.row, self.col))

    def to_dict(self) -> Dict[str, int]:
        """Convert to dictionary for JSON export."""
        return {"row": self.row, "col": self.col}

    @classmethod
    def from_dict(cls, data: Dict[str, int]) -> 'GridPosition':
        """Create from dictionary."""
        return cls(data["row"], data["col"])


class RoomConnection:
    """Represents a door connection between two adjacent rooms."""

    def __init__(self, from_pos: GridPosition, to_pos: GridPosition, door_position: str):
        """
        Initialize a room connection.

        Args:
            from_pos: Grid position of the source room
            to_pos: Grid position of the target room
            door_position: Vertical position of door (DoorPosition constant)
        """
        self.from_pos = from_pos
        self.to_pos = to_pos
        self.door_position = door_position

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON export."""
        return {
            "from": self.from_pos.to_dict(),
            "to": self.to_pos.to_dict(),
            "door_position": self.door_position
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'RoomConnection':
        """Create from dictionary."""
        return cls(
            GridPosition.from_dict(data["from"]),
            GridPosition.from_dict(data["to"]),
            data["door_position"]
        )


class FloorLayout:
    """Represents a floor layout with rooms arranged in a grid."""

    def __init__(self, rows: int = 5, cols: int = 5):
        """
        Initialize a floor layout.

        Args:
            rows: Number of rows in the grid
            cols: Number of columns in the grid
        """
        self.rows = rows
        self.cols = cols
        # Maps GridPosition to room_id
        self.grid: Dict[GridPosition, Optional[int]] = {}
        # Initialize empty grid
        for row in range(rows):
            for col in range(cols):
                self.grid[GridPosition(row, col)] = None

        # List of connections between rooms
        self.connections: List[RoomConnection] = []

    def place_room(self, pos: GridPosition, room_id: Optional[int]):
        """
        Place a room at a grid position.

        Args:
            pos: Grid position
            room_id: ID of the room to place (None to clear)
        """
        if pos in self.grid:
            self.grid[pos] = room_id

    def get_room_at(self, pos: GridPosition) -> Optional[int]:
        """Get the room ID at a grid position."""
        return self.grid.get(pos)

    def add_row(self):
        """Add a new row to the bottom of the grid."""
        self.rows += 1
        for col in range(self.cols):
            self.grid[GridPosition(self.rows - 1, col)] = None

    def add_column(self):
        """Add a new column to the right of the grid."""
        self.cols += 1
        for row in range(self.rows):
            self.grid[GridPosition(row, self.cols - 1)] = None

    def remove_row(self):
        """Remove the bottom row if empty."""
        if self.rows <= 1:
            return False

        # Check if bottom row is empty
        for col in range(self.cols):
            if self.grid.get(GridPosition(self.rows - 1, col)) is not None:
                return False

        # Remove the row
        for col in range(self.cols):
            del self.grid[GridPosition(self.rows - 1, col)]
        self.rows -= 1

        # Remove connections involving the removed row
        self.connections = [
            c for c in self.connections
            if c.from_pos.row < self.rows and c.to_pos.row < self.rows
        ]
        return True

    def remove_column(self):
        """Remove the rightmost column if empty."""
        if self.cols <= 1:
            return False

        # Check if rightmost column is empty
        for row in range(self.rows):
            if self.grid.get(GridPosition(row, self.cols - 1)) is not None:
                return False

        # Remove the column
        for row in range(self.rows):
            del self.grid[GridPosition(row, self.cols - 1)]
        self.cols -= 1

        # Remove connections involving the removed column
        self.connections = [
            c for c in self.connections
            if c.from_pos.col < self.cols and c.to_pos.col < self.cols
        ]
        return True

    def set_connection(self, from_pos: GridPosition, to_pos: GridPosition, door_position: str):
        """
        Set or update a connection between two rooms.

        Args:
            from_pos: Source grid position
            to_pos: Target grid position
            door_position: Door position (DoorPosition constant)
        """
        # Remove any existing connection between these positions
        self.connections = [
            c for c in self.connections
            if not ((c.from_pos == from_pos and c.to_pos == to_pos) or
                   (c.from_pos == to_pos and c.to_pos == from_pos))
        ]

        # Add new connection if not NONE
        if door_position != DoorPosition.NONE:
            self.connections.append(RoomConnection(from_pos, to_pos, door_position))

    def get_connection(self, from_pos: GridPosition, to_pos: GridPosition) -> Optional[RoomConnection]:
        """Get the connection between two positions (if any)."""
        for conn in self.connections:
            if (conn.from_pos == from_pos and conn.to_pos == to_pos) or \
               (conn.from_pos == to_pos and conn.to_pos == from_pos):
                return conn
        return None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON export."""
        # Convert grid to list format
        grid_list = []
        for row in range(self.rows):
            row_data = []
            for col in range(self.cols):
                room_id = self.grid.get(GridPosition(row, col))
                row_data.append(room_id)
            grid_list.append(row_data)

        return {
            "rows": self.rows,
            "cols": self.cols,
            "grid": grid_list,
            "connections": [c.to_dict() for c in self.connections]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'FloorLayout':
        """Create from dictionary."""
        layout = cls(data["rows"], data["cols"])

        # Populate grid
        grid_list = data["grid"]
        for row in range(data["rows"]):
            for col in range(data["cols"]):
                room_id = grid_list[row][col]
                layout.grid[GridPosition(row, col)] = room_id

        # Populate connections
        for conn_data in data.get("connections", []):
            layout.connections.append(RoomConnection.from_dict(conn_data))

        return layout
