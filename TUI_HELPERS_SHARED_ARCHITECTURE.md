# TUI Helpers: Shared Foundation for Scripted AND Native Widgets

## TL;DR: Perfect Layering

**YES!** `lib/tui_helpers.nim` would be **shared by both approaches**, creating a beautiful layered architecture:

```
┌─────────────────────────────────────────────────┐
│ User Scripts (Nimini)                           │
│ - Direct helper calls                           │
│ - Manual state management                       │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────┐
│ Native Widgets (lib/tui.nim) - OPTIONAL        │
│ - Widget ref objects with state                 │
│ - Uses helpers internally                       │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────┐
│ TUI Helpers (lib/tui_helpers.nim)              │
│ - Stateless primitives                          │
│ - Works from any context                        │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────┐
│ Core TStorie (src/layers, src/types)           │
│ - Terminal buffer operations                    │
│ - Layer compositing                             │
└─────────────────────────────────────────────────┘
```

This is **excellent architecture** - let me show you why.

---

## How They Share

### Helper Functions Are Stateless Primitives

```nim
# lib/tui_helpers.nim - Pure functions, no state
proc drawBox*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a box with corners
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

proc centerTextX*(text: string, boxX, boxWidth: int): int =
  ## Calculate X position to center text
  let textWidth = text.len  # TODO: handle UTF-8 width
  result = boxX + (boxWidth - textWidth) div 2

proc pointInRect*(px, py, rx, ry, rw, rh: int): bool =
  ## Hit test for rectangles
  px >= rx and px < rx + rw and py >= ry and py < ry + rh
```

**Key: These work on raw coordinates and layers - no widget state!**

### Native Widgets Call Helpers Internally

```nim
# lib/tui.nim - Native Button widget
import tui_helpers  # ← Import the helpers!

method render*(btn: Button, layer: Layer) =
  if not btn.visible:
    return
  
  let style = btn.resolveStyle()
  
  # USE THE HELPER instead of manual drawing!
  drawBox(layer.id, btn.x, btn.y, btn.width, btn.height, style)
  
  # USE THE HELPER for text centering!
  let labelX = centerTextX(btn.label, btn.x, btn.width)
  let labelY = centerTextY(btn.y, btn.height)
  draw(layer.id, labelX, labelY, btn.label, style)

method contains*(btn: Button, px, py: int): bool =
  # USE THE HELPER for hit testing!
  pointInRect(px, py, btn.x, btn.y, btn.width, btn.height)
```

**Result: Native widgets are thin wrappers with state management, delegating visuals to helpers.**

### Scripted Widgets Call Helpers Directly

```nim
# docs/demos/tui.md - User script
# Widget state in arrays
var widgetX = @[10, 10, 10]
var widgetY = @[5, 9, 13]
var btnLabels = @["Submit", "Clear", "Reset"]

# Render loop
var i = 0
while i < widgetCount:
  if widgetTypes[i] == 1:  # Button
    let focused = (i == focusIndex)
    let pressed = btnPressed[i - buttonStartIndex]
    
    # USE THE SAME HELPER the native widgets use!
    drawButton(0, widgetX[i], widgetY[i], widgetW[i], widgetH[i],
               btnLabels[i - buttonStartIndex], focused, pressed)
  
  i = i + 1

# Input handling
if event.type == "mouse" and event.action == "press":
  # USE THE SAME HELPER for hit testing!
  let clicked = findClickedWidget(event.x, event.y, widgetX, widgetY, widgetW, widgetH)
  if clicked >= 0:
    focusIndex = clicked
```

**Result: Scripted code is shorter and looks identical to native output!**

---

## Concrete Example: Button Rendering

### Current tui.md (Manual, ~20 lines)

```nim
if widgetTypes[i] == 1:
  let btnIndex = i - 6
  let btnStyle = if focused: getStyle("info") else: getStyle("border")
  
  # Manual box drawing
  if btnPressed[btnIndex]:
    fillRect(0, x, y, w, h, "#", getStyle("button"))
  else:
    # Draw box manually
    draw(0, x, y, "┌", btnStyle)
    draw(0, x + w - 1, y, "┐", btnStyle)
    draw(0, x, y + h - 1, "└", btnStyle)
    draw(0, x + w - 1, y + h - 1, "┘", btnStyle)
    
    # ... 8 more lines of box drawing
  
  # Manual centering
  let label = btnLabels[btnIndex]
  let labelX = x + (w - len(label)) div 2
  let labelY = y + h div 2
  draw(0, labelX, labelY, label, btnStyle)
```

