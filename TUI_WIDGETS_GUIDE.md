# TUI Widgets Guide - Interactive UI Components for tStorie

Complete guide to using TUI widgets in nimini scripts, enabling rapid prototyping of interactive interfaces with the Rebuild Pattern workflow.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Widget Manager](#widget-manager)
3. [Button Widget](#button-widget)
4. [Slider Widget](#slider-widget)
5. [TextField Widget](#textfield-widget)
6. [CheckBox & RadioButton](#checkbox--radiobutton)
7. [ProgressBar Widget](#progressbar-widget)
8. [Label Widget](#label-widget)
9. [Generic Widget Operations](#generic-widget-operations)
10. [Integration with ASCII Art](#integration-with-ascii-art)
11. [The Rebuild Pattern for Widgets](#the-rebuild-pattern-for-widgets)

---

## Quick Start

### Basic Widget Example

```nim on:init
# Create a button
var myButton = newButton("btn1", 10, 5, 20, 3, "Click Me!")

# Add to widget manager
addWidget(myButton)
```

```nim on:render
# Render all widgets
renderWidgets()
```

```nim on:update
# Update all widgets
updateWidgets(deltaTime)
```

---

## Widget Manager

The widget manager handles widget lifecycle, focus, and event routing.

### Functions

- `newWidgetManager()` - Create widget manager (usually automatic)
- `addWidget(widget)` - Add a widget to the manager
- `removeWidget(widgetId)` - Remove widget by ID
- `focusWidget(widgetId)` - Focus a specific widget
- `updateWidgets(deltaTime)` - Update all widgets
- `renderWidgets()` - Render all widgets to current layer

### Example

```nim on:init
# Widgets are automatically added to the global manager
var btn1 = newButton("submit", 10, 10, 15, 3, "Submit")
var btn2 = newButton("cancel", 30, 10, 15, 3, "Cancel")

addWidget(btn1)
addWidget(btn2)

# Focus the submit button
focusWidget("submit")
```

---

## Button Widget

Interactive button with label, borders, and click events.

### Constructor

```nim
newButton(id, x, y, width, height, label)
```

**Parameters:**
- `id` (string) - Unique widget identifier
- `x`, `y` (int) - Position
- `width`, `height` (int) - Size
- `label` (string, optional) - Button text (default: "Button")

### Functions

- `buttonSetLabel(button, label)` - Change button text
- `buttonSetOnClick(button, callback)` - Set click handler (TODO)

### Example

```nim on:init
var engageBtn = newButton("engage", 20, 5, 22, 3, "[ ENGAGE WARP ]")
var abortBtn = newButton("abort", 20, 9, 22, 3, "[ ABORT ]")

addWidget(engageBtn)
addWidget(abortBtn)

# Customize appearance
widgetSetEnabled(abortBtn, false)  # Disabled until ready
```

---

## Slider Widget

Adjustable numeric value control, horizontal or vertical.

### Constructors

```nim
newSlider(id, x, y, length, minValue, maxValue)
newVerticalSlider(id, x, y, length, minValue, maxValue)
```

**Parameters:**
- `id` (string) - Unique widget identifier
- `x`, `y` (int) - Position
- `length` (int) - Length of the slider track
- `minValue`, `maxValue` (float) - Value range

### Functions

- `sliderGetValue(slider)` → float - Get current value
- `sliderSetValue(slider, value)` - Set value programmatically
- `sliderSetShowValue(slider, show)` - Toggle numeric display
- `sliderSetChars(slider, trackChar, fillChar, handleChar)` - Customize appearance

### Example

```nim on:init
# Power level slider
var powerSlider = newSlider("power", 10, 5, 30, 0.0, 100.0)
sliderSetValue(powerSlider, 75.0)
sliderSetShowValue(powerSlider, true)
sliderSetChars(powerSlider, "░", "▓", "█")
addWidget(powerSlider)

# Vertical frequency slider
var freqSlider = newVerticalSlider("freq", 50, 5, 15, 1.0, 10.0)
sliderSetValue(freqSlider, 5.5)
sliderSetChars(freqSlider, "│", "║", "═")
addWidget(freqSlider)
```

```nim on:render
# Display slider value with custom formatting
var power = sliderGetValue(powerSlider)
drawText(2, 10, 7, "Power: " & $int(power) & "%", rgb(0, 255, 0))

var freq = sliderGetValue(freqSlider)
drawText(2, 50, 21, $freq & " Hz", rgb(0, 255, 255))
```

---

## TextField Widget

Single-line text input with cursor navigation.

### Constructor

```nim
newTextField(x, y, width)
```

**Parameters:**
- `x`, `y` (int) - Position
- `width` (int) - Field width

### Functions

- `textFieldGetText(textField)` → string - Get current text
- `textFieldSetText(textField, text)` - Set text programmatically
- `textFieldClear(textField)` - Clear all text
- `textFieldSetFocused(textField, focused)` - Set focus state

### Example

```nim on:init
var nameField = newTextField(20, 10, 30)
textFieldSetText(nameField, "Enter name...")
addWidget(nameField)

var commandField = newTextField(5, 20, 60)
textFieldSetFocused(commandField, true)  # Start focused
addWidget(commandField)
```

```nim on:input
if keyPressed("enter"):
  var text = textFieldGetText(commandField)
  print("Command entered: " & text)
  textFieldClear(commandField)
```

---

## CheckBox & RadioButton

Toggleable boolean controls and mutually-exclusive radio groups.

### Constructors

```nim
newCheckBox(id, x, y, label, checked)
newRadioButton(id, x, y, label, group)
```

**Parameters:**
- `id` (string) - Unique widget identifier
- `x`, `y` (int) - Position
- `label` (string, optional) - Text label
- `checked` (bool, optional) - Initial state (checkbox only)
- `group` (string, optional) - Radio group name

### Functions

- `checkBoxIsChecked(checkBox)` → bool - Get checked state
- `checkBoxSetChecked(checkBox, checked)` - Set state
- `checkBoxToggle(checkBox)` - Toggle state
- `checkBoxSetChars(checkBox, checkedChar, uncheckedChar)` - Customize appearance

### Example

```nim on:init
# System toggles
var shieldsCheck = newCheckBox("shields", 10, 5, "Shield Array", true)
var weaponsCheck = newCheckBox("weapons", 10, 7, "Weapons Online", true)
checkBoxSetChars(shieldsCheck, "✓", "✗")
checkBoxSetChars(weaponsCheck, "✓", "✗")
addWidget(shieldsCheck)
addWidget(weaponsCheck)

# Difficulty selection
var easyRadio = newRadioButton("easy", 10, 12, "Easy", "difficulty")
var normalRadio = newRadioButton("normal", 10, 14, "Normal", "difficulty")
var hardRadio = newRadioButton("hard", 10, 16, "Hard", "difficulty")
checkBoxSetChecked(normalRadio, true)  # Default selection
addWidget(easyRadio)
addWidget(normalRadio)
addWidget(hardRadio)
```

```nim on:update
# React to checkbox state
if not checkBoxIsChecked(shieldsCheck):
  # Shields are down - take damage!
  health = health - deltaTime * 10.0
```

---

## ProgressBar Widget

Visual progress indicator, horizontal or vertical.

### Constructor

```nim
newProgressBar(id, x, y, length, orientation)
```

**Parameters:**
- `id` (string) - Unique widget identifier
- `x`, `y` (int) - Position
- `length` (int) - Bar length
- `orientation` (string, optional) - "horizontal" (default) or "vertical"

### Functions

- `progressBarSetValue(progressBar, value)` - Set raw value
- `progressBarSetProgress(progressBar, progress)` - Set normalized progress (0.0-1.0)
- `progressBarGetProgress(progressBar)` → float - Get normalized progress
- `progressBarSetText(progressBar, text)` - Set overlay text
- `progressBarSetShowPercentage(progressBar, show)` - Toggle percentage display
- `progressBarSetChars(progressBar, emptyChar, fillChar, leftCap, rightCap)` - Customize appearance

### Example

```nim on:init
# Health bar
var healthBar = newProgressBar("health", 10, 2, 40, "horizontal")
progressBarSetProgress(healthBar, 1.0)  # Full health
progressBarSetShowPercentage(healthBar, true)
progressBarSetChars(healthBar, "░", "█", "[", "]")
addWidget(healthBar)

# Loading bar
var loadBar = newProgressBar("load", 10, 5, 50, "horizontal")
progressBarSetChars(loadBar, "-", "=", "|", "|")
progressBarSetText(loadBar, "LOADING...")
addWidget(loadBar)

# Vertical fuel gauge
var fuelGauge = newProgressBar("fuel", 70, 5, 20, "vertical")
progressBarSetProgress(fuelGauge, 0.6)
progressBarSetChars(fuelGauge, "│", "║", "▲", "▼")
addWidget(fuelGauge)
```

```nim on:update
# Animate loading
var progress = progressBarGetProgress(loadBar)
if progress < 1.0:
  progressBarSetProgress(loadBar, progress + deltaTime * 0.2)
else:
  progressBarSetText(loadBar, "COMPLETE")
```

---

## Label Widget

Static text display (already in lib/tui.nim, exported automatically).

### Usage

Labels are created through the base Widget constructor with custom rendering. For now, use `drawText()` for static text or implement Label bindings if needed.

---

## Generic Widget Operations

These functions work on any widget type.

### Functions

- `widgetSetVisible(widget, visible)` - Show/hide widget
- `widgetSetEnabled(widget, enabled)` - Enable/disable widget
- `widgetSetPosition(widget, x, y)` - Move widget
- `widgetSetSize(widget, width, height)` - Resize widget

### Example

```nim on:init
var secretButton = newButton("secret", 50, 10, 15, 3, "Secret")
widgetSetVisible(secretButton, false)  # Hidden by default
addWidget(secretButton)
```

```nim on:input
if keyPressed("~"):
  # Toggle secret menu
  var isVisible = secretButton.visible  # TODO: Add getter
  widgetSetVisible(secretButton, not isVisible)
```

---

## Integration with ASCII Art

Combine TUI widgets with ASCII art patterns for stunning custom UIs.

### Example: Custom Button Borders

```nim on:init
import random

# Create button
var fancyBtn = newButton("fancy", 20, 10, 30, 5, "FANCY BUTTON")
addWidget(fancyBtn)

# Generate custom border pattern
random.randomize(42)
var borderPattern = crackedBorderPattern(42, 0.3)
```

```nim on:render
# Draw custom border around button
var btnX = 19
var btnY = 9
var btnW = 32
var btnH = 7

drawBorderFull(2, btnX, btnY, btnW, btnH, borderPattern)

# Render button on top
renderWidgets()
```

### Example: Themed Control Panel

```nim on:init
# Sci-fi panel with modulo patterns
var panel1Pattern = moduloPattern(7, 3, BoxDrawing.light, 42)
var panel2Pattern = moduloPattern(5, 5, BoxDrawing.heavy, 84)

var powerBtn = newButton("power", 10, 5, 15, 3, "POWER")
var systemBtn = newButton("system", 10, 10, 15, 3, "SYSTEMS")
addWidget(powerBtn)
addWidget(systemBtn)
```

```nim on:render
# Panel 1 background
drawBorderFull(1, 5, 3, 25, 8, panel1Pattern)

# Panel 2 background
drawBorderFull(1, 5, 12, 25, 8, panel2Pattern)

# Widgets on top layer
renderWidgets()
```

### Example: Dynamic Pattern Updates

```nim on:input
if keyPressed("space"):
  # Regenerate border on spacebar
  random.randomize()
  borderPattern = crackedBorderPattern(random.rand(100), 0.2 + random.rand(0.4))
```

---

## The Rebuild Pattern for Widgets

The same workflow from the ASCII art system applies to widgets!

### Workflow

1. **Prototype in .md file** - Use nimini scripts to experiment
2. **Refine with Claude** - "Make this slider look more cyberpunk"
3. **Test interactively** - Use R key to randomize, arrow keys to adjust
4. **Export to module** - When satisfied, export to compiled Nim (TODO: implement widget export)
5. **Integrate** - Import as compiled module for production

### Example: Iterative Design

```nim on:init
# Experiment with different slider styles
var slider1 = newSlider("style1", 10, 5, 20, 0.0, 100.0)
sliderSetChars(slider1, "░", "▓", "█")  # Style A
addWidget(slider1)

var slider2 = newSlider("style2", 10, 9, 20, 0.0, 100.0)
sliderSetChars(slider2, "-", "=", ">")  # Style B
addWidget(slider2)

var slider3 = newSlider("style3", 10, 13, 20, 0.0, 100.0)
sliderSetChars(slider3, "·", "━", "●")  # Style C
addWidget(slider3)

var currentStyle = 1
```

```nim on:input
if keyPressed("tab"):
  # Cycle through styles to compare
  currentStyle = (currentStyle mod 3) + 1
  
  case currentStyle
  of 1:
    print("Style A: Block characters")
  of 2:
    print("Style B: ASCII dashes")
  of 3:
    print("Style C: Unicode symbols")
```

---

## Common Patterns

### Modal Dialogs

```nim on:init
var dialogVisible = false
var okBtn = newButton("ok", 30, 20, 10, 3, "OK")
var cancelBtn = newButton("cancel", 42, 20, 12, 3, "Cancel")
widgetSetVisible(okBtn, false)
widgetSetVisible(cancelBtn, false)
addWidget(okBtn)
addWidget(cancelBtn)
```

```nim on:input
if keyPressed("escape"):
  dialogVisible = not dialogVisible
  widgetSetVisible(okBtn, dialogVisible)
  widgetSetVisible(cancelBtn, dialogVisible)
```

```nim on:render
if dialogVisible:
  # Draw dialog box
  drawBorderFull(3, 25, 15, 35, 12, crackedBorderPattern(42, 0.2))
  drawText(3, 30, 17, "Confirm action?", rgb(255, 255, 255))
  renderWidgets()
```

### Settings Panel

```nim on:init
var volumeSlider = newSlider("volume", 15, 5, 30, 0.0, 100.0)
var fullscreenCheck = newCheckBox("fullscreen", 15, 8, "Fullscreen", false)
var vsyncCheck = newCheckBox("vsync", 15, 10, "V-Sync", true)
var applyBtn = newButton("apply", 15, 13, 12, 3, "Apply")

sliderSetValue(volumeSlider, 80.0)
sliderSetShowValue(volumeSlider, true)

addWidget(volumeSlider)
addWidget(fullscreenCheck)
addWidget(vsyncCheck)
addWidget(applyBtn)
```

### Character Creator

```nim on:init
var nameField = newTextField(20, 5, 25)
textFieldSetText(nameField, "Hero")

var strSlider = newSlider("str", 20, 8, 20, 1.0, 20.0)
var dexSlider = newSlider("dex", 20, 11, 20, 1.0, 20.0)
var intSlider = newSlider("int", 20, 14, 20, 1.0, 20.0)

var warrior = newRadioButton("warrior", 20, 18, "Warrior", "class")
var rogue = newRadioButton("rogue", 20, 20, "Rogue", "class")
var mage = newRadioButton("mage", 20, 22, "Mage", "class")

# Set defaults
sliderSetValue(strSlider, 10.0)
sliderSetValue(dexSlider, 10.0)
sliderSetValue(intSlider, 10.0)
checkBoxSetChecked(warrior, true)

addWidget(nameField)
addWidget(strSlider)
addWidget(dexSlider)
addWidget(intSlider)
addWidget(warrior)
addWidget(rogue)
addWidget(mage)
```

---

## Tips & Best Practices

1. **Use Unique IDs** - Widget IDs must be unique across your document
2. **Layer Management** - Render widgets on appropriate layers (usually layer 2+)
3. **Focus Indication** - Provide visual feedback for focused widgets
4. **Keyboard Navigation** - Support Tab/Shift+Tab for accessibility
5. **Custom Styling** - Combine ASCII art patterns with widgets for unique looks
6. **State Management** - Track widget states in your on:init/on:update blocks
7. **Event Handling** - Use widget callbacks for complex interactions (when implemented)
8. **Performance** - Only update/render visible widgets
9. **Prototype Rapidly** - Use the Rebuild Pattern to iterate quickly
10. **Export When Ready** - Move proven designs to compiled modules

---

## Next Steps

- Implement widget event callbacks (onClick, onChange, etc.)
- Add widget export support to pattern_export.nim
- Create more preset widget themes (cyberpunk, retro, fantasy, etc.)
- Build compound widgets (ComboBox, ScrollBar, TabControl, etc.)
- Integrate with animation system for smooth transitions
- Add drag-and-drop support for repositionable widgets

---

## See Also

- [ASCII_ART_SYSTEM.md](../ASCII_ART_SYSTEM.md) - ASCII art pattern generation
- [docs/demos/tui_demo.md](demos/tui_demo.md) - Interactive widget examples
- [docs/demos/border_prototype.md](demos/border_prototype.md) - ASCII pattern prototyping
- [lib/tui.nim](../lib/tui.nim) - TUI widget implementation
- [lib/tui_bindings.nim](../lib/tui_bindings.nim) - Nimini bindings source
