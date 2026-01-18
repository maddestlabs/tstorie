---
title: "Keyboard & Timing Events Demo"
theme: "catppuccin"
---

This example demonstrates modern keyboard event handling using SDL3-compatible KEY_* constants and frame-independent animations.

```nim on:init
# Track keyboard state
var lastKey = "none"
var lastKeyCode = 0
var lastAction = "none"
var keyPressCount = 0
var shiftPressed = false
var ctrlPressed = false
var altPressed = false
var superPressed = false

# Animation state (frame-independent)
var keyPressFlashPhase = 0.0
var arrowKeyAngle = 0.0
var typingBarWidth = 0.0
var lastKeyTime = 0.0

# Arrow key tracking for visual
var arrowUpHeld = false
var arrowDownHeld = false
var arrowLeftHeld = false
var arrowRightHeld = false
```

```nim on:input
# Handle keyboard events through the normal input lifecycle
if event.type == "key":
  lastKeyCode = event.keyCode
  lastAction = event.action
  lastKeyTime = getTime()
  
  # Reset typing bar animation on new key press
  if event.action == "press":
    typingBarWidth = 0.0
  
  # Update modifier states from event.mods array
  # mods is an array of strings: ["shift", "alt", "ctrl", "super"]
  shiftPressed = false
  altPressed = false
  ctrlPressed = false
  superPressed = false
  
  var i = 0
  while i < len(event.mods):
    if event.mods[i] == "shift":
      shiftPressed = true
    elif event.mods[i] == "alt":
      altPressed = true
    elif event.mods[i] == "ctrl":
      ctrlPressed = true
    elif event.mods[i] == "super":
      superPressed = true
    i = i + 1
  
  # Convert keyCode to readable name using KEY_* constants
  if lastKeyCode == KEY_ESCAPE:
    lastKey = "ESC"
  elif lastKeyCode == KEY_RETURN:
    lastKey = "ENTER"
  elif lastKeyCode == KEY_SPACE:
    lastKey = "SPACE"
  elif lastKeyCode == KEY_TAB:
    lastKey = "TAB"
  elif lastKeyCode == KEY_BACKSPACE:
    lastKey = "BACKSPACE"
  elif lastKeyCode == KEY_DELETE:
    lastKey = "DELETE"
  elif lastKeyCode == KEY_UP:
    lastKey = "UP"
    arrowUpHeld = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode == KEY_DOWN:
    lastKey = "DOWN"
    arrowDownHeld = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode == KEY_LEFT:
    lastKey = "LEFT"
    arrowLeftHeld = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode == KEY_RIGHT:
    lastKey = "RIGHT"
    arrowRightHeld = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode >= 32 and lastKeyCode < 127:
    # Printable ASCII character
    lastKey = "'" & str(lastKeyCode) & "'"
  else:
    lastKey = "KEY_" & str(lastKeyCode)
  
  # Clear arrow states on release
  if event.action == "release":
    if lastKeyCode == KEY_UP:
      arrowUpHeld = false
    elif lastKeyCode == KEY_DOWN:
      arrowDownHeld = false
    elif lastKeyCode == KEY_LEFT:
      arrowLeftHeld = false
    elif lastKeyCode == KEY_RIGHT:
      arrowRightHeld = false

  if event.action == "press":
    keyPressCount = keyPressCount + 1
    keyPressFlashPhase = 0.0  # Start flash animation
  
  # Use KEY_Q constant for quit
  if event.keyCode == KEY_Q or event.keyCode == KEY_ESCAPE:
    return false  # Allow default quit behavior
  
  return true

elif event.type == "text":
  # Handle text input (actual characters typed)
  lastKey = "'" & event.text & "'"
  lastKeyCode = 0
  lastAction = "text"
  keyPressCount = keyPressCount + 1
  lastKeyTime = getTime()
  typingBarWidth = 0.0
  
  # Example: Check for specific character
  if event.text == "T":
    lastKey = "'T' (uppercase detected!)"
  elif event.text == "t":
    lastKey = "'t' (lowercase detected!)"
  
  return true

return true
```

```nim on:update
# Frame-independent animations using deltaTime
keyPressFlashPhase = keyPressFlashPhase + (deltaTime * 6.0)  # Fast flash
arrowKeyAngle = arrowKeyAngle + (deltaTime * 3.0)  # Rotate for arrow visual
typingBarWidth = typingBarWidth + (deltaTime * 30.0)  # Typing bar grows
if typingBarWidth > 20.0:
  typingBarWidth = 20.0
```

