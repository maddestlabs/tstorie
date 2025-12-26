---
title: "Canvas Effects Demo"
author: "Maddest Labs"
minWidth: 60
minHeight: 15
theme: "nord"
---

```nim on:init
# Canvas-based Presentation System using Nimini
# Navigate with arrow keys: Left/Right for main topics, Up/Down for subtopics

var width = getTermWidth()
var height = getTermHeight()
var fx = "rain"

print "Presentation initialized"

# Initialize canvas in presentation mode
# Second parameter = starting section (1 for first real section)
# Third parameter = presentation mode (true)
nimini_initCanvas(1, true)
```

```nim on:input
# Handle keyboard and mouse input for canvas navigation

if event.type == "key":
  if event.action == "press":
    # Pass key events to canvas system
    var handled = nimini_canvasHandleKey(event.keyCode, 0)
    if handled:
      return true
  return false

elif event.type == "mouse":
  if event.action == "press":
    # Pass mouse events to canvas system (only on press, not release)
    var handled = nimini_canvasHandleMouse(event.x, event.y, event.button, true)
    if handled:
      return true
  return false

return false
```

```nim on:render
bgClear()
fgClear()

nimini_canvasRender()
```

```nim on:update
nimini_canvasUpdate()
```

# Rain

Simple rain effect.

```nim on:enter
fx = "rain"
```

```
# Draw rain particles ('.') falling from the top
const rainCount = 80
var rainY: array[rainCount, float]
var rainX: array[rainCount, int]

# Initialize positions
for i in 0..<rainCount:
  rainX[i] = rand(width-1)
  rainY[i] = rand(height-1).float

proc drawRain() =
  for i in 0..<rainCount:
    drawText(rainX[i], int(rainY[i]), ".")
    rainY[i] += 0.7 + rand(3) * 0.1
    if rainY[i] > height:
      rainY[i] = 0
      rainX[i] = rand(width-1)

drawRain()
```

# Snow

Just a bit of light snow.

```nim on:enter
fx = "snow"
```

```
# Draw snow particles ('*') falling and drifting
const snowCount = 60
var snowY: array[snowCount, float]
var snowX: array[snowCount, float]

# Initialize positions
for i in 0..<snowCount:
  snowX[i] = rand(width-1).float
  snowY[i] = rand(height-1).float

proc drawSnow() =
  for i in 0..<snowCount:
    drawText(int(snowX[i]), int(snowY[i]), "*")
    snowY[i] += 0.3 + rand(2) * 0.1
    snowX[i] += (rand(3)-1) * 0.2
    if snowY[i] > height:
      snowY[i] = 0
      snowX[i] = rand(width-1).float
    if snowX[i] < 0: snowX[i] = 0
    if snowX[i] > width-1: snowX[i] = width-1

drawSnow()
```

# Fire

A Meager attempt at flames.

```
# Draw a simple flame effect using colored characters
const fireWidth = 40
const fireHeight = 12
var fire: array[fireWidth, array[fireHeight, int]]

# Initialize base
for x in 0..<fireWidth:
  fire[x][fireHeight-1] = 8 + rand(8)

proc drawFire() =
  # Propagate fire upward
  for y in countdown(fireHeight-2, 0):
    for x in 0..<fireWidth:
      var below = fire[x][y+1]
      var left = fire[(x-1+fireWidth) mod fireWidth][y+1]
      var right = fire[(x+1) mod fireWidth][y+1]
      fire[x][y] = (below + left + right) div 3
      fire[x][y] -= rand(3)
      if fire[x][y] < 0: fire[x][y] = 0
  # Draw fire
  for y in 0..<fireHeight:
    for x in 0..<fireWidth:
      let chars = [" ", ".", ",", ":", ";", "i", "I", "|", "*", "#", "@"]
      let cidx = min(fire[x][y] div 2, chars.len-1)
      drawText(x+20, y+8, chars[cidx])
  # Re-ignite base
  for x in 0..<fireWidth:
    fire[x][fireHeight-1] = 8 + rand(8)

drawFire()
```

```nim on:enter
fx = "fire"
```
