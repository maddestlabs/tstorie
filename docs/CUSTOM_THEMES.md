# Custom Theme URL Parameters

TStorie now supports custom theme creation via URL parameters, allowing users to create, share, and customize color themes on-the-fly without modifying code.

## Features

### 1. Custom Hex Color Themes

You can now pass a custom theme as a URL parameter using 7 hex colors:

```
?theme=#001111#09343a#e0e0e0#909090#00d98e#ffff00#ff006e
```

**Format:** `#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB`

**Order:**
1. Background Primary (main background)
2. Background Secondary (panels, cards)
3. Foreground Primary (main text)
4. Foreground Secondary (muted text)
5. Accent 1 (headings, highlights)
6. Accent 2 (links, borders)
7. Accent 3 (emphasis, warnings)

### 2. Built-in Theme Names

Built-in themes still work as before:

```
?theme=dracula
?theme=nord
?theme=neotopia
```

### 3. Safe Fallback

If a custom theme fails to parse (wrong format, invalid hex, etc.), it automatically falls back to the Neotopia theme.

## Implementation

### Nim Side (lib/storie_themes.nim)

**New Functions:**

- `parseCustomTheme(hexString: string): Option[ThemeColors]`  
  Parses custom hex theme string into ThemeColors object

- `toHexString(color: tuple[r, g, b: uint8]): string`  
  Converts RGB tuple to hex string

- `toHexString(theme: ThemeColors): string`  
  Converts entire theme to shareable URL format

**Updated Function:**

- `getTheme(name: string): ThemeColors`  
  Now checks if theme is a custom hex string (starts with #) before falling back to default

### JavaScript Side

**theme-builder.js** - Utility library for building custom theme URLs:

- `TStorieThemes.parseCustomTheme()` - Parse hex theme string
- `TStorieThemes.buildThemeString()` - Build theme from color object
- `TStorieThemes.buildUrl()` - Create complete URL with theme
- `TStorieThemes.copyThemeUrl()` - Copy to clipboard
- `TStorieThemes.rgbToHex()` / `hexToRgb()` - Color conversions

## Tools

### Theme Builder HTML (docs/theme-builder.html)

Interactive theme builder with:
- Color pickers for all 7 theme colors
- Load built-in themes as starting point
- Real-time hex value sync
- URL generation and clipboard copy
- Live preview iframe
- All 13 built-in themes included

**Usage:**
```
http://localhost:8001/theme-builder.html
```

### Theme Customizer Demo (docs/demos/theme-customizer.md)

TStorie markdown demo that:
- Displays current theme colors
- Lists available built-in themes
- Shows shareable URL format
- Supports URL params for individual colors
- Includes visual TUI preview
- Provides usage examples

**Usage:**
```
http://localhost:8001/?content=demo:theme-customizer
http://localhost:8001/?content=demo:theme-customizer&theme=dracula
http://localhost:8001/?content=demo:theme-customizer&theme=#ff00ff#00ff00#ffffff#cccccc#ff0000#00ff00#0000ff
```

## Scripting API

Scripts can access theme parameters using existing `getParam()` function:

```nim
import storie_themes

# Get theme from URL
let themeParam = getParam("theme")
let currentTheme = getTheme(themeParam)  # Handles both built-in and custom

# Get shareable URL format
let themeHex = toHexString(currentTheme)
print("Share URL: ?theme=" & themeHex)

# Parse custom colors if provided
if themeParam.startsWith("#"):
  let custom = parseCustomTheme(themeParam)
  if custom.isSome:
    print("Custom theme detected!")
```

Individual color overrides (for theme builder UI):

```nim
# Override specific colors via URL params
let bg1 = getParam("bg1")  # e.g., ?bg1=001111
let acc1 = getParam("acc1")  # e.g., ?acc1=ff2671
```

## Examples

### Basic Custom Theme

```
?theme=#001111#09343a#e0e0e0#909090#00d98e#ffff00#ff006e
```

### Built-in Theme with Content

```
?theme=dracula&content=demo:tui3
```

### Custom Theme with Demo

```
?theme=#1a0033#2d0055#f0f0ff#8b5cf6#ff006e#00f5ff#ffbe0b&content=demo:theme-customizer
```

### Individual Color Override (for builder)

```
?bg1=000000&bg2=111111&fg1=ffffff&fg2=cccccc&acc1=ff00ff&acc2=00ffff&acc3=ffff00
```

## Benefits

- ✅ **No database needed** - themes are in the URL
- ✅ **Easy sharing** - copy and paste URLs
- ✅ **Backwards compatible** - built-in themes still work
- ✅ **Safe fallback** - invalid themes use default
- ✅ **Simple format** - just 7 hex colors
- ✅ **Interactive tools** - builder and preview included
- ✅ **Script accessible** - getParam() API works

## Testing

### Test Custom Theme

```bash
# Start server
cd /workspaces/telestorie/docs
python3 -m http.server 8001

# Visit in browser:
# http://localhost:8001/?theme=#001111#09343a#e0e0e0#909090#00d98e#ffff00#ff006e
```

### Test Theme Builder

```
http://localhost:8001/theme-builder.html
```

### Test Customizer Demo

```
http://localhost:8001/?content=demo:theme-customizer
```

## Files Modified/Created

**Modified:**
- `lib/storie_themes.nim` - Added parseCustomTheme(), toHexString(), updated getTheme()

**Created:**
- `docs/theme-builder.js` - JavaScript utility library
- `docs/theme-builder.html` - Interactive theme builder
- `docs/demos/theme-customizer.md` - TStorie demo script

## Future Enhancements

Possible additions:
- Theme gallery/marketplace
- Import/export .json theme files
- Color contrast checker
- Accessibility scoring
- Theme variations (light/dark toggle)
- Preset color palettes
- Random theme generator
