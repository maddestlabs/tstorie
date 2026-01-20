---
title: "Layer Compositing Tutorial"
minWidth: 60
minHeight: 18
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

# Create named layers with explicit z-order
addLayer("background", 1)  # z=1, drawn after default layer
addLayer("middle", 2)      # z=2, drawn after background
addLayer("overlay", 3)     # z=3, drawn on top of all

# Layer visibility toggles
var showBackground = true
var showMiddle = true
var showOverlay = true

# Animation
var time = 0.0

var message = "Space: Toggle layers | Watch the animated overlay on 'overlay' layer"
```

```nim on:render
# ===================================================================
# Render
# ===================================================================
clear(0)

let w = termWidth
let h = termHeight

# Title
fillBox("default", 0, 0, w, 3, "═", getStyle("primary"))
drawLabel("default", w div 2 - 15, 1, "LAYER COMPOSITING TUTORIAL", getStyle("warning"))

# Instructions panel
drawPanel("default", 2, 5, 40, 25, "How Layers Work", "double")

drawLabel("default", 4, 7, "Layers composite by z-order:", getStyle("info"))
drawLabel("default", 4, 8, "• Lower z = drawn first (back)", getStyle("dim"))
drawLabel("default", 4, 9, "• Higher z = drawn last (front)", getStyle("dim"))

drawLabel("default", 4, 11, "This demo has 4 layers:", getStyle("success"))
drawLabel("default", 4, 13, "'default' (z=0):", getStyle("dim"))
drawLabel("default", 6, 14, "UI and instructions", getStyle("dim"))
drawLabel("default", 4, 16, "'background' (z=1):", getStyle("dim"))
drawLabel("default", 6, 17, "Background grid pattern", getStyle("dim"))
drawLabel("default", 4, 19, "'middle' (z=2):", getStyle("dim"))
drawLabel("default", 6, 20, "Static content boxes", getStyle("dim"))
drawLabel("default", 4, 22, "'overlay' (z=3):", getStyle("dim"))
drawLabel("default", 6, 23, "Animated foreground text", getStyle("dim"))

drawLabel("default", 4, 25, "Layer Count: " & str(getLayerCount()), getStyle("info"))

# Controls
drawLabel("default", 4, 27, "Space: Toggle layers", getStyle("warning"))
drawLabel("default", 4, 28, "1-3: Toggle individual layers", getStyle("warning"))

# ===================================================================
# BACKGROUND LAYER - (z=1, drawn FIRST after default)
# ===================================================================
if showBackground:
  # Clear layer with transparent background
  clear("background", true)
  
  # Draw a grid pattern
  var gx = 44
  while gx < 88:
    var gy = 5
    while gy < 30:
      if gx mod 4 == 0 and gy mod 2 == 0:
        drawLabel("background", gx, gy, "·", getStyle("dim"))
      gy = gy + 1
    gx = gx + 1
  
  # Border for the demo area
  drawBox("background", 44, 5, 44, 25, getStyle("border"), "single")
  drawLabel("background", 46, 5, "[ background layer ]", getStyle("dim"))

# ===================================================================
# MIDDLE LAYER - (z=2, drawn SECOND)
# ===================================================================
if showMiddle:
  # Clear layer with transparent background
  clear("middle", true)
  
  # Draw static content boxes
  fillBox("middle", 50, 8, 15, 5, "▒", getStyle("info"))
  drawBox("middle", 50, 8, 15, 5, getStyle("border"), "double")
  drawLabel("middle", 52, 10, "Static Box 1", getStyle("text"))
  
  fillBox("middle", 68, 15, 15, 5, "░", getStyle("success"))
  drawBox("middle", 68, 15, 15, 5, getStyle("border"), "rounded")
  drawLabel("middle", 70, 17, "Static Box 2", getStyle("text"))

