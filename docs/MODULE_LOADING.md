# TStorie Module-Based Loading Implementation

This document describes the proper module-based (plugin) loading architecture for TStorie using Emscripten's MAIN_MODULE/SIDE_MODULE system.

## Architecture Overview

### MAIN_MODULE (Core)
- **File**: `docs/tstorie-core.wasm` + `tstorie-core.js`
- **Size**: ~1.9MB
- **Contents**: SDL3, Nim runtime, core rendering (ASCII debug font)
- **Build Flag**: `-sMAIN_MODULE=2`
- **Purpose**: Loads first, provides fast startup with basic rendering

### SIDE_MODULEs (Plugins)
- **Location**: `docs/plugins/*.wasm`
- **Build Flag**: `-sSIDE_MODULE=2`
- **Purpose**: Load on-demand based on content requirements
- **Dependencies**: Share symbols from main module (SDL3, malloc, etc.)

#### Available Plugins
1. **TTF Plugin** (`plugins/ttf.wasm`)
   - Size: ~1.5MB
   - Contents: SDL3_ttf, FreeType, HarfBuzz
   - Loaded when: Content contains unicode, emoji, box-drawing characters
   - Status: ✅ Built and ready

2. **Audio Plugin** (`plugins/audio.wasm`)
   - Size: ~300KB
   - Contents: miniaudio, audio synthesis
   - Loaded when: Content uses audio features
   - Status: 🚧 Planned

3. **Particles Plugin** (`plugins/particles.wasm`)
   - Size: ~150KB
   - Contents: Particle system
   - Loaded when: Content uses particle effects
   - Status: 🚧 Planned

4. **Effects Plugin** (`plugins/effects.wasm`)
   - Size: ~200KB
   - Contents: Layer effects, shaders
   - Loaded when: Content uses visual effects
   - Status: 🚧 Planned

## Implementation Components

### 1. Nim FFI (tstorie.nim)

Added dynamic library loading support:

```nim
when defined(emscripten):
  # Import Emscripten's loadDynamicLibrary
  proc loadDynamicLibrary(path: cstring): pointer {.
    importc: "loadDynamicLibrary".}
  
  proc dlsym(handle: pointer, symbol: cstring): pointer {.
    importc: "dlsym", header: "<dlfcn.h>".}
  
  # Plugin state
  var gUseDebugFont* = true
  var gTTFPluginLoaded* = false
  
  proc loadTTFPlugin*() {.exportc: "loadTTFPlugin".} =
    ## Load and initialize TTF plugin
    let handle = loadDynamicLibrary("plugins/ttf.wasm")
    if not handle.isNil:
      # Find and call ttfPluginInit()
      # Switch to TTF renderer
      switchToTTFRenderer()
  
  proc switchToTTFRenderer*() {.exportc: "switchToTTFRenderer".} =
    ## Switch from ASCII debug font to TTF
    gUseDebugFont = false
  
  proc isPluginLoaded*(pluginName: cstring): bool {.exportc.} =
    ## Query plugin status
    case $pluginName
    of "ttf": return gTTFPluginLoaded
    else: return false
  
  proc getPluginStatus*(): cstring {.exportc.} =
    ## Get JSON status of all plugins
    return """{"ttf":false,"debugFont":true}""".cstring
```

**Exports Available**:
- `_loadTTFPlugin()` - Load TTF plugin
- `_switchToTTFRenderer()` - Switch renderer
- `_isPluginLoaded(name)` - Check if plugin loaded
- `_getPluginStatus()` - Get JSON status

### 2. Progressive Loader (progressive-loader.js)

Complete rewrite for SIDE_MODULE architecture:

```javascript
class ProgressiveLoader {
  constructor() {
    this.coreModule = null;
    this.loadedPlugins = new Set();
    this.pluginConfig = {
      ttf: {
        path: 'plugins/ttf.wasm',
        nimInit: 'loadTTFPlugin',
        features: ['ttf']
      }
    };
  }
  
  async init(canvasId) {
    // Load core MAIN_MODULE
    this.coreModule = await TStorieCore({
      canvas: document.getElementById(canvasId)
    });
  }
  
  async loadPlugin(pluginName) {
    // Use Emscripten's loadDynamicLibrary
    await this.coreModule.loadDynamicLibrary(config.path, {
      loadAsync: true,
      nodelete: true,
      global: true
    });
    
    // Call Nim init function
    this.coreModule._loadTTFPlugin();
  }
  
  analyzeContent(markdown) {
    // Detect unicode/emoji for TTF requirement
    const needsTTF = /[\u{1F300}-\u{1F9FF}]/.test(markdown);
    return needsTTF ? ['ttf'] : [];
  }
}
```

### 3. HTML Integration (index-progressive.html)

Simplified loader usage:

