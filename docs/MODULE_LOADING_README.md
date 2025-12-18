# Module Loading - Quick Start

Runtime module loading for tstorie is now implemented! 🎉

## Usage

### In Your Story

```markdown
---
title: "My Interactive Story"
---

```nim global
# Load a module from a gist
canvas = require("gist:YOUR_GIST_ID/canvas.nim", state)
canvas.init()

# Or load locally during development
# canvas = require("examples/canvas.nim", state)
```

# first_section

```nim on:render
canvas.drawBox(10, 5, 40, 15, "Welcome!")
```

Your story continues...
```

## Publishing Modules

1. Create your module file (e.g., `mymodule.nim`)
2. Upload to a GitHub gist
3. Get the gist ID from the URL
4. Share: `require("gist:GIST_ID/filename.nim", state)`

## Files Created

- `lib/module_loader.nim` - Core loading system
- `lib/nimini_bridge.nim` - API bridge to tstorie
- `web/module_loader.js` - JavaScript helper for WASM
- `examples/canvas.nim` - Example module
- `docs/MODULE_LOADING.md` - User documentation
- `docs/MODULE_LOADING_IMPLEMENTATION.md` - Implementation details

## Testing

Native build:
```bash
nim c -r tstorie.nim
# Story with require() will load modules
```

Web build:
```bash
./build-web.sh
# Open web/module_example.html
```

## Next Steps

1. Test with a simple module
2. Publish your first module as a gist
3. Share modules with the community!

See `docs/MODULE_LOADING.md` for full documentation.
