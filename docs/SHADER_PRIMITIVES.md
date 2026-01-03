# Shader Primitives Reference

This document describes the shader-oriented procedural generation primitives added to `lib/procgen_primitives.nim` and how to use them in both nimini scripts and exported native code.

## Overview

The shader primitives provide building blocks for creating terminal-based visual effects similar to GPU shaders, but using integer math for deterministic, platform-independent results. These primitives are designed to be composable - you can combine them in creative ways to build complex visual effects.

## Core Philosophy

1. **Integer-Only Math**: All primitives use integer math (scaled by 1000 for fixed-point decimals) to ensure deterministic behavior across platforms
2. **Composability**: Primitives are designed to be mixed and matched - build complex effects from simple building blocks
3. **Export-Compatible**: Works in both nimini scripts and exported native code (same primitives, same results)
4. **Performance**: Integer math is fast, making these suitable for real-time terminal rendering

## Trigonometry Functions

Fast integer trigonometry using lookup tables.

### `isin(angle: int): int`
Integer sine function.
- **Input**: Angle in decidegrees (0..3600, where 3600 = 360°)
- **Output**: -1000..1000 (scaled by 1000, so -1000 = -1.0, 1000 = 1.0)
- **Example**: `isin(900)` returns 1000 (sine of 90° = 1.0)
- **Use case**: Wave patterns, oscillations, circular motion

### `icos(angle: int): int`
Integer cosine function.
- **Input**: Angle in decidegrees (0..3600)
- **Output**: -1000..1000
- **Example**: `icos(0)` returns 1000 (cosine of 0° = 1.0)
- **Use case**: Complementary to isin for phase-shifted waves

**Example: Horizontal wave pattern**
```nim
var y = 0
while y < height:
  var x = 0
  while x < width:
    var wave = isin((x * 10 + frame * 5) mod 3600)
    # wave is now -1000..1000, oscillating horizontally
    x = x + 1
  y = y + 1
```

## Polar Coordinate Functions

Convert between Cartesian (x, y) and polar (distance, angle) coordinates.

### `polarDistance(x, y, centerX, centerY: int): int`
Calculate distance from center point.
- **Input**: Point (x, y) and center (centerX, centerY)
- **Output**: Distance in pixels
- **Use case**: Radial gradients, ripple effects, circular patterns

### `polarAngle(x, y, centerX, centerY: int): int`
Calculate angle from center point.
- **Input**: Point (x, y) and center (centerX, centerY)
- **Output**: Angle in decidegrees (0..3600)
- **Use case**: Spiral patterns, angular gradients, rotation effects

**Example: Ripple effect**
```nim
var centerX = termWidth / 2
var centerY = termHeight / 2

var y = 0
while y < termHeight:
  var x = 0
  while x < termWidth:
    var dist = polarDistance(x, y, centerX, centerY)
    var ripple = isin((dist * 20 - frame * 10) mod 3600)
    # Creates concentric rings moving outward
    x = x + 1
  y = y + 1
```

## Wave Combination Functions

Combine multiple wave patterns together.

### `waveAdd(wave1, wave2: int): int`
Add two waves together with clamping.
- **Input**: Two wave values (typically -1000..1000)
- **Output**: Sum clamped to -2000..2000
- **Use case**: Layer multiple wave patterns

### `waveMultiply(wave1, wave2: int): int`
Multiply two waves together.
- **Input**: Two wave values (typically -1000..1000)
- **Output**: Product (scaled back to -1000..1000)
- **Use case**: Modulation, interference patterns

### `waveMix(wave1, wave2, t: int): int`
Linear interpolation between two waves.
- **Input**: Two wave values, interpolation factor t (0..1000)
- **Output**: Mixed value
- **Example**: `waveMix(w1, w2, 500)` returns 50% mix
- **Use case**: Smooth transitions between patterns

**Example: Plasma effect using wave combination**
```nim
# Create 4 sine waves at different frequencies
var wave1 = isin((x * 10 + frame * 3) mod 3600)      # Horizontal
var wave2 = isin((y * 15 + frame * 2) mod 3600)      # Vertical
var wave3 = isin((x * 8 + y * 8 + frame * 4) mod 3600)  # Diagonal
var wave4 = isin(((x - cx) * (x - cx) + (y - cy) * (y - cy)) mod 3600)  # Radial

# Combine them
var combined = waveAdd(wave1, wave2)
combined = waveAdd(combined, wave3)
combined = waveAdd(combined, wave4)
# Result is now a complex interference pattern
```

## Color Palette Functions

Map values to color gradients. All color functions:
- **Input**: Value 0..255 (intensity)
- **Output**: Packed RGB integer (0xRRGGBB format)

