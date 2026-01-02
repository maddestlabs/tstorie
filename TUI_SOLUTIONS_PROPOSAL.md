# TUI Solutions: Memory Safety & Helper Functions

## Executive Summary

This document proposes **two complementary solutions** to enhance TUI development in tstorie:

1. **Native TUI via Handle System** - Safe native widgets using opaque integer handles (optional, advanced)
2. **Scripted TUI Helpers** - Rich helper functions to make scripted widgets easier (recommended, primary approach)

**Recommendation:** Focus on **#2 (scripted helpers)** as the primary approach, implement #1 only if proven necessary.

---

## Part 1: Safe Native TUI (If Needed)

### The Memory Problem Recap

Native `ref object` widgets fail because:
- **Type erasure** through pointer casts
- **Shared mutable references** (styleSheet corruption)
- **Closure lifetime mismanagement**
- **GC coordination failure** across Nimini boundary

### Solution: Handle-Based Architecture

Instead of passing pointers, use **integer handles** with a native registry.

#### Architecture

```
┌─────────────────────────────────────────────┐
│ Nimini Script                               │
│                                             │
│ let btn = createWidget("button", ...)      │
│ # btn = Value(kind: vkInt, i: 42)          │
│                                             │
│ setWidgetProperty(btn, "label", "Click")   │
│ renderWidget(btn, layer, x, y)             │
└─────────────────┬───────────────────────────┘
                  │ Integer handles only
                  │ (no pointers!)
                  ▼
┌─────────────────────────────────────────────┐
│ Native Registry (lib/tui_handles.nim)      │
│                                             │
│ var gWidgetRegistry: Table[int, Widget]    │
│ var gNextHandle = 1                        │
│                                             │
│ proc getWidget(handle: int): Widget        │
│   # Safe lookup, validation                │
└─────────────────────────────────────────────┘
```

#### Implementation

**`lib/tui_handles.nim`** (new module):

