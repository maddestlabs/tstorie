#!/bin/bash
# Windows build script for TStorie (Unix-style)
# Can be used from WSL or Git Bash
# Usage: ./build-windows.sh [filename]
# Example: ./build-windows.sh examples/boxes.nim

echo "========================================"
echo "TStorie Windows Build (Cross-compile)"
echo "========================================"
echo ""

# Check if Nim is installed
if ! command -v nim &> /dev/null; then
    echo "ERROR: Nim compiler not found!"
    echo "Please install Nim from https://nim-lang.org/"
    exit 1
fi

# Set default file
USERFILE="${1:-index}"
USERFILE="${USERFILE%.nim}"  # Remove .nim extension if present

echo "Building: $USERFILE.nim"
echo "Target: Windows Console"
echo ""

# Compile for Windows (cross-compile if on Linux/WSL)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Native Windows
    nim c --path:nimini/src -d:release --opt:size -d:strip -d:useMalloc --passC:-flto --passL:-flto --passL:-s -d:userFile="$USERFILE" --out:tstorie.exe tstorie.nim
else
    # Cross-compile from Linux/Mac using MinGW
    echo "Cross-compiling for Windows..."
    
    # Check if MinGW is installed
    if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        echo "ERROR: MinGW-w64 not found!"
        echo "Install with: sudo apt-get install mingw-w64"
        exit 1
    fi
    
    nim c --path:nimini/src --os:windows --cpu:amd64 \
        --gcc.exe:x86_64-w64-mingw32-gcc \
        --gcc.linkerexe:x86_64-w64-mingw32-gcc \
        -d:release --opt:size -d:strip -d:useMalloc --passC:-flto --passL:-flto --passL:-s -d:userFile="$USERFILE" \
        --out:tstorie.exe tstorie.nim
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "Build successful!"
    echo "========================================"
    echo ""
    echo "Run with: tstorie.exe"
    echo ""
    echo "NOTE: For best results, use Windows Terminal"
    echo "      Legacy CMD may have limited support"
else
    echo ""
    echo "========================================"
    echo "Build failed!"
    echo "========================================"
    exit 1
fi
