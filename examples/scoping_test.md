# Scoping Test

This example demonstrates tstorie's scoping rules:
- Front matter variables are global
- Variables declared in `on:init` blocks are global
- Variables declared in `on:update` and `on:render` blocks are local
- Assignments without `var` update globals if they exist

---
targetFPS: 60
---

```nim on:init
# These variables are GLOBAL - accessible in all blocks
var counter = 0
var message = "Hello from global scope!"

# Note: Multi-line arrays might have parsing issues in nimini
# Using simple single value for now
var currentColorIndex = 0
```

```nim on:update
# This is LOCAL - only exists during this execution
var dt = 1.0 / 60.0
var increment = int(dt * 100.0)

# This UPDATES the global counter (no 'var' keyword)
counter = counter + 1

# This would create a LOCAL variable, not visible in render
var localTemp = counter * 2

# Test: this assignment updates global message
if counter mod 60 == 0:
  message = "Counter reached: " & $counter
```

```nim on:render
bgClear()
fgClear()

# Can read global variables
var style = defaultStyle()
style.fg = colors[0]
style.bold rgb(255, 0, 0)
style.bold = true

bgWriteText(5, 3, "Global Counter: " & $counter, style)

# Change color
style.fg = rgb(0, 255, 0)
bgWriteText(5, 5, message, style)

# Local variables in render
var localX = 5
var localY = 7

# Show different colors
var style1 = defaultStyle()
style1.fg = rgb(255, 0, 0)
bgWriteText(localX, localY, "Color 0 (red)", style1)

var style2 = defaultStyle()
style2.fg = rgb(0, 255, 0)
bgWriteText(localX, localY + 1, "Color 1 (green)", style2)

var style3 = defaultStyle()
style3.fg = rgb(0, 0, 255)
bgWriteText(localX, localY + 2, "Color 2 (blue)", style3
# Show scope info
var infoStyle = defaultStyle()
infoStyle.fg = cyan()
bgWriteText(5, 12, "Scoping Rules:", infoStyle)
bgWriteText(5, 13, "- 'var x' in init = global", infoStyle)
bgWriteText(5, 14, "- 'var x' in update/render = local", infoStyle)
bgWriteText(5, 15, "- 'x = value' updates global if exists", infoStyle)

# Variables like localX, localY, style don't persist to next frame
```
