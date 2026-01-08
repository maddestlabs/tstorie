---
title: "Displacement Shaders Demo"
theme: "catppuccin"
minWidth: 60
minHeight: 20
---

# Displacement Shaders - Content Distortion Effects

This demo showcases displacement effects that warp and distort existing terminal
content in real-time. Click left/right or use arrow keys to cycle through effects!

```nim on:init
# Initialize displacement system
var currentEffect = 0
var numEffects = 8
var intensity = 1.0

# Effect names
var effectName0 = "Horizontal Wave - Ocean waves"
var effectName1 = "Vertical Wave - Curtain ripple"
var effectName2 = "Ripple - Water drop impact"
var effectName3 = "Noise - Organic turbulence"
var effectName4 = "Heat Haze - Desert shimmer"
var effectName5 = "Swirl - Vortex rotation"
var effectName6 = "Fisheye - Lens distortion"
var effectName7 = "Bulge - Animated pulse"

# Render area dimensions
var renderHeight = termHeight - 4
var contentLayer = 0
var displayLayer = 1

# Initialize displacement
initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)

print "Displacement shaders initialized"
```

```nim on:update
# Update displacement animation every frame
updateDisplacement()
```

```nim on:render
# First, draw content to layer 0 (source)
clear(contentLayer)

# Draw a grid pattern with text as content to distort
var gridStyle = getStyle("body")
var headingStyle = getStyle("heading")
var linkStyle = getStyle("link")
var commentStyle = getStyle("comment")

# Title in the middle
var titleY = renderHeight / 2 - 5
draw(contentLayer, termWidth / 2 - 15, titleY, "DISPLACEMENT SHADERS", headingStyle)
draw(contentLayer, termWidth / 2 - 20, titleY + 2, "Real-time content distortion effects", linkStyle)

# Draw a grid of text for distortion
var gridSpacing = 4
var y = 4
while y < renderHeight - 4:
  var x = 5
  while x < termWidth - 10:
    if (x / gridSpacing) mod 2 == 0 and (y / gridSpacing) mod 2 == 0:
      draw(contentLayer, x, y, "•", commentStyle)
    elif (x / gridSpacing) mod 2 == 1 and (y / gridSpacing) mod 2 == 1:
      draw(contentLayer, x, y, "○", gridStyle)
    x = x + gridSpacing
  y = y + gridSpacing

# Draw border frame
var borderStyle = getStyle("link")
var borderY = 2
var borderH = renderHeight - 4
# Top and bottom
var bx = 2
while bx < termWidth - 2:
  draw(contentLayer, bx, borderY, "─", borderStyle)
  draw(contentLayer, bx, borderY + borderH, "─", borderStyle)
  bx = bx + 1

# Sides
var by = borderY
while by <= borderY + borderH:
  draw(contentLayer, 2, by, "│", borderStyle)
  draw(contentLayer, termWidth - 3, by, "│", borderStyle)
  by = by + 1

# Corners
draw(contentLayer, 2, borderY, "┌", borderStyle)
draw(contentLayer, termWidth - 3, borderY, "┐", borderStyle)
draw(contentLayer, 2, borderY + borderH, "└", borderStyle)
draw(contentLayer, termWidth - 3, borderY + borderH, "┘", borderStyle)

# Add some ASCII art elements
if termWidth > 60:
  draw(contentLayer, 10, 6, "  ╔═══╗  ", linkStyle)
  draw(contentLayer, 10, 7, "  ║ ◉ ║  ", linkStyle)
  draw(contentLayer, 10, 8, "  ╚═══╝  ", linkStyle)
  
  draw(contentLayer, termWidth - 20, 6, "  ╭───╮  ", commentStyle)
  draw(contentLayer, termWidth - 20, 7, "  │ ★ │  ", commentStyle)
  draw(contentLayer, termWidth - 20, 8, "  ╰───╯  ", commentStyle)

# Add some text labels
if termHeight > 15:
  draw(contentLayer, 6, renderHeight - 8, "WAVE", gridStyle)
  draw(contentLayer, termWidth - 20, renderHeight - 8, "DISTORT", gridStyle)
  draw(contentLayer, termWidth / 2 - 4, 5, "CONTENT", headingStyle)

# Clear display layer
clear(displayLayer)

# Apply displacement from content layer to display layer
drawDisplacement(displayLayer, contentLayer)

# Get effect name
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
elif currentEffect == 7:
  effectName = effectName7

# Draw UI footer on display layer
var footerY = termHeight - 2
var headerStyle = getStyle("heading")
var bodyStyle = getStyle("body")

# Clear footer area
fillRect(displayLayer, 0, footerY, termWidth, 2, " ", bodyStyle)

# Effect name
draw(displayLayer, 2, footerY, effectName, headerStyle)

# Controls
var controls = "  [P] Prev  [N] Next  [+/-] Intensity  [S] Pause  [R] Reset  (Click left/right to navigate)"
draw(displayLayer, 2, footerY + 1, controls, linkStyle)

# Progress indicator
var intensityText = "Intensity: " & $(int(intensity * 100.0)) & "%"
var progressText = "Effect " & $(currentEffect + 1) & "/" & $(numEffects) & "  " & intensityText
draw(displayLayer, termWidth - len(progressText) - 2, footerY + 1, progressText, bodyStyle)
```

