# WebGPU Integration - Complete Reference

**Status:** ✅ Phase 5 Complete (Compute), � Phase 6 In Progress (Full Rendering)

This document provides comprehensive reference for TStorie's WebGPU integration, including current compute shader implementation and in-progress full rendering pipeline migration.

---

## Strategic Direction

TStorie is moving toward **full WebGPU for web**, diverging from SDL3 to optimize for web delivery:

### Platform Split (Intentional)
```
Web:    Full WebGPU (rendering + compute) + Canvas 2D fonts + WebAudio
        → Optimized for size, speed, browser capabilities
        
Native: SDL3 (rendering) + CPU compute + TTF fonts + MiniAudio
        → Unified desktop experience
```

### Why Diverge from SDL3 for Web?

**Size:** SDL3 WASM (~2.5MB) vs WebGPU (~600KB) - **Critical for itch.io**
- Faster loads
- Better conversion rates
- Mobile-friendly

**Fonts:** Browser font fallback >> SDL3 TTF
- System fonts automatically available
- No font file shipping
- Better international support
- Emoji support free

**Audio:** WebAudio API >> SDL3 >> MiniAudio for web
- Advanced spatial audio
- Web Audio API features
- Better browser integration

**Performance:** Modern GPU API
- Unified rendering + compute context
- Better batching
- Future-proof

### Current State (Phase 6 Complete)

| Component | Implementation | Status |
|-----------|---------------|---------|
| Compute shaders | WebGPU | ✅ Production |
| Terminal rendering | WebGPU (with WebGL fallback) | ✅ Production |
| Text rendering | Canvas 2D | ✅ Production |
| Fallback | Automatic WebGL fallback | ✅ Production |
| Size | ~620KB | ✅ Production |

---

## Table of Contents

