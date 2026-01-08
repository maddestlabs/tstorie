---
title: "Drawing & Compositing Demo"
minWidth: 100
minHeight: 50
theme: "futurism"
---

# Drawing API Showcase

This demo showcases the drawing system including box styles, fill operations, and various drawing primitives.

```nim on:init
# ===================================================================
# State Management
# ===================================================================
var animFrame = 0
var rotation = 0.0

# Moving shapes for demo
var circle1X = 45.0
var circle1Y = 10.0
var circle1DirX = 0.3
var circle1DirY = 0.2

var circle2X = 50.0
var circle2Y = 12.0
var circle2DirX = -0.25
var circle2DirY = 0.15

# Box style cycling
var currentBoxStyle = 0
var boxStyles = @["single", "double", "rounded", "bold", "ascii"]
var boxStyleNames = @["Single Line", "Double Line", "Rounded", "Bold", "ASCII"]

# Fill pattern
var fillPattern = 0
var fillPatterns = @["█", "▓", "▒", "░", "■", "●", "◆", "▪"]

# Message
var message = "B: Change box style | F: Change fill pattern | Arrow keys: Move red circle"
```

```nim on:render
# ===================================================================
# Render
# ===================================================================
clear()

let w = getWidth()
let h = getHeight()

# Title banner
fillBox(0, 0, 0, w, 3, "═", getStyle("primary"))
drawLabel(0, w div 2 - 12, 1, "DRAWING API SHOWCASE", getStyle("warning"))

# Decorative corners
drawLabel(0, 0, 0, "╔", getStyle("primary"))
drawLabel(0, w - 1, 0, "╗", getStyle("primary"))
drawLabel(0, 0, 2, "╚", getStyle("primary"))
drawLabel(0, w - 1, 2, "╝", getStyle("primary"))

# Draw a grid background using dots
var gx = 0
while gx < w:
  var gy = 5
  while gy < h - 3:
    if gx mod 10 == 0 or gy mod 5 == 0:
      drawLabel(0, gx, gy, "·", getStyle("dim"))
    gy = gy + 1
  gx = gx + 1

# ===================================================================
# Box Styles Gallery
# ===================================================================
drawPanel(0, 2, 5, 30, 18, "Box Styles Gallery", boxStyles[currentBoxStyle])

var styleY = 7
var idx = 0
while idx < len(boxStyles):
  let style = boxStyles[idx]
  let name = boxStyleNames[idx]
  let isCurrent = idx == currentBoxStyle
  
  drawBox(0, 4, styleY, 12, 3, getStyle("border"), style)
  drawLabel(0, 17, styleY + 1, name, if isCurrent: getStyle("success") else: getStyle("default"))
  
  styleY = styleY + 3
  idx = idx + 1

# ===================================================================
# Fill Patterns
# ===================================================================
drawPanel(0, 35, 5, 30, 12, "Fill Patterns", "double")

# Large filled rectangle with current pattern
let patternChar = fillPatterns[fillPattern]
fillBox(0, 37, 7, 26, 5, patternChar, getStyle("primary"))
drawLabel(0, 39, 8, "Current: " & patternChar, getStyle("warning"))

# Gradient-like effect using different fill patterns
var px = 37
var pidx = 0
while pidx < 4:
  fillBox(0, px, 13, 5, 3, fillPatterns[pidx], getStyle("info"))
  px = px + 6
  pidx = pidx + 1
drawLabel(0, 37, 12, "Density Gradient:", getStyle("dim"))

# ===================================================================
# Animated Circles
# ===================================================================
drawPanel(0, 35, 18, 30, 10, "Animated Shapes", "rounded")

let cx1 = int(circle1X)
let cy1 = int(circle1Y)

drawLabel(0, cx1, cy1 - 2, "▀", getStyle("danger"))
drawLabel(0, cx1 - 1, cy1 - 1, "▄█▀", getStyle("danger"))
drawLabel(0, cx1 - 1, cy1, "█●█", getStyle("danger"))
drawLabel(0, cx1 - 1, cy1 + 1, "▀█▄", getStyle("danger"))
drawLabel(0, cx1, cy1 + 2, "▄", getStyle("danger"))

let cx2 = int(circle2X)
let cy2 = int(circle2Y)

drawLabel(0, cx2, cy2 - 2, "▀", getStyle("success"))
drawLabel(0, cx2 - 1, cy2 - 1, "▄█▀", getStyle("success"))
drawLabel(0, cx2 - 1, cy2, "█●█", getStyle("success"))
drawLabel(0, cx2 - 1, cy2 + 1, "▀█▄", getStyle("success"))
drawLabel(0, cx2, cy2 + 2, "▄", getStyle("success"))

drawLabel(0, 37, 26, "Red: " & str(cx1) & "," & str(cy1), getStyle("danger"))
drawLabel(0, 54, 26, "Grn: " & str(cx2) & "," & str(cy2), getStyle("success"))

# ===================================================================
# Drawing Primitives
# ===================================================================
drawPanel(0, 68, 5, 30, 23, "Drawing Primitives", "single")

# Horizontal line
var hx = 70
while hx < 96:
  drawLabel(0, hx, 8, "─", getStyle("info"))
  hx = hx + 1
drawLabel(0, 70, 7, "Horizontal Line", getStyle("dim"))

# Vertical line
var vy = 10
while vy < 20:
  drawLabel(0, 70, vy, "│", getStyle("success"))
  vy = vy + 1
drawLabel(0, 72, 10, "Vertical", getStyle("dim"))

# Diagonal patterns
var dx = 0
while dx < 8:
  drawLabel(0, 80 + dx, 10 + dx, "╱", getStyle("danger"))
  drawLabel(0, 88 + dx, 10 + dx, "╲", getStyle("warning"))
  dx = dx + 1
drawLabel(0, 82, 9, "Diagonals", getStyle("dim"))

# Small filled boxes with patterns
var bx = 70
var bpidx = 0
while bpidx < 4:
  fillBox(0, bx, 20, 4, 3, fillPatterns[bpidx + 4], getStyle("default"))
  drawBox(0, bx, 20, 4, 3, getStyle("border"), "single")
  bx = bx + 5
  bpidx = bpidx + 1
drawLabel(0, 70, 19, "Pattern Samples:", getStyle("dim"))

# API list
drawLabel(0, 70, 24, "APIs Used:", getStyle("info"))
drawLabel(0, 70, 25, "• drawPanel()", getStyle("dim"))
drawLabel(0, 70, 26, "• drawBox()", getStyle("dim"))

# ===================================================================
# Controls Panel
# ===================================================================
drawPanel(0, 2, 24, 30, 7, "Controls", "rounded")
drawLabel(0, 4, 26, "B: Change Box Style", getStyle("info"))
drawLabel(0, 4, 27, "F: Change Fill Pattern", getStyle("info"))
drawLabel(0, 4, 28, "Arrows: Move Red Circle", getStyle("info"))

# ===================================================================
# Stats Panel
# ===================================================================
drawPanel(0, 2, 32, 30, 8, "Statistics", "double")
drawLabel(0, 4, 34, "Frame: " & str(animFrame), getStyle("info"))
drawLabel(0, 4, 35, "Rotation: " & str(int(rotation)), getStyle("info"))
drawLabel(0, 4, 36, "Box Style: " & boxStyleNames[currentBoxStyle], getStyle("info"))
drawLabel(0, 4, 37, "Fill Pattern: " & fillPatterns[fillPattern], getStyle("info"))

# ===================================================================
# API Reference
# ===================================================================
drawPanel(0, 35, 29, 63, 11, "Available Drawing APIs", "single")
drawLabel(0, 37, 31, "• fillBox(layer, x, y, w, h, char, style)", getStyle("dim"))
drawLabel(0, 37, 32, "• drawBox(layer, x, y, w, h, style, borderType)", getStyle("dim"))
drawLabel(0, 37, 33, "• drawPanel(layer, x, y, w, h, title, borderType)", getStyle("dim"))
drawLabel(0, 37, 34, "• drawLabel(layer, x, y, text, style)", getStyle("dim"))
drawLabel(0, 37, 35, "• getStyle(name) - Get themed color style", getStyle("dim"))
drawLabel(0, 37, 36, "• clear() - Clear the display buffer", getStyle("dim"))
drawLabel(0, 37, 37, "• getWidth() / getHeight() - Get dimensions", getStyle("dim"))

# Footer message bar
fillBox(0, 0, h - 2, w, 2, " ", getStyle("default"))
drawLabel(0, 2, h - 1, message, getStyle("warning"))
```

