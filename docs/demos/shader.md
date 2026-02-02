---
title: "Terminal Shaders Demo"
theme: "alleycat"
fontsize: 24
---

# Terminal Shaders - Procedural Visual Effects

This demo showcases shader-like visual effects in the terminal using
native Nim rendering for maximum performance.

```nim on:init
# Initialize shader system
var currentEffect = 0
var numEffects = 7

# Shader names
var effectName0 = "Plasma - Sine wave interference"
var effectName1 = "Ripple - Concentric waves"
var effectName2 = "Fire - Rising flames"
var effectName3 = "Fractal Noise - Multi-octave"
var effectName4 = "Wave Pattern - Horizontal flow"
var effectName5 = "Tunnel - Perspective distortion"
var effectName6 = "Matrix Rain - Digital cascade"

# Initialize shader (effectId, layerId, x, y, width, height, reduction)
# reduction: 1=full res, 2=half res (2x faster), 4=quarter res (4x faster)
# Max useful reduction: ~8 (beyond that, too few pixels render)
var renderHeight = termHeight - 4
var reduction = 8  # Default to half resolution for better performance
initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)

print "Terminal shaders initialized with native rendering"
```

```nim on:update
# Update shader animation every frame
updateShader()
```

```nim on:render
# Draw the current shader effect
drawShader(0)

# Get effect name based on index
var effectName = "Unknown"
if currentEffect == 0:
  effectName = effectName0
elif currentEffect == 1:
  effectName = effectName1
elif currentEffect == 2:
  effectName = effectName2
elif currentEffect == 3:
  effectName = effectName3
elif currentEffect == 4:
  effectName = effectName4
elif currentEffect == 5:
  effectName = effectName5
elif currentEffect == 6:
  effectName = effectName6

# Draw UI footer
var footerY = termHeight - 2
var headerStyle = getStyle("heading")
var bodyStyle = getStyle("body")
var linkStyle = getStyle("link")

# Clear footer area
fillRect(0, 0, footerY, termWidth, 2, " ", bodyStyle)

# Effect name
draw(0, 2, footerY, effectName, headerStyle)

# Controls
var controls = "  [P] Prev  [N] Next  [+/-] Res  [S] Pause  [R] Reset  [Q] Quit  (Click left/right to navigate)"
draw(0, 2, footerY + 1, controls, linkStyle)

# Progress indicator
var resText = "Res: 1/" & $(reduction)
var progressText = "Effect " & $(currentEffect + 1) & "/" & $(numEffects) & "  " & resText
draw(0, termWidth - len(progressText) - 2, footerY + 1, progressText, bodyStyle)
```

```nim on:input
if event.type == "text":
  var key = event.text
  if key == "n" or key == "N":
    # Next effect
    currentEffect = (currentEffect + 1) mod numEffects
    var renderHeight = termHeight - 4
    initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)
  elif key == "p" or key == "P":
    # Previous effect
    currentEffect = (currentEffect - 1 + numEffects) mod numEffects
    var renderHeight = termHeight - 4
    initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)
  elif key == "+" or key == "=":
    # Increase resolution (decrease reduction)
    if reduction > 1:
      reduction = reduction div 2
      var renderHeight = termHeight - 4
      initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)
      print "Resolution: " & $(termWidth div reduction) & "x" & $(renderHeight div reduction)
  elif key == "-" or key == "_":
    # Decrease resolution (increase reduction)
    if reduction < 8:
      reduction = reduction * 2
      var renderHeight = termHeight - 4
      initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)
      print "Resolution: " & $(termWidth div reduction) & "x" & $(renderHeight div reduction)
  elif key == "s" or key == "S":
    # Toggle pause (changed from P to S to avoid conflict with Previous)
    pauseShader()
    print "Animation paused"
  elif key == "r" or key == "R":
    # Reset animation
    resetShader()
    print "Animation reset"

elif event.type == "mouse":
  if event.action == "press":
    var mouseX = event.x
    var leftThird = termWidth / 3
    var rightThird = (termWidth * 2) / 3
    
    if mouseX < leftThird:
      # Click on left side - previous effect
      currentEffect = (currentEffect - 1 + numEffects) mod numEffects
      var renderHeight = termHeight - 4
      initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)
    elif mouseX > rightThird:
      # Click on right side - next effect
      currentEffect = (currentEffect + 1) mod numEffects
      var renderHeight = termHeight - 4
      initShader(currentEffect, 0, 0, 1, termWidth, renderHeight, reduction)
```

## Available Effects

**0. Plasma** - Multiple sine wave interference creating psychedelic patterns
   - Uses 4 sine waves at different frequencies
   - Rainbow color cycling
   - Character ramp: ` ░▒▓█`

**1. Ripple** - Concentric waves emanating from center
   - Distance-based wave calculation
   - Heatmap color gradient (black→red→yellow→white)
   - Smooth wave animation

**2. Fire** - Rising flames with turbulence
   - Height-based intensity
   - Procedural turbulence using hash functions
   - Fire gradient (black→red→orange→yellow)

**3. Fractal Noise** - Multi-octave Perlin-like noise
   - 4 octaves of smooth noise
   - Cool-warm color gradient
   - Fine-grained Braille characters for detail

**4. Wave** - Horizontal sine wave pattern
   - Simple directional wave
   - Ocean color palette (deep blue→cyan)
   - Block characters for smooth gradient: `▁▂▃▄▅▆▇█`

**5. Tunnel** - Rotating perspective distortion
   - Polar coordinate transformation
   - Distance and angle-based patterns
   - Neon cyan-magenta colors

**6. Matrix Rain** - Digital rain cascade
   - Column-based falling animation
   - Random character generation
   - Green matrix-style coloring

## Technical Implementation

All effects are rendered **natively in Nim** for maximum performance:
- Direct buffer manipulation (no per-pixel nimini calls)
- Tight loops run at native speed
- Character and color computed inline
- Simple API: `initShader()`, `updateShader()`, `drawShader()`

Compare this to the manual implementation where each pixel required:
- A nimini function call
- Style object creation
- Color calculation in interpreted code
- Individual draw() call

The native implementation is **orders of magnitude faster** and can easily
render at 60+ FPS on modern terminals!

## How It Works

**Character-as-Pixel Concept:**
- Each terminal cell acts as a "pixel" with:
  - **Density** (character choice): ` ░▒▓█` or `⡀⡄⡆⡇⣇⣧⣷⣿`
  - **Color** (RGB values): Full true color support

**Procedural Techniques:**
- **Distance Fields**: Ripple and Tunnel effects based on `dist(x, y, centerX, centerY)`
- **Sine Waves**: Plasma uses multiple sine wave interference patterns
- **Procedural Noise**: Fractal/Perlin-style generation with `intHash2D` and `fractalNoise2D`
- **Time-based Animation**: All shaders accept a frame counter for motion

**Color Palettes:**
- `heatmap()`: Black → Red → Yellow → White
- `plasma()`: Rainbow gradient
- `ocean()`: Deep blue → Cyan
- `fire()`: Black → Red → Orange → Yellow
- `neon()`: Cyan → Magenta with high saturation

**Character Ramps:**
```nim
DENSITY_ASCII   = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"]
DENSITY_SMOOTH  = [" ", "░", "▒", "▓", "█"]
DENSITY_BLOCKS  = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
DENSITY_BRAILLE = [" ", "⡀", "⡄", "⡆", "⡇", "⣇", "⣧", "⣷", "⣿"]
```

See `lib/terminal_shaders.nim` for full implementation!
