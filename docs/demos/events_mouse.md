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
if event.type == "mouse":
  mouseX = event.x
  mouseY = event.y
  lastButton = event.button
  lastAction = event.action
  
  if event.action == "press":
    clickCount = clickCount + 1
    
    # Check if click was in the box
    if mouseX >= 10 and mouseX <= 29 and mouseY >= 14 and mouseY <= 18:
      print("Box clicked at (" & str(mouseX) & ", " & str(mouseY) & ")")
  
  return true  # Consume the event

elif event.type == "mouse_move":
  mouseX = event.x
  mouseY = event.y
  return false

return false
```

```nim on:render
# Clear screen
bgClear()

# Draw title  
bgWriteText(2, 2, "=== MOUSE EVENT TEST ===")

# Draw instructions
bgWriteText(2, 4, "Move your mouse and click buttons to test")
bgWriteText(2, 5, "Press Q or ESC to quit")

# Display mouse state
bgWriteText(2, 7, "Mouse Position: (" & str(mouseX) & ", " & str(mouseY) & ")")
bgWriteText(2, 8, "Last Button: " & lastButton)
bgWriteText(2, 9, "Last Action: " & lastAction)
bgWriteText(2, 10, "Click Count: " & str(clickCount))

# Draw a clickable box
bgWriteText(10, 13, "+------------------+")
var i = 0
while i < 5:
  bgWriteText(10, 14 + i, "|                  |")
  i = i + 1
bgWriteText(10, 19, "+------------------+")

bgWriteText(13, 16, "CLICK ME!")

# Visual feedback if mouse is over the box
if mouseX >= 10 and mouseX <= 29 and mouseY >= 14 and mouseY <= 18:
  bgWriteText(11, 16, "  HOVERING  ")
```

```nim on:shutdown
# Cleanup
```
