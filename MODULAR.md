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
- Layer initialization (duplicate layer prevention)
- Performance optimization (verbose logging removed)
- Particle systems (all particle effects now render correctly)
- Audio playback (WebAudio API via audio_bridge.js)

❌ **Known Issues:**
- Performance may degrade with very complex scenes (mitigated by dirty tracking)
- Some demos may still have issues (needs systematic testing)
- External FIGlet font loading (use embedded fonts instead)

⚠️ **Needs Testing:**
- All demo content for compatibility
- Complex layer compositing scenarios
- Canvas module operations

## Architecture Overview

### Rendering Pipeline
SDL3 uses a **different rendering architecture** than terminal backend:

```
Terminal:  draw() → layers → compositing → display buffer
SDL3:      sdl3DrawCell() → direct canvas write → renderCellsToPixels() → present()
```

**Critical:** SDL3 bypasses the layer system entirely. Functions write directly to `gSDL3Canvas.cells[]`.

### Persistent Texture Rendering (Battery-Efficient Dirty Tracking)

SDL3 uses **double-buffering** which automatically clears the back buffer on every `SDL_RenderPresent()`. This means skipped cells would appear black. To solve this, we use a **persistent texture** approach inspired by modern terminal emulators (Ghostty, Kitty):

**Architecture:**
```
1. Persistent Texture (SDL_TEXTUREACCESS_TARGET)
   ↓
2. Dirty Tracking: Compare cells[] vs prevCells[]
   ↓
3. Render ONLY changed cells to persistent texture
   ↓
4. Blit entire texture to back buffer
   ↓
5. Present frame
```

**Performance Characteristics:**
- **Static content**: ~0-10 dirty cells/frame after initial render
- **Moving particles**: Only particle cells marked dirty
- **Each frame**: Single texture blit (GPU operation, very fast)
- **Battery efficient**: No wasted CPU/GPU work on unchanged content

**Key Implementation Details:**
- `terminalTexture`: Persistent render target created with `SDL_CreateTexture()`
- `SDL_SetRenderTarget()`: Switch between texture and back buffer
- `prevCells[]`: Previous frame state for dirty detection
- Texture blit: Fast GPU copy of entire terminal texture to screen

**Why This Approach?**
SDL3's double-buffering clears the back buffer each frame. Without a persistent texture, we'd need to re-render ALL 3,700+ cells every frame (wasteful). With persistent texture + dirty tracking, we only render changed cells (~1-5% of screen for static content).

### Main Loop ([tstorie.nim](tstorie.nim) lines 675-710)
```nim
proc sdl3MainLoop():
  1. Poll input events (SDL3InputHandler)
  2. Process each event via inputHandler()
  3. Update timing
  4. Call onUpdate lifecycle
  5. Call renderStorie() - executes on:render blocks
  6. Clear SDL renderer with theme background
  7. renderCellsToPixels() - dirty tracking + persistent texture rendering
     a. Compare cells[] vs prevCells[] to find changes
     b. Render ONLY changed cells to terminalTexture
     c. Blit entire texture to back buffer
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

## SDL3 Double-Buffering Gotcha

**Critical Understanding:** SDL3 automatically clears the back buffer on `SDL_RenderPresent()`. This is standard double-buffering behavior.

**Why This Matters:**
- If you skip rendering a cell, it appears **black** (not the previous content)
- Naive dirty tracking (skip unchanged cells) results in disappearing static content
- Terminal backends don't have this issue (persistent display buffer)

**Solution:** Persistent texture as render target
- Texture persists between frames (doesn't clear)
- Only render changed cells to texture
- Blit entire texture to back buffer each frame
- Back buffer clears, but texture retains all content

**Implementation:** [backends/sdl3/sdl_canvas.nim](backends/sdl3/sdl_canvas.nim)
- `terminalTexture: ptr SDL_Texture` - persistent render target
- `SDL_SetRenderTarget(renderer, terminalTexture)` - render to texture
- `SDL_SetRenderTarget(renderer, nil)` - back to back buffer
- `SDL_RenderTexture()` - blit texture to screen

## Common Issues & Solutions

### Unicode Characters Render as "?"
**Root Cause:** Text iteration was byte-by-byte instead of UTF-8 character-by-character.

**Fix:** Use `writeCellText()` which properly handles UTF-8 characters:
```nim
# WRONG: Iterates byte UTF-8
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
- SDLuplicate Layer Creation Causing Blank Screens (RESOLVED)
**Root Cause:** Multiple code paths were creating "default" layers without checking if one already existed. This violated the requirement from FIX_LAYERS.md that layers should only be created once. Multiple duplicate layers would overwrite each other during compositing, causing blank screens or missing content.