### With Helpers (~4 lines)

```nim
if widgetTypes[i] == 1:
  let btnIndex = i - 6
  let focused = (i == focusIndex)
  drawButton(0, x, y, w, h, btnLabels[btnIndex], focused, btnPressed[btnIndex])
```

### Native Widget (~5 lines in Widget.render)

```nim
method render*(btn: Button, layer: Layer) =
  if not btn.visible: return
  
  let style = btn.resolveStyle()
  let focused = (btn.state == wsFocused)
  let pressed = (btn.state == wsActive)
  
  drawButton(layer.id, btn.x, btn.y, btn.width, btn.height, btn.label, focused, pressed)
```

**All three produce identical output because they use the same `drawButton` helper!**

---

## Real Implementation Example

### lib/tui_helpers.nim

```nim
## TUI Helpers - Shared primitives for all TUI approaches

import ../src/types
import storie_types

# ==============================================================================
# Box Drawing (Used by both native and scripted)
# ==============================================================================

proc drawBox*(layer: int, x, y, w, h: int, style: Style) =
  draw(layer, x, y, "┌", style)
  draw(layer, x + w - 1, y, "┐", style)
  draw(layer, x, y + h - 1, "└", style)
  draw(layer, x + w - 1, y + h - 1, "┘", style)
  
  for dx in 1 ..< w - 1:
    draw(layer, x + dx, y, "─", style)
    draw(layer, x + dx, y + h - 1, "─", style)
  
  for dy in 1 ..< h - 1:
    draw(layer, x, y + dy, "│", style)
    draw(layer, x + w - 1, y + dy, "║", style)

# ==============================================================================
# Widget Rendering (Used by both)
# ==============================================================================

proc drawButton*(layer: int, x, y, w, h: int, label: string, 
                 isFocused: bool, isPressed: bool = false) =
  let style = if isFocused: getStyle("info") else: getStyle("border")
  
  if isPressed:
    # Filled when pressed
    for dy in 0 ..< h:
      for dx in 0 ..< w:
        draw(layer, x + dx, y + dy, "█", getStyle("button"))
  else:
    drawBox(layer, x, y, w, h, style)
  
  # Center label
  let labelX = centerTextX(label, x, w)
  let labelY = centerTextY(y, h)
  draw(layer, labelX, labelY, label, style)

# ==============================================================================
# Hit Testing (Used by both)
# ==============================================================================

proc pointInRect*(px, py, rx, ry, rw, rh: int): bool =
  px >= rx and px < rx + rw and py >= ry and py < ry + rh

proc findClickedWidget*(mouseX, mouseY: int, 
                       widgetX, widgetY, widgetW, widgetH: seq[int]): int =
  for i in countdown(widgetX.len - 1, 0):
    if pointInRect(mouseX, mouseY, widgetX[i], widgetY[i], widgetW[i], widgetH[i]):
      return i
  return -1

# ==============================================================================
# Text Helpers (Used by both)
# ==============================================================================

proc centerTextX*(text: string, boxX, boxWidth: int): int =
  boxX + (boxWidth - text.len) div 2

proc centerTextY*(boxY, boxHeight: int): int =
  boxY + boxHeight div 2
```

### lib/tui.nim - Native Implementation

```nim
## Native TUI Widgets - Uses helpers internally

import tui_helpers  # ← Share the helpers!
import storie_types
import ../src/types

type
  Button* = ref object of Widget
    label*: string
    # ... other fields

method render*(btn: Button, layer: Layer) =
  if not btn.visible:
    return
  
  let focused = (btn.state == wsFocused)
  let pressed = (btn.state == wsActive)
  
  # DELEGATE to helper - same code as scripts!
  drawButton(layer.id, btn.x, btn.y, btn.width, btn.height, 
             btn.label, focused, pressed)

method contains*(btn: Button, px, py: int): bool =
  # DELEGATE to helper
  pointInRect(px, py, btn.x, btn.y, btn.width, btn.height)
```

### User Script - Direct Usage

```nim
# docs/demos/tui.md - Scripted approach

# Widget state
var btnX = @[10, 30]
var btnY = @[5, 5]
var btnLabels = @["Submit", "Cancel"]
var btnFocused = @[true, false]

# Render
var i = 0
while i < 2:
  # SAME function native widgets call!
  drawButton(0, btnX[i], btnY[i], 15, 3, btnLabels[i], btnFocused[i], false)
  i = i + 1

# Input
if event.type == "mouse":
  # SAME function native widgets use!
  let clicked = findClickedWidget(event.x, event.y, btnX, btnY, 
                                   @[15, 15], @[3, 3])
```

