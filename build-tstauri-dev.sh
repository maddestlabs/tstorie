#!/bin/bash
# tStauri WASM + Frontend build (no desktop binary)
# Use this for development when you don't need to build the full executable

set -e

echo "╔══════════════════════════════════════════╗"
echo "║   tStauri Dev Build (WASM + Frontend)   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Step 1: Build tStorie WASM with custom welcome screen
echo "📦 Step 1/2: Building tStorie WASM engine..."
./build-web-tauri.sh

if [ $? -ne 0 ]; then
    echo "❌ WASM build failed!"
    exit 1
fi

echo ""
echo "✓ WASM build complete"
echo ""

# Step 2: Build Vite frontend
echo "🎨 Step 2/2: Building Vite frontend..."
cd tstauri
npm run vite:build

if [ $? -ne 0 ]; then
    echo "❌ Vite build failed!"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║    ✓ tStauri Dev Build Complete!       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "WASM and frontend assets are ready in:"
echo "  - tstauri/dist-tstauri/ (WASM files)"
echo "  - tstauri/dist-frontend/ (HTML/JS/CSS)"
echo ""
echo "To test in dev mode:"
echo "  cd tstauri && npm run dev"
echo ""
echo "To build the desktop executable:"
echo "  ./build-tstauri-complete.sh"
echo "  (requires system dependencies on Linux)"
echo ""