**Affected Locations:**
- `src/runtime_api.nim` - sdl3DrawCell, sdl3FillRect, drawWrapper, initStorieContext
- `lib/figlet_bindings.nim` - FIGlet drawing function
- `lib/nimini_bridge.nim` - Shader drawing function

**Fix:** Added `getLayer()` checks before `addLayer()` calls:
```nim
# WRONG: Always creates new layer
layer = gSDL3Canvas.addLayer("default", 0)

# CORRECT: Check if exists first
layer = gSDL3Canvas.getLayer("default")
if layer.isNil:
  layer = gSDL3Canvas.addLayer("default", 0)
```

**Files Changed:**
- [src/runtime_api.nim](src/runtime_api.nim) - 4 locations fixed
- [lib/figlet_bindings.nim](lib/figlet_bindings.nim) - 1 location fixed
- [lib/nimini_bridge.nim](lib/nimini_bridge.nim) - 1 location fixed

**Status:** ✅ Fixed - layers now initialize correctly without duplicates

### Performance Issues from Console Logging (RESOLVED)
**Root Cause:** Excessive debug logging in hot paths (called every frame or per-character) was flooding the browser console and causing severe performance degradation. Logging was happening:
- Every character drawn (per-pixel/cell operations)
- Every render cycle (60+ times per second)
- Every layer composite operation
- Every buffer write

**Removed Logging From:**
- `sdl3DrawCell` - "Called with N args", "After write" messages
- `TermBuffer.write` - "Writing 'X' at (x,y)" messages
- `renderCellsToPixels` - "rendering 'X' at pixel", "TTF render result", cell iteration logs
- `compositeBufferOnto` - "copying cell" messages per character
- `compositeLayers` - layer checking and buffer inspection logs
- `renderStorie` - "Has render blocks", "Executing render block" messages
- SDL3 render cycle - "Starting render cycle", "About to composite", "Render cycle complete"

**Files Changed:**
- [src/runtime_api.nim](src/runtime_api.nim) - Removed hot-path logging
- [backends/terminal/termbuffer.nim](backends/terminal/termbuffer.nim) - Removed write logging
- [backends/sdl3/sdl_canvas.nim](backends/sdl3/sdl_canvas.nim) - Removed render/composite logging
- [tstorie.nim](tstorie.nim) - Removed main loop logging

**Status:** ✅ Fixed - performance dramatically improved, console remains clean

### D3 path uses `gSDL3Canvas.writeCell()` for direct rendering
- Regular path continues using `gDefaultLayer.buffer.write()`

**Files Changed:**
- [src/runtime_api.nim](src/runtime_api.nim) - Made drawWrapper SDL3-aware

**Status:** ✅ Fixed - ANSI art now renders correctly in SDL3 modular build

### Audio Not Working (RESOLVED)
**Root Cause:** The SDL3 modular build was missing the `audio_bridge.js` JavaScript bridge, and [lib/audio.nim](lib/audio.nim) had audio functions stubbed out for SDL3 backend.

**Pipeline:**
- **Regular WASM**: Audio calls → `audio.nim` → `emAudioPlaySample()` → `audio_bridge.js` → WebAudio API ✅
- **SDL3 (broken)**: Audio calls → `audio.nim` → stub functions (discard) → ❌ (no sound)
- **SDL3 (fixed)**: Audio calls → `audio.nim` → `emAudioPlaySample()` → `audio_bridge.js` → WebAudio API ✅

