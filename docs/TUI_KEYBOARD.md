# TUI Keyboard Navigation

The TUI system now supports full keyboard navigation and control, allowing users to interact with widgets without a mouse.

## Quick Start

Add keyboard handling to your `on:input` block:

```nim
on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false
  
  # Handle keyboard input
  if event.type == "key":
    handleTUIKey(event.keyCode, event.action)
```

That's it! The TUI system will automatically handle:
- TAB navigation through widgets
- ENTER/SPACE to activate buttons and toggle checkboxes
- ARROW keys to adjust sliders and navigate widgets

## Keyboard Controls

### Navigation
- **TAB**: Cycle forward through focusable widgets
- **Arrow Up/Down**: Navigate to previous/next widget
- **Arrow Left/Right** (non-sliders): Navigate backward/forward through widgets

### Activation
- **ENTER**: Activate focused button or toggle focused checkbox
- **SPACE**: Same as ENTER
- **Arrow Left/Right** (sliders): Decrease/increase slider value

## Visual Feedback

Focused widgets are indicated with special styling:

### Buttons
- **Normal**: Single-line border (`┌─┐`)
- **Focused**: Double-line border (`╔═╗`) with link_focused theme color

### Checkboxes  
- **Normal**: Square brackets `[X]` or `[ ]`
- **Focused**: Guillemets `《X》` or `《 》` with link_focused theme color

### Sliders
- **Normal**: Dashes for track `[---]`
- **Focused**: Double lines for track `《═══》` with highlighted label and handle

## API Reference

### handleTUIKey()
```nim
handleTUIKey(keyCode: int, action: string)
```
Process keyboard input for TUI navigation and interaction.
- **keyCode**: Integer key code (e.g., KEY_TAB=9, KEY_RETURN=13, KEY_UP=1073741906)
- **action**: "press", "release", or "repeat" (only "press" and "repeat" are processed)

**Usage**: Call from `on:input` when `event.type == "key"`

**Supported Keys**:
- **KEY_TAB** (9): Navigate forward through widgets
- **KEY_RETURN** (13) / **KEY_SPACE** (32): Activate button or toggle checkbox
- **KEY_UP** (1073741906): Navigate to previous widget
- **KEY_DOWN** (1073741905): Navigate to next widget  
- **KEY_LEFT** (1073741904): Decrease slider value or navigate backward
- **KEY_RIGHT** (1073741903): Increase slider value or navigate forward

### Focus Management

#### getFocusedWidget()
```nim
let focusedId = getFocusedWidget()
```
Returns the ID of the currently focused widget, or -1 if no widget has focus.

#### setFocusedWidget()
```nim
setFocusedWidget(id)
```
Programmatically set keyboard focus to a specific widget.
- Pass -1 to clear focus
- Labels cannot receive focus (automatically skipped)
- Invisible widgets and widgets in hidden groups are skipped

#### clearFocus()
```nim
clearFocus()
```
Remove keyboard focus from all widgets.

## Examples

### Basic Keyboard Support

```nim
on:init
  initTUI()
  initButton(0, 5, 5, 20, 3, "Button 1")
  initButton(1, 5, 9, 20, 3, "Button 2")
  initCheckbox(2, 5, 13, 25, 1, "Option", false)
  var mousePressed = false

on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false
  
  if event.type == "key":
    handleTUIKey(event.key, event.action)

on:update
  updateTUI(mouseX, mouseY, mousePressed)

on:render
  clear()
  drawTUI("button")
```

### Custom Focus Handling

```nim
on:init
  initTUI()
  initButton(0, 5, 5, 20, 3, "Start")
  initButton(1, 5, 9, 20, 3, "Options")
  initButton(2, 5, 13, 20, 3, "Quit")
  
  # Start with focus on first button
  setFocusedWidget(0)
  
  var mousePressed = false

on:input
  if event.type == "key":
    # Custom handling for ESC key
    if event.keyCode == 27 and event.action == "press":  # KEY_ESCAPE = 27
      clearFocus()  # Clear focus on ESC
    else:
      handleTUIKey(event.keyCode, event.action)
  
  if event.type == "mouse":
    # ... mouse handling

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Show which widget has focus
  let focused = getFocusedWidget()
  if focused >= 0:
    setLabelText(3, "Focused: Widget " & $focused)
  else:
    setLabelText(3, "No focus")

on:render
  clear()
  drawTUI("button")
```

