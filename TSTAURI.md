# tStauri - Desktop tStorie Application

A Tauri-based desktop application for running tStorie markdown documents with drag-and-drop functionality.

## Project Overview

**What it does:** Provides a native desktop wrapper for tStorie that allows users to drag and drop `.md` files to execute them in a terminal interface.

**Tech Stack:**
- **Tauri 2.9.5** - Desktop framework (Rust backend + webview frontend)
- **Rust 1.92.0** - Backend with MinGW-w64 cross-compilation for Windows
- **Vite 7.3.1** - Frontend bundler (root: `src/`, output: `dist-frontend/`)
- **tStorie WASM** - Terminal engine (`tstorie.js`, `tstorie.wasm.js`, `tstorie.wasm.wasm`, **`tstorie-webgl.js`**)
- **WebGL2 Renderer** - GPU-accelerated terminal rendering (10-100× faster)
- **WebView2** - Windows webview runtime

## Project Structure

```
tstauri/
├── src-tauri/               # Rust backend
│   ├── src/main.rs         # File loading, WASM serving, drag-drop handling
│   ├── Cargo.toml          # Rust dependencies, devtools feature
│   ├── tauri.conf.json     # Tauri configuration
│   └── capabilities/       # Permission definitions
├── src/                     # Frontend source
│   ├── index.html          # UI with drop zone and canvas#terminal
│   ├── main.js             # WASM initialization and file handling
│   └── styles.css          # Styling
├── dist-frontend/           # Vite build output (bundled into .exe)
├── dist/                    # Portable package output
├── build-windows.sh         # Cross-compile Windows binary
├── package-windows.sh       # Create portable ZIP with WebView2Loader.dll
└── WEBVIEW2_SOLUTION.md     # WebView2 distribution approach
```

## Build System

### Development Build (Linux → Windows)
```bash
npm run tauri build -- --target x86_64-pc-windows-gnu
```

### Portable Package
```bash
bash package-windows.sh
```
Creates: `dist/tstauri-windows-portable.zip` (7.9 MB) containing:
- `tstauri.exe` (20 MB, includes bundled frontend)
- `WebView2Loader.dll` (157 KB)
- `MicrosoftEdgeWebview2Setup.exe` (1.7 MB, optional bootstrapper)
- WASM files: `tstorie.js`, `tstorie.wasm.js`, `tstorie.wasm.wasm`, **`tstorie-webgl.js`**
- `run-tstauri.bat`, `README.txt`

## Critical Architecture Notes

### WebGL Renderer

tStauri now uses the **WebGL renderer** for GPU-accelerated terminal rendering:
- **10-100× faster** than Canvas 2D through instanced drawing
- **Full Unicode support** including CJK characters (Japanese, Chinese, Korean)
- **Dynamic glyph caching** for on-demand character atlas generation
- **WebGL2 requirement**: Supported in all modern browsers (99%+ as of 2026)

All Tauri webviews (Windows WebView2, macOS WKWebView, Linux WebKitGTK) support WebGL2.

### WASM Loading Sequence (IMPORTANT!)

The initialization order is **critical**:

1. **Pre-load all WASM files as blob URLs** (must be synchronous for Emscripten)
   ```javascript
   const wasmFiles = {};
   wasmFiles['tstorie.wasm.wasm'] = URL.createObjectURL(wasmBlob);
   ```

2. **Set up Module object with `onRuntimeInitialized` callback BEFORE loading script**
   ```javascript
   window.Module = {
       canvas: canvasElement,
       onRuntimeInitialized: function() { /* ... */ },
       locateFile: function(path) { return wasmFiles[path]; }  // Must be synchronous!
   };
   ```

3. **Load `tstorie.wasm.js` first** (Emscripten runtime, not `tstorie.js`)
   ```javascript
   script.src = wasmJsUrl;  // tstorie.wasm.js
   ```

4. **In `onRuntimeInitialized`, load WebGL renderer** (`tstorie-webgl.js`)
   ```javascript
   const webglScript = document.createElement('script');
   webglScript.src = webglUrl;  // tstorie-webgl.js
   ```

