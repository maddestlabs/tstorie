---
title: "Layer Compositing Tutorial"
minWidth: 90
minHeight: 35
theme: "neotopia"
---

# Understanding Layers and Compositing

This tutorial demonstrates how the layer system works in TStorie. Layers allow you to organize your drawing into separate buffers that composite together.

```nim on:init
# ===================================================================
# Understanding Layer Z-Order
# ===================================================================
# Layers composite from LOW z-value to HIGH z-value
# - Lower z values are drawn FIRST (background)
# - Higher z values are drawn LAST (foreground)
#
# When you draw to a layer by index, it auto-creates with z = index
# Example: Drawing to layer 1 creates layer with z=1
#          Drawing to layer 2 creates layer with z=2
#          So layer 2 appears ON TOP of layer 1

# Layer visibility toggles
var showBackground = true
var showMiddle = true
var showOverlay = true

# Animation
var time = 0.0

var message = "Space: Toggle layers | Watch the animated overlay on layer 3"
```

```nim on:render
# ===================================================================
# Render
# ===================================================================
clear(0)

let w = getWidth()
let h = getHeight()

# Title
fillBox(0, 0, 0, w, 3, "═", getStyle("primary"))
drawLabel(0, w div 2 - 15, 1, "LAYER COMPOSITING TUTORIAL", getStyle("warning"))

# Instructions panel
drawPanel(0, 2, 5, 40, 25, "How Layers Work", "double")

drawLabel(0, 4, 7, "Layers composite by z-order:", getStyle("info"))
drawLabel(0, 4, 8, "• Lower z = drawn first (back)", getStyle("dim"))
drawLabel(0, 4, 9, "• Higher z = drawn last (front)", getStyle("dim"))

drawLabel(0, 4, 11, "This demo has 4 layers:", getStyle("success"))
drawLabel(0, 4, 13, "Layer 0 (default):", getStyle("dim"))
drawLabel(0, 6, 14, "UI and instructions", getStyle("dim"))
drawLabel(0, 4, 16, "Layer 1: z=1", getStyle("dim"))
drawLabel(0, 6, 17, "Background grid (auto-created)", getStyle("dim"))
drawLabel(0, 4, 19, "Layer 2: z=2", getStyle("dim"))
drawLabel(0, 6, 20, "Middle content (auto-created)", getStyle("dim"))
drawLabel(0, 4, 22, "Layer 3: z=3", getStyle("dim"))
drawLabel(0, 6, 23, "Foreground text (auto-created)", getStyle("dim"))

drawLabel(0, 4, 25, "Layer Count: " & str(getLayerCount()), getStyle("info"))

# Controls
drawLabel(0, 4, 27, "Space: Toggle layers", getStyle("warning"))
drawLabel(0, 4, 28, "Arrows: Move box", getStyle("warning"))

# ===================================================================
# LAYER 1 - Background (z=1, drawn FIRST after layer 0)
# ===================================================================
if showBackground:
  # Clear layer with transparent background
  clear(1, true)
  
  # Draw a grid pattern
  var gx = 44
  while gx < 88:
    var gy = 5
    while gy < 30:
      if gx mod 4 == 0 and gy mod 2 == 0:
        drawLabel(1, gx, gy, "·", getStyle("dim"))
      gy = gy + 1
    gx = gx + 1
  
  # Border for the demo area
  drawBox(1, 44, 5, 44, 25, getStyle("border"), "single")
  drawLabel(1, 46, 5, "[ Layer 1: Background ]", getStyle("dim"))

# ===================================================================
# LAYER 2 - Middle Content (z=2, drawn SECOND)
# ===================================================================
if showMiddle:
  # Clear layer with transparent background
  clear(2, true)
  
  # Draw static content boxes
  fillBox(2, 50, 8, 15, 5, "▒", getStyle("info"))
  drawBox(2, 50, 8, 15, 5, getStyle("border"), "double")
  drawLabel(2, 52, 10, "Static Box 1", getStyle("text"))
  
  fillBox(2, 68, 15, 15, 5, "░", getStyle("success"))
  drawBox(2, 68, 15, 15, 5, getStyle("border"), "rounded")
  drawLabel(2, 70, 17, "Static Box 2", getStyle("text"))

# ===================================================================
# LAYER 3 - Animated Overlay (z=3, drawn THIRD on top of all)
# ===================================================================
if showOverlay:
  # Clear layer with transparent background
  clear(3, true)
  
  # Animated box that moves and changes size
  var centerX = 66
  var centerY = 15
  var boxWidth = 10 + int(sin(time * 2.0) * 3.0)
  var boxHeight = 6 + int(cos(time * 2.0) * 2.0)
  
  var boxX = centerX - int(boxWidth / 2)
  var boxY = centerY - int(boxHeight / 2)
  
  # Draw with bold border and solid fill
  fillBox(3, boxX, boxY, boxWidth, boxHeight, "█", getStyle("warning"))
  drawBox(3, boxX, boxY, boxWidth, boxHeight, getStyle("border"), "bold")
  drawLabel(3, boxX + 2, boxY + 2, "Overlay", getStyle("text"))
  drawLabel(3, boxX + 2, boxY + 3, "Layer 3", getStyle("dim"))

# ===================================================================
# Layer Status (on default layer 0)
# ===================================================================
drawPanel(0, 2, 31, 86, 3, "Layer Status", "single")
drawLabel(0, 4, 32, if showBackground: "[✓] Layer 1 (z=1)" else: "[ ] Layer 1 (z=1)", 
         if showBackground: getStyle("success") else: getStyle("dim"))
drawLabel(0, 30, 32, if showMiddle: "[✓] Layer 2 (z=2)" else: "[ ] Layer 2 (z=2)", 
         if showMiddle: getStyle("success") else: getStyle("dim"))
drawLabel(0, 56, 32, if showOverlay: "[✓] Layer 3 (z=3)" else: "[ ] Layer 3 (z=3)", 
         if showOverlay: getStyle("success") else: getStyle("dim"))

# Footer
fillBox(0, 0, h - 2, w, 2, " ", getStyle("default"))
drawLabel(0, 2, h - 1, message, getStyle("warning"))
```

