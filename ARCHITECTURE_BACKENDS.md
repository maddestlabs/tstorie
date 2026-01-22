# tStorie Multi-Backend Architecture

## Overview

tStorie uses a unified codebase with compile-time backend selection, supporting four distinct build targets:

```
                 Terminal Backend    |    SDL3 Backend
                 ─────────────────────────────────────────
Native           Lightweight CLI     |  Desktop multimedia
                 (current default)   |  (graphics + audio)
                 ─────────────────────────────────────────
Emscripten       Text-based web      |  Rich web apps
                 (current WebGL)     |  (SDL3 canvas)
```

## Build Targets

### Terminal + Native (Default)
```bash
nim c tstorie.nim
```
- **Use Case**: Quick sketches, CLI tools, server-side rendering
- **Features**: ANSI colors, figlets, ASCII art, minimal dependencies
- **Size**: ~2MB binary
- **Load Time**: Instant

### Terminal + Emscripten (Current Web Build)
```bash
nim c -d:emscripten tstorie.nim
```
- **Use Case**: Interactive terminal art, code demos, text-based games
- **Features**: Custom WebGL renderer, shader pipeline, monospace grid
- **Tech**: Character-cell rendering, Web Audio API bridge
- **Best For**: Terminal-style interactive content

### SDL3 + Native (New)
```bash
nim c -d:sdl3Backend tstorie.nim
```
- **Use Case**: Full desktop apps, game development, audio visualization
- **Features**: Pixel-level graphics, multiple fonts, smooth animations, miniaudio
- **Tech**: SDL3 graphics + input, TTF fonts, OpenGL/Metal/DirectX
- **Best For**: Rich multimedia applications

### SDL3 + Emscripten (New)
```bash
nim c -d:emscripten -d:sdl3Backend tstorie.nim
```
- **Use Case**: Rich web games, multimedia presentations, WebGL + audio
- **Features**: Same as SDL3 native, but runs in browser
- **Tech**: SDL3's emscripten backend (unified graphics/audio/input)
- **Best For**: Browser-based multimedia that needs more than terminal rendering

## Core Architecture Principles

### 1. Type Abstraction (95% Code Reuse)

Core types are backend-agnostic:

```nim
# src/types.nim - works everywhere
type
  Color* = object
    r*, g*, b*: uint8
  
  Style* = object
    fg*, bg*: Color
    bold*, italic*, underline*, dim*: bool
  
  Cell* = object
    ch*: string
    style*: Style
```

### 2. Backend Interface Pattern

Backends implement common operations:

```nim
# Concept: Any backend must support these operations
type RenderBuffer* = concept buffer
  buffer.write(x, y: int, text: string, style: Style)
  buffer.fill(x, y, w, h: int, ch: string, style: Style)
  buffer.clear(bg: Color)
  buffer.width: int
  buffer.height: int
```

### 3. Conditional Compilation (Zero Runtime Overhead)

```nim
when defined(emscripten):
  when defined(sdl3Backend):
    import backends/sdl3/sdl_web
  else:
    import backends/terminal/term_web
else:
  when defined(sdl3Backend):
    import backends/sdl3/sdl_native
  else:
    import backends/terminal/term_native
```

## Canvas Module Architecture

The canvas module contains three distinct layers:

### Layer 1: Navigation Core (Backend-Agnostic) ✅

**100% reusable across all backends**

```nim
type
  Camera* = object
    x*, y*: float          # Works in pixels OR cells
    targetX*, targetY*: float
    smoothFactor*: float
  
  SectionLayout* = object
    section*: Section
    x*, y*: float          # Backend units (pixels or cells)
    width*, height*: float
    navigable*: bool
  
  Link* = object
    text*: string
    target*: string
    screenX*, screenY*: int
```

**Features:**
- Smooth camera panning
- Section-to-section navigation
- Link tracking and interaction
- Coordinate transformations
- Input handling (mouse/keyboard)

### Layer 2: Layout Engine (Abstracted)

**Backend-specific constants, shared logic:**

```nim
when defined(sdl3Backend):
  const
    SECTION_WIDTH = 800.0   # pixels
    SECTION_HEIGHT = 600.0
    SECTION_PADDING = 50.0
else: # terminal
  const
    SECTION_WIDTH = 60.0    # character cells
    SECTION_HEIGHT = 20.0
    SECTION_PADDING = 10.0

# Shared layout algorithm works with either unit system
proc calculateSectionPositions*(sections: seq[Section]): seq[SectionLayout] =
  var layouts: seq[SectionLayout]
  var currentX, currentY = 0.0
  
  for section in sections:
    layouts.add(SectionLayout(
      x: currentX,
      y: currentY,
      width: SECTION_WIDTH,
      height: SECTION_HEIGHT
    ))
    currentX += SECTION_WIDTH + SECTION_PADDING
  
  return layouts
```

