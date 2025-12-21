# Transition Helpers Demo

Simple color fade transition using the animation helper functions.

Press SPACE to start a new transition, ESC to exit.

```nim on:init
var trans = 0  # Will store transition ID
var fromColor = 0  # 0=red, 1=green, 2=blue
var toColor = 1
```

```nim on:render
fgClear()

# Get transition progress
var t = 1.0  # Default to fully transitioned
if trans != 0:
  if nimini_transitionIsActive(trans):
    t = nimini_transitionEasedProgress(trans)

# Define colors (RGB values)  
var redR = 255
var redG = 0
var redB = 0
var greenR = 0
var greenG = 255
var greenB = 0
var blueR = 0
var blueG = 0
var blueB = 255

# Select from/to colors based on state
var fromR = redR
var fromG = redG
var fromB = redB
var toR = greenR
var toG = greenG
var toB = greenB

if fromColor == 1:
  fromR = greenR
  fromG = greenG
  fromB = greenB
if fromColor == 2:
  fromR = blueR
  fromG = blueG
  fromB = blueB

if toColor == 1:
  toR = greenR
  toG = greenG
  toB = greenB
if toColor == 2:
  toR = blueR
  toG = blueG
  toB = blueB

# Interpolate between colors
var r = nimini_lerpInt(fromR, toR, t)
var g = nimini_lerpInt(fromG, toG, t)
var b = nimini_lerpInt(fromB, toB, t)

# Fill screen with interpolated color
var style = Style(fg: rgb(r, g, b), bg: black())
for y in 0 ..< termHeight:
  for x in 0 ..< termWidth:
    fgWrite(x, y, "█", style)

# Show instructions
var textStyle = Style(fg: white(), bg: black(), bold: true)
fgWriteText(5, 5, "Transition Helpers Demo", textStyle)
fgWriteText(5, 7, "SPACE = New transition", textStyle)
fgWriteText(5, 8, "ESC = Exit", textStyle)

# Show progress
var progressPct = int(t * 100.0)
var progressText = "Progress: " & str(progressPct) & "%"
fgWriteText(5, 10, progressText, textStyle)
```

```nim on:update
if trans != 0:
  nimini_updateTransition(trans, deltaTime)
```

```nim on:input
# SPACE key triggers a new transition (ESC to quit is handled by default)
if event.type == "key" and event.action == "press":
  if event.keyCode == 32:  # SPACE key
    # Start new transition
    trans = nimini_newTransition(1.5, EASE_IN_OUT_CUBIC)
    
    # Cycle colors
    fromColor = toColor
    toColor = (toColor + 1) mod 3
```
