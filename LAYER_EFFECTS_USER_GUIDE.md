# Layer Effects Plugin - User Guide

The Layer Effects plugin provides visual effects for tstorie's layer system, enabling parallax scrolling, automatic depth cueing, and per-layer visual transformations.

## Features

### 1. Parallax Scrolling
Move layers at different speeds to create depth illusion:

```nim
setLayerOffset("background", x, y)  # Offset layer position
```

### 2. Auto-Depthing
Automatically darken background layers based on z-depth:

```nim
enableAutoDepthing(minDarken, maxDarken)  # 0.0-1.0 range
disableAutoDepthing()
```

### 3. Layer Darkening
Manually control layer brightness:

```nim
setLayerDarkness("layer_id", 0.5)  # 0.0 = black, 1.0 = full brightness
```

### 4. Desaturation
Remove color from layers:

```nim
setLayerDesaturation("layer_id", 0.8)  # 0.0 = full color, 1.0 = grayscale
```

### 5. Shader Effects (if available)
Displacement and advanced effects when shaders are compiled:

```nim
setLayerDisplacement("layer_id", amount)  # Requires shader support
```

## Complete API Reference

### Plugin Control

```nim
enableLayerFx()          # Enable layer effects processing
disableLayerFx()         # Disable effects (improves performance)
clearLayerEffects("id")  # Remove effects from one layer
```

### Offset Effects (Parallax)

```nim
setLayerOffset(layerId: string, offsetX, offsetY: int)
```

**Example - Smooth Parallax:**
```nim
var time = 0.0

on update:
  time = time + dt
  let scrollX = sin(time) * 50.0
  
  # Far background moves slowest
  setLayerOffset("bg", int(scrollX * 0.2), 0)
  
  # Mid-ground moves medium speed
  setLayerOffset("mid", int(scrollX * 0.6), 0)
  
  # Near objects move fastest
  setLayerOffset("near", int(scrollX), 0)
```

### Auto-Depthing

```nim
enableAutoDepthing(depthMin, depthMax: float)
disableAutoDepthing()
```

Parameters:
- `depthMin`: Brightness multiplier for closest layer (typically 0.7-1.0)
- `depthMax`: Brightness multiplier for farthest layer (typically 0.3-0.7)

**Example:**
```nim
# Subtle depth effect
enableAutoDepthing(0.8, 1.0)

# Strong depth effect (atmospheric perspective)
enableAutoDepthing(0.3, 1.0)
```

Auto-depthing automatically calculates darkness based on layer z-depth. Layers with lower z values (more negative) are darker.

### Manual Darkness Control

```nim
setLayerDarkness(layerId: string, factor: float)
```

Factor range: 0.0 (completely black) to 1.0 (original brightness)

**Example - Fade In Effect:**
```nim
var fadeFactor = 0.0

on update:
  if fadeFactor < 1.0:
    fadeFactor = fadeFactor + dt * 0.5
    setLayerDarkness("foreground", fadeFactor)
```

### Desaturation

```nim
setLayerDesaturation(layerId: string, amount: float)
```

Amount range: 0.0 (full color) to 1.0 (complete grayscale)

**Example - Memory/Flashback Effect:**
```nim
# Make background look like old memory
setLayerDesaturation("background", 0.9)
setLayerDarkness("background", 0.6)
```

### Displacement (Shader Required)

```nim
setLayerDisplacement(layerId: string, amount: float)
```

Creates wave/distortion effects. Only available when shaders are compiled in.

## Complete Examples

### Example 1: Parallax Scrolling Scene

```nim on:init
# Create depth layers
addLayer("sky", -3)
addLayer("mountains", -2)
addLayer("trees", -1)
addLayer("player", 0)

# Enable depth cueing
enableAutoDepthing(0.4, 1.0)

# Draw static content
setLayer("sky")
fillRect(0, 0, 80, 30, ' ', rgb(100, 150, 200))

setLayer("mountains")
# Draw mountains...

setLayer("trees")
# Draw trees...

var cameraX = 0.0
```

