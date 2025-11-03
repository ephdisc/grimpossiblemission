#!/bin/bash

# Installation script for GrimpossibleMission Level Editor

echo "Installing GrimpossibleMission Level Editor..."
echo ""

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

echo "Python version:"
python3 --version
echo ""

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo ""
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install PyQt5
echo "Installing PyQt5..."
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo ""
    echo "Installation complete!"
    echo ""
    echo "To run the level editor:"
    echo "  ./run.sh"
    echo ""
    echo "Or manually:"
    echo "  source venv/bin/activate"
    echo "  python level_editor.py"
    echo ""
else
    echo ""
    echo "Installation failed. Please check the error messages above."
    exit 1
fi
