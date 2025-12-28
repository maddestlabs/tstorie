---
title: "Simple UI POC - Pure Nimini"
minWidth: 60
minHeight: 25
---

# Simple UI Proof of Concept

This demonstrates building UI widgets entirely in Nimini scripting, using only the basic drawing primitives that tStorie exposes.

```nim on:init
# ===================================================================
# Helper function to draw boxes (like Storiel's drawBox)
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
# TextBox Widget State
# ===================================================================
var tbX = 10
var tbY = 5
var tbWidth = 30
var tbHeight = 3
var tbLabel = "Name:"
var tbText = ""
var tbCursor = 0
var tbFocused = true

# ===================================================================
# Button Widget State
# ===================================================================
var btnX = 15
var btnY = 10
var btnWidth = 15
var btnHeight = 3
var btnLabel = "Submit"
var btnPressed = false
var btnWasClicked = false

# ===================================================================
# Global State
# ===================================================================
var message = "Type in the textbox or click the button"
var clickCount = 0

# Enable features
# Note: Mouse should be enabled by default in editor mode
```

```nim on:render
# Check for button click
if btnWasClicked:
  btnWasClicked = false
  clickCount = clickCount + 1
  if tbText == "":
    message = "Please enter a name!"
  else:
    message = "Hello, " & tbText & "! (clicked " & str(clickCount) & " times)"

# Render
clear()

let infoStyle = getStyle("info")
let warningStyle = getStyle("warning")

draw(0, 5, 2, "Pure Nimini UI - Type in box, click button", infoStyle)
draw(0, 5, 22, "Message: " & message, warningStyle)

# Render textbox
var tbStyle = getStyle("border")
if tbFocused:
  tbStyle = getStyle("highlight")
drawBox(tbX, tbY, tbWidth, tbHeight, tbStyle)

let labelStyle = getStyle("info")
draw(0, tbX + 1, tbY, tbLabel, labelStyle)

let textStyle = getStyle("default")
draw(0, tbX + 2, tbY + 1, tbText, textStyle)

if tbFocused:
  let cursorStyle = getStyle("warning")
  draw(0, tbX + 2 + tbCursor, tbY + 1, "_", cursorStyle)

# Render button
let btnStyle = getStyle("border")

if btnPressed:
  let fillStyle = getStyle("button")
  fillRect(0, btnX, btnY, btnWidth, btnHeight, "#", fillStyle)
else:
  drawBox(btnX, btnY, btnWidth, btnHeight, btnStyle)

let labelX = btnX + (btnWidth - len(btnLabel)) div 2
let labelY = btnY + btnHeight div 2
draw(0, labelX, labelY, btnLabel, btnStyle)
```

```nim on:input
if event.type == "text":
  # Handle text input (printable characters)
  if not tbFocused:
    return false
  
  tbText = tbText & event.text
  tbCursor = tbCursor + 1
  return true

elif event.type == "key":
  # Handle special keys
  let keyCode = event.keyCode
  
  if not tbFocused:
    return false
  
  # Backspace
  if keyCode == 127 or keyCode == 8:
    if tbCursor > 0 and len(tbText) > 0:
      tbText = tbText[0..<len(tbText) - 1]
      tbCursor = tbCursor - 1
    return true
  
  return false

elif event.type == "mouse":
  # Handle mouse input
  let x = event.x
  let y = event.y
  let action = event.action
  let inside = x >= btnX and x < btnX + btnWidth and y >= btnY and y < btnY + btnHeight
  
  if action == "press" and inside:
    btnPressed = true
    return true
  elif action == "release":
    if btnPressed and inside:
      btnWasClicked = true
    btnPressed = false
    return true
  
  return false

return false
```

No native UI code needed!
