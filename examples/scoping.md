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
bgWriteText(5, 3, "Global Counter: " & $counter)
bgWriteText(5, 5, message)

# Local variables in render
var localX = 5
var localY = 7

# Display some test text
bgWriteText(localX, localY, "Testing local variables")
bgWriteText(localX, localY + 1, "localX = " & $localX)
bgWriteText(localX, localY + 2, "localY = " & $localY)

# Show scope info
bgWriteText(5, 12, "Scoping Rules:")
bgWriteText(5, 13, "- 'var x' in init = global")
bgWriteText(5, 14, "- 'var x' in update/render = local")
bgWriteText(5, 15, "- 'x = value' updates global if exists")

# Variables like localX, localY don't persist to next frame
```
