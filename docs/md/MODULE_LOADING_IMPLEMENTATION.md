# Runtime Module Loading Implementation

This implementation adds support for loading Nim modules at runtime from GitHub gists or local files, similar to the Lua `require()` functionality in the previous version.

## Implementation Overview

### Components

1. **lib/module_loader.nim** - Core module loading system
   - Fetches modules from gists or local files
   - Caches compiled modules
   - Handles both native and WASM builds

2. **lib/nimini_bridge.nim** - API bridge
   - Exposes tstorie APIs to interpreted modules
   - Provides drawing, input, layer management functions
   - Enables safe sandboxed execution

3. **tstorie.nim** - Integration
   - Added `require()` function
   - Global nimini runtime environment
   - WASM exports for gist loading

4. **web/module_loader.js** - JavaScript helper
   - Handles async gist fetching in WASM builds
   - Module caching on JS side
   - Error handling and logging

5. **examples/canvas.nim** - Example module
   - Demonstrates module structure
   - Shows API usage
   - Ready to publish as gist

## How It Works

### Native Builds

```
User Story (depths.md)
    ↓
require("gist:ID/file.nim", state)
    ↓
module_loader.fetchGistFile() → HTTP GET
    ↓
nimini.compileSource() → AST
    ↓
nimini.execProgram() → Execute with tstorie APIs
    ↓
Return RuntimeEnv with exports
```

### WASM Builds

```
User Story (depths.md)
    ↓
require("gist:ID/file.nim", state) → emRequireModule()
    ↓
Returns "fetch_needed"
    ↓
JavaScript: fetchGistFile() → fetch()
    ↓
JavaScript: emLoadGistCode(ref, code)
    ↓
Nim: loadGistCode() → cache source
    ↓
JavaScript: emRequireModule() again
    ↓
nimini.compileSource() → AST
    ↓
nimini.execProgram() → Execute with tstorie APIs
    ↓
Returns "loaded"
```

## Usage

### In a Story

```nim
# Global block
canvas = require("gist:abc123/canvas.nim", state)
canvas.init()

# Later in sections
canvas.drawBox(10, 5, 40, 15, "Title")
```

### Creating a Module

```nim
## My Module
## Loadable via require()

proc init*() =
  echo "Module initialized"
  createLayer("my_layer", 5)

proc draw*(x: int, y: int) =
  write(x, y, "Hello", {"fg": rgb(255, 255, 0)})
```

### Publishing

1. Create your `.nim` file
2. Upload to GitHub gist
3. Share: `require("gist:GIST_ID/file.nim", state)`

## Testing

### Test Native Build

```bash
# Create a test story that uses module loading
cat > test_module.md << 'EOF'
---
title: "Module Test"
---

```nim global
canvas = require("examples/canvas.nim", state)
canvas.init()
```

# test

```nim on:render
canvas.drawBox(5, 2, 50, 10, "Test Box")
```
EOF

# Compile and run
nim c -r -d:userFile=test_module tstorie.nim
```

### Test WASM Build

```bash
# Build WASM
./build-web.sh

# Open web/module_example.html in browser
# Check console for module loading logs
```

## Available APIs in Modules

Modules have access to all functions registered in `lib/nimini_bridge.nim`:

**Drawing:**
- `write(x, y, text, style)`
- `writeText(x, y, text, style)`
- `fillRect(x, y, w, h, char, style)`

**Layers:**
- `createLayer(id, z)`
- `getLayer(id)`
- `removeLayer(id)`

**Colors:**
- `rgb(r, g, b)`
- `black()`, `white()`, `red()`, `green()`, `blue()`

**Input:**
- `getInput()` → array of events

**State:**
- `termWidth`, `termHeight`, `mouseX`, `mouseY` (globals), `getDeltaTime()`

**Utilities:**
- `echo(...)`
- `len(arr_or_str)`

## Security Considerations

1. **Sandboxed Execution** - Modules run in nimini interpreter, not native code
2. **Limited API** - Only exposed functions are available
3. **No File I/O** - Modules can't directly access filesystem (except via provided APIs)
4. **CORS Required** - Gists must be accessible (GitHub provides CORS headers)

## Performance Notes

- **First load:** HTTP fetch + compilation (~100-500ms depending on module size)
- **Cached loads:** Instant (already compiled)
- **Module size:** Keep modules small (<10KB source for best performance)
- **Gist fetch:** Limited by network speed in WASM builds

## Future Improvements

1. **Module Registry** - Central list of verified modules
2. **Version Pinning** - Support gist revision hashes
3. **Dependency Resolution** - Modules that require other modules
4. **Hot Reload** - Reload modules without restarting story
5. **NPM-style packages** - `require("@user/module")`
6. **Local Development Mode** - File watching and auto-reload

## Troubleshooting

### "Module not yet loaded" Error
**Cause:** Async gist fetch not complete
**Fix:** Use `preloadModules()` in JavaScript before initialization

### Compilation Errors
**Cause:** Invalid Nim syntax or unsupported features
**Fix:** Check module uses only nimini-compatible syntax

### CORS Errors
**Cause:** Gist fetch blocked by browser
**Fix:** Ensure gists are public; check browser console

### Module Not Found (Local)
**Cause:** File path incorrect
**Fix:** Use paths relative to story file

## Examples

See:
- `examples/canvas.nim` - Drawing utilities module
- `depths.md` - Story using module loading
- `web/module_example.html` - Web integration
- `docs/MODULE_LOADING.md` - User documentation
