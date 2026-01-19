# Layer Effects as a Plugin - Revised Architecture

## Core Problem

**Original Design Flaw:**
- Added `effects: LayerEffects` field to core `Layer` type
- This makes effects **always present**, not truly optional
- Violates plugin architecture (core depends on plugin concepts)
- Can't be disabled in minimal builds

**Solution:**
Make layer effects a **separate plugin** that augments layers without modifying the core type.

## Revised Architecture

### Core Layers (Always Present)

```nim
# src/types.nim - Unchanged, stays simple
Layer* = ref object
  id*: string
  z*: int
  visible*: bool
  buffer*: TermBuffer
  # NO effects field!
```

Core compositing stays clean:
```nim
# src/layers.nim
proc compositeLayers*(state: AppState) =
  # Sort by z
  state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
  
  # Simple composite
  for layer in state.layers:
    if layer.visible:
      compositeBufferOnto(state.currentBuffer, layer.buffer)
```

### Layer Effects Plugin (Optional)

```nim
# lib/layer_effects.nim - New plugin module

import ../src/types
import ../src/layers
import std/tables

type
  LayerEffects* = object
    ## Effects applied to a layer during compositing
    offsetX*, offsetY*: int           # Parallax/camera offset
    darkenFactor*: float              # Brightness multiplier (0.0-1.0)
    desaturation*: float              # Grayscale blend (0.0-1.0)
    
    # Plugin-dependent (only if terminal_shaders available)
    displacementEffect*: string       # "wave", "ripple", "noise", ""
    displacementIntensity*: float     # Displacement strength

  LayerEffectsRegistry* = ref object
    ## Global registry mapping layer IDs to their effects
    effects*: Table[string, LayerEffects]
    autoDepthing*: bool
    depthMin*, depthMax*: float

# Global registry (only exists if plugin loaded)
var gEffectsRegistry*: LayerEffectsRegistry = nil

# ================================================================
# PLUGIN INITIALIZATION
# ================================================================

proc initLayerEffectsPlugin*() =
  ## Initialize the layer effects plugin
  ## Call this during plugin registration
  if gEffectsRegistry.isNil:
    gEffectsRegistry = LayerEffectsRegistry(
      effects: initTable[string, LayerEffects](),
      autoDepthing: false,
      depthMin: 0.3,
      depthMax: 1.0
    )

proc isLayerEffectsAvailable*(): bool =
  ## Check if layer effects plugin is loaded
  return not gEffectsRegistry.isNil

# ================================================================
# EFFECT MANAGEMENT
# ================================================================

proc getOrCreateEffects(layerId: string): var LayerEffects =
  ## Get effects for a layer, creating if needed
  if layerId notin gEffectsRegistry.effects:
    gEffectsRegistry.effects[layerId] = LayerEffects(
      offsetX: 0,
      offsetY: 0,
      darkenFactor: 1.0,
      desaturation: 0.0,
      displacementEffect: "",
      displacementIntensity: 0.0
    )
  return gEffectsRegistry.effects[layerId]

proc getEffects*(layerId: string): ptr LayerEffects =
  ## Get effects for a layer (returns nil if no effects set)
  if layerId in gEffectsRegistry.effects:
    return addr gEffectsRegistry.effects[layerId]
  return nil

proc clearEffects*(layerId: string) =
  ## Remove all effects from a layer
  gEffectsRegistry.effects.del(layerId)

# ================================================================
# CORE EFFECT FUNCTIONS (Always Available)
# ================================================================

proc setLayerOffset*(layerId: string, x, y: int) =
  ## Set parallax offset for a layer
  var effects = getOrCreateEffects(layerId)
  effects.offsetX = x
  effects.offsetY = y

proc setLayerDarkness*(layerId: string, factor: float) =
  ## Set brightness multiplier (0.0 = black, 1.0 = normal)
  var effects = getOrCreateEffects(layerId)
  effects.darkenFactor = clamp(factor, 0.0, 1.0)

proc setLayerDesaturation*(layerId: string, amount: float) =
  ## Set desaturation amount (0.0 = full color, 1.0 = grayscale)
  var effects = getOrCreateEffects(layerId)
  effects.desaturation = clamp(amount, 0.0, 1.0)

# ================================================================
# AUTO-DEPTHING (Killer Feature)
# ================================================================

proc enableAutoDepthing*(minBrightness: float = 0.3, maxBrightness: float = 1.0) =
  ## Automatically darken layers based on z-depth
  ## Lower z (background) = darker, Higher z (foreground) = brighter
  gEffectsRegistry.autoDepthing = true
  gEffectsRegistry.depthMin = clamp(minBrightness, 0.0, 1.0)
  gEffectsRegistry.depthMax = clamp(maxBrightness, 0.0, 1.0)

proc disableAutoDepthing*() =
  gEffectsRegistry.autoDepthing = false

proc applyAutoDepthing*(state: AppState) =
  ## Apply auto-depthing to all layers
  if not gEffectsRegistry.autoDepthing or state.layers.len == 0:
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
    let brightness = mix(gEffectsRegistry.depthMin, gEffectsRegistry.depthMax, normalizedZ)
    setLayerDarkness(layer.id, brightness)

# ================================================================
# PLUGIN-ENHANCED EFFECTS (Conditional)
# ================================================================

when not defined(emscripten):
  # Try to import shader support
  when compiles(import terminal_shaders):
    import terminal_shaders
    const hasShaderSupport = true
  else:
    const hasShaderSupport = false
else:
  const hasShaderSupport = false

proc setLayerDisplacement*(layerId: string, effect: string, intensity: float) =
  ## Set displacement effect (requires shader plugin)
  ## Gracefully ignored if shaders unavailable
  when hasShaderSupport:
    var effects = getOrCreateEffects(layerId)
    effects.displacementEffect = effect
    effects.displacementIntensity = intensity
  else:
    discard  # Silently ignore

# ================================================================
# CORE EFFECT APPLICATION
# ================================================================

proc applyColorEffects(style: Style, effects: LayerEffects): Style =
  ## Apply color-based effects to a style
  result = style
  
  # Apply darkening
  if effects.darkenFactor < 1.0:
    result.fg.r = uint8(clamp(float(style.fg.r) * effects.darkenFactor, 0.0, 255.0))
    result.fg.g = uint8(clamp(float(style.fg.g) * effects.darkenFactor, 0.0, 255.0))
    result.fg.b = uint8(clamp(float(style.fg.b) * effects.darkenFactor, 0.0, 255.0))
  
  # Apply desaturation
  if effects.desaturation > 0.0:
    let gray = uint8(
      0.299 * float(result.fg.r) +
      0.587 * float(result.fg.g) +
      0.114 * float(result.fg.b)
    )
    result.fg.r = uint8(mix(float(result.fg.r), float(gray), effects.desaturation))
    result.fg.g = uint8(mix(float(result.fg.g), float(gray), effects.desaturation))
    result.fg.b = uint8(mix(float(result.fg.b), float(gray), effects.desaturation))

proc applyDisplacement(x, y: int, effects: LayerEffects): tuple[dx, dy: int] =
  ## Calculate displacement offset
  when hasShaderSupport:
    if effects.displacementEffect.len > 0:
      case effects.displacementEffect
      of "wave":
        let offset = sin(float(x) * 0.1 + float(y) * 0.05) * effects.displacementIntensity
        return (0, int(offset))
      of "ripple":
        let dist = sqrt(float(x * x + y * y))
        let offset = sin(dist * 0.1) * effects.displacementIntensity
        return (int(offset), int(offset))
      else:
        return (0, 0)
  
  return (0, 0)

# ================================================================
# ENHANCED COMPOSITING (Replaces Core)
# ================================================================

proc compositeLayersWithEffects*(state: AppState) =
  ## Enhanced layer compositing that applies effects
  ## This REPLACES the core compositeLayers when plugin loaded
  if state.layers.len == 0:
    return
  
  # Apply auto-depthing if enabled
  if gEffectsRegistry.autoDepthing:
    applyAutoDepthing(state)
  
  # Clear destination
  state.currentBuffer.clear(state.themeBackground)
  
  # Sort layers by z-index
  state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
  
  # Composite each layer with effects
  for layer in state.layers:
    if not layer.visible:
      continue
    
    # Get effects for this layer (if any)
    let effectsPtr = getEffects(layer.id)
    
    if effectsPtr.isNil:
      # No effects - use standard composite
      compositeBufferOnto(state.currentBuffer, layer.buffer)
    else:
      # Apply effects during composite
      let effects = effectsPtr[]
      let w = min(state.currentBuffer.width, layer.buffer.width)
      let h = min(state.currentBuffer.height, layer.buffer.height)
      
      for y in 0 ..< h:
        for x in 0 ..< w:
          # Calculate source position with offset
          let srcX = x - effects.offsetX
          let srcY = y - effects.offsetY
          
          if srcX < 0 or srcX >= layer.buffer.width or srcY < 0 or srcY >= layer.buffer.height:
            continue
          
          let srcIdx = srcY * layer.buffer.width + srcX
          var cell = layer.buffer.cells[srcIdx]
          
          # Skip transparent
          if cell.ch.len == 0 and cell.style.bg.r == 0 and 
             cell.style.bg.g == 0 and cell.style.bg.b == 0:
            continue
          
          # Apply displacement
          var finalX = x
          var finalY = y
          let (dx, dy) = applyDisplacement(x, y, effects)
          finalX += dx
          finalY += dy
          
          if finalX < 0 or finalX >= state.currentBuffer.width or 
             finalY < 0 or finalY >= state.currentBuffer.height:
            continue
          
          # Apply color effects
          cell.style = applyColorEffects(cell.style, effects)
          
          # Write to destination
          let destIdx = finalY * state.currentBuffer.width + finalX
          if destIdx >= 0 and destIdx < state.currentBuffer.cells.len:
            state.currentBuffer.cells[destIdx] = cell

# ================================================================
# HELPER FUNCTIONS
# ================================================================

proc mix(a, b, t: float): float =
  a * (1.0 - t) + b * t

proc clamp(val, minVal, maxVal: float): float =
  max(minVal, min(maxVal, val))
```

