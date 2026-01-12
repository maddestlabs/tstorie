---
title: TUI Helpers Demo
author: TStorie
theme: "neotopia"
---

# TUI Helpers Demo

This demo showcases the new stateless TUI helper functions that enable rapid UI prototyping.

```nim on:init
# ===================================================================
# Global state
# ===================================================================
var buttonPressed = false
var sliderValue = 0.5
var checkboxValue = false
var progress = 0.0
var message = "Use arrow keys for slider | Space for checkbox | B for button | Q to quit"
```

```nim on:render
# ===================================================================
# Animate progress bar
# ===================================================================
progress = progress + 0.01
if progress > 1.0:
  progress = 0.0

# ===================================================================
# Render
# ===================================================================
clear()

# Get dimensions
let w = getWidth()
let h = getHeight()
let centerX = w div 2

# Title panel
drawPanel(0, centerX - 30, 2, 60, 3, "TUI HELPERS DEMO", getStyle("border"))

# Box drawing examples
drawBoxSimple(0, 5, 7, 25, 8, getStyle("border"))
drawLabel(0, 7, 8, "Simple Box", getStyle("info"))

drawBoxDouble(0, 35, 7, 25, 8, getStyle("border"))
drawLabel(0, 37, 8, "Double Box", getStyle("info"))

drawBoxRounded(0, 65, 7, 25, 8, getStyle("border"))
drawLabel(0, 67, 8, "Rounded Box", getStyle("info"))

# Interactive widgets
let buttonY = 17
drawButton(0, centerX - 10, buttonY, 20, 3, "Click Me!", buttonPressed, getStyle("info"), getStyle("border"))

# Slider
drawLabel(0, 10, 22, "Slider Value:", getStyle("border"))
drawSlider(0, 25, 22, 40, sliderValue, getStyle("info"), getStyle("border"))

# Checkbox
drawCheckBox(0, 10, 25, "Enable Feature", checkboxValue, getStyle("info"), getStyle("border"))

# Progress bar
drawLabel(0, 10, 28, "Progress:", getStyle("border"))
drawProgressBar(0, 20, 28, 50, progress, getStyle("info"), getStyle("border"))

# Separator
drawSeparator(0, 5, 31, w - 10, getStyle("border"))

# Text box with wrapped content
let helpText = "These helpers are stateless, FFI-safe, and work from both native Nim and nimini scripts. They integrate with the layer system for automatic compositing and the theme system for consistent styling."
drawTextBox(0, 5, 33, w - 10, 6, helpText, getStyle("border"), getStyle("info"), 0)

# Status message
draw(0, 5, h - 3, message, getStyle("warning"))
```

```nim on:input
var handled = false

# ===================================================================
# Key Input
# ===================================================================
if event.type == "key":
  let keyCode = event.keyCode
  
  # Q - quit
  if keyCode == 113:  # 'q'
    quit()
  
  # B - toggle button
  if keyCode == 98:  # 'b'
    buttonPressed = not buttonPressed
    message = "Button " & (if buttonPressed: "pressed" else: "released")
  
  # Space - toggle checkbox
  if keyCode == 32:  # Space
    checkboxValue = not checkboxValue
    message = "Checkbox " & (if checkboxValue: "checked" else: "unchecked")
  
  # Arrow keys - adjust slider
  if keyCode >= 37 and keyCode <= 40:
    if keyCode == 37 or keyCode == 40:  # Left or Down
      sliderValue = sliderValue - 0.1
      if sliderValue < 0.0:
        sliderValue = 0.0
      message = "Slider: " & str(int(sliderValue * 100.0)) & "%"
    elif keyCode == 39 or keyCode == 38:  # Right or Up
      sliderValue = sliderValue + 0.1
      if sliderValue > 1.0:
        sliderValue = 1.0
      message = "Slider: " & str(int(sliderValue * 100.0)) & "%"
```

## Features Demonstrated

1. **Box Drawing**: Simple, double-line, and rounded box styles
2. **Interactive Widgets**: Buttons, sliders, checkboxes  
3. **Progress Indicators**: Animated progress bars
4. **Text Layout**: Multi-line text boxes with wrapping
5. **Labels**: Simple text rendering
6. **Panels**: Titled containers with borders
7. **Separators**: Horizontal dividers

## Key Benefits

- **Stateless**: All functions are pure, taking parameters instead of mutating global state
- **FFI-Safe**: No ref objects, no crashes at the FFI boundary
- **Theme-Aware**: Automatically uses theme styles via `getStyle()`
- **Layer-Aware**: Draws on specified layers for automatic compositing
- **Easy to Use**: Simple function calls, no object initialization required
