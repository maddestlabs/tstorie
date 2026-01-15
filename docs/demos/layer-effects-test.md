---
title: Layer Effects System Test
minWidth: 100
minHeight: 35
theme: dracula
---

# Layer Effects System Test

Comprehensive test of the layer effects plugin.

```nim on:init
# Test 1: Create layers at different depths
addLayer("background", -3)
addLayer("mid1", -2)  
addLayer("mid2", -1)
addLayer("foreground", 0)

# Test 2: Enable auto-depthing
enableAutoDepthing(0.3, 1.0)
echo "Auto-depthing enabled"

# Test 3: Set manual offsets for parallax
setLayerOffset("mid1", 0, 0)
setLayerOffset("mid2", 0, 0)

# Test 4: Add content to layers (simple patterns)
# Background - filled with dots
for y in 0..34:
  for x in 0..99:
    draw("background", x, y, '.', rgb(50, 50, 150))

# Mid1 - horizontal lines
for i in 0..9:
  let x = 10 + i * 8
  draw("mid1", x, 10, 'M', rgb(100, 200, 100))
  draw("mid1", x + 1, 10, '1', rgb(100, 200, 100))

# Mid2 - more horizontal lines
for i in 0..14:
  let x = 5 + i * 6
  draw("mid2", x, 15, 'M', rgb(200, 150, 100))
  draw("mid2", x + 1, 15, '2', rgb(200, 150, 100))

# Foreground - title text
draw("foreground", 35, 20, 'F', rgb(255, 255, 255))
draw("foreground", 36, 20, 'G', rgb(255, 255, 255))

echo "Layers initialized with content"

# Test animation variables
var scrollX = 0.0
var time = 0.0
```

```nim on:update
time = time + deltaTime

# Parallax scrolling - layers move at different speeds based on depth
scrollX = sin(time * 0.5) * 30.0

# Background moves slowest (depth -3)
setLayerOffset("background", int(scrollX * 0.2), 0)

# Mid layers move at medium speeds
setLayerOffset("mid1", int(scrollX * 0.5), 0)
setLayerOffset("mid2", int(scrollX * 0.7), 0)
```

```nim on:render
# Info panel - draw directly to foreground layer
draw("foreground", 2, 0, 'L', rgb(255, 255, 255))
draw("foreground", 3, 0, 'a', rgb(255, 255, 255))
draw("foreground", 4, 0, 'y', rgb(255, 255, 255))
draw("foreground", 5, 0, 'e', rgb(255, 255, 255))
draw("foreground", 6, 0, 'r', rgb(255, 255, 255))

draw("foreground", 2, 2, 'T', rgb(255, 255, 255))
draw("foreground", 3, 2, 'e', rgb(255, 255, 255))
draw("foreground", 4, 2, 's', rgb(255, 255, 255))
draw("foreground", 5, 2, 't', rgb(255, 255, 255))

# Show time counter
let timeStr = $int(time)
draw("foreground", 2, 4, timeStr[0], rgb(255, 255, 0))
```
