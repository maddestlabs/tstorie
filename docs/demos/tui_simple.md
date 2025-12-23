---
title: TUI Test
styles:
  label: { fg: [200, 200, 200], bg: [20, 20, 20] }
  button.normal: { fg: [255, 255, 255], bg: [50, 50, 150], bold: false }
  button.focused: { fg: [255, 255, 100], bg: [80, 80, 200], bold: true }
  button.hover: { fg: [255, 255, 150], bg: [70, 70, 180], bold: true }
  button.active: { fg: [200, 200, 50], bg: [100, 100, 220], bold: true }
  checkbox.normal: { fg: [200, 200, 200], bg: [20, 20, 20] }
  checkbox.focused: { fg: [255, 255, 100], bg: [20, 20, 20], bold: true }
  slider.normal: { fg: [100, 150, 255], bg: [20, 20, 20] }
  slider.focused: { fg: [150, 200, 255], bg: [20, 20, 20], bold: true }
---

# TUI Widget Test

Simple test of TUI widgets.

**Controls:**
- Press I/D/R keys to increment/decrement/reset counter
- Press Q to quit

```nim on:init
# Global counter variable
var clickCount = 0
var lastClickedButton = ""

# Create widget manager
nimini_newWidgetManager()

# Enable mouse support for widgets
nimini_enableMouse()

# Add widgets
nimini_newLabel("title", 2, 2, 40, 1, "TUI Widget Test")
nimini_newLabel("counter", 2, 4, 40, 1, "Clicks: 0")

# Buttons
nimini_newButton("btn_inc", 5, 7, 12, 3, "Increment")
nimini_newButton("btn_dec", 20, 7, 12, 3, "Decrement")
nimini_newButton("btn_reset", 35, 7, 10, 3, "Reset")

# Checkbox
nimini_newCheckBox("check1", 5, 12, "Feature enabled", false)

# Slider
nimini_newSlider("slider1", 5, 15, 30, 0, 100)
nimini_newLabel("slider_val", 37, 15, 15, 1, "Value: 50")

# Status
nimini_newLabel("status", 2, 18, 50, 1, "Ready")
```

```nim on:update
# Update widgets
nimini_widgetManagerUpdate(deltaTime)

# Update counter display
nimini_widgetSetText("counter", "Clicks: " & str(clickCount))

# Update slider value display
var sliderValue = nimini_widgetGetValue("slider1")
if sliderValue != 0:
  nimini_widgetSetText("slider_val", "Value: " & str(int(sliderValue)))
```

```nim on:render
# Clear layers
bgClear()
fgClear()

# Draw instructions
bgWriteText(2, 20, "Press I/D/R keys or click widgets")

# Render all widgets
nimini_widgetManagerRender("foreground")
```

```nim on:input
# Handle keyboard shortcuts for I/D/R keys before widgets
# Alphanumeric keys come as text events!
if event.type == "text":
  if event.keyCode == 105:  # 'i' key
    clickCount = clickCount + 1
    nimini_widgetSetText("status", "Incremented!")
    return 1
  if event.keyCode == 100:  # 'd' key
    clickCount = clickCount - 1  
    nimini_widgetSetText("status", "Decremented!")
    return 1
  if event.keyCode == 114:  # 'r' key
    clickCount = 0
    nimini_widgetSetText("status", "Reset!")
    return 1

# Let widget manager handle all other input (including mouse events for slider drag)
var handled = nimini_widgetManagerHandleInput()
if handled:
  # Check for button clicks immediately after widget manager handles input
  if nimini_widgetWasClicked("btn_inc"):
    clickCount = clickCount + 1
    nimini_widgetSetText("status", "Incremented!")
  
  if nimini_widgetWasClicked("btn_dec"):
    clickCount = clickCount - 1
    nimini_widgetSetText("status", "Decremented!")
  
  if nimini_widgetWasClicked("btn_reset"):
    clickCount = 0
    nimini_widgetSetText("status", "Reset!")
  
return 0
```
