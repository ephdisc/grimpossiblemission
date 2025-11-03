"""
Layout Editor widgets for grid-based floor layout.

Provides drag-and-drop room arrangement and door placement controls.
"""

from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel,
                              QPushButton, QScrollArea, QGroupBox, QComboBox,
                              QGridLayout, QSizePolicy)
from PyQt5.QtCore import Qt, QSize, QMimeData, pyqtSignal, QPoint
from PyQt5.QtGui import QPainter, QColor, QPen, QBrush, QPixmap, QDrag, QPalette
from data_models import (Level, Room, FloorLayout, GridPosition,
                          DoorPosition, TileType, RoomConnection)
from typing import Optional


class RoomPreviewWidget(QLabel):
    """
    Small thumbnail preview of a room's tile layout.
    """

    def __init__(self, room: Optional[Room] = None, size: int = 100, parent=None):
        super().__init__(parent)
        self.room = room
        self.preview_size = size
        self.setFixedSize(size, size)
        self.setFrameStyle(QLabel.Panel | QLabel.Sunken)
        self.setLineWidth(2)
        self.render_preview()

    def set_room(self, room: Optional[Room]):
        """Update the room being displayed."""
        self.room = room
        self.render_preview()

    def render_preview(self):
        """Render the room as a small pixmap."""
        if not self.room:
            self.setText("Empty")
            self.setAlignment(Qt.AlignCenter)
            return

        pixmap = QPixmap(self.preview_size, self.preview_size)
        pixmap.fill(QColor(50, 50, 50))  # Dark background

        painter = QPainter(pixmap)

        # Calculate tile size to fit the room in the preview
        width = self.room.width
        height = self.room.height
        tile_width = self.preview_size / width
        tile_height = self.preview_size / height
        tile_size = min(tile_width, tile_height)

        # Center the room in the preview
        offset_x = (self.preview_size - (width * tile_size)) / 2
        offset_y = (self.preview_size - (height * tile_size)) / 2

        # Draw walls (perimeter)
        painter.setBrush(QBrush(QColor(100, 100, 100)))
        painter.setPen(Qt.NoPen)

        # Top and bottom walls
        for x in range(width):
            painter.drawRect(int(offset_x + x * tile_size),
                           int(offset_y),
                           int(tile_size + 1), int(tile_size + 1))
            painter.drawRect(int(offset_x + x * tile_size),
                           int(offset_y + (height - 1) * tile_size),
                           int(tile_size + 1), int(tile_size + 1))

        # Left and right walls
        for y in range(height):
            painter.drawRect(int(offset_x),
                           int(offset_y + y * tile_size),
                           int(tile_size + 1), int(tile_size + 1))
            painter.drawRect(int(offset_x + (width - 1) * tile_size),
                           int(offset_y + y * tile_size),
                           int(tile_size + 1), int(tile_size + 1))

        # Draw interior tiles
        for y in range(len(self.room.interior)):
            for x in range(len(self.room.interior[0])):
                tile_type = self.room.interior[y][x]
                if tile_type == TileType.EMPTY:
                    continue

                # Map tile types to colors
                if tile_type == TileType.BLOCK:
                    color = QColor(139, 69, 19)  # Brown
                elif tile_type == TileType.PLATFORM:
                    color = QColor(34, 139, 34)  # Green
                elif tile_type == TileType.SPAWN:
                    color = QColor(255, 0, 255)  # Magenta
                elif tile_type == TileType.SEARCHABLE:
                    color = QColor(178, 34, 34)  # Red
                else:
                    color = QColor(128, 128, 128)  # Gray

                painter.setBrush(QBrush(color))
                # Interior coordinates: x=0 is rightmost, y=0 is topmost
                # Add 1 to skip wall
                screen_x = int(offset_x + (x + 1) * tile_size)
                screen_y = int(offset_y + (y + 1) * tile_size)
                painter.drawRect(screen_x, screen_y, int(tile_size + 1), int(tile_size + 1))

        painter.end()
        self.setPixmap(pixmap)


