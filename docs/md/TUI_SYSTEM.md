# TUI (Terminal User Interface) System

## Overview

The TUI system provides interactive UI widgets with state management, styling, and event handling for tstorie applications.

## Status: Phases 1, 2 & 3 Complete ✓

### Implemented Components

#### Phase 1: Foundation
- ✅ Widget base class with state management
- ✅ WidgetManager for focus and tab order
- ✅ Style resolution system (integrates with StyleSheet)
- ✅ Event routing and hit detection
- ✅ Tab navigation (Tab/Shift+Tab)
- ✅ Mouse hover tracking

#### Phase 2: Basic Widgets
- ✅ Label widget (non-interactive text display)
- ✅ Button widget (interactive with click handling)

#### Phase 3: Input Widgets
- ✅ CheckBox widget (boolean toggle with label)
- ✅ RadioButton widget (grouped single-selection)
- ✅ Slider widget (numeric value with drag support, horizontal/vertical)

### Test Results

All 18 unit tests pass:
1. ✓ Widget manager creation
2. ✓ Label widget creation and addition
3. ✓ Button widget creation and addition
4. ✓ Tab order building
5. ✓ Focus management (next/prev/cycle)
6. ✓ Widget lookup by ID
7. ✓ Style resolution
8. ✓ Widget removal
9. ✓ Hit detection
10. ✓ Widget state changes
11. ✓ Checkbox toggle and state setting
12. ✓ Radio button group exclusion and switching
13. ✓ Horizontal slider value setting and clamping
14. ✓ Slider step snapping
15. ✓ Vertical slider
16. ✓ Checkbox onChange callback
17. ✓ Slider onChange callback
18. ✓ Checkbox hit detection

## Architecture

### Widget Base Class

```nim
type
  Widget = ref object of RootObj
    id: string
    x, y, width, height: int
    visible, enabled: bool
    state: WidgetState  # Normal/Focused/Hovered/Disabled/Active
    focusable: bool
    tabIndex: int
    
    # Style references
    normalStyle, focusedStyle, hoverStyle, disabledStyle: string
    
    # Callbacks
    onFocus, onBlur, onChange, onClick: proc
```

### Style System Integration

Widgets use **named style references** that lookup from the document's StyleSheet:

```yaml
---
styles:
  button.normal: { fg: [255,255,255], bg: [50,50,150], bold: false }
  button.focused: { fg: [255,255,100], bg: [80,80,200], bold: true }
---
```

Style resolution priority:
1. Style override (direct Style object)
2. State-specific named style (e.g., "button.focused")
3. Normal named style (e.g., "button.normal")
4. Default style

### Widget Manager

Manages collections of widgets with:
- Focus management (keyboard navigation)
- Tab order (automatic or explicit)
- Hover tracking (mouse position)
- Event routing (top-to-bottom z-order)
- Lifecycle methods (update/render/handleInput)

## Usage Example

### Creating Widgets

```nim
import lib/tui

# Create manager with stylesheet
var wm = newWidgetManager(styleSheet)

# Create label
var label = newLabel("title", 5, 2, 30, 1, "Hello World")
label.hAlign = AlignCenter
wm.addWidget(label)

# Create button
var button = newButton("btn1", 5, 5, 12, 3, "Click Me")
button.tabIndex = 0
button.onClick = proc(w: Widget) =
  echo "Button clicked!"
wm.addWidget(button)
```

### Lifecycle Integration

```nim
# In update loop
wm.update(deltaTime)

# In render loop
wm.render(layer)

# In input handler
if wm.handleInput(event):
  # Event was consumed by widget
  return
```

### Tab Navigation

```nim
# Tab key pressed
if event.keyCode == INPUT_TAB:
  if ModShift in event.keyMods:
    wm.focusPrev()
  else:
    wm.focusNext()
```

## Widget Types

### Label

Non-interactive text display with alignment support.

**Properties:**
- `text: string` - Display text
- `hAlign: HAlign` - Horizontal alignment (Left/Center/Right)
- `vAlign: VAlign` - Vertical alignment (Top/Middle/Bottom)
- `padding: int` - Internal padding

**Usage:**
```nim
var label = newLabel("id", x, y, w, h, "Text")
label.hAlign = AlignCenter
label.setText("New Text")
```

### Button

Interactive clickable button with border and text.

**Properties:**
- `label: string` - Button text
- `hAlign, vAlign: HAlign, VAlign` - Text alignment
- `drawBorder: bool` - Show/hide border
- `onClick: proc` - Click callback

**Usage:**
```nim
var btn = newButton("id", x, y, w, h, "Label")
btn.onClick = proc(w: Widget) =
  echo "Clicked!"
```

