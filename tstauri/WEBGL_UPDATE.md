# tStauri WebGL Renderer Update

## Summary

tStauri has been updated to use the new **WebGL renderer** from tstorie core, providing significantly improved performance and Unicode support.

## Changes Made

### 1. Bundled Files Updated
**File:** [src-tauri/tauri.conf.json](src-tauri/tauri.conf.json)

Added `tstorie-webgl.js` to the bundled resources:
```json
"resources": [
  "../../docs/tstorie.js",
  "../../docs/tstorie.wasm.js",
  "../../docs/tstorie.wasm.wasm",
  "../../docs/tstorie-webgl.js"  // NEW
]
```

### 2. JavaScript Loading Sequence Updated
**File:** [src/main.js](src/main.js)

Updated the initialization sequence to load the WebGL renderer:

**Old sequence:**
1. Load WASM runtime (`tstorie.wasm.js`)
2. Wait for `onRuntimeInitialized`
3. Load terminal wrapper (`tstorie.js`)
4. Call `inittstorie()`

**New sequence:**
1. Load WASM runtime (`tstorie.wasm.js`)
2. Wait for `onRuntimeInitialized`
3. **Load WebGL renderer (`tstorie-webgl.js`)** ← NEW
4. Load terminal wrapper (`tstorie.js`)
5. Call `inittstorie()`

This ensures the `TStorieTerminal` class from the WebGL renderer is available before `tstorie.js` tries to use it.

### 3. Canvas Styling Updated
**File:** [src/index.html](src/index.html)

Changed canvas rendering style for WebGL:
```css
/* OLD: Canvas 2D pixelated rendering */
#canvas {
    image-rendering: pixelated;
    image-rendering: crisp-edges;
}

/* NEW: WebGL smooth rendering */
#terminal {
    image-rendering: auto;
}
```

WebGL renders smoothly with anti-aliasing, so pixelation is no longer needed.

### 4. Documentation Updated
**Files:** [BUILD_PROCESS.md](BUILD_PROCESS.md), [../TSTAURI.md](../TSTAURI.md)

- Added section on WebGL renderer integration
- Updated loading sequence documentation
- Added browser compatibility information
- Updated bundled files list

## Benefits

### Performance
- **10-100× faster rendering** through GPU instanced drawing
- Single draw call for entire terminal (vs. 1,920 draw calls with Canvas 2D)
- Consistent 60 FPS even with large documents

### Unicode Support
- **Full CJK character support** (Japanese, Chinese, Korean)
- **Dynamic glyph caching** - characters are rendered on-demand
- Proper handling of single-width, double-width, and zero-width characters

### Future-Proof
- **Native shader support** for terminal effects
- **Post-processing effects** possible (CRT, bloom, etc.)
- **Path to WebGPU** migration

## Browser/Webview Compatibility

WebGL2 is supported in **99%+ of browsers** as of 2026:
- Chrome/Edge 56+ (March 2017+)
- Firefox 51+ (January 2017+)
- Safari 15+ (September 2021+)
- Opera 43+ (March 2017+)

All Tauri webviews support WebGL2:
- ✅ Windows: WebView2 (Chromium-based)
- ✅ macOS: WKWebView (WebKit-based, Safari 15+)
- ✅ Linux: WebKitGTK (WebKit-based)

## Testing Required

Before releasing, test that:

1. **Application launches** without errors
2. **Drag and drop works** - files load correctly
3. **Terminal renders** properly with WebGL
4. **Unicode characters** display correctly (test with CJK text if available)
5. **PNG export** still works (WebGL preserves drawing buffer for `toDataURL()`)
6. **No console errors** related to WebGL initialization

### Test on:
- ✅ Linux (AppImage)
- ✅ macOS (Intel and ARM if possible)
- ✅ Windows (portable .exe)

### Quick test markdown:
```markdown
# Test tStauri WebGL Renderer

Hello, world! 🌍

こんにちは世界 (Japanese)
你好世界 (Chinese)

## Box Drawing
┌─────────┐
│  Test   │
└─────────┘

## Colors
\u001b[31mRed text\u001b[0m
\u001b[32mGreen text\u001b[0m
\u001b[34mBlue text\u001b[0m
```

## Rollback Plan

If issues arise, you can rollback by:

1. **Revert to Canvas 2D renderer:**
   - In `tauri.conf.json`, remove `tstorie-webgl.js`
   - In `main.js`, remove the WebGL loading step
   - Ensure the old Canvas 2D version is in `docs/`

2. **Or use the Canvas 2D backup:**
   - The old renderer is preserved as `tstorie-canvas2d.js` in the main repo
   - Can be renamed/swapped if needed

## Build Instructions

### Development Build
```bash
cd tstauri
npm run dev
# Drop a .md file to test
```

### Production Build (Linux → Windows)
```bash
cd tstauri
npm run tauri build -- --target x86_64-pc-windows-gnu
bash package-windows.sh
```

### Full Release (All Platforms)
See [BUILD_PROCESS.md](BUILD_PROCESS.md) for the complete GitHub Actions workflow.

## References

- [../../WEBGL_MIGRATION.md](../../WEBGL_MIGRATION.md) - Full details on WebGL renderer
- [BUILD_PROCESS.md](BUILD_PROCESS.md) - Build and release process
- [../TSTAURI.md](../TSTAURI.md) - Complete tStauri documentation

## Questions?

For technical questions or issues:
1. Check console logs in DevTools (F12)
2. Test with `npm run dev` for detailed error messages
3. Open a GitHub issue with browser/platform details