```nim on:input
if event.type == "text":
  var key = event.text
  if key == "n" or key == "N":
    # Next effect
    currentEffect = (currentEffect + 1) mod numEffects
    var renderHeight = termHeight - 4
    initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)
  elif key == "p" or key == "P":
    # Previous effect
    currentEffect = (currentEffect - 1 + numEffects) mod numEffects
    var renderHeight = termHeight - 4
    initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)
  elif key == "+" or key == "=":
    # Increase intensity
    if intensity < 3.0:
      intensity = intensity + 0.2
      setDisplacementIntensity(intensity)
      print "Intensity: " & $(int(intensity * 100.0)) & "%"
  elif key == "-" or key == "_":
    # Decrease intensity
    if intensity > 0.2:
      intensity = intensity - 0.2
      setDisplacementIntensity(intensity)
      print "Intensity: " & $(int(intensity * 100.0)) & "%"
  elif key == "s" or key == "S":
    # Toggle pause
    pauseDisplacement()
    print "Animation paused/resumed"
  elif key == "r" or key == "R":
    # Reset animation
    resetDisplacement()
    print "Animation reset"

elif event.type == "key":
  if event.keyCode == 1002:  # Left arrow
    currentEffect = (currentEffect - 1 + numEffects) mod numEffects
    var renderHeight = termHeight - 4
    initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)
  elif event.keyCode == 1003:  # Right arrow
    currentEffect = (currentEffect + 1) mod numEffects
    var renderHeight = termHeight - 4
    initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)

elif event.type == "mouse":
  if event.action == "press":
    var mouseX = event.x
    var leftThird = termWidth / 3
    var rightThird = (termWidth * 2) / 3
    
    if mouseX < leftThird:
      # Click on left side - previous effect
      currentEffect = (currentEffect - 1 + numEffects) mod numEffects
      var renderHeight = termHeight - 4
      initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)
    elif mouseX > rightThird:
      # Click on right side - next effect
      currentEffect = (currentEffect + 1) mod numEffects
      var renderHeight = termHeight - 4
      initDisplacement(currentEffect, displayLayer, 0, 1, termWidth, renderHeight, intensity)
```

## Available Displacement Effects

**0. Horizontal Wave** 🌊
   - Sine wave distortion along X-axis
   - Creates ocean wave effect
   - Perfect for liquid/water simulations

**1. Vertical Wave** 📏
   - Sine wave distortion along Y-axis
   - Curtain or flag ripple effect
   - Smooth vertical undulation

**2. Ripple** 💧
   - Radial waves from center point
   - Water drop impact simulation
   - Distance-based wave propagation

**3. Noise Distortion** 🌪️
   - Multi-octave Perlin-like noise
   - Organic, turbulent distortion
   - Great for heat/air distortion effects

**4. Heat Haze** 🔥
   - Wavy vertical shimmer
   - Desert mirage effect
   - Combines noise with wave motion

**5. Swirl/Vortex** 🌀
   - Rotational distortion around center
   - Whirlpool or tornado effect
   - Angle-based displacement

**6. Fisheye Lens** 🔍
   - Radial scaling distortion
   - Camera lens effect
   - Distance-based magnification

**7. Animated Bulge** 🫧
   - Pulsing bubble effect
   - Rhythmic expansion/contraction
   - Time-animated displacement

## How Displacement Works

**Displacement vs Drawing:**
Unlike traditional shaders that draw new patterns, displacement shaders **reposition
existing content** by calculating offset vectors for each cell.

**The Algorithm:**
```
For each cell (x, y):
  1. Calculate displacement offset: (dx, dy) = displacementFunc(x, y, time)
  2. Sample source content at: (x + dx, y + dy)
  3. Write sampled content to: (x, y)
```

**Advantages:**
- ✅ Preserves original content (text, colors, styles)
- ✅ More efficient than redrawing patterns
- ✅ Can combine with any visual content
- ✅ Creates realistic distortion effects
- ✅ Lower computational cost than color shaders

**Real-World Applications:**
- UI transitions and animations
- Water/liquid surface effects
- Heat shimmer and atmospheric effects
- Lens and camera distortions
- Portal/wormhole effects
- Gravity well visualizations

## Performance

Displacement shaders are optimized for real-time rendering:
- **Native Nim implementation** - No per-pixel script calls
- **Direct buffer access** - Efficient memory operations
- **Bounds checking** - Safe edge handling
- **Configurable intensity** - Fine-tune distortion strength

The system renders at **60+ FPS** even with complex multi-octave noise functions!

## API Usage

```nim
# Initialize
initDisplacement(effectId, layerId, x, y, width, height, intensity)

# Update animation
updateDisplacement()

# Render
drawDisplacement(destLayer, sourceLayer)
# or
drawDisplacementInPlace(layer)

# Controls
setDisplacementEffect(newEffectId)
setDisplacementIntensity(0.0 to 3.0)
pauseDisplacement() / resumeDisplacement()
resetDisplacement()
```

## Try It!

- **Click left/right** edges to navigate effects
- **Arrow keys** also work for navigation
- **+/-** to adjust distortion intensity
- **P/N** for previous/next effect
- **S** to pause/resume animation
- **R** to reset to beginning

Experiment with different intensities to see how extreme distortions can create
surreal and artistic effects!
