---
title: "Border Example"
author: "Example"
minWidth: 50
minHeight: 14
theme: "futurism"
---

```nim on:init
initCanvas(1)
```

```nim on:render
clear()
canvasRender()

# Get the current section's screen coordinates and dimensions
var metrics = getSectionMetrics()

# Draw a border around the content area
var borderStyle = defaultStyle()
borderStyle.fg = rgb(255, 0, 255)  # Magenta border
borderStyle.bold = true

# Draw top border
var x = metrics.x
while x < metrics.x + metrics.width:
  draw(0, x, metrics.y, "═", borderStyle)
  x = x + 1

# Draw bottom border
x = metrics.x
while x < metrics.x + metrics.width:
  draw(0, x, metrics.y + metrics.height - 1, "═", borderStyle)
  x = x + 1

# Draw left border
var y = metrics.y
while y < metrics.y + metrics.height:
  draw(0, metrics.x, y, "║", borderStyle)
  y = y + 1

# Draw right border
y = metrics.y
while y < metrics.y + metrics.height:
  draw(0, metrics.x + metrics.width - 1, y, "║", borderStyle)
  y = y + 1

# Draw corners
draw(0, metrics.x, metrics.y, "╔", borderStyle)
draw(0, metrics.x + metrics.width - 1, metrics.y, "╗", borderStyle)
draw(0, metrics.x, metrics.y + metrics.height - 1, "╚", borderStyle)
draw(0, metrics.x + metrics.width - 1, metrics.y + metrics.height - 1, "╝", borderStyle)
```

# Welcome
⠀
This is a simple example showing how to use `getSectionMetrics()` to draw a border around the current section.
⠀
The border adjusts automatically based on the section's position and size.
⠀
- [Next section](#features)

# Features
⠀
The `getSectionMetrics()` function returns:
⠀
- **x, y**: Screen coordinates (after camera transform)
- **width, height**: Actual rendered content dimensions
- **worldX, worldY**: World coordinates (before camera transform)
⠀
This makes it easy to draw UI elements that follow the section boundaries.
⠀
- [Go back](#welcome)
