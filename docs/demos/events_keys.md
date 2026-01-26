---
title: "Keyboard & Timing Events Demo"
theme: "catppuccin"
---

This example demonstrates modern keyboard event handling using the optimal input system approach:
- **TextEvent** for printable characters (letters, numbers, symbols)
- **KeyEvent** for special keys (arrows, escape, function keys)
- Event-local modifiers (not global state)

```nim on:init
# Track keyboard state
var lastKey = "none"
var lastKeyCode = 0
var lastAction = "none"
var keyPressCount = 0
var lastModifiers = ""

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
# Handle keyboard events - use TextEvent for printable characters, KeyEvent for special keys
if event.type == "text":
  # Handle printable characters via TextEvent (optimal approach)
  lastKey = "'" & event.text & "'"
  lastKeyCode = 0
  lastAction = "text"
  keyPressCount = keyPressCount + 1
  lastKeyTime = getTime()
  typingBarWidth = 0.0
  keyPressFlashPhase = 0.0
  
  # Read modifiers directly from event (TextEvent now has mods field!)
  lastModifiers = ""
  var i = 0
  while i < len(event.mods):
    if i > 0:
      lastModifiers = lastModifiers & ", "
    lastModifiers = lastModifiers & event.mods[i]
    i = i + 1
  if lastModifiers == "":
    lastModifiers = "(none)"
  
  # Example: Detect specific characters with modifiers
  if event.text == "T":
    lastKey = "'T' (uppercase - Shift was pressed)"
  elif event.text == "t":
    lastKey = "'t' (lowercase)"
  
  # Check for quit (q or Q)
  if event.text == "q" or event.text == "Q":
    return false  # Allow default quit behavior
  
  return true

elif event.type == "key":
  # Handle special keys (arrows, escape, function keys, etc.)
  lastKeyCode = event.keyCode
  lastAction = event.action
  lastKeyTime = getTime()
  
  # Read modifiers directly from event (only available in KeyEvent)
  lastModifiers = ""
  var i = 0
  while i < len(event.mods):
    if i > 0:
      lastModifiers = lastModifiers & ", "
    lastModifiers = lastModifiers & event.mods[i]
    i = i + 1
  if lastModifiers == "":
    lastModifiers = "(none)"
  
  # Reset typing bar animation on new key press
  if event.action == "press":
    typingBarWidth = 0.0
    keyPressCount = keyPressCount + 1
    keyPressFlashPhase = 0.0
  
  # Convert keyCode to readable name using KEY_* constants
  if lastKeyCode == KEY_ESCAPE:
    lastKey = "ESC"
    return false  # Quit on escape
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
draw(0, 2, 6, "Press Q or ESC to quit")
draw(0, 2, 7, "Try modifiers: Shift+T, Ctrl+Arrow, etc.")

# === KEYBOARD STATE ===
draw(0, 2, 9, "Last Key: " & lastKey)
draw(0, 2, 10, "Key Code: " & str(lastKeyCode))
draw(0, 2, 11, "Action: " & lastAction)
draw(0, 2, 12, "Press Count: " & str(keyPressCount))

# === MODIFIER STATES ===
var modStr = "Modifiers: "
if len(lastModifiers) > 0:
  modStr = modStr & lastModifiers
else:
  modStr = modStr & "(none)"
draw(0, 2, 13, modStr)

# Draw a visual keyboard hint
draw(0, 2, 15, "Common Keys:")
draw(0, 4, 16, "Arrows: UP/DOWN/LEFT/RIGHT (try holding them!)")
draw(0, 4, 17, "Special: ESC, ENTER, SPACE, TAB, BACKSPACE, DELETE")
draw(0, 4, 18, "Letters: a-z, A-Z (TextEvents)")
draw(0, 4, 19, "Numbers: 0-9 (TextEvents)")
draw(0, 4, 20, "Try: Press 'T' or 'Shift+T' to see character detection!")

# === PRESS COUNTER BOX (with animation) ===
var boxY = 9
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
draw(0, 2, 22, "Typing Activity:")
draw(0, 2, 23, "[")
var barFilled = int(typingBarWidth)
i = 0
while i < barFilled:
  draw(0, 3 + i, 23, "=")
  i = i + 1
draw(0, 23, 23, "]")

# === ARROW KEY VISUAL ===
draw(0, 50, 15, "Arrow Keys Status:")
var arrowCenterX = 60
var arrowCenterY = 18

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
draw(0, 2, 25, "Last Action:")
if lastAction == "press":
  draw(0, 15, 25, ">>> KEY PRESSED <<<")
elif lastAction == "release":
  draw(0, 15, 25, ">>> KEY RELEASED <<<")
elif lastAction == "repeat":
  draw(0, 15, 25, ">>> KEY REPEATING <<<")
elif lastAction == "text":
  draw(0, 15, 25, ">>> TEXT INPUT <<<")

# Show time since last key
var timeSinceKey = getTime() - lastKeyTime
if timeSinceKey < 2.0:
  draw(0, 2, 26, "Time since last key: " & str(int(timeSinceKey * 1000)) & "ms")

# === INPUT SYSTEM INFO ===
draw(0, 2, termHeight - 4, "Input System: Unified event normalization across backends")
draw(0, 3, termHeight - 3, "TextEvent: Printable characters with event.mods array")
draw(0, 3, termHeight - 2, "KeyEvent: Special keys with event.mods array (shift, ctrl, alt, super)")
draw(0, 3, termHeight - 1, "Modifiers work on BOTH text and key events!")
```