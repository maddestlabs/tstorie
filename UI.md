# t|Storie UI System Architecture

## Overview

t|Storie's UI system uses **retained mode** with **fixed-size arrays** to provide a simple, reliable, cross-backend UI framework. This architecture avoids complexity and segfaults that easily creep in with scripting around UI. Meanwhile, anyone wanting immediate mode UI can just use on:render and on:input blocks to draw and handle input from manually created UI elements. So both modes are available.

**Current Implementation:** `lib/tui.nim` - Production-ready module with 16 widgets, 4 widget types, group management, and automatic theme integration.

**Theme Integration:** TUI widgets automatically use theme-based styles from `storie_themes.nim`, providing consistent visual design across different themes with semantic color usage (headings, buttons, info text, etc.).

## Core Design Principles

### 1. Retained Mode Pattern
State is stored between frames and updated/rendered in separate phases:

```nim on:init
# Define UI structure (once)
initButton(0, 10, 5, 20, 3, "Click Me")
```

```nim on:update
# Update all state
updateTUI(mouseX, mouseY, mousePressed)
```

```nim on:render
# Draw from stored state
drawTUI("button")
```

**Benefits:**
- Clear separation of concerns (update vs render)
- Single source of truth (stored state)
- Batch operations (one update, one draw for all elements)
- Stateful queries (check `wasClicked(0)` anywhere)

### 2. Fixed-Size Arrays
No dynamic allocation = no segfaults:

```nim
# Proof of concept (tui_test.nim)
var gButtons: array[2, ButtonState]

# Production (tui.nim)
var gWidgets: array[32, Widget]  # 32 widgets, 4 types
var gGroupVisible: array[8, bool]  # 8 UI groups
```

**Scaling complete:**
- ✅ Started: 2 buttons (proof of concept)
- ✅ Current: 32 widgets with multiple types
- 🔄 Future: Configurable max via constants

### 3. ID-Based Element Access

Elements are accessed by integer ID:

```nim
initButton(0, x, y, w, h, "First")   # Button ID 0
initButton(1, x, y, w, h, "Second")  # Button ID 1

if wasClicked(0):
  # Handle button 0 click
```

**ID allocation:**
- User manages IDs (0-based indexing)
- Range: 0-31 (32 total widgets)
- Out-of-range IDs are safely ignored
- Simple and efficient

## Implementation Reference

### Core Module: `lib/tui.nim` (Production)

**Key components:**

```nim
type
  WidgetType = enum
    wtButton, wtLabel, wtCheckbox, wtSlider
  
  Widget = object
    id, x, y, w, h: int
    kind: WidgetType
    group: int
    active, visible, hovered: bool
    # Widget-specific fields (label, checked, value, etc.)

var gWidgets: array[16, Widget]
var gGroupVisible: array[8, bool]
```

**Core API:**
- `initTUI()` - Initialize the system (call once)
- `initButton/Label/Checkbox/Slider(id, x, y, w, h, ...)` - Create widgets
- `updateTUI(mouseX, mouseY, mousePressed)` - Update all states
- `drawTUI(styleName)` - Render all visible widgets (uses theme styles automatically)
- `wasClicked/Toggled(id)` - Query click/toggle events
- `isHovered/Checked(id)` - Query states
- `getSliderValue(id)` - Get slider values
- `setGroupVisible(group, visible)` - Control group visibility

### Documentation

See [docs/TUI_REFERENCE.md](docs/TUI_REFERENCE.md) for quick reference and [docs/TUI_EVOLUTION.md](docs/TUI_EVOLUTION.md) for the progression from proof of concept to production.

### Usage Example: `docs/demos/tui_demo.md`

**Production example with all features:**