```nim
## Handle-based TUI system - FFI-safe native widgets
## 
## This module provides a safe wrapper around lib/tui.nim
## for use from scripting environments like nimini.

import tables, options
import tui  # The existing native TUI module
import storie_types

# ==============================================================================
# Registry & Handle Management
# ==============================================================================

type
  WidgetHandle* = distinct int  # Type-safe handle
  
  WidgetRegistry = object
    widgets: Table[int, Widget]
    managers: Table[int, WidgetManager]
    nextHandle: int

var gRegistry = WidgetRegistry(
  widgets: initTable[int, Widget](),
  managers: initTable[int, WidgetManager](),
  nextHandle: 1
)

proc allocHandle(): int =
  result = gRegistry.nextHandle
  inc gRegistry.nextHandle

proc registerWidget(w: Widget): WidgetHandle =
  let handle = allocHandle()
  gRegistry.widgets[handle] = w
  result = WidgetHandle(handle)

proc getWidget(handle: WidgetHandle): Option[Widget] =
  let h = handle.int
  if h in gRegistry.widgets:
    return some(gRegistry.widgets[h])
  return none(Widget)

proc unregisterWidget(handle: WidgetHandle) =
  gRegistry.widgets.del(handle.int)

# ==============================================================================
# Safe Widget Creation (Nimini-friendly)
# ==============================================================================

proc createLabel*(id: string, x, y, w, h: int, text: string = ""): WidgetHandle =
  ## Create a label widget, returns integer handle
  let label = newLabel(id, x, y, w, h, text)
  result = registerWidget(label)

proc createButton*(id: string, x, y, w, h: int, label: string = "Button"): WidgetHandle =
  ## Create a button widget, returns integer handle
  let btn = newButton(id, x, y, w, h, label)
  result = registerWidget(btn)

proc createCheckBox*(id: string, x, y: int, label: string = "", checked: bool = false): WidgetHandle =
  ## Create a checkbox widget, returns integer handle
  let cb = newCheckBox(id, x, y, label, checked)
  result = registerWidget(cb)

proc createSlider*(id: string, x, y, length: int, minVal, maxVal: float): WidgetHandle =
  ## Create a slider widget, returns integer handle
  let slider = newSlider(id, x, y, length, minVal, maxVal)
  result = registerWidget(slider)

# ==============================================================================
# Widget Property Access (Safe, Validated)
# ==============================================================================

proc setWidgetPosition*(handle: WidgetHandle, x, y: int): bool =
  ## Set widget position. Returns false if handle invalid.
  let widget = getWidget(handle)
  if widget.isSome:
    widget.get.setPosition(x, y)
    return true
  return false

proc setWidgetVisible*(handle: WidgetHandle, visible: bool): bool =
  let widget = getWidget(handle)
  if widget.isSome:
    widget.get.setVisible(visible)
    return true
  return false

proc setLabelText*(handle: WidgetHandle, text: string): bool =
  let widget = getWidget(handle)
  if widget.isSome and widget.get of Label:
    Label(widget.get).setText(text)
    return true
  return false

proc setButtonLabel*(handle: WidgetHandle, label: string): bool =
  let widget = getWidget(handle)
  if widget.isSome and widget.get of Button:
    Button(widget.get).setLabel(label)
    return true
  return false

proc getSliderValue*(handle: WidgetHandle): float =
  let widget = getWidget(handle)
  if widget.isSome and widget.get of Slider:
    return Slider(widget.get).value
  return 0.0

proc setSliderValue*(handle: WidgetHandle, value: float): bool =
  let widget = getWidget(handle)
  if widget.isSome and widget.get of Slider:
    Slider(widget.get).setValue(value)
    return true
  return false

proc isCheckBoxChecked*(handle: WidgetHandle): bool =
  let widget = getWidget(handle)
  if widget.isSome and widget.get of CheckBox:
    return CheckBox(widget.get).checked
  return false

proc setCheckBoxChecked*(handle: WidgetHandle, checked: bool): bool =
  let widget = getWidget(handle)
  if widget.isSome and widget.get of CheckBox:
    CheckBox(widget.get).setChecked(checked)
    return true
  return false

# ==============================================================================
# Widget Manager (Handle-based)
# ==============================================================================

proc createWidgetManager*(): int =
  ## Create widget manager, returns integer handle
  let handle = allocHandle()
  let wm = newWidgetManager()
  gRegistry.managers[handle] = wm
  result = handle

proc addWidgetToManager*(managerHandle: int, widgetHandle: WidgetHandle): bool =
  if managerHandle notin gRegistry.managers:
    return false
  let widget = getWidget(widgetHandle)
  if widget.isNone:
    return false
  
  gRegistry.managers[managerHandle].addWidget(widget.get)
  return true

proc renderManager*(managerHandle: int, layer: Layer): bool =
  if managerHandle notin gRegistry.managers:
    return false
  gRegistry.managers[managerHandle].render(layer)
  return true

proc updateManager*(managerHandle: int, dt: float): bool =
  if managerHandle notin gRegistry.managers:
    return false
  gRegistry.managers[managerHandle].update(dt)
  return true

# ==============================================================================
# Cleanup
# ==============================================================================

proc destroyWidget*(handle: WidgetHandle) =
  ## Destroy widget and free handle
  unregisterWidget(handle)

proc clearRegistry*() =
  ## Clear all widgets and managers (for cleanup/reset)
  gRegistry.widgets.clear()
  gRegistry.managers.clear()
  gRegistry.nextHandle = 1
```

#### Nimini Bindings

**In `index.nim`** (add these registrations):

