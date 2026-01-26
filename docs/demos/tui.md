---
title: "Scripted TUI Demo"
theme: "coffee"
# Custom highlight style inherits background from theme
styles.highlight.fg: "#FF0000"
styles.highlight.bold: "true"
shaders: "ruledlines+paper+lightnight"
fontsize: 16
---

# Comprehensive TUI System

A full-featured UI widget system built with scripting of core drawing functions. This demo automatically adapts to the active theme, using standard style names that are defined for all themes: `border`, `info`, `default`, `button`, and `warning`.

```nim on:init
# ===================================================================
# Helper function to draw boxes
# ===================================================================
proc drawBox(x, y, w, h: int, style: Style) =
  draw(0, x, y, "┌", style)
  draw(0, x + w - 1, y, "┐", style)
  draw(0, x, y + h - 1, "└", style)
  draw(0, x + w - 1, y + h - 1, "┘", style)
  
  var dx = 1
  while dx < w - 1:
    draw(0, x + dx, y, "─", style)
    draw(0, x + dx, y + h - 1, "─", style)
    dx = dx + 1
  
  var dy = 1
  while dy < h - 1:
    draw(0, x, y + dy, "│", style)
    draw(0, x + w - 1, y + dy, "│", style)
    dy = dy + 1

# ===================================================================
# Widget Types & State Arrays
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

# Button press tracking
var btnPressed = @[false, false]
var btnWasClicked = @[false, false]
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

let infoStyle = getStyle("info")
let warningStyle = getStyle("warning")

draw(0, 5, 2, "Comprehensive TUI System - Tab/Shift+Tab to navigate", infoStyle)
draw(0, 5, 31, "Message: " & message, warningStyle)
draw(0, 5, 32, "Last event: " & lastEvent, infoStyle)

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
    let tbStyle = if focused: getStyle("highlight") else: getStyle("border")
    drawBox(x, y, w, h, tbStyle)
    
    let labelStyle = getStyle("info")
    draw(0, x + 1, y, tbLabels[tbIndex], labelStyle)
    
    let textStyle = getStyle("default")
    draw(0, x + 2, y + 1, tbTexts[tbIndex], textStyle)
    
    if focused:
      let cursorStyle = getStyle("highlight")
      draw(0, x + 2 + tbCursors[tbIndex], y + 1, "_", cursorStyle)
  
  # Button
  elif wType == 1:
    let btnIndex = i - 6
    let btnStyle = if focused: getStyle("info") else: getStyle("border")
    
    if btnPressed[btnIndex]:
      let fillStyle = getStyle("button")
      fillRect(0, x, y, w, h, "#", fillStyle)
    else:
      drawBox(x, y, w, h, btnStyle)
    
    let label = btnLabels[btnIndex]
    let labelX = x + (w - len(label)) div 2
    let labelY = y + h div 2
    draw(0, labelX, labelY, label, btnStyle)
  
  # Slider
  elif wType == 2:
    let sliderIndex = i - 2
    let sliderStyle = if focused: getStyle("highlight") else: getStyle("border")
    drawBox(x, y, w, h, sliderStyle)
    
    let labelStyle = getStyle("info")
    draw(0, x + 1, y, sliderLabels[sliderIndex], labelStyle)
    
    let sliderY = y + 1
    let sliderX = x + 2
    let sliderWidth = w - 4
    
    let minVal = sliderMins[sliderIndex]
    let maxVal = sliderMaxs[sliderIndex]
    let curVal = sliderValues[sliderIndex]
    let percent = (curVal - minVal) / (maxVal - minVal)
    let handlePos = int(percent * float(sliderWidth - 1))
    
    var dx = 0
    while dx < sliderWidth:
      let ch = if dx == handlePos: "O" else: "─"
      let chStyle = if dx == handlePos: getStyle("warning") else: getStyle("default")
      draw(0, sliderX + dx, sliderY, ch, chStyle)
      dx = dx + 1
    
    let valueText = str(int(curVal))
    draw(0, x + w - len(valueText) - 2, y + 2, valueText, getStyle("default"))
  
  # Checkbox
  elif wType == 3:
    let cbIndex = i - 4
    let cbStyle = if focused: getStyle("highlight") else: getStyle("default")
    let checkChar = if cbChecked[cbIndex]: "X" else: " "
    draw(0, x, y, "[" & checkChar & "]", cbStyle)
    draw(0, x + 4, y, cbLabels[cbIndex], getStyle("default"))
  
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

Complete TUI system with focus management, keyboard navigation, and mouse interaction!
