# tStauri App Icons

Icons generated from `../../docs/favicon.png` using the `generate-icons.sh` script.

## Generated Files

- `32x32.png` - Small icon
- `128x128.png` - Medium icon
- `128x128@2x.png` - Retina medium icon
- `icon.png` - Large icon (512x512)
- `icon.ico` - Windows icon
- `icon.icns` - macOS icon (generated on macOS or during CI build)

## Regenerating Icons

```bash
cd tstauri
bash generate-icons.sh
```

This automatically generates all required icon sizes from the favicon.

## Manual Generation

If you want to use a different source image:

```bash
# Edit generate-icons.sh and change SOURCE_ICON path
# Or manually:
convert your-icon.png -resize 32x32 32x32.png
convert your-icon.png -resize 128x128 128x128.png
convert your-icon.png -resize 256x256 128x128@2x.png
convert your-icon.png -resize 512x512 icon.png

# macOS .icns (requires iconutil on macOS)
mkdir icon.iconset
for size in 16 32 64 128 256 512; do
  convert your-icon.png -resize ${size}x${size} icon.iconset/icon_${size}x${size}.png
done
iconutil -c icns icon.iconset

# Windows .ico
convert your-icon.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico
```

## Requirements

- ImageMagick (`convert` command)
- iconutil (macOS only, for .icns generation)

Recommended source image: 1024x1024 PNG with transparency
