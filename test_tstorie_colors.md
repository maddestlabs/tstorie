---
title: "Direct Color Test"
---

# Test

```nim on:render
bgClear()

# Create a style with explicit RGB red
var redStyle = defaultStyle()
redStyle.fg.r = 255
redStyle.fg.g = 0
redStyle.fg.b = 0

bgWriteText(10, 5, "RED TEXT", redStyle)

# Try yellow too
var yellowStyle = defaultStyle()
yellowStyle.fg = yellow()
bgWriteText(10, 7, "YELLOW TEXT", yellowStyle)

# And white for comparison
bgWriteText(10, 9, "WHITE TEXT", defaultStyle())
```