### Slider Adjustment

```nim
on:init
  initTUI()
  initSlider(0, 5, 5, 40, 3, "Volume", 0, 100, 50)
  initSlider(1, 5, 9, 40, 3, "Balance", -10, 10, 0)
  var mousePressed = false

on:input
  if event.type == "key":
    handleTUIKey(event.keyCode, event.action)
  # ... mouse handling

on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Get slider values
  var volume = getSliderValue(0)
  var balance = getSliderValue(1)

on:render
  clear()
  draw(0, 5, 2, "Use TAB to navigate, ARROWS to adjust", "dim")
  drawTUI("button")
```

## Focus Navigation Logic

The TUI system implements smart focus navigation:

1. **TAB**: Always moves forward through focusable widgets
   - Wraps around from last to first widget
   - Skips labels, invisible widgets, and widgets in hidden groups

2. **Arrow Up/Down**: Navigate in widget order
   - Up goes to previous, Down goes to next
   - If no widget is focused, starts from the first focusable widget

3. **Arrow Left/Right**:
   - On sliders: Adjust value (5% steps)
   - On other widgets: Navigate backward/forward

4. **ENTER/SPACE**: Activate focused widget
   - Buttons: Set clicked state (detected by `wasClicked()`)
   - Checkboxes: Toggle checked state (detected by `wasToggled()`)
   - Sliders: No effect
   - Labels: No effect

## Integration with Mouse Input

Keyboard and mouse input work seamlessly together:

- Clicking a widget gives it keyboard focus
- Keyboard focus is maintained independently of mouse hover
- Mouse hover and keyboard focus can coexist (different visual states)
- The system prioritizes visual feedback: clicked > focused > hovered > normal

## Accessibility Notes

The keyboard navigation system makes TUI interfaces accessible for:
- Users who prefer keyboard-only navigation
- Terminal-only environments without mouse support
- Screen reader compatibility (semantic focus states)
- Rapid navigation for power users

## Theme Integration

Focus states use the `link_focused` theme color by default. To customize:

```markdown
---
styles.link_focused.fg: "#00FF00"  # Bright green for focused widgets
styles.link_focused.bg: "#002200"  # Dark green background
---
```

## Known Key Codes

Key codes passed to `handleTUIKey()`:

**Navigation**:
- `KEY_TAB` = 9
- `KEY_UP` = 1073741906
- `KEY_DOWN` = 1073741905
- `KEY_LEFT` = 1073741904
- `KEY_RIGHT` = 1073741903

**Activation**:
- `KEY_RETURN` / `KEY_ENTER` = 13
- `KEY_SPACE` = 32

**Special**:
- `KEY_ESCAPE` = 27
- `KEY_BACKSPACE` = 8

**Note**: These constants can be used directly in scripts (e.g., `if event.keyCode == KEY_TAB:`).

## Performance Considerations

- Focus tracking has minimal overhead (single integer variable)
- Navigation searches are O(n) where n = MAX_WIDGETS (32)
- Key handling only processes "press" events (ignores "release")
- No performance impact if keyboard handling is not used

## Migration Guide

### From Mouse-Only to Keyboard Support

1. Add keyboard handling to `on:input`:
   ```nim
   if event.type == "key":
     handleTUIKey(event.key, event.action)
   ```

2. Optionally set initial focus:
   ```nim
   setFocusedWidget(0)  # In on:init
   ```

3. Test TAB navigation and widget activation

That's it! Your TUI interface now supports keyboard navigation with zero changes to existing widget code.

## Future Enhancements

Potential improvements for future versions:

- **Custom key bindings**: Allow scripts to override default behavior
- **Focus groups**: Constrain TAB navigation to specific widget groups
- **Focus traps**: Modal dialogs that capture all keyboard input
- **Type-ahead**: Start typing to jump to labeled widgets
- **Vim-style navigation**: hjkl for arrow key alternatives
- **Gamepad support**: Map gamepad buttons to TUI navigation

## See Also

- [UI.md](../UI.md) - TUI system architecture and memory layout
- [tui_widgets_example.md](demos/tui_widgets_example.md) - Complete keyboard + mouse demo
- [DEBUGGING.md](../DEBUGGING.md) - Troubleshooting TUI scripts
