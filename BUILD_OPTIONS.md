# TStorie Build Options

## Overview

TStorie provides two build configurations to balance features and size:

1. **Default Build** (Recommended) - Includes TTF support
2. **Minimal Build** - SDL3 debug text only

## Default Build: `build-modular.sh`

**Size:** ~2-2.5MB (WASM)
**Use when:** You want full text rendering features out of the box

### Features:
- ✓ SDL3 rendering backend
- ✓ TTF font support with anti-aliasing
- ✓ Unicode text rendering
- ✓ Variable font support
- ✓ Plugin architecture ready for future extensions (audio, etc.)

### Build Command:
```bash
./build-modular.sh
```

### Output:
- `docs/tstorie.js`
- `docs/tstorie.wasm`

---

## Minimal Build: `build-web-sdl3-minimal.sh`

**Size:** ~800KB (WASM)
**Use when:** You need smallest possible bundle or prefer bitmap fonts

### Features:
- ✓ SDL3 rendering backend
- ✓ SDL3 debug text rendering (ASCII only)
- ✓ Plugin architecture ready for extensions
- ✗ No TTF support (saves ~1.5MB)
- ✗ No anti-aliasing
- ✗ Limited Unicode support

### Build Command:
```bash
./build-web-sdl3-minimal.sh
```

### Output:
- `docs/tstorie-minimal.js`
- `docs/tstorie-minimal.wasm`

---

## Plugin Architecture

Both builds maintain the runtime function pointer architecture that enables:

- **Future plugin support** for audio, physics, advanced rendering
- **Runtime feature detection** - plugins can be loaded on demand
- **Graceful degradation** - core works without plugins

### Currently Ready For:
- TTF rendering plugin (can be dynamically loaded in minimal build)
- Audio plugin system
- Custom shader plugins
- Any future extension that benefits from optional loading

### Implementation:
The codebase uses runtime dispatch with function pointers:
```nim
# Example: TTF rendering
if not gTTFRenderFunc.isNil and not gTTFFontHandle.isNil:
  # Use TTF rendering
  gTTFRenderFunc(...)
else:
  # Fallback to debug text
  SDL_RenderDebugText(...)
```

This pattern allows plugins to be:
1. Compiled into the main binary (default build)
2. Loaded dynamically at runtime (future capability)
3. Gracefully absent with automatic fallbacks

---

## Choosing Your Build

### Use Default Build If:
- Building for general web deployment
- 95% of your content uses text extensively
- Want the simplest single-file distribution
- Size under 3MB is acceptable

### Use Minimal Build If:
- Building for size-constrained environments
- Using bitmap fonts exclusively
- Text rendering is minimal or absent
- Every KB matters for your use case

---

## Future: True Dynamic Plugin Loading

When SDL3_ttf becomes available in Emscripten ports (with -fPIC compilation), we can enable true SIDE_MODULE loading:

```bash
# Core (MAIN_MODULE)
nim c -d:coreOnly --passL:"-sMAIN_MODULE=2" -o:tstorie-core.js tstorie.nim

# TTF Plugin (SIDE_MODULE)
nim c --passL:"-sSIDE_MODULE=2" -o:plugins/ttf.wasm ttf_plugin.nim

# Load plugin at runtime via JavaScript
Module.loadDynamicLibrary('plugins/ttf.wasm')
```

This will enable:
- Initial load at ~800KB
- Progressive enhancement with plugins
- User choice of which features to load
- True incremental loading strategy

The architecture is already in place - we're just waiting for the vendor libraries.

---

## Technical Notes

### Why TTF Adds Size
The TTF rendering stack includes:
- SDL3_ttf library (~200KB)
- FreeType font renderer (~800KB)
- HarfBuzz text shaping (~400KB)
- Font file (KodeMono ~150KB)

**Total:** ~1.5MB additional

### Why Keep Plugin Architecture
Even with TTF included by default:
1. **Future audio plugins** will benefit from dynamic loading
2. **Custom shader plugins** for advanced effects
3. **Physics engines** for interactive demos
4. **Minimal build option** proves architecture works
5. **Migration path** when SDL3_ttf ports become available

### Build Performance
- Default build: ~2-3 minutes
- Minimal build: ~1-2 minutes
- Both use aggressive optimization: `-Os`, `-flto`, `--opt:size`
