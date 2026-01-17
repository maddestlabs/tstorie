# Front Matter Defaults for Fonts and Shaders

## Overview

TStorie now supports setting default fonts, font sizes, and shader chains directly in your markdown front matter. These settings are applied automatically when the document loads, with graceful fallback if resources aren't available.

**Key Features:**
- ✅ Works in both WASM (web) and Tauri (desktop) builds
- ✅ URL parameters take precedence over front matter
- ✅ Graceful failure if fonts/shaders can't be loaded
- ✅ Supports Google Fonts by name or full URL
- ✅ Supports shader chains with multiple effects

## Front Matter Properties

### `font`
Specifies a custom font to load. Can be:
- A Google Fonts name: `"Fira Code"`
- A Google Fonts URL: `"https://fonts.googleapis.com/css2?family=Fira+Code&display=swap"`

**Example:**
```yaml
---
font: "Press Start 2P"
---
```

### `fontsize`
Sets the font size in pixels.

**Example:**
```yaml
---
fontsize: 18
---
```

### `shaders`
Specifies a shader chain to apply. Multiple shaders can be chained using `+` or `;` separators.

Shaders are loaded from:
1. Local `shaders/` directory (e.g., `shaders/crt.js`)
2. GitHub Gist by ID (e.g., `abc123` loads from gist)

**Examples:**
```yaml
---
shaders: "crt"
---
```

```yaml
---
shaders: "grid2x1+sand+gradualblur"
---
```

```yaml
---
shaders: "invert;crt;scanlines"
---
```

## Complete Example

```yaml
---
title: "Retro Terminal Game"
theme: "catppuccin-mocha"
font: "VT323"
fontsize: 20
shaders: "crt+scanlines"
minWidth: 80
minHeight: 24
---

# My Game

\`\`\`nim on:render
# Your game code here
\`\`\`
```

## Priority Order

Settings are applied in this order (later ones override earlier):

1. **Front matter defaults** (from your markdown)
2. **URL parameters** (e.g., `?font=Roboto+Mono&shader=invert`)

This allows users to override your defaults via URL parameters while providing sensible defaults for most viewers.

## Error Handling

All operations fail gracefully:
- If a font URL is invalid or blocked by CORS, the default terminal font is used
- If a shader file isn't found locally, it tries loading from GitHub Gist
- If a shader can't be loaded at all, rendering continues without it
- Parse errors in `fontsize` are silently ignored

Errors are logged to the browser console with the `[WASM]` prefix for debugging.

## Browser Compatibility

- **Fonts:** Requires browser support for external font loading (all modern browsers)
- **Shaders:** Requires WebGL support (Canvas2D falls back without shaders)

## Testing Your Configuration

1. **Local development:**
   ```bash
   # Start local server
   cd docs
   python -m http.server 8000
   
   # Open in browser
   open http://localhost:8000/?content=demos/your-demo.md
   ```

2. **Check console:**
   Look for messages like:
   ```
   [WASM] Loading font from front matter: Press Start 2P
   [WASM] Applied custom font: Press Start 2P
   [WASM] Loading shaders from front matter: crt+scanlines
   [WASM] All shaders loaded: crt → scanlines
   ```

3. **Override with URL:**
   Test URL parameter precedence:
   ```
   http://localhost:8000/?content=demos/your-demo.md&font=Courier+Prime&shader=invert
   ```

## Examples in the Repository

- **[stonegarden.md](../demos/stonegarden.md)**: Uses custom theme with shader chain
  ```yaml
  theme: "stonegarden"
  shaders: "grid2x1+sand+gradualblur"
  ```

- **[intro.md](../demos/intro.md)**: Uses default theme
  ```yaml
  theme: "neotopia"
  ```

## Implementation Details

**WASM Build:**
- Front matter is parsed in Nim during document initialization
- JavaScript bridge functions (`emLoadFont`, `emLoadShaders`) are called from Nim
- Font loading uses standard `<link>` tags for Google Fonts
- Shader loading uses the existing multi-shader system

**Desktop Build (Tauri):**
- Uses the same HTML/JavaScript infrastructure as web build
- All features work identically
- Shaders require WebGL support in the webview

**Timing:**
Front matter processing happens:
1. After markdown parsing
2. Before `on:init` blocks execute
3. After URL parameters are checked

This ensures:
- Front matter defaults are available to your code
- URL parameters can override front matter
- Font/shader loading doesn't block initialization

## Common Patterns

### Themed Document with Matching Font
```yaml
---
title: "Cyberpunk Adventure"
theme: "cyberpunk"
font: "Orbitron"
fontsize: 16
shaders: "crt+glitch"
---
```

### Retro Terminal Aesthetic
```yaml
---
theme: "amber"
font: "VT323"
fontsize: 22
shaders: "scanlines+phosphor"
---
```

### Clean Modern Interface
```yaml
---
theme: "github-light"
font: "Fira Code"
fontsize: 14
---
```

### Pixel Art Game
```yaml
---
font: "Press Start 2P"
fontsize: 16
shaders: "pixelate"
doubleWidth: true
---
```

## Troubleshooting

**Font not loading:**
- Check browser console for CORS errors
- Verify font name matches Google Fonts exactly
- Try using full Google Fonts URL instead of name

**Shaders not applying:**
- Verify shader files exist in `shaders/` directory
- Check WebGL is enabled in browser
- Look for shader errors in console

**Settings being overridden:**
- Check URL parameters - they take precedence
- Clear browser cache if testing changes

**Performance issues:**
- Limit shader chain to 2-3 effects
- Use smaller font sizes for complex scenes
- Test on target devices

## Future Enhancements

Potential additions (not yet implemented):
- Custom font file URLs (beyond Google Fonts)
- Font fallback chains
- Conditional shader loading based on device capability
- Shader configuration parameters from front matter
