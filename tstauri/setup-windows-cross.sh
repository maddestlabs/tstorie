#!/bin/bash
# Cross-compile tStauri for Windows on Linux
# This builds Windows binaries without needing a Windows machine

set -e

echo "🪟 tStauri Windows Cross-Compilation Setup"
echo ""

# Check if we're on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This script is for Linux only (cross-compiling to Windows)"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "📋 Checking prerequisites..."

# Check for Rust
if ! command_exists rustc; then
    echo "❌ Rust not found. Installing..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "✓ Rust installed: $(rustc --version)"
fi

# Check for mingw-w64
if ! command_exists x86_64-w64-mingw32-gcc; then
    echo "📦 Installing MinGW-w64 cross-compiler..."
    sudo apt update
    sudo apt install -y mingw-w64
else
    echo "✓ MinGW-w64 installed"
fi

# Add Windows target
echo "📦 Adding Windows target to Rust..."
rustup target add x86_64-pc-windows-gnu

# Install cargo-xwin for better Windows cross-compilation (optional but recommended)
if ! command_exists cargo-xwin; then
    echo "📦 Installing cargo-xwin for improved Windows builds..."
    cargo install cargo-xwin || echo "⚠️  cargo-xwin install failed, continuing with mingw..."
fi

# Create cargo config for cross-compilation
echo "⚙️  Configuring Cargo for Windows cross-compilation..."
mkdir -p .cargo
cat > .cargo/config.toml << 'EOF'
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "link-arg=-lws2_32", "-C", "link-arg=-luserenv"]
EOF

echo ""
echo "✅ Windows cross-compilation setup complete!"
echo ""
echo "To build for Windows, run:"
echo "  ./build-windows.sh"
echo ""