### Easy Way: Using `unpackColor()` Helper

```nim
# Get color as packed integer
var colorInt = colorPlasma(value)

# Unpack using helper function
var color = unpackColor(colorInt)

# Use with style
var style = defaultStyle()
style.fg = color
draw(0, x, y, char, style)
```

### Manual Way: Extract RGB Components

```nim
# Get color as packed integer
var colorInt = colorPlasma(value)

# Extract RGB components manually
var r = (colorInt / 65536) mod 256  # (colorInt >> 16) & 0xFF
var g = (colorInt / 256) mod 256    # (colorInt >> 8) & 0xFF
var b = colorInt mod 256            # colorInt & 0xFF

# Create style and draw
var style = defaultStyle()
style.fg = rgb(r, g, b)
draw(0, x, y, char, style)
```

### `colorHeatmap(value: int): int`
Heatmap gradient: Black → Red → Yellow → White
- Classic heat visualization
- Good for: temperature maps, intensity visualization

### `colorPlasma(value: int): int`
Plasma/rainbow gradient: Blue → Purple → Red → Orange
- Full spectrum rainbow colors
- Good for: plasma effects, rainbow gradients

### `colorCoolWarm(value: int): int`
Cool-warm gradient: Blue → White → Red
- Diverging color scheme
- Good for: bidirectional data, temperature contrasts

### `colorFire(value: int): int`
Fire gradient: Black → Red → Orange → Yellow
- Realistic fire colors
- Good for: fire effects, ember glows

### `colorOcean(value: int): int`
Ocean gradient: Deep Blue → Cyan → White
- Water-themed colors
- Good for: water effects, underwater scenes

### `colorNeon(value: int): int`
Neon gradient: Purple → Pink → Cyan → Green
- Cyberpunk aesthetic
- Good for: neon signs, retro-futuristic effects

### `colorMatrix(value: int): int`
Matrix-style green gradient
- Classic Matrix rain aesthetic
- Good for: Matrix-style effects, terminal themes

### `colorGrayscale(value: int): int`
Simple grayscale: Black → White
- Monochrome gradient
- Good for: height maps, simple visualization

**Example: Coloring a wave pattern**
```nim
var wave = isin((x * 10 + frame * 5) mod 3600)  # -1000..1000

# Map wave to 0..255 for color lookup
var value = (wave + 1000) / 8  # Now 0..255
value = clamp(value, 0, 255)

# Get color and unpack
var color = unpackColor(colorPlasma(value))

# Create style and draw with color
var style = defaultStyle()
style.fg = color
draw(0, x, y, "█", style)
```

## Complete Working Examples

### Example 1: Simple Sine Wave
```nim
var y = 0
while y < height:
  var x = 0
  while x < width:
    # Horizontal sine wave
    var wave = isin((x * 15 + frame * 5) mod 3600)
    
    # Map to 0..255
    var value = (wave + 1000) / 8
    value = clamp(value, 0, 255)
    
    # Get and unpack color
    var color = unpackColor(colorPlasma(value))
    
    # Create style and draw
    var style = defaultStyle()
    style.fg = color
    var char = if value > 128: "█" else: " "
    draw(0, x, y, char, style)
    x = x + 1
  y = y + 1
```

### Example 2: Radial Gradient
```nim
var centerX = termWidth / 2
var centerY = termHeight / 2

var y = 0
while y < termHeight:
  var x = 0
  while x < termWidth:
    # Distance from center
    var dist = polarDistance(x, y, centerX, centerY)
    
    # Map to 0..255 (fade out at distance ~60)
    var value = 255 - clamp(dist * 4, 0, 255)
    
    # Get and unpack color
    var color = unpackColor(colorFire(value))
    
    # Create style and draw
    var style = defaultStyle()
    style.fg = color
    var char = if value > 50: "▒" else: " "
    draw(0, x, y, char, style)
    x = x + 1
  y = y + 1
```

### Example 3: Animated Ripple
```nim
var centerX = termWidth / 2
var centerY = termHeight / 2

var y = 0
while y < termHeight:
  var x = 0
  while x < termWidth:
    var dist = polarDistance(x, y, centerX, centerY)
    var angle = polarAngle(x, y, centerX, centerY)
    
    # Ripple moving outward
    var ripple = isin((dist * 20 - frame * 15) mod 3600)
    
    # Spiral component
    var spiral = isin((angle + dist * 5) mod 3600)
    
    # Combine
    var combined = waveMultiply(ripple, spiral)
    
    # Map to 0..255
    var value = (combined + 1000) / 8
    value = clamp(value, 0, 255)
    
    # Get and unpack color
    var color = unpackColor(colorOcean(value))
    
    # Create style and draw
    var style = defaultStyle()
    style.fg = color
    draw(0, x, y, "~", style)
    x = x + 1
  y = y + 1
```

