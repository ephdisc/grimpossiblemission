#!/usr/bin/env python3
"""
Test script to verify JSON export format.
"""

from data_models import Room, Level, TileType

# Create a simple test level
level = Level()

# Create a test room
room = Room(room_id=1, width=10, height=8)

# Set some tiles for testing
room.set_tile(0, 0, TileType.BLOCK)
room.set_tile(1, 0, TileType.BLOCK)
room.set_tile(0, 1, TileType.PLATFORM)
room.set_tile(5, 5, TileType.SEARCHABLE)

# Set exits
room.exits["right"] = {"type": "doorway"}

# Add room to level
level.add_room(room)

# Add to layout
level.add_to_layout(1)

# Export to JSON
output_file = "test_level.json"
level.to_json(output_file)

print(f"✅ Test level exported to {output_file}")
print()

# Read and display the file
with open(output_file, 'r') as f:
    content = f.read()
    print("Exported JSON:")
    print("-" * 60)
    print(content)
    print("-" * 60)

# Verify format
print()
print("Format verification:")

# Check for compact interior array format
if ',' in content and '],\n        [' in content:
    print("✅ Interior arrays are in compact single-line format")
else:
    print("❌ Interior arrays might not be in compact format")

# Check dimensions
if '"width": 10' in content and '"height": 8' in content:
    print("✅ Dimensions are correct")
else:
    print("❌ Dimensions might be incorrect")

# Check interior dimensions (should be width-2 x height-2 = 8x6)
lines = content.split('\n')
interior_section = False
row_count = 0
for line in lines:
    if '"interior":' in line:
        interior_section = True
    elif interior_section and line.strip().startswith('['):
        row_count += 1
    elif interior_section and '],' in line and 'interior' not in line:
        break

if row_count == 6:  # height - 2
    print(f"✅ Interior has correct number of rows: {row_count}")
else:
    print(f"❌ Interior row count incorrect: {row_count} (expected 6)")

# Test import
print()
print("Testing import...")
imported_level = Level.from_json(output_file)

if len(imported_level.rooms) == 1:
    print("✅ Import successful: 1 room loaded")
    imported_room = imported_level.rooms[0]

    # Verify tiles
    if (imported_room.get_tile(0, 0) == TileType.BLOCK and
        imported_room.get_tile(1, 0) == TileType.BLOCK and
        imported_room.get_tile(0, 1) == TileType.PLATFORM and
        imported_room.get_tile(5, 5) == TileType.SEARCHABLE):
        print("✅ Tile data preserved correctly")
    else:
        print("❌ Tile data mismatch")

    # Verify exits
    if imported_room.exits.get("right"):
        print("✅ Exit data preserved correctly")
    else:
        print("❌ Exit data missing")
else:
    print("❌ Import failed")

# Validate
errors = imported_level.validate()
if not errors:
    print("✅ Level validation passed")
else:
    print(f"❌ Validation errors: {errors}")

print()
print("All tests completed!")