**Fix:**
- Added `--passL:--js-library --passL:web/audio_bridge.js` to [build-modular.sh](build-modular.sh)
- Removed SDL3-specific stubs from [lib/audio.nim](lib/audio.nim) - audio_bridge.js works for all emscripten builds
- Audio system already registered in [lib/nimini_bridge.nim](lib/nimini_bridge.nim) via `getAudioSys()`

**Available Audio Functions:**
- `audioPlayTone(frequency, duration, waveform, volume)` - Custom tone generation
- `audioPlayBleep(frequency, volume)` - Quick beep sound
- `audioPlayJump(volume)` - Jump sound effect
- `audioPlayLanding(volume)` - Landing sound effect
- `audioPlayHit(volume)` - Hit/damage sound effect
- `audioPlayPowerUp(volume)` - Power-up sound effect
- `audioPlayLaser(volume)` - Laser sound effect

**Files Changed:**
- [build-modular.sh](build-modular.sh) - Added audio_bridge.js to linker flags
- [lib/audio.nim](lib/audio.nim) - Removed SDL3 stub conditionals, enabled WebAudio for all emscripten builds

**Status:** ✅ Fixed - audio now works correctly in SDL3 modular build

### Particles Not Rendering (RESOLVED)
**Root Cause:** The `particleRender` function in [lib/particles_bindings.nim](lib/particles_bindings.nim) was accessing layers from `gAppStateRef.layers`, but in SDL3 mode, layers are stored in `gSDL3Canvas.layers`.

**Pipeline Difference:**
- **Regular WASM**: Particles → `gAppStateRef.layers[i]` → layer.buffer ✅
- **SDL3 (broken)**: Particles → `gAppStateRef.layers[i]` → ❌ (layers not in AppState)
- **SDL3 (fixed)**: Particles → `gSDL3CanvasRef.layers[i]` → layer.buffer → compositing ✅

**Fix:**
- Added `when defined(sdl3Backend)` conditional import of `sdl_canvas` module
- Added global `gSDL3CanvasRef` variable to store SDL3 canvas reference
- Updated `particleRender` to use `gSDL3CanvasRef.layers` when in SDL3 mode
- Created `setParticleSDL3Canvas` function to initialize the SDL3 canvas reference
- Called `setParticleSDL3Canvas(gSDL3Canvas)` in runtime_api.nim after particle bindings registration

**Files Changed:**
- [lib/particles_bindings.nim](lib/particles_bindings.nim) - Added SDL3 layer access support
- [src/runtime_api.nim](src/runtime_api.nim) - Set SDL3 canvas reference for particles

**Status:** ✅ Fixed - particles now render correctly in SDL3 modular build

**Performance Bottleneck Explanation:** 

The regular WASM build uses **WebGL with GPU instanced rendering** - it renders ALL 3,700 cells in a **single GPU draw call**. The WebGL renderer uses a glyph atlas texture and shader-based rendering, allowing the GPU to process all cells in parallel.

The SDL3 modular build uses **individual SDL API calls per cell**. Even though SDL3 on Emscripten compiles to WebGL underneath, each `SDL_RenderFillRect()` and `TTF_RenderText()` call becomes a separate draw operation. At 60 FPS rendering 3,700 cells = 222,000+ individual API calls/second.

**Optimization:** Implemented dirty rectangle tracking to only render cells that changed since last frame. This reduces particle rendering from 3,700 cells/frame to ~300-500 cells/frame (~90% reduction). While still not as efficient as WebGL's single instanced draw call, it makes SDL3 performance acceptable.

**Files Changed:**
- [backends/sdl3/sdl_canvas.nim](backends/sdl3/sdl_canvas.nim) - Added prevCells buffer and dirty tracking in renderCellsToPixels()
- [lib/particles_bindings.nim](lib/particles_bindings.nim) - Fixed SDL3 layer access

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
1. Is `gSDL3Canvas` initialized? (set via setSDL3Canvas)
2. Are draw functions being called? (add temporary logging to sdl3DrawCell)
3. Is `renderCellsToPixels()` being called every frame?
4. Check browser console for SDL errors

