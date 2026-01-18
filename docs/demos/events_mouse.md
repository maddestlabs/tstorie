---
title: "Mouse & Timing Events Demo"
theme: "catppuccin"
---

# Mouse & Timing Event Demo

This example demonstrates mouse event handling and frame-independent timing in tstorie.

```nim on:init
# Track mouse state
var mouseX = 0
var mouseY = 0
var lastButton = "none"
var lastAction = "none"
var clickCount = 0
var leftClicks = 0
var middleClicks = 0
var rightClicks = 0

# Animation state (frame-independent)
var boxPulsePhase = 0.0
var circleAngle = 0.0
var circleRadius = 5.0

# Click feedback animation
var clickFeedbackTime = 0.0
var clickFeedbackActive = false
var clickFeedbackX = 0
var clickFeedbackY = 0
```

```nim on:input
# Handle mouse events through the normal input lifecycle
if event.type == "mouse_move":
  # Update coordinates from mouse move events
  mouseX = event.x
  mouseY = event.y
  lastAction = "move"

if event.type == "mouse":
  lastButton = event.button
  lastAction = event.action
  
  if event.action == "press":
    clickCount = clickCount + 1
    
    # Count by button type
    if event.button == "left":
      leftClicks = leftClicks + 1
    elif event.button == "middle":
      middleClicks = middleClicks + 1
    elif event.button == "right":
      rightClicks = rightClicks + 1
    
    # Show click feedback animation
    clickFeedbackActive = true
    clickFeedbackTime = getTime()
    clickFeedbackX = mouseX
    clickFeedbackY = mouseY
    
    # Check if click was in the interactive box
    if mouseX >= 10 and mouseX <= 29 and mouseY >= 16 and mouseY <= 20:
      # Box was clicked!
      boxPulsePhase = 0.0

# Handle keyboard events with new KEY_* constants
if event.type == "key":
  if event.keyCode == KEY_ESCAPE or event.keyCode == KEY_Q:
    # ESC or Q to quit (demonstrates key constants)
    return false
```

```nim on:update
# Frame-independent animation using deltaTime
boxPulsePhase = boxPulsePhase + (deltaTime * 3.0)  # 3 cycles per second
circleAngle = circleAngle + (deltaTime * 2.0)      # Rotate at 2 rad/sec

# Decay click feedback
if clickFeedbackActive:
  if getTime() - clickFeedbackTime > 0.5:
    clickFeedbackActive = false
```

```nim on:render
clear()

# === HEADER ===
draw(0, 2, 1, "=== MOUSE & TIMING EVENT DEMO ===")

# === TIMING INFO ===
var fps = 60
if deltaTime > 0.0:
  fps = int(1.0 / deltaTime)
draw(0, 2, 3, "Time: " & str(int(getTime() * 1000)) & "ms | FPS: " & str(fps) & " | Frame: " & str(getFrameCount()))
draw(0, 2, 4, "Delta: " & str(int(deltaTime * 1000000)) & "us (microseconds)")

# === MOUSE STATE ===
draw(0, 2, 6, "Mouse Position: (" & str(mouseX) & ", " & str(mouseY) & ")")
draw(0, 2, 7, "Last Button: " & lastButton & " | Action: " & lastAction)
draw(0, 2, 8, "Total Clicks: " & str(clickCount) & " (L:" & str(leftClicks) & " M:" & str(middleClicks) & " R:" & str(rightClicks) & ")")

# === EVENT CONSTANTS INFO ===
draw(0, 2, 10, "Event Constants Available:")
draw(0, 3, 11, "- KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT")
draw(0, 3, 12, "- KEY_A through KEY_Z, KEY_0 through KEY_9")
draw(0, 3, 13, "- Mouse buttons: left, middle, right")

# === INTERACTIVE BOX (with pulse animation on click) ===
var boxY = 16
var pulseIntensity = 0
if boxPulsePhase < 6.28:  # One pulse cycle
  pulseIntensity = int(sin(boxPulsePhase) * sin(boxPulsePhase) * 100)

draw(0, 10, boxY - 1, "+------------------+")
var i = 0
while i < 5:
  draw(0, 10, boxY + i, "|                  |")
  i = i + 1
draw(0, 10, boxY + 4, "+------------------+")

# Box label with pulse effect
if pulseIntensity > 10:
  draw(0, 13, boxY + 2, "!!! CLICKED !!!")
else:
  draw(0, 13, boxY + 2, "  CLICK ME!  ")

# Hover detection
var isHovering = mouseX >= 10 and mouseX <= 29 and mouseY >= boxY and mouseY <= boxY + 4
if isHovering:
  draw(0, 11, boxY + 3, "   [HOVERING]   ")

# === ANIMATED CIRCLE (demonstrates frame-independent rotation) ===
var centerX = 50
var centerY = boxY + 2
draw(0, centerX - 8, boxY - 2, "Rotating Circle:")
draw(0, centerX - 10, boxY - 1, "(frame-independent)")

# Draw center point first
draw(0, centerX, centerY, "+")

# Draw circle using rotating point (make it more visible)
var angleRad = circleAngle
var offsetX = circleRadius * cos(angleRad)
var offsetY = circleRadius * sin(angleRad)
var cx = int(float(centerX) + offsetX)
var cy = int(float(centerY) + offsetY)

# Make sure coordinates are valid and draw
if cx >= 0 and cx < termWidth and cy >= 0 and cy < termHeight:
  draw(0, cx, cy, "@")

# === CLICK FEEDBACK ANIMATION ===
if clickFeedbackActive:
  var elapsed = getTime() - clickFeedbackTime
  var fadeProgress = elapsed / 0.5  # Fade over 500ms
  if fadeProgress < 1.0:
    # Expanding ring effect
    var ringSize = int(fadeProgress * 10.0)
    if ringSize > 0:
      # Draw expanding ring around click point
      draw(0, clickFeedbackX - ringSize, clickFeedbackY, "[")
      draw(0, clickFeedbackX + ringSize, clickFeedbackY, "]")
      if ringSize > 2:
        draw(0, clickFeedbackX, clickFeedbackY - ringSize / 2, "^")
        draw(0, clickFeedbackX, clickFeedbackY + ringSize / 2, "v")

# === INSTRUCTIONS ===
draw(0, 2, termHeight - 4, "Instructions:")
draw(0, 3, termHeight - 3, "- Move mouse around to see coordinates")
draw(0, 3, termHeight - 2, "- Click anywhere to see feedback animation")
draw(0, 3, termHeight - 1, "- Press ESC or Q to quit (using KEY_ESCAPE constant)")
```