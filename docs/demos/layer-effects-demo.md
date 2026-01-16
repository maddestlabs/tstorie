---
title: "Layer Effects Demo"
minWidth: 80
minHeight: 30
theme: "dracula"
---

# Layer Effects Demo

This demo showcases tstorie's layer effects system with automatic depth cueing and parallax scrolling.

**Controls:**
- **Arrow Keys**: Move camera
- **Space**: Toggle auto-depthing
- **1-4**: Toggle individual layers
- **R**: Reset camera
- **Q**: Quit

```nim on:init
# Create named layers with z-coordinates
addLayer("sky", -3)
addLayer("mountains", -2)
addLayer("trees", -1)
addLayer("player", 0)

# Camera position
var cameraX = 0.0
var cameraY = 0.0

# Layer visibility
var showSky = true
var showMountains = true
var showTrees = true
var showPlayer = true

# Auto-depthing toggle (start with it on to showcase the effect)
var autoDepthing = true
enableAutoDepthing(0.3, 1.0)

# Animation
var time = 0.0

echo "Layer effects demo initialized with named layers"
```

```nim on:update
# Advance animation time
time = time + 0.05
```

```nim on:render
clear("default")
clear("sky", true)
clear("mountains", true)
clear("trees", true)
clear("player", true)

let w = termWidth
let h = termHeight

# Safety check for minimum dimensions
if w < 10 or h < 10:
  drawLabel("default", 2, 2, "Terminal too small!", getStyle("error"))
  return

# Apply parallax offsets to create depth effect
setLayerOffset("sky", int(cameraX * 0.1), int(cameraY * 0.1))
setLayerOffset("mountains", int(cameraX * 0.3), int(cameraY * 0.2))
setLayerOffset("trees", int(cameraX * 0.6), int(cameraY * 0.4))
setLayerOffset("player", int(cameraX), int(cameraY))

# HUD on default layer (always on top, no offset)
fillBox("default", 0, 0, w, 3, "═", getStyle("primary"))
drawLabel("default", w div 2 - 15, 1, "LAYER EFFECTS DEMO", getStyle("warning"))

# Sky layer (z=-3, darkest with auto-depthing)
if showSky:
  # Stars
  let halfH = h div 2
  for i in 0..20:
    let x = (i * 17) mod w
    let y = (i * 13) mod halfH
    drawLabel("sky", x, y, "*", getStyle("warning"))

  
  # Moon
  drawLabel("sky", w - 15, 3, "O", getStyle("info"))

# Mountains layer (z=-2)
if showMountains:
  # Mountain silhouettes
  for x in 0..w-1:
    let mountain1 = int(sin(float(x) * 0.1) * 5.0 + 15.0)
    let mountain2 = int(sin(float(x) * 0.15 + 2.0) * 4.0 + 18.0)
    let peak = max(mountain1, mountain2)
    
    for y in peak..h-1:
      drawLabel("mountains", x, y, "▓", getStyle("primary"))

# Trees layer (z=-1, closer)
if showTrees:
  # Animated swaying trees
  for i in 0..8:
    let baseX = i * 10 + 5
    let sway = int(sin(time * 2.0 + float(i)) * 2.0)
    let treeX = baseX + sway
    let treeY = h - 8
    
    # Tree trunk
    drawLabel("trees", treeX, treeY, "|", getStyle("warning"))
    drawLabel("trees", treeX, treeY + 1, "|", getStyle("warning"))
    
    # Tree foliage
    drawLabel("trees", treeX - 1, treeY - 1, "#", getStyle("success"))
    drawLabel("trees", treeX, treeY - 1, "#", getStyle("success"))
    drawLabel("trees", treeX + 1, treeY - 1, "#", getStyle("success"))
    drawLabel("trees", treeX, treeY - 2, "#", getStyle("success"))

# Player layer (z=0, foreground - full brightness)
if showPlayer:
  # Ground
  for x in 0..w-1:
    drawLabel("player", x, h - 3, "=", getStyle("dim"))
  
  # Player character (centered)
  let playerX = w div 2
  let playerY = h - 5
  let bounce = int(sin(time * 4.0) * 1.0)
  
  drawLabel("player", playerX, playerY + bounce, "@", getStyle("error"))
  
  # Shadow
  drawLabel("player", playerX, playerY + 1, ".", getStyle("dim"))

# Status bar
var status = "Auto-Depth: "
if autoDepthing:
  status = status & "ON (0.3-1.0)"
else:
  status = status & "OFF"
status = status & " | Layers: "
if showSky:
  status = status & "S"
else:
  status = status & "_"
if showMountains:
  status = status & "M"
else:
  status = status & "_"
if showTrees:
  status = status & "T"
else:
  status = status & "_"
if showPlayer:
  status = status & "P"
else:
  status = status & "_"
status = status & " | Cam: " & $int(cameraX) & "," & $int(cameraY)
drawLabel("default", 2, h - 1, status, getStyle("info"))

# Instructions
let controls = "←→↑↓:Move | Space:Toggle Depth | 1-4:Toggle Layers | R:Reset | Q:Quit"
drawLabel("default", w - controls.len - 2, h - 1, controls, getStyle("dim"))
```