### Integration with Core

The plugin **hooks into** the rendering pipeline without modifying core types:

```nim
# src/runtime_api.nim - Add plugin check to render path

proc callOnDraw*(state: AppState) =
  # ... existing render code ...
  
  # Use effects compositing if plugin loaded
  when declared(compositeLayersWithEffects):
    if isLayerEffectsAvailable():
      compositeLayersWithEffects(state)
    else:
      compositeLayers(state)  # Core compositing
  else:
    compositeLayers(state)  # Core compositing (no plugin)
```

Or better yet, use a callback pattern:

```nim
# src/layers.nim - Core provides hooks

type
  CompositeHook* = proc(state: AppState)

var gCompositeHook*: CompositeHook = nil

proc compositeLayers*(state: AppState) =
  # Check if a plugin has registered an enhanced compositor
  if not gCompositeHook.isNil:
    gCompositeHook(state)
  else:
    # Standard compositing
    if state.layers.len == 0:
      return
    state.currentBuffer.clear(state.themeBackground)
    state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
    for layer in state.layers:
      if layer.visible:
        compositeBufferOnto(state.currentBuffer, layer.buffer)

# lib/layer_effects.nim - Plugin registers itself
proc initLayerEffectsPlugin*() =
  if gEffectsRegistry.isNil:
    gEffectsRegistry = LayerEffectsRegistry(...)
    
    # Register our enhanced compositor
    gCompositeHook = compositeLayersWithEffects
```