```nim on:update
# Smooth camera movement
cameraX = cameraX + dt * 10.0

# Apply parallax based on depth
setLayerOffset("sky", int(-cameraX * 0.1), 0)
setLayerOffset("mountains", int(-cameraX * 0.3), 0)
setLayerOffset("trees", int(-cameraX * 0.7), 0)
setLayerOffset("player", int(-cameraX), 0)
```

### Example 2: Dynamic Depth of Field

```nim on:init
addLayer("background", -2)
addLayer("focus", 0)
addLayer("foreground", 2)

var focusDepth = 0  # -2, 0, or 2
```

```nim on:update
# Simulate focus change based on game state
# (e.g., player looks at different depths)

# Blur/darken out-of-focus layers
if focusDepth == 0:
  setLayerDesaturation("background", 0.7)
  setLayerDarkness("background", 0.6)
  setLayerDesaturation("foreground", 0.7)
  setLayerDarkness("foreground", 0.6)
  setLayerDesaturation("focus", 0.0)
  setLayerDarkness("focus", 1.0)
```

### Example 3: Atmospheric Weather

```nim on:init
addLayer("scene", 0)
addLayer("fog", 1)
addLayer("rain", 2)

enableAutoDepthing(0.6, 1.0)

var fogDensity = 0.0
var rainIntensity = 0.0
```

```nim on:update
# Animate fog rolling in
fogDensity = sin(time * 0.1) * 0.5 + 0.5
setLayerDesaturation("scene", fogDensity * 0.4)
setLayerDarkness("scene", 1.0 - fogDensity * 0.3)

# Simulate rain by offsetting rain layer
setLayerOffset("rain", int(time * -20.0) mod 10, int(time * 100.0) mod 30)
```

## Performance Considerations

1. **Disable When Not Needed**: Use `disableLayerFx()` during static scenes
2. **Limit Layer Count**: Effects are applied per-layer during compositing
3. **Auto-Depthing is Cheap**: Darkness calculation happens once per frame
4. **Offset is Free**: No performance cost, just changes blit position
5. **Desaturation is Expensive**: Color conversion per pixel

## Integration with Other Systems

### With Canvas Module

```nim
# Canvas commands draw to active layer
setLayer("ui")
drawRect(10, 10, 30, 15, rgb(255, 255, 255))

# Apply effects to the canvas layer
setLayerDarkness("ui", 0.8)
```

### With Animation Module

```nim
# Use easing functions for smooth transitions
let t = easeInOutQuad(time / duration)
setLayerDarkness("fade", t)
```

### With Section Manager

```nim
# Apply effects per story section
on section_enter:
  if currentSection() == "cave":
    enableAutoDepthing(0.3, 1.0)
    setLayerDesaturation("environment", 0.5)
```

## Troubleshooting

**Effects not visible:**
- Ensure plugin is initialized (automatic in recent builds)
- Check layer IDs match exactly (case-sensitive)
- Verify layer z-ordering is set up correctly

**Performance issues:**
- Disable effects: `disableLayerFx()`
- Reduce number of layers
- Use auto-depthing instead of per-frame darkness updates

**Shader features unavailable:**
- Displacement requires compilation with `terminal_shaders` module
- Check `getLayerFxInfo()` for shader support status

## Future Enhancements

Planned features:
- Blur effects (requires shader support)
- Color tinting per layer
- Layer masks and blend modes
- Time-based automatic animations
- Per-pixel lighting effects

## See Also

- [LAYER_EFFECTS.md](../LAYER_EFFECTS.md) - Technical design document
- [LAYER_EFFECTS_RATIONALE.md](../LAYER_EFFECTS_RATIONALE.md) - Architecture decisions
- [canvas.nim](../../lib/canvas.nim) - Canvas drawing system
- [layers.nim](../../src/layers.nim) - Core layer management
