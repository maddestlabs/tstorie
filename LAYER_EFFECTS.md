# Layer Effects and Transformations

## Overview

Enhanced layer system with transform, visual effects, and shader integration capabilities. These features make layers powerful compositing units that enable parallax scrolling, visual effects, and procedural transformations without modifying rendering code.

## Architecture Principle

**Effects are applied at composite time**, not during drawing. This ensures:
- ✅ Canvas sections automatically inherit layer effects
- ✅ Direct `draw*()` calls also get effects
- ✅ Separation of concerns: layers handle compositing, canvas handles layout
- ✅ Effects are applied once per frame, maximizing performance

## Layer Type Enhancements

### Current (Implemented)
```nim
Layer* = ref object
  id*: string          # Unique identifier (e.g., "canvas_z0", "ui", "background")
  z*: int              # Compositing order (negative = back, positive = front)
  visible*: bool       # Toggle layer visibility
  buffer*: TermBuffer  # Character/color data
```

### Transform Properties (Planned)
```nim
Layer* = ref object
  # ... existing fields ...
  
  # Transform properties
  offsetX*, offsetY*: int      # Screen-space offset for parallax/scrolling
  scaleX*, scaleY*: float      # Future: scaling (1.0 = normal, >1.0 = zoom in)
  rotation*: float             # Future: rotation in degrees (0-360)
```

### Visual Effects (Planned)
```nim
Layer* = ref object
  # ... existing fields ...
  
  # Color/style effects
  colorMultiply*: Color        # Tint/color filter (white = no change)
  saturation*: float           # 0.0 = grayscale, 1.0 = normal, >1.0 = vibrant
  brightness*: float           # 0.0 = black, 1.0 = normal, >1.0 = brighter
  contrast*: float             # 0.0 = flat gray, 1.0 = normal, >1.0 = high contrast
```

### Shader Integration (Planned)
```nim
Layer* = ref object
  # ... existing fields ...
  
  # Shader effects (from lib/terminal_shaders.nim)
  displacementFunc*: DisplacementFunc  # Procedural displacement (waves, noise, etc.)
```

## Use Cases

### 1. Parallax Scrolling
```nim
# In update callback
let bgLayer = state.getLayer("canvas_z-2")
let mgLayer = state.getLayer("canvas_z-1")

# Background moves slower (30% of camera speed)
bgLayer.offsetX = int(-cameraX * 0.3)
bgLayer.offsetY = int(-cameraY * 0.3)

# Midground moves medium speed (60% of camera speed)
mgLayer.offsetX = int(-cameraX * 0.6)
mgLayer.offsetY = int(-cameraY * 0.6)

# Foreground (z=0) moves at full camera speed
```

### 2. Depth Cueing (Atmospheric Perspective)
```nim
# Make distant layers darker and desaturated
let bgLayer = state.getLayer("canvas_z-2")
bgLayer.brightness = 0.4      # 40% brightness (darker)
bgLayer.saturation = 0.3      # 30% saturation (more gray)

let mgLayer = state.getLayer("canvas_z-1")
mgLayer.brightness = 0.7      # 70% brightness
mgLayer.saturation = 0.6      # 60% saturation
```

### 3. Dynamic Visual Effects
```nim
# Wavy underwater effect on background
let bgLayer = state.getLayer("canvas_z-1")
bgLayer.displacementFunc = waveDisplacement(
  amplitude: 2.0, 
  frequency: 0.2, 
  speed: 0.1
)

# Color tint for mood/atmosphere
bgLayer.colorMultiply = rgb(100, 150, 255)  # Blueish underwater tint
```

### 5. Canvas with Layer Effects
```markdown
# Background Mountains {"z": -2, "x": 0, "y": 0}
Static background section content here

# Animated Cloud Layer {"z": -1}

\`\`\`nimini:update
# Get the layer this section renders to
let cloudLayer = getLayerForZ(-1)

# Apply parallax and effects
cloudLayer.offsetX = int(time * 10) mod 200  # Scroll clouds
cloudLayer.saturation = 0.5                  # Desaturated
\`\`\`

# Main Content {"z": 0}
This is the primary gameplay/content area
```

## Implementation Strategy

### Phase 1: Transform Properties (Priority)
- Add `offsetX`, `offsetY` to Layer type
- Modify `compositeBufferOnto()` to respect offsets
- Enable parallax scrolling immediately

### Phase 2: Visual Effects
- Add saturation, brightness, contrast fields
- Create `applyColorEffects()` function
- Integrate into `compositeLayers()`

### Phase 3: Shader Integration
- Add `displacementFunc` field to Layer
- Create wrapper to apply displacement during composite
- Leverage existing `terminal_shaders.nim` functions

### Phase 4: Advanced Transforms (Future)
- Scale and rotation (requires interpolation/resampling)
- More complex compositing modes (multiply, screen, overlay)
- Layer groups/hierarchies

## API Design

### Getting Layers by Z-Index
```nim
proc getLayerForZ*(state: AppState, z: int): Layer =
  ## Get the layer canvas uses for given z-coordinate
  ## Returns nil if layer doesn't exist
  let layerId = "canvas_z" & $z
  return state.getLayer(layerId)
```

### Setting Layer Properties
```nim
# Simple property assignment
let layer = state.getLayerForZ(-1)
layer.offsetX = -100
layer.offsetY = -50
layer.brightness = 0.6
layer.saturation = 0.5
```

### Nimini Bindings (Future)
```nim
# From nimini scripts
setLayerOffset(-1, -100, -50)      # Set parallax offset
setLayerBrightness(-1, 0.6)        # Darken layer
setLayerSaturation(-1, 0.5)        # Desaturate
setLayerDisplacement(-1, "wave")   # Apply shader effect
```

## Performance Considerations

- **Effects applied once per frame** during composition, not per draw call
- **Lazy evaluation**: Effects only computed for visible layers
- **Shader caching**: Displacement functions can cache results for static areas
- **Early culling**: Invisible layers skipped entirely
- **Bounded operations**: All effects work within layer buffer bounds

## Integration with Canvas Z-Coordinates

Canvas sections can specify `z` in metadata:
```markdown
# Background {"z": -2, "x": 0, "y": 0, "width": 100}
# Midground {"z": -1}
# Foreground {"z": 0}
# Overlay {"z": 1}
```

Canvas automatically creates/uses layers: `canvas_z-2`, `canvas_z-1`, `canvas_z0`, `canvas_z1`

Users can then:
1. **Draw to those layers** using `drawBox(getLayerForZ(-1), ...)`
2. **Apply effects** to those layers using `layer.brightness = 0.5`
3. **Both approaches coexist** - section content and direct drawing get same effects

## Benefits

1. **Non-destructive**: Effects don't modify buffer data, applied at composite time
2. **Composable**: Multiple effects can be combined (parallax + darkness + displacement)
3. **Reusable**: Any system using layers gets effects (canvas, UI, particle systems)
4. **Performant**: Effects computed once during composition, not per draw call
5. **Intuitive**: Simple property assignment, no complex API
6. **Flexible**: Works with both canvas sections and direct drawing

## See Also

- [lib/canvas.nim](lib/canvas.nim) - Canvas system with z-coordinate support
- [lib/terminal_shaders.nim](lib/terminal_shaders.nim) - Shader effects and displacement functions
- [src/layers.nim](src/layers.nim) - Core layer system implementation
- [CANVAS_EDITOR.md](CANVAS_EDITOR.md) - Visual node editor architecture
