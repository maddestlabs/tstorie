# SDL3 Modular Build - Architecture & Known Issues

**Build Command:** `./build-modular.sh` → Outputs to `docs/tstorie.{js,wasm}`  
**Test URL:** `http://localhost:8000/index-modular.html`

## Current Status

✅ **Working:**
- Basic SDL3 rendering (text displays on screen)
- Input event polling (keyboard, mouse, wheel)
- KEY_* constants exposed to Nimini
- Window close/quit handling
- Unicode character rendering (fixed: use writeCellText for UTF-8)
- FIGlet fonts (embedded in markdown with ```figlet:fontname blocks)
- ANSI art rendering (from ansi: code blocks)

❌ **Limited/Broken:**
- Most demos fail
- External FIGlet font loading (use embedded fonts instead)
- Unknown what specific functionality is missing

## Architecture Overview

### Rendering Pipeline
SDL3 uses a **different rendering architecture** than terminal backend:

```
Terminal:  draw() → layers → compositing → display buffer
SDL3:      sdl3DrawCell() → direct canvas write → renderCellsToPixels() → present()
```

**Critical:** SDL3 bypasses the layer system entirely. Functions write directly to `gSDL3Canvas.cells[]`.

### Main Loop ([tstorie.nim](tstorie.nim) lines 675-710)
```nim
proc sdl3MainLoop():
  1. Poll input events (SDL3InputHandler)
  2. Process each event via inputHandler()
  3. Update timing
  4. Call onUpdate lifecycle
  5. Call renderStorie() - executes on:render blocks
  6. Clear SDL renderer with theme background
  7. renderCellsToPixels() - convert cells to pixels
  8. present() - display to screen
```

### Draw Functions ([src/runtime_api.nim](src/runtime_api.nim) lines 185-220)

SDL3 uses **custom draw functions** registered in Nimini:
- `draw()` → `sdl3DrawCell()` - writes single character or string
- `clear()` → `sdl3ClearCells()` - fills with theme background
- `fillRect()` → `sdl3FillCellRect()` - fills rectangle

**Implementation:** Character-by-character writes using `gSDL3Canvas.writeCell()`, NOT `writeText()`.

### Global State Requirements

**Must be initialized before rendering:**
```nim
gAppState = globalState           # Set in tstorie.nim SDL3 init
gSDL3Canvas = globalCanvas         # Set via setSDL3Canvas()
```

Both are set during SDL3 initialization around line 1500 in [tstorie.nim](tstorie.nim).

### Input System Integration

**Architecture:** SDL events → SDL3InputHandler → unified InputEvent → user code

**File:** [src/input/sdl3input.nim](src/input/sdl3input.nim)
- Converts SDL_Event to InputEvent format
- Maps scancodes to KEY_* constants
- Handles modifiers (Shift, Ctrl, Alt)
- Applies event normalization (removes duplicate KeyEvent for printable chars)

**Registration:** [src/runtime_api.nim](src/runtime_api.nim) createNiminiContext (lines 1371+)
- KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT
- KEY_F1-F12, KEY_SPACE, KEY_TAB, KEY_BACKSPACE, etc.
- All exposed as integer constants to Nimini scripts

## Debugging Session Summary

### Issue #1: Blank Screen (RESOLVED)
**Root Cause:** Multiple compounding issues:
1. Main loop missing → Added sdl3MainLoop with emscripten_set_main_loop
2. gAppState was nil → Set during SDL3 init
3. Wrong function names → SDL3 uses sdl3DrawCell not draw()
4. gSDL3Canvas was nil → Added setSDL3Canvas() call
5. Layer buffer system broken → Bypassed entirely, direct canvas writes
6. Missing clear() call → Added before renderCellsToPixels()

**Final Fix:** Direct canvas writes + clear + renderCellsToPixels in main loop.

### Issue #2: No Input Events (RESOLVED)
**Root Cause:** SDL3 main loop was calling `globalCanvas.pollEvents()` which returns SDL event format, not the unified InputEvent format.

**Fix:** 
- Created `globalInputHandler: SDL3InputHandler`
- Initialized with `newSDL3InputHandler(addr globalCanvas, cellWidth, cellHeight)`
- Changed main loop to `globalInputHandler.pollInput()` → returns InputEvent[]
- Pass each event to `inputHandler()` from runtime_api.nim

**Related:** Added SDL_EVENT_QUIT and SDL_EVENT_WINDOW_CLOSE_REQUESTED handling in sdl3input.nim to generate ESC key event.

### Issue #3: Missing KEY_* Constants (RESOLVED)
**Root Cause:** KEY_UP, KEY_DOWN, etc. not exposed to Nimini environment.

**Fix:** Added defineVar() calls in createNiminiContext() for all common KEY_* constants (ESCAPE, RETURN, arrows, function keys).

## Common Issues & Solutions

### Unicode Characters Render as "?"
**Root Cause:** Text iteration was byte-by-byte instead of UTF-8 character-by-character.

**Fix:** Use `writeCellText()` which properly handles UTF-8 characters:
```nim
# WRONG: Iterates bytes, breaks multi-byte UTF-8
for i, ch in text:
  canvas.writeCell(x + i, y, $ch, style)

# CORRECT: Handles UTF-8 properly
canvas.writeCellText(x, y, text, style)
```

**Status:** ✅ Fixed in commit [current]

### FIGlet Fonts Not Loading/Rendering
**Root Cause:** The `drawFigletText()` function in [lib/figlet_bindings.nim](lib/figlet_bindings.nim) was using `layer[].buffer.writeText()` which doesn't work in SDL3. SDL3 uses a different rendering architecture that writes directly to the canvas grid via `gSDL3Canvas.writeCellText()` instead of using the layer buffer system.

**Pipeline Difference:**
- **Regular WASM**: FIGlet → `layer.buffer.writeText()` → layer compositing → display ✅
- **SDL3 (broken)**: FIGlet → `layer.buffer.writeText()` → ❌ (layers don't have functional buffers)
- **SDL3 (fixed)**: FIGlet → `gSDL3Canvas.writeCellText()` → direct canvas → renderCellsToPixels → display ✅

**Fix:** 
- Added `when defined(sdl3Backend)` conditionals to `drawFigletText()` to use SDL3 canvas directly
- Added `gSDL3Canvas` reference to figlet_bindings.nim
- Updated `registerFigletBindings()` to accept and store SDL3 canvas reference
- Modified all text output in figlet rendering to use appropriate backend

**Files Changed:**
- [lib/figlet_bindings.nim](lib/figlet_bindings.nim) - Added SDL3 support to drawFigletText
- [src/runtime_api.nim](src/runtime_api.nim) - Pass SDL3 canvas to figlet registration
- [build-modular.sh](build-modular.sh) - Added figlet_bridge.js (for external font loading)

**Note:** The `figlet_bridge.js` addition enables external .flf font loading but isn't required for embedded fonts. The main fix was making drawFigletText() SDL3-aware.

**Status:** ✅ Fixed - figlet fonts now render correctly in SDL3 modular build

### ANSI Art Not Rendering
**Root Cause:** Same issue as FIGlet fonts. The `drawWrapper` callback in [src/runtime_api.nim](src/runtime_api.nim) used by ANSI art rendering was calling `gDefaultLayer.buffer.write()` which doesn't work in SDL3.

**Pipeline:**
- **Regular WASM**: ANSI parser → drawWrapper → `layer.buffer.write()` → compositing ✅
- **SDL3 (broken)**: ANSI parser → drawWrapper → `layer.buffer.write()` → ❌
- **SDL3 (fixed)**: ANSI parser → drawWrapper → `gSDL3Canvas.writeCell()` → direct canvas ✅

**Fix:**
- Added `when defined(sdl3Backend)` conditional to `drawWrapper` procedure
- SDL3 path uses `gSDL3Canvas.writeCell()` for direct rendering
- Regular path continues using `gDefaultLayer.buffer.write()`

**Files Changed:**
- [src/runtime_api.nim](src/runtime_api.nim) - Made drawWrapper SDL3-aware

**Status:** ✅ Fixed - ANSI art now renders correctly in SDL3 modular build

### Demo Fails to Load
**Check:**
1. Does demo use terminal-specific APIs? (ANSI codes, terminal size detection)
2. Does demo rely on layer compositing? (SDL3 bypasses this)
3. Does demo use functions not registered for SDL3? (check createNiminiContext)

**Debug:**
- Check browser console for errors
- Look for "ERROR:" messages in wasm output
- Verify on:init blocks executed (check storieCtx.codeBlocks)

### Text Not Rendering
**Check:**
1. `gSDL3Canvas` is set (call setSDL3Canvas before initStorieContext)
2. `gAppState` is set (assign globalState before init)
3. draw() function is being called (not clear/fillRect only)
4. renderCellsToPixels() called in main loop
5. Theme background color set correctly

**Debug:** Add temporary logging in sdl3DrawCell to verify calls.

### Input Not Working
**Check:**
1. `globalInputHandler` initialized with correct canvas reference
2. Event processing loop calls `inputHandler(globalState, event)`
3. on:input blocks present in markdown
4. KEY_* constants defined if using special keys

### Colors Wrong or Missing
SDL3 uses theme background for clear():
```nim
let themeBg = globalState.themeBackground  # From stylesheet
globalCanvas.clear((themeBg.r, themeBg.g, themeBg.b))
```

**Check:** storieCtx.themeBackground set from frontmatter or default theme.

## Architecture Differences: Terminal vs SDL3

| Feature | Terminal Backend | SDL3 Backend |
|---------|-----------------|--------------|
| **Draw Functions** | draw(), clear(), fillRect() | sdl3DrawCell(), sdl3ClearCells(), sdl3FillCellRect() |
| **Registration** | Direct API functions | Registered via registerNative() in createNiminiContext |
| **Layers** | Full compositing system | Bypassed - direct canvas writes |
| **Text Rendering** | writeText() works | writeCellText() on SDLCanvas |
| **FIGlet Fonts** | layer.buffer.writeText() | gSDL3Canvas.writeCellText() |
| **Cell Size** | 1x1 character | 8x16 pixels (default font size) |
| **Color Support** | RGB + ANSI | RGB only (no ANSI codes) |
| **Input** | ANSI escape sequences | SDL events → InputEvent |

## Files to Check When Debugging

**Main Loop & Initialization:**
- [tstorie.nim](tstorie.nim) lines 1495-1560 (SDL3 init)
- [tstorie.nim](tstorie.nim) lines 675-710 (sdl3MainLoop)

**Rendering Functions:**
- [src/runtime_api.nim](src/runtime_api.nim) lines 185-220 (sdl3DrawCell, etc.)
- [src/runtime_api.nim](src/runtime_api.nim) line 141 (setSDL3Canvas)
- [src/runtime_api.nim](src/runtime_api.nim) lines 1432-1434 (function registration)

**Input System:**
- [src/input/sdl3input.nim](src/input/sdl3input.nim) (event conversion)
- [src/runtime_api.nim](src/runtime_api.nim) lines 2205+ (inputHandler)
- [src/runtime_api.nim](src/runtime_api.nim) lines 1371+ (KEY constants)

**SDL3 Backend:**
- [backends/sdl3/sdl_canvas.nim](backends/sdl3/sdl_canvas.nim) (SDLCanvas type)
- [backends/sdl3/bindings/](backends/sdl3/bindings/) (SDL3 C bindings)
- [web/sdl3_stub_bridge.js](web/sdl3_stub_bridge.js) (JS stubs for terminal-only functions)

## Next Steps for Debugging

1. **Test each demo systematically** - identify which specific APIs/features fail
2. **Check missing function registrations** - SDL3 may need more APIs exposed
3. **Verify layer operations** - some demos may require layer compositing
4. **Test timing functions** - getDeltaTime(), getTime(), etc.
5. **Check canvas operations** - if using canvas module, verify SDL3 compatibility
6. **Look for terminal-specific code** - ANSI codes, escape sequences won't work

## Build System Notes

**JavaScript Bridges Required:** 
- `web/sdl3_stub_bridge.js` - Stubs for terminal-only functions (fonts, shaders)
- `web/figlet_bridge.js` - FIGlet font loading support (embedded and external .flf files)

**FIGlet Support:** 
- Embedded fonts (in markdown) are parsed and stored in `gEmbeddedFigletFonts`
- External .flf font loading works via `fetchFontFile` JavaScript bridge
- Both embedded and external fonts are fully supported in SDL3 build

**Compilation Flags:**
- `-d:sdl3Backend` - enables SDL3-specific code paths
- `-d:emscripten` - WASM build target
- Check [build-modular.sh](build-modular.sh) for complete flags

## Quick Reference

**To test a fix:**
```bash
./build-modular.sh
cd docs && python3 -m http.server 8000
# Open http://localhost:8000/index-modular.html
```

**To add a new API for SDL3:**
1. Add function to src/runtime_api.nim
2. Register with `registerNative("name", function)` in createNiminiContext
3. If function needs canvas access, use gSDL3Canvas global
4. Rebuild and test

**To debug rendering:**
- Add logging to sdl3DrawCell (but remove before commit!)
- Check gSDL3Canvas.cells[] contents
- Verify clear() called with correct background color
- Ensure renderCellsToPixels() called every frame
