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
# Camera position
var cameraX = 0.0
var cameraY = 0.0

# Layer visibility
var showLayer1 = true
var showLayer2 = true
var showLayer3 = true
var showLayer4 = true

# Auto-depthing toggle
var autoDepthing = false  # Start disabled

# Animation
var time = 0.0

# Disable layer effects plugin to test basic rendering
disableLayerFx()

echo "Basic layer test (effects disabled)"
```

```nim on:update
# Advance animation time
time = time + 0.05
```

```nim on:render
clear(0)

let w = termWidth
let h = termHeight

# Safety check for minimum dimensions
if w < 10 or h < 10:
  drawLabel(0, 2, 2, "Terminal too small!", getStyle("error"))
  return

# Draw directly to layer 0 first
fillBox(0, 0, 0, w, 3, "═", getStyle("primary"))
drawLabel(0, w div 2 - 15, 1, "LAYER EFFECTS DEMO", getStyle("warning"))
drawLabel(0, 2, 3, "w=" & $w & " h=" & $h, getStyle("dim"))

# Draw to each layer using simple indices (layers auto-create with z=index)

# Layer 1: Sky (background)
if showLayer1:
  clear(1, true)
  drawLabel(1, 5, 5, "LAYER 1: SKY", getStyle("error"))
  
  # Stars
  let halfH = h div 2
  for i in 0..15:
    let x = (i * 17) mod w
    let y = (i * 13) mod halfH
    draw(1, x, y, "*", getStyle("warning"))

  
  # Moon
  draw(1, w - 15, 3, "O", getStyle("info"))

# Layer 2: Mountains
if showLayer2:
  clear(2, true)
  
  # Mountain silhouettes
  for x in 0..w-1:
    let mountain1 = int(sin(float(x) * 0.1) * 5.0 + 15.0)
    let mountain2 = int(sin(float(x) * 0.15 + 2.0) * 4.0 + 18.0)
    let peak = max(mountain1, mountain2)
    
    for y in peak..h-1:
      draw(2, x, y, "▓", getStyle("primary"))

# Layer 3: Trees
if showLayer3:
  clear(3, true)
  
  # Animated swaying trees
  for i in 0..8:
    let baseX = i * 10 + 5
    let sway = int(sin(time * 2.0 + float(i)) * 2.0)
    let treeX = baseX + sway
    let treeY = h - 8
    
    # Tree trunk
    draw(3, treeX, treeY, "|", getStyle("warning"))
    draw(3, treeX, treeY + 1, "|", getStyle("warning"))
    
    # Tree foliage
    draw(3, treeX - 1, treeY - 1, "#", getStyle("success"))
    draw(3, treeX, treeY - 1, "#", getStyle("success"))
    draw(3, treeX + 1, treeY - 1, "#", getStyle("success"))
    draw(3, treeX, treeY - 2, "#", getStyle("success"))

# Layer 4: Player/Ground
if showLayer4:
  clear(4, true)
  
  # Ground
  for x in 0..w-1:
    draw(4, x, h - 3, "=", getStyle("dim"))
  
  # Player character (centered)
  let playerX = w div 2
  let playerY = h - 5
  let bounce = int(sin(time * 4.0) * 1.0)
  
  draw(4, playerX, playerY + bounce, "@", getStyle("error"))
  
  # Shadow
  draw(4, playerX, playerY + 1, ".", getStyle("dim"))

# HUD (on default layer 0, always on top)
fillBox(0, 0, 0, w, 1, " ", getStyle("primary"))
let title = "LAYER EFFECTS DEMO - Camera: " & $int(cameraX) & "," & $int(cameraY)
drawLabel(0, 2, 0, title, getStyle("warning"))

# Status
var status = "Auto-Depth: "
if autoDepthing:
  status = status & "ON"
else:
  status = status & "OFF"
status = status & " | Layers: "
if showLayer1:
  status = status & "1"
else:
  status = status & " "
if showLayer2:
  status = status & "2"
else:
  status = status & " "
if showLayer3:
  status = status & "3"
else:
  status = status & " "
if showLayer4:
  status = status & "4"
else:
  status = status & " "
drawLabel(0, 2, h - 1, status, getStyle("info"))

# Instructions
let controls = "←→↑↓:Move | Space:Toggle Depth | 1-4:Toggle Layers | R:Reset | Q:Quit"
drawLabel(0, w - controls.len - 2, h - 1, controls, getStyle("dim"))
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
    echo "Auto-depthing: ON"
  else:
    echo "Auto-depthing: OFF"
  return true

# Toggle layers
if event.keyCode == 49:  # '1'
  showLayer1 = not showLayer1
  return true
elif event.keyCode == 50:  # '2'
  showLayer2 = not showLayer2
  return true
elif event.keyCode == 51:  # '3'
  showLayer3 = not showLayer3
  return true
elif event.keyCode == 52:  # '4'
  showLayer4 = not showLayer4
  return true

# Quit
if event.keyCode == 81 or event.keyCode == 113:  # 'Q' or 'q'
  quit()

return false
```

## How It Works

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