```nim
# TUI Handle-Based API
registerNative("createLabel", proc(env: ref Env; args: seq[Value]): Value =
  if args.len < 5: return valInt(-1)
  let handle = createLabel(
    toString(args[0]),  # id
    toInt(args[1]),     # x
    toInt(args[2]),     # y
    toInt(args[3]),     # width
    toInt(args[4]),     # height
    if args.len > 5: toString(args[5]) else: ""  # text
  )
  return valInt(handle.int)
)

registerNative("createButton", proc(env: ref Env; args: seq[Value]): Value =
  if args.len < 5: return valInt(-1)
  let handle = createButton(
    toString(args[0]),  # id
    toInt(args[1]),     # x
    toInt(args[2]),     # y
    toInt(args[3]),     # width
    toInt(args[4]),     # height
    if args.len > 5: toString(args[5]) else: "Button"
  )
  return valInt(handle.int)
)

registerNative("setButtonLabel", proc(env: ref Env; args: seq[Value]): Value =
  if args.len < 2: return valBool(false)
  let success = setButtonLabel(WidgetHandle(toInt(args[0])), toString(args[1]))
  return valBool(success)
)

# ... etc for other widget operations
```

#### Usage from Nimini

```nim
# Create native widgets via handles
var manager = createWidgetManager()

var btn1 = createButton("btn1", 10, 5, 20, 3, "Submit")
var btn2 = createButton("btn2", 35, 5, 20, 3, "Cancel")
var slider = createSlider("slider1", 10, 10, 40, 0.0, 100.0)

addWidgetToManager(manager, btn1)
addWidgetToManager(manager, btn2)
addWidgetToManager(manager, slider)

# Use widgets
setSliderValue(slider, 75.0)
var currentValue = getSliderValue(slider)

# Render
renderManager(manager, 0)
```

### Advantages of Handle System

✅ **Memory Safety** - No pointers cross FFI boundary
✅ **Type Safety** - Handle validity checked on every operation
✅ **Clear Ownership** - Registry owns all widgets
✅ **Debuggability** - Can log all handle operations
✅ **Resource Tracking** - Know what's allocated
✅ **Gradual Adoption** - Can use alongside scripted widgets

### Disadvantages

❌ **Complexity** - Extra layer of indirection
❌ **Maintenance** - Wrapper must stay in sync with native TUI
❌ **Limited** - Can't expose all widget features easily
❌ **Boilerplate** - Need wrapper for every operation
❌ **Performance** - Handle lookup overhead (minor)

---

## Part 2: Scripted TUI Helpers (Recommended)

### The Better Approach

Instead of fighting FFI to expose native widgets, **enhance scripted widgets** with rich helper functions.

### Analysis of Current tui.md

The demo reimplements common patterns:

```nim
# Manual box drawing (13 lines)
proc drawBox(x, y, w, h: int, style: Style) =
  draw(0, x, y, "┌", style)
  # ... 11 more lines

# Manual hit testing
if mx >= x and mx < x + w and my >= y and my < y + h:
  clickedWidget = i

# Manual text centering
let labelX = x + (w - len(label)) div 2
let labelY = y + h div 2

# Manual focus style logic
let btnStyle = if focused: getStyle("info") else: getStyle("border")
```

**These patterns should be helpers!**

### Proposed Helper Module

**`lib/tui_helpers.nim`** (new module):

