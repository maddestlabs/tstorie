#!/bin/bash
# Complete tStauri build script
# Builds WASM engine, then desktop app

set -e

echo "╔══════════════════════════════════════════╗"
echo "║     tStauri Complete Build Process      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Step 1: Build tStorie WASM with custom welcome screen
echo "📦 Step 1/3: Building tStorie WASM engine..."
./build-web-tauri.sh

if [ $? -ne 0 ]; then
    echo "❌ WASM build failed!"
    exit 1
fi

echo ""
echo "✓ WASM build complete"
echo ""

# Step 2: Build Vite frontend
echo "🎨 Step 2/3: Building Vite frontend..."
cd tstauri
npm run vite:build

if [ $? -ne 0 ]; then
    echo "❌ Vite build failed!"
    exit 1
fi

echo ""
echo "✓ Frontend build complete"
echo ""

# Step 3: Build Tauri app
echo "🖥️  Step 3/3: Building Tauri desktop app..."
npm run tauri build

if [ $? -ne 0 ]; then
    echo "❌ Tauri build failed!"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       ✓ tStauri Build Complete!        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Desktop app built successfully!"
echo ""
echo "Output locations:"
echo "  Linux:   tstauri/src-tauri/target/release/tstauri"
echo "  Windows: tstauri/src-tauri/target/release/tstauri.exe"
echo "  Bundle:  tstauri/src-tauri/target/release/bundle/"
echo ""