```nim on:update
# ===================================================================
# Animation Update
# ===================================================================
animFrame = animFrame + 1
rotation = rotation + 2.0
if rotation >= 360.0:
  rotation = 0.0

# Update circle 1 position
circle1X = circle1X + circle1DirX
circle1Y = circle1Y + circle1DirY

# Bounce off boundaries (within the animated shapes panel)
if circle1X < 37.0 or circle1X > 62.0:
  circle1DirX = -circle1DirX
if circle1Y < 20.0 or circle1Y > 26.0:
  circle1DirY = -circle1DirY

# Update circle 2 position
circle2X = circle2X + circle2DirX
circle2Y = circle2Y + circle2DirY

# Bounce off boundaries
if circle2X < 37.0 or circle2X > 62.0:
  circle2DirX = -circle2DirX
if circle2Y < 20.0 or circle2Y > 26.0:
  circle2DirY = -circle2DirY
```

```nim on:input
# ===================================================================
# Input Handling
# ===================================================================
if event.type == "key":
  let keyCode = event.keyCode
  
  # B - Change box style
  if keyCode == 98 or keyCode == 66:  # 'b' or 'B'
    currentBoxStyle = (currentBoxStyle + 1) mod len(boxStyles)
    message = "Box style: " & boxStyleNames[currentBoxStyle]
    return true
  
  # F - Change fill pattern
  if keyCode == 102 or keyCode == 70:  # 'f' or 'F'
    fillPattern = (fillPattern + 1) mod len(fillPatterns)
    message = "Fill pattern: " & fillPatterns[fillPattern]
    return true
  
  # Arrow keys - Manual control of circle 1
  if keyCode == 1000:  # Up
    circle1Y = circle1Y - 1.0
    if circle1Y < 20.0:
      circle1Y = 20.0
    message = "Red circle moved up"
    return true
  elif keyCode == 1001:  # Down
    circle1Y = circle1Y + 1.0
    if circle1Y > 26.0:
      circle1Y = 26.0
    message = "Red circle moved down"
    return true
  elif keyCode == 1002:  # Left
    circle1X = circle1X - 1.0
    if circle1X < 37.0:
      circle1X = 37.0
    message = "Red circle moved left"
    return true
  elif keyCode == 1003:  # Right
    circle1X = circle1X + 1.0
    if circle1X > 62.0:
      circle1X = 62.0
    message = "Red circle moved right"
    return true
  
  return false

elif event.type == "mouse":
  # Click to move circle 1
  if event.action == "press":
    let mx = event.x
    let my = event.y
    
    # If clicked in the animated shapes panel
    if mx >= 37 and mx < 63 and my >= 20 and my < 27:
      circle1X = float(mx)
      circle1Y = float(my)
      message = "Red circle teleported to click position"
      return true
  
  return false

return false
```

## Features Demonstrated

### Drawing APIs
- `fillBox()` - Fill rectangular areas with any character pattern
- `drawBox()` - Draw boxes with various border styles  
- `drawPanel()` - Draw titled panels with borders
- `drawLabel()` - Draw text and single characters at any position
- `getStyle()` - Get themed color styles (primary, success, danger, info, warning, dim, etc.)
- `clear()` - Clear the display buffer
- `getWidth()` / `getHeight()` - Get terminal dimensions

### Box Styles
- **Single line** (`single`) - ┌─┐│└┘
- **Double line** (`double`) - ╔═╗║╚╝
- **Rounded** (`rounded`) - ╭─╮│╰╯  
- **Bold** (`bold`) - Thicker lines
- **ASCII** (`ascii`) - +-+|| (fallback)

### Fill Patterns
Multiple density levels and shapes: █ ▓ ▒ ░ ■ ● ◆ ▪

### Interactive Controls
- **B**: Cycle through box styles
- **F**: Cycle through fill patterns
- **Arrow Keys**: Manually move the red circle
- **Mouse Click**: Teleport red circle to click position within the panel

All drawing happens on layer 0, with automatic theme-aware styling!