---

## Benefits of Sharing

### 1. **DRY Principle** ✅

```
Before:
- Native widgets: drawBox in lib/tui.nim (20 lines)
- Scripts: drawBox in each demo (20 lines × N demos)
Total: 20 + 20N lines

After:
- Helpers: drawBox in lib/tui_helpers.nim (20 lines)
- Native: calls helper (1 line)
- Scripts: call helper (1 line)
Total: 20 + 1 + N lines
```

### 2. **Visual Consistency** ✅

**Guaranteed**: Scripted and native widgets look identical because they use the same rendering code.

```nim
# Script renders button
drawButton(0, 10, 10, 20, 3, "Click", true)

# Native widget renders button
btn.render(layer)  # Internally calls same drawButton()

# Both produce EXACT same output
```

### 3. **Testing** ✅

Test helpers once, both approaches benefit:

```nim
# Test helper (once)
test "drawButton renders correctly":
  let layer = newLayer(80, 25)
  drawButton(0, 10, 10, 20, 3, "Test", true)
  # Verify buffer contents...

# Now BOTH native and scripted buttons are tested
```

### 4. **Bug Fixes** ✅

Fix a rendering bug in one place:

```nim
# Bug: Box corners don't render at edges
proc drawBox*(layer: int, x, y, w, h: int, style: Style) =
  # Fix bounds checking...
  if x < 0 or y < 0: return  # ← FIX ONCE
  # ...

# Native widgets automatically fixed
# Scripted widgets automatically fixed
```

### 5. **Learning Path** ✅

Users learn helpers in scripts, then native widgets are familiar:

```nim
# Learn in script
drawButton(0, x, y, w, h, label, focused, pressed)

# Native API feels natural because it's the same underneath
let btn = newButton("btn1", x, y, w, h, label)
btn.render(layer)  # Uses same drawButton internally!
```

### 6. **Migration Path** ✅

Easy to upgrade from scripted to native:

```nim
# Starting point: Scripted (200 lines)
var btnLabels = @["Submit", "Clear"]
drawButton(0, 10, 5, 15, 3, btnLabels[0], focused, false)

# Upgrade to native (50 lines)
let submitBtn = newButton("submit", 10, 5, 15, 3, "Submit")
submitBtn.render(layer)

# Same visuals, less code!
```

### 7. **Export Benefits** ✅

When exported to native Nim, helpers compile identically:

```nim
# Script uses helper
drawButton(0, x, y, w, h, label, focused, pressed)

# Exported native code
drawButton(0, x, y, w, h, label, focused, pressed)

# No performance difference - same compiled function!
```

---

## Architecture Comparison

### Without Helpers (Current)

```
┌─────────────────────────┐
│ User Scripts            │
│ - Manual box drawing    │
│ - Manual centering      │
│ - Manual hit testing    │
│ - 400 lines per demo    │
└─────────────┬───────────┘
              │
              ▼
┌─────────────────────────┐
│ Core Drawing            │
│ - draw(), fillRect()    │
└─────────────────────────┘

+ Native Widgets (separate, duplicates logic)
┌─────────────────────────┐
│ lib/tui.nim             │
│ - Manual box drawing    │
│ - Manual centering      │
│ - Same logic, different│
│   code (segfaults)      │
└─────────────┬───────────┘
              │
              ▼
┌─────────────────────────┐
│ Core Drawing            │
│ - draw(), fillRect()    │
└─────────────────────────┘

PROBLEM: Duplicated logic, inconsistent rendering
```

### With Helpers (Proposed)

```
┌─────────────────────────┐       ┌─────────────────────────┐
│ User Scripts            │       │ Native Widgets          │
│ - Call helpers          │       │ - ref object state      │
│ - Simple state arrays   │       │ - Call helpers          │
│ - 150 lines per demo    │       │ - Lifecycle management  │
└───────────┬─────────────┘       └───────────┬─────────────┘
            │                                  │
            └──────────────┬───────────────────┘
                           │ Both use same helpers
                           ▼
            ┌─────────────────────────────────┐
            │ TUI Helpers (lib/tui_helpers)   │
            │ - drawBox, drawButton           │
            │ - centerTextX, pointInRect      │
            │ - Stateless, pure functions     │
            └──────────────┬──────────────────┘
                           │
                           ▼
            ┌─────────────────────────────────┐
            │ Core Drawing (src/layers)       │
            │ - draw(), fillRect()            │
            └─────────────────────────────────┘

SOLUTION: Shared logic, consistent rendering, less code
```