```nim on:update
# Advance animation time
time = time + 0.05
```

```nim on:input
if event.type == "key":
  let keyCode = event.keyCode
  
  # Space - Cycle through layer visibility
  if keyCode == 32:
    if showBackground and showMiddle and showOverlay:
      showOverlay = false
      message = "Overlay hidden - see static middle layer content"
    elif showBackground and showMiddle and not showOverlay:
      showMiddle = false
      message = "Middle hidden - only background visible now"
    elif showBackground and not showMiddle and not showOverlay:
      showBackground = false
      message = "All layers hidden - only UI remains"
    else:
      showBackground = true
      showMiddle = true
      showOverlay = true
      message = "All layers visible - watch layer compositing in action!"
      message = "All layers visible again"
    return true
  
  # Number keys - Toggle individual layers
  if keyCode == 49:  # '1'
    showBackground = not showBackground
    message = "Layer 1 (background): " & (if showBackground: "ON" else: "OFF")
    return true
  elif keyCode == 50:  # '2'
    showMiddle = not showMiddle
    message = "Layer 2 (middle): " & (if showMiddle: "ON" else: "OFF")
    return true
  elif keyCode == 51:  # '3'
    showOverlay = not showOverlay
    message = "Layer 3 (overlay): " & (if showOverlay: "ON" else: "OFF")
    return true
  
  return false

return false
```

## Key Concepts

### Automatic Layer Creation
**Layers are automatically created when you draw to them!**

```nim
# Just draw to any layer index - it will be created automatically
drawLabel(1, x, y, "text", style)  # Creates layer 1 with z=1
fillBox(2, x, y, w, h, "█", style) # Creates layer 2 with z=2

# Layer 0 always exists and is the default layer
drawLabel(0, x, y, "UI", style)
```

When you draw to layer N, if it doesn't exist, it's automatically created with **z-order = N**. This means:
- Layer 1 gets z=1 (drawn after layer 0)
- Layer 2 gets z=2 (drawn after layer 1)
- Layer 3 gets z=3 (drawn after layer 2)

### Z-Order (Important!)
- **Lower z values = drawn FIRST (background)**
- **Higher z values = drawn LAST (foreground)**
- Example: z=0 → z=1 → z=2 means 0 is bottom, 2 is top

### Transparency
```nim
# Clear with transparent background (lets lower layers show through)
clear(layer, true)

# Clear with solid background (blocks lower layers)
clear(layer, false)
```

### Advanced Layer Control (Optional)
For more control, you can manually create layers with custom z-orders:

```nim
# Create a layer with specific ID and z-order
let layerId = addLayer("myLayer", 15)  # z=15, very high
drawLabel(layerId, x, y, "text", style)

# Layer management functions
removeLayer("myLayer")         # Delete a layer
setLayerVisible("myLayer", false)  # Hide without deleting
getLayerCount()                 # Get total number of layers
```

### Drawing to Layers
All drawing functions accept a layer parameter (int index or string ID):
- `drawLabel(layer, x, y, text, style)`
- `fillBox(layer, x, y, w, h, char, style)`
- `drawBox(layer, x, y, w, h, style, borderType)`
- `drawPanel(layer, x, y, w, h, title, borderType)`
- `clear(layer, transparent)`

Press **Space** to see how layers composite!
