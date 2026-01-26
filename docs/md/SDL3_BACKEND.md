# SDL3 Backend Quick Reference

## Compilation

### Terminal Backend (Default)
```bash
nim c tstorie.nim
nim c -d:release tstorie.nim
```

### SDL3 Backend
```bash
# Development build
nim c -d:sdl3Backend tstorie.nim

# Release build
nim c -d:release -d:sdl3Backend tstorie.nim

# WebAssembly (Emscripten)
nim c -d:emscripten -d:sdl3Backend tstorie.nim
```

## Prerequisites

### Native Builds

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install libsdl3-dev libsdl3-ttf-dev
```

#### Arch Linux
```bash
sudo pacman -S sdl3 sdl3_ttf
```

#### macOS
```bash
brew install sdl3 sdl3_ttf
```

#### Windows
Download SDL3 development libraries from [libsdl.org](https://www.libsdl.org/) and configure paths in `backends/sdl3/bindings/build_config.nim`.

### WebAssembly Builds

Emscripten includes SDL3 automatically - no additional setup needed!

```bash
source ~/emsdk/emsdk_env.sh
nim c -d:emscripten -d:sdl3Backend tstorie.nim
```

## Architecture

### File Organization

```
backends/sdl3/
├── sdl3_bindings.nim          # Main module (imports all bindings)
├── sdl_canvas.nim             # Canvas/rendering implementation
├── sdl_window.nim             # Window and input management
└── bindings/                  # Direct C bindings (no wrappers!)
    ├── build_config.nim       # Compiler flags and linking
    ├── types.nim              # SDL types (SDL_Window, etc.)
    ├── core.nim               # Window/init functions
    ├── render.nim             # Drawing operations
    ├── events.nim             # Input events
    └── ttf.nim                # Font rendering
```

### Key Types

```nim
# Canvas
type SDLCanvas* = ref object
  window*: ptr SDL_Window
  renderer*: ptr SDL_Renderer
  width*, height*: int
  bgColor*: tuple[r, g, b: uint8]

# Input Events
type SDLInputEvent* = object
  kind*: SDLInputEventKind    # SDLQuit, SDLKeyDown, SDLResize, etc.
  key*: int
  ch*: string

type SDLInputEventKind* = enum
  SDLQuit, SDLKeyDown, SDLKeyUp, SDLMouseMove, SDLResize, SDLUnknown
```

## API Reference

### Canvas Operations

```nim
# Create canvas
let canvas = newSDLCanvas(800, 600, "My App")

# Clear canvas
canvas.clear((0'u8, 0'u8, 0'u8))  # Black background

# Draw text
canvas.writeText(10, 10, "Hello SDL3!", style)

# Fill rectangle
canvas.fillRect(100, 100, 200, 150, " ", style)

# Present to screen
canvas.present()

# Cleanup
canvas.shutdown()
```

### Window Management

```nim
# Get window size
let (w, h) = canvas.getSize()

# Set background color
canvas.setBackgroundColor(255'u8, 0'u8, 0'u8)  # Red
```

### Input Handling

```nim
# Non-blocking poll
for event in canvas.pollEvents():
  case event.kind
  of SDLQuit:
    quit(0)
  of SDLKeyDown:
    echo "Key pressed: ", event.key
  of SDLResize:
    echo "Window resized to: ", canvas.getSize()
  else:
    discard

# Blocking wait with timeout
let event = canvas.waitEvent(timeoutMs = 100)
if event.kind == SDLQuit:
  quit(0)
```

### Clipping and Offset

```nim
# Set clipping region
canvas.setClip(50, 50, 300, 200)
canvas.writeText(100, 100, "Clipped text", style)
canvas.clearClip()

# Set rendering offset
canvas.setOffset(100, 50)
canvas.writeText(0, 0, "Offset text", style)  # Actually at (100, 50)
canvas.setOffset(0, 0)
```

## Differences from Terminal Backend

| Feature | Terminal Backend | SDL3 Backend |
|---------|------------------|--------------|
| **Units** | Character cells | Pixels |
| **Resolution** | Terminal size (e.g., 80×24) | Window size (e.g., 1920×1080) |
| **Colors** | 256-color, true-color | True RGB (16.7M colors) |
| **Text** | Monospace, character grid | TTF fonts, any size |
| **Rendering** | ANSI escape codes | Hardware-accelerated |
| **Performance** | Fast (minimal CPU) | Very fast (GPU) |
| **Smoothness** | Character-aligned | Sub-pixel precision |

## Common Patterns

### Basic App Loop

```nim
when defined(sdl3Backend):
  import backends/sdl3/sdl_canvas
  import backends/sdl3/sdl_window
  
  proc main() =
    let canvas = newSDLCanvas(800, 600, "My App")
    defer: canvas.shutdown()
    
    var running = true
    while running:
      # Handle input
      for event in canvas.pollEvents():
        if event.kind == SDLQuit:
          running = false
      
      # Render
      canvas.clear((0'u8, 0'u8, 0'u8))
      canvas.writeText(10, 10, "Hello, SDL3!", defaultStyle)
      canvas.present()
  
  main()
```

### Cross-Platform Code

```nim
# Works with BOTH terminal and SDL3 backends!
proc drawBox(buffer: auto, x, y, w, h: int, style: Style) =
  for dy in 0..<h:
    for dx in 0..<w:
      buffer.write(x + dx, y + dy, "█", style)

# Compile with terminal backend:
#   nim c myapp.nim
# Compile with SDL3 backend:
#   nim c -d:sdl3Backend myapp.nim
```

## Current Limitations

1. **Font Rendering**: Using SDL_RenderDebugText (basic). Full TTF support coming in Phase 3.5.

2. **Input Mapping**: Scancode-to-key mapping incomplete. Currently returns placeholder values.

3. **Performance**: Not yet optimized. Texture caching and dirty rectangles to be added.

4. **Features**: Some SDL3 features not yet exposed (audio, advanced rendering, etc.).

## Troubleshooting

### "SDL3 not found"

**Solution**: Install SDL3 development libraries (see Prerequisites above).

### "undefined reference to SDL_*"

**Solution**: Update linker flags in `backends/sdl3/bindings/build_config.nim`:

```nim
{.passL: "-lSDL3".}
{.passL: "-lSDL3_ttf".}
```

### "Window created but black screen"

**Solution**: Make sure to call `canvas.present()` after rendering!

## Examples

See documentation in:
- `docs/PHASE3_COMPLETE.md` - Full phase 3 documentation
- `docs/ARCHITECTURE_BACKENDS.md` - Multi-backend architecture
- Terminal examples work with SDL3 - just add `-d:sdl3Backend`!

## Next Steps

### Phase 3.5 (Coming Soon)
- Full TTF font support with multiple sizes/styles
- Complete keyboard/mouse input mapping
- Texture caching for performance
- Advanced rendering (blending, effects)

## Contributing

To add new SDL3 functions:

1. Add binding to appropriate file in `backends/sdl3/bindings/`
2. Follow the direct C binding pattern:
   ```nim
   proc SDL_NewFunction*(params: types): ReturnType {.
     importc, 
     header: "SDL3/SDL_header.h"
   .}
   ```
3. Test compilation: `nim check -d:sdl3Backend tstorie.nim`
4. Document in this guide

---

**Status**: ✅ Phase 3 Complete  
**Backend**: SDL3 (pixel-based, hardware-accelerated)  
**Compatibility**: Terminal code runs unchanged on SDL3!