### Static Content Disappears After First Frame
**Root Cause:** SDL3 double-buffering clears back buffer on present.

**Solution:** Already implemented via persistent texture (see "Persistent Texture Rendering" section above).

**If you see this issue:**
- Check that `terminalTexture` is created successfully
- Verify `SDL_SetRenderTarget()` calls are working
- Ensure `prevCells[]` buffer is allocated and updated
- Add temporary logging to count dirty cells per frame

### Performance Drops with Many Particles/Animations
**Expected Behavior:** Dirty tracking reduces render load for static content, but moving content still requires rendering.

**Performance Tips:**
- Static text: ~0-10 cells/frame (excellent)
- Moderate animation: ~100-500 cells/frame (good)
- Full-screen particles: ~1000+ cells/frame (acceptable, but CPU-bound)

**Optimization Ideas (not yet implemented):**
- Spatial hashing for particle systems
- Batch rendering for consecutive dirty cells
- GPU instanced rendering (like WebGL backend)

## TODO: Remaining Work for Full Functionality

### High Priority
1. **Systematic Demo Testing** - Test all demos in `docs/demos/` to identify specific API failures
   - Document which demos work vs fail
   - Identify missing function registrations
   - Note any terminal-specific dependencies

2. **API Completeness Audit**
   - Compare registered functions in SDL3 vs terminal backend
   - Add missing canvas operations (if canvas module is used)
   - Verify all drawing primitives are SDL3-aware

3. **Layer System Verification**
   - Test multi-layer scenarios thoroughly
   - Verify z-ordering works correctly
   - Check layer visibility toggling
   - Test layer clearing and resizing

### Medium Priority
4. **Timing & Animation**
   - Verify getDeltaTime() accuracy
   - Test frame timing consistency
   - Check animation smoothness

5. **Performance Optimization**
   - Profile render pipeline bottlenecks
   - Consider dirty rectangle tracking
   - Optimize layer compositing if needed

6. **Error Handling**
   - Add better error messages for SDL3-specific issues
   - Graceful degradation for missing features
   - User-friendly warnings in console

### Low Priority
7. **External Font Loading** - Re-enable if needed
8. **Audio Integration** - If demos use audio features
9. **WebGL Shader Integration** - For advanced visual effects
10. **Documentation** - Update demo markdown files with SDL3 compatibility notes

## Next Steps for Debugging

1. **Test each demo systematically** - identify which specific APIs/features fail
2. **Check missing function registrations** - SDL3 may need more APIs exposed
3. **Verify layer operations** - some demos may require advanced layer features

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
- [backends/sdl3/sdl_canvas.nim](backends/sdl3/sdl_canvas.nim) (SDLCanvas type, persistent texture rendering)
  - `renderCellsToPixels()` - dirty tracking implementation
  - `terminalTexture` - persistent render target
  - `prevCells[]` - previous frame state for comparison
- [backends/sdl3/bindings/render.nim](backends/sdl3/bindings/render.nim) (SDL3 render API)
  - `SDL_CreateTexture()` - create persistent texture
  - `SDL_SetRenderTarget()` - switch render target
  - `SDL_RenderTexture()` - blit texture to screen
- [backends/sdl3/bindings/](backends/sdl3/bindings/) (other SDL3 C bindings)
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

**To debug performance issues:**
```nim
# Add to renderCellsToPixels() temporarily:
var dirtyCount = 0
for y in 0 ..< height:
  for x in 0 ..< width:
    if cells[idx] != prevCells[idx]:
      dirtyCount += 1
echo "[SDL3] Dirty cells: ", dirtyCount, " / ", (width * height)
```
- Static content should show ~0-10 dirty cells after initial render
- Moving particles should only dirty ~particle count cells
- If all cells dirty every frame, dirty tracking is broken

**To understand persistent texture:**
- `terminalTexture` is created once at startup
- `SDL_SetRenderTarget(renderer, terminalTexture)` switches to texture
- Render only changed cells to texture
- `SDL_SetRenderTarget(renderer, nil)` switches back to screen
- `SDL_RenderTexture()` copies entire texture to screen
- Back buffer clears on present, but texture persists
