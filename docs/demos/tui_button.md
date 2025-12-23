---
title: Simple TUI Test
styles:
  label: { fg: [200, 200, 200], bg: [20, 20, 20] }
  button.normal: { fg: [255, 255, 255], bg: [50, 50, 150], bold: false }
  button.focused: { fg: [255, 255, 100], bg: [80, 80, 200], bold: true }
  button.hover: { fg: [255, 255, 150], bg: [70, 70, 180], bold: true }
  button.active: { fg: [200, 200, 50], bg: [100, 100, 220], bold: true }
---

# Simple Button Test

One button, one counter, keyboard event display.

```nim on:init
# Counter
var clickCount = 0

# Last key info
var lastKey = "none"
var lastKeyCode = 0

# Create widget manager
nimini_newWidgetManager()
nimini_enableMouse()

# Add widgets
nimini_newLabel("title", 2, 2, 40, 1, "Simple Button Test")
nimini_newLabel("counter", 2, 4, 40, 1, "Clicks: 0")
nimini_newLabel("lastkey", 2, 6, 40, 1, "Last key: none")

# Single button
nimini_newButton("btn_click", 5, 9, 15, 3, "Click Me!")

# Status
nimini_newLabel("status", 2, 14, 50, 1, "Ready - Press keys or click button")
```

```nim on:update
# Update widgets
nimini_widgetManagerUpdate(deltaTime)

# Update counter display
nimini_widgetSetText("counter", "Clicks: " & str(clickCount))

# Update last key display
nimini_widgetSetText("lastkey", "Last key: " & lastKey & " (code: " & str(lastKeyCode) & ")")
```

```nim on:render
# Clear layers
bgClear()
fgClear()

# Draw instructions
bgWriteText(2, 17, "Try: Click button with mouse")
bgWriteText(2, 18, "     Press any key")
bgWriteText(2, 19, "     Press Q to quit")

# Render all widgets
nimini_widgetManagerRender("foreground")
```

```nim on:input
# Log all events for debugging
if event.type == "key":
  lastKey = "KEY"
  lastKeyCode = event.keyCode
  nimini_widgetSetText("status", "Key pressed: " & str(event.keyCode))
  # Don't consume - let it propagate to quit handler
  return 0

elif event.type == "text":
  # Alphanumeric keys come through as text events!
  lastKey = event.text
  lastKeyCode = event.keyCode  # ASCII value of the character
  nimini_widgetSetText("status", "Text input: " & event.text)
  # Don't consume - let it propagate
  return 0

elif event.type == "mouse":
  nimini_widgetSetText("status", "Mouse event: " & event.button & " " & event.action & " at (" & str(event.x) & "," & str(event.y) & ")")
  # Let widget manager handle it
  var handled = nimini_widgetManagerHandleInput()
  if handled:
    # Check for button click immediately after widget manager handles input
    if nimini_widgetWasClicked("btn_click"):
      clickCount = clickCount + 1
      nimini_widgetSetText("status", "Button clicked! Count: " & str(clickCount))
    return 1
  return 0

elif event.type == "mouse_move":
  # Don't log mouse moves, too spammy
  # Let widget manager handle for hover states
  var handled = nimini_widgetManagerHandleInput()
  if handled:
    return 1
  return 0

# Default: don't consume
return 0
```