```nim
## TUI Helper Functions
## 
## Stateless utility functions to make scripted TUI widgets easier.
## All functions are pure (no hidden state) and FFI-safe.

import storie_types
import ../src/types

# ==============================================================================
# Box Drawing
# ==============================================================================

proc drawBox*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a box with nice corners
  ## Usage: drawBox(0, 10, 10, 20, 5, getStyle("border"))
  draw(layer, x, y, "┌", style)
  draw(layer, x + w - 1, y, "┐", style)
  draw(layer, x, y + h - 1, "└", style)
  draw(layer, x + w - 1, y + h - 1, "┘", style)
  
  for dx in 1 ..< w - 1:
    draw(layer, x + dx, y, "─", style)
    draw(layer, x + dx, y + h - 1, "─", style)
  
  for dy in 1 ..< h - 1:
    draw(layer, x, y + dy, "│", style)
    draw(layer, x + w - 1, y + dy, "│", style)

proc drawBoxDouble*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a double-line box
  draw(layer, x, y, "╔", style)
  draw(layer, x + w - 1, y, "╗", style)
  draw(layer, x, y + h - 1, "╚", style)
  draw(layer, x + w - 1, y + h - 1, "╝", style)
  
  for dx in 1 ..< w - 1:
    draw(layer, x + dx, y, "═", style)
    draw(layer, x + dx, y + h - 1, "═", style)
  
  for dy in 1 ..< h - 1:
    draw(layer, x, y + dy, "║", style)
    draw(layer, x + w - 1, y + dy, "║", style)

proc drawBoxRounded*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a box with rounded corners
  draw(layer, x, y, "╭", style)
  draw(layer, x + w - 1, y, "╮", style)
  draw(layer, x, y + h - 1, "╰", style)
  draw(layer, x + w - 1, y + h - 1, "╯", style)
  
  for dx in 1 ..< w - 1:
    draw(layer, x + dx, y, "─", style)
    draw(layer, x + dx, y + h - 1, "─", style)
  
  for dy in 1 ..< h - 1:
    draw(layer, x, y + dy, "│", style)
    draw(layer, x + w - 1, y + dy, "│", style)

proc fillBox*(layer: int, x, y, w, h: int, ch: string, style: Style) =
  ## Fill a rectangular area with a character
  for dy in 0 ..< h:
    for dx in 0 ..< w:
      draw(layer, x + dx, y + dy, ch, style)

# ==============================================================================
# Hit Testing
# ==============================================================================

proc pointInRect*(px, py, rx, ry, rw, rh: int): bool =
  ## Check if point (px, py) is inside rectangle
  ## Usage: if pointInRect(mouseX, mouseY, buttonX, buttonY, buttonW, buttonH):
  px >= rx and px < rx + rw and py >= ry and py < ry + rh

proc rectsOverlap*(x1, y1, w1, h1, x2, y2, w2, h2: int): bool =
  ## Check if two rectangles overlap
  x1 < x2 + w2 and x1 + w1 > x2 and
  y1 < y2 + h2 and y1 + h1 > y2

# ==============================================================================
# Text Measurement & Centering
# ==============================================================================

proc measureText*(text: string): int =
  ## Get display width of text (handles UTF-8)
  ## Note: Currently assumes 1 char = 1 cell
  ## TODO: Handle wide characters (CJK, emojis)
  result = text.len

proc centerTextX*(text: string, boxX, boxWidth: int): int =
  ## Calculate X position to center text in box
  ## Usage: let x = centerTextX("Hello", 10, 30)
  let textWidth = measureText(text)
  result = boxX + (boxWidth - textWidth) div 2

proc centerTextY*(boxY, boxHeight: int): int =
  ## Calculate Y position to center single-line text vertically
  result = boxY + boxHeight div 2

proc alignTextX*(text: string, boxX, boxWidth: int, align: string): int =
  ## Align text horizontally: "left", "center", "right"
  case align
  of "center": centerTextX(text, boxX, boxWidth)
  of "right": boxX + boxWidth - measureText(text)
  else: boxX  # left

# ==============================================================================
# Style Helpers
# ==============================================================================

proc getFocusedStyle*(normalStyle, focusedStyle: string, isFocused: bool): Style =
  ## Get style based on focus state
  ## Usage: let style = getFocusedStyle("button", "button.focused", focused)
  if isFocused:
    getStyle(focusedStyle)
  else:
    getStyle(normalStyle)

proc getStateStyle*(baseStyle: string, isFocused, isHovered, isPressed, isDisabled: bool): Style =
  ## Get style based on widget state (priority: disabled > pressed > focused > hovered > normal)
  if isDisabled:
    return getStyle(baseStyle & ".disabled")
  if isPressed:
    return getStyle(baseStyle & ".active")
  if isFocused:
    return getStyle(baseStyle & ".focused")
  if isHovered:
    return getStyle(baseStyle & ".hover")
  return getStyle(baseStyle & ".normal")

# ==============================================================================
# Widget Rendering Helpers
# ==============================================================================

proc drawButton*(layer: int, x, y, w, h: int, label: string, isFocused: bool, isPressed: bool = false) =
  ## Draw a complete button widget
  ## Handles box, label centering, and state styling automatically
  let style = if isFocused: getStyle("info") else: getStyle("border")
  
  if isPressed:
    # Filled appearance when pressed
    fillBox(layer, x, y, w, h, "█", getStyle("button"))
  else:
    drawBox(layer, x, y, w, h, style)
  
  # Center label
  let labelX = centerTextX(label, x, w)
  let labelY = centerTextY(y, h)
  draw(layer, labelX, labelY, label, style)

proc drawTextBox*(layer: int, x, y, w, h: int, labelText, value: string, cursorPos: int, isFocused: bool) =
  ## Draw a complete text input widget
  let style = if isFocused: getStyle("highlight") else: getStyle("border")
  drawBox(layer, x, y, w, h, style)
  
  # Label
  draw(layer, x + 1, y, labelText, getStyle("info"))
  
  # Value
  draw(layer, x + 2, y + 1, value, getStyle("default"))
  
  # Cursor (if focused)
  if isFocused:
    draw(layer, x + 2 + cursorPos, y + 1, "_", getStyle("highlight"))

proc drawSlider*(layer: int, x, y, w, h: int, labelText: string, value, minVal, maxVal: float, isFocused: bool) =
  ## Draw a complete slider widget
  let style = if isFocused: getStyle("highlight") else: getStyle("border")
  drawBox(layer, x, y, w, h, style)
  
  # Label
  draw(layer, x + 1, y, labelText, getStyle("info"))
  
  # Track
  let trackX = x + 2
  let trackY = y + 1
  let trackWidth = w - 4
  
  let percent = (value - minVal) / (maxVal - minVal)
  let handlePos = int(percent * float(trackWidth - 1))
  
  for dx in 0 ..< trackWidth:
    let ch = if dx == handlePos: "O" else: "─"
    let chStyle = if dx == handlePos: getStyle("warning") else: getStyle("default")
    draw(layer, trackX + dx, trackY, ch, chStyle)
  
  # Value display
  let valueText = $int(value)
  draw(layer, x + w - valueText.len - 2, y + 2, valueText, getStyle("default"))

proc drawCheckBox*(layer: int, x, y: int, labelText: string, checked: bool, isFocused: bool) =
  ## Draw a complete checkbox widget
  let style = if isFocused: getStyle("highlight") else: getStyle("default")
  let checkChar = if checked: "X" else: " "
  draw(layer, x, y, "[" & checkChar & "]", style)
  draw(layer, x + 4, y, labelText, getStyle("default"))

# ==============================================================================
# Layout Helpers
# ==============================================================================

proc layoutGrid*(startX, startY, cols, spacing: int, index: int): tuple[x, y: int] =
  ## Calculate position for grid layout
  ## Usage: let (x, y) = layoutGrid(10, 10, 3, 5, widgetIndex)
  let col = index mod cols
  let row = index div cols
  result.x = startX + col * spacing
  result.y = startY + row * spacing

proc layoutVertical*(startX, startY, spacing: int, index: int): tuple[x, y: int] =
  ## Calculate position for vertical stack layout
  result.x = startX
  result.y = startY + index * spacing

proc layoutHorizontal*(startX, startY, spacing: int, index: int): tuple[x, y: int] =
  ## Calculate position for horizontal row layout
  result.x = startX + index * spacing
  result.y = startY

# ==============================================================================
# Focus Management Helpers
# ==============================================================================

proc findNextFocusable*(currentIndex, count: int, direction: int = 1): int =
  ## Calculate next focusable index (wraps around)
  ## direction: 1 for forward, -1 for backward
  result = (currentIndex + direction + count) mod count

proc findClickedWidget*(mouseX, mouseY: int, widgetX, widgetY, widgetW, widgetH: seq[int]): int =
  ## Find which widget was clicked (returns index or -1)
  for i in countdown(widgetX.len - 1, 0):
    if pointInRect(mouseX, mouseY, widgetX[i], widgetY[i], widgetW[i], widgetH[i]):
      return i
  return -1

# ==============================================================================
# Animation Helpers
# ==============================================================================

proc lerpInt*(a, b: int, t: float): int =
  ## Linear interpolation between two integers
  ## t should be 0.0 to 1.0
  a + int((float(b - a) * t))

proc lerpFloat*(a, b: float, t: float): float =
  ## Linear interpolation between two floats
  a + (b - a) * t

proc smoothstep*(t: float): float =
  ## Smooth easing function (0.0 to 1.0)
  result = t * t * (3.0 - 2.0 * t)
```

