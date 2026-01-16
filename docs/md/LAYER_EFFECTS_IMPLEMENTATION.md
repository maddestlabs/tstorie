# Layer Effects Implementation Guide

> **⚠️ ARCHITECTURAL UPDATE**: This document describes the original design where effects were baked into core Layer types. 
> 
> **See [LAYER_EFFECTS_PLUGIN_DESIGN.md](LAYER_EFFECTS_PLUGIN_DESIGN.md) for the revised architecture** that properly treats layer effects as a separate plugin without modifying core types.

## Original Design (Flawed)

This document describes the initial design which had an architectural issue: adding effect fields to the core Layer type would make them always present, violating the plugin architecture.

**The problem**: Core types initialize before plugins, so effects can't truly be optional if baked into Layer.

**The solution**: Make layer effects a separate plugin that augments layers via a registry pattern (see LAYER_EFFECTS_PLUGIN_DESIGN.md).

---

# Original Design (Superseded)



## Core Constraints

### 1. Terminal Limitations
- **No true transparency/opacity**: Terminal cells are either rendered or not
- **No alpha blending**: Can't blend colors smoothly
- **Character-based**: "Blurring" requires careful character/color selection
- **Unicode support varies**: Not all terminals support full Unicode

### 2. Plugin Architecture
- **Core**: Layers, basic compositing, buffer management
- **Plugins**: Advanced effects (shaders, particles, advanced color manipulation)
- **Conditional compilation**: `when not defined(emscripten)` for native-only features
- **Runtime checks**: `isPluginAvailable()` pattern for dynamic libraries

### 3. User Flexibility
- **Full build** (this repo): All plugins enabled
- **Minimal build**: Core only, no plugins
- **Selective builds**: User chooses which plugins to include

## Proposed Architecture

### Layer Type Extensions

```nim
# src/types.nim - Core layer definition

type
  LayerEffects* = object
    ## Built-in effects (always available, no plugins required)
    offsetX*, offsetY*: int              # Parallax/camera offset
    darkenFactor*: float                 # 0.0-1.0, multiply color brightness
    
    ## Plugin-dependent effects (gracefully ignored if unavailable)
    displacementEffect*: string          # Effect name: "wave", "noise", "ripple", ""
    displacementIntensity*: float        # Strength multiplier
    
  Layer* = ref object
    id*: string
    z*: int
    visible*: bool
    buffer*: TermBuffer
    effects*: LayerEffects              # Optional effects
```

### Effect Categories

#### Category 1: Always Available (Core)

These effects use only basic color math, no plugins required:

1. **Offset (Parallax)** - Simple coordinate translation
2. **Darkening/Brightness** - Multiply RGB values by factor
3. **Simple Desaturation** - Blend toward grayscale

**Rationale**: These are fundamental transformations that don't require special libraries.

```nim
# src/layers.nim - Core effect implementation

proc applyCoreForeEffect*(style: Style, factor: float): Style =
  ## Darken by multiplying foreground RGB values
  ## No plugins required
  result = style
  result.fg.r = uint8(clamp(float(style.fg.r) * factor, 0.0, 255.0))
  result.fg.g = uint8(clamp(float(style.fg.g) * factor, 0.0, 255.0))
  result.fg.b = uint8(clamp(float(style.fg.b) * factor, 0.0, 255.0))

proc applyDesaturation*(style: Style, amount: float): Style =
  ## Desaturate toward grayscale (0.0 = full color, 1.0 = grayscale)
  ## Uses standard luminance formula: Y = 0.299R + 0.587G + 0.114B
  result = style
  let gray = uint8(
    0.299 * float(style.fg.r) +
    0.587 * float(style.fg.g) +
    0.114 * float(style.fg.b)
  )
  result.fg.r = uint8(mix(float(style.fg.r), float(gray), amount))
  result.fg.g = uint8(mix(float(style.fg.g), float(gray), amount))
  result.fg.b = uint8(mix(float(style.fg.b), float(gray), amount))
```

#### Category 2: Plugin-Enhanced (Optional)

These leverage existing plugins if available:

1. **Displacement Effects** - Uses `lib/terminal_shaders.nim` 
2. **Advanced Color Effects** - Uses shader color palettes
3. **Procedural Patterns** - Noise, plasma, etc.