class RoomPaletteWidget(QWidget):
    """
    Displays all available rooms as draggable previews.
    """

    room_selected = pyqtSignal(int)  # room_id

    def __init__(self, level: Level, parent=None):
        super().__init__(parent)
        self.level = level
        self.setup_ui()

    def setup_ui(self):
        """Set up the UI layout."""
        layout = QVBoxLayout()
        layout.setContentsMargins(5, 5, 5, 5)

        # Title
        title = QLabel("Available Rooms")
        title.setStyleSheet("font-weight: bold;")
        layout.addWidget(title)

        # Scroll area for rooms
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)

        scroll_content = QWidget()
        self.room_layout = QVBoxLayout()
        self.room_layout.setSpacing(10)
        scroll_content.setLayout(self.room_layout)
        scroll.setWidget(scroll_content)

        layout.addWidget(scroll)
        self.setLayout(layout)

        self.refresh_rooms()

    def refresh_rooms(self):
        """Refresh the list of rooms."""
        # Clear existing widgets
        while self.room_layout.count():
            item = self.room_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        # Add room previews
        for room in self.level.rooms:
            room_widget = self.create_room_item(room)
            self.room_layout.addWidget(room_widget)

        self.room_layout.addStretch()

    def create_room_item(self, room: Room) -> QWidget:
        """Create a widget for a single room."""
        container = QWidget()
        container_layout = QVBoxLayout()
        container_layout.setContentsMargins(0, 0, 0, 0)

        # Room preview
        preview = RoomPreviewWidget(room, size=120)
        preview.setAlignment(Qt.AlignCenter)

        # Make it draggable
        preview.mousePressEvent = lambda event: self.start_drag(room.id, event)

        container_layout.addWidget(preview)

        # Room label
        label = QLabel(f"Room {room.id}")
        label.setAlignment(Qt.AlignCenter)
        label.setStyleSheet("font-size: 10pt;")
        container_layout.addWidget(label)

        container.setLayout(container_layout)
        return container

    def start_drag(self, room_id: int, event):
        """Start dragging a room."""
        if event.button() == Qt.LeftButton:
            drag = QDrag(self)
            mime_data = QMimeData()
            mime_data.setText(str(room_id))
            drag.setMimeData(mime_data)
            drag.exec_(Qt.CopyAction)


class DoorSelectorButton(QPushButton):
    """
    Button for selecting door position between rooms.
    """

    door_changed = pyqtSignal(str)  # door_position

    def __init__(self, parent=None):
        super().__init__(parent)
        self.door_position = DoorPosition.NONE
        self.setFixedSize(20, 40)
        self.clicked.connect(self.cycle_door_position)
        self.update_display()

    def set_door_position(self, position: str):
        """Set the door position."""
        self.door_position = position
        self.update_display()

    def cycle_door_position(self):
        """Cycle through door positions."""
        positions = DoorPosition.get_all_positions()
        current_index = positions.index(self.door_position)
        next_index = (current_index + 1) % len(positions)
        self.door_position = positions[next_index]
        self.update_display()
        self.door_changed.emit(self.door_position)

    def update_display(self):
        """Update button appearance based on current position."""
        if self.door_position == DoorPosition.NONE:
            self.setText("X")
            self.setStyleSheet("background-color: #444; color: white;")
        elif self.door_position == DoorPosition.TOP:
            self.setText("↑")
            self.setStyleSheet("background-color: #4CAF50; color: white; font-weight: bold;")
        elif self.door_position == DoorPosition.MID:
            self.setText("→")
            self.setStyleSheet("background-color: #2196F3; color: white; font-weight: bold;")
        elif self.door_position == DoorPosition.BOT:
            self.setText("↓")
            self.setStyleSheet("background-color: #FF9800; color: white; font-weight: bold;")