```nim on:init
  initTUI()
  
  # Main menu (group 0)
  initButton(0, 5, 3, 25, 3, "Start Game", 0)
  initButton(1, 5, 7, 25, 3, "Settings", 0)
  initLabel(2, 5, 1, 25, 1, "MAIN MENU", "center", 0)
  
  # Settings (group 1)
  initCheckbox(3, 40, 7, 25, 1, "Sound", true, 1)
  initSlider(4, 40, 12, 30, 3, "Volume", 0, 100, 50, 1)
  
  setGroupVisible(1, false)  # Hide settings initially
  var mousePressed = false
```

```nim on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false
```

```nim on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Toggle between menu and settings
  if wasClicked(1):  # Settings button
    setGroupVisible(0, false)
    setGroupVisible(1, true)

```nim on:render
  drawTUI("button")  # Draws all widgets from visible groups!
```

**Result:** Full multi-screen UI with buttons, labels, checkboxes, and sliders - all managed by one system!

## Grouping System (Implemented!)

### Design

Use integer-based groups for organization and visibility control:

```nim on:init
  # Game overlay (group 0)
  initButton(0, x, y, w, h, "Health", group=0)
  initButton(1, x, y, w, h, "Inventory", group=0)
  
  # Settings menu (group 1)  
  initButton(2, x, y, w, h, "Volume", group=1)
  initButton(3, x, y, w, h, "Controls", group=1)
  
  # Control visibility
  setGroupVisible(0, true)   # Show game overlay
  setGroupVisible(1, false)  # Hide settings
```

```nim on:update
  updateTUI(mouseX, mouseY, mousePressed)  # Updates all, but only visible groups interact
```

```nim on:render
  drawTUI("button")  # Renders only visible groups
```

### User-Friendly Enums

Users can define readable names:

```nim on:init
  # Define groups
  const
    GROUP_OVERLAY = 0
    GROUP_SETTINGS = 1
    GROUP_HUD = 2
  
  initButton(0, x, y, w, h, "Health", group=GROUP_OVERLAY)
  initButton(1, x, y, w, h, "Volume", group=GROUP_SETTINGS)
```

### Implementation

**State tracking (implemented in tui.nim):**
```nim
type
  Widget = object
    # ... existing fields ...
    group: int = 0  # Default group

const MAX_GROUPS = 8
var gGroupVisible: array[MAX_GROUPS, bool]
```

**Update logic (implemented):**
```nim
proc updateTUI*(mouseX, mouseY: int, mousePressed: bool) =
  for i in 0..<MAX_WIDGETS:
    if not gWidgets[i].active or not gGroupVisible[gWidgets[i].group]:
      continue
    # ... update logic ...
```

**Render order (implemented):**
```nim
proc drawTUI*(buffer: ptr TermBuffer, style: Style) =
  # Draw in group order (0 first, then 1, etc.)
  for groupId in 0..<MAX_GROUPS:
    if not gGroupVisible[groupId]:
      continue
    # Draw all widgets in this group
```

**Benefits:**
- ✅ Single system manages all UI contexts
- ✅ Clear input routing (only visible groups respond)
- ✅ Deterministic render order (group 0 first, then 1, etc.)
- ✅ Easy state coordination (disable game UI when settings open)

## Backend Compatibility

### Unified Buffer Abstraction

The UI system uses `TermBuffer` through the layer system, which is backend-agnostic:

```nim
proc drawTUI*(buffer: ptr TermBuffer, style: Style) =
  buffer[].writeText(x, y, text, style)  # Works everywhere!
