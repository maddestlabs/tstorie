---
title: "Timing & Events Demo"
theme: "catppuccin"
shaders: "invert+ruledlines+paper+lightnight"
fontsize: 16
---

This example demonstrates comprehensive event handling including keyboard, mouse, and timing systems with SDL3-compatible constants.

```nim on:init
# === MOUSE STATE ===
var mouseButton = "none"
var mouseAction = "none"
var totalClicks = 0
var leftClicks = 0
var middleClicks = 0
var rightClicks = 0

# === KEYBOARD STATE ===
var lastKey = "none"
var lastKeyCode = 0
var lastKeyAction = "none"
var keyPressCount = 0
var lastModifiers = ""

# === ANIMATION STATE (frame-independent) ===
var clickRippleTime = 0.0
var clickRippleActive = false
var clickRippleX = 0
var clickRippleY = 0
var keyFlashPhase = 0.0
var rotationAngle = 0.0
var pulsePhase = 0.0

# === INTERACTIVE ELEMENTS ===
var boxX = 10
var boxY = 16
var boxWidth = 20
var boxHeight = 5
var boxHovered = false
var boxClicked = false
var boxClickTime = 0.0
var boxDragging = false
var boxDragOffsetX = 0
var boxDragOffsetY = 0

# === SPECIAL EVENT DETECTION ===
var shiftQDetected = false
var ctrlMouseDetected = false
var mouseWheelDir = "none"
var mouseWheelTime = 0.0

# === ARROW KEY STATE ===
var arrowUp = false
var arrowDown = false
var arrowLeft = false
var arrowRight = false
```

```nim on:input
# === KEYBOARD EVENTS (TextEvent first for printable characters) ===
if event.type == "text":
  lastKey = "'" & event.text & "'"
  lastKeyAction = "text"
  keyPressCount = keyPressCount + 1
  
  # Read modifiers from event
  lastModifiers = ""
  var i = 0
  while i < len(event.mods):
    if i > 0:
      lastModifiers = lastModifiers & ", "
    lastModifiers = lastModifiers & event.mods[i]
    i = i + 1
  
  # SPECIAL: Shift+Q detection (uppercase Q implies Shift was pressed)
  if event.text == "Q":
    shiftQDetected = true
  
  return true

elif event.type == "key":
  lastKeyCode = event.keyCode
  lastKeyAction = event.action
  
  # Read modifiers from event
  lastModifiers = ""
  var i = 0
  while i < len(event.mods):
    if i > 0:
      lastModifiers = lastModifiers & ", "
    lastModifiers = lastModifiers & event.mods[i]
    i = i + 1
  
  # Track arrow key states
  if lastKeyCode == KEY_UP:
    arrowUp = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode == KEY_DOWN:
    arrowDown = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode == KEY_LEFT:
    arrowLeft = (event.action == "press" or event.action == "repeat")
  elif lastKeyCode == KEY_RIGHT:
    arrowRight = (event.action == "press" or event.action == "repeat")
  
  # Clear arrow states on release
  if event.action == "release":
    if lastKeyCode == KEY_UP:
      arrowUp = false
    elif lastKeyCode == KEY_DOWN:
      arrowDown = false
    elif lastKeyCode == KEY_LEFT:
      arrowLeft = false
    elif lastKeyCode == KEY_RIGHT:
      arrowRight = false
  
  # Convert keyCode to readable name
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
  elif lastKeyCode == KEY_UP:
    lastKey = "UP"
  elif lastKeyCode == KEY_DOWN:
    lastKey = "DOWN"
  elif lastKeyCode == KEY_LEFT:
    lastKey = "LEFT"
  elif lastKeyCode == KEY_RIGHT:
    lastKey = "RIGHT"
  else:
    lastKey = "KEY_" & str(lastKeyCode)
  
  if event.action == "press":
    keyPressCount = keyPressCount + 1
    keyFlashPhase = 0.0  # Start flash animation
  
  # Quit on ESC only
  if event.keyCode == KEY_ESCAPE:
    return false
  
  return true

# === MOUSE EVENTS ===
elif event.type == "mouse_move":
  
  # Handle box dragging
  if boxDragging:
    boxX = mouseX - boxDragOffsetX
    boxY = mouseY - boxDragOffsetY
    # Keep box on screen
    if boxX < 0:
      boxX = 0
    if boxY < 0:
      boxY = 0
    if boxX + boxWidth >= termWidth:
      boxX = termWidth - boxWidth - 1
    if boxY + boxHeight >= termHeight:
      boxY = termHeight - boxHeight - 1
  
  # Check box hover
  boxHovered = mouseX >= boxX and mouseX < boxX + boxWidth and mouseY >= boxY and mouseY < boxY + boxHeight

if event.type == "mouse":
  mouseButton = event.button
  mouseAction = event.action
  
  if event.action == "press":
    totalClicks = totalClicks + 1
    
    # Count by button
    if event.button == "left":
      leftClicks = leftClicks + 1
      
      # Start dragging if clicking on box
      if boxHovered:
        boxDragging = true
        boxDragOffsetX = mouseX - boxX
        boxDragOffsetY = mouseY - boxY
    elif event.button == "middle":
      middleClicks = middleClicks + 1
    elif event.button == "right":
      rightClicks = rightClicks + 1
    
    # Start ripple animation
    clickRippleActive = true
    clickRippleTime = getTime()
    clickRippleX = mouseX
    clickRippleY = mouseY
    
    # Check if box was clicked
    if boxHovered:
      boxClicked = true
      boxClickTime = getTime()
    
    # SPECIAL: CTRL + Mouse click detection
    var ctrlHeld = false
    var j = 0
    while j < len(event.mods):
      if event.mods[j] == "ctrl":
        ctrlHeld = true
      j = j + 1
    if ctrlHeld:
      ctrlMouseDetected = true
  
  elif event.action == "release":
    # Stop dragging on mouse release
    if event.button == "left":
      boxDragging = false
  
  return true

elif event.type == "mouse" and (event.button == "scroll_up" or event.button == "scroll_down"):
  # Mouse wheel event detection
  if event.button == "scroll_up":
    mouseWheelDir = "up"
  else:
    mouseWheelDir = "down"
  mouseWheelTime = getTime()
  return true

return true
```