class GridCellWidget(QLabel):
    """
    A single cell in the floor layout grid.
    """

    room_dropped = pyqtSignal(int, int, int)  # row, col, room_id

    def __init__(self, row: int, col: int, parent=None):
        super().__init__(parent)
        self.row = row
        self.col = col
        self.room_id: Optional[int] = None
        self.setFixedSize(120, 120)
        self.setFrameStyle(QLabel.Panel | QLabel.Raised)
        self.setLineWidth(2)
        self.setAcceptDrops(True)
        self.update_display()

    def set_room(self, room_id: Optional[int], room: Optional[Room] = None):
        """Set the room for this cell."""
        self.room_id = room_id
        if room and room_id:
            preview = RoomPreviewWidget(room, size=116)
            self.setPixmap(preview.pixmap())
        else:
            self.update_display()

    def update_display(self):
        """Update the cell display."""
        if not self.room_id:
            self.setText(f"{self.row},{self.col}")
            self.setAlignment(Qt.AlignCenter)
            self.setStyleSheet("background-color: #2a2a2a; color: #666;")
        else:
            self.setStyleSheet("background-color: #1a1a1a;")

    def dragEnterEvent(self, event):
        """Handle drag enter."""
        if event.mimeData().hasText():
            event.acceptProposedAction()

    def dropEvent(self, event):
        """Handle drop."""
        room_id = int(event.mimeData().text())
        self.room_dropped.emit(self.row, self.col, room_id)
        event.acceptProposedAction()


class FloorLayoutGridWidget(QWidget):
    """
    Main grid for arranging rooms in a floor layout.
    """

    layout_changed = pyqtSignal()

    def __init__(self, level: Level, floor_layout: FloorLayout, parent=None):
        super().__init__(parent)
        self.level = level
        self.floor_layout = floor_layout
        self.cells = {}  # (row, col) -> GridCellWidget
        self.door_buttons = {}  # (row, col, direction) -> DoorSelectorButton
        self.setup_ui()

    def setup_ui(self):
        """Set up the UI layout."""
        main_layout = QVBoxLayout()

        # Controls
        controls = QHBoxLayout()
        btn_add_row = QPushButton("Add Row")
        btn_add_row.clicked.connect(self.add_row)
        controls.addWidget(btn_add_row)

        btn_add_col = QPushButton("Add Column")
        btn_add_col.clicked.connect(self.add_column)
        controls.addWidget(btn_add_col)

        btn_remove_row = QPushButton("Remove Row")
        btn_remove_row.clicked.connect(self.remove_row)
        controls.addWidget(btn_remove_row)

        btn_remove_col = QPushButton("Remove Column")
        btn_remove_col.clicked.connect(self.remove_column)
        controls.addWidget(btn_remove_col)

        controls.addStretch()
        main_layout.addLayout(controls)

        # Scroll area for grid
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)

        scroll_content = QWidget()
        self.grid_layout = QGridLayout()
        self.grid_layout.setSpacing(5)
        scroll_content.setLayout(self.grid_layout)
        scroll.setWidget(scroll_content)

        main_layout.addWidget(scroll)
        self.setLayout(main_layout)

        self.rebuild_grid()

    def rebuild_grid(self):
        """Rebuild the entire grid."""
        # Clear existing widgets
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        self.cells.clear()
        self.door_buttons.clear()

        # Create grid cells and door buttons
        for row in range(self.floor_layout.rows):
            for col in range(self.floor_layout.cols):
                # Create cell
                cell = GridCellWidget(row, col, self)
                cell.room_dropped.connect(self.place_room_at)
                pos = GridPosition(row, col)
                room_id = self.floor_layout.get_room_at(pos)
                if room_id:
                    room = self.level.get_room(room_id)
                    cell.set_room(room_id, room)

                # Cell goes at (row * 2, col * 2) to leave space for door buttons
                self.grid_layout.addWidget(cell, row * 2, col * 2)
                self.cells[(row, col)] = cell

                # Add door button to the right (if not last column)
                if col < self.floor_layout.cols - 1:
                    door_btn = DoorSelectorButton(self)
                    door_btn.door_changed.connect(
                        lambda pos_str, r=row, c=col: self.on_door_changed(r, c, r, c+1, pos_str)
                    )
                    self.grid_layout.addWidget(door_btn, row * 2, col * 2 + 1, Qt.AlignCenter)
                    self.door_buttons[(row, col, 'right')] = door_btn

                    # Set initial door position
                    conn = self.floor_layout.get_connection(
                        GridPosition(row, col), GridPosition(row, col + 1)
                    )
                    if conn:
                        door_btn.set_door_position(conn.door_position)

                # Add door button below (if not last row)
                if row < self.floor_layout.rows - 1:
                    door_btn = DoorSelectorButton(self)
                    door_btn.setFixedSize(40, 20)  # Horizontal
                    door_btn.door_changed.connect(
                        lambda pos_str, r=row, c=col: self.on_door_changed(r, c, r+1, c, pos_str)
                    )
                    self.grid_layout.addWidget(door_btn, row * 2 + 1, col * 2, Qt.AlignCenter)
                    self.door_buttons[(row, col, 'bottom')] = door_btn

                    # Set initial door position
                    conn = self.floor_layout.get_connection(
                        GridPosition(row, col), GridPosition(row + 1, col)
                    )
                    if conn:
                        door_btn.set_door_position(conn.door_position)

    def place_room_at(self, row: int, col: int, room_id: int):
        """Place a room at a grid position."""
        pos = GridPosition(row, col)
        self.floor_layout.place_room(pos, room_id)

        # Update cell display
        cell = self.cells.get((row, col))
        if cell:
            room = self.level.get_room(room_id)
            cell.set_room(room_id, room)

        self.layout_changed.emit()

    def on_door_changed(self, from_row: int, from_col: int, to_row: int, to_col: int, door_position: str):
        """Handle door position change."""
        from_pos = GridPosition(from_row, from_col)
        to_pos = GridPosition(to_row, to_col)
        self.floor_layout.set_connection(from_pos, to_pos, door_position)
        self.layout_changed.emit()

    def add_row(self):
        """Add a row to the grid."""
        self.floor_layout.add_row()
        self.rebuild_grid()
        self.layout_changed.emit()

    def add_column(self):
        """Add a column to the grid."""
        self.floor_layout.add_column()
        self.rebuild_grid()
        self.layout_changed.emit()

    def remove_row(self):
        """Remove the last row if empty."""
        if self.floor_layout.remove_row():
            self.rebuild_grid()
            self.layout_changed.emit()

    def remove_column(self):
        """Remove the last column if empty."""
        if self.floor_layout.remove_column():
            self.rebuild_grid()
            self.layout_changed.emit()