### Layer 3: Rendering (Backend-Specific)

**Terminal Backend:**
```nim
# backends/terminal/canvas_terminal_renderer.nim
type TerminalCanvasRenderer* = object
  buffer: ptr TermBuffer
  units: CanvasUnits = CellBased

proc drawText*(r: var TerminalCanvasRenderer, 
               x, y: float, text: string, style: RenderStyle) =
  let cellX = int(x)  # Round to character cell
  let cellY = int(y)
  r.buffer[].writeText(cellX, cellY, text, style.toTermStyle())

proc getTextBounds*(r: var TerminalCanvasRenderer,
                    text: string, style: RenderStyle): Bounds =
  # Character-based bounds
  Bounds(width: float(text.len), height: 1.0)
```

**SDL3 Backend:**
```nim
# backends/sdl3/canvas_sdl3_renderer.nim
type SDL3CanvasRenderer* = object
  renderer: ptr SDL_Renderer
  fonts: Table[string, ptr TTF_Font]  # Multiple font support!
  units: CanvasUnits = PixelBased

proc drawText*(r: var SDL3CanvasRenderer,
               x, y: float, text: string, style: RenderStyle) =
  let font = r.fonts.getOrDefault(style.fontFamily, r.defaultFont)
  
  # Pixel-perfect rendering with sub-pixel positioning
  let surface = TTF_RenderText_Blended(font, text.cstring, style.color)
  let texture = SDL_CreateTextureFromSurface(r.renderer, surface)
  
  var destRect = SDL_Rect(x: int(x), y: int(y), w: surface.w, h: surface.h)
  SDL_RenderCopy(r.renderer, texture, nil, addr destRect)

proc getTextBounds*(r: var SDL3CanvasRenderer,
                    text: string, style: RenderStyle): Bounds =
  # Actual pixel bounds from TTF font metrics
  let font = r.fonts.getOrDefault(style.fontFamily, r.defaultFont)
  var w, h: cint
  TTF_SizeText(font, text.cstring, addr w, addr h)
  Bounds(width: float(w), height: float(h))
```

## Terminal Features in SDL3

**Key Insight:** Terminal features (figlets, ASCII art) are character generators, not renderers!

### Figlet Example
```nim
# lib/figlet.nim - pure string generation
proc renderText*(font: FIGfont, text: string): seq[string] =
  # Returns ASCII art as strings
  # ["  _   _      _ _       ", 
  #  " | | | | ___| | | ___  ",
  #  " | |_| |/ _ \ | |/ _ \ "]

# Works in BOTH backends:
let figletLines = font.renderText("Hello")

when defined(terminalBackend):
  # Write character-by-character
  for y, line in figletLines:
    buffer.writeText(x, y, line, style)

when defined(sdl3Backend):
  # Render as monospace font texture OR
  # Render each character as individual textured quad
  for y, line in figletLines:
    for x, ch in line:
      sdl.renderChar(x * charWidth, y * charHeight, ch, style)
```

### ASCII Art Example
```nim
# lib/ascii_art.nim - pattern generator
proc generatePattern*(w, h: int, seed: int): PatternFunc =
  # Returns closure: (x, y) -> character
  return proc(x, y: int): string =
    # Generate character based on position
    if (x + y) mod 3 == 0: "░" else: "▓"

# Works in BOTH backends:
let pattern = generatePattern(width, height, 42)

for y in 0..<height:
  for x in 0..<width:
    let ch = pattern(x, y)
    renderer.drawChar(x, y, ch, style)  # Same API!
```

## Advantages of Unified Architecture

### 1. No Code Duplication
- Core libraries (particles, animation, graph, audio_gen) work everywhere
- Navigation and UI logic written once
- Terminal features automatically work in SDL3

### 2. Compile-Time Optimization
- Zero runtime overhead from backend selection
- Dead code elimination removes unused backends
- Each build only includes what it needs

### 3. Incremental Migration
- Terminal builds stay unchanged (backward compatible)
- SDL3 features added gradually
- Both backends coexist during development

### 4. Feature Parity
- All animation/timing code shared
- Input handling abstracted
- Audio unified through miniaudio (native) / Web Audio (emscripten)

### 5. Developer Experience
- Write code once, deploy to 4 targets
- Test features in lightweight terminal build
- Ship rich multimedia when needed

## Directory Structure

