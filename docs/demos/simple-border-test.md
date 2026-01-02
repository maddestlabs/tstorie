---
title: "Border Test"
minWidth: 40
minHeight: 10
theme: "default"
---

```nim on:init
initCanvas(1)
```

```nim on:render
clear()
canvasRender()

# Get metrics
var m = getSectionMetrics()

# Draw simple border
var s = defaultStyle()
s.fg = rgb(255, 100, 200)

# Top
var x = m.x
while x < m.x + m.width:
  draw(0, x, m.y, "-", s)
  x = x + 1

# Bottom
x = m.x
while x < m.x + m.width:
  draw(0, x, m.y + m.height - 1, "-", s)
  x = x + 1

# Left & Right
var y = m.y
while y < m.y + m.height:
  draw(0, m.x, y, "|", s)
  draw(0, m.x + m.width - 1, y, "|", s)
  y = y + 1
```

# Test Section

This tests the getSectionMetrics() function.

You should see a border around this content!

- [Next](#another)

# Another

Another section with a border.

This confirms it works across sections.

- [Back](#test-section)