class LayoutEditorTab(QWidget):
    """
    Main tab for editing floor layouts with grid-based room arrangement.
    """

    def __init__(self, level: Level, parent=None):
        super().__init__(parent)
        self.level = level

        # Create default floor layout if none exists
        if not self.level.floor_layouts:
            self.level.floor_layouts.append(FloorLayout())

        self.current_layout = self.level.floor_layouts[0]
        self.setup_ui()

    def setup_ui(self):
        """Set up the UI layout."""
        main_layout = QHBoxLayout()

        # Left side - Floor layout grid
        left_panel = QGroupBox("Floor Layout")
        left_layout = QVBoxLayout()

        self.grid_widget = FloorLayoutGridWidget(self.level, self.current_layout, self)
        self.grid_widget.layout_changed.connect(self.on_layout_changed)
        left_layout.addWidget(self.grid_widget)

        left_panel.setLayout(left_layout)
        main_layout.addWidget(left_panel, 3)

        # Right side - Room palette
        right_panel = QGroupBox("Room Palette")
        right_layout = QVBoxLayout()

        self.palette_widget = RoomPaletteWidget(self.level, self)
        right_layout.addWidget(self.palette_widget)

        right_panel.setLayout(right_layout)
        main_layout.addWidget(right_panel, 1)

        self.setLayout(main_layout)

    def on_layout_changed(self):
        """Handle layout changes."""
        # Could add auto-save or dirty flag here
        pass

    def refresh(self):
        """Refresh the entire tab."""
        self.palette_widget.refresh_rooms()
        self.grid_widget.rebuild_grid()