```
tstorie/
├── tstorie.nim              # Main entry, backend selection
├── src/
│   ├── types.nim            # Backend-agnostic core types
│   ├── input.nim            # Unified input handling
│   ├── layers.nim           # Buffer/layer abstractions
│   └── appstate.nim         # Core application state
├── lib/
│   ├── canvas.nim           # Navigation core + backend dispatch
│   ├── animation.nim        # Backend-agnostic animations
│   ├── particles.nim        # Particle systems (work anywhere)
│   ├── figlet.nim           # ASCII art generator (pure strings)
│   ├── ascii_art.nim        # Pattern generators (pure logic)
│   └── audio_gen.nim        # Audio DSP (backend-agnostic)
├── backends/
│   ├── buffer_interface.nim # Concept/trait definitions
│   ├── terminal/
│   │   ├── termbuffer.nim           # Character-cell buffer
│   │   ├── term_native.nim          # ANSI terminal output
│   │   ├── term_web.nim             # WebGL renderer
│   │   └── canvas_terminal_renderer.nim
│   └── sdl3/
│       ├── sdl_canvas.nim           # SDL3 render target
│       ├── sdl_native.nim           # Native SDL3 windowing
│       ├── sdl_web.nim              # Emscripten SDL3
│       └── canvas_sdl3_renderer.nim
└── nimini/                  # Runtime scripting (backend-agnostic)
```

## Migration Path

### Phase 1: Abstraction Layer (Low Risk) ✅ **COMPLETE**
- [x] Create `backends/` directory structure
- [x] Define buffer interface concept
- [x] Move terminal code to `backends/terminal/`
- [x] No functional changes, just organization

**See [docs/PHASE1_COMPLETE.md](docs/PHASE1_COMPLETE.md) for details.**

### Phase 2: Backend Selection ✅ **COMPLETE**
- [x] Add conditional compilation in tstorie.nim
- [x] Implement backend type aliases
- [x] Update canvas.nim to use float coordinates
- [x] Test terminal builds still work identically

**See [docs/PHASE2_COMPLETE.md](docs/PHASE2_COMPLETE.md) for details.**

### Phase 3: SDL3 Implementation
- [ ] Implement SDL3 canvas renderer
- [ ] Add SDL3 native windowing
- [ ] Port input handling to SDL3 events
- [ ] Test SDL3 native builds

### Phase 4: Emscripten SDL3
- [ ] Add SDL3 emscripten backend
- [ ] Test web SDL3 builds
- [ ] Compare with terminal web builds

### Phase 5: SDL3-Specific Features
- [ ] TTF font loading and rendering
- [ ] Non-monospace text support
- [ ] Pixel-level smooth scrolling
- [ ] Custom shaders (OpenGL/WebGL)
- [ ] Alpha blending and effects

## Build System Updates

### tstorie.nimble
```nim
# Add backend-specific tasks

task buildTermNative, "Build terminal native":
  exec "nim c -o:bin/tstorie tstorie.nim"

task buildTermWeb, "Build terminal web":
  exec "nim c -d:emscripten -o:web/tstorie.js tstorie.nim"

task buildSDLNative, "Build SDL3 native":
  exec "nim c -d:sdl3Backend -o:bin/tstorie-sdl tstorie.nim"

task buildSDLWeb, "Build SDL3 web":
  exec "nim c -d:emscripten -d:sdl3Backend -o:web/tstorie-sdl.js tstorie.nim"

task buildAll, "Build all targets":
  buildTermNativeTask()
  buildTermWebTask()
  buildSDLNativeTask()
  buildSDLWebTask()
```

## Performance Characteristics

| Build Target | Binary Size | Load Time | Features |
|--------------|-------------|-----------|----------|
| Terminal Native | ~2MB | <50ms | Text, ANSI, figlets, fast |
| Terminal Web | ~1MB WASM | ~200ms | WebGL shaders, interactive |
| SDL3 Native | ~8MB | ~100ms | Full graphics, audio, TTF |
| SDL3 Web | ~4MB WASM | ~500ms | WebGL/WebGPU, full features |

## Future Possibilities

### Multiple Rendering Backends
- Raylib backend (alternative to SDL3)
- Terminal backend with Sixel graphics support
- Vulkan backend for maximum performance

### Hybrid Rendering
- SDL3 window with terminal-style character grid
- Mix pixel graphics with ASCII overlays
- Terminal emulator written in tStorie!

### Cross-Platform Deployment
- Mobile (SDL3 supports iOS/Android)
- Consoles (through SDL3)
- Raspberry Pi (terminal or SDL3)

## Philosophy

> **tStorie is one engine with multiple backends, not multiple engines.**

The core abstractions (Sections, Canvas, Animation, Particles, Audio) transcend any specific rendering technology. Terminal and SDL3 are just different ways to present the same creative medium.

This architecture allows creators to:
- Start fast with terminal prototypes
- Deploy rich web experiences with one flag
- Ship desktop apps without rewriting
- Choose the right tool for each project

**Write once. Deploy everywhere. Stay creative.**