```nim on:input
# Only handle key press events
if event.type != "key" or event.action != "press":
  return false

# Camera movement
if event.keyCode == 37:  # Left arrow
  cameraX -= 5.0
  return true
elif event.keyCode == 39:  # Right arrow
  cameraX += 5.0
  return true
elif event.keyCode == 38:  # Up arrow
  cameraY -= 3.0
  return true
elif event.keyCode == 40:  # Down arrow
  cameraY += 3.0
  return true

# Reset camera
if event.keyCode == 82 or event.keyCode == 114:  # 'R' or 'r'
  cameraX = 0.0
  cameraY = 0.0
  return true

# Toggle auto-depthing
if event.keyCode == 32:  # Space
  autoDepthing = not autoDepthing
  if autoDepthing:
    enableAutoDepthing(0.3, 1.0)
    echo "Auto-depthing: ON (0.3-1.0)"
  else:
    disableAutoDepthing()
    echo "Auto-depthing: OFF"
  return true

# Toggle layers
if event.keyCode == 49:  # '1' - Sky
  showSky = not showSky
  return true
elif event.keyCode == 50:  # '2' - Mountains
  showMountains = not showMountains
  return true
elif event.keyCode == 51:  # '3' - Trees
  showTrees = not showTrees
  return true
elif event.keyCode == 52:  # '4' - Player
  showPlayer = not showPlayer
  return true

# Quit
if event.keyCode == 81 or event.keyCode == 113:  # 'Q' or 'q'
  quit()

return false
```

## How It Works

### String-Based Layer API
This demo showcases the new string-based layer API:

```nim
# Create named layers
addLayer("sky", -3)
addLayer("mountains", -2)
addLayer("trees", -1)
addLayer("player", 0)

# Draw using layer names (no more index guessing!)
drawLabel("sky", x, y, "*", style)
fillBox("mountains", x, y, w, h, "▓", style)
setLayerOffset("trees", offsetX, offsetY)
```

Much clearer than numeric indices!

### Auto-Depth Cueing
When `enableAutoDepthing(0.3, 1.0)` is called, tstorie automatically calculates brightness for each layer based on its z-coordinate:

- **Sky (z=-3)**: 30% brightness (very dark, atmospheric distance)
- **Mountains (z=-2)**: ~50% brightness (medium distance)
- **Trees (z=-1)**: ~75% brightness (close)
- **Player (z=0)**: 100% brightness (foreground, full detail)

This creates instant depth perception without manual tuning!

### Parallax Scrolling
Each layer moves at a different speed relative to the camera:

- **Sky**: 10% speed (barely moves)
- **Mountains**: 30% speed (slow)
- **Trees**: 60% speed (faster)
- **Player**: 100% speed (moves with camera)

This amplifies the depth effect created by the auto-depthing.

### Plugin Awareness
The demo calls `setLayerDisplacement()` for a wavy effect. If the `terminal_shaders` plugin isn't available, this call is silently ignored. The demo still works perfectly in minimal builds!

## Try It Yourself

1. **Move the camera** - Notice how layers scroll at different speeds
2. **Toggle auto-depthing** - See the dramatic difference in depth perception
3. **Toggle individual layers** - Understand how z-order works
4. **Compare**: Run this in a full build vs minimal build

The magic is that **ONE LINE** (`enableAutoDepthing`) gives you professional-looking depth effects!
