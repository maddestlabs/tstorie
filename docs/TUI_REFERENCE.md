# TUI Quick Reference

Quick reference for the tStorie TUI (Terminal UI) module.

## Setup

```nim
on:init
  initTUI()  # Call once at startup
```

## Widgets

### Button
```nim
initButton(id, x, y, w, h, "label", group=0)

# Query
if wasClicked(id):
  # Handle click
```

### Label
```nim
initLabel(id, x, y, w, h, "text", "align", group=0)
# align: "left", "center", "right"

# Update
setLabelText(id, "new text")
```

### Checkbox
```nim
initCheckbox(id, x, y, w, h, "label", checked=false, group=0)

# Query
if wasToggled(id):
  if isChecked(id):
    # Now checked
  else:
    # Now unchecked
```

### Slider
```nim
initSlider(id, x, y, w, h, "label", minVal, maxVal, initialVal, group=0)

# Get value
var value = getSliderValue(id)

# Set value
setSliderValue(id, newValue)
```

## Core Loop

```nim
on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  # Check widget states here

on:render
  drawTUI("button")  # Draws all widgets
```

## Groups

```nim
# Define groups (in on:init)
const
  GROUP_MENU = 0
  GROUP_GAME = 1
  GROUP_SETTINGS = 2

# Create widgets in groups
initButton(0, x, y, w, h, "Play", GROUP_MENU)
initButton(1, x, y, w, h, "Pause", GROUP_GAME)

# Control visibility
setGroupVisible(GROUP_MENU, true)
setGroupVisible(GROUP_GAME, false)

# Check visibility
if isGroupVisible(GROUP_SETTINGS):
  # Settings visible
```

## Widget Control

```nim
# Visibility
setWidgetVisible(id, true/false)
if isWidgetVisible(id):
  # Widget is visible

# Text updates
setButtonLabel(id, "new label")
setLabelText(id, "new text")

# Hover state
if isHovered(id):
  # Mouse over widget
```

## Limits

- Max widgets: 16 (IDs 0-15)
- Max groups: 8 (IDs 0-7)
- Default group: 0

## Examples

### Simple Menu
```nim
on:init
  initTUI()
  initButton(0, 10, 5, 20, 3, "Start")
  initButton(1, 10, 9, 20, 3, "Quit")

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  if wasClicked(0):
    # Start game
  if wasClicked(1):
    # Quit

on:render
  drawTUI("button")
```

### Settings Panel
```nim
on:init
  initTUI()
  initLabel(0, 10, 2, 30, 1, "SETTINGS", "center")
  initCheckbox(1, 10, 5, 25, 1, "Enable Sound", true)
  initSlider(2, 10, 8, 30, 3, "Volume", 0, 100, 75)
  initButton(3, 10, 13, 20, 3, "Apply")

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  if wasClicked(3):
    var volume = getSliderValue(2)
    var soundOn = isChecked(1)
    # Apply settings
```

### Multi-Screen UI
```nim
on:init
  initTUI()
  const SCREEN_MENU = 0
  const SCREEN_GAME = 1
  
  # Menu screen
  initButton(0, 10, 5, 20, 3, "Play", SCREEN_MENU)
  
  # Game screen
  initLabel(1, 5, 1, 20, 1, "Score: 0", "left", SCREEN_GAME)
  initButton(2, 10, 20, 20, 3, "Menu", SCREEN_GAME)
  
  # Start on menu
  setGroupVisible(SCREEN_MENU, true)
  setGroupVisible(SCREEN_GAME, false)

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  if wasClicked(0):  # Play button
    setGroupVisible(SCREEN_MENU, false)
    setGroupVisible(SCREEN_GAME, true)
  
  if wasClicked(2):  # Menu button
    setGroupVisible(SCREEN_GAME, false)
    setGroupVisible(SCREEN_MENU, true)
```

## Best Practices

✅ **Do:**
- Call `initTUI()` in `on:init`
- Use group constants for readability
- Call `updateTUI()` once per frame in `on:update`
- Call `drawTUI()` once per frame in `on:render`
- Check widget states after `updateTUI()`
- Use groups for different screens/contexts

❌ **Don't:**
- Initialize widgets in `on:render`
- Call widget-specific draw functions manually
- Exceed widget limit (0-15)
- Use duplicate IDs
- Update widgets during render

## Architecture

**Retained Mode:** State persists between frames
- Initialize once in `on:init`
- Update state in `on:update`
- Render from state in `on:render`

**Fixed Arrays:** No dynamic allocation
- Predictable performance
- No memory fragmentation
- Safe and reliable

**Backend Agnostic:** Works everywhere
- Terminal (ANSI)
- SDL3 (OpenGL)
- WebGPU (Browser)