---

## Implementation Strategy

### Phase 1: Create Helpers (Works Standalone)

```nim
# lib/tui_helpers.nim
proc drawBox*(...) = ...
proc drawButton*(...) = ...
proc pointInRect*(...) = ...

# Register with nimini
# index.nim
registerNative("drawBox", nimini_drawBox, ...)
registerNative("drawButton", nimini_drawButton, ...)
```

**Test**: Update tui.md demo to use helpers. Should be smaller and clearer.

### Phase 2: Native Widgets Use Helpers

```nim
# lib/tui.nim
import tui_helpers  # ← Add import

method render*(btn: Button, layer: Layer) =
  # Replace manual rendering with helper call
  drawButton(layer.id, btn.x, btn.y, btn.width, btn.height,
             btn.label, btn.state == wsFocused, btn.state == wsActive)
```

**Test**: Native widgets should render identically to scripted ones.

### Phase 3: Verify Consistency

```nim
# Create demo with BOTH approaches
# docs/demos/tui_mixed.md

# Scripted button at (10, 5)
drawButton(0, 10, 5, 20, 3, "Scripted", true, false)

# Native button at (35, 5)
var nativeBtn = createButton("btn1", 35, 5, 20, 3, "Native")
renderWidget(nativeBtn, 0)

# They should look IDENTICAL!
```

---

## API Design Considerations

### Helper Function Signatures

Design helpers to work for both contexts:

```nim
# GOOD: Takes raw coordinates + layer ID
proc drawButton*(layer: int, x, y, w, h: int, label: string, 
                 focused: bool, pressed: bool)

# Native widget can call it:
drawButton(layer.id, btn.x, btn.y, btn.width, btn.height, 
           btn.label, btn.state == wsFocused, btn.state == wsActive)

# Script can call it:
drawButton(0, widgetX[i], widgetY[i], widgetW[i], widgetH[i],
           btnLabels[i], focusIndex == i, btnPressed[i])
```

### Avoid Widget-Specific Helpers

```nim
# BAD: Requires Widget object
proc renderButton*(widget: Widget, layer: Layer)

# GOOD: Works with any data source
proc drawButton*(layer: int, x, y, w, h: int, label: string, ...)
```

### Provide Multiple Levels

```nim
# Low-level (for custom logic)
proc drawBox*(layer: int, x, y, w, h: int, style: Style)
proc centerTextX*(text: string, boxX, boxWidth: int): int

# High-level (for convenience)
proc drawButton*(layer: int, x, y, w, h: int, label: string, ...)
proc drawTextBox*(layer: int, x, y, w, h: int, ...)
```

---

## Conclusion

### The Perfect Architecture

**lib/tui_helpers.nim as the shared foundation is brilliant because:**

1. ✅ **Eliminates duplication** - One implementation for all
2. ✅ **Guarantees consistency** - Same visuals everywhere
3. ✅ **Simplifies testing** - Test once, both work
4. ✅ **Eases maintenance** - Fix once, both benefit
5. ✅ **Natural learning path** - Learn in scripts, use in native
6. ✅ **Migration friendly** - Upgrade incrementally
7. ✅ **Export optimized** - Compiles to same code

### Native Implementation Doesn't Differ

**Native widgets don't need different rendering logic** - they just add:
- **State management** (ref object with fields)
- **Lifecycle hooks** (onFocus, onChange callbacks)
- **Type safety** (Widget hierarchy with methods)

But the **visual rendering** is delegated to helpers, keeping them consistent.

### This Is Industry Standard

This is how mature UI libraries work:

- **Qt**: `QPainter` primitives used by all widgets
- **React**: `react-dom` rendering used by all components  
- **Dear ImGui**: `DrawList` API used by all widgets

**TStorie should follow this proven pattern.**

### Next Steps

1. **Implement helpers first** (Phase 1 from proposal)
2. **Update tui.md to use them** (verify simplification)
3. **If native widgets are ever needed**, they import helpers
4. **Both approaches share the same visual language**

**The helpers are valuable regardless of native widget implementation!**
