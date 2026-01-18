# Particle Shaders Guide

## Overview

The particle system now uses **shaders** for rendering, separating physics (particle movement) from appearance (how particles affect cells). This matches modern game engine architecture and provides maximum flexibility.

## Core Concept

```nim
Particle = Physics Data (position, velocity, life, color, char)
         ↓
    CellShader = Rendering (how particle affects a cell)
         ↓
    Output Cell (final appearance)
```

## Basic Usage

### 1. Default Behavior (Replace Entire Cell)

```nim
# Initialize a particle system
particleInit("rain", 1000)

# Configure as rain
particleConfigureRain("rain", 50.0)

# Render (uses default replaceShader automatically)
on:update -> particleUpdate("rain", dt)
on:render -> particleRender("rain", 0)  # layer 0
```

By default, particles use `replaceShader()` which replaces the entire cell (character + colors).

### 2. Using Different Shaders

```nim
# Particles only affect foreground color
particleSetShader("sparkles", "foreground")

# Particles only affect characters
particleSetShader("static", "char")

# Particles only affect background
particleSetShader("glow", "background")
```

## Available Shaders

### Basic Shaders

#### `replaceShader()` - Default
Replaces entire cell with particle (char + fg + bg).

```nim
particleSetShader("rain", "replace")
```

#### `charOnlyShader()`
Only changes the character, preserves all colors.

```nim
particleSetShader("noise", "char")
```

#### `foregroundOnlyShader()`
Only changes foreground color, preserves char and background.

```nim
particleSetShader("colorWash", "foreground")
```

#### `backgroundOnlyShader()`
Only changes background color, preserves char and foreground.

```nim
particleSetShader("glow", "background")
```

### Color Blending Shaders

#### `colorModulateShader(strength)`
Tints existing colors toward particle color (mixing).

```nim
# 30% blend with existing colors
particleSetShader("tint", "modulate", 0.3)
```

#### `colorAdditiveShader(strength)`
Adds particle color to existing (brightening effect).

```nim
# Brighten existing content
particleSetShader("brighten", "additive", 0.5)
```

#### `colorMultiplyShader()`
Multiplies colors together (darkening/filtering effect).

```nim
particleSetShader("darken", "multiply")
```

### Character Density Shaders

#### `charDensityReduceShader(amount)`
Makes characters less dense (more transparent).

```nim
# Reduce density by 2 steps
particleSetShader("fade", "density_reduce", 2)
```

Character density scale: ` ` → `.` → `·` → `:` → `-` → `=` → `+` → `*` → `#` → `@` → `█`

#### `charDensityIncreaseShader(amount)`
Makes characters more dense (more solid).

```nim
# Increase density by 1 step
particleSetShader("solidify", "density_increase", 1)
```

## Practical Examples

### Example 1: Subtle Rain (Tints Background)

```nim
particleInit("subtleRain", 500)
particleConfigureRain("subtleRain", 30.0)

# Use modulation to tint background subtly
particleSetShader("subtleRain", "modulate", 0.2)
particleSetColorRange("subtleRain", 100, 150, 200, 150, 200, 255)
```

### Example 2: Character Static Effect

```nim
particleInit("static", 200)
particleSetEmitRate("static", 50.0)
particleSetLifeRange("static", 0.1, 0.3)
particleSetChars("static", " ░▒▓█")

# Only affect characters, preserve colors
particleSetShader("static", "char")
```

### Example 3: Atmospheric Glow

```nim
particleInit("glow", 100)
particleSetEmitRate("glow", 20.0)
particleSetVelocityRange("glow", -1, -1, 1, 1)
particleSetLifeRange("glow", 2.0, 4.0)
particleSetFadeOut("glow", true)

# Additive blending for glow effect
particleSetShader("glow", "additive", 0.4)
particleSetColorRange("glow", 255, 200, 100, 255, 255, 150)
```

### Example 4: Text Corruption Effect

```nim
particleInit("corrupt", 50)
particleSetEmitRate("corrupt", 10.0)
particleSetLifeRange("corrupt", 1.0, 2.0)
particleSetChars("corrupt", "!@#$%^&*")

# Reduce character density where particles pass
particleSetShader("corrupt", "density_reduce", 1)
```

### Example 5: Color Wash Over Text

