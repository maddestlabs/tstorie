# Layer Effects Quick Reference

## Always Available (Core - No Plugins)

### Parallax/Camera Offset
```nim
setLayerOffset(layerId, offsetX, offsetY)
```
- Shifts layer content by given pixels
- Perfect for parallax scrolling
- Works with any layer ID (string) or index (int)

**Example:**
```nim
setLayerOffset("background", -int(cameraX * 0.3), 0)  # 30% scroll speed
```

### Darkening/Brightness
```nim
setLayerDarkness(layerId, factor)  # 0.0 = black, 1.0 = normal
```
- Multiplies all RGB color values
- Great for depth cueing (distant = darker)
- Instant atmospheric perspective

**Example:**
```nim
setLayerDarkness("mountains", 0.5)  # 50% brightness (darker)
```

### Auto-Depth Cueing (⭐ Recommended!)
```nim
enableAutoDepthing(minBrightness, maxBrightness)
```
- **Automatically** darkens layers based on z-coordinate
- Lower z (background) → darker
- Higher z (foreground) → brighter
- ONE line for professional depth effects!

**Example:**
```nim
enableAutoDepthing(0.4, 1.0)  # Background at 40%, foreground at 100%
```

## Plugin-Enhanced (Optional)

These features work if `terminal_shaders` plugin is available, otherwise gracefully ignored.

### Displacement Effects
```nim
setLayerDisplacement(layerId, effect, intensity)
```
- `effect`: "wave", "ripple", "noise", ""
- `intensity`: 0.0 to 1.0+ (strength)
- Creates wavy/distorted visual effects

**Example:**
```nim
setLayerDisplacement("water", "wave", 0.5)  # Wavy water effect
```

## Introspection

### Check Available Effects
```nim
let effects = getLayerEffectsAvailable()

if effects.displacement:
  # Shader plugin available
  setLayerDisplacement("bg", "wave", 0.3)
else:
  # Minimal build - use core effects only
  setLayerDarkness("bg", 0.7)
```

## Common Patterns

### Parallax Scrolling Game
```nim
on:init
  enableAutoDepthing(0.3, 1.0)  # Auto depth!

on:update
  # Move layers at different speeds for parallax
  setLayerOffset("sky", -int(cameraX * 0.1), 0)      # 10% speed
  setLayerOffset("mountains", -int(cameraX * 0.3), 0) # 30% speed
  setLayerOffset("trees", -int(cameraX * 0.6), 0)     # 60% speed
  setLayerOffset("player", -int(cameraX), 0)          # 100% speed
  
  # Layers auto-darken by depth - no manual tuning needed!
```

### Underwater Scene
```nim
on:init
  setLayerDarkness("background", 0.6)  # Darker in deep water
  
on:update
  # Wave effect if shader plugin available
  setLayerDisplacement("seaweed", "wave", 0.4)
```

### Foggy Forest
```nim
on:init
  enableAutoDepthing(0.2, 1.0)  # Heavy fog effect
  
  # Distant trees very dark (fog obscures)
  # Close objects bright and clear
```

## Performance Notes

- Effects applied **once per frame** during layer compositing
- No performance penalty per draw call
- Works with both canvas sections and direct drawing
- Efficient: only visible layers processed

## Build Configurations

### Full Build (All Features)
```bash
nim c -d:release tstorie.nim
```
All effects available.

### Minimal Build (Core Only)
```bash
nim c -d:release -d:minimalBuild tstorie.nim
```
Core effects only (offset, darkness, auto-depthing).

Your code adapts automatically - no changes needed!

## Tips & Tricks

1. **Start with auto-depthing**: One line, huge impact
2. **Test without plugins**: Your content should degrade gracefully
3. **Combine effects**: Offset + darkness = parallax with depth
4. **Animate carefully**: Smooth motion > flashy effects
5. **Check availability**: Use `getLayerEffectsAvailable()` for feature detection

## See Also

- [LAYER_EFFECTS.md](LAYER_EFFECTS.md) - Conceptual overview
- [LAYER_EFFECTS_IMPLEMENTATION.md](LAYER_EFFECTS_IMPLEMENTATION.md) - Implementation details
- [lib/terminal_shaders.nim](lib/terminal_shaders.nim) - Shader plugin documentation
