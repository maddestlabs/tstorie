# TUI Widgets Quick Reference

One-page reference for all TUI widget functions in nimini scripts.

## Widget Manager

```nim
addWidget(widget)              # Add widget to manager
removeWidget(widgetId)         # Remove by ID
focusWidget(widgetId)          # Focus widget
updateWidgets(deltaTime)       # Update all widgets
renderWidgets()                # Render all widgets
```

## Button

```nim
var btn = newButton(id, x, y, width, height, label)
buttonSetLabel(btn, "New Text")
```

## Slider

```nim
# Horizontal
var slider = newSlider(id, x, y, length, minVal, maxVal)

# Vertical
var slider = newVerticalSlider(id, x, y, length, minVal, maxVal)

# Operations
sliderGetValue(slider) → float
sliderSetValue(slider, value)
sliderSetShowValue(slider, true/false)
sliderSetChars(slider, trackChar, fillChar, handleChar)
```

## TextField

```nim
var field = newTextField(x, y, width)

textFieldGetText(field) → string
textFieldSetText(field, text)
textFieldClear(field)
textFieldSetFocused(field, true/false)
```

## CheckBox / RadioButton

```nim
# CheckBox
var check = newCheckBox(id, x, y, label, checked)

# RadioButton
var radio = newRadioButton(id, x, y, label, group)

# Operations
checkBoxIsChecked(check) → bool
checkBoxSetChecked(check, true/false)
checkBoxToggle(check)
checkBoxSetChars(check, checkedChar, uncheckedChar)
```

## ProgressBar

```nim
var bar = newProgressBar(id, x, y, length, orientation)
# orientation: "horizontal" (default) or "vertical"

progressBarSetValue(bar, value)           # Raw value
progressBarSetProgress(bar, 0.0-1.0)      # Normalized
progressBarGetProgress(bar) → float
progressBarSetText(bar, "Loading...")     # Overlay text
progressBarSetShowPercentage(bar, true)
progressBarSetChars(bar, emptyChar, fillChar, leftCap, rightCap)
```

## Generic Widget Operations

```nim
widgetSetVisible(widget, true/false)
widgetSetEnabled(widget, true/false)
widgetSetPosition(widget, x, y)
widgetSetSize(widget, width, height)
```

## ASCII Art Integration

```nim
# Custom borders around widgets
var pattern = crackedBorderPattern(seed, density)
drawBorderFull(layer, x, y, width, height, pattern)

# Modulo patterns
var pattern = moduloPattern(xMod, yMod, charset, seed)
```

## Common Patterns

### Sci-Fi Panel
```nim
var slider = newSlider("power", 10, 5, 30, 0.0, 100.0)
sliderSetChars(slider, "░", "▓", "█")
addWidget(slider)

var border = crackedBorderPattern(42, 0.3)
drawBorderFull(2, 8, 3, 34, 5, border)
renderWidgets()
```

### Settings Menu
```nim
var volume = newSlider("vol", 10, 5, 25, 0.0, 100.0)
var fullscreen = newCheckBox("fs", 10, 8, "Fullscreen", false)
var apply = newButton("apply", 10, 11, 15, 3, "Apply")

addWidget(volume)
addWidget(fullscreen)
addWidget(apply)
```

### Progress Indicator
```nim
var progress = newProgressBar("load", 10, 10, 50, "horizontal")
progressBarSetProgress(progress, 0.0)
progressBarSetShowPercentage(progress, true)
addWidget(progress)

# In on:update
var p = progressBarGetProgress(progress)
if p < 1.0:
  progressBarSetProgress(progress, p + deltaTime * 0.1)
```

## Visual Customization Presets

### Style A: Block Characters
```nim
sliderSetChars(slider, "░", "▓", "█")
checkBoxSetChars(check, "■", "□")
progressBarSetChars(bar, "░", "█", "[", "]")
```

### Style B: ASCII Dashes
```nim
sliderSetChars(slider, "-", "=", ">")
checkBoxSetChars(check, "X", " ")
progressBarSetChars(bar, "-", "=", "|", "|")
```

### Style C: Unicode Symbols
```nim
sliderSetChars(slider, "·", "━", "●")
checkBoxSetChars(check, "✓", "✗")
progressBarSetChars(bar, "╌", "━", "▐", "▌")
```

### Style D: Retro
```nim
sliderSetChars(slider, ".", "#", "#")
checkBoxSetChars(check, "*", "o")
progressBarSetChars(bar, ".", "#", "<", ">")
```

## Tips

1. **Unique IDs** - Every widget needs a unique ID string
2. **Layer 2+** - Render widgets on layers 2 or higher (layer 0-1 for backgrounds)
3. **Update Order** - Call updateWidgets() before renderWidgets()
4. **Borders** - Draw borders before rendering widgets so they appear behind
5. **Randomization** - Use random.randomize(seed) for reproducible patterns

## See Full Documentation

- [TUI_WIDGETS_GUIDE.md](TUI_WIDGETS_GUIDE.md) - Complete guide
- [ASCII_ART_SYSTEM.md](ASCII_ART_SYSTEM.md) - ASCII art patterns
- [docs/demos/tui_demo.md](docs/demos/tui_demo.md) - Interactive examples
