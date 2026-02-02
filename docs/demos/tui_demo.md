---
name: "TUI Demo - UI System Test"
theme: "coffee"
shaders: "paper+ruledlines"
---

This demo showcases all TUI widgets and features:
- Buttons (grouped)
- Labels (with alignment)
- Checkboxes
- Sliders
- Group visibility toggling

## Init

```nim on:init
  # Initialize the TUI system
  initTUI()
  
  # Define group constants for readability
  const
    GROUP_MAIN = 0
    GROUP_SETTINGS = 1
  
  # Main menu (group 0)
  initButton(0, 5, 3, 25, 3, "Start Game", GROUP_MAIN)
  initButton(1, 5, 7, 25, 3, "Settings", GROUP_MAIN)
  initButton(2, 5, 11, 25, 3, "Quit", GROUP_MAIN)
  
  initLabel(3, 5, 1, 25, 1, "MAIN MENU", "center", GROUP_MAIN)
  
  # Settings menu (group 1, initially hidden)
  initLabel(4, 40, 1, 30, 1, "SETTINGS", "center", GROUP_SETTINGS)
  initButton(5, 40, 3, 20, 3, "Back", GROUP_SETTINGS)
  
  initCheckbox(6, 40, 7, 25, 1, "Enable Sound", true, GROUP_SETTINGS)
  initCheckbox(7, 40, 9, 25, 1, "Fullscreen", false, GROUP_SETTINGS)
  
  initSlider(8, 40, 12, 30, 3, "Volume", 0, 100, 50, GROUP_SETTINGS)
  initSlider(9, 40, 16, 30, 3, "Difficulty", 1, 5, 3, GROUP_SETTINGS)
  
  # Start with settings hidden
  setGroupVisible(GROUP_SETTINGS, false)
  
  var mousePressed = false
```

## Input

```nim on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false
```

## Update

```nim on:update
  # Update all widgets
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Handle main menu buttons
  if wasClicked(0):
    # Start Game button
    setLabelText(3, "Starting...")
  
  if wasClicked(1):
    # Settings button - toggle groups
    setGroupVisible(0, false)  # Hide main menu
    setGroupVisible(1, true)   # Show settings
  
  if wasClicked(2):
    # Quit button
    setLabelText(3, "Goodbye!")
  
  # Handle settings buttons
  if wasClicked(5):
    # Back button - return to main menu
    setGroupVisible(0, true)   # Show main menu
    setGroupVisible(1, false)  # Hide settings
  
  # Update label based on checkbox state
  if wasToggled(6):
    if isChecked(6):
      setLabelText(4, "Sound: ON")
    else:
      setLabelText(4, "Sound: OFF")
  
  # Update button label based on slider value
  var volume = getSliderValue(8)
  setButtonLabel(5, "Back [Vol: " & $volume & "]")
```

## Render

```nim on:render
  # Clear screen
  clear()
  
  # Draw all visible widgets (both groups handled automatically)
  drawTUI("button")
  
  # Show instructions at bottom
  draw(0, 5, 23, "Use mouse to interact with UI", "default")
  draw(0, 5, 24, "Click 'Settings' to see more widgets", "default")
```