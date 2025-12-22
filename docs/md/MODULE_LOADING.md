# Module Loading System

tstorie now supports runtime loading of Nim modules from GitHub gists or local files, allowing you to easily share and reuse functionality across stories.

## Quick Start

### In Your Markdown Story

```markdown
---
title: "My Story"
---

```nim global
# Load a module from a GitHub gist
canvas = require("gist:abc123def456/canvas.nim", state)

# Or load a local module
utils = require("examples/canvas.nim", state)

# Use the module's functions
canvas.init()
canvas.drawBox(10, 5, 40, 10, "Welcome")
```

# first_section

Your story content...
```

## Module Reference Formats

### GitHub Gist
```nim
canvas = require("gist:GIST_ID/filename.nim", state)
```

Example:
```nim
canvas = require("gist:abc123def456/canvas.nim", state)
```

### Local File
```nim
utils = require("path/to/file.nim", state)
```

Example:
```nim
utils = require("examples/canvas.nim", state)
```

## Creating Loadable Modules

Modules are regular Nim files that have access to tstorie APIs when loaded.

### Example Module (`mymodule.nim`)

```nim
## My Custom Module
## Can be loaded via require()

type
  ModuleState = ref object
    initialized: bool

var state = ModuleState(initialized: false)

proc init*() =
  ## Initialize the module
  echo "Module initialized!"
  state.initialized = true
  createLayer("my_layer", 5)

proc drawTitle*(text: string, x: int, y: int) =
  ## Draw a fancy title
  let style = {
    "fg": rgb(255, 255, 0),
    "bold": true
  }
  write(x, y, text, style)

proc cleanup*() =
  ## Clean up module resources
  removeLayer("my_layer")
  state.initialized = false
```

### Using Your Module

```nim
# Load it
mymod = require("gist:xyz789/mymodule.nim", state)

# Call its functions
mymod.init()
mymod.drawTitle("Hello World", 10, 5)
```

## Available APIs in Modules

When your module is loaded, it has access to these tstorie functions:

### Drawing
- `write(x, y, text, style)` - Write text at position
- `writeText(x, y, text, style)` - Write multi-line text
- `fillRect(x, y, w, h, char, style)` - Fill rectangle with character

### Layer Management
- `createLayer(id, z)` - Create a new layer
- `getLayer(id)` - Get layer info
- `removeLayer(id)` - Remove a layer

### Colors
- `rgb(r, g, b)` - Create RGB color (0-255 each)
- `black()`, `white()`, `red()`, `green()`, `blue()` - Preset colors

### Input
- `getInput()` - Get array of input events

### State
- `getWidth()` - Get terminal/canvas width
- `getHeight()` - Get terminal/canvas height
- `getDeltaTime()` - Get frame delta time

### Utilities
- `echo(...)` - Print to console
- `len(array_or_string)` - Get length

## Sharing Modules via Gists

1. Create your `.nim` module file
2. Create a GitHub gist with your file
3. Get the gist ID from the URL: `https://gist.github.com/username/GIST_ID`
4. Share the require line: `require("gist:GIST_ID/filename.nim", state)`

## WASM/Web Usage

For web builds, include the module loader script:

```html
<script src="module_loader.js"></script>
<script>
  // Preload modules before starting
  async function startStory() {
    await tstorieModuleLoader.preloadModules([
      'gist:abc123/canvas.nim',
      'gist:def456/utils.nim'
    ]);
    
    // Now start tstorie
    Module.onRuntimeInitialized = function() {
      Module._emInit(80, 24);
    };
  }
  
  startStory();
</script>
```

## Examples

### Canvas Drawing Module

See `examples/canvas.nim` for a complete example that provides:
- Box drawing with borders
- Section management
- Styled text rendering

### Usage in a Story

```markdown
---
title: "Interactive Map"
---

```nim global
canvas = require("gist:abc123/canvas.nim", state)
canvas.init()
```

# map_screen

```nim on:render
canvas.clear()
canvas.drawBox(0, 0, 60, 20, "World Map")
canvas.renderSection("Location", 2, 2, """
You are in a mysterious forest.
Paths lead north and east.
""")
```

[Go North](north_path)
[Go East](east_path)
```

## Troubleshooting

### Module Not Found
- Check the gist ID is correct
- Verify the filename matches exactly (case-sensitive)
- For local files, ensure the path is relative to the story file

### Compilation Errors
- Modules must be valid Nim syntax
- Only use APIs listed above (nimini subset)
- Check for syntax errors in your module

### WASM Async Loading
- In web builds, gists are fetched asynchronously
- Use `preloadModules()` to load before initialization
- Check browser console for fetch errors

## Best Practices

1. **Keep modules focused** - One module should do one thing well
2. **Initialize explicitly** - Use an `init()` function users must call
3. **Clean up resources** - Provide cleanup functions for layers/state
4. **Document exports** - Comment which functions are public API
5. **Handle errors gracefully** - Don't crash on invalid input
6. **Version your gists** - Use gist revisions for updates

## Performance Notes

- Modules are cached after first load
- Multiple require() calls for same module return cached version
- Native builds can read local files directly
- WASM builds fetch gists via JavaScript async fetch
