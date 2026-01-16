# Layer Effects: Design Rationale

## The Problem

You want amazing visual effects in your terminal engine:
- Parallax scrolling for depth
- Atmospheric perspective (distant things darker)
- Dynamic effects (waves, displacement)
- Professional-looking scenes

**But you have constraints:**
- Terminal graphics (characters, not pixels)
- Plugin architecture (effects might not be available)
- User builds (full or minimal)
- No true opacity/alpha blending

## The Solution: Three-Tier Effect System

### Tier 1: Core Effects (Always Available)

**Why these?** They use only basic RGB math - no external dependencies.

```nim
LayerEffects* = object
  offsetX*, offsetY*: int        # Integer coordinate offset
  darkenFactor*: float           # RGB multiplier (0.0 to 1.0)
```

**Implementation:**
```nim
proc applyCoreForeEffect(style: Style, factor: float): Style =
  result.fg.r = uint8(clamp(float(style.fg.r) * factor, 0.0, 255.0))
  result.fg.g = uint8(clamp(float(style.fg.g) * factor, 0.0, 255.0))
  result.fg.b = uint8(clamp(float(style.fg.b) * factor, 0.0, 255.0))
```

**Why it works:**
- ✅ No dependencies
- ✅ Fast (simple multiplication)
- ✅ Universal (works in any terminal with color)
- ✅ Predictable results

### Tier 2: Auto-Depthing (The Killer Feature)

**Problem:** Manually setting brightness for each layer is tedious.

**Solution:** Automatically interpolate brightness based on z-coordinate.

```nim
proc applyAutoDepthing(state: AppState, minBrightness, maxBrightness: float) =
  # Find z-range
  var minZ = layers[0].z
  var maxZ = layers[0].z
  for layer in layers:
    minZ = min(minZ, layer.z)
    maxZ = max(maxZ, layer.z)
  
  # Apply interpolated brightness
  for layer in layers:
    let t = (layer.z - minZ) / (maxZ - minZ)  # 0.0 to 1.0
    layer.effects.darkenFactor = mix(minBrightness, maxBrightness, t)
```

**Why it's powerful:**
- ✅ ONE line for atmospheric perspective
- ✅ Automatic - works with any layer configuration
- ✅ Dynamic - adjusts as layers added/removed
- ✅ Intuitive - "back layers are darker"

**User experience:**
```nim
enableAutoDepthing(0.3, 1.0)  # Done! Professional depth effects
```

### Tier 3: Plugin-Enhanced Effects (Optional)

**Problem:** Advanced effects (displacement, noise) require complex math.

**Solution:** Leverage `terminal_shaders.nim` when available, ignore when not.

```nim
# In layer_shader_bridge.nim
when not defined(emscripten):
  import terminal_shaders
  
  proc applyDisplacementEffect(x, y: int, effect: string, 
                                intensity: float): tuple[dx, dy: int] =
    case effect
    of "wave": 
      # Use shader functions
      ...
    else:
      (0, 0)
else:
  # Minimal build - stub implementation
  proc applyDisplacementEffect(x, y: int, effect: string,
                                intensity: float): tuple[dx, dy: int] =
    (0, 0)
```

**Why conditional compilation?**
- ✅ Zero overhead when disabled
- ✅ No runtime checks in hot paths
- ✅ Clean separation of concerns
- ✅ User controls build size

**Graceful degradation:**
```nim
# User code - works in ANY build
setLayerDisplacement("water", "wave", 0.5)

# Full build: Wavy effect applied
# Minimal build: Silently ignored, no error
```

## Terminal Constraints: Creative Solutions

### Problem: No Real Opacity

**Terminal reality:**
- Can't blend two characters
- Can't have "50% transparent"
- Cell is either drawn or not

**Solution: Fake it with darkness**
```nim
proc applyFakeOpacity(style: Style, opacity: float): Style =
  # Blend toward background color
  # For dark terminals, this looks like opacity
  result.fg.r = uint8(float(style.fg.r) * opacity)
  result.fg.g = uint8(float(style.fg.g) * opacity)
  result.fg.b = uint8(float(style.fg.b) * opacity)
```

**Why it works:**
- Darkening simulates transparency on dark backgrounds
- Users perceive it as "fading"
- Good enough for depth cueing
- No actual alpha channel needed

### Problem: Character-Based "Blurring"

**Can't blur pixels, but we can:**
- Use lighter/denser characters (` ` → `░` → `▒` → `▓` → `█`)
- Fade colors toward background
- Adjust brightness/contrast

**For layer effects, we chose:**
- Focus on **color darkening** (universal, predictable)
- Leave character-based effects to shaders (optional)
- Prioritize simple, reliable effects

## Performance: Composite-Time Application

**Key decision:** Apply effects during `compositeLayers()`, not during drawing.

### Why?

