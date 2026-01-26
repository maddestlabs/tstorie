---
title: "TUI Demo v2 - Using Built-in Helpers"
theme: "coffee"
shaders: "ruledlines+paper+lightnight"
fontsize: 16
styles.highlight.fg: "#FFFF00"
styles.highlight.bold: "true"
---

# TUI System Using Built-in Helpers

This demo recreates the comprehensive TUI system using the new built-in helper functions. Much simpler code with the same functionality!

```nim on:init
# ===================================================================
# Widget State Arrays
# ===================================================================
# Widget types: 0=TextBox, 1=Button, 2=Slider, 3=Checkbox
var widgetTypes = @[0, 0, 2, 2, 3, 3, 1, 1]
var widgetX = @[10, 10, 10, 10, 12, 12, 15, 32]
var widgetY = @[5, 9, 13, 17, 21, 22, 26, 26]
var widgetW = @[30, 30, 30, 30, 30, 30, 15, 15]
var widgetH = @[3, 3, 3, 3, 1, 1, 3, 3]

# TextBox data (indices 0, 1)
var tbLabels = @["Name:", "Email:"]
var tbTexts = @["", ""]
var tbCursors = @[0, 0]

# Button data (indices 6, 7)
var btnLabels = @["Submit", "Clear"]
var btnPressed = @[false, false]
var btnWasClicked = @[false, false]

# Slider data (indices 2, 3)
var sliderLabels = @["Volume:", "Brightness:"]
var sliderMins = @[0.0, 0.0]
var sliderMaxs = @[100.0, 100.0]
var sliderValues = @[50.0, 75.0]
var sliderDragging = @[false, false]

# Checkbox data (indices 4, 5)
var cbLabels = @["Opt-in to newsletter", "Enable notifications"]
var cbChecked = @[false, true]

# Focus management
var focusIndex = 0
var widgetCount = 8

# Global state
var message = "Tab/Shift+Tab to navigate | Space/Enter to activate"
var lastEvent = ""
```

```nim on:render
# ===================================================================
# Handle button clicks
# ===================================================================
if btnWasClicked[0]:  # Submit button
  btnWasClicked[0] = false
  if tbTexts[0] == "":
    message = "Please enter a name!"
  else:
    var opts = ""
    if cbChecked[0]:
      opts = opts & " +Newsletter"
    if cbChecked[1]:
      opts = opts & " +Notify"
    message = "Submitted: " & tbTexts[0] & opts

if btnWasClicked[1]:  # Clear button
  btnWasClicked[1] = false
  tbTexts[0] = ""
  tbTexts[1] = ""
  tbCursors[0] = 0
  tbCursors[1] = 0
  sliderValues[0] = 50.0
  sliderValues[1] = 75.0
  cbChecked[0] = false
  cbChecked[1] = true
  message = "Form cleared!"

# ===================================================================
# Render
# ===================================================================
clear()

# Header
drawLabel(0, 5, 2, "TUI v2 - Using Built-in Helpers", getStyle("info"))
drawLabel(0, 5, 31, "Message: " & message, getStyle("warning"))
drawLabel(0, 5, 32, "Last event: " & lastEvent, getStyle("info"))

# Render all widgets
var i = 0
while i < widgetCount:
  let x = widgetX[i]
  let y = widgetY[i]
  let w = widgetW[i]
  let h = widgetH[i]
  let focused = i == focusIndex
  let wType = widgetTypes[i]
  
  # TextBox
  if wType == 0:
    let tbIndex = i
    # Draw label above the box
    drawLabel(0, x + 1, y, tbLabels[tbIndex], getStyle("info"))
    # Draw the textbox itself
    drawTextBox(0, x, y, w, h, tbTexts[tbIndex], tbCursors[tbIndex], focused, "single")
  
  # Button
  elif wType == 1:
    let btnIndex = i - 6
    drawButton(0, x, y, w, h, btnLabels[btnIndex], focused, btnPressed[btnIndex], "single")
  
  # Slider
  elif wType == 2:
    let sliderIndex = i - 2
    # Draw box around slider
    let sliderStyle = if focused: getStyle("highlight") else: getStyle("border")
    drawBoxSimple(0, x, y, w, h, sliderStyle)
    
    # Draw label
    drawLabel(0, x + 1, y, sliderLabels[sliderIndex], getStyle("info"))
    
    # Draw slider inside box
    let sliderY = y + 1
    let sliderX = x + 2
    let sliderWidth = w - 4
    drawSlider(0, sliderX, sliderY, sliderWidth, sliderValues[sliderIndex], sliderMins[sliderIndex], sliderMaxs[sliderIndex], focused)
  
  # Checkbox
  elif wType == 3:
    let cbIndex = i - 4
    drawCheckBox(0, x, y, cbLabels[cbIndex], cbChecked[cbIndex], focused)
  
  i = i + 1
```

