# tStorie Backends

This directory contains rendering backend implementations for tStorie's multi-backend architecture.

## Structure

```
backends/
├── buffer_interface.nim     # Abstract interface all backends implement
├── terminal/                # Terminal (ANSI) backend
│   ├── termbuffer.nim       # Character-cell buffer implementation
│   ├── term_native.nim      # Native terminal display (future)
│   └── term_web.nim         # WebGL terminal renderer (future)
└── sdl3/                    # SDL3 multimedia backend (future)
    ├── sdl_canvas.nim       # Pixel-based rendering buffer
    ├── sdl_native.nim       # Native SDL3 windowing
    └── sdl_web.nim          # Emscripten SDL3 backend
```

## Backend Interface

All backends must implement the operations defined in `buffer_interface.nim`:

- **Core properties**: `width`, `height`
- **Rendering**: `write()`, `writeText()`, `fillRect()`, `clear()`
- **Cell access**: `getCell()`
- **Advanced**: `setClip()`, `setOffset()` for scrolling/clipping

## Current Status (Phase 1)

✅ **Completed:**
- Created backends directory structure
- Defined abstract buffer interface
- Moved terminal buffer implementation to `backends/terminal/termbuffer.nim`
- Updated `src/layers.nim` to import from backend
- Zero functional changes - all existing code still works

**File organization:**
- `src/layers.nim` - Layer management, compositing, display logic
- `backends/terminal/termbuffer.nim` - Terminal-specific buffer operations
- `backends/buffer_interface.nim` - Abstract interface documentation

## Terminal Backend

The terminal backend renders to character cells using ANSI escape codes.

**Coordinate system**: Cell-based (1 unit = 1 character)
**Fonts**: Monospace only
**Features**:
- ANSI 256-color and true-color support
- Bold, italic, underline, dim styles
- UTF-8 and double-width character support
- Efficient diff-based rendering

**Rendering pipeline**:
1. Draw to TermBuffer (2D array of Cell)
2. Composite layers with alpha blending
3. Generate ANSI escape codes (only for changed cells)
4. Batch write to stdout

## SDL3 Backend (Future - Phase 3)

The SDL3 backend will render to a pixel canvas using TTF fonts and OpenGL/Metal/DirectX.

**Coordinate system**: Pixel-based (floating point for smooth motion)
**Fonts**: TTF (variable width fonts supported)
**Features**:
- Pixel-perfect positioning and smooth scrolling
- Multiple fonts simultaneously
- Alpha blending, rotations, shaders
- Hardware-accelerated rendering

**Rendering pipeline**:
1. Draw to SDLCanvas (render target texture)
2. Composite layers with GPU blending
3. Render TTF glyphs to texture
4. Present to window or WebGL canvas

## Backend Selection

Backends are selected at compile time using conditional compilation:

```nim
# In main file or build config:
when defined(sdl3Backend):
  import backends/sdl3/sdl_canvas
  type RenderBuffer = SDLCanvas
else:
  import backends/terminal/termbuffer
  type RenderBuffer = TermBuffer
```

This means:
- Zero runtime overhead (no vtables, no dynamic dispatch)
- Dead code elimination removes unused backends
- Each build only includes what it needs

## Build Targets

| Backend | Native | Emscripten |
|---------|--------|------------|
| **Terminal** | `nim c tstorie.nim` | `nim c -d:emscripten tstorie.nim` |
| **SDL3** | `nim c -d:sdl3Backend tstorie.nim` | `nim c -d:emscripten -d:sdl3Backend tstorie.nim` |

## Migration Roadmap

### ✅ Phase 1: Abstraction Layer (Current)
- Created backends directory structure
- Defined buffer interface
- Moved terminal code to backends/terminal/
- No functional changes

### Phase 2: Backend Selection
- Add conditional compilation in tstorie.nim
- Update canvas.nim to use backend types
- Test that terminal builds still work

### Phase 3: SDL3 Implementation
- Implement SDL3 canvas renderer
- Add SDL3 native windowing
- Port input handling to SDL3 events

### Phase 4: Emscripten SDL3
- Add SDL3 emscripten backend
- Test web SDL3 builds

### Phase 5: SDL3-Specific Features
- TTF font loading and rendering
- Smooth pixel-level scrolling
- Custom shaders and effects

## Design Principles

1. **High-level code doesn't know about backends**
   - Canvas, animation, particles use abstract interface
   - 95% code reuse across all backends

2. **Backends implement same operations differently**
   - Terminal: Round to cell, use ANSI codes
   - SDL3: Pixel position, render TTF glyphs

3. **Compile-time selection, zero runtime cost**
   - No vtables, no dynamic dispatch
   - Each build is fully optimized

4. **Terminal features work everywhere**
   - Figlets generate strings (backend-agnostic)
   - ASCII art patterns work in both terminals and SDL3

## Adding a New Backend

To add a new backend (e.g., raylib, Sixel graphics):

1. Create directory: `backends/mybackend/`
2. Implement buffer interface in `backends/mybackend/mybuffer.nim`
3. Add rendering/display logic
4. Add conditional compilation to main file
5. Define build flag: `nim c -d:mybackendBackend tstorie.nim`

The rest of tStorie (canvas, animation, etc.) automatically works with your backend!

## Questions?

See [ARCHITECTURE_BACKENDS.md](../ARCHITECTURE_BACKENDS.md) for the full architectural overview.