### Nimini Bindings

```nim
# lib/layer_effects_bindings.nim - Separate bindings module

import ../src/types
import ../src/runtime_api
import layer_effects
import ../nimini/runtime

proc registerLayerEffectsBindings*(env: ref Env) =
  ## Register layer effects functions to nimini
  ## Only called if plugin is included in build
  
  env.vars["setLayerOffset"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    if args.len < 3: return valNil()
    let layerId = getLayerIdFromValue(args[0])
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    setLayerOffset(layerId, x, y)
    return valNil()
  
  env.vars["setLayerDarkness"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    if args.len < 2: return valNil()
    let layerId = getLayerIdFromValue(args[0])
    let factor = valueToFloat(args[1])
    setLayerDarkness(layerId, factor)
    return valNil()
  
  env.vars["enableAutoDepthing"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    let minB = if args.len >= 1: valueToFloat(args[0]) else: 0.3
    let maxB = if args.len >= 2: valueToFloat(args[1]) else: 1.0
    enableAutoDepthing(minB, maxB)
    return valNil()
  
  env.vars["setLayerDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    if args.len < 3: return valNil()
    let layerId = getLayerIdFromValue(args[0])
    let effect = args[1].s
    let intensity = valueToFloat(args[2])
    setLayerDisplacement(layerId, effect, intensity)
    return valNil()
  
  env.vars["isLayerEffectsAvailable"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return valBool(isLayerEffectsAvailable())
```

### Build Configurations

#### Full Build (This Repo)
```nim
# tstorie.nim
import src/types
import src/layers
import lib/layer_effects  # Plugin included
import lib/layer_effects_bindings

# During initialization
initLayerEffectsPlugin()
registerLayerEffectsBindings(gEnv)
```

#### Minimal Build
```nim
# tstorie.nim
import src/types
import src/layers
# No layer_effects import!

# Core compositing works without plugin
```

## Benefits of Plugin Approach

1. **True Separation**: Core never depends on effects
2. **Zero Overhead**: Minimal builds don't allocate effect structs
3. **Clean Architecture**: Plugins extend, don't modify core
4. **Easy to Disable**: Just don't import the plugin
5. **Follows Pattern**: Same as audio_plugin, etc.

## Performance Impact

**Minimal Build**: No overhead at all
- Core compositing is unchanged
- No effect allocations
- No conditionals

**Full Build**: Overhead only when effects used
- Effects stored in table (only allocated layers with effects)
- Single table lookup per layer during composite
- ~O(1) overhead per layer

## Usage Example

```nim
# User document works in ANY build

```​nim on:init
# Check if effects available
if isLayerEffectsAvailable():
  echo "Layer effects enabled!"
  enableAutoDepthing(0.4, 1.0)
else:
  echo "Minimal build - core features only"
```​

```​nim on:update
# These work if plugin loaded, ignored otherwise
setLayerOffset("background", -int(cameraX * 0.3), 0)
setLayerDarkness("mountains", 0.6)

# No errors, no crashes, just graceful degradation
```​
```

## Conclusion

Making layer effects a **separate plugin** is the right architectural choice:

- ✅ Respects plugin architecture
- ✅ Core stays simple and focused
- ✅ True optional (not just conditional)
- ✅ Zero overhead when disabled
- ✅ Follows established patterns
- ✅ Clean separation of concerns

The key insight: **Core provides hooks, plugins enhance behavior**.