**Checking Plugin Availability**:

```nim
# Check if shader functionality is available
when declared(terminal_shaders):
  const hasShaderPlugin = true
else:
  const hasShaderPlugin = false
  
# Runtime check for dynamic plugins
proc hasDisplacementEffects*(): bool =
  when hasShaderPlugin:
    return true
  else:
    return false
```

### Modified Compositing Flow

```nim
# src/layers.nim - Enhanced compositeBufferOnto

proc compositeBufferOnto*(dest: var TermBuffer, src: TermBuffer, effects: LayerEffects) =
  ## Composite source buffer onto destination with effects applied
  let w = min(dest.width, src.width)
  let h = min(dest.height, src.height)
  
  for y in 0 ..< h:
    for x in 0 ..< w:
      # Calculate source position with offset (parallax)
      let srcX = x - effects.offsetX
      let srcY = y - effects.offsetY
      
      # Skip if out of bounds after offset
      if srcX < 0 or srcX >= src.width or srcY < 0 or srcY >= src.height:
        continue
      
      let srcIdx = srcY * src.width + srcX
      var cell = src.cells[srcIdx]
      
      # Skip transparent cells
      if cell.ch.len == 0 and cell.style.bg.r == 0 and 
         cell.style.bg.g == 0 and cell.style.bg.b == 0:
        continue
      
      # Apply displacement effect (if plugin available)
      var finalX = x
      var finalY = y
      when declared(applyDisplacementEffect):
        if effects.displacementEffect.len > 0:
          let (dx, dy) = applyDisplacementEffect(
            x, y, effects.displacementEffect, effects.displacementIntensity
          )
          finalX += dx
          finalY += dy
          
          # Clamp to bounds
          if finalX < 0 or finalX >= dest.width or finalY < 0 or finalY >= dest.height:
            continue
      
      # Apply core color effects (always available)
      if effects.darkenFactor < 1.0:
        cell.style = applyCoreForeEffect(cell.style, effects.darkenFactor)
      
      # Write to destination
      let destIdx = finalY * dest.width + finalX
      if destIdx >= 0 and destIdx < dest.cells.len:
        dest.cells[destIdx] = cell

proc compositeLayers*(state: AppState) =
  if state.layers.len == 0:
    return
  
  state.currentBuffer.clear(state.themeBackground)
  
  # Sort by z-index
  state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
  
  # Composite each visible layer with its effects
  for layer in state.layers:
    if layer.visible:
      compositeBufferOnto(state.currentBuffer, layer.buffer, layer.effects)
```

## User-Facing API

### Nimini Bindings

```nim
# src/runtime_api.nim - Layer effect functions

proc setLayerOffset(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## setLayerOffset(layerId: string|int, x: int, y: int)
  ## Set parallax offset for a layer (always available)
  if args.len < 3:
    return valNil()
  
  let layer = getLayerFromArg(args[0])  # Helper to get layer
  if layer.isNil:
    return valNil()
  
  layer.effects.offsetX = valueToInt(args[1])
  layer.effects.offsetY = valueToInt(args[2])
  return valNil()

proc setLayerDarkness(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## setLayerDarkness(layerId: string|int, factor: float)
  ## Darken layer: 0.0 = black, 1.0 = normal (always available)
  if args.len < 2:
    return valNil()
  
  let layer = getLayerFromArg(args[0])
  if layer.isNil:
    return valNil()
  
  layer.effects.darkenFactor = clamp(valueToFloat(args[1]), 0.0, 1.0)
  return valNil()

proc setLayerDisplacement(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## setLayerDisplacement(layerId: string|int, effect: string, intensity: float)
  ## Apply displacement effect (requires shader plugin)
  ## Gracefully ignored if plugin not available
  if args.len < 3:
    return valNil()
  
  let layer = getLayerFromArg(args[0])
  if layer.isNil:
    return valNil()
  
  when declared(hasShaderPlugin):
    if hasShaderPlugin:
      layer.effects.displacementEffect = args[1].s
      layer.effects.displacementIntensity = valueToFloat(args[2])
    else:
      # Silently ignore or log warning
      discard
  else:
    # Plugin not compiled in
    discard
  
  return valNil()

proc getLayerEffectsAvailable(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## getLayerEffectsAvailable() -> object with boolean flags
  ## Check what effects are available in current build
  result = valObject()
  result.objFields["offset"] = valBool(true)
  result.objFields["darkness"] = valBool(true)
  result.objFields["desaturation"] = valBool(true)
  
  when declared(hasShaderPlugin):
    result.objFields["displacement"] = valBool(hasShaderPlugin)
  else:
    result.objFields["displacement"] = valBool(false)
```

