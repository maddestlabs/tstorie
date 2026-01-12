#!/bin/bash
# Build tStauri for Windows from Linux

set -e

echo "🪟 Building tStauri for Windows (x86_64)"
echo ""

# Check if cross-compilation is set up
if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    echo "❌ MinGW-w64 not found. Run setup first:"
    echo "   bash setup-windows-cross.sh"
    exit 1
fi

# Check if Windows target is installed
if ! rustup target list | grep -q "x86_64-pc-windows-gnu (installed)"; then
    echo "📦 Adding Windows target..."
    rustup target add x86_64-pc-windows-gnu
fi

# Build WASM first (if not already built)
if [ ! -f "../docs/tstorie.wasm.wasm" ]; then
    echo "🔨 Building tStorie WASM first..."
    cd ..
    ./build-web.sh -o docs
    cd tstauri
fi

# Generate icons if needed
if [ ! -f "src-tauri/icons/icon.ico" ]; then
    echo "🎨 Generating icons..."
    bash generate-icons.sh
fi

# Install npm dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing npm dependencies..."
    npm install
fi

echo "🔨 Building for Windows..."
echo "   Target: x86_64-pc-windows-gnu"
echo "   This may take 5-10 minutes..."
echo ""

# Use npm run tauri to properly bundle frontend assets into the binary
npm run tauri build -- --target x86_64-pc-windows-gnu

echo ""
echo "✅ Windows build complete!"
echo ""
echo "Output location:"
echo "   Binary: src-tauri/target/x86_64-pc-windows-gnu/release/tstauri.exe"
echo ""
echo "⚠️  Note: Frontend assets are now bundled in the .exe"
echo "   For MSI installer, use GitHub Actions"
echo ""
echo "To test on Windows:"
echo "   1. Copy tstauri.exe to a Windows machine"
echo "   2. Copy these files alongside it:"
echo "      - WebView2Loader.dll (from target/x86_64-pc-windows-gnu/release/)"
echo "      - ../docs/tstorie.js"
echo "      - ../docs/tstorie.wasm.js"
echo "      - ../docs/tstorie.wasm.wasm"
echo "   3. Run tstauri.exe"
echo ""