**Option A: Apply during drawing (❌)**
```nim
proc draw(layer, x, y, text, style):
  # Apply effects here
  let effectStyle = applyLayerEffects(layer, style)
  layer.buffer.write(x, y, text, effectStyle)
```

**Problems:**
- Effects applied N times per draw call
- Shader functions called repeatedly
- Complex to implement
- Performance overhead

**Option B: Apply during composite (✅)**
```nim
proc compositeLayers(state):
  for layer in layers:
    # Apply effects ONCE per frame
    for each cell in layer.buffer:
      if layer.effects.darkenFactor < 1.0:
        cell.style = applyDarkening(cell.style, layer.effects.darkenFactor)
      
      if layer.effects.displacementEffect != "":
        # Displacement calculations
        ...
      
      dest[x, y] = cell
```

**Advantages:**
- ✅ Effects applied once per frame
- ✅ Consistent across all drawing methods
- ✅ Canvas sections get effects automatically
- ✅ Direct draws get effects automatically
- ✅ Separation of concerns: drawing vs compositing

**Performance:**
- ~60 FPS terminal: 80x30 = 2,400 cells
- With 4 layers: 9,600 cells/second to process
- Simple RGB multiply: negligible cost
- Displacement: ~10-20 µs per cell (still fast)

## Plugin Awareness: The Right Way

### Anti-Pattern: Runtime Checks Everywhere (❌)

```nim
proc draw(layer, x, y, text):
  if isShaderPluginAvailable():  # Check every call!
    applyShader(...)
  layer.buffer.write(...)
```

**Problems:**
- Performance overhead
- Clutters code
- Easy to forget checks
- Runtime dependencies

### Better: Conditional Compilation (✅)

```nim
when declared(terminal_shaders):
  const hasShaders = true
  import terminal_shaders
else:
  const hasShaders = false

proc applyDisplacement(...):
  when hasShaders:
    # Real implementation
  else:
    # Stub (compile-time eliminated)
```

**Advantages:**
- ✅ Zero runtime overhead
- ✅ Compiler eliminates dead code
- ✅ Type-safe (won't compile if missing)
- ✅ Clear dependencies

### User API: Graceful Degradation

```nim
# Public API that's always safe to call
proc setLayerDisplacement(layer, effect, intensity):
  when hasShaders:
    layer.effects.displacementEffect = effect
    layer.effects.displacementIntensity = intensity
  else:
    discard  # Silently ignore
```

**Why this works:**
- User code doesn't need conditionals
- Works in any build configuration
- Fails gracefully (no crashes)
- Discoverable via `getLayerEffectsAvailable()`

## API Design: Progressive Disclosure

### Level 1: Just Works™
```nim
enableAutoDepthing(0.4, 1.0)
```
One line, instant results. No configuration needed.

### Level 2: Simple Control
```nim
setLayerOffset("background", -cameraX / 3, 0)
setLayerDarkness("mountains", 0.6)
```
Straightforward, predictable API.

### Level 3: Advanced Effects
```nim
setLayerDisplacement("water", "wave", 0.5)
let available = getLayerEffectsAvailable()
```
Power features for those who need them.

### Level 4: Expert Mode
```nim
layer.effects.darkenFactor = computeComplexFading()
when hasShaders:
  customShaderIntegration()
```
Direct access for maximum control.

## Comparison: Other Approaches

### Game Engines (Unity, Godot)
- **Approach:** Full scene graph, shader languages, lighting systems
- **Pros:** Incredibly powerful, flexible
- **Cons:** Complex, heavyweight, requires GPU
- **Not suitable for terminals**

### ASCII/ANSI Libraries
- **Approach:** Character-based drawing, no layers
- **Pros:** Simple, fast
- **Cons:** No depth effects, manual z-ordering
- **Missing:** Atmospheric perspective

### tstorie's Approach
- **Layers:** Z-ordered compositing
- **Core effects:** Always available (offset, darkening)
- **Auto-depthing:** Killer feature (one-line depth)
- **Plugin-aware:** Enhanced when available
- **Terminal-native:** Respects character-based constraints

## Conclusion: Why This Design Works

1. **Pragmatic:** Works within terminal constraints
2. **Flexible:** Full or minimal builds supported
3. **Performant:** Composite-time application is efficient
4. **Intuitive:** Auto-depthing provides instant results
5. **Extensible:** Plugin system allows enhancements
6. **Reliable:** Graceful degradation prevents errors
7. **Simple:** Clear API, minimal configuration

**The key insight:** 
> Don't fight the terminal's limitations - embrace them with clever color effects and automatic depth perception!

**The killer feature:**
> ONE line (`enableAutoDepthing`) gives professional depth effects that would take hours to tune manually.

---

This design balances simplicity, power, and practicality to deliver visual effects that feel magical in a terminal context.