### Nimini Bindings

**In `lib/tstorie_export_metadata.nim`**:

```nim
# TUI Helper functions -> lib/tui_helpers
gFunctionMetadata["drawBox"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw a box with nice corners")

gFunctionMetadata["drawBoxDouble"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw a double-line box")

gFunctionMetadata["drawBoxRounded"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw a box with rounded corners")

gFunctionMetadata["fillBox"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Fill rectangular area")

gFunctionMetadata["pointInRect"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Hit test for rectangles")

gFunctionMetadata["centerTextX"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Calculate centered X position")

gFunctionMetadata["drawButton"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw complete button widget")

gFunctionMetadata["drawTextBox"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw complete text input widget")

gFunctionMetadata["drawSlider"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw complete slider widget")

gFunctionMetadata["drawCheckBox"] = FunctionMetadata(
  storieLibs: @["tui_helpers"],
  description: "Draw complete checkbox widget")

# ... etc
```

**In `index.nim`** (register with nimini):

```nim
# TUI Helpers
registerNative("drawBox", nimini_drawBox,
  storieLibs = @["tui_helpers"],
  description = "Draw a box with corners")

registerNative("pointInRect", nimini_pointInRect,
  storieLibs = @["tui_helpers"],
  description = "Check if point is in rectangle")

registerNative("centerTextX", nimini_centerTextX,
  storieLibs = @["tui_helpers"],
  description = "Calculate centered text position")

registerNative("drawButton", nimini_drawButton,
  storieLibs = @["tui_helpers"],
  description = "Draw complete button widget")

registerNative("drawTextBox", nimini_drawTextBox,
  storieLibs = @["tui_helpers"],
  description = "Draw text input widget")

registerNative("drawSlider", nimini_drawSlider,
  storieLibs = @["tui_helpers"],
  description = "Draw slider widget")

registerNative("drawCheckBox", nimini_drawCheckBox,
  storieLibs = @["tui_helpers"],
  description = "Draw checkbox widget")

registerNative("findClickedWidget", nimini_findClickedWidget,
  storieLibs = @["tui_helpers"],
  description = "Find which widget was clicked")

# ... etc
```

