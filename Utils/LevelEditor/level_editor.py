#!/usr/bin/env python3
"""
GrimpossibleMission Level Editor

A standalone GUI application for creating room layouts and level configurations.
"""

import sys
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QTabWidget, QWidget, QVBoxLayout, QHBoxLayout,
    QListWidget, QPushButton, QLabel, QSpinBox, QComboBox, QGroupBox,
    QRadioButton, QButtonGroup, QScrollArea, QMessageBox, QFileDialog,
    QAction, QToolBar, QColorDialog, QDialog, QTextEdit, QLineEdit,
    QFormLayout, QListWidgetItem, QInputDialog
)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QKeySequence, QIcon, QColor

from data_models import Room, Level, TileType, LayoutEntry
from tile_canvas import TileCanvas
from layout_editor import LayoutEditorTab
from typing import Optional, List, Dict, Any


class UndoStack:
    """Simple undo/redo stack for room edits."""

    def __init__(self, max_size: int = 100):
        self.max_size = max_size
        self.undo_stack: List[Any] = []
        self.redo_stack: List[Any] = []

    def push(self, state: Any):
        """Push a new state onto the undo stack."""
        self.undo_stack.append(state)
        if len(self.undo_stack) > self.max_size:
            self.undo_stack.pop(0)
        self.redo_stack.clear()

    def can_undo(self) -> bool:
        """Check if undo is available."""
        return len(self.undo_stack) > 0

    def can_redo(self) -> bool:
        """Check if redo is available."""
        return len(self.redo_stack) > 0

    def undo(self) -> Optional[Any]:
        """Pop a state from undo stack."""
        if self.can_undo():
            state = self.undo_stack.pop()
            self.redo_stack.append(state)
            return state
        return None

    def redo(self) -> Optional[Any]:
        """Pop a state from redo stack."""
        if self.can_redo():
            state = self.redo_stack.pop()
            self.undo_stack.append(state)
            return state
        return None

    def clear(self):
        """Clear all stacks."""
        self.undo_stack.clear()
        self.redo_stack.clear()