```nim
particleInit("colorWash", 100)
particleSetEmitRate("colorWash", 30.0)
particleSetVelocityRange("colorWash", 0, 5, 0, 10)
particleSetLifeRange("colorWash", 2.0, 4.0)
particleSetColorRange("colorWash", 255, 100, 200, 255, 150, 255)

# Modulate foreground only, preserve characters
particleSetShader("colorWash", "foreground")
particleSetShader("colorWash", "modulate", 0.5)  # Then add modulation
```

## Compositing Shaders (Advanced)

You can combine multiple shader effects:

```nim
particleInit("complex", 200)
particleConfigureRain("complex", 40.0)

# First reduce character density, then tint color
particleSetShaderComposite("complex", [
  "density_reduce:1",
  "modulate:0.3"
])
```

## Creating Custom Effects

### Lens Distortion Effect
```nim
particleInit("lensDistort", 50)
particleSetEmitterShape("lensDistort", 2)  # Circle
particleSetEmitterSize("lensDistort", 10, 10)
particleSetEmitRate("lensDistort", 0)  # Manual emit
particleSetLifeRange("lensDistort", 2.0, 2.0)
particleSetChars("lensDistort", "O")

# Particles push content outward (density reduce at edges)
particleSetShader("lensDistort", "density_reduce", 2)

# Emit on demand
on:click -> particleEmit("lensDistort", 20)
```

### Scanline Effect
```nim
particleInit("scanlines", 200)
particleSetEmitterShape("scanlines", 1)  # Line
particleSetEmitterSize("scanlines", screenWidth, 0)
particleSetEmitRate("scanlines", 40.0)
particleSetVelocityRange("scanlines", 0, 3, 0, 5)
particleSetLifeRange("scanlines", 3.0, 5.0)
particleSetChars("scanlines", "─")
particleSetColorRange("scanlines", 100, 255, 100, 150, 255, 150)

# Additive glow for scanlines
particleSetShader("scanlines", "additive", 0.3)
particleSetFadeOut("scanlines", true)
```

## Tips & Best Practices

1. **Start with default (`replace`) then experiment** - Most effects work well with full replacement

2. **Use modulation for subtle effects** - `modulate` with low strength (0.2-0.4) creates atmospheric effects

3. **Combine density changes with color** - Reducing density while changing color creates ghosting effects

4. **Additive works best for bright particles** - Use for glows, sparks, energy effects

5. **Character-only for glitch effects** - Preserving colors while changing chars creates digital corruption

6. **Background-only for subtle ambiance** - Change backgrounds to create weather/atmosphere without obscuring text

7. **Test with different content** - Effects look different on dense vs sparse text

## Shader Reference Quick Guide

| Shader | Best For | Preserves |
|--------|----------|-----------|
| `replace` | Standard particles, rain, snow | Nothing (full replace) |
| `char` | Glitch, corruption, noise | Colors |
| `foreground` | Color washes, tinting | Character, background |
| `background` | Ambient glow, weather | Character, foreground |
| `modulate` | Subtle tinting, fog | Character (adjusts colors) |
| `additive` | Glows, sparks, energy | Character (brightens) |
| `multiply` | Shadows, darkening | Character (darkens) |
| `density_reduce` | Fading, ghosting, distortion | Colors (adjusts density) |
| `density_increase` | Solidifying, emphasis | Colors (adjusts density) |

## Troubleshooting

**Particles not visible?**
- Check if shader is nil: `particleSetShader("name", "replace")`
- Ensure particles are being emitted: `particleGetCount("name")`
- Verify layer is visible and particles are in bounds

**Effect too subtle?**
- Increase shader strength parameter
- Use more particles (higher emit rate)
- Try additive blending instead of modulate

**Effect too strong?**
- Reduce strength parameter (0.1-0.3 range)
- Use fewer particles
- Increase fade out or reduce lifetime

**Colors look wrong?**
- Check particle color range vs background
- Try different blend modes
- Ensure background color is set correctly

## API Reference

```nim
# Set shader by name
particleSetShader(systemName: string, shaderType: string)
particleSetShader(systemName: string, shaderType: string, strength: float)

# Available shader types:
# - "replace", "char", "foreground", "background"
# - "modulate", "additive", "multiply"
# - "density_reduce", "density_increase"

# Composite shaders (apply multiple in sequence)
particleSetShaderComposite(systemName: string, shaders: seq[string])
```
