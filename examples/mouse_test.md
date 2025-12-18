# Mouse Event Test

This example demonstrates mouse event handling in tstorie.

```nim on:init
# Enable mouse input
enableMouse()

# Track mouse state
var mouseX = 0
var mouseY = 0
var lastButton = "none"
var lastAction = "none"
var clickCount = 0

# Register global input handler to capture mouse events
proc handleMouse(event):
  if event.type == "mouse":
    mouseX = event.x
    mouseY = event.y
    lastButton = event.button
    lastAction = event.action
    
    if event.action == "press":
      clickCount = clickCount + 1
      
      # Check if click was in the box
      if mouseX >= 10 and mouseX <= 29 and mouseY >= 14 and mouseY <= 18:
        print("Box clicked at (" + str(mouseX) + ", " + str(mouseY) + ")")
    
    return false  # Don't consume the event
  
  elif event.type == "mouse_move":
    mouseX = event.x
    mouseY = event.y
    return false
  
  return false

registerGlobalInput("mouse_handler", handleMouse, 0)
```

```nim on:render
# Clear screen
bgClear()

# Draw title
var titleStyle = defaultStyle()
titleStyle.fg = cyan()
titleStyle.bold = true
bgWrite(2, 2, "=== MOUSE EVENT TEST ===", titleStyle)

# Draw instructions
var infoStyle = defaultStyle()
infoStyle.fg = yellow()
bgWrite(2, 4, "Move your mouse and click buttons to test", infoStyle)
bgWrite(2, 5, "Press Q or ESC to quit", infoStyle)

# Display mouse state
var dataStyle = defaultStyle()
dataStyle.fg = green()
bgWrite(2, 7, "Mouse Position: (" + str(mouseX) + ", " + str(mouseY) + ")", dataStyle)
bgWrite(2, 8, "Last Button: " + lastButton, dataStyle)
bgWrite(2, 9, "Last Action: " + lastAction, dataStyle)
bgWrite(2, 10, "Click Count: " + str(clickCount), dataStyle)

# Draw a clickable box
var boxStyle = defaultStyle()
boxStyle.fg = magenta()
boxStyle.bold = true

bgWrite(10, 13, "+------------------+", boxStyle)
for i in 0..4:
  bgWrite(10, 14 + i, "|                  |", boxStyle)
bgWrite(10, 19, "+------------------+", boxStyle)

var labelStyle = defaultStyle()
labelStyle.fg = white()
bgWrite(13, 16, "CLICK ME!", labelStyle)

# Visual feedback if mouse is over the box
if mouseX >= 10 and mouseX <= 29 and mouseY >= 14 and mouseY <= 18:
  var hoverStyle = defaultStyle()
  hoverStyle.fg = yellow()
  hoverStyle.bold = true
  bgWrite(11, 16, "  HOVERING  ", hoverStyle)
```

```nim on:shutdown
# Disable mouse when exiting
disableMouse()
```
