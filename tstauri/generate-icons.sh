#!/bin/bash
# Generate Tauri app icons from tStorie favicon

set -e

SOURCE_ICON="$(dirname "$0")/../docs/favicon.png"
ICONS_DIR="$(dirname "$0")/src-tauri/icons"

echo "🎨 Generating tStauri icons from $SOURCE_ICON"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not found. Please install it:"
    echo "   macOS: brew install imagemagick"
    echo "   Ubuntu: sudo apt install imagemagick"
    echo "   Windows: Download from https://imagemagick.org/"
    exit 1
fi

# Create icons directory
mkdir -p "$ICONS_DIR"

# Generate PNG icons
echo "📐 Generating PNG icons..."
convert "$SOURCE_ICON" -resize 32x32 "$ICONS_DIR/32x32.png"
convert "$SOURCE_ICON" -resize 128x128 "$ICONS_DIR/128x128.png"
convert "$SOURCE_ICON" -resize 256x256 "$ICONS_DIR/128x128@2x.png"
convert "$SOURCE_ICON" -resize 512x512 "$ICONS_DIR/icon.png"

# Generate macOS .icns
echo "🍎 Generating macOS icon..."
ICONSET="$ICONS_DIR/icon.iconset"
mkdir -p "$ICONSET"

for size in 16 32 64 128 256 512; do
    convert "$SOURCE_ICON" -resize ${size}x${size} "$ICONSET/icon_${size}x${size}.png"
    convert "$SOURCE_ICON" -resize $((size*2))x$((size*2)) "$ICONSET/icon_${size}x${size}@2x.png"
done

# Create .icns (macOS only, but we'll try)
if command -v iconutil &> /dev/null; then
    iconutil -c icns "$ICONSET" -o "$ICONS_DIR/icon.icns"
    rm -rf "$ICONSET"
    echo "✓ Generated icon.icns"
else
    echo "⚠️  iconutil not found (macOS only) - .icns will be generated during macOS build"
    # Keep the iconset for the build process
fi

# Generate Windows .ico
echo "🪟 Generating Windows icon..."
convert "$SOURCE_ICON" -define icon:auto-resize=256,128,64,48,32,16 "$ICONS_DIR/icon.ico"

echo "✅ Icon generation complete!"
echo ""
echo "Generated files in $ICONS_DIR:"
ls -lh "$ICONS_DIR" | grep -E '\.(png|ico|icns)$' || ls -lh "$ICONS_DIR"