class RoomEditorTab(QWidget):
    """Tab for editing individual rooms."""

    def __init__(self, level: Level, parent=None):
        super().__init__(parent)
        self.level = level
        self.current_room: Optional[Room] = None
        self.undo_stack = UndoStack()

        self.setup_ui()

    def setup_ui(self):
        """Set up the UI layout."""
        main_layout = QHBoxLayout()

        # Left sidebar - Room list
        left_sidebar = self.create_room_list_panel()
        main_layout.addWidget(left_sidebar, 1)

        # Center - Canvas with scroll area
        center_layout = QVBoxLayout()

        # Canvas in scroll area (must be created BEFORE toolbar)
        self.canvas = TileCanvas()
        self.canvas.tile_changed.connect(self.on_tile_changed)
        self.canvas.tile_type_selected.connect(self.update_tile_type_selector)

        # Toolbar above canvas
        toolbar = self.create_canvas_toolbar()
        center_layout.addWidget(toolbar)

        scroll_area = QScrollArea()
        scroll_area.setWidget(self.canvas)
        scroll_area.setWidgetResizable(False)
        center_layout.addWidget(scroll_area)

        main_layout.addLayout(center_layout, 3)

        # Right sidebar - Properties
        right_sidebar = self.create_properties_panel()
        main_layout.addWidget(right_sidebar, 1)

        self.setLayout(main_layout)

        # Create initial room if none exists
        if not self.level.rooms:
            self.create_new_room()

    def create_room_list_panel(self) -> QWidget:
        """Create the room list panel."""
        panel = QGroupBox("Rooms")
        layout = QVBoxLayout()

        self.room_list = QListWidget()
        self.room_list.currentItemChanged.connect(self.on_room_selected)
        layout.addWidget(self.room_list)

        # Buttons
        btn_new = QPushButton("New Room")
        btn_new.clicked.connect(self.create_new_room)
        layout.addWidget(btn_new)

        btn_duplicate = QPushButton("Duplicate")
        btn_duplicate.clicked.connect(self.duplicate_room)
        layout.addWidget(btn_duplicate)

        btn_delete = QPushButton("Delete Room")
        btn_delete.clicked.connect(self.delete_room)
        layout.addWidget(btn_delete)

        panel.setLayout(layout)
        return panel

    def create_canvas_toolbar(self) -> QWidget:
        """Create toolbar above the canvas."""
        toolbar = QWidget()
        layout = QHBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)

        # Tile palette
        palette_group = QGroupBox("Tile Palette")
        palette_layout = QVBoxLayout()

        self.tile_buttons = QButtonGroup()
        tile_types = [
            (TileType.EMPTY, "Empty (0)", "🔲"),
            (TileType.BLOCK, "Block (1)", "🟫"),
            (TileType.PLATFORM, "Platform (2)", "🟩"),
            (TileType.SPAWN, "Spawn (8)", "🟪"),
            (TileType.SEARCHABLE, "Searchable (9)", "🟥")
        ]

        for tile_id, name, icon in tile_types:
            btn = QRadioButton(f"{icon} {name}")
            btn.setProperty("tile_type", tile_id)
            btn.toggled.connect(lambda checked, t=tile_id: self.on_tile_type_selected(t) if checked else None)
            self.tile_buttons.addButton(btn, tile_id)
            palette_layout.addWidget(btn)

        # Select empty by default
        self.tile_buttons.button(TileType.EMPTY).setChecked(True)

        palette_group.setLayout(palette_layout)
        layout.addWidget(palette_group)

        # Brush size
        brush_group = QGroupBox("Brush")
        brush_layout = QVBoxLayout()

        brush_label = QLabel("Size:")
        brush_layout.addWidget(brush_label)

        self.brush_size_combo = QComboBox()
        self.brush_size_combo.addItems(["1x1", "2x2", "3x3", "4x4", "5x5"])
        self.brush_size_combo.currentIndexChanged.connect(self.on_brush_size_changed)
        brush_layout.addWidget(self.brush_size_combo)

        btn_fill = QPushButton("Fill Selection (F)")
        btn_fill.clicked.connect(self.fill_selection)
        brush_layout.addWidget(btn_fill)

        btn_clear = QPushButton("Clear Room")
        btn_clear.clicked.connect(self.clear_room)
        brush_layout.addWidget(btn_clear)

        brush_group.setLayout(brush_layout)
        layout.addWidget(brush_group)

        # Zoom controls
        zoom_group = QGroupBox("Zoom")
        zoom_layout = QVBoxLayout()

        btn_zoom_in = QPushButton("Zoom In (+)")
        btn_zoom_in.clicked.connect(self.canvas.zoom_in)
        zoom_layout.addWidget(btn_zoom_in)

        btn_zoom_out = QPushButton("Zoom Out (-)")
        btn_zoom_out.clicked.connect(self.canvas.zoom_out)
        zoom_layout.addWidget(btn_zoom_out)

        btn_zoom_fit = QPushButton("Zoom Fit")
        btn_zoom_fit.clicked.connect(self.canvas.zoom_fit)
        zoom_layout.addWidget(btn_zoom_fit)

        zoom_group.setLayout(zoom_layout)
        layout.addWidget(zoom_group)

        layout.addStretch()

        toolbar.setLayout(layout)
        return toolbar

    def create_properties_panel(self) -> QWidget:
        """Create the room properties panel."""
        panel = QGroupBox("Room Properties")
        layout = QFormLayout()

        # Room ID
        self.room_id_spin = QSpinBox()
        self.room_id_spin.setMinimum(1)
        self.room_id_spin.setMaximum(9999)
        self.room_id_spin.valueChanged.connect(self.on_room_id_changed)
        layout.addRow("Room ID:", self.room_id_spin)

        # Dimensions
        self.width_spin = QSpinBox()
        self.width_spin.setMinimum(10)
        self.width_spin.setMaximum(200)
        self.width_spin.setValue(64)
        self.width_spin.valueChanged.connect(self.on_dimensions_changed)
        layout.addRow("Width:", self.width_spin)

        self.height_spin = QSpinBox()
        self.height_spin.setMinimum(10)
        self.height_spin.setMaximum(200)
        self.height_spin.setValue(36)
        self.height_spin.valueChanged.connect(self.on_dimensions_changed)
        layout.addRow("Height:", self.height_spin)

        # Exits
        self.left_exit_combo = QComboBox()
        self.left_exit_combo.addItems(["None", "Doorway"])
        self.left_exit_combo.currentIndexChanged.connect(self.on_exits_changed)
        layout.addRow("Left Exit:", self.left_exit_combo)

        self.right_exit_combo = QComboBox()
        self.right_exit_combo.addItems(["None", "Doorway"])
        self.right_exit_combo.currentIndexChanged.connect(self.on_exits_changed)
        layout.addRow("Right Exit:", self.right_exit_combo)

        # Theme colors
        layout.addRow(QLabel(""))
        layout.addRow(QLabel("Theme Colors:"))

        self.wall_color_edit = QLineEdit("darkgray")
        btn_wall_color = QPushButton("Pick...")
        btn_wall_color.clicked.connect(lambda: self.pick_color(self.wall_color_edit, "wall_color"))
        color_layout = QHBoxLayout()
        color_layout.addWidget(self.wall_color_edit)
        color_layout.addWidget(btn_wall_color)
        layout.addRow("Wall Color:", color_layout)

        self.floor_color_edit = QLineEdit("gray")
        btn_floor_color = QPushButton("Pick...")
        btn_floor_color.clicked.connect(lambda: self.pick_color(self.floor_color_edit, "floor_color"))
        color_layout2 = QHBoxLayout()
        color_layout2.addWidget(self.floor_color_edit)
        color_layout2.addWidget(btn_floor_color)
        layout.addRow("Floor Color:", color_layout2)

        self.ceiling_color_edit = QLineEdit("gray")
        btn_ceiling_color = QPushButton("Pick...")
        btn_ceiling_color.clicked.connect(lambda: self.pick_color(self.ceiling_color_edit, "ceiling_color"))
        color_layout3 = QHBoxLayout()
        color_layout3.addWidget(self.ceiling_color_edit)
        color_layout3.addWidget(btn_ceiling_color)
        layout.addRow("Ceiling Color:", color_layout3)

        panel.setLayout(layout)
        return panel

    def refresh_room_list(self):
        """Refresh the room list display."""
        self.room_list.clear()
        for room in self.level.rooms:
            item = QListWidgetItem(f"Room {room.id} ({room.width}x{room.height})")
            item.setData(Qt.UserRole, room.id)
            self.room_list.addItem(item)

    def create_new_room(self):
        """Create a new room."""
        room_id = self.level.get_next_room_id()
        room = Room(room_id=room_id, width=64, height=36)

        if self.level.add_room(room):
            self.refresh_room_list()
            # Select the new room
            for i in range(self.room_list.count()):
                item = self.room_list.item(i)
                if item.data(Qt.UserRole) == room_id:
                    self.room_list.setCurrentItem(item)
                    break

    def duplicate_room(self):
        """Duplicate the current room."""
        if not self.current_room:
            return

        room_id = self.level.get_next_room_id()
        new_room = self.current_room.clone()
        new_room.id = room_id

        if self.level.add_room(new_room):
            self.refresh_room_list()
            # Select the new room
            for i in range(self.room_list.count()):
                item = self.room_list.item(i)
                if item.data(Qt.UserRole) == room_id:
                    self.room_list.setCurrentItem(item)
                    break

    def delete_room(self):
        """Delete the current room."""
        if not self.current_room:
            return

        reply = QMessageBox.question(
            self, "Delete Room",
            f"Are you sure you want to delete Room {self.current_room.id}?",
            QMessageBox.Yes | QMessageBox.No
        )

        if reply == QMessageBox.Yes:
            self.level.remove_room(self.current_room.id)
            self.current_room = None
            self.canvas.set_room(None)
            self.refresh_room_list()

            # Select first room if available
            if self.room_list.count() > 0:
                self.room_list.setCurrentRow(0)

    def on_room_selected(self, current, previous):
        """Handle room selection from list."""
        if current:
            room_id = current.data(Qt.UserRole)
            self.current_room = self.level.get_room(room_id)

            if self.current_room:
                self.canvas.set_room(self.current_room)
                self.load_room_properties()
                self.undo_stack.clear()

    def load_room_properties(self):
        """Load current room properties into the UI."""
        if not self.current_room:
            return

        # Block signals to prevent triggering change handlers
        self.room_id_spin.blockSignals(True)
        self.width_spin.blockSignals(True)
        self.height_spin.blockSignals(True)
        self.left_exit_combo.blockSignals(True)
        self.right_exit_combo.blockSignals(True)

        self.room_id_spin.setValue(self.current_room.id)
        self.width_spin.setValue(self.current_room.width)
        self.height_spin.setValue(self.current_room.height)

        # Exits
        self.left_exit_combo.setCurrentIndex(
            1 if self.current_room.exits.get("left") else 0
        )
        self.right_exit_combo.setCurrentIndex(
            1 if self.current_room.exits.get("right") else 0
        )

        # Theme colors
        self.wall_color_edit.setText(self.current_room.theme.get("wall_color", "darkgray"))
        self.floor_color_edit.setText(self.current_room.theme.get("floor_color", "gray"))
        self.ceiling_color_edit.setText(self.current_room.theme.get("ceiling_color", "gray"))

        # Unblock signals
        self.room_id_spin.blockSignals(False)
        self.width_spin.blockSignals(False)
        self.height_spin.blockSignals(False)
        self.left_exit_combo.blockSignals(False)
        self.right_exit_combo.blockSignals(False)

    def on_tile_type_selected(self, tile_type: int):
        """Handle tile type selection."""
        self.canvas.set_tile_type(tile_type)

    def on_brush_size_changed(self, index: int):
        """Handle brush size change."""
        size = index + 1  # 0->1, 1->2, 2->3, etc.
        self.canvas.set_brush_size(size)

    def on_tile_changed(self):
        """Handle tile changes for undo/redo."""
        if self.current_room:
            # Save state for undo
            from copy import deepcopy
            state = deepcopy(self.current_room.interior)
            self.undo_stack.push(state)

    def on_room_id_changed(self, new_id: int):
        """Handle room ID change."""
        if not self.current_room:
            return

        # Check for duplicate ID
        if any(r.id == new_id and r is not self.current_room for r in self.level.rooms):
            QMessageBox.warning(self, "Duplicate ID", f"Room ID {new_id} already exists!")
            self.room_id_spin.setValue(self.current_room.id)
            return

        self.current_room.id = new_id
        self.refresh_room_list()

    def on_dimensions_changed(self):
        """Handle room dimension changes."""
        if not self.current_room:
            return

        new_width = self.width_spin.value()
        new_height = self.height_spin.value()

        if new_width != self.current_room.width or new_height != self.current_room.height:
            self.current_room.resize(new_width, new_height)
            self.canvas.set_room(self.current_room)
            self.refresh_room_list()

    def on_exits_changed(self):
        """Handle exit configuration changes."""
        if not self.current_room:
            return

        self.current_room.exits["left"] = (
            {"type": "doorway"} if self.left_exit_combo.currentIndex() == 1 else None
        )
        self.current_room.exits["right"] = (
            {"type": "doorway"} if self.right_exit_combo.currentIndex() == 1 else None
        )

    def pick_color(self, line_edit: QLineEdit, color_key: str):
        """Open color picker dialog."""
        if not self.current_room:
            return

        color = QColorDialog.getColor()
        if color.isValid():
            color_name = color.name()
            line_edit.setText(color_name)
            self.current_room.theme[color_key] = color_name

    def fill_selection(self):
        """Fill the current selection."""
        self.canvas.fill_selection(self.canvas.current_tile_type)

    def clear_room(self):
        """Clear all tiles in the room."""
        if not self.current_room:
            return

        reply = QMessageBox.question(
            self, "Clear Room",
            "Are you sure you want to clear all tiles in this room?",
            QMessageBox.Yes | QMessageBox.No
        )

        if reply == QMessageBox.Yes:
            self.canvas.clear_room()

    def update_tile_type_selector(self, tile_type: int):
        """Update the tile type selector (called from canvas keyboard shortcut)."""
        btn = self.tile_buttons.button(tile_type)
        if btn:
            btn.setChecked(True)

    def undo(self):
        """Undo the last change."""
        if self.current_room and self.undo_stack.can_undo():
            state = self.undo_stack.undo()
            if state:
                from copy import deepcopy
                self.current_room.interior = deepcopy(state)
                self.canvas.update()

    def redo(self):
        """Redo the last undone change."""
        if self.current_room and self.undo_stack.can_redo():
            state = self.undo_stack.redo()
            if state:
                from copy import deepcopy
                self.current_room.interior = deepcopy(state)
                self.canvas.update()