# ===================================================================
# OVERLAY LAYER - (z=3, drawn THIRD on top of all)
# ===================================================================
if showOverlay:
  # Clear layer with transparent background
  clear("overlay", true)
  
  # Animated box that moves and changes size
  var centerX = 66
  var centerY = 15
  var boxWidth = 10 + int(sin(time * 2.0) * 3.0)
  var boxHeight = 6 + int(cos(time * 2.0) * 2.0)
  
  var boxX = centerX - int(boxWidth / 2)
  var boxY = centerY - int(boxHeight / 2)
  
  # Draw with bold border and solid fill
  fillBox("overlay", boxX, boxY, boxWidth, boxHeight, "█", getStyle("warning"))
  drawBox("overlay", boxX, boxY, boxWidth, boxHeight, getStyle("border"), "bold")
  drawLabel("overlay", boxX + 2, boxY + 2, "Overlay", getStyle("text"))
  drawLabel("overlay", boxX + 2, boxY + 3, "on top!", getStyle("dim"))

# ===================================================================
# Layer Status (on default layer)
# ===================================================================
drawPanel("default", 2, 31, 86, 3, "Layer Status", "single")
drawLabel("default", 4, 32, if showBackground: "[✓] background (z=1)" else: "[ ] background (z=1)", 
         if showBackground: getStyle("success") else: getStyle("dim"))
drawLabel("default", 30, 32, if showMiddle: "[✓] middle (z=2)" else: "[ ] middle (z=2)", 
         if showMiddle: getStyle("success") else: getStyle("dim"))
drawLabel("default", 56, 32, if showOverlay: "[✓] overlay (z=3)" else: "[ ] overlay (z=3)", 
         if showOverlay: getStyle("success") else: getStyle("dim"))

# Footer
fillBox("default", 0, h - 2, w, 2, " ", getStyle("default"))
drawLabel("default", 2, h - 1, message, getStyle("warning"))
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
      message = "'overlay' hidden - see static middle layer content"
    elif showBackground and showMiddle and not showOverlay:
      showMiddle = false
      message = "'middle' hidden - only background visible now"
    elif showBackground and not showMiddle and not showOverlay:
      showBackground = false
      message = "All layers hidden - only UI remains"
    else:
      showBackground = true
      showMiddle = true
      showOverlay = true
      message = "All layers visible - watch layer compositing in action!"
    return true
  
  # Number keys - Toggle individual layers
  if keyCode == 49:  # '1'
    showBackground = not showBackground
    message = "'background' layer: " & (if showBackground: "ON" else: "OFF")
    return true
  elif keyCode == 50:  # '2'
    showMiddle = not showMiddle
    message = "'middle' layer: " & (if showMiddle: "ON" else: "OFF")
    return true
  elif keyCode == 51:  # '3'
    showOverlay = not showOverlay
    message = "'overlay' layer: " & (if showOverlay: "ON" else: "OFF")
    return true
  
  return false

return false
```

## Key Concepts

### String-Based Layer API (Recommended)
**Use named layers for clarity and maintainability!**

```nim
# Create layers with explicit names and z-order
addLayer("background", 1)
addLayer("middle", 2)
addLayer("overlay", 3)

# Draw using layer names (no more guessing what layer 1 or 2 means!)
drawLabel("background", x, y, "text", style)
fillBox("overlay", x, y, w, h, "█", style)

# The default layer always exists
drawLabel("default", x, y, "UI", style)
```

### Legacy Numeric API (Still Supported)
You can still use numeric indices for backwards compatibility:

```nim
# Draws to layer by index - auto-creates with z=index
drawLabel(1, x, y, "text", style)  # Creates layer with z=1
fillBox(2, x, y, w, h, "█", style) # Creates layer with z=2
```

However, **string names are clearer** than remembering what layer 1, 2, or 3 represent!

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

### Layer Management Functions

```nim
# Create layers with names and custom z-order
addLayer("myLayer", 15)         # z=15, very high
addLayer("hud", 100)            # z=100, always on top

# Layer management
removeLayer("myLayer")          # Delete a layer
setLayerVisible("myLayer", false)  # Hide without deleting
getLayerCount()                  # Get total number of layers
```

### Drawing to Layers
All drawing functions accept a layer parameter (string name or int index):
- `drawLabel("layer", x, y, text, style)`
- `fillBox("layer", x, y, w, h, char, style)`
- `drawBox("layer", x, y, w, h, style, borderType)`
- `drawPanel("layer", x, y, w, h, title, borderType)`
- `clear("layer", transparent)`

**Tip:** Use string names for all layer operations to make your code self-documenting!

Press **Space** to see how layers composite!