```nim on:render
# Clear screen
clear()

# === HEADER ===
draw(0, 2, 1, "=== KEYBOARD EVENT TEST ===")
draw(0, 2, 2, "Time: " & str(int(getTimeMs())) & "ms | FPS: " & str(int(getFps())) & " | Frame: " & str(getFrameCount()))
draw(0, 2, 3, "Delta: " & str(int(getDeltaTime() * 1000000.0)) & "us (microseconds)")

# === INSTRUCTIONS ===
draw(0, 2, 5, "Press any key to test keyboard input")
draw(0, 2, 6, "Press Q or ESC to quit (using KEY_Q and KEY_ESCAPE constants)")

# === KEYBOARD STATE ===
draw(0, 2, 8, "Last Key: " & lastKey)
draw(0, 2, 9, "Key Code: " & str(lastKeyCode))
draw(0, 2, 10, "Action: " & lastAction)
draw(0, 2, 11, "Press Count: " & str(keyPressCount))

# === MODIFIER STATES ===
var modStr = "Modifiers: "
if shiftPressed:
  modStr = modStr & "[SHIFT] "
if ctrlPressed:
  modStr = modStr & "[CTRL] "
if altPressed:
  modStr = modStr & "[ALT] "
if superPressed:
  modStr = modStr & "[SUPER] "
if not (shiftPressed or ctrlPressed or altPressed or superPressed):
  modStr = modStr & "(none)"
draw(0, 2, 12, modStr)

# Draw a visual keyboard hint
draw(0, 2, 14, "Common Keys:")
draw(0, 4, 15, "Arrows: UP/DOWN/LEFT/RIGHT (try holding them!)")
draw(0, 4, 16, "Special: ESC, ENTER, SPACE, TAB, BACKSPACE, DELETE")
draw(0, 4, 17, "Letters: a-z, A-Z")
draw(0, 4, 18, "Numbers: 0-9")
draw(0, 4, 19, "Try: Press 'T' or 'Shift+T' to see character detection!")

# === PRESS COUNTER BOX (with animation) ===
var boxY = 8
draw(0, 50, boxY - 1, "+-------------------+")
draw(0, 50, boxY, "| Total Key Presses |")
draw(0, 50, boxY + 1, "|                   |")

var countStr = str(keyPressCount)
var padding = 19 - len(countStr)
var leftPad = padding / 2
var rightPad = padding - leftPad
var i = 0
var paddedCount = ""
while i < leftPad:
  paddedCount = paddedCount & " "
  i = i + 1
paddedCount = paddedCount & countStr
i = 0
while i < rightPad:
  paddedCount = paddedCount & " "
  i = i + 1
draw(0, 50, boxY + 2, "|" & paddedCount & "|")
draw(0, 50, boxY + 3, "+-------------------+")

# Flash effect on box when key pressed
var flashIntensity = 0
if keyPressFlashPhase < 6.28:  # One flash cycle (2*PI)
  flashIntensity = int(sin(keyPressFlashPhase) * sin(keyPressFlashPhase) * 50)
  if flashIntensity > 5:
    draw(0, 50, boxY + 4, "   *** FLASH! ***   ")

# === TYPING ACTIVITY BAR ===
draw(0, 2, 21, "Typing Activity:")
draw(0, 2, 22, "[")
var barFilled = int(typingBarWidth)
i = 0
while i < barFilled:
  draw(0, 3 + i, 22, "=")
  i = i + 1
draw(0, 23, 22, "]")

# === ARROW KEY VISUAL ===
draw(0, 50, 14, "Arrow Keys Status:")
var arrowCenterX = 60
var arrowCenterY = 17

# Draw arrow key indicators
if arrowUpHeld:
  draw(0, arrowCenterX, arrowCenterY - 2, "^")
  draw(0, arrowCenterX, arrowCenterY - 1, "|")
if arrowDownHeld:
  draw(0, arrowCenterX, arrowCenterY + 1, "|")
  draw(0, arrowCenterX, arrowCenterY + 2, "v")
if arrowLeftHeld:
  draw(0, arrowCenterX - 2, arrowCenterY, "<")
  draw(0, arrowCenterX - 1, arrowCenterY, "-")
if arrowRightHeld:
  draw(0, arrowCenterX + 1, arrowCenterY, "-")
  draw(0, arrowCenterX + 2, arrowCenterY, ">")

# Center indicator
draw(0, arrowCenterX, arrowCenterY, "+")

# Rotating indicator when any arrow is held
if arrowUpHeld or arrowDownHeld or arrowLeftHeld or arrowRightHeld:
  var rotX = int(float(arrowCenterX) + 4.0 * cos(arrowKeyAngle))
  var rotY = int(float(arrowCenterY) + 2.0 * sin(arrowKeyAngle))
  if rotX >= 0 and rotX < termWidth and rotY >= 0 and rotY < termHeight:
    draw(0, rotX, rotY, "*")

# === VISUAL FEEDBACK FOR LAST ACTION ===
draw(0, 2, 24, "Last Action:")
if lastAction == "press":
  draw(0, 15, 24, ">>> KEY PRESSED <<<")
elif lastAction == "release":
  draw(0, 15, 24, ">>> KEY RELEASED <<<")
elif lastAction == "repeat":
  draw(0, 15, 24, ">>> KEY REPEATING <<<")
elif lastAction == "text":
  draw(0, 15, 24, ">>> TEXT INPUT <<<")

# Show time since last key
var timeSinceKey = getTime() - lastKeyTime
if timeSinceKey < 2.0:
  draw(0, 2, 25, "Time since last key: " & str(int(timeSinceKey * 1000)) & "ms")

# === KEY CONSTANTS INFO ===
draw(0, 2, termHeight - 3, "Using SDL3-compatible KEY_* constants:")
draw(0, 3, termHeight - 2, "KEY_ESCAPE, KEY_RETURN, KEY_SPACE, KEY_TAB, KEY_BACKSPACE")
draw(0, 3, termHeight - 1, "KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_DELETE, KEY_Q")
```