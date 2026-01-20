#!/bin/bash
# Local build script that replicates the GitHub Action for Windows Portable build
# This creates the exact same output as .github/workflows/build-tstauri-windows-portable.yml

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  tStauri Windows Portable Build (Local Test Build)         ║"
echo "║  Replicates: .github/workflows/build-tstauri-windows-portable.yml  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."
echo ""

# Check Nim
if ! command -v nim &> /dev/null; then
    echo "❌ Nim is not installed!"
    echo "   Install with: curl https://nim-lang.org/choosenim/init.sh -sSf | sh"
    exit 1
fi
NIM_VERSION=$(nim --version | head -n1 | awk '{print $4}')
echo "✓ Nim $NIM_VERSION"

# Check Emscripten
if ! command -v emcc &> /dev/null; then
    echo "❌ Emscripten is not installed!"
    echo "   Install with: ./setup-emscripten.sh"
    exit 1
fi
EMCC_VERSION=$(emcc --version | head -n1 | awk '{print $7}')
echo "✓ Emscripten $EMCC_VERSION"

# Check Rust
if ! command -v rustc &> /dev/null; then
    echo "❌ Rust is not installed!"
    echo "   Install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi
RUST_VERSION=$(rustc --version | awk '{print $2}')
echo "✓ Rust $RUST_VERSION"

# Check for Windows target
if ! rustup target list | grep -q "x86_64-pc-windows-gnu (installed)"; then
    echo "❌ Rust Windows target not installed!"
    echo "   Installing x86_64-pc-windows-gnu target..."
    rustup target add x86_64-pc-windows-gnu
    if [ $? -ne 0 ]; then
        echo "   Failed to install Windows target"
        exit 1
    fi
    echo "✓ Windows target installed"
else
    echo "✓ Rust target x86_64-pc-windows-gnu"
fi

# Check mingw-w64
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo "⚠️  mingw-w64 not found - attempting to install..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y gcc-mingw-w64-x86-64
    else
        echo "❌ Please install mingw-w64 manually:"
        echo "   Debian/Ubuntu: sudo apt-get install gcc-mingw-w64-x86-64"
        echo "   Arch: sudo pacman -S mingw-w64-gcc"
        echo "   macOS: brew install mingw-w64"
        exit 1
    fi
fi
echo "✓ mingw-w64 cross-compiler"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed!"
    echo "   Install from: https://nodejs.org/"
    exit 1
fi
NODE_VERSION=$(node --version)
echo "✓ Node.js $NODE_VERSION"

echo ""
echo "✅ All prerequisites satisfied"
echo ""

# Step 1: Build tStorie WASM for tStauri
echo "════════════════════════════════════════════════════════════════"
echo "  Step 1/6: Building tStorie WASM for tStauri"
echo "════════════════════════════════════════════════════════════════"
echo ""

chmod +x build-web-tauri.sh
./build-web-tauri.sh

if [ $? -ne 0 ]; then
    echo "❌ WASM build failed!"
    exit 1
fi

echo ""

# Step 2: Verify WASM files (matches GitHub Action verification)
echo "════════════════════════════════════════════════════════════════"
echo "  Step 2/6: Verifying WASM files"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Checking for required WASM files..."
echo ""
echo "Directory listing:"
ls -lh tstauri/dist-tstauri/ || echo "ERROR: dist-tstauri directory not found!"
echo ""

# Check each required file
if [ ! -f "tstauri/dist-tstauri/tstorie-webgl.js" ]; then
    echo "❌ ERROR: tstorie-webgl.js not found!"
    exit 1
else
    echo "✓ tstorie-webgl.js"
fi

if [ ! -f "tstauri/dist-tstauri/tstorie.wasm.js" ]; then
    echo "❌ ERROR: tstorie.wasm.js not found!"
    exit 1
else
    echo "✓ tstorie.wasm.js"
fi

if [ ! -f "tstauri/dist-tstauri/tstorie.wasm.wasm" ]; then
    echo "❌ ERROR: tstorie.wasm.wasm not found!"
    exit 1
else
    echo "✓ tstorie.wasm.wasm"
fi