```

**Supported backends:**
- ✅ **Terminal**: Direct ANSI/cell rendering
- ✅ **SDL3**: Cell-based OpenGL texture rendering  
- ✅ **WebGPU/WASM**: Browser-based cell rendering

**How it works:**
- `TermBuffer` is the universal cell grid
- Each backend implements `writeText()` for its renderer
- Layer system (via `gDefaultLayerRef`) routes to active backend
- No special handling needed in UI code

**Example - same code, all backends:**
```bash
./tstorie demo.md           # Terminal backend
./tstorie-sdl3 demo.md      # SDL3 graphics
# Browser: loads WASM        # WebGPU
```

### Canvas Pattern Compatibility

The UI system follows the proven canvas module pattern:
1. Direct buffer access via layers
2. Single update/render cycle
3. Style-based rendering

This ensures backend compatibility is automatic, just like `canvas`, `figlet`, and other modules.

### Theme Integration

The TUI system automatically integrates with t|Storie's theme system (`storie_themes.nim`), using semantic style names for different widget types and states:

**Widget-specific styles:**
- **Buttons**: Use `"button"` style (accent colors with proper contrast)
- **Button hover**: Uses `"link_focused"` style (highlighted appearance)
- **Button clicked**: Uses `"warning"` style (visual feedback)
- **Labels**: Use `"heading"` style for titles, `"body"` for normal text
- **Checkboxes**: Use `"info"` style (accent colors)
- **Checkbox hover**: Uses `"link_focused"` style
- **Sliders**: Use `"border"` style for tracks, `"info"` for handles

**Benefits:**
- Consistent visual design across all themes
- Semantic color usage (headings, buttons, info, warnings)
- Automatic theme switching (change theme, UI updates)
- No hardcoded colors in widget code

**Example - same UI, different themes:**
```bash
# Default theme
./tstorie tui_demo.md

# Dracula theme
./tstorie tui_demo.md --theme=dracula

# Custom theme
./tstorie tui_demo.md --theme=#001111#09343a#e0e0e0#909090#00d98e#ffff00#ff006e
```

The UI automatically adapts to any theme without code changes!

## Implementation Status

### ✅ Phase 1: Core Architecture (Complete)
- ✅ Retained mode pattern
- ✅ Fixed-size arrays
- ✅ ID-based access
- ✅ Backend-agnostic rendering

### ✅ Phase 2: Widget Library (Complete - tui.nim)
- ✅ Buttons (interactive, clickable, themed styling)
- ✅ Labels (text display with alignment, semantic styles)
- ✅ Checkboxes (boolean toggles, themed colors)
- ✅ Sliders (value selection with dragging)
- ✅ 16 widget capacity (up from 2)

### ✅ Phase 3: Organization (Complete)
- ✅ Group system (8 groups)
- ✅ Visibility control (per-widget and per-group)
- ✅ Deterministic render order
- ✅ Theme integration (automatic style application)
- ✅ State-based styling (hover, click, focus states)

**Implementation achieved:**
```nim
type
  WidgetType = enum
    wtButton, wtLabel, wtCheckbox, wtSlider
  
  Widget = object
    id: int
    kind: WidgetType
    x, y, w, h: int
    group: int
    active, visible, hovered: bool
    case kind:
      of wtButton:
        buttonLabel: string
        clicked: bool
      of wtLabel:
        labelText: string
        labelAlign: string
      of wtCheckbox:
        checkLabel: string
        checked, toggled: bool
      of wtSlider:
        sliderLabel: string
        minVal, maxVal, currentVal: int
        dragging: bool

var gWidgets: array[16, Widget]
var gGroupVisible: array[8, bool]
```

### 🔄 Phase 4: Advanced Features (Planned)
- Text input fields (keyboard input)
- Radio button groups (single selection)
- Dropdown menus
- Progress bars
- Focus management (TAB navigation)
- Layouts (automatic positioning)
- Themes (style overrides per widget)
- Animation states (smooth transitions)

### 🔄 Phase 5: Enhancements (Planned)
- Dirty rectangles (only redraw changed regions)
- Spatial partitioning (faster hit testing)
- Configurable element limits

## Best Practices

### Do's ✅
- Use integer IDs (0-based)
- Initialize all elements in `on:init`
- Call `updateTUI()` in `on:update`
- Call `drawTUI()` in `on:render`
- Use groups to organize related elements
- Query state (`wasClicked()`, `isHovered()`) after update
- Leverage global `mouseX`/`mouseY` (no need to track)

### Don'ts ❌
- Don't initialize elements in `on:render` (retained mode!)
- Don't call widget-specific draw functions (use `drawTUI()`)
- Don't exceed array bounds (widget IDs: 0-31, groups: 0-7)
- Don't create multiple TUI systems (use groups instead)
- Don't manually track mouse position (`mouseX`/`mouseY` are global)

## Comparison: Immediate vs Retained Mode

### Immediate Mode (tui_helpers.nim)
```nim
on:render
  if ui.button("id", "label", x, y, w, h):
    # clicked!
  # Must manually draw
  drawBoxSingle(x, y, w, h, style)
  drawCenteredText(x, y, w, h, "label", style)