## Tips and Best Practices

### 1. **Frequency Control**
Scale x/y coordinates to control pattern frequency:
```nim
var wave = isin((x * 5 + frame) mod 3600)   # Slow, wide waves
var wave = isin((x * 20 + frame) mod 3600)  # Fast, tight waves
```

### 2. **Animation**
Add `frame` counter to create movement:
```nim
var wave = isin((x * 10 + frame * 5) mod 3600)  # Moves right
var wave = isin((x * 10 - frame * 5) mod 3600)  # Moves left
var wave = isin((y * 10 + frame * 5) mod 3600)  # Moves down
```

### 3. **Value Mapping**
Always map wave outputs to color input ranges:
```nim
var wave = isin(angle)           # -1000..1000
var value = (wave + 1000) / 8    # 0..255 for colors
value = clamp(value, 0, 255)     # Ensure bounds
```

### 4. **Combining Patterns**
Layer multiple effects for complexity:
```nim
var wave1 = isin((x * 10) mod 3600)
var wave2 = isin((y * 15) mod 3600)
var wave3 = isin((x + y) mod 3600)
var combined = waveAdd(waveAdd(wave1, wave2), wave3)
```

### 5. **Polar for Radial**
Use polar coordinates for any circular/radial pattern:
```nim
var dist = polarDistance(x, y, centerX, centerY)
var angle = polarAngle(x, y, centerX, centerY)
# Now you can create spirals, rings, starbursts, etc.
```

## Performance Considerations

1. **Integer Math is Fast**: These primitives use only integer operations, no floating point
2. **Lookup Tables**: Trig functions use precomputed lookup tables for speed
3. **Avoid Redundant Calculations**: Calculate shared values (like center points) outside loops
4. **Character Density**: Use simpler character ramps (fewer unique characters) for better performance
5. **Resolution Reduction**: Render at lower resolution if needed (built into monolithic shader system)

## Comparison: Primitives vs Monolithic Shaders

**Monolithic Shaders** (`lib/terminal_shaders.nim`):
- ✅ Easy to use (single function call)
- ✅ Optimized rendering pipeline
- ✅ Resolution reduction built-in
- ❌ Fixed effects, hard to customize
- ❌ Can't combine effects

**Shader Primitives** (`lib/procgen_primitives.nim`):
- ✅ Fully composable
- ✅ Create custom effects
- ✅ Mix and match patterns
- ✅ Export-compatible
- ❌ More code to write
- ❌ Manual optimization needed

**Recommendation**: Use monolithic shaders for quick demos and standard effects. Use primitives when you need custom effects or want to export your patterns.

## Integration with Export System

These primitives work seamlessly with tstorie's export system because:

1. **Same Code**: Primitives use the same integer math in nimini and native code
2. **No Runtime Dependencies**: Pure functions with no state
3. **Deterministic**: Same inputs always produce same outputs
4. **Portable**: Works on any platform (WASM, native, exported)

When you export a nimini script using shader primitives, the exported code will use the exact same functions from `lib/procgen_primitives.nim`, ensuring identical results.

## See Also

- [shader_demo.md](docs/demos/shader_demo.md) - Monolithic shader system demos
- [shader_primitives_demo.md](docs/demos/shader_primitives_demo.md) - Interactive primitive composition demos
- [procgen_primitives.nim](lib/procgen_primitives.nim) - Full primitive library source
- [DUNGEN_SUMMARY.md](DUNGEN_SUMMARY.md) - Dungeon generation using same primitives

## Function Quick Reference

```nim
# Trigonometry (angle in decidegrees 0..3600, output -1000..1000)
isin(angle: int): int
icos(angle: int): int

# Polar coordinates
polarDistance(x, y, centerX, centerY: int): int
polarAngle(x, y, centerX, centerY: int): int  # Returns 0..3600

# Wave operations (inputs typically -1000..1000)
waveAdd(w1, w2: int): int
waveMultiply(w1, w2: int): int
waveMix(w1, w2, t: int): int  # t = 0..1000 blend factor

# Color palettes (input 0..255, output packed RGB int)
colorHeatmap(value: int): int
colorPlasma(value: int): int
colorCoolWarm(value: int): int
colorFire(value: int): int
colorOcean(value: int): int
colorNeon(value: int): int
colorMatrix(value: int): int
colorGrayscale(value: int): int
```