### Usage Examples

```nim
# Markdown document with layer effects

```​nim on:init
# Check what's available
let effects = getLayerEffectsAvailable()
if effects.displacement:
  echo "Shader effects enabled!"
else:
  echo "Running minimal build - basic effects only"
```​

```​nim on:update
# Always works - core features
setLayerOffset("background", -int(time * 20), 0)  # Parallax scroll
setLayerDarkness("background", 0.5)  # Darken distant layer

# Plugin-dependent (gracefully ignored if unavailable)
setLayerDisplacement("water", "wave", 0.3)  # Wavy effect if shader plugin loaded
```​
```

## Auto-Depth Cueing

A killer feature: automatically darken layers based on z-depth!

```nim
# src/layers.nim or separate module

proc applyAutoDepthing*(state: AppState, enable: bool = true, 
                        minBrightness: float = 0.3, maxBrightness: float = 1.0) =
  ## Automatically darken layers based on z-depth
  ## Layers further back (lower z) are darker
  ## This provides automatic atmospheric perspective
  
  if not enable or state.layers.len == 0:
    return
  
  # Find z-range
  var minZ = state.layers[0].z
  var maxZ = state.layers[0].z
  for layer in state.layers:
    minZ = min(minZ, layer.z)
    maxZ = max(maxZ, layer.z)
  
  let zRange = float(maxZ - minZ)
  if zRange < 0.01:  # All same z
    return
  
  # Apply brightness based on normalized z
  for layer in state.layers:
    let normalizedZ = float(layer.z - minZ) / zRange  # 0.0 to 1.0
    layer.effects.darkenFactor = mix(minBrightness, maxBrightness, normalizedZ)

# Nimini binding
proc enableAutoDepthing(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## enableAutoDepthing([minBrightness: float, maxBrightness: float])
  ## Auto-darken layers based on z-depth
  let minB = if args.len >= 1: valueToFloat(args[0]) else: 0.3
  let maxB = if args.len >= 2: valueToFloat(args[1]) else: 1.0
  
  gAppState.applyAutoDepthing(true, minB, maxB)
  return valNil()
```

Usage:

```nim
```​nim on:init
# Enable automatic depth cueing
# Back layers (low z) at 40% brightness, front at 100%
enableAutoDepthing(0.4, 1.0)
```​
```

## Shader Plugin Integration

For the shader plugin, we'd create a bridge module:

```nim
# lib/layer_shader_bridge.nim - Conditional shader integration

when not defined(emscripten):
  import terminal_shaders
  
  proc applyDisplacementEffect*(x, y: int, effectName: string, 
                                 intensity: float): tuple[dx, dy: int] =
    ## Apply displacement effect using shader functions
    ## Returns offset to apply to position
    case effectName
    of "wave":
      let offset = sin(float(x) * 0.1 + float(y) * 0.05) * intensity
      return (0, int(offset))
    of "ripple":
      let dist = sqrt(float(x * x + y * y))
      let offset = sin(dist * 0.1) * intensity
      return (int(offset), int(offset))
    of "noise":
      # Use noise function from terminal_shaders if available
      let n = perlinNoise(float(x) * 0.05, float(y) * 0.05) * intensity
      return (int(n), int(n))
    else:
      return (0, 0)
else:
  # WASM build - no shader plugin
  proc applyDisplacementEffect*(x, y: int, effectName: string,
                                 intensity: float): tuple[dx, dy: int] =
    return (0, 0)
```

## Build Configurations

### Full Build (This Repo)
```bash
nim c -d:release tstorie.nim
# Includes: terminal_shaders, audio plugins, compression plugins
```

### Minimal Build (User)
```bash
nim c -d:release -d:minimalBuild tstorie.nim
# Core only: layers, basic effects, no plugins
```

