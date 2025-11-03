#!/bin/bash

# Run script for GrimpossibleMission Level Editor

cd "$(dirname "$0")"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running installation..."
    ./install.sh
fi

# Activate venv and run
source venv/bin/activate
python level_editor.py
