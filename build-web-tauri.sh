#!/bin/bash
# Build tStorie WASM for tStauri desktop app
# This creates a separate build with a custom welcome screen

set -e

echo "========================================"
echo "  tStauri Web Build"
echo "========================================"
echo ""

# Build tStorie to tstauri-specific directory
OUTPUT_DIR="tstauri/dist-tstauri"

echo "Step 1: Building tStorie WASM..."
./build-web.sh -o "$OUTPUT_DIR"

if [ $? -ne 0 ]; then
    echo "❌ WASM build failed!"
    exit 1
fi

echo ""
echo "Step 2: Installing custom welcome screen..."

# Copy the custom welcome.md as index.md
if [ -f "tstauri/welcome.md" ]; then
    cp tstauri/welcome.md "$OUTPUT_DIR/index.md"
    echo "  ✓ Installed tstauri/welcome.md as index.md"
else
    echo "  ⚠ Warning: tstauri/welcome.md not found, using default"
fi

# Copy shaders directory for offline shader support
if [ -d "docs/shaders" ]; then
    mkdir -p "$OUTPUT_DIR/shaders"
    cp docs/shaders/*.js "$OUTPUT_DIR/shaders/" 2>/dev/null || true
    cp docs/shaders/*.md "$OUTPUT_DIR/shaders/" 2>/dev/null || true
    echo "  ✓ Copied shaders directory ($(ls docs/shaders/*.js 2>/dev/null | wc -l) shaders)"
else
    echo "  ⚠ Warning: docs/shaders not found, shaders will load from Gist only"
fi

# Ensure index.html exists (copy from web/ if needed)
if [ ! -f "$OUTPUT_DIR/index.html" ]; then
    if [ -f "web/index.html" ]; then
        cp web/index.html "$OUTPUT_DIR/index.html"
        echo "  ✓ Copied web/index.html"
    fi
fi

echo ""
echo "========================================"
echo "  ✓ tStauri Web Build Complete!"
echo "========================================"
echo ""
echo "Output directory: $OUTPUT_DIR/"
echo ""
echo "Files created:"
echo "  - $OUTPUT_DIR/tstorie.wasm.wasm"
echo "  - $OUTPUT_DIR/tstorie.wasm.js"
echo "  - $OUTPUT_DIR/tstorie.js"
echo "  - $OUTPUT_DIR/tstorie-webgl.js"
echo "  - $OUTPUT_DIR/index.html"
echo "  - $OUTPUT_DIR/index.md (custom welcome screen)"
echo "  - $OUTPUT_DIR/shaders/ (local shader library)"
echo ""
echo "Next steps:"
echo "  cd tstauri && npm run build"
echo ""