1. [Strategic Direction](#strategic-direction)
2. [Overview](#overview)
3. [Architecture](#architecture)
4. [Platform Detection System](#platform-detection-system)
5. [API Reference](#api-reference)
6. [File Structure](#file-structure)
7. [Build System](#build-system)
8. [Usage Examples](#usage-examples)
9. [Export Support](#export-support)
10. [Performance](#performance)
11. [Browser Compatibility](#browser-compatibility)
12. [Migration Roadmap](#migration-roadmap)

---

## Overview

TStorie's web build uses WebGPU for GPU acceleration with automatic WebGL fallback.

**Current (Phase 6 - Complete):**
- ✅ WebGPU compute shaders - 50-300× faster noise generation
- ✅ WebGPU rendering - Terminal grid (with automatic WebGL fallback)
- ✅ Canvas 2D - Text with browser font fallback
- ✅ Progressive enhancement - WebGPU → WebGL → CPU
- ✅ Unified GPU context - One API for compute + rendering

**Benefits:**
- **Unified Context** - No switching between WebGL and WebGPU
- **Modern API** - Better performance, cleaner code
- **Smaller Builds** - One primary GPU API
- **Future-Proof** - WebGPU is WebGL's successor
- **Better Integration** - Compute + rendering share resources
- **Progressive Enhancement** - Works on all browsers with automatic fallback

### Platform Philosophy

**Web = WebGPU Optimized**
- Smallest possible builds
- Browser-native features
- Fast loading (itch.io critical)
- Progressive enhancement

**Native = SDL3 Unified**  
- Cross-platform desktop
- Native performance
- Rich graphics capabilities
- TTF font rendering

---

## Architecture

### Current Architecture (Phase 6 Complete)

```
┌─────────────────────────────────────────────────────────┐
│                   Nimini Scripts                         │
│  (Markdown code blocks with noise() calls)              │
└──────────────────────┬───────────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────────┐
│              Runtime API (runtime_api.nim)               │
│  • nimini_noise(), nimini_noiseSample2D(), etc.          │
│  • nimini_webgpuStart(), nimini_webgpuGet(), etc.        │
│  • nimini_defined() - Platform detection                 │
└──────────────────────┬───────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼──────┐            ┌─────────▼─────────┐
│   CPU Path   │            │    GPU Path       │
│ (lib/noise/) │            │ (Web/WASM only)   │
│              │            │ COMPUTE SHADERS   │
└──────────────┘            └─────────┬─────────┘
                                      │
                            ┌─────────▼─────────────────────┐
                            │  webgpu_bridge_extern.js      │
                            │  (Emscripten external decls)  │
                            └─────────┬─────────────────────┘
                                      │
                            ┌─────────▼─────────────────────┐
                            │  webgpu_wasm_bridge.js        │
                            │  (Async→Sync bridge)          │
                            └─────────┬─────────────────────┘
                                      │
                            ┌─────────▼─────────────────────┐
                            │    webgpu_bridge.js           │
                            │  (GPU compute execution)      │
                            └───────────────────────────────┘

Rendering (Current - Phase 5):
┌───────────────────────────────────────────────────────────┐
│  WebGL Renderer (tstorie-webgl.js)                        │
│  • Terminal grid rendering                                │
│  • Vertex/Fragment shaders for text/graphics             │
│  • Canvas 2D fallback for text                           │
└───────────────────────────────────────────────────────────┘
```

### Target Architecture (Phase 6)

```
┌─────────────────────────────────────────────────────────┐
│                   Nimini Scripts                         │
│  (Markdown code blocks - same code!)                    │
└──────────────────────┬───────────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────────┐
│              Runtime API (runtime_api.nim)               │
│  • Same API - implementation swaps internally            │
└──────────────────────┬───────────────────────────────────┘
                       │
        ┌──Phase 6 - Progressive Enhancement):
┌───────────────────────────────────────────────────────────┐
│  Hybrid Renderer (tstorie-hybrid-renderer.js)            │
│  • Progressive enhancement: WebGPU → WebGL               │
│  • Automatic fallback based on browser support           │
│  │                                                        │
│  ├─→ WebGPU Renderer (tstorie-webgpu-render.js)        │
│  │   • Terminal grid rendering                           │
│  │   • Render pipeline for text/graphics                │
│  │Data Flow (Unified GPU
1. **Resource Sharing** - Compute results feed directly to rendering
2. **No Context Switch** - Single GPU device for everything
3. **Better Performance** - Less overhead, better batching
4. **Simpler Code** - One GPU API instead of two
5. **Smaller Build** - Remove WebGL code (~20KB saved)

### Data Flow

**CPU Path (Always Available):**
```
Script → Runtime API → Noise Library → Direct sampling → Result
```

**GPU Path (Web only, when available):**
```
Script → Runtime API → Start GPU execution → Poll for ready → Get results
         ↓
    CPU continues running (non-blocking)
```

### Bridge Architecture

The WebGPU integration uses a three-layer bridge:

1. **webgpu_bridge.js** - High-level API for GPU compute execution
2. **webgpu_wasm_bridge.js** - Async→Sync bridge with result caching
3. **webgpu_bridge_extern.js** - Emscripten external function declarations

This allows synchronous Nim/WASM code to call asynchronous JavaScript WebGPU APIs via a polling mechanism.

---

## Platform Detection System

### Runtime Detection: `defined()` Function

Scripts can detect their platform at runtime:

```nim
if defined("web"):
  # Web-specific code
  if webgpuSupport (when WebGPU available):**
```
Script → Runtime API → Single GPUDevice
                       ├─→ Compute pipeline (noise)
                       └─→ Render pipeline (terminal)
```

**Fallback Path (when WebGPU unavailable):**
```
Script → Runtime API → WebGL Renderer
                       └─→ Vertex/Fragment shaders (terminal)
```

**Text (both paths):**
```
Text → Canvas 2D → Browser fonts
```

### Benefits of Unified Context

1. **Resource Sharing** - Compute results feed directly to rendering
2. **No Context Switch** - Single GPU device for everything (when available)
3. **Better Performance** - Less overhead, better batching
4. **Simpler Code** - One GPU API instead of two
5. **Progressive Enhancement** - Automatic fallback ensures universal compatibility
| `"macosx"` or `"macos"` | Running on macOS |
| `"debug"` | Built in debug mode |
| `"release"` | Built in release mode |

**Case-insensitive:** `defined("Web")` and `defined("WEB")` both work.

### Implementation

**Runtime (runtime_api.nim):**
```nim
proc nimini_defined(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Runtime platform detection
  if args.len < 1: return valBool(false)
  
  let symbol = args[0].s
  
  when defined(emscripten):
    if symbol == "emscripten" or symbol == "web":
      return valBool(true)
  # ... more checks
```

**Export Transform (nim_export.nim):**
```nim
# Scripts using defined() are transformed during export:
if defined("web"):       # → when defined(emscripten):
  callWebGPU()           #     callWebGPU()
```

This allows scripts to work identically at runtime and when exported to native Nim.

---

## API Reference

### Noise Configuration (Available everywhere)

```nim
# Create noise configuration
let config = noise(ntPerlin2D)
  .seed(42)
  .scale(100)
  .octaves(4)
  .gain(500)
  .lacunarity(2000)

# CPU sampling (always works)
let value = config.sample2D(x, y)
let value3d = config.sample3D(x, y, z)

# Generate WGSL shader code
let shader = config.toWGSL()
```

### WebGPU Execution API (Web only)

**Check availability:**
```nim
if defined("web"):
  let supported = webgpuSupported()  # Is WebGPU API available?
  let ready = webgpuReady()          # Is GPU initialized and ready?
```

**Execute on GPU:**
```nim
# Start GPU execution (non-blocking)
let started = webgpuStart(config, width, height, offsetX, offsetY)

# Poll for completion
if webgpuIsReady():
  # Get dimensions
  let (w, h) = webgpuSize()
  
  # Get individual values
  for y in 0..<h:
    for x in 0..<w:
      let value = webgpuGet(x, y)
      # Process value...

# Cancel if needed
webgpuCancel()
```

### Platform Detection

```nim
# Check platform
if defined("web"):
  print("Running in browser")
  if webgpuSupported():
    print("WebGPU available!")

if defined("native"):
  print("Running as native binary")

if defined("linux"):
  print("Linux-specific code")
```

---

## File Structure

### Source Files (src/)

**runtime_api.nim** - Main runtime API
- `nimini_noise()` - Create noise configurations
- `nimini_noiseSample2D/3D()` - CPU sampling
- `nimini_noiseToWGSL()` - Generate shader code
- `nimini_webgpuSupported/Ready/Start/Get()` - GPU execution
- `nimini_defined()` - Platform detection

### Web Bridge Files (web/)

**webgpu_bridge.js** (13 KB) - High-level GPU API
```javascript
class WebGPUBridge {
  async executeNoiseShader(wgsl, width, height, offsetX, offsetY)
  // Returns Float32Array of noise values
}
```

**webgpu_wasm_bridge.js** - WASM↔JS Bridge
```javascript
// Synchronous functions callable from WASM:
function tStorie_webgpuStartExecution(wgslPtr, w, h, offX, offY)
function tStorie_webgpuIsResultReady()
function tStorie_webgpuGetValue(x, y)
function tStorie_webgpuGetResultSize()
function tStorie_webgpuCancel()
```

**webgpu_bridge_extern.js** - Emscripten declarations
```javascript
mergeInto(LibraryManager.library, {
  tStorie_webgpuIsSupported: function() { ... },
  tStorie_webgpuIsReady: function() { ... },
  // ... 5 more functions
});
```

### Output Files (docs/)

After building:
- `tstorie.wasm.js`, `tstorie.wasm` - Main application
- `tstorie-webgl.js` - **Terminal renderer (WebGL vertex/fragment shaders)**
- `webgpu_bridge.js` - **GPU compute API (WebGPU compute shaders, optional)**
- `index.html` - Standard build (WebGL rendering, no GPU compute)
- `index-webgpu.html` - GPU-enabled build (WebGL rendering + GPU compute)

**Key Point:** Both builds use WebGL for rendering. The difference is GPU compute availability.

---

## Build System

### Build Scripts

**build-web.sh** - Standard web build with WebGPU + automatic fallback
```bash
./build-web.sh              # Compile to docs/ with WebGPU (auto-fallback to WebGL)
./build-web.sh -s           # Compile and serve
./build-web.sh -d           # Debug mode
```
- Outputs: `docs/tstorie.wasm.js`, `docs/index.html`
- **Uses WebGPU by default** with automatic WebGL fallback
- Copies all necessary files: WebGL, WebGPU, and hybrid renderer
- Progressive enhancement: tries WebGPU first, falls back to WebGL if unavailable
- Scripts can use `defined("web")` and WebGPU functions

**build-webgpu.sh** - WebGPU-focused build (legacy/testing)
```bash
./build-webgpu.sh           # Compile with WebGPU demo page
./build-webgpu.sh -s        # Compile and serve
```
- Outputs: `docs/tstorie-webgpu.wasm.js`, `docs/index-webgpu.html`
- Dedicated WebGPU testing page with GPU toggles
- Same functionality as build-web.sh but separate output

**build.sh** - Native build
```bash
./build.sh                  # Compile native binary
./ts docs/demos/webgpu.md   # Run demo in terminal
```
- Outputs: `tstorie` binary
- `defined("web")` returns false
- WebGPU functions not called (protected by defined() checks)

### Build Chybrid-renderer.js` - **Progressive enhancement wrapper**
- `tstorie-webgpu-render.js` - **WebGPU terminal renderer (primary)**
- `tstorie-webgl.js` - **WebGL terminal renderer (automatic fallback)**
- `webgpu_bridge.js` - **GPU compute API (unified with rendering)**
- `index.html` - Standard build (WebGPU with auto-fallback to WebGL)
- `index-webgpu.html` - Legacy/testing build (same functionality)

**Key Point:** Both builds use progressive enhancement: WebGPU → WebGL → CPU. The system automatically selects the best available backend
| GPU API | WebGPU (auto-fallback) | WebGPU (auto-fallback) | None |
| Size | ~620 KB | ~620 KB | ~1.5 MB |
| Target | Universal/Production | Testing/Legacy | Desktop |
| Use case | Main web deployment | GPU-specific testing | Local/native |

**Progressive Enhancement* - Tries WebGPU first, automatically falls back to WebGL if unavailableack/legacy | Production web | Local/native |

**Phase 6 changes*

### Strategic Split

**Web (build-webgpu.sh):**
```
✅ Full WebGPU (compute + render)
✅ Canvas 2D fonts (browser fallback)
✅ WebAudio API
✅ ~600KB builds
✅ Optimized for itch.io/web delivery
```

**Native (build.sh / SDL3):**
```
✅ SDL3 graphics
✅ TTF font rendering
✅ MiniAudio (+ WebAudio features)
✅ Cross-platform desktop
✅ Rich graphics capabilities
```

**This split is intentional and beneficial!**

---

## Usage Examples

### Basic GPU-Accelerated Noise

```nim
# on:init
var noiseConfig = noise(ntPerlin2D)
  .seed(42)
  .scale(100)
  .octaves(4)

var gpuAvailable = false
if defined("web"):
  gpuAvailable = webgpuSupported() and webgpuReady()

# on:render
if defined("web") and gpuAvailable:
  # Try GPU execution
  if webgpuStart(noiseConfig, 64, 64, 0, 0):
    # Wait for results...
    if webgpuIsReady():
      let (w, h) = webgpuSize()
      for y in 0..<h:
        for x in 0..<w:
          let value = webgpuGet(x, y)
          # Draw with value...
else:
  # CPU fallback
  for y in 0..<64:
    for x in 0..<64:
      let value = noiseConfig.sample2D(x, y)
      # Draw with value...
```

### GPU Toggle with Status Display

```nim
# on:init
var useGPU = false
var gpuAvailable = false

if defined("web"):
  if webgpuSupported():
    gpuAvailable = webgpuReady()

# on:input
if key == "g" or key == "G":
  if defined("web") and gpuAvailable:
    useGPU = not useGPU
    print("GPU mode: " + (if useGPU: "ON" else: "OFF"))

# on:render
if defined("web") and gpuAvailable:
  print("GPU: " + (if useGPU: "ENABLED" else "AVAILABLE"))
else:
  print("GPU: N/A")
```

### Cross-Platform Noise Generation

```nim
# This code works identically in browser and terminal!

# on:init
let terrain = noise(ntPerlin2D)
  .seed(12345)
  .scale(50)
  .octaves(6)
  .ridged()

# on:render
for y in 0..<termHeight:
  for x in 0..<termWidth:
    let value = terrain.sample2D(x, y)
    let char = if value > 0.5: "▓" else: "░"
    draw(x, y, char, getStyle("default"))

# When running in web with WebGPU:
# - Can optionally use webgpuStart() for batch generation
# When running natively:
# - Uses CPU sampling (no WebGPU code compiled)
```

### Complete Demo

See [docs/demos/webgpu.md](docs/demos/webgpu.md) for a full interactive demo with:
- Noise type switching
- FBM mode control
- Parameter adjustment
- GPU/CPU toggle
- Real-time visualization
- Performance comparison

---

## Export Support

### Automatic Transformation

When exporting scripts with `tstorie export`, the system automatically transforms runtime `defined()` calls to Nim's compile-time `when defined()`:

**Input (Nimini script):**
```nim
if defined("web"):
  if webgpuSupported():
    print("GPU available")

if defined("native"):
  print("Running natively")
```

**Output (Exported Nim):**
```nim
when defined(emscripten):
  if webgpuSupported():
    print("GPU available")

when not defined(emscripten):
  print("Running natively")
```

### Symbol Mapping

| Script Symbol | Exported Nim |
|--------------|-------------|
| `defined("web")` | `when defined(emscripten)` |
| `defined("native")` | `when not defined(emscripten)` |
| `defined("windows")` | `when defined(windows)` |
| `defined("linux")` | `when defined(linux)` |
| `defined("macosx")` | `when defined(macosx)` |

### Export Command

```bash
# Export to native Nim
tstorie export docs/demos/webgpu.md

# Output: webgpu.nim (fully compilable Nim program)
# - Runtime defined() → compile-time when defined()
# - WebGPU code conditionally compiled only for web targets
# - CPU fallback always available
```

The exported code compiles as native Nim and works correctly with Nim's standard compilation targets (C, C++, JavaScript).

---

## Performance

### Benchmark Results

Complex noise (Perlin 2D, 4 octaves, 512×512):

| Platform | Time | Speedup |
|----------|------|---------|
| CPU (single-threaded) | ~100ms | 1× |
| GPU (WebGPU compute) | ~2-5ms | **50-300×** |

### Factors Affecting Performance

**Better GPU performance when:**
- More octaves (3-6 octaves)
- Higher resolution (512×512 or larger)
- Complex FBM modes (ridged, billow, turbulence)
- Batch generation (many values at once)
- Dedicated GPU (vs integrated)

**Better CPU performance when:**
- Single-point sampling
- Small data sets (<64×64)
- Simple noise (1-2 octaves)
- GPU readback overhead significant

### Optimization Tips

1. **Batch GPU operations** - Generate entire noise fields, not individual points
2. **Keep results cached** - Don't regenerate every frame if parameters unchanged
3. **Use CPU for UI** - Text, input, drawing still uses WebGL/Canvas
4. **Progressive loading** - Start with CPU, upgrade to GPU when ready
5. **Provide fallback** - Always implement CPU path for compatibility

---

## Browser Compatibility

### Full Support

| Browser | Version | Notes |
|---------|---------|-------|
| Chrome | 113+ | Full WebGPU support |
| Edge | 113+ | Full WebGPU support |
| Safari | 18+ | Requires macOS Sonoma 14.3+ |

### Experimental Support

| Browser | Version | Requirements |
|---------|---------|--------------|
| Firefox | Nightly | Enable `dom.webgpu.enabled` flag |

### Feature Detection

Always check availability before using WebGPU:

```nim
if defined("web"):
  if webgpuSupported():
    # WebGPU API exists
    if webgpuReady():
      # GPU initialized and ready
      # Safe to call webgpuStart(), etc.
    else:
      # GPU initialization failed
      # Use CPU fallback
  else:
    # WebGPU not supported in this browser
    # Use CPU fallback
else:
  # Running natively - no WebGPU available
  # Use CPU (this code path not even compiled for web)
```

### Fallback Strategy

The recommended pattern:

```nim
# 1. Create noise configuration (works everywhere)
let noise = noise(ntPerlin2D).seed(42).octaves(4)

# 2. Try GPU if available (web only)
var gpuFailed = false
if defined("web") and webgpuSupported() and webgpuReady():
  if not webgpuStart(noise, width, height, 0, 0):
    gpuFailed = true

# 3. Fall back to CPU if needed (always works)
if gpuFailed or not defined("web"):
  for y in 0..<height:
    for x in 0..<width:
      let value = noise.sample2D(x, y)
      # Use value...
```

---

## Testing

### Test in Browser

```bash
cd /workspaces/telestorie
./build-webgpu.sh -s
# Opens http://localhost:8000/index-webgpu.html
```

Test pages:
- **index-webgpu.html** - Full TStorie with WebGPU
- **webgpu-diagnostic.html** - GPU capability checker
- **test-webgpu-noise.html** - Standalone noise demo

### Test Natively

```bash
cd /workspaces/telestorie
./build.sh
./ts docs/demos/webgpu.md
```

Should display demo without errors (WebGPU code not called).

### Test Export

```bash
./tstorie export docs/demos/webgpu.md
nim check webgpu.nim  # Should compile without errors
```

---

## Implementation Notes

### Why Polling Instead of Callbacks?

JavaScript WebGPU is async, but Nim/WASM runtime is synchronous. The polling architecture:
- Allows Nim code to remain synchronous and simple
- Prevents blocking the main thread
- Enables "fire and forget" GPU operations
- Lets CPU continue working while GPU processes

### Why Separate Bridge Files?

Three-layer architecture provides:
- **webgpu_bridge.js** - Clean high-level API, reusable
- **webgpu_wasm_bridge.js** - WASM-specific glue, handles memory
- **webgpu_bridge_extern.js** - Emscripten declarations, build system

This separation means:
- Bridge can be used outside WASM
- WASM code doesn't know about WebGPU complexity
- Build system easily includes/excludes WebGPU

### Why include WebGPU in build-web.sh?

Even though standard builds don't inject the bridge:
- Functions are linked (prevents undefined symbols)
- Scripts can use `defined("web")` safely
- No runtime errors if script calls GPU functions
- Easy migration: just switch HTML file to enable GPU

### Memory Management

Results cached in JavaScript until:
- New execution started
- Explicitly canceled
- Page unloaded

WASM calls use simple indices (x, y) - no complex memory transfer needed.

---

## Troubleshooting

### "undefined symbol: tStorie_webgpuXXX"

**Cause:** Build script missing WebGPU extern declarations.

**Fix:** Ensure build script includes:
```bash
--passL:--js-library --passL:web/webgpu_bridge_extern.js
```

Both `build-web.sh` and `build-webgpu.sh` include this.

### "Undefined variable 'defined'"

**Cause:** Native binary not rebuilt after adding `defined()` function.

**Fix:**
```bash
./build.sh  # Rebuild native binary
```

### GPU execution returns no results

**Possible causes:**
1. `webgpuSupported()` returns false - WebGPU not available
2. `webgpuReady()` returns false - GPU initialization failed
3. Shader compilation error - Check browser console
4. Result not ready yet - Poll with `webgpuIsReady()`

**Debug:**
```nim
if defined("web"):
  print("Supported: " + str(webgpuSupported()))
  print("Ready: " + str(webgpuReady()))
  
  if webgpuStart(config, w, h, 0, 0):
    print("Execution started")
  else:
    print("Failed to start")
```

### Export doesn't transform defined()

**Cause:** Using compile-time `when defined()` instead of runtime `defined()`.

**Fix:** Use runtime function:
```nim
# Wrong (compile-time, won't export)
when defined(emscripten):
  callGPU()

# Right (runtime, exports correctly)
if defined("web"):
  callGPU()
```

---

## Summary

TStorie's WebGPU strategy:

**Current (Phase 5):**
✅ GPU-accelerated noise (50-300× faster) via compute shaders  
✅ WebGL terminal rendering (works everywhere)  
✅ Canvas 2D fonts (browser fallback)  
✅ Runtime platform detection with `defined()`  
✅ Export support with compile-time transformation  
✅ Automatic CPU/WebGL fallback  

**Planned (Phase 6):**
🚧 Full WebGPU rendering pipeline  
🚧 Unified GPU context (compute + render)  
🚧 Remove WebGL dependency (smaller builds)  
✅ Keep Canvas 2D fonts (best solution)  
✅ Keep WebGL as legacy fallback  

**Platform Strategy:**
- **Web:** Full WebGPU optimized (~600KB, fast loading, browser-native features)
- **Native:** SDL3 unified (graphics, TTF fonts, cross-platform)
- **Audio:** WebAudio (web) + MiniAudio (native) - intentional split for best experience

The web and native platform split is **intentional and beneficial** - each optimized for its environment.

---

## Migration Roadmap

### Phase 5: Compute Shaders ✅ Complete

- [x] WebGPU compute pipeline integration
- [x] Async→Sync bridge for WASM
- [x] Runtime platform detection (`defined()`)
- [x] Export system support
- [x] Demo and documentation

**Status:** Production-ready, all builds working

### Phase 6: Full Rendering � In Progress

**Goal:** Replace WebGL with WebGPU for terminal rendering

**Tasks:**
- Phase 6 Complete (February 2026):**
✅ GPU-accelerated noise (50-300× faster) via compute shaders  
✅ WebGPU terminal rendering with automatic WebGL fallback  
✅ Canvas 2D fonts (browser fallback)  
✅ Runtime platform detection with `defined()`  
✅ Export support with compile-time transformation  
✅ Progressive enhancement (WebGPU → WebGL → CPU)  
✅ Unified GPU context (compute + render share device)  
✅ Universal compatibility (works on all browsers)

**Deployment:**
- **Main build** (`build-web.sh` → `index.html`): WebGPU with automatic fallback
- **Testing build** (`build-webgpu.sh` → `index-webgpu.html`): Same functionality
- **Native build** (`build.sh` → `tstorie`): SDL3 graphics

**Platform Strategy:**
- **Web:** Full WebGPU optimized (~620KB, fast loading, progressive enhancement)
- **Native:** SDL3 unified (graphics, TTF fonts, cross-platform)
- **Audio:** WebAudio (web) + MiniAudio (native) - intentional split for best experience

The web and native platform split is **intentional and beneficial** - each optimized for its environment. All platforms use the same **Nimini scripting layer** - scripts work everywhere!
- Smaller builds (~20KB saved)
- Better performance (shared context)
- Future-proof (WebGPU is successor to WebGL)

**Compatibility:**
- Keep WebGL fallback for older browsers
- Progressive enhancement pattern
- Same visual output
- No breaking changes to user code

### Phase 7: Advanced Features 📋 Future

**Potential additions once rendering unified:**
- Compute → Render direct pipeline (no CPU readback)
- Custom visual effects (post-processing)
- Particle systems on GPU
- Advanced rendering techniques
- 3D terminal effects (if desired)

### Timeline

- **Phase 5:** Complete ✅
- **Phase 6:** When WebGPU support reaches target threshold
- **Phase 7:** As needed for features

**Key metric:** WebGPU browser support % vs performance/size benefits

---

## Why This Approach?

### Web Platform Optimization

**Size Matters:**
- itch.io load times critical for discovery/conversion
- Every KB counts on mobile
- ~600KB is competitive, ~2.5MB is not

**Browser-Native Features Win:**
- Font fallback > shipping font files
- WebAudio > WASM audio libraries
- WebGPU > WebGL (future)

**Progressive Enhancement:**
- WebGPU (modern) → WebGL (fallback) → CPU
- Best experience on capable browsers
- Still works on older browsers

### Native Platform Optimization

**SDL3 Makes Sense:**
- Cross-platform graphics
- Native performance
- Unified desktop codebase
- Rich graphics features

**Different Constraints:**
- Size less critical (not downloaded)
- Native fonts available
- Hardware access direct

### Two Pipelines, Both Optimal

This isn't "technical debt" - it's **platform optimization**:

```
Web:    Optimized for delivery, browser features, size
Native: Optimized for capabilities, performance, richness
```

Both use the same **Nimini scripting layer** - scripts work everywhere!

---

## Related Files

- [docs/demos/webgpu.md](docs/demos/webgpu.md) - Interactive demo
- [lib/noise.nim](lib/noise.nim) - CPU noise implementation
- [src/runtime_api.nim](src/runtime_api.nim) - Runtime API functions
- [lib/nim_export.nim](lib/nim_export.nim) - Export transformation
- [web/webgpu_bridge.js](web/webgpu_bridge.js) - GPU API
- [web/webgpu_wasm_bridge.js](web/webgpu_wasm_bridge.js) - WASM bridge
- [web/webgpu_bridge_extern.js](web/webgpu_bridge_extern.js) - Emscripten declarations

---

**Last Updated:** January 30, 2026  
**Implementation Status:** Phase 5 Complete
February 2, 2026  
**Implementation Status:** Phase 6 Complete - Production Ready