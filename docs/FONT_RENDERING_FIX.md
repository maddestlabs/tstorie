# Font Rendering Fix - January 2026

## Problem
Text in the SDL3 web build appeared pixelated with artifacts, resembling "cheap font smoothing" on Linux.

## Root Cause
The HTML canvas element had CSS properties forcing pixelated rendering:
```css
image-rendering: pixelated;
image-rendering: crisp-edges;
```

These CSS properties override SDL3's texture filtering settings, forcing the browser to use nearest-neighbor scaling for the entire canvas, which made TTF-rendered text look jagged and artifacted.

## Solution
Changed CSS to use smooth rendering:
```css
image-rendering: auto;
image-rendering: -webkit-optimize-contrast;
```

Additionally:
1. Added `SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_LINEAR)` to all font texture creation
2. Disabled `SDL_LOGICAL_PRESENTATION_LETTERBOX` on web builds to avoid double-scaling artifacts

## Files Modified
- `docs/index-modular.html` - Main SDL3 build page
- `docs/index-sdl3.html` - SDL3 test page  
- `docs/test-sdl3.html` - SDL3 unit test page
- `backends/sdl3/bindings/render.nim` - Added SDL_ScaleMode enums and functions
- `backends/sdl3/sdl_fonts.nim` - Set linear filtering on font textures
- `backends/sdl3/sdl_canvas.nim` - Disabled logical presentation on web
- `ttf_plugin.nim` - Added linear filtering to plugin

## Testing
After making these changes, hard-refresh your browser (Ctrl+Shift+R / Cmd+Shift+R) to clear cached assets.

Text should now render smoothly with proper anti-aliasing!