class LevelEditor(QMainWindow):
    """Main window for the level editor."""

    def __init__(self):
        super().__init__()

        self.level = Level()
        self.current_filepath: Optional[str] = None
        self.unsaved_changes = False

        self.setWindowTitle("GrimpossibleMission Level Editor")
        self.setGeometry(100, 100, 1400, 900)

        self.setup_ui()
        self.setup_menu_bar()
        self.setup_toolbar()

    def setup_ui(self):
        """Set up the main UI."""
        # Create tab widget
        self.tabs = QTabWidget()
        self.tabs.currentChanged.connect(self.on_tab_changed)

        # Room editor tab
        self.room_editor = RoomEditorTab(self.level)
        self.tabs.addTab(self.room_editor, "Room Editor")

        # Layout editor tab
        self.layout_editor = LayoutEditorTab(self.level)
        self.tabs.addTab(self.layout_editor, "Layout Editor")

        self.setCentralWidget(self.tabs)

    def setup_menu_bar(self):
        """Set up the menu bar."""
        menubar = self.menuBar()

        # File menu
        file_menu = menubar.addMenu("&File")

        action_new = QAction("&New Level", self)
        action_new.setShortcut(QKeySequence.New)
        action_new.triggered.connect(self.new_level)
        file_menu.addAction(action_new)

        action_open = QAction("&Open...", self)
        action_open.setShortcut(QKeySequence.Open)
        action_open.triggered.connect(self.open_level)
        file_menu.addAction(action_open)

        file_menu.addSeparator()

        action_save = QAction("&Save", self)
        action_save.setShortcut(QKeySequence.Save)
        action_save.triggered.connect(self.save_level)
        file_menu.addAction(action_save)

        action_save_as = QAction("Save &As...", self)
        action_save_as.setShortcut(QKeySequence.SaveAs)
        action_save_as.triggered.connect(self.save_level_as)
        file_menu.addAction(action_save_as)

        file_menu.addSeparator()

        action_exit = QAction("E&xit", self)
        action_exit.setShortcut(QKeySequence.Quit)
        action_exit.triggered.connect(self.close)
        file_menu.addAction(action_exit)

        # Edit menu
        edit_menu = menubar.addMenu("&Edit")

        action_undo = QAction("&Undo", self)
        action_undo.setShortcut(QKeySequence.Undo)
        action_undo.triggered.connect(self.room_editor.undo)
        edit_menu.addAction(action_undo)

        action_redo = QAction("&Redo", self)
        action_redo.setShortcut(QKeySequence.Redo)
        action_redo.triggered.connect(self.room_editor.redo)
        edit_menu.addAction(action_redo)

        # Tools menu
        tools_menu = menubar.addMenu("&Tools")

        action_validate = QAction("&Validate Level", self)
        action_validate.triggered.connect(self.validate_level)
        tools_menu.addAction(action_validate)

        action_stats = QAction("&Statistics", self)
        action_stats.triggered.connect(self.show_statistics)
        tools_menu.addAction(action_stats)

    def setup_toolbar(self):
        """Set up the toolbar."""
        toolbar = QToolBar("Main Toolbar")
        self.addToolBar(toolbar)

        # New
        action_new = QAction("New", self)
        action_new.triggered.connect(self.new_level)
        toolbar.addAction(action_new)

        # Open
        action_open = QAction("Open", self)
        action_open.triggered.connect(self.open_level)
        toolbar.addAction(action_open)

        # Save
        action_save = QAction("Save", self)
        action_save.triggered.connect(self.save_level)
        toolbar.addAction(action_save)

        toolbar.addSeparator()

        # Undo/Redo
        action_undo = QAction("Undo", self)
        action_undo.triggered.connect(self.room_editor.undo)
        toolbar.addAction(action_undo)

        action_redo = QAction("Redo", self)
        action_redo.triggered.connect(self.room_editor.redo)
        toolbar.addAction(action_redo)

    def on_tab_changed(self, index):
        """Handle tab change events."""
        # If switching to Layout Editor tab, refresh it
        if index == 1:  # Layout Editor is the second tab (index 1)
            if hasattr(self, 'layout_editor'):
                self.layout_editor.refresh()

    def new_level(self):
        """Create a new level."""
        if self.unsaved_changes:
            reply = QMessageBox.question(
                self, "Unsaved Changes",
                "You have unsaved changes. Do you want to save before creating a new level?",
                QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel
            )

            if reply == QMessageBox.Save:
                self.save_level()
            elif reply == QMessageBox.Cancel:
                return

        self.level = Level()
        self.current_filepath = None
        self.unsaved_changes = False

        # Recreate tabs
        self.tabs.clear()
        self.room_editor = RoomEditorTab(self.level)
        self.tabs.addTab(self.room_editor, "Room Editor")
        self.layout_editor = LayoutEditorTab(self.level)
        self.tabs.addTab(self.layout_editor, "Layout Editor")

        self.setWindowTitle("GrimpossibleMission Level Editor - New Level")

    def open_level(self):
        """Open a level from JSON file."""
        filepath, _ = QFileDialog.getOpenFileName(
            self, "Open Level", "", "JSON Files (*.json);;All Files (*)"
        )

        if filepath:
            try:
                self.level = Level.from_json(filepath)
                self.current_filepath = filepath
                self.unsaved_changes = False

                # Recreate tabs with new level
                self.tabs.clear()
                self.room_editor = RoomEditorTab(self.level)
                self.tabs.addTab(self.room_editor, "Room Editor")
                self.layout_editor = LayoutEditorTab(self.level)
                self.tabs.addTab(self.layout_editor, "Layout Editor")

                self.setWindowTitle(f"GrimpossibleMission Level Editor - {filepath}")

                QMessageBox.information(self, "Success", "Level loaded successfully!")

            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to load level:\n{str(e)}")

    def save_level(self):
        """Save the current level."""
        if not self.current_filepath:
            self.save_level_as()
        else:
            try:
                self.level.to_json(self.current_filepath)
                self.unsaved_changes = False
                QMessageBox.information(self, "Success", "Level saved successfully!")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to save level:\n{str(e)}")

    def save_level_as(self):
        """Save the current level with a new filename."""
        filepath, _ = QFileDialog.getSaveFileName(
            self, "Save Level As", "", "JSON Files (*.json);;All Files (*)"
        )

        if filepath:
            if not filepath.endswith('.json'):
                filepath += '.json'

            try:
                self.level.to_json(filepath)
                self.current_filepath = filepath
                self.unsaved_changes = False
                self.setWindowTitle(f"GrimpossibleMission Level Editor - {filepath}")
                QMessageBox.information(self, "Success", "Level saved successfully!")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to save level:\n{str(e)}")

    def validate_level(self):
        """Validate the current level."""
        errors = self.level.validate()

        if errors:
            error_text = "\n".join(f"• {error}" for error in errors)
            QMessageBox.warning(
                self, "Validation Errors",
                f"The following errors were found:\n\n{error_text}"
            )
        else:
            QMessageBox.information(
                self, "Validation Success",
                "Level is valid! No errors found."
            )

    def show_statistics(self):
        """Show level statistics."""
        stats = []
        stats.append(f"Total Rooms: {len(self.level.rooms)}")
        stats.append(f"Layout Length: {len(self.level.layout)}")

        # Count tiles
        tile_counts = {t: 0 for t in TileType.get_all_types()}
        for room in self.level.rooms:
            for row in room.interior:
                for tile in row:
                    if tile in tile_counts:
                        tile_counts[tile] += 1

        stats.append("\nTile Counts:")
        for tile_type, count in tile_counts.items():
            name = TileType.get_name(tile_type)
            stats.append(f"  {name}: {count}")

        QMessageBox.information(
            self, "Level Statistics",
            "\n".join(stats)
        )

    def closeEvent(self, event):
        """Handle window close event."""
        if self.unsaved_changes:
            reply = QMessageBox.question(
                self, "Unsaved Changes",
                "You have unsaved changes. Do you want to save before exiting?",
                QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel
            )

            if reply == QMessageBox.Save:
                self.save_level()
                event.accept()
            elif reply == QMessageBox.Discard:
                event.accept()
            else:
                event.ignore()
        else:
            event.accept()


def main():
    """Main entry point."""
    app = QApplication(sys.argv)
    app.setApplicationName("GrimpossibleMission Level Editor")

    editor = LevelEditor()
    editor.show()

    sys.exit(app.exec_())


if __name__ == '__main__':
    main()
