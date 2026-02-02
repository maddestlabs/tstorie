---
name: "TUI Widgets Demo"
theme: "solarlight"
shaders: "ruledlines+paper"
---

A demo showing TUI widgets with both keyboard and mouse input.

**Keyboard Controls:**
- **TAB**: Navigate forward through widgets
- **SHIFT+TAB**: Navigate backward through widgets  
- **ENTER/SPACE**: Activate button or toggle checkbox
- **ARROW KEYS**: Adjust sliders (Left/Right) or navigate (Up/Down)

## Init

```nim on:init
  initTUI()
  
  # Button widgets
  initButton(0, 5, 2, 20, 3, "Click Me")
  initButton(1, 30, 2, 20, 3, "Press Here")
  
  # Label widgets (different alignments)
  initLabel(2, 5, 7, 20, 1, "Left Label", "left")
  initLabel(3, 30, 7, 20, 1, "Center", "center")
  initLabel(4, 55, 7, 20, 1, "Right", "right")
  
  # Checkbox widgets
  initCheckbox(5, 5, 10, 25, 1, "Option A", false)
  initCheckbox(6, 5, 12, 25, 1, "Option B", true)
  
  # Slider widgets
  initSlider(7, 5, 15, 30, 3, "Speed", 0, 10, 5)
  initSlider(8, 5, 19, 30, 3, "Power", 1, 100, 50)
  
  var mousePressed = false
  var clickCount = 0
```

## Input

```nim on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false
  
  # Handle keyboard input for TUI navigation
  # Pass modifiers for SHIFT+TAB support
  if event.type == "key":
    handleTUIKey(event.keyCode, event.action, event.mods)
```

## Update

```nim on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Count button clicks
  if wasClicked(0):
    clickCount = clickCount + 1
    setButtonLabel(0, "Clicks: " & $clickCount)
  
  if wasClicked(1):
    setLabelText(3, "Button 2 pressed!")
  
  # Show checkbox states
  if wasToggled(5):
    if isChecked(5):
      setLabelText(2, "A: ON")
    else:
      setLabelText(2, "A: OFF")
  
  if wasToggled(6):
    if isChecked(6):
      setLabelText(4, "B: ON")
    else:
      setLabelText(4, "B: OFF")
  
  # Display slider values
  var speed = getSliderValue(7)
  var power = getSliderValue(8)
  setLabelText(3, "S:" & $speed & " P:" & $power)
```

## Render

```nim on:render
  clear()
  
  # Title
  draw(0, 5, 0, "TUI Widgets Demo - Keyboard & Mouse", "heading")
  draw(0, 5, 1, "TAB: Navigate | ENTER: Activate | ARROWS: Adjust/Navigate", "dim")
  
  # Draw all widgets
  drawTUI("button")
```
