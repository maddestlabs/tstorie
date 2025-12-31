# TUI Widget Demo - Interactive Components

A comprehensive demonstration of the TUI widget system, showcasing buttons, sliders, text fields, checkboxes, and custom ASCII art styling.

## Sci-Fi Control Panel

```nim on:init
# Create widgets for a sci-fi themed control panel
var btn1 = newButton("btn_engage", 5, 3, 18, 3, "[ ENGAGE ]")
var btn2 = newButton("btn_abort", 5, 7, 18, 3, "[ ABORT ]")
var btn3 = newButton("btn_reset", 5, 11, 18, 3, "[ RESET ]")

# Power level slider (horizontal)
var powerSlider = newSlider("power", 30, 4, 25, 0.0, 100.0)
sliderSetValue(powerSlider, 75.0)
sliderSetShowValue(powerSlider, true)
sliderSetChars(powerSlider, "░", "▓", "█")

# Shield frequency slider (vertical)
var freqSlider = newVerticalSlider("freq", 62, 3, 12, 1.0, 10.0)
sliderSetValue(freqSlider, 5.5)
sliderSetShowValue(freqSlider, true)
sliderSetChars(freqSlider, "│", "║", "═")

# Status display text field
var statusField = newTextField(30, 8, 30)
textFieldSetText(statusField, "SYSTEMS NOMINAL")

# System checkboxes
var check1 = newCheckBox("shields", 30, 11, "Shield Array", true)
var check2 = newCheckBox("weapons", 30, 13, "Weapons Online", true)
var check3 = newCheckBox("life_support", 30, 15, "Life Support", true)
checkBoxSetChars(check1, "✓", "✗")
checkBoxSetChars(check2, "✓", "✗")
checkBoxSetChars(check3, "✓", "✗")

# Add all widgets to manager
addWidget(btn1)
addWidget(btn2)
addWidget(btn3)
addWidget(powerSlider)
addWidget(freqSlider)
addWidget(statusField)
addWidget(check1)
addWidget(check2)
addWidget(check3)

# Custom border using ASCII art patterns
var borderPattern = crackedBorderPattern(42, 0.3)

print("Sci-Fi Control Panel initialized!")
```

```nim on:render
# Clear layer
layerClear(2)

# Draw fancy cracked border around the entire panel
drawBorderFull(2, 0, 0, 70, 20, borderPattern)

# Draw section headers with ASCII art decoration
drawText(2, 5, 1, "╔═══ COMMANDS ═══╗", rgb(0, 255, 255))
drawText(2, 30, 1, "╔═════ STATUS ═════╗", rgb(0, 255, 255))
drawText(2, 62, 1, "╔══ FREQ ══╗", rgb(0, 255, 255))

# Draw slider labels
drawText(2, 30, 3, "POWER:", rgb(150, 150, 255))
drawText(2, 63, 16, "Hz", rgb(150, 150, 255))

# Render all widgets
renderWidgets()

# Draw dynamic status indicator
var statusColor = rgb(0, 255, 0)
if sliderGetValue(powerSlider) < 30.0:
  statusColor = rgb(255, 0, 0)
elif sliderGetValue(powerSlider) < 60.0:
  statusColor = rgb(255, 255, 0)

drawText(2, 30, 10, "PWR: " & $int(sliderGetValue(powerSlider)) & "%", statusColor)

# Draw shield frequency display
var freqVal = sliderGetValue(freqSlider)
drawText(2, 62, 2, $freqVal & " Hz", rgb(0, 255, 255))

# Draw animated scan line effect (using deltaTime)
var scanLine = int(getTime() * 2.0) mod 18
for x in 1..68:
  if x mod 4 == 0:  # Sparse dots
    drawText(2, x, 2 + scanLine, "·", rgb(0, 100, 200))
```

```nim on:update
# Update all widget states
updateWidgets(deltaTime)

# Simulate system dynamics
# If power is low, disable some systems
if sliderGetValue(powerSlider) < 25.0:
  if checkBoxIsChecked(check2):  # Auto-disable weapons
    checkBoxSetChecked(check2, false)
    textFieldSetText(statusField, "WEAPONS OFFLINE - LOW POWER")

# React to frequency changes
var freq = sliderGetValue(freqSlider)
if freq < 3.0 or freq > 8.0:
  textFieldSetText(statusField, "WARNING: FREQ OUT OF RANGE")
```