### Usage Comparison

#### Before (Current tui.md - 400 lines)

```nim
# Manual box drawing
proc drawBox(x, y, w, h: int, style: Style) =
  draw(0, x, y, "┌", style)
  draw(0, x + w - 1, y, "┐", style)
  # ... 10 more lines

# Manual button rendering
if widgetTypes[i] == 1:
  let btnIndex = i - 6
  let btnStyle = if focused: getStyle("info") else: getStyle("border")
  
  if btnPressed[btnIndex]:
    fillRect(0, x, y, w, h, "#", getStyle("button"))
  else:
    drawBox(x, y, w, h, btnStyle)
  
  let label = btnLabels[btnIndex]
  let labelX = x + (w - len(label)) div 2
  let labelY = y + h div 2
  draw(0, labelX, labelY, label, btnStyle)

# Manual hit testing
var clickedWidget = -1
var i = 0
while i < widgetCount:
  if mx >= x and mx < x + w and my >= y and my < y + h:
    clickedWidget = i
    break
  i = i + 1
```

#### After (With Helpers - ~200 lines)

```nim
# Box drawing is built-in
drawBox(0, x, y, w, h, style)

# Button rendering is one call
if widgetTypes[i] == 1:
  let btnIndex = i - 6
  drawButton(0, x, y, w, h, btnLabels[btnIndex], focused, btnPressed[btnIndex])

# Hit testing is one call
var clickedWidget = findClickedWidget(mx, my, widgetX, widgetY, widgetW, widgetH)
```

