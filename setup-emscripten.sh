#!/bin/bash
# Setup Emscripten for Storie web builds

set -e

EMSDK_DIR="${EMSDK_DIR:-$HOME/.emsdk}"

echo "Installing Emscripten SDK..."
echo "Install directory: $EMSDK_DIR"
echo ""

# Check if already installed
if [ -d "$EMSDK_DIR" ] && [ -f "$EMSDK_DIR/emsdk" ]; then
    echo "Emscripten SDK already installed at $EMSDK_DIR"
    echo "Activating latest version..."
    cd "$EMSDK_DIR"
    ./emsdk activate latest
else
    echo "Cloning Emscripten SDK..."
    git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
    
    cd "$EMSDK_DIR"
    
    echo ""
    echo "Installing latest Emscripten..."
    ./emsdk install latest
    
    echo ""
    echo "Activating Emscripten..."
    ./emsdk activate latest
fi

echo ""
echo "✓ Emscripten setup complete!"
echo ""
echo "To use Emscripten in your current shell:"
echo "  source $EMSDK_DIR/emsdk_env.sh"
echo ""
echo "To add to your shell profile permanently:"
echo "  echo 'source \"$EMSDK_DIR/emsdk_env.sh\"' >> ~/.bashrc"
echo "  # or for zsh:"
echo "  echo 'source \"$EMSDK_DIR/emsdk_env.sh\"' >> ~/.zshrc"
echo ""
echo "Now you can build for web with:"
echo "  ./build-web.sh"
