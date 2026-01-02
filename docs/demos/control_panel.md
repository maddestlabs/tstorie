# Control Panel Demo

```nim on:init
# Create three buttons
var btnStart = newButton("start", 5, 6, 16, 3, "[ START ]")
addWidget(btnStart)

var btnStop = newButton("stop", 5, 10, 16, 3, "[ STOP ]")
addWidget(btnStop)

var btnReset = newButton("reset", 5, 14, 16, 3, "[ RESET ]")
addWidget(btnReset)

# Create a slider
var powerSlider = newSlider("power", 30, 7, 30, 0.0, 100.0)
sliderSetValue(powerSlider, 50.0)
sliderSetShowValue(powerSlider, true)
sliderSetChars(powerSlider, "-", "=", ">")
addWidget(powerSlider)

# Create checkboxes
var shieldsCheck = newCheckBox("shields", 30, 11, "Shields Active", true)
checkBoxSetChars(shieldsCheck, "X", " ")
addWidget(shieldsCheck)

var weaponsCheck = newCheckBox("weapons", 30, 13, "Weapons Online", false)
checkBoxSetChars(weaponsCheck, "X", " ")
addWidget(weaponsCheck)
```

```nim on:render
# Title
draw(0, 2, 1, "=== CONTROL PANEL ===", defaultStyle())

# Labels
draw(0, 30, 5, "Power Level:", defaultStyle())
draw(0, 30, 9, "Systems:", defaultStyle())

# Render all widgets
renderWidgets()
```