5. **After WebGL loads, load `tstorie.js`** (terminal wrapper with `inittstorie()`)

6. **Call `inittstorie()`** to create the terminal

**Why this order matters:**
- `tstorie.wasm.js` is the Emscripten runtime that initializes the WASM binary
- `tstorie-webgl.js` provides the `TStorieTerminal` class (WebGL renderer)
- `tstorie.js` is the terminal wrapper that depends on both WASM and WebGL being ready
- `locateFile` MUST be synchronous - async breaks Emscripten initialization
- `Module` object must exist before script loads

### Canvas Element

The canvas **must** have `id="terminal"` (not "canvas"):
```html
<canvas id="terminal" tabindex="-1"></canvas>
```

tStorie's `inittstorie()` function expects this specific ID:
```javascript
const canvas = document.getElementById('terminal');  // Line 453 of tstorie.js
terminal = new TStorieTerminal(canvas);
```

### Container Visibility

The canvas must be **visible in the DOM** before initialization:
```javascript
// WRONG: display: none removes from DOM
tstorieContainer.style.display = 'none';

// RIGHT: keeps in DOM but hidden
tstorieContainer.style.visibility = 'hidden';
tstorieContainer.style.opacity = '0';
```

After showing container, wait for DOM to render:
```javascript
tstorieContainer.classList.add('active');
await new Promise(resolve => setTimeout(resolve, 50));
```

### Content Reloading Limitation

**TStorie WASM is not designed for reloading content.** The "Back to drop zone" button now simply reloads the entire page:
```javascript
function resetToDropZone() {
    window.location.reload();
}
```

Attempting to reset state without reloading causes initialization failures.

## Common Issues & Solutions

### Issue: "Canvas element not found"
**Cause:** Container hidden when looking for canvas
**Solution:** Show container FIRST, wait 50ms, THEN call `loadTStorieEngine()`

### Issue: "Module._emInit not found"
**Cause:** Wrong script loaded first, or async `locateFile`
**Solution:** 
1. Pre-load all WASM files as blob URLs
2. Make `locateFile` synchronous
3. Load `tstorie.wasm.js` (not `tstorie.js`)

### Issue: "Cannot read properties of null (reading 'getContext')"
**Cause:** Canvas has wrong ID
**Solution:** Change to `<canvas id="terminal">`

### Issue: Hangs at "Loading WASM script"
**Cause:** `onRuntimeInitialized` callback not set up before script loads
**Solution:** Define `window.Module` with callback BEFORE appending script to DOM

### Issue: Second file drop fails
**Cause:** Canvas removed from DOM by `display: none`
**Solution:** Use `visibility: hidden` + `opacity: 0` instead

## Key Files to Check

### Frontend Logic (`src/main.js`)
- `loadTStorieEngine()` - WASM initialization sequence (lines ~17-170)
- `runMarkdown()` - File handling and content loading (lines ~173-265)
- `resetToDropZone()` - Page reload function (lines ~296-299)

### Backend (`src-tauri/src/main.rs`)
- `load_markdown_content()` - Read .md files from filesystem
- `get_bundled_wasm_file()` - Serve WASM files as Vec<u8> for blob URLs
- `get_bundled_wasm_path()` - Return resource directory path
- File drop handler: `WindowEvent::DragDrop` → emit 'file-dropped' event

### Configuration (`src-tauri/tauri.conf.json`)
- `webviewInstallMode: { type: "downloadBootstrapper", silent: true }`
- CSP: `"default-src 'self'; script-src 'self' 'unsafe-inline' blob:; worker-src blob:;"`
- `frontendDist: "../dist-frontend"`
- `beforeBuildCommand: "npm run vite:build"`

## Debugging Tips

### Enable DevTools in Release Builds
Already configured in `tauri.conf.json`:
```json
"devtools": true
```

Press **F12** to open DevTools in the app.

### Check Console Output
Critical log messages to look for:
```
✓ All WASM files pre-loaded
✓ Terminal canvas found on attempt 1
✓ Loading Emscripten WASM runtime...
Module requesting: tstorie.wasm.wasm
✓ WASM runtime initialized
Module._emInit available: true
Loading tstorie.js wrapper...
✓ tstorie.js loaded
✓ inittstorie function ready
✓ tStorie engine initialized successfully
```

