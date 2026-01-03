---
title: "Shader Primitives - Build Your Own Effects"
theme: "catppuccin"
minWidth: 40
minHeight: 10
---

# Shader Primitives - Compose Your Own Effects

This demo shows how to use shader primitives to build custom visual effects
from scratch. Unlike the monolithic shader system, these primitives let you
combine waves, colors, and patterns in creative ways.

```nim on:init
# Initialize variables
var frame = 0
var paused = 0
var currentDemo = 0
var numDemos = 3

# Demo names
var demoName0 = "Plasma - Sine wave composition"
var demoName1 = "Ripple - Polar coordinates"
var demoName2 = "Custom - Wave mixing"

# Character ramps for intensity mapping
var densityRamp = " .'`^\,:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"

print "Shader primitives demo initialized"
```

```nim on:update
if paused == 0:
  frame = frame + 1
```

```nim on:render
# Clear the render area
var renderHeight = termHeight - 4
fillRect(0, 0, 1, termWidth, renderHeight, " ", getStyle("body"))

# Demo 0: Plasma effect using sine wave composition
if currentDemo == 0:
  var y = 0
  while y < renderHeight:
    var x = 0
    while x < termWidth:
      # Calculate 4 sine waves at different frequencies and phases
      var wave1 = isin((x * 10 + frame * 3) mod 3600)      # Horizontal
      var wave2 = isin((y * 15 + frame * 2) mod 3600)      # Vertical
      var wave3 = isin((x * 8 + y * 8 + frame * 4) mod 3600)  # Diagonal
      var wave4 = isin(((x - termWidth / 2) * (x - termWidth / 2) + (y - renderHeight / 2) * (y - renderHeight / 2)) mod 3600)
      
      # Combine waves (they're in range -1000..1000)
      var combined = waveAdd(wave1, wave2)
      combined = waveAdd(combined, wave3)
      combined = waveAdd(combined, wave4)
      
      # Map to 0..255 range for color lookup
      var value = (combined + 4000) / 31  # Scale to 0..255
      value = clamp(value, 0, 255)
      
      # Get plasma color (returns packed RGB integer)
      var colorInt = colorPlasma(value)
      
      # Unpack to color map for use with style
      var color = unpackColor(colorInt)
      
      # Create style with color
      var style = defaultStyle()
      style.fg = color
      
      # Map to character intensity
      var intensity = value / 4  # 0..63 for character ramp
      var charIdx = clamp(intensity, 0, 63)
      var char = " "
      if charIdx == 0:
        char = " "
      elif charIdx == 1:
        char = "."
      elif charIdx == 2:
        char = "'"
      elif charIdx >= 3 and charIdx < 10:
        char = ":"
      elif charIdx >= 10 and charIdx < 20:
        char = "+"
      elif charIdx >= 20 and charIdx < 30:
        char = "="
      elif charIdx >= 30 and charIdx < 40:
        char = "#"
      elif charIdx >= 40 and charIdx < 50:
        char = "@"
      else:
        char = "█"
      
      # Draw character with color
      draw(0, x, y + 1, char, style)
      x = x + 1
    y = y + 1

# Demo 1: Ripple effect using polar coordinates
elif currentDemo == 1:
  var centerX = termWidth / 2
  var centerY = renderHeight / 2
  
  var y = 0
  while y < renderHeight:
    var x = 0
    while x < termWidth:
      # Get distance and angle from center
      var dist = polarDistance(x, y, centerX, centerY)
      var angle = polarAngle(x, y, centerX, centerY)
      
      # Create ripple pattern
      var ripple = isin((dist * 20 - frame * 10) mod 3600)
      
      # Add spiral component using angle
      var spiral = isin((angle + dist * 5 + frame * 5) mod 3600)
      
      # Combine
      var combined = waveAdd(ripple, spiral)
      
      # Map to 0..255
      var value = (combined + 2000) / 16
      value = clamp(value, 0, 255)
      
      # Get ocean color (packed RGB integer) and unpack
      var color = unpackColor(colorOcean(value))
      
      # Create style with color
      var style = defaultStyle()
      style.fg = color
      
      # Map to character
      var char = " "
      if value < 200:
        char = " "
      elif value < 400:
        char = "."
      elif value < 600:
        char = "~"
      elif value < 800:
        char = "="
      else:
        char = "≈"
      
      draw(0, x, y + 1, char, style)
      x = x + 1
    y = y + 1

# Demo 2: Custom wave mixing
elif currentDemo == 2:
  var y = 0
  while y < renderHeight:
    var x = 0
    while x < termWidth:
      # Create two different wave patterns
      var wave1 = isin((x * 12 + frame * 4) mod 3600)
      var wave2 = icos((y * 20 - frame * 3) mod 3600)
      
      # Mix them based on position
      var mixFactor = (x * 1000) / termWidth  # 0..1000 across screen
      var mixed = waveMix(wave1, wave2, mixFactor)
      
      # Map to 0..255
      var value = (mixed + 1000) / 8
      value = clamp(value, 0, 255)
      
      # Get neon color (packed RGB integer) and unpack
      var color = unpackColor(colorNeon(value))
      
      # Create style with color
      var style = defaultStyle()
      style.fg = color
      
      # Map to character
      var char = " "
      if value < 150:
        char = " "
      elif value < 300:
        char = "."
      elif value < 450:
        char = ":"
      elif value < 600:
        char = "+"
      elif value < 750:
        char = "="
      elif value < 900:
        char = "#"
      else:
        char = "█"
      
      draw(0, x, y + 1, char, style)
      x = x + 1
    y = y + 1