**Result: 50% less code, more readable, more maintainable**

---

## Recommendation Matrix

| Criteria | Native Handle System | Scripted Helpers |
|----------|---------------------|------------------|
| **Memory Safety** | ✅ Safe | ✅ Safe |
| **Implementation Effort** | ❌ High (2-3 days) | ✅ Low (4-6 hours) |
| **Maintenance Burden** | ❌ High | ✅ Low |
| **User Learning Curve** | ⚠️ Medium | ✅ Low |
| **Flexibility** | ❌ Limited by wrapper | ✅ Full script control |
| **Performance** | ✅ Native speed | ⚠️ Interpreted (but fast enough) |
| **Distribution** | ⚠️ Native dependency | ✅ Export-friendly |
| **Debugging** | ⚠️ Cross-boundary issues | ✅ All in script |
| **Customization** | ❌ Fixed widget behavior | ✅ Fully customizable |
| **Export Support** | ✅ Works in export | ✅ Works in export |

**Score: Native = 4/10, Scripted Helpers = 9/10**

---

## Implementation Plan

### Phase 1: Core Helpers (4 hours)

Implement essentials:
- `drawBox`, `drawBoxRounded`, `fillBox`
- `pointInRect`, `rectsOverlap`
- `centerTextX`, `centerTextY`, `alignTextX`
- `measureText`

Register with nimini, add metadata, test.

### Phase 2: Widget Helpers (2 hours)

Implement:
- `drawButton`
- `drawTextBox`
- `drawSlider`
- `drawCheckBox`

Update tui.md demo to use helpers, verify it works.

### Phase 3: Layout & Focus (2 hours)

Implement:
- `layoutGrid`, `layoutVertical`, `layoutHorizontal`
- `findNextFocusable`
- `findClickedWidget`
- `getFocusedStyle`, `getStateStyle`

### Phase 4: Documentation (1 hour)

Create:
- `TUI_HELPERS_GUIDE.md` with examples
- Update `TUI_QUICK_REFERENCE.md`
- Add helper showcase demo

**Total: ~9 hours for complete scripted helper system**

---

## Optional: Handle System (If Needed Later)

If users demand native widgets despite scripted success:

### Phase 1: Core Infrastructure (8 hours)
- Handle registry system
- Widget creation functions
- Basic property getters/setters

### Phase 2: Widget Types (8 hours)
- Label, Button wrappers
- CheckBox, Slider wrappers
- Manager integration

### Phase 3: Nimini Bindings (4 hours)
- Register all functions
- Test from scripts
- Handle lifecycle properly

**Total: ~20 hours for handle-based native system**

**Decision: Only implement if scripted helpers prove insufficient**

---

## Conclusion

### Primary Recommendation: Scripted Helpers

**Implement lib/tui_helpers.nim with rich helper functions**

**Why:**
1. **Safer** - No FFI complexity, no memory issues
2. **Faster to implement** - 9 hours vs 20+ hours
3. **More maintainable** - Pure functions, no state
4. **More flexible** - Users can customize everything
5. **Better for learning** - Clear, visible behavior
6. **Export-friendly** - Helpers compile to native code too
7. **Proven approach** - Current tui.md works great, just verbose

### Secondary Option: Handle System

**Only if users specifically request native widget state management**

Most use cases are satisfied by scripted widgets + helpers. The handle system is available as a "power user" option if proven necessary, but shouldn't be the default recommendation.

### Next Steps

1. Create `lib/tui_helpers.nim` with Phase 1 functions
2. Add nimini bindings in `index.nim`
3. Add metadata in `lib/tstorie_export_metadata.nim`
4. Update `tui.md` demo to use helpers
5. Measure: lines of code before/after, performance, user feedback
6. If successful, expand to Phases 2-4
7. Monitor: if users ask for native widgets, consider handle system

**The scripted approach with helpers is the path forward.**