If you see polling that never completes, the callback isn't firing.

### Test Different Files
Some tStorie documents may have initialization issues. Try simpler ones:
- `docs/demos/intro.md` - Basic introduction
- `docs/demos/layout.md` - Layout test
- `docs/demos/events_mouse.md` - Mouse events

### Check WASM File Loading
In DevTools Network tab, look for:
- blob URLs (not asset:// or http://)
- All three WASM files loading successfully
- No 404 or CORS errors

## Cross-Compilation Notes

### Required Rust Target
```bash
rustup target add x86_64-pc-windows-gnu
```

### MinGW-w64 Required
```bash
sudo apt install mingw-w64
```

### Build Output
- Binary: `src-tauri/target/x86_64-pc-windows-gnu/release/tstauri.exe`
- Size: ~20 MB (includes bundled Vite frontend)
- Compression: Deflates to ~6 MB in ZIP

### Known Warnings
```
warning: unused import: `std::path::PathBuf`
```
This is harmless and can be ignored or fixed with `cargo fix`.

## Performance Considerations

### Window Size
Optimized for 640x480 to match typical tStorie terminal dimensions:
```json
"width": 640,
"height": 480
```

### WASM Loading
All files pre-loaded as blobs to avoid async delays during initialization. Total WASM size: ~1 MB.

### Canvas Polling
Up to 20 attempts × 100ms = 2 seconds timeout for canvas to appear.

## Future Improvements

### Potential Features
- [ ] Multi-file tabs (requires tStorie redesign for reloading)
- [ ] Recent files list
- [ ] File association (.md opens in tStauri)
- [ ] Command-line argument support for opening files
- [ ] Auto-reload on file changes

### Known Limitations
1. **No content reloading** - Must refresh page to load new file
2. **Windows-only** - Not tested on macOS/Linux (Tauri supports both)
3. **No error recovery** - Failed initialization requires restart
4. **No progress indication** - Long WASM loads appear frozen

## Testing Checklist

When making changes, test these scenarios:

- [ ] First file drop initializes successfully
- [ ] Terminal renders content correctly
- [ ] Mouse/keyboard input works
- [ ] "Back to drop zone" button reloads page
- [ ] Second file drop after reload works
- [ ] Large files (>10 KB) load without hanging
- [ ] DevTools accessible with F12
- [ ] Error messages visible if initialization fails

## Helpful Claude Prompts for Continuation

When starting a new discussion about tStauri:

**Context-Setting Prompt:**
```
I'm working on tStauri, a Tauri desktop app for tStorie (WASM terminal engine). 
Key facts:
- Canvas must be id="terminal"
- Must load tstorie.wasm.js (Emscripten) before tstorie.js (wrapper)
- locateFile must be synchronous
- Content reloading not supported (reload page instead)

Current issue: [describe your issue]

See TSTAURI.md in the project for full architecture details.
```

**For Build Issues:**
```
tStauri build failing with: [error message]

Build system: npm run tauri build → Vite bundles src/ → Cargo builds Rust → Output: tstauri.exe
See build-windows.sh and package-windows.sh for process.
```

**For WASM Issues:**
```
tStorie WASM initialization problem: [issue]

Current sequence:
1. Pre-load WASM files as blobs
2. Set up Module with onRuntimeInitialized
3. Load tstorie.wasm.js
4. Callback loads tstorie.js
5. Call inittstorie()

See src/main.js loadTStorieEngine() function.
```

## Additional Resources

- **Tauri Docs**: https://v2.tauri.app/
- **Emscripten API**: https://emscripten.org/docs/api_reference/
- **WebView2 Distribution**: See WEBVIEW2_SOLUTION.md
- **tStorie Source**: Check /workspaces/telestorie/docs/tstorie.js for terminal implementation

## Version History

- **v0.1.0** - Initial working version with drag-drop, WASM loading, Windows cross-compilation

---

**Last Updated:** January 12, 2026  
**Status:** Working with known reloading limitation
