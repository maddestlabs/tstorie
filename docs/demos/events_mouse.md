# Mouse Event Test

This example demonstrates mouse event handling in tstorie.

```nim on:init
# Track mouse state
var mouseX = 0
var mouseY = 0
var lastButton = "none"
var lastAction = "none"
var clickCount = 0
```

```nim on:input
# Handle mouse events through the normal input lifecycle
if event.type == "mouse_move":
  # Update coordinates from mouse move events
  mouseX = event.x
  mouseY = event.y
  # Update to show we got a move event
  lastAction = "move"

if event.type == "mouse":
  #mouseX = event.x
  #mouseY = event.y
  lastButton = event.button
  lastAction = event.action
  
  if event.action == "press":
    clickCount = clickCount + 1
    
    # Check if click was in the box
    if mouseX >= 10 and mouseX <= 29 and mouseY >= 14 and mouseY <= 18:
      draw(0, 2, termHeight - 1, "Box clicked at (" & str(mouseX) & ", " & str(mouseY) & ")")

```

```nim on:render
# Clear screen
clear()

# Draw title  
draw(0, 2, 2, "=== MOUSE EVENT TEST ===")

# Draw instructions
draw(0, 2, 4, "Move your mouse and click buttons to test")
draw(0, 2, 5, "Press Q or ESC to quit")

# Display mouse state (using local variables)
draw(0, 2, 7, "Mouse Position (local): (" & str(mouseX) & ", " & str(mouseY) & ")")
draw(0, 2, 8, "Last Button: " & lastButton)
draw(0, 2, 9, "Last Action: " & lastAction)
draw(0, 2, 10, "Click Count: " & str(clickCount))

# Display mouse state using getMouseX/getMouseY functions
draw(0, 2, 12, "Mouse Position (getMouseX/Y): (" & str(getMouseX()) & ", " & str(getMouseY()) & ")")

# Draw a clickable box
draw(0, 10, 15, "+------------------+")
var i = 0
while i < 5:
  draw(0, 10, 16 + i, "|                  |")
  i = i + 1
draw(0, 10, 21, "+------------------+")

draw(0, 13, 18, "CLICK ME!")

# Visual feedback if mouse is over the box
if mouseX >= 10 and mouseX <= 29 and mouseY >= 16 and mouseY <= 20:
  draw(0, 11, 18, "  HOVERING  ")
```

```nim on:shutdown
# Cleanup
```