### Custom Build
```bash
nim c -d:release -d:noShaders -d:noAudio tstorie.nim
# Selective exclusion
```

## Benefits of This Design

1. **Graceful Degradation**: Code works regardless of plugin availability
2. **No Runtime Errors**: Missing plugins don't cause crashes
3. **Discoverable**: Users can query what's available
4. **Progressive Enhancement**: Advanced effects when available, basics always work
5. **Terminal-Aware**: Effects respect character-based constraints
6. **Performance**: Effects applied once during composite, not per-draw
7. **Intuitive API**: Simple function calls, clear naming

## Implementation Phases

### Phase 1: Core Effects (Immediate)
- [ ] Add `LayerEffects` type to `src/types.nim`
- [ ] Implement `applyCoreForeEffect` (darkening)
- [ ] Modify `compositeBufferOnto` to accept effects
- [ ] Update `compositeLayers` to use layer effects
- [ ] Add `setLayerOffset`, `setLayerDarkness` to runtime API

### Phase 2: Auto-Depthing (High Value)
- [ ] Implement `applyAutoDepthing` function
- [ ] Add `enableAutoDepthing` nimini binding
- [ ] Update documentation with examples

### Phase 3: Shader Integration (Plugin-Dependent)
- [ ] Create `lib/layer_shader_bridge.nim`
- [ ] Implement displacement effects using terminal_shaders
- [ ] Add `setLayerDisplacement` to runtime API
- [ ] Add plugin availability checks

### Phase 4: Polish
- [ ] Add `getLayerEffectsAvailable` introspection
- [ ] Create demo documents showcasing effects
- [ ] Performance optimization
- [ ] Documentation and tutorials

## Example: Parallax Scrolling Platformer

```markdown
---
title: "Parallax Demo"
theme: "dracula"
---

```​nim on:init
enableAutoDepthing(0.3, 1.0)  # Auto-darken by depth

var cameraX = 0.0

# Create depth layers
addLayer("sky", -3)      # Farthest back
addLayer("mountains", -2)
addLayer("trees", -1) 
addLayer("player", 0)    # Foreground
```​

```​nim on:update
cameraX += deltaTime * 50.0

# Parallax: farther layers move slower
setLayerOffset("sky", -int(cameraX * 0.1), 0)
setLayerOffset("mountains", -int(cameraX * 0.3), 0)
setLayerOffset("trees", -int(cameraX * 0.6), 0)
setLayerOffset("player", -int(cameraX), 0)

# Optional: wavy water effect (if shader plugin available)
setLayerDisplacement("water", "wave", 0.5)
```​

```​nim on:render
# Layers auto-composite with effects!
# Sky is darkest (z=-3), player is brightest (z=0)
# Parallax automatically applied during composite
```​
```

## Terminal Opacity Workaround

Since we can't do true opacity, here's a clever workaround:

```nim
proc applyFakeOpacity*(style: Style, opacity: float): Style =
  ## Simulate opacity by blending with black background
  ## Works for dark terminals - adjustable for light themes
  result = style
  let factor = clamp(opacity, 0.0, 1.0)
  
  # Blend foreground toward background color
  # For dark terminals, blend toward black
  # For light terminals, blend toward white
  result.fg.r = uint8(float(style.fg.r) * factor)
  result.fg.g = uint8(float(style.fg.g) * factor)
  result.fg.b = uint8(float(style.fg.b) * factor)
  
  # For backgrounds, similar approach
  result.bg.r = uint8(float(style.bg.r) * factor)
  result.bg.g = uint8(float(style.bg.g) * factor)
  result.bg.b = uint8(float(style.bg.b) * factor)
```

This creates a "fade to background" effect that looks like opacity in many cases.

## Conclusion

This design provides:
- **Practical effects** that work within terminal constraints
- **Plugin awareness** with graceful fallbacks
- **User flexibility** for minimal or maximal builds
- **Killer feature**: Auto-depth cueing for instant atmospheric perspective
- **Clean API** that's easy to use and understand

The key insight: **Layer effects are applied at composite time, not draw time**, which means:
- Effects work with any drawing method (canvas sections, direct draws)
- Performance is optimized (once per frame, not per draw call)
- Users get amazing visual depth with minimal code

Ready to implement! 🚀