```nim on:input
var handled = false

# ===================================================================
# Text Input (for TextBox widgets)
# ===================================================================
if event.type == "text":
  if widgetTypes[focusIndex] == 0:  # TextBox
    let tbIndex = focusIndex
    tbTexts[tbIndex] = tbTexts[tbIndex] & event.text
    tbCursors[tbIndex] = tbCursors[tbIndex] + 1
    lastEvent = "text: " & event.text
    return true
  
  return false

# ===================================================================
# Key Input
# ===================================================================
elif event.type == "key":
  let keyCode = event.keyCode
  lastEvent = "key: " & str(keyCode)
  
  # Tab - cycle focus forward
  if keyCode == 9:
    if event.shift:
      # Shift+Tab - cycle backward
      focusIndex = (focusIndex - 1 + widgetCount) mod widgetCount
    else:
      # Tab - cycle forward
      focusIndex = (focusIndex + 1) mod widgetCount
    lastEvent = if event.shift: "shift-tab" else: "tab"
    return true
  
  # Backspace (for TextBox)
  if keyCode == 127 or keyCode == 8:
    if widgetTypes[focusIndex] == 0:
      let tbIndex = focusIndex
      if tbCursors[tbIndex] > 0 and len(tbTexts[tbIndex]) > 0:
        tbTexts[tbIndex] = tbTexts[tbIndex][0..<len(tbTexts[tbIndex]) - 1]
        tbCursors[tbIndex] = tbCursors[tbIndex] - 1
      return true
  
  # Space or Enter (for Button and Checkbox)
  if keyCode == 32 or keyCode == 13:
    if widgetTypes[focusIndex] == 1:  # Button
      let btnIndex = focusIndex - 6
      btnWasClicked[btnIndex] = true
      return true
    elif widgetTypes[focusIndex] == 3:  # Checkbox
      let cbIndex = focusIndex - 4
      cbChecked[cbIndex] = not cbChecked[cbIndex]
      return true
  
  # Arrow keys (for Slider)
  if keyCode >= 37 and keyCode <= 40:  # Arrow keys
    if widgetTypes[focusIndex] == 2:
      let sliderIndex = focusIndex - 2
      let range = sliderMaxs[sliderIndex] - sliderMins[sliderIndex]
      let step = range / 10.0
      
      if keyCode == 37 or keyCode == 40:  # Left or Down
        sliderValues[sliderIndex] = sliderValues[sliderIndex] - step
        if sliderValues[sliderIndex] < sliderMins[sliderIndex]:
          sliderValues[sliderIndex] = sliderMins[sliderIndex]
        return true
      elif keyCode == 39 or keyCode == 38:  # Right or Up
        sliderValues[sliderIndex] = sliderValues[sliderIndex] + step
        if sliderValues[sliderIndex] > sliderMaxs[sliderIndex]:
          sliderValues[sliderIndex] = sliderMaxs[sliderIndex]
        return true
  
  return false

# ===================================================================
# Mouse Input
# ===================================================================
elif event.type == "mouse":
  let mx = event.x
  let my = event.y
  let action = event.action
  
  lastEvent = "mouse " & action & " (" & str(mx) & "," & str(my) & ")"
  
  # Check which widget was clicked
  var clickedWidget = -1
  var i = 0
  while i < widgetCount:
    let x = widgetX[i]
    let y = widgetY[i]
    let w = widgetW[i]
    let h = widgetH[i]
    
    if mx >= x and mx < x + w and my >= y and my < y + h:
      clickedWidget = i
      break
    
    i = i + 1
  
  # Handle mouse press
  if action == "press":
    if clickedWidget >= 0:
      # Update focus
      focusIndex = clickedWidget
      
      # Button press
      if widgetTypes[clickedWidget] == 1:
        let btnIndex = clickedWidget - 6
        btnPressed[btnIndex] = true
        return true
      
      # Slider drag start
      elif widgetTypes[clickedWidget] == 2:
        let sliderIndex = clickedWidget - 2
        sliderDragging[sliderIndex] = true
        
        # Update slider value based on mouse position
        let sliderX = widgetX[clickedWidget] + 2
        let sliderWidth = widgetW[clickedWidget] - 4
        let relX = mx - sliderX
        var percent = float(relX) / float(sliderWidth - 1)
        if percent < 0.0:
          percent = 0.0
        if percent > 1.0:
          percent = 1.0
        
        let minVal = sliderMins[sliderIndex]
        let maxVal = sliderMaxs[sliderIndex]
        sliderValues[sliderIndex] = minVal + percent * (maxVal - minVal)
        return true
      
      # Checkbox toggle
      elif widgetTypes[clickedWidget] == 3:
        let cbIndex = clickedWidget - 4
        cbChecked[cbIndex] = not cbChecked[cbIndex]
        return true
  
  # Handle mouse drag
  elif action == "drag":
    # Update slider during drag
    var i = 0
    while i < 2:
      if sliderDragging[i]:
        let widgetIndex = i + 2
        let sliderX = widgetX[widgetIndex] + 2
        let sliderWidth = widgetW[widgetIndex] - 4
        let relX = mx - sliderX
        var percent = float(relX) / float(sliderWidth - 1)
        if percent < 0.0:
          percent = 0.0
        if percent > 1.0:
          percent = 1.0
        
        let minVal = sliderMins[i]
        let maxVal = sliderMaxs[i]
        sliderValues[i] = minVal + percent * (maxVal - minVal)
        return true
      i = i + 1
  
  # Handle mouse release
  elif action == "release":
    # Check button clicks
    var i = 0
    while i < 2:
      if btnPressed[i]:
        btnPressed[i] = false
        let widgetIndex = i + 6
        let x = widgetX[widgetIndex]
        let y = widgetY[widgetIndex]
        let w = widgetW[widgetIndex]
        let h = widgetH[widgetIndex]
        
        if mx >= x and mx < x + w and my >= y and my < y + h:
          btnWasClicked[i] = true
        return true
      i = i + 1
    
    # Stop slider dragging
    sliderDragging[0] = false
    sliderDragging[1] = false
    return true
  
  return false

return false
```

## Code Comparison

**Before (tui.md):** ~120 lines just for the `drawBox` helper function!

**After (tui2.md):** Uses built-in `drawBoxSimple()`, `drawButton()`, `drawTextBox()`, `drawSlider()`, and `drawCheckBox()` - **40% less code** with the same functionality!

## Benefits

1. **Cleaner code** - No need to manually draw box borders
2. **Consistent styling** - All widgets use theme styles automatically
3. **Less error-prone** - Pre-tested widget functions
4. **Easier to maintain** - Updates to widgets happen in one place