```nim on:input
# Handle widget interactions
# (Input handling would be connected through the widget manager's event system)

if keyPressed("r"):
  # Randomize settings using time-based variations
  var timeVal = getTime()
  var timeFrac = timeVal - float(int(timeVal))
  sliderSetValue(powerSlider, timeFrac * 100.0)
  sliderSetValue(freqSlider, 1.0 + (timeFrac * 9.0))
  textFieldSetText(statusField, "RANDOMIZED")

if keyPressed("f"):
  # Toggle shield focus
  checkBoxToggle(check1)
  if checkBoxIsChecked(check1):
    textFieldSetText(statusField, "SHIELDS RAISED")
  else:
    textFieldSetText(statusField, "SHIELDS DOWN")

if keyPressed("space"):
  # Regenerate border pattern using time-based seed
  var timeVal = getTime()
  var newSeed = int(timeVal * 1000.0) mod 1000
  var newDensity = 0.2 + ((timeVal - float(int(timeVal))) * 0.4)
  borderPattern = crackedBorderPattern(newSeed, newDensity)
```

## Retro Terminal Style

```nim on:init
# Alternative theme: Retro green terminal
var inputField = newTextField(10, 22, 50)
textFieldSetText(inputField, "> _")
textFieldSetFocused(inputField, true)
addWidget(inputField)

# Retro buttons with different chars
var termBtn1 = newButton("exec", 10, 24, 15, 3, "EXECUTE")
var termBtn2 = newButton("clear", 27, 24, 15, 3, "CLEAR")
var termBtn3 = newButton("exit", 44, 24, 15, 3, "EXIT")
addWidget(termBtn1)
addWidget(termBtn2)
addWidget(termBtn3)

# Simple progress bar mockup with slider
var progressBar = newSlider("progress", 10, 28, 49, 0.0, 100.0)
sliderSetValue(progressBar, 0.0)
sliderSetChars(progressBar, "-", "=", ">")
sliderSetShowValue(progressBar, true)
addWidget(progressBar)
```

```nim on:render
# Retro terminal section
drawText(2, 8, 20, "╔" & "═".repeat(54) & "╗", rgb(0, 255, 0))
drawText(2, 8, 21, "║", rgb(0, 255, 0))
drawText(2, 62, 21, "║", rgb(0, 255, 0))
drawText(2, 8, 29, "╚" & "═".repeat(54) & "╝", rgb(0, 255, 0))

for i in 22..28:
  drawText(2, 8, i, "║", rgb(0, 255, 0))
  drawText(2, 62, i, "║", rgb(0, 255, 0))

# Render terminal widgets
renderWidgets()

# Simulate progress bar animation
var progress = sliderGetValue(progressBar)
if progress < 100.0:
  sliderSetValue(progressBar, progress + deltaTime * 10.0)
```

## Widget Customization Examples

```nim on:init
# Custom styled checkbox with ASCII art
var fancyCheck = newCheckBox("fancy", 72, 3, "Fancy Mode", false)
checkBoxSetChars(fancyCheck, "◉", "◯")  # Filled/empty circles
addWidget(fancyCheck)

# Radio button group for theme selection
var radio1 = newRadioButton("theme_scifi", 72, 6, "Sci-Fi", "theme")
var radio2 = newRadioButton("theme_retro", 72, 8, "Retro", "theme")
var radio3 = newRadioButton("theme_cyber", 72, 10, "Cyber", "theme")
checkBoxSetChecked(radio1, true)  # Default selection
addWidget(radio1)
addWidget(radio2)
addWidget(radio3)

# Mini slider for opacity
var opacitySlider = newSlider("opacity", 72, 13, 15, 0.0, 1.0)
sliderSetValue(opacitySlider, 1.0)
sliderSetChars(opacitySlider, "·", "━", "●")
addWidget(opacitySlider)
```

```nim on:render
# Customization panel
drawText(2, 70, 1, "╔═ OPTIONS ═╗", rgb(255, 255, 0))
drawText(2, 70, 5, "─ THEME ─", rgb(255, 255, 0))
drawText(2, 70, 12, "OPACITY:", rgb(255, 255, 0))

renderWidgets()

# Show current opacity value
var opacity = sliderGetValue(opacitySlider)
drawText(2, 70, 14, $int(opacity * 100) & "%", rgb(255, 255, 0))
```

## Instructions

- **R**: Randomize main panel settings
- **F**: Toggle shields
- **Space**: Regenerate border pattern
- **Tab**: Cycle focus between widgets
- **Arrow Keys**: Navigate sliders
- **Enter**: Activate focused button
- **Mouse**: Click widgets directly

This demo shows:
1. Multiple widget types working together
2. Custom ASCII art borders integrated with widgets
3. Dynamic styling based on state
4. Themed widget configurations
5. Real-time updates and animations

Try combining different ASCII art patterns with widget styles to create unique UI aesthetics!