```nim on:update
# Frame-independent animations
keyFlashPhase = keyFlashPhase + (deltaTime * 8.0)
rotationAngle = rotationAngle + (deltaTime * 2.0)
pulsePhase = pulsePhase + (deltaTime * 3.0)

# Decay click ripple
if clickRippleActive:
  if getTime() - clickRippleTime > 1.0:
    clickRippleActive = false

# Decay box click effect
if boxClicked:
  if getTime() - boxClickTime > 0.5:
    boxClicked = false

# Decay special event indicators
if shiftQDetected:
  if getTime() - keyFlashPhase > 2.0:
    shiftQDetected = false

if ctrlMouseDetected:
  if getTime() - clickRippleTime > 2.0:
    ctrlMouseDetected = false

if mouseWheelDir != "none":
  if getTime() - mouseWheelTime > 1.5:
    mouseWheelDir = "none"
```

```nim on:render
clear()

# === HEADER ===
draw(0, 2, 1, "=== COMPLETE EVENTS DEMO ===")
draw(0, 2, 2, "Time: " & str(int(getTimeMs())) & "ms | FPS: " & str(int(getFps())) & " | Frame: " & str(getFrameCount()))
draw(0, 2, 3, "Delta: " & str(int(getDeltaTime() * 1000000.0)) & "us")

# === MOUSE STATE ===
draw(0, 2, 5, "=== MOUSE ===")
draw(0, 2, 6, "Position: (" & str(mouseX) & ", " & str(mouseY) & ")")
draw(0, 2, 7, "Button: " & mouseButton & " | Action: " & mouseAction)
draw(0, 2, 8, "Clicks: " & str(totalClicks) & " (L:" & str(leftClicks) & " M:" & str(middleClicks) & " R:" & str(rightClicks) & ")")

# === KEYBOARD STATE ===
draw(0, 2, 10, "=== KEYBOARD ===")
draw(0, 2, 11, "Last Key: " & lastKey & " (code: " & str(lastKeyCode) & ")")
draw(0, 2, 12, "Action: " & lastKeyAction & " | Total: " & str(keyPressCount))

# Modifiers (read from last event)
var modStr = "Modifiers: "
if len(lastModifiers) > 0:
  modStr = modStr & lastModifiers
else:
  modStr = modStr & "(none)"
draw(0, 2, 13, modStr)

# === INTERACTIVE BOX ===
draw(0, boxX, boxY - 1, "+--------------------+")
var i = 0
while i < boxHeight:
  draw(0, boxX, boxY + i, "|                    |")
  i = i + 1
draw(0, boxX, boxY + boxHeight, "+--------------------+")

# Box label with state
var boxLabel = "  INTERACTIVE BOX  "
if boxDragging:
  boxLabel = "   === DRAG ME === "
elif boxClicked:
  boxLabel = "   *** CLICKED! *** "
elif boxHovered:
  boxLabel = "    >> HOVER <<     "
draw(0, boxX + 1, boxY + 2, boxLabel)

# Drag instruction
if boxHovered and not boxDragging:
  draw(0, boxX + 2, boxY + 3, "(Click & drag me!)")

# Pulse effect when clicked
if boxClicked:
  var intensity = int(sin(pulsePhase * 2.0) * sin(pulsePhase * 2.0) * 100)
  if intensity > 30:
    draw(0, boxX - 2, boxY + 2, ">>")
    draw(0, boxX + boxWidth + 1, boxY + 2, "<<")

# === ARROW KEY VISUAL ===
var arrowCenterX = 50
var arrowCenterY = 10

draw(0, arrowCenterX - 8, arrowCenterY - 2, "Arrow Keys:")

# Draw arrow indicators
if arrowUp:
  draw(0, arrowCenterX, arrowCenterY - 2, "^")
  draw(0, arrowCenterX, arrowCenterY - 1, "|")
if arrowDown:
  draw(0, arrowCenterX, arrowCenterY + 1, "|")
  draw(0, arrowCenterX, arrowCenterY + 2, "v")
if arrowLeft:
  draw(0, arrowCenterX - 2, arrowCenterY, "<")
  draw(0, arrowCenterX - 1, arrowCenterY, "-")
if arrowRight:
  draw(0, arrowCenterX + 1, arrowCenterY, "-")
  draw(0, arrowCenterX + 2, arrowCenterY, ">")

# Center point
draw(0, arrowCenterX, arrowCenterY, "+")

# Rotating indicator when arrows held
if arrowUp or arrowDown or arrowLeft or arrowRight:
  var rotX = int(float(arrowCenterX) + 5.0 * cos(rotationAngle))
  var rotY = int(float(arrowCenterY) + 2.5 * sin(rotationAngle))
  if rotX >= 0 and rotX < termWidth and rotY >= 0 and rotY < termHeight:
    draw(0, rotX, rotY, "*")

# === KEY FLASH INDICATOR ===
var flashIntensity = 0
if keyFlashPhase < 6.28:
  flashIntensity = int(sin(keyFlashPhase) * sin(keyFlashPhase) * 100)
if flashIntensity > 30:
  draw(0, 50, 13, ">>> KEY PRESSED <<<")

# === CLICK RIPPLE ANIMATION ===
if clickRippleActive:
  var elapsed = getTime() - clickRippleTime
  var progress = elapsed / 1.0  # 1 second duration
  
  if progress < 1.0:
    var rippleSize = int(progress * 15.0)
    if rippleSize > 0:
      # Expanding diamond/square pattern
      var cx = clickRippleX
      var cy = clickRippleY
      
      if cx - rippleSize >= 0 and cy >= 0 and cy < termHeight:
        draw(0, cx - rippleSize, cy, "[")
      if cx + rippleSize < termWidth and cy >= 0 and cy < termHeight:
        draw(0, cx + rippleSize, cy, "]")
      
      if rippleSize > 3:
        var halfSize = rippleSize / 2
        if cx >= 0 and cx < termWidth and cy - halfSize >= 0:
          draw(0, cx, cy - halfSize, "^")
        if cx >= 0 and cx < termWidth and cy + halfSize < termHeight:
          draw(0, cx, cy + halfSize, "v")

# === CURSOR CROSSHAIR ===
# Draw subtle crosshair at mouse position
if mouseX > 0 and mouseX < termWidth - 1:
  draw(0, mouseX - 1, mouseY, "-")
  draw(0, mouseX + 1, mouseY, "-")
if mouseY > 0 and mouseY < termHeight - 1:
  draw(0, mouseX, mouseY - 1, "|")
  draw(0, mouseX, mouseY + 1, "|")
draw(0, mouseX, mouseY, "+")

# === SPECIAL EVENT DETECTIONS ===
draw(0, 50, 16, "=== SPECIAL EVENTS ===")

# Q detection (simplified)
if shiftQDetected:
  draw(0, 50, 17, ">>> Q KEY <<<")
  draw(0, 50, 18, "  DETECTED!  ")
else:
  draw(0, 50, 17, "Try: Press Q")

# CTRL + Mouse detection
if ctrlMouseDetected:
  draw(0, 50, 20, ">>> CTRL + MOUSE <<<")
  draw(0, 50, 21, "    DETECTED!    ")
else:
  draw(0, 50, 20, "Try: CTRL + Click")

# Mouse wheel detection
if mouseWheelDir != "none":
  draw(0, 50, 23, ">>> MOUSE WHEEL <<<")
  if mouseWheelDir == "up":
    draw(0, 50, 24, "  SCROLL UP ^^^  ")
  else:
    draw(0, 50, 24, "  SCROLL DOWN vvv")
else:
  draw(0, 50, 23, "Try: Mouse Wheel")

# === INSTRUCTIONS ===
draw(0, 2, termHeight - 5, "=== INSTRUCTIONS ===")
draw(0, 2, termHeight - 4, "Mouse: Click & drag the interactive box, scroll wheel, try CTRL+Click")
draw(0, 2, termHeight - 3, "Keyboard: Press any key, use arrow keys, try SHIFT+Q, modifiers (Shift/Ctrl/Alt)")
draw(0, 2, termHeight - 2, "Press ESC or Q to quit (SHIFT+Q shows special event detection)")
draw(0, 2, termHeight - 1, "Using SDL3-compatible KEY_* constants and frame-independent timing")
```

