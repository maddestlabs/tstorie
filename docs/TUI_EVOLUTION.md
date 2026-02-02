# TUI Module Evolution - From Test to Production

This document tracks the evolution from `tui_test.nim` (proof of concept) to `tui.nim` (production module).

## What Changed

### Scale Increase
**Before (tui_test.nim):**
- 2 button slots only
- Single widget type (buttons)

**After (tui.nim):**
- 16 widget slots (8x increase)
- 4 widget types (buttons, labels, checkboxes, sliders)
- 8 UI groups for organization

### Widget Types Added

#### 1. Labels
```nim
initLabel(id, x, y, w, h, "text", "center")
setLabelText(id, "updated text")
```
**Use cases:**
- Titles and headers
- Status displays
- Score counters
- Info text

#### 2. Checkboxes
```nim
initCheckbox(id, x, y, w, h, "Enable feature", false)
if wasToggled(id):
  if isChecked(id):
    # Feature enabled
```
**Use cases:**
- Settings toggles
- Option selection
- Feature flags

#### 3. Sliders
```nim
initSlider(id, x, y, w, h, "Volume", 0, 100, 50)
var value = getSliderValue(id)
```
**Use cases:**
- Volume controls
- Difficulty selection
- Value adjustment
- Progress bars

### Group System
**New feature:** Organize widgets into groups with visibility control

```nim
# Define readable group names
const
  GROUP_MAIN_MENU = 0
  GROUP_GAME_HUD = 1
  GROUP_SETTINGS = 2

# Assign widgets to groups
initButton(0, x, y, w, h, "Play", GROUP_MAIN_MENU)
initLabel(1, x, y, w, h, "Score: 0", "left", GROUP_GAME_HUD)

# Toggle entire screens
setGroupVisible(GROUP_MAIN_MENU, false)
setGroupVisible(GROUP_GAME_HUD, true)
```

**Benefits:**
- Single system for multiple UI contexts
- Easy screen transitions
- Clear input routing (only visible groups respond)
- Deterministic render order (group 0 first, then 1, etc.)

### Enhanced State Management

**New state queries:**
- `wasToggled(id)` - Checkbox state changes
- `isChecked(id)` - Checkbox current state
- `getSliderValue(id)` - Slider value
- `setSliderValue(id, value)` - Programmatic slider control

**New visibility control:**
- `setWidgetVisible(id, visible)` - Individual widget control
- `isWidgetVisible(id)` - Check widget visibility
- `setGroupVisible(group, visible)` - Group-level control

**New text updates:**
- `setButtonLabel(id, text)` - Update button text
- `setLabelText(id, text)` - Update label text

### Improved Click Detection

**Before:**
```nim
# Clicked if hovered and pressed (could re-trigger)
gButtons[i].clicked = gButtons[i].hovered and mousePressed
```

**After:**
```nim
# Clicked only on press event (no re-trigger)
let mouseJustPressed = mousePressed and not gLastMousePressed
gLastMousePressed = mousePressed
gWidgets[i].clicked = gWidgets[i].hovered and mouseJustPressed
```

This prevents held clicks from triggering multiple times per frame.

### Better Rendering

**Organized by groups:**
```nim
# Draw in group order (0 first, then 1, etc.)
for groupId in 0..<MAX_GROUPS:
  if not gGroupVisible[groupId]:
    continue
  # Draw all widgets in this group
```

**Benefits:**
- Predictable z-order (lower groups behind higher groups)
- Easy layering (game UI below menu UI)
- Automatic visibility handling

## API Comparison

### Initialization

**tui_test.nim:**
```nim
on:init
  initButton(0, 10, 5, 20, 3, "Button 1")
  initButton(1, 10, 12, 20, 3, "Button 2")
```

**tui.nim:**
```nim
on:init
  initTUI()  # New: explicit initialization
  
  # Buttons with groups
  initButton(0, 10, 5, 20, 3, "Start", 0)
  
  # Multiple widget types
  initLabel(1, 10, 2, 20, 1, "MENU", "center", 0)
  initCheckbox(2, 10, 10, 25, 1, "Sound", true, 0)
  initSlider(3, 10, 15, 30, 3, "Volume", 0, 100, 50, 0)
```

### Update Loop

**tui_test.nim:**
```nim
on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  if wasClicked(0):
    # Handle button 0
```

**tui.nim:**
```nim
on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Button clicks
  if wasClicked(0):
    # Handle button
  
  # Checkbox toggles
  if wasToggled(2):
    if isChecked(2):
      # Checkbox now checked
  
  # Slider values
  var volume = getSliderValue(3)
  
  # Dynamic updates
  setLabelText(1, "Volume: " & $volume)
```

### Rendering

**Both versions (same API):**
```nim
on:render
  drawTUI("button")  # Draws all visible widgets
```

The rendering API remains simple and unchanged!

## File Structure

```
lib/
  tui_test.nim           # Proof of concept (2 buttons)
  tui_test_bindings.nim  # Bindings for test version
  
  tui.nim                # Production module (16 widgets, 4 types)
  tui_bindings.nim       # Complete bindings
```

## Migration Path

### Simple Button Code
**No changes needed!** Basic button code works in both:

```nim
on:init
  initButton(0, 10, 5, 20, 3, "Click")

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  if wasClicked(0):
    # Handle click

on:render
  drawTUI("button")
```

### Upgrading to Full TUI
Just add `initTUI()` and use new features:

```nim
on:init
  initTUI()  # Add this line
  initButton(0, 10, 5, 20, 3, "Click")
  # Now add new widgets
  initLabel(1, 10, 2, 20, 1, "Title", "center")
```

## Performance

**Memory overhead:**
- tui_test.nim: ~160 bytes (2 buttons × 80 bytes)
- tui.nim: ~2KB (16 widgets × ~128 bytes + 8 groups)
- Still negligible!

**CPU overhead:**
- Both iterate through active widgets once per frame
- tui.nim adds group visibility checks (minimal)
- No dynamic allocation in either version

## Future Enhancements

Planned for `tui.nim` v2:

1. **More widget types:**
   - Text input fields
   - Radio button groups
   - Dropdown menus
   - Progress bars

2. **Layout helpers:**
   ```nim
   layoutVertical(group=0, startY=5, spacing=2, [
     button("First"),
     button("Second"),
     button("Third")
   ])
   ```

3. **Focus management:**
   - TAB key navigation
   - Active widget highlighting
   - Keyboard input routing

4. **Themes:**
   - Per-widget style overrides
   - Hover/active state styles
   - Custom border styles

5. **Animation:**
   - Smooth transitions
   - Fade in/out effects
   - Slide animations

## Testing

**Test demos:**
- `docs/demos/tui_test_demo.md` - Original 2-button test
- `docs/demos/tui_widgets_example.md` - All widget types
- `docs/demos/tui_demo.md` - Complete menu system with groups

**Run tests:**
```bash
./ts docs/demos/tui_test_demo        # Original test
./ts docs/demos/tui_widgets_example  # Widget showcase
./ts docs/demos/tui_demo             # Full demo
```

## Summary

**tui_test.nim** proved the retained mode concept with buttons.

**tui.nim** expands it into a production-ready UI system:
- ✅ 8x more capacity (16 widgets)
- ✅ 4 widget types (was 1)
- ✅ Group-based organization
- ✅ Enhanced state management
- ✅ Better click detection
- ✅ Organized rendering
- ✅ Backward compatible API

The architecture is proven, scalable, and ready for complex UIs!