```

**Issues:**
- State computed every frame
- Render logic mixed with interaction logic
- Manual drawing required
- More boilerplate

### Retained Mode (tui.nim)
```nim on:init
  initButton(0, x, y, w, h, "label")
```

```nim on:update
  updateTUI(mouseX, mouseY, mousePressed)
```

``` nim on:render
  drawTUI("button")
```

**Advantages:**
- State persistent
- Clear phase separation
- Automatic rendering
- Minimal boilerplate

## Technical Notes

### Thread Safety
Current implementation is single-threaded. Future multi-threaded considerations:
- Separate update/render threads would need locks on `gButtons`
- Or double-buffering: update writes to buffer A, render reads from buffer B

### Memory Overhead
**Current (32 widgets with 4 types):**
- ~100 bytes per Widget × 32 = ~3.2 KB
- ~8 bytes for group visibility × 8 = ~64 bytes
- **Total: ~3.3 KB** - Negligible overhead

**Original proof of concept (2 buttons):**
- ~80 bytes per ButtonState × 2 = ~160 bytes total

**Comparison:**
- Immediate mode: Recomputes every frame (CPU cost)
- Retained mode: Stores state (memory cost)
- Trade-off favors retained mode for UI (infrequent updates)

### Integration with Existing Systems

The UI system complements existing t|Storie features:

**With Canvas:**
```nim on:render
  # Draw background art
  canvas.rect(0, 0, width(), height(), "background")
  
  # Overlay UI
  drawTUI("button")
```

**With Figlet:**
```nim on:render
  # Title
  figletRender("GAME TITLE", 10, 2, "heading")
  
  # Menu buttons
  drawTUI("button")
```

**With Layers:**
```nim on:init
  addLayer("ui_layer", z=100)  # UI on top
```

```nim on:render
  # Game renders to layer 0
  # UI renders to layer "ui_layer"
  drawTUI("button")
```

## Future API Considerations

### Possible additions:

**Widget-specific styling:**
```nim
drawTUI("button", overrides = {
  0: "button_primary",   # Custom style for button 0
  1: "button_danger"     # Custom style for button 1
})
```

**Callbacks:**
```nim
initButton(0, x, y, w, h, "Click", onClick = proc() =
  echo "Clicked!"
)
```

**Layout helpers:**
```nim
layoutVertical(group=0, startY=5, spacing=2, [
  button("First"),
  button("Second"),
  button("Third")
])
```

## Conclusion

The retained mode UI system provides a **simple, reliable, and scalable** foundation for UI development in t|Storie. By using fixed-size arrays and clear phase separation, it avoids the pitfalls of both immediate mode complexity and dynamic allocation segfaults.

**Current Status:**
- ✅ Core architecture proven and stable
- ✅ 4 widget types implemented (buttons, labels, checkboxes, sliders)
- ✅ 32 widget capacity with 8 UI groups
- ✅ Full group management and visibility control
- ✅ Backend-agnostic (terminal, SDL3, WebGPU)
- ✅ Automatic theme integration with semantic styling
- ✅ State-based visual feedback (hover, click, toggle)

**Future Enhancements:**
1. Text input fields with keyboard handling
2. Radio button groups and dropdown menus
3. Focus management (TAB navigation)
4. Layout helpers (automatic positioning)
5. Advanced features (dirty rectangles, animations, themes)

The system is production-ready and actively used in t|Storie demos and applications.