if [ ! -f "tstauri/dist-tstauri/tstorie.js" ]; then
    echo "❌ ERROR: tstorie.js not found!"
    exit 1
else
    echo "✓ tstorie.js"
fi

if [ ! -f "tstauri/dist-tstauri/index.md" ]; then
    echo "❌ ERROR: index.md (welcome screen) not found!"
    echo "Checking if welcome.md source exists..."
    ls -lh tstauri/welcome.md || echo "  → welcome.md source is also missing!"
    exit 1
else
    echo "✓ index.md (welcome screen)"
    echo "  Preview:" 
    head -n 5 tstauri/dist-tstauri/index.md | sed 's/^/    /'
fi

if [ ! -d "tstauri/dist-tstauri/shaders" ]; then
    echo "❌ ERROR: shaders directory not found!"
    exit 1
else
    SHADER_COUNT=$(ls tstauri/dist-tstauri/shaders/*.js 2>/dev/null | wc -l)
    if [ "$SHADER_COUNT" -lt 10 ]; then
        echo "❌ ERROR: Expected at least 10 shaders, found $SHADER_COUNT"
        ls tstauri/dist-tstauri/shaders/
        exit 1
    else
        echo "✓ Shaders directory ($SHADER_COUNT shaders)"
    fi
fi

echo ""
echo "✅ All required files present and verified!"
echo ""

# Step 3: Generate App Icons
echo "════════════════════════════════════════════════════════════════"
echo "  Step 3/6: Generating App Icons"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd tstauri
bash generate-icons.sh
cd ..

echo ""

# Step 4: Install frontend dependencies
echo "════════════════════════════════════════════════════════════════"
echo "  Step 4/6: Installing frontend dependencies"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd tstauri
npm install
cd ..

echo ""

# Step 5: Build Vite frontend
echo "════════════════════════════════════════════════════════════════"
echo "  Step 5/6: Building Vite frontend"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd tstauri
npm run vite:build
cd ..

echo ""

# Step 6: Build Windows executable (cross-compile from Linux)
echo "════════════════════════════════════════════════════════════════"
echo "  Step 6/6: Building Windows executable (cross-compile)"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd tstauri
npm run tauri build -- --target x86_64-pc-windows-gnu
cd ..

echo ""

# Step 7: Package portable Windows build
echo "════════════════════════════════════════════════════════════════"
echo "  Step 7/7: Packaging portable Windows build"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd tstauri
bash package-windows.sh
cd ..

echo ""

# Verify package contents
echo "════════════════════════════════════════════════════════════════"
echo "  Verifying package contents"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Checking package contents..."
cd tstauri/dist/tstauri-windows-portable
ls -lh
echo ""
echo "Verifying critical files..."
[ -f "tstauri.exe" ] && echo "✓ tstauri.exe (all-in-one binary)" || echo "✗ tstauri.exe MISSING"
[ -f "WebView2Loader.dll" ] && echo "✓ WebView2Loader.dll (required)" || echo "✗ WebView2Loader.dll MISSING"
[ -f "run-tstauri.bat" ] && echo "✓ run-tstauri.bat (launcher)" || echo "✗ run-tstauri.bat MISSING"
[ -f "README.txt" ] && echo "✓ README.txt" || echo "✗ README.txt MISSING"
cd ../../..
echo ""
echo "Note: WASM files, UI, and welcome screen are bundled inside tstauri.exe"
echo ""

# Get package size
SIZE=$(du -h tstauri/dist/tstauri-windows-portable.zip | cut -f1)
echo "📦 Package size: $SIZE"
echo ""

# Final output
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           ✅ Windows Portable Build Complete!               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Output location:"
echo "   tstauri/dist/tstauri-windows-portable.zip"
echo ""
echo "📁 Package contents:"
echo "   tstauri/dist/tstauri-windows-portable/"
echo ""
echo "🧪 To test on Windows:"
echo "   1. Transfer tstauri-windows-portable.zip to a Windows machine"
echo "   2. Extract the ZIP file"
echo "   3. Run run-tstauri.bat (recommended) or tstauri.exe"
echo ""
echo "💡 This build matches exactly what the GitHub Action produces!"
echo ""