```nim on:shutdown
# Cleanup
```

---

## What This Demo Shows

### ✅ Complete Event Handling
- **Mouse Events:** Position tracking, button detection, click counting, drag & drop
- **Mouse Wheel:** Scroll detection with visual feedback
- **Keyboard Events:** Key codes, actions (press/release/repeat), text input
- **Modifier Keys:** Real-time Shift, Ctrl, Alt detection
- **Arrow Keys:** Visual compass showing which arrows are held

### ✅ Special Event Detection Examples
- **SHIFT + Q:** Modifier + key combination detection (reference pattern)
- **CTRL + Mouse Click:** Modifier + mouse button combination
- **Mouse Wheel Up/Down:** Scroll event handling with direction detection
- These patterns can be used as reference for implementing custom key/mouse combinations

### ✅ SDL3-Compatible API
- **KEY_* Constants:** `KEY_ESCAPE`, `KEY_Q`, `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`, etc.
- **Event Types:** Proper discrimination between "mouse", "mouse_move", "scroll", "key", and "text"
- **Modern Design:** Ready for both terminal (current) and SDL3 graphical (future) backends

### ✅ Frame-Independent Animations
- **Click Ripple:** Expanding diamond pattern from click location
- **Key Flash:** Pulsing indicator when keys are pressed
- **Rotating Star:** Spins around arrow compass when arrows are held
- **Box Pulse:** Expanding brackets when interactive box is clicked
- **All animations scale with `deltaTime`** for smooth, consistent motion

### ✅ Interactive Elements
- **Draggable Box:** Click and drag to move around the screen (full drag & drop implementation)
- **Hover Detection:** Visual feedback when mouse is over interactive elements
- **Cursor Crosshair:** Follows mouse with subtle indicators
- **Arrow Compass:** Real-time visual for arrow key states
- **Ripple Effect:** Beautiful expanding animation on every click
- **Special Event Indicators:** Visual confirmation of special key/mouse combinations

### ✅ Timing System Integration
- **getTime():** Monotonic time for animation tracking
- **getDeltaTime():** Frame-independent animation scaling
- **getTimeMs():** Millisecond precision for display
- **getFps():** Real-time FPS monitoring
- **getFrameCount():** Total frames rendered

This demo combines all event handling capabilities into one comprehensive example, showing how mouse and keyboard events work together with modern timing APIs. It serves as a complete reference for implementing custom event combinations and interactions.
