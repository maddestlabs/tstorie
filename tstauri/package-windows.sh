#!/bin/bash
# Package Windows build with all required files for easy testing

set -e

WINDOWS_BUILD="src-tauri/target/x86_64-pc-windows-gnu/release/tstauri.exe"
PACKAGE_DIR="dist/tstauri-windows-portable"

if [ ! -f "$WINDOWS_BUILD" ]; then
    echo "❌ Windows build not found. Run ./build-windows.sh first"
    exit 1
fi

echo "📦 Creating portable Windows package..."

# Create package directory
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Download WebView2 bootstrapper if not present
BOOTSTRAPPER="$PACKAGE_DIR/MicrosoftEdgeWebview2Setup.exe"
if [ ! -f "$BOOTSTRAPPER" ]; then
    echo "📥 Downloading WebView2 bootstrapper..."
    curl -L -o "$BOOTSTRAPPER" "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
    if [ $? -eq 0 ]; then
        echo "✓ WebView2 bootstrapper downloaded"
    else
        echo "⚠️  Failed to download bootstrapper, continuing without it"
    fi
fi

# Copy executable
echo "📄 Copying tstauri.exe..."
cp "$WINDOWS_BUILD" "$PACKAGE_DIR/"

# Copy WebView2Loader.dll (required for WebView2 to work)
echo "📄 Copying WebView2Loader.dll..."
DLL_PATH="src-tauri/target/x86_64-pc-windows-gnu/release/WebView2Loader.dll"
if [ -f "$DLL_PATH" ]; then
    cp "$DLL_PATH" "$PACKAGE_DIR/"
    echo "✓ WebView2Loader.dll copied"
else
    echo "⚠️  WebView2Loader.dll not found at $DLL_PATH"
fi

# Note: Frontend files (index.html, main.js) are now bundled IN the .exe
# No need to copy them separately

# Copy WASM files (still loaded externally for now)
echo "📄 Copying WASM engine..."
cp ../docs/tstorie.js "$PACKAGE_DIR/"
cp ../docs/tstorie.wasm.js "$PACKAGE_DIR/"
cp ../docs/tstorie.wasm.wasm "$PACKAGE_DIR/"
echo "✓ WASM files copied"

# Create a README for Windows users
cat > "$PACKAGE_DIR/README.txt" << 'EOF'
tStauri - Desktop tStorie Runner
================================

Quick Start:

RECOMMENDED - Use the launcher:
   Double-click: run-tstauri.bat
   This will auto-install WebView2 if needed (one-time).

OR directly:
   Double-click: tstauri.exe
   If you see a WebView2 error, run: MicrosoftEdgeWebview2Setup.exe

What is WebView2?
   It's Microsoft's web rendering engine (like a mini browser).
   Windows 11 has it pre-installed.
   Windows 10 may need it installed (one-time, ~3MB download).

Usage:
   1. Launch tstauri.exe or run-tstauri.bat
   2. Drag and drop a .md file onto the window
   3. Watch your tStorie document run!

Keyboard Shortcuts:
   - Escape: Return to drop zone

Files in this folder:
   - tstauri.exe                          The application
   - WebView2Loader.dll                   Required for WebView2
   - run-tstauri.bat                      Launcher with auto-install
   - MicrosoftEdgeWebview2Setup.exe       WebView2 installer (if needed)
   - tstorie.js, tstorie.wasm.*          WASM engine files

Keep all files together in the same folder!

For more info: https://github.com/maddestlabs/tstorie
EOF

# Create a simple batch file launcher
cat > "$PACKAGE_DIR/run-tstauri.bat" << 'EOF'
@echo off
echo Starting tStauri...

REM Check if WebView2 is installed
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :run

REM WebView2 not found, try to install it
echo WebView2 not found. Installing...
if exist MicrosoftEdgeWebview2Setup.exe (
    echo Running WebView2 installer...
    start /wait MicrosoftEdgeWebview2Setup.exe /silent /install
    timeout /t 5 /nobreak >nul
)

:run
tstauri.exe
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error starting tStauri!
    echo If the app still doesn't start, WebView2 may not be installed.
    echo Please run MicrosoftEdgeWebview2Setup.exe manually.
    pause
)
EOF

# Create ZIP archive
echo "Creating ZIP archive..."
cd dist
zip -r tstauri-windows-portable.zip tstauri-windows-portable/
cd ..

echo ""
echo "✅ Portable Windows package created!"
echo ""
echo "📁 Package location:"
echo "   dist/tstauri-windows-portable/"
echo ""
echo "📦 ZIP archive:"
echo "   dist/tstauri-windows-portable.zip"
echo ""
echo "To test on Windows:"
echo "   1. Transfer the ZIP to a Windows machine"
echo "   2. Extract it"
echo "   3. Run tstauri.exe or run-tstauri.bat"
echo ""
echo "⚠️  Note: This is a portable build, not an installer"
echo "   For MSI installer, use GitHub Actions"
echo ""