**Input:**
- Mouse click (Press/Release)
- Keyboard (Space/Enter when focused)

### CheckBox

Boolean toggle widget with checkbox or radio button behavior.

**Properties:**
- `checked: bool` - Current state
- `label: string` - Label text next to box
- `group: string` - Radio button group (empty for checkbox)
- `radio: bool` - True for radio button mode
- `checkedChar, uncheckedChar: string` - Visual indicators
- `onChange: proc` - State change callback

**Usage:**
```nim
# Checkbox
var cb = newCheckBox("agree", x, y, "I agree", false)
cb.onChange = proc(w: Widget) =
  echo "Checked: ", CheckBox(w).checked

# Radio buttons
var r1 = newRadioButton("opt1", x, y, "Option 1", "group1")
var r2 = newRadioButton("opt2", x, y+1, "Option 2", "group1")
r1.onChange = proc(w: Widget) =
  wm.uncheckRadioGroup("group1", w.id)
```

**Methods:**
- `toggle()` - Toggle checked state (prevents radio uncheck)
- `setChecked(bool)` - Set state programmatically
- `wm.uncheckRadioGroup(group, exceptId)` - Uncheck other radios in group

**Input:**
- Mouse click
- Keyboard (Space when focused)

### Slider

Numeric value selector with mouse drag and keyboard support.

**Properties:**
- `value, minValue, maxValue: float` - Value range
- `step: float` - Step increment (0 for continuous)
- `showValue: bool` - Display numeric value
- `orientation: Orientation` - Horizontal or Vertical
- `trackChar, fillChar, handleChar: string` - Visual customization
- `onChange: proc` - Value change callback

**Usage:**
```nim
# Horizontal slider
var slider = newSlider("volume", x, y, 20, 0.0, 100.0)
slider.step = 5.0  # Snap to 5-unit increments
slider.onChange = proc(w: Widget) =
  echo "Value: ", Slider(w).value

# Vertical slider
var vSlider = newVerticalSlider("level", x, y, 10, 0.0, 100.0)
```

**Methods:**
- `setValue(float)` - Set value with clamping and step snapping
- `updateValueFromPosition(x, y)` - Calculate value from mouse position

**Input:**
- Mouse drag (Press, Move, Release)
- Keyboard arrows (Left/Down = decrease, Right/Up = increase)
- Home/End (min/max values)
- MouseMoveEvent for drag tracking

## Implementation Notes

### Type Dependencies

The TUI module must be **included** (not imported) after tstorie types are defined, as it depends on:
- `Color`, `Style` - From tstorie.nim
- `Layer`, `TermBuffer` - From tstorie.nim
- `InputEvent`, `InputAction`, `MouseButton` - From tstorie.nim
- `StyleSheet`, `StyleConfig` - From storie_types.nim

### Method Dispatch

Widgets use Nim's method dispatch for extensibility:
```nim
method render*(w: Widget, layer: Layer) {.base.}
method handleInput*(w: Widget, event: InputEvent): bool {.base.}
method update*(w: Widget, dt: float) {.base.}
method contains*(w: Widget, x, y: int): bool {.base.}
```

### State Management

Widget state affects both appearance and behavior:
- **wsNormal** - Default state
- **wsFocused** - Has keyboard focus (can receive key events)
- **wsHovered** - Mouse is over widget
- **wsDisabled** - Grayed out, no input
- **wsActive** - Being pressed/dragged

State changes trigger style re-resolution automatically.

## Future Enhancements (Phase 3+)

### Phase 3: Input Widgets
- [ ] CheckBox - Boolean toggle
- [ ] RadioButton - Grouped single-selection
- [ ] Slider - Numeric value with drag

### Phase 4: Advanced Widgets
- [ ] TextBox - Text editing with cursor
- [ ] ListBox - Scrollable item list
- [ ] ProgressBar - Progress indicator
- [ ] Dropdown - Collapsible selection menu

### Additional Features
- [ ] Animation support for state transitions
- [ ] Word wrapping for labels
- [ ] Validation callbacks for inputs
- [ ] Keyboard shortcuts
- [ ] Context menus
- [ ] Tooltips
- [ ] Modal dialogs
- [ ] Layout containers (HBox/VBox)

## Testing

Run the test suite:
```bash
nim c -r tests/test_tui.nim
```

The test verifies:
- Widget creation and management
- Focus and tab navigation
- Style resolution
- Hit detection
- State management
- Event routing

## Files

- `lib/tui.nim` - Main TUI module (733 lines)
- `tests/test_tui.nim` - Unit tests
- `examples/tui_demo.md` - Interactive demo (WIP)
- `docs/TUI_SYSTEM.md` - This documentation

## License

Part of the tstorie project.
