# mouseX and mouseY Test

This example demonstrates the new `mouseX` and `mouseY` functions.

These functions return the last known mouse position and can be called from anywhere in your code (render, update, etc.), not just during mouse events.

```nim on:init
# No need to track mouse position manually anymore!
```

```nim on:render
# Clear screen
clear()

# Draw title  
draw(0, 2, 2, "=== mouseX / mouseY Test ===")

# Draw instructions
draw(0, 2, 4, "Move your mouse around the screen")
draw(0, 2, 5, "These functions work from anywhere!")
draw(0, 2, 6, "Press Q or ESC to quit")

# Get mouse position using the new functions
var x = mouseX
var y = mouseY

# Display mouse coordinates
draw(0, 2, 8, "Mouse X: " & str(x))
draw(0, 2, 9, "Mouse Y: " & str(y))

# Draw a cursor follower (offset slightly to see it)
if x > 0 and y > 0 and x < termWidth - 1 and y < termHeight - 1:
  draw(0, x + 1, y, "<")
  draw(0, x - 1, y, ">")
  draw(0, x, y + 1, "^")
  draw(0, x, y - 1, "v")

# Draw coordinate grid lines to show position
var i = 0
while i < termWidth:
  if i == x:
    draw(0, i, 12, "|")
  else:
    draw(0, i, 12, ".")
  i = i + 1

var j = 0
while j < termHeight:
  if j == y:
    draw(0, 50, j, "-")
  else:
    draw(0, 50, j, ":")
  j = j + 1
```

```nim on:update
# You can access mouse position in update too!
var x = mouseX
var y = mouseY
# Could use this for game logic, animations, etc.
```

```nim on:shutdown
# Cleanup
```