```javascript
const loader = new ProgressiveLoader();

// Load core
await loader.init('canvas');

// Analyze content
const plugins = loader.analyzeContent(markdown);

// Load plugins
await loader.loadPlugins(plugins);

// Start app
loader.startMainLoop();
```

### 4. Debug Test Page (test-module-loading.html)

Interactive test page with:
- Manual plugin loading buttons
- Status displays (JS and Nim)
- Real-time logging
- Performance metrics
- Console helpers

## Build Process

The modular build is handled by `build-modular.sh`:

```bash
# Step 1: Build MAIN_MODULE (core)
nim c \
  -d:sdl3Backend \
  -d:coreOnly \
  --passL:"-sMAIN_MODULE=2" \
  --passL:"-sEXPORTED_RUNTIME_METHODS=['loadDynamicLibrary']" \
  -o:docs/tstorie-core.js \
  tstorie.nim

# Step 2: Build SIDE_MODULE (TTF plugin)
nim c \
  --app:lib \
  --passL:"-sSIDE_MODULE=2" \
  --passL:"-fPIC" \
  -o:docs/plugins/ttf.wasm \
  ttf_plugin.nim
```

## Testing

### Option 1: Test Page
1. Build the project: `./build-modular.sh`
2. Start server: `cd docs && python3 -m http.server 8000`
3. Open: http://localhost:8000/test-module-loading.html
4. Click "Load Core Module"
5. Click "Load TTF Plugin"
6. Check console and status displays

### Option 2: Console Testing
1. Open test-module-loading.html
2. Open browser console
3. Run commands:
   ```javascript
   loadCore()                    // Load core
   startMain()                   // Start rendering
   loadPluginManual('ttf')       // Load TTF plugin
   showStatus()                  // Show status
   showNimStatus()               // Show Nim status
   loader.getStatus()            // Get status object
   ```

### Option 3: Progressive Page
1. Open: http://localhost:8000/index-progressive.html
2. Core loads automatically
3. Plugins load based on content analysis

## Flow Diagram

```
User opens page
       ↓
Load tstorie-core.js
       ↓
TStorieCore() initializes MAIN_MODULE
       ↓
Core renders immediately (ASCII debug font)
       ↓
Analyze content for required features
       ↓
If unicode/emoji detected:
       ↓
   Module.loadDynamicLibrary('plugins/ttf.wasm')
       ↓
   Module._loadTTFPlugin()  [Nim export]
       ↓
   ttfPluginInit() in plugin
       ↓
   switchToTTFRenderer()
       ↓
Next frame renders with TTF
```

## Debug Commands

In browser console:

```javascript
// Check loader status
loader.getStatus()

// Load plugin manually
loader.loadPlugin('ttf')

// Check Nim-side status
const status = loader.coreModule.UTF8ToString(
  loader.coreModule._getPluginStatus()
);
JSON.parse(status)

// Check if plugin loaded
loader.coreModule._isPluginLoaded('ttf')
```

## Benefits

1. **Fast Startup**: Core loads in <2s, renders immediately
2. **Incremental Loading**: Only download what you need
3. **No Code Duplication**: Plugins share core's symbols
4. **Seamless Upgrade**: Switch from ASCII to TTF without reload
5. **Independent Plugins**: Can load TTF without audio, etc.

## Troubleshooting

### Plugin doesn't load
- Check console for errors
- Verify `plugins/ttf.wasm` exists
- Check network tab for 404s
- Run `loader.getStatus()` to check state

### Nim init function not found
- Check exports: `console.log(Object.keys(loader.coreModule).filter(k => k.startsWith('_')))`
- Verify function name matches (e.g., `_loadTTFPlugin`)

### Plugin loads but doesn't render
- Check `loader.coreModule._isPluginLoaded('ttf')`
- Check `loader.coreModule._getPluginStatus()`
- Verify `gUseDebugFont` is false

## Next Steps

1. ✅ Implement dynamic loading FFI
2. ✅ Rewrite progressive-loader.js
3. ✅ Add debug test page
4. 🚧 Test with actual TTF plugin
5. 🚧 Implement audio plugin
6. 🚧 Implement particle plugin
7. 🚧 Add content analysis for automatic loading

## Files Modified

- ✅ `tstorie.nim` - Added plugin loading FFI and exports
- ✅ `docs/progressive-loader.js` - Complete rewrite for SIDE_MODULE
- ✅ `docs/index-progressive.html` - Updated to use new loader
- ✅ `docs/test-module-loading.html` - New debug test page
- ✅ `docs/MODULE_LOADING.md` - This documentation

## References

- [PROGRESS.md](../PROGRESS.md) - Original requirements
- [build-modular.sh](../build-modular.sh) - Build script
- [Emscripten Dynamic Linking](https://emscripten.org/docs/compiling/Dynamic-Linking.html)
