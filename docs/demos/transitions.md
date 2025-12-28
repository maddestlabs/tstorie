# Manual Transitions Demo

Simple fade transition demo using character density instead of colors.
The screen gradually fades from blank to a checkerboard pattern using progressively denser characters.
Works in terminals with limited color support!

Press ESC to exit.

```nim on:init
var initialized = false
var startFrame = 0
```

```nim on:render
if not initialized:
  startFrame = getFrameCount()
  initialized = true

# Clear screen for clean rendering
clear()

# Calculate transition progress based on frame count
# Assuming ~60 FPS: 180 frames = 3 seconds
var elapsedFrames = getFrameCount() - startFrame
var cycleFrames = 360  # 6 seconds at 60fps (3s fade in + 3s fade out)
var frameInCycle = elapsedFrames % cycleFrames
var transitionProgress = 0.0

# First half: fade in (0 to 1)
# Second half: fade out (1 to 0)
if frameInCycle < 180:
  transitionProgress = float(frameInCycle) / 180.0
else:
  transitionProgress = 1.0 - (float(frameInCycle - 180) / 180.0)

# Apply easing (easeInOutQuad)
var t = transitionProgress
var easedProgress = 0.0
if t < 0.5:
  easedProgress = 2.0 * t * t
else:
  easedProgress = -1.0 + (4.0 - 2.0 * t) * t

# Manual transition: fade from dark to pattern using character density
# This works in terminals without full color support
# Character progression: " " -> "░" -> "▒" -> "▓" -> "█"
var chars = " ░▒▓█"
var charIndex = int(easedProgress * 4.0)
if charIndex > 4:
  charIndex = 4

var ch = " "
if charIndex == 0:
  ch = " "
elif charIndex == 1:
  ch = "░"
elif charIndex == 2:
  ch = "▒"
elif charIndex == 3:
  ch = "▓"
else:
  ch = "█"

var y = 0
while y < termHeight:
  var x = 0
  while x < termWidth:
    if (x + y) % 2 == 0:
      draw(0, x, y, ch, blue())
    x = x + 1
  y = y + 1

# Show status with progress percentage
var progressPercent = int(transitionProgress * 100.0)
var phase = "fading in"
if frameInCycle >= 180:
  phase = "fading out"
var statusText = "Transition: " & $progressPercent & "% (" & phase & ")"
draw(0, 5, 5, statusText)
```

```nim on:input
# ESC to quit is handled automatically by the engine
```