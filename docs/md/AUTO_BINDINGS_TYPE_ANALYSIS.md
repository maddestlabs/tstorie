# Auto-Bindings Type Analysis for tui_helpers

## Current Status

**Converted (4 functions)**: Using `{.autoExpose: "tui".}` pragma
- centerTextX(text: string, boxX, boxWidth: int): int ✅
- centerTextY(boxY, boxHeight: int): int ✅
- truncateText(text: string, maxWidth: int): string ✅
- pointInRect(px, py, rx, ry, rw, rh: int): bool ✅

**Remaining (16+ functions)**: Need complex type support

## Type Requirements

### 1. Style Type (Most Common)

**Usage Count**: ~12 functions take `Style` parameter

**Current Manual Conversion**:
```nim
proc valueToStyle(v: Value): Style =
  if v.kind == vkMap:
    var style = Style()
    # Parse fg color from hex string or RGB map
    if v.map.hasKey("fg"):
      let fgVal = v.map["fg"]
      if fgVal.kind == vkString:
        # Parse "#RRGGBB"
        style.fg = parseHexColor(fgVal.s)
      elif fgVal.kind == vkMap:
        # Parse {r, g, b}
        style.fg = Color(
          r: uint8(fgVal.map["r"].i),
          g: uint8(fgVal.map["g"].i),
          b: uint8(fgVal.map["b"].i)
        )
    # Same for bg
    # Parse bold, italic, underline, dim flags
    return style
  return defaultStyle()
```

**Functions Needing Style**:
1. drawBox(layer, x, y, w, h: int, style: Style, ...) - 11 string params too
2. drawBoxSimple(layer, x, y, w, h: int, style: Style)
3. drawBoxSingle(layer, x, y, w, h: int, style: Style)
4. drawBoxDouble(layer, x, y, w, h: int, style: Style)
5. drawBoxRounded(layer, x, y, w, h: int, style: Style)
6. fillBox(layer, x, y, w, h: int, ch: string, style: Style)
7. drawCenteredText(layer, x, y, w, h: int, text: string, style: Style)
8. drawLabel(layer, x, y: int, text: string, style: Style)
9. drawSeparator(layer, x, y, w: int, style: Style, ch: string = "─")
10. drawRadioButton(layer, x, y: int, label: string, isSelected, isFocused: bool, style: Style)

### 2. seq[int] Type (Layout Functions)

**Usage Count**: 4 functions (1 input, 3 output)

**Input Conversion** (seq[int] parameter):
```nim
# findClickedWidget takes 4 seq[int] params
var widgetX: seq[int] = @[]
if args[2].kind == vkArray:
  for v in args[2].arr:
    widgetX.add(valueToInt(v))
```

**Output Conversion** (returns seq[int]):
```nim
# layoutVertical returns seq[int]
let positions = layoutVertical(startY, spacing, count)
var result: seq[Value] = @[]
for pos in positions:
  result.add(valInt(pos))
return valArray(result)
```

**Functions Using seq[int]**:
1. findClickedWidget(mouseX, mouseY: int, widgetX, widgetY, widgetW, widgetH: seq[int]): int
2. layoutVertical(startY, spacing, count: int): seq[int]
3. layoutHorizontal(startX, spacing, count: int): seq[int]

### 3. Tuple Return Types (Layout Functions)

**Usage Count**: 2 functions

**Current Manual Conversion**:
```nim
# layoutCentered returns tuple[x, y: int]
let pos = layoutCentered(containerX, containerY, containerW, containerH, itemW, itemH)
var result = initTable[string, Value]()
result["x"] = valInt(pos.x)
result["y"] = valInt(pos.y)
return valMap(result)
```

```nim
# layoutGrid returns seq[tuple[x, y: int]]
let positions = layoutGrid(startX, startY, cols, rows, 
                          cellWidth, cellHeight, spacingX, spacingY)
var result: seq[Value] = @[]
for pos in positions:
  var posMap = initTable[string, Value]()
  posMap["x"] = valInt(pos.x)
  posMap["y"] = valInt(pos.y)
  result.add(valMap(posMap))
return valArray(result)
```

**Functions Using Tuples**:
1. layoutCentered(...): tuple[x, y: int]
2. layoutGrid(...): seq[tuple[x, y: int]]

### 4. Complex Widget Functions (Not Auto-Bindable)

**Count**: ~6 functions with complex parameter combinations

These have too many parameters or complex internal state to be good auto-binding candidates:

1. **drawButton**(layer, x, y, w, h: int, label: string, isFocused, isPressed: bool, borderStyle: string)
   - 9 parameters, needs switch statement, calls multiple internal functions
   
2. **drawTextBox**(layer, x, y, w, h: int, content: string, cursorPos: int, isFocused: bool, borderStyle: string)
   - 9 parameters, complex internal logic for cursor handling
   
3. **drawSlider**(layer, x, y, w: int, value, minVal, maxVal: float, isFocused: bool)
   - 8 parameters, needs float normalization
   
4. **drawCheckBox**(layer, x, y: int, label: string, isChecked, isFocused: bool)
   - Simple but needs multiple tuiDraw calls with conditional logic
   
5. **drawPanel**(layer, x, y, w, h: int, title: string, borderStyle: string)
   - Needs fillBox + drawBox + title placement logic
   
6. **drawProgressBar**(layer, x, y, w: int, progress: float, showPercent: bool)
   - Complex rendering with optional percentage display

### 5. Input Handler Functions (var params)

**Count**: 3 functions

These use `var` parameters which modify state - not suitable for simple auto-binding:

1. handleTextInput(text: string, cursorPos: var int, content: var string): bool
2. handleBackspace(cursorPos: var int, content: var string): bool
3. handleArrowKeys(keyCode: int, value: var float, minVal, maxVal, step: float): bool

## Proposed Solutions

### Option A: Extend Auto-Bindings with Type Converters

Add converter procs to auto_bindings.nim for each complex type:

```nim
# In auto_bindings.nim
proc niminiConvertToStyle(v: Value): Style =
  if v.kind == vkMap:
    # Full Style parsing logic
    ...
  return defaultStyle()

proc niminiConvertToSeqInt(v: Value): seq[int] =
  result = @[]
  if v.kind == vkArray:
    for item in v.arr:
      result.add(niminiConvertToInt(item))

proc niminiConvertFromSeqInt(s: seq[int]): Value =
  var arr: seq[Value] = @[]
  for item in s:
    arr.add(valInt(item))
  return valArray(arr)

proc niminiConvertFromTuple2Int(t: tuple[x, y: int]): Value =
  var m = initTable[string, Value]()
  m["x"] = valInt(t.x)
  m["y"] = valInt(t.y)
  return valMap(m)
```

Then update the macro to recognize these types:

```nim
proc makeConverter(argName: NimNode, typeName: string, valueExpr: NimNode): NimNode =
  case typeName
  of "Style":
    return quote do:
      niminiConvertToStyle(`valueExpr`)
  of "seq[int]":
    return quote do:
      niminiConvertToSeqInt(`valueExpr`)
  # ... etc
```

**Pros**:
- Enables auto-expose for many more functions (~10 additional)
- Centralizes conversion logic
- Still maintains type safety

**Cons**:
- Style converter needs access to Color type and parsing logic
- Increases auto_bindings.nim dependencies
- May need to handle seq[string], seq[float], etc. separately

### Option B: Hybrid Approach with Custom Converters

Allow modules to register custom converters:

```nim
# In tui_helpers.nim
import ../nimini/auto_bindings

# Register custom converter before using it
registerConverter("Style", niminiConvertToStyle, niminiConvertFromStyle)

proc drawLabel*(layer, x, y: int, text: string, style: Style) {.autoExpose: "tui".} =
  tuiDraw(layer, x, y, text, style)
```

The auto_bindings macro would check registered converters:

```nim
var customConverters = initTable[string, tuple[toNative, fromNative: NimNode]]()

proc registerConverter*(typeName: string, toProc, fromProc: NimNode) =
  customConverters[typeName] = (toProc, fromProc)

proc makeConverter(...):
  if customConverters.hasKey(typeName):
    let converter = customConverters[typeName].toNative
    return quote do:
      `converter`(`valueExpr`)
```

**Pros**:
- Keeps auto_bindings.nim generic
- Each module can define its own converters
- Flexible for custom types

**Cons**:
- More complex to implement
- Need to handle registration timing carefully
- Converter functions must be visible at macro expansion time

### Option C: Template-Based Per-Type Wrappers

Instead of full automation, provide templates for common patterns:

```nim
# In nimini_helpers.nim
template registerStyleFunction*(name: string, procName: untyped) =
  proc `niminiAuto name`*(env: ref Env; args: seq[Value]): Value {.nimini.} =
    # Auto-generated wrapper that knows about Style
    ...

# In tui_helpers_bindings.nim
registerStyleFunction("drawLabel", drawLabel)
```

**Pros**:
- More control over generated code
- Can optimize per type
- Easier to debug

**Cons**:
- Still requires binding file
- Less automatic than macro approach
- More boilerplate for each type

## Recommended Approach

**Phase 1**: Extend auto_bindings with built-in converters for common types
- Add Style converter (needs import ../src/types)
- Add seq[int], seq[string] converters
- Add tuple[x, y: int] converter

**Phase 2**: Convert simple single-Style-param functions (~10 functions)
- drawBoxSimple, drawBoxSingle, drawBoxDouble, drawBoxRounded
- fillBox
- drawCenteredText
- drawLabel
- drawSeparator

**Phase 3**: Handle layout functions with seq/tuple returns
- layoutVertical, layoutHorizontal → seq[int] return
- layoutCentered → tuple return
- layoutGrid → seq[tuple] return

**Phase 4**: Keep complex multi-logic functions as manual wrappers
- drawButton, drawTextBox, drawSlider, etc.
- These benefit from manual optimization
- ~6 functions stay manual

## Impact Estimate

**Current**:
- 4 functions auto-exposed (20% of simple functions)
- ~50 lines removed

**After Phase 1-3**:
- 17 functions auto-exposed (85% of bindable functions)
- ~400-500 lines removed from bindings file
- 6 complex functions remain manual (~200 lines)
- Net reduction: ~70% of binding code

**Binary Size Impact**: Should remain neutral or slightly smaller (less wrapper code)

## Implementation Priority

1. **High Priority**: Style converter
   - Unlocks 10 functions immediately
   - Most commonly needed type
   
2. **Medium Priority**: seq[int] converters
   - Unlocks 3 layout functions
   - Common pattern in other modules too
   
3. **Low Priority**: Tuple converters
   - Only 2 functions
   - Could stay manual without much cost

4. **Skip**: var params, complex multi-step functions
   - Better as manual wrappers
   - Difficult to generalize

## Code Organization

After implementation, the structure would be:

```
lib/tui_helpers.nim
  - All native functions
  - ~17 with {.autoExpose: "tui".} pragma
  - No binding code

lib/tui_helpers_bindings.nim
  - Import auto_bindings (brings in converters)
  - ~6 complex manual wrappers
  - Registration function calls auto-generated register_* functions
  - Total: ~200 lines (down from ~900)

nimini/auto_bindings.nim
  - Generic int/float/string/bool converters ✅
  - Style converter (needs types import)
  - seq[T] converters
  - tuple converters
  - Total: ~300 lines
```

## Dependencies Needed

For Style support, auto_bindings.nim needs:
```nim
import ../src/types  # For Style, Color
import std/strutils  # For hex parsing

proc niminiConvertToStyle(v: Value): Style =
  # Full implementation from valueToStyle in tui_helpers_bindings.nim
```

This creates a dependency from nimini/ → src/, which may not be desired architecturally.

**Alternative**: Keep Style converter in tui_helpers_bindings.nim, but allow auto_bindings to call module-provided converters:

```nim
# In auto_bindings.nim - generic, no type imports
proc makeConverter(...):
  case typeName
  of "Style":
    return quote do:
      valueToStyle(`valueExpr`)  # Expect this to exist in calling module
```

Then modules provide their own `valueToStyle` proc before using auto-expose on Style params.