# Draw UI footer
var footerY = termHeight - 2
var headerStyle = getStyle("heading")
var bodyStyle = getStyle("body")
var linkStyle = getStyle("link")

# Clear footer area
fillRect(0, 0, footerY, termWidth, 2, " ", bodyStyle)

# Effect name
var effectName = "Unknown"
if currentDemo == 0:
  effectName = demoName0
elif currentDemo == 1:
  effectName = demoName1
elif currentDemo == 2:
  effectName = demoName2

draw(0, 2, footerY, effectName, headerStyle)

# Controls
var controls = "  [P] Prev  [N] Next  [S] Pause  [R] Reset  [Q] Quit  (Click left/right to navigate)"
draw(0, 2, footerY + 1, controls, linkStyle)

# Progress indicator
var progressText = "Demo " & $(currentDemo + 1) & "/" & $(numDemos) & "  Frame: " & $(frame)
draw(0, termWidth - len(progressText) - 2, footerY + 1, progressText, bodyStyle)
```

```nim on:input
if event.type == "text":
  var key = event.text
  if key == "n" or key == "N":
    # Next demo
    currentDemo = (currentDemo + 1) mod numDemos
    frame = 0
  elif key == "p" or key == "P":
    # Previous demo
    currentDemo = (currentDemo - 1 + numDemos) mod numDemos
    frame = 0
  elif key == "s" or key == "S":
    # Toggle pause (changed from P to S)
    if paused == 0:
      paused = 1
    else:
      paused = 0
  elif key == "r" or key == "R":
    # Reset animation
    frame = 0

elif event.type == "mouse":
  if event.action == "press":
    var mouseX = event.x
    var leftThird = termWidth / 3
    var rightThird = (termWidth * 2) / 3
    
    if mouseX < leftThird:
      # Click on left side - previous demo
      currentDemo = (currentDemo - 1 + numDemos) mod numDemos
      frame = 0
    elif mouseX > rightThird:
      # Click on right side - next demo
      currentDemo = (currentDemo + 1) mod numDemos
      frame = 0
```

## Available Primitives

This demo showcases composable shader primitives that you can use to create your own effects:

### Trigonometry Functions
- `isin(angle)` - Integer sine (-1000..1000 for angle 0..3600 decidegrees)
- `icos(angle)` - Integer cosine (-1000..1000 for angle 0..3600 decidegrees)

### Polar Coordinates
- `polarDistance(x, y, centerX, centerY)` - Distance from center point
- `polarAngle(x, y, centerX, centerY)` - Angle from center (0..3600 decidegrees)

### Wave Operations
- `waveAdd(w1, w2)` - Add two waves with clamping
- `waveMultiply(w1, w2)` - Multiply two waves
- `waveMix(w1, w2, t)` - Mix two waves (t=0..1000 is blend factor)

### Color Palettes
- `colorHeatmap(v)` - Black → Red → Yellow → White
- `colorPlasma(v)` - Blue → Purple → Red → Orange
- `colorCoolWarm(v)` - Blue → White → Red
- `colorFire(v)` - Black → Red → Orange → Yellow
- `colorOcean(v)` - Deep Blue → Cyan → White
- `colorNeon(v)` - Purple → Pink → Cyan → Green
- `colorMatrix(v)` - Matrix-style green
- `colorGrayscale(v)` - Black → White

All color functions take values 0..255 and return a packed RGB integer (0xRRGGBB).
Use the `unpackColor()` helper to convert for use with styles:
```nim
var colorInt = colorPlasma(value)  # Get packed color
var color = unpackColor(colorInt)  # Unpack to {r, g, b} map
var style = defaultStyle()
style.fg = color
draw(0, x, y, char, style)
```

Alternatively, extract components manually:
```nim
var colorInt = colorPlasma(value)
var r = (colorInt / 65536) mod 256  # Extract red
var g = (colorInt / 256) mod 256    # Extract green  
var b = colorInt mod 256            # Extract blue
var style = defaultStyle()
style.fg = rgb(r, g, b)
```

## Tips for Building Effects

1. **Combine Multiple Waves**: Use `waveAdd()` to layer sine waves at different frequencies
2. **Use Polar Coordinates**: Create radial patterns with `polarDistance()` and `polarAngle()`
3. **Animate with Frame Counter**: Add frame to wave calculations for movement
4. **Scale Coordinates**: Multiply x/y by constants to change pattern frequency
5. **Map Values**: Use `map()` or manual scaling to convert wave ranges to 0..255 for colors
6. **Character Mapping**: Map intensity values to character ramps for ASCII art effects
7. **Mix Techniques**: Combine Cartesian waves with polar coordinates for complex patterns

These primitives work in both nimini scripts AND exported native code, making them ideal
for procedurally generated content that needs to export to production builds.
