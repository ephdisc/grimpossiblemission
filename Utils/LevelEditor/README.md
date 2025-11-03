# GrimpossibleMission Level Editor

A standalone GUI application for creating room layouts and level configurations for the GrimpossibleMission tvOS game.

## Quick Start

### Installation

Run the installation script (recommended):
```bash
./install.sh
```

Or manually:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Running

Run the editor:
```bash
./run.sh
```

Or manually:
```bash
source venv/bin/activate
python level_editor.py
```

## Features

### Room Editor Tab
- **Visual Tile Grid**: Paint tiles with different types (Empty, Block, Platform, Searchable)
- **Click + Drag Painting**: Efficiently paint multiple tiles at once
- **Brush Size**: Adjustable brush from 1x1 to 5x5
- **Room List**: Create, duplicate, and delete rooms
- **Room Properties**: Configure ID, dimensions, exits, and theme colors
- **Undo/Redo**: Full undo/redo support (Ctrl+Z / Ctrl+Y)
- **Zoom Controls**: Zoom in/out and fit-to-window
- **Selection Tool**: Middle-click drag to select rectangular areas
- **Fill Tool**: Fill selections with current tile type (F key)

### Layout Editor Tab
- **Room Sequencing**: Define the order of rooms in the level
- **Drag-and-Drop**: Reorder rooms easily
- **Visual List**: See all rooms in the layout sequence

### File Operations
- **New Level**: Start a fresh level (Ctrl+N)
- **Open Level**: Load existing JSON files (Ctrl+O)
- **Save/Save As**: Export to JSON format (Ctrl+S / Ctrl+Shift+S)
- **Validation**: Check level for errors (Tools → Validate)
- **Statistics**: View tile counts and level info (Tools → Statistics)

## Controls

### Mouse Controls
- **Left Click**: Place selected tile type
- **Right Click**: Erase tile (set to empty)
- **Click + Drag**: Paint multiple tiles
- **Middle Click + Drag**: Create selection
- **Ctrl + Mouse Wheel**: Zoom in/out

### Keyboard Shortcuts

#### General
- **Ctrl+N**: New level
- **Ctrl+O**: Open level
- **Ctrl+S**: Save level
- **Ctrl+Shift+S**: Save As
- **Ctrl+Z**: Undo
- **Ctrl+Y**: Redo
- **Ctrl+Q**: Quit

#### Tile Editing
- **0**: Select Empty tile
- **1**: Select Block tile
- **2**: Select Platform tile
- **9**: Select Searchable tile
- **Delete/Backspace**: Clear selection
- **F**: Fill selection with current tile type
- **Esc**: Clear selection

#### View
- **Ctrl++**: Zoom in
- **Ctrl+-**: Zoom out

## JSON Format

The editor exports levels in the following format:

```json
{
  "tile_types": {
    "0": {"name": "empty", "solidType": "none"},
    "1": {"name": "block", "color": "brown", "solidType": "block"},
    "2": {"name": "platform", "color": "green", "solidType": "platform"},
    "9": {"name": "searchable", "solidType": "none"}
  },
  "rooms": [
    {
      "id": 1,
      "width": 64,
      "height": 36,
      "interior": [
        [0,0,0,0,...],  // Compact single-line rows
        [0,0,0,0,...],
        ...
      ],
      "exits": {
        "left": null,
        "right": {"type": "doorway"}
      },
      "theme": {
        "wall_color": "darkgray",
        "floor_color": "gray",
        "ceiling_color": "gray"
      }
    }
  ],
  "layout": [
    {"room_id": 1, "position": 0},
    {"room_id": 2, "position": 1}
  ]
}
```

### Key Format Details

1. **Interior Dimensions**: Always (width - 2) × (height - 2) to exclude perimeter walls
2. **Compact Format**: Each interior row on a single line
3. **Coordinate System**:
   - `interior[0]` = TOP row (near ceiling)
   - `interior[last]` = BOTTOM row (near floor)
   - `interior[y][0]` = RIGHT side (mirrored horizontally)
   - `interior[y][last]` = LEFT side (mirrored horizontally)

## Workflow

### Creating a New Level

1. **Create Rooms**:
   - Click "New Room" to add rooms
   - Select a room from the list to edit it
   - Use the tile palette to select tile types
   - Paint tiles by clicking and dragging on the canvas
   - Adjust room properties (ID, size, exits, colors) in the right panel

2. **Configure Room Properties**:
   - Set unique Room IDs
   - Adjust dimensions (width/height)
   - Configure exits (left/right doorways)
   - Customize theme colors

3. **Arrange Layout**:
   - Switch to the "Layout Editor" tab
   - Add rooms to the layout from the available rooms list
   - Drag to reorder rooms in the sequence
   - Remove rooms from layout if needed

4. **Save**:
   - Click File → Save (or Ctrl+S)
   - Choose a filename (e.g., `level_1.json`)
   - The file will be exported in the correct format for the game

5. **Validate**:
   - Click Tools → Validate Level
   - Fix any reported errors
   - Re-save when validation passes

### Tips

- **Use Duplicate**: Clone rooms to create variations quickly
- **Use Brush Size**: Larger brushes speed up filling big areas
- **Use Selection + Fill**: Select rectangular areas and fill them instantly (F key)
- **Use Zoom Fit**: After changing room size, click "Zoom Fit" to see the entire room
- **Undo Often**: Don't worry about mistakes - undo is always available
- **Test Import**: After exporting, use Tools → Validate to ensure the file is correct

## Testing

Run the test script to verify JSON export/import:
```bash
source venv/bin/activate
python test_export.py
```

This will create a test level and verify:
- JSON format is correct
- Interior arrays are compact
- Dimensions are preserved
- Import/export round-trip works
- Validation passes

## Troubleshooting

### PyQt5 Installation Issues

If you see "externally-managed-environment" errors, the install script will automatically create a virtual environment. If problems persist:

```bash
python3 -m venv venv
source venv/bin/activate
pip install PyQt5
```

### Application Won't Start

Make sure you're using Python 3.7 or later:
```bash
python3 --version
```

### Can't See Tiles After Painting

- Check that you've selected a room from the room list
- Try zooming in (Ctrl + Mouse Wheel)
- Click "Zoom Fit" to see the entire room

## Files

- **level_editor.py**: Main application
- **tile_canvas.py**: Canvas widget for tile editing
- **data_models.py**: Data structures (Room, Level, TileType)
- **requirements.txt**: Python dependencies
- **install.sh**: Installation script
- **run.sh**: Launch script
- **test_export.py**: Test JSON export/import

## License

Part of the GrimpossibleMission project.
