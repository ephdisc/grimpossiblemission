"""
TileCanvas widget for the level editor.

Provides a visual grid for editing room tiles with mouse and keyboard support.
"""

from PyQt5.QtWidgets import QWidget
from PyQt5.QtCore import Qt, QRect, pyqtSignal
from PyQt5.QtGui import QPainter, QColor, QPen, QBrush, QMouseEvent, QWheelEvent
from data_models import Room, TileType
from typing import Optional, Tuple


class TileCanvas(QWidget):
    """
    Interactive canvas for editing room tiles.

    Signals:
        tile_changed: Emitted when tiles are modified (for undo/redo)
        tile_type_selected: Emitted when user selects a tile type via keyboard (int)
    """

    tile_changed = pyqtSignal()
    tile_type_selected = pyqtSignal(int)

    def __init__(self, parent=None):
        super().__init__(parent)

        self.room: Optional[Room] = None
        self.current_tile_type = TileType.EMPTY
        self.tile_size = 12  # Base size in pixels
        self.zoom_level = 1.0
        self.brush_size = 1  # 1x1, 2x2, 3x3, etc.

        # Mouse state
        self.is_painting = False
        self.last_paint_pos: Optional[Tuple[int, int]] = None

        # View state
        self.show_grid = True
        self.show_coordinates = False

        # Selection state (for future fill/copy operations)
        self.selection_start: Optional[Tuple[int, int]] = None
        self.selection_end: Optional[Tuple[int, int]] = None

        # Colors for tile types
        self.tile_colors = {
            TileType.EMPTY: QColor(240, 240, 240),      # Light gray
            TileType.BLOCK: QColor(139, 90, 43),         # Brown
            TileType.PLATFORM: QColor(76, 175, 80),      # Green
            TileType.SPAWN: QColor(255, 0, 255),         # Magenta
            TileType.SEARCHABLE: QColor(244, 67, 54)     # Red
        }

        # UI settings
        self.grid_color = QColor(200, 200, 200)
        self.selection_color = QColor(0, 120, 215, 100)  # Semi-transparent blue

        # Set focus policy to receive keyboard events
        self.setFocusPolicy(Qt.StrongFocus)
        self.setMouseTracking(True)

        # Minimum size
        self.setMinimumSize(400, 300)

    def set_room(self, room: Optional[Room]):
        """Set the room to display and edit."""
        self.room = room
        self.update_size()
        self.update()

    def update_size(self):
        """Update the widget size based on room dimensions and zoom."""
        if self.room:
            effective_size = int(self.tile_size * self.zoom_level)
            width = self.room.get_interior_width() * effective_size
            height = self.room.get_interior_height() * effective_size
            self.setMinimumSize(width, height)
            self.resize(width, height)

    def set_tile_type(self, tile_type: int):
        """Set the current tile type for painting."""
        self.current_tile_type = tile_type

    def set_brush_size(self, size: int):
        """Set the brush size (1x1, 2x2, 3x3, etc.)."""
        self.brush_size = max(1, size)

    def set_zoom(self, zoom: float):
        """Set the zoom level (1.0 = 100%)."""
        self.zoom_level = max(0.25, min(4.0, zoom))
        self.update_size()
        self.update()

    def zoom_in(self):
        """Increase zoom level."""
        self.set_zoom(self.zoom_level * 1.2)

    def zoom_out(self):
        """Decrease zoom level."""
        self.set_zoom(self.zoom_level / 1.2)

    def zoom_fit(self):
        """Zoom to fit the entire room in the viewport."""
        if self.room and self.parentWidget():
            parent_width = self.parentWidget().width()
            parent_height = self.parentWidget().height()

            room_width = self.room.get_interior_width()
            room_height = self.room.get_interior_height()

            zoom_x = parent_width / (room_width * self.tile_size)
            zoom_y = parent_height / (room_height * self.tile_size)

            self.set_zoom(min(zoom_x, zoom_y) * 0.95)  # 95% to add padding

    def get_tile_at_pos(self, x: int, y: int) -> Optional[Tuple[int, int]]:
        """Convert pixel coordinates to tile coordinates."""
        if not self.room:
            return None

        effective_size = int(self.tile_size * self.zoom_level)
        tile_x = x // effective_size
        tile_y = y // effective_size

        if (0 <= tile_x < self.room.get_interior_width() and
            0 <= tile_y < self.room.get_interior_height()):
            return (tile_x, tile_y)

        return None

    def paint_tile(self, tile_x: int, tile_y: int, tile_type: int):
        """
        Paint a tile or area of tiles based on brush size.

        Args:
            tile_x: X coordinate of tile
            tile_y: Y coordinate of tile
            tile_type: Tile type to paint
        """
        if not self.room:
            return

        # Paint area based on brush size
        half_brush = self.brush_size // 2

        for dy in range(-half_brush, half_brush + 1):
            for dx in range(-half_brush, half_brush + 1):
                x = tile_x + dx
                y = tile_y + dy

                if (0 <= x < self.room.get_interior_width() and
                    0 <= y < self.room.get_interior_height()):
                    self.room.set_tile(x, y, tile_type)

        self.tile_changed.emit()
        self.update()

    def fill_selection(self, tile_type: int):
        """Fill the current selection with the given tile type."""
        if not self.room or not self.selection_start or not self.selection_end:
            return

        x1 = min(self.selection_start[0], self.selection_end[0])
        x2 = max(self.selection_start[0], self.selection_end[0])
        y1 = min(self.selection_start[1], self.selection_end[1])
        y2 = max(self.selection_start[1], self.selection_end[1])

        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                if (0 <= x < self.room.get_interior_width() and
                    0 <= y < self.room.get_interior_height()):
                    self.room.set_tile(x, y, tile_type)

        self.tile_changed.emit()
        self.update()

    def clear_room(self):
        """Clear all tiles in the room."""
        if not self.room:
            return

        for y in range(self.room.get_interior_height()):
            for x in range(self.room.get_interior_width()):
                self.room.set_tile(x, y, TileType.EMPTY)

        self.tile_changed.emit()
        self.update()

    def paintEvent(self, event):
        """Draw the tile grid."""
        if not self.room:
            return

        painter = QPainter(self)
        effective_size = int(self.tile_size * self.zoom_level)

        # Draw tiles
        for y in range(self.room.get_interior_height()):
            for x in range(self.room.get_interior_width()):
                tile_type = self.room.get_tile(x, y)
                color = self.tile_colors.get(tile_type, QColor(255, 255, 255))

                rect = QRect(
                    x * effective_size,
                    y * effective_size,
                    effective_size,
                    effective_size
                )

                painter.fillRect(rect, color)

        # Draw grid lines
        if self.show_grid:
            painter.setPen(QPen(self.grid_color, 1))

            # Vertical lines
            for x in range(self.room.get_interior_width() + 1):
                x_pos = x * effective_size
                painter.drawLine(
                    x_pos, 0,
                    x_pos, self.room.get_interior_height() * effective_size
                )

            # Horizontal lines
            for y in range(self.room.get_interior_height() + 1):
                y_pos = y * effective_size
                painter.drawLine(
                    0, y_pos,
                    self.room.get_interior_width() * effective_size, y_pos
                )

        # Draw selection
        if self.selection_start and self.selection_end:
            x1 = min(self.selection_start[0], self.selection_end[0])
            x2 = max(self.selection_start[0], self.selection_end[0])
            y1 = min(self.selection_start[1], self.selection_end[1])
            y2 = max(self.selection_start[1], self.selection_end[1])

            selection_rect = QRect(
                x1 * effective_size,
                y1 * effective_size,
                (x2 - x1 + 1) * effective_size,
                (y2 - y1 + 1) * effective_size
            )

            painter.fillRect(selection_rect, self.selection_color)
            painter.setPen(QPen(QColor(0, 120, 215), 2))
            painter.drawRect(selection_rect)

        # Draw coordinates if enabled
        if self.show_coordinates:
            painter.setPen(QPen(QColor(0, 0, 0), 1))
            for y in range(0, self.room.get_interior_height(), 5):
                for x in range(0, self.room.get_interior_width(), 5):
                    text = f"{x},{y}"
                    painter.drawText(
                        x * effective_size + 2,
                        y * effective_size + 12,
                        text
                    )

    def mousePressEvent(self, event: QMouseEvent):
        """Handle mouse press for painting or selection."""
        tile_pos = self.get_tile_at_pos(event.x(), event.y())

        if not tile_pos:
            return

        if event.button() == Qt.LeftButton:
            # Start painting
            self.is_painting = True
            self.last_paint_pos = tile_pos
            self.paint_tile(tile_pos[0], tile_pos[1], self.current_tile_type)

        elif event.button() == Qt.RightButton:
            # Erase (paint empty)
            self.is_painting = True
            self.last_paint_pos = tile_pos
            self.paint_tile(tile_pos[0], tile_pos[1], TileType.EMPTY)

        elif event.button() == Qt.MiddleButton:
            # Start selection
            self.selection_start = tile_pos
            self.selection_end = tile_pos
            self.update()

    def mouseMoveEvent(self, event: QMouseEvent):
        """Handle mouse movement for drag painting or selection."""
        tile_pos = self.get_tile_at_pos(event.x(), event.y())

        if not tile_pos:
            return

        if self.is_painting and tile_pos != self.last_paint_pos:
            # Continue painting
            if event.buttons() & Qt.LeftButton:
                self.paint_tile(tile_pos[0], tile_pos[1], self.current_tile_type)
            elif event.buttons() & Qt.RightButton:
                self.paint_tile(tile_pos[0], tile_pos[1], TileType.EMPTY)

            self.last_paint_pos = tile_pos

        elif self.selection_start and event.buttons() & Qt.MiddleButton:
            # Update selection
            self.selection_end = tile_pos
            self.update()

    def mouseReleaseEvent(self, event: QMouseEvent):
        """Handle mouse release to stop painting."""
        if event.button() in (Qt.LeftButton, Qt.RightButton):
            self.is_painting = False
            self.last_paint_pos = None

    def wheelEvent(self, event: QWheelEvent):
        """Handle mouse wheel for zooming."""
        if event.modifiers() & Qt.ControlModifier:
            # Zoom with Ctrl+Wheel
            if event.angleDelta().y() > 0:
                self.zoom_in()
            else:
                self.zoom_out()
            event.accept()
        else:
            event.ignore()

    def keyPressEvent(self, event):
        """Handle keyboard input."""
        # Number keys for tile type selection
        if Qt.Key_0 <= event.key() <= Qt.Key_9:
            num = event.key() - Qt.Key_0
            if num in TileType.get_all_types():
                self.current_tile_type = num
                self.tile_type_selected.emit(num)
                event.accept()
                return

        # Delete/Backspace to clear selection
        if event.key() in (Qt.Key_Delete, Qt.Key_Backspace):
            if self.selection_start and self.selection_end:
                self.fill_selection(TileType.EMPTY)
                event.accept()
                return

        # F key to fill selection
        if event.key() == Qt.Key_F:
            if self.selection_start and self.selection_end:
                self.fill_selection(self.current_tile_type)
                event.accept()
                return

        # Escape to clear selection
        if event.key() == Qt.Key_Escape:
            self.selection_start = None
            self.selection_end = None
            self.update()
            event.accept()
            return

        event.ignore()
