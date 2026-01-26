# Bug Fix: Range Error in SDL3 WASM Build

## Problem
The SDL3 WASM build was crashing on startup with:
```
Error: unhandled exception: value out of range: -1 notin 0 .. 2147483647 [RangeDefect]
Program terminated with exit(1)
```

## Root Causes
This bug had **two separate root causes** that both needed fixing:

### 1. Canvas Size Mismatch (Primary Issue)
The SDL3 canvas initialization had a critical ordering bug:

1. Initial dimensions were set to 1024×768 pixels
2. Cell dimensions were calculated: cellWidth=128, cellHeight=48 (based on 1024×768)
3. A cell grid was allocated with 128×48 = 6,144 cells
4. **Then** for Emscripten, the actual HTML canvas size (800×600) was retrieved
5. Width/height were updated to 800×600
6. **But cellWidth/cellHeight remained 128×48 instead of the correct 100×37!**

This created a mismatch where:
- The AppState was created with dimensions 128×48 (correct for 1024×768, **wrong for 800×600**)
- The actual rendering canvas was 800×600 pixels (should be 100×37 cells)
- Coordinate calculations failed, causing array out-of-bounds errors

### 2. Missing Bounds Checking (Secondary Issue)
The runtime API functions (`draw`, `clear`, `fillRect`) were accessing layer arrays without checking for negative indices:

```nim
# Problem code:
if idx == 0: gDefaultLayer
else:
  if idx >= gAppState.layers.len:
    discard gAppState.addLayer("layer" & $idx, idx)
  gAppState.layers[idx]  # <-- CRASH if idx < 0!
```

When `idx` was negative (e.g., -1 from a failed layer lookup), the code would:
1. Check `if idx == 0` (false for -1)
2. Check `if idx >= gAppState.layers.len` (false for -1)
3. Try to access `gAppState.layers[-1]` → **RangeDefect!**

## Files Changed

### 1. [backends/sdl3/sdl_canvas.nim](backends/sdl3/sdl_canvas.nim)
**Lines 89-103** - Fixed Emscripten canvas size handling:
```nim
# Before (WRONG):
when defined(emscripten):
  var canvasW, canvasH: cint
  discard emscripten_get_canvas_element_size("#canvas", addr canvasW, addr canvasH)
  result.width = canvasW.int
  result.height = canvasH.int
  # cellWidth/cellHeight NOT recalculated!

# After (CORRECT):
when defined(emscripten):
  var canvasW, canvasH: cint
  discard emscripten_get_canvas_element_size("#canvas", addr canvasW, addr canvasH)
  result.width = canvasW.int
  result.height = canvasH.int
  
  # Recalculate cell dimensions based on actual canvas size
  result.cellWidth = result.width div CHAR_WIDTH
  result.cellHeight = result.height div CHAR_HEIGHT
  
  # Resize the cell grid to match new dimensions
  result.cells = newSeq[Cell](result.cellWidth * result.cellHeight)
  for i in 0 ..< result.cells.len:
    result.cells[i] = Cell(ch: " ", style: defaultStyle)
```

### 2. [src/runtime_api.nim](src/runtime_api.nim)
**Lines 300, 347, 385** - Added bounds checking for negative indices in `draw()`, `clear()`, and `fillRect()`:
```nim
# Before (WRONG):
let layer = if args[0].kind == vkInt:
              let idx = args[0].i
              if idx == 0: gDefaultLayer
              else:
                if idx >= gAppState.layers.len:
                  discard gAppState.addLayer("layer" & $idx, idx)
                gAppState.layers[idx]  # <-- No check for negative!

# After (CORRECT):
let layer = if args[0].kind == vkInt:
              let idx = args[0].i
              if idx == 0: gDefaultLayer
              elif idx < 0:
                return valNil()  # Negative index is invalid
              elif idx >= gAppState.layers.len:
                discard gAppState.addLayer("layer" & $idx, idx)
                gAppState.layers[idx]
              else:
                gAppState.layers[idx]
```

### 3. [tstorie.nim](tstorie.nim)
**Line 1599** - Changed to use cell dimensions (required the sdl_canvas.nim fix to provide correct values):
```nim
var state = newAppState(canvas.cellWidth, canvas.cellHeight)
```

**Lines 646, 1662** - Fixed resize handlers to use cell dimensions

### 4. [backends/sdl3/sdl_fonts.nim](backends/sdl3/sdl_fonts.nim)
Fixed indentation issues throughout the file

## Explanation

The SDL3 backend implements a **hybrid coordinate system**:

1. **Physical Layer** (Pixels): The actual SDL window and renderer
   - HTML Canvas: 800×600 pixels (as defined in index-optimized.html)
   - Used for: Direct SDL rendering calls

2. **Logical Layer** (Character Cells): Terminal emulation grid
   - Grid: 100×37 cells (800÷8 × 600÷16)
   - Used for: AppState, layers, TermBuffer
   - Each cell = 8×16 pixels

The bugs occurred because:
1. **Canvas size mismatch**: Cell dimensions were calculated from initial parameters (1024×768), but Emscripten overwrote pixel dimensions to actual canvas size (800×600) without recalculating cell dimensions
2. **Missing validation**: Runtime functions tried to access layers with negative indices without checking bounds first

## Testing
After the fix:
1. Core build (1.9MB): ✅ Loads and renders correctly with 800×600 canvas
2. Full build (3.4MB): ✅ Compiles and loads correctly
3. No more RangeDefect errors
4. Progressive loading system operational
5. Correct cell dimensions: 100×37 for 800×600 canvas
6. Negative layer indices properly rejected

## Prevention
When working with SDL3 backend on Emscripten:
- **Always recalculate cell dimensions after getting the actual canvas size**
- Never assume the HTML canvas size matches initialization parameters
- Cell dimensions must be synchronized with pixel dimensions
- Formula: `cellWidth = width / 8`, `cellHeight = height / 16`
- **Always validate array indices before access**, especially when they come from user input or lookups that can fail

## Build Command
```bash
./build-web-progressive.sh
```

## Date
January 23, 2026
