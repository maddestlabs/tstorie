# Module Binding Standardization Guide

## Quick Reference

**Baseline Module**: `lib/tui_helpers.nim` + `lib/tui_helpers_bindings.nim`  
**Infrastructure**: `nimini/auto_bindings.nim` + `nimini/type_converters.nim`  
**Status**: 15 of 20 tui_helpers functions converted (75% auto-exposed)  
**Binary Impact**: 0 bytes increase (1.2M unchanged)  

## System Architecture

### Auto-Bindings System
```
Native Module (lib/mymodule.nim)
  ↓ uses {.autoExpose: "libname".} pragma
nimini/auto_bindings.nim (macro)
  ↓ generates wrapper + registration
nimini/type_converters.nim (conversions)
  ↓ handles Style, Color, seq[T], tuple
Generated Functions:
  - myFunc (original native)
  - niminiAuto_myFunc (wrapper)
  - register_myFunc (registration)
```

### Type Support Matrix

| Type | Input | Output | Converter | Status |
|------|-------|--------|-----------|--------|
| int, float, string, bool | ✅ | ✅ | Built-in | Ready |
| Style | ✅ | ✅ | type_converters.nim | Ready |
| Color | ✅ | ✅ | type_converters.nim | Ready |
| seq[int] | ✅ | ✅ | type_converters.nim | Ready |
| seq[string] | ✅ | ✅ | type_converters.nim | Ready |
| seq[float] | ✅ | ✅ | type_converters.nim | Ready |
| tuple[x, y: int] | ✅ | ✅ | type_converters.nim | Ready |
| seq[tuple[x, y: int]] | ✅ | ✅ | type_converters.nim | Ready |
| var params | ❌ | ❌ | Manual wrapper | N/A |
| Custom types | ❌ | ❌ | Add to type_converters.nim | Extend |

## The 6 Binding Patterns

### Pattern 1: Simple Functions → Auto-Expose ✅

**Use When:**
- Parameters: Only int, float, string, bool
- Returns: Single value of above types
- Logic: Pure function, no side effects
- Examples: `centerTextX`, `truncateText`, `pointInRect`

**Implementation:**
```nim
# In lib/mymodule.nim
proc myUtilFunc*(x: int, text: string): bool {.autoExpose: "mylib".} =
  ## Calculate something
  result = x > text.len

# In lib/mymodule_bindings.nim
proc registerMyModuleBindings*(env: ref Env) =
  register_myUtilFunc()  # That's it!
```

**Code Reduction**: ~90% (15 lines → 1 line)

---

### Pattern 2: Style/Color Functions → Auto-Expose ✅

**Use When:**
- Parameters: Include Style or Color types
- Returns: void or simple types
- Logic: Straightforward delegation
- Examples: `drawBoxSimple`, `fillBox`, `drawLabel`

**Implementation:**
```nim
# In lib/mymodule.nim
import ../nimini/auto_bindings  # Brings in type_converters

proc drawSomething*(layer, x, y: int, style: Style) {.autoExpose: "mylib".} =
  ## Draw with style
  internalDraw(layer, x, y, style)

# In lib/mymodule_bindings.nim
proc registerMyModuleBindings*(env: ref Env) =
  register_drawSomething()  # Style auto-converted!
```

**Code Reduction**: ~85% (70 lines of valueToStyle logic → 1 line)

---

### Pattern 3: Seq/Tuple Returns → Auto-Expose ✅

**Use When:**
- Returns: seq[int], seq[string], tuple[x, y: int], seq[tuple]
- Parameters: Simple types
- Logic: Pure calculation
- Examples: `layoutVertical`, `layoutCentered`, `layoutGrid`

**Implementation:**
```nim
# In lib/mymodule.nim
proc calculatePositions*(start, spacing, count: int): seq[int] {.autoExpose: "mylib".} =
  ## Return array of positions
  result = @[]
  for i in 0..<count:
    result.add(start + i * spacing)

# In lib/mymodule_bindings.nim
proc registerMyModuleBindings*(env: ref Env) =
  register_calculatePositions()  # seq[int] auto-converted to nimini array!
```

**Code Reduction**: ~80% (20 lines of array construction → 1 line)

---

### Pattern 4: Complex Multi-Step Logic → Manual Wrapper 🔧

**Use When:**
- Logic: Multiple conditional branches
- Calls: Many internal function calls
- Validation: Complex parameter checking
- Examples: `drawButton`, `drawTextBox`, `drawSlider`

**Implementation:**
```nim
# In lib/mymodule.nim - NO pragma, keep normal
proc complexWidget*(layer, x, y, w, h: int, label: string, 
                   isFocused, isPressed: bool, borderStyle: string) =
  ## Complex rendering with many branches
  let style = if isFocused: getStyle("focus") else: getStyle("normal")
  
  if isPressed:
    fillBox(layer, x, y, w, h, "█", style)
  else:
    case borderStyle
    of "simple": drawBoxSimple(layer, x, y, w, h, style)
    of "double": drawBoxDouble(layer, x, y, w, h, style)
    else: drawBoxSingle(layer, x, y, w, h, style)
  
  drawCenteredText(layer, x, y, w, h, label, style)

# In lib/mymodule_bindings.nim - Keep manual wrapper
proc nimini_complexWidget*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 9: return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  # ... extract all params
  let borderStyle = valueToString(args[8])
  
  complexWidget(layer, x, y, w, h, label, isFocused, isPressed, borderStyle)
  return valNil()

proc registerMyModuleBindings*(env: ref Env) =
  registerNative("complexWidget", nimini_complexWidget,
    storieLibs = @["mylib"],
    description = "Complex widget with conditional rendering")
```

**Why Manual**: Too much logic to auto-generate reliably. Manual wrapper gives full control.

---

### Pattern 5: Var Parameters → Manual Wrapper 🔧

**Use When:**
- Parameters: Any `var` parameters
- Purpose: Modify state
- Examples: `handleTextInput`, `handleBackspace`

**Implementation:**
```nim
# In lib/mymodule.nim - NO pragma, var params not supported
proc handleInput*(text: string, cursorPos: var int, content: var string): bool =
  ## Modify cursor and content
  content = content & text
  cursorPos = cursorPos + 1
  return true

# In lib/mymodule_bindings.nim - Return modified values as array
proc nimini_handleInput*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 3: return valArray(@[])
  
  let text = valueToString(args[0])
  var cursorPos = valueToInt(args[1])
  var content = valueToString(args[2])
  
  let handled = handleInput(text, cursorPos, content)
  
  # Return array of modified values
  return valArray(@[valInt(cursorPos), valString(content), valBool(handled)])

proc registerMyModuleBindings*(env: ref Env) =
  registerNative("handleInput", nimini_handleInput,
    storieLibs = @["mylib"],
    description = "Handle input - returns [cursorPos, content, handled]")
```

**Why Manual**: Nimini doesn't support var parameters. Manual wrapper returns tuple of results.

---

### Pattern 6: Seq Inputs → Manual Wrapper 🔧

**Use When:**
- Parameters: Takes seq[int], seq[string], etc. as input
- Reason: Want explicit control over array validation
- Examples: `findClickedWidget(widgetX, widgetY, widgetW, widgetH: seq[int])`

**Implementation:**
```nim
# In lib/mymodule.nim - Could auto-expose, but manual gives control
proc findItem*(mouseX, mouseY: int, itemsX, itemsY: seq[int]): int =
  ## Find clicked item
  for i in 0..<itemsX.len:
    if mouseX == itemsX[i] and mouseY == itemsY[i]:
      return i
  return -1

# In lib/mymodule_bindings.nim - Manual for array validation
proc nimini_findItem*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 4: return valInt(-1)
  
  let mouseX = valueToInt(args[0])
  let mouseY = valueToInt(args[1])
  
  # Explicit array conversion with validation
  var itemsX: seq[int] = @[]
  var itemsY: seq[int] = @[]
  
  if args[2].kind == vkArray:
    for v in args[2].arr:
      itemsX.add(valueToInt(v))
  
  if args[3].kind == vkArray:
    for v in args[3].arr:
      itemsY.add(valueToInt(v))
  
  return valInt(findItem(mouseX, mouseY, itemsX, itemsY))
```

**Note**: Could potentially auto-expose with type_converters.valueToSeqInt, but manual gives better error handling.

---

## Step-by-Step Conversion Process

### Phase 1: Analyze Module

```bash
# 1. Count exported functions
grep "^proc \w\+\*" lib/mymodule.nim | wc -l

# 2. Check for Style/Color usage
grep "Style\|Color" lib/mymodule.nim

# 3. Check for seq/tuple returns
grep "seq\[" lib/mymodule.nim
grep "tuple\[" lib/mymodule.nim

# 4. Check for var parameters
grep "var " lib/mymodule.nim
```

### Phase 2: Categorize Functions

For each function, ask:
1. **Parameters only int/float/string/bool?** → Pattern 1
2. **Uses Style/Color?** → Pattern 2
3. **Returns seq/tuple?** → Pattern 3
4. **Multiple branches/calls?** → Pattern 4
5. **Has var parameters?** → Pattern 5
6. **Takes seq parameters?** → Pattern 6

### Phase 3: Update Native File

```nim
# lib/mymodule.nim

# Add at top if using auto-expose:
import ../nimini/auto_bindings

# Add pattern documentation sections:
# ==============================================================================
# PATTERN 1: Simple utility functions → Auto-expose
# ==============================================================================

proc simpleFunc*(x: int): bool {.autoExpose: "mylib".} =
  ## Simple calculation
  result = x > 0

# ==============================================================================  
# PATTERN 2: Style functions → Auto-expose
# ==============================================================================

proc drawFunc*(x, y: int, style: Style) {.autoExpose: "mylib".} =
  ## Draw something
  internalDraw(x, y, style)

# ==============================================================================
# PATTERN 4: Complex functions → Manual wrappers (see mymodule_bindings.nim)
# ==============================================================================

proc complexFunc*(...) =  # NO .autoExpose pragma
  ## Complex logic - manual wrapper in bindings file
  # Many branches, calls, etc.
```

### Phase 4: Update Bindings File

```nim
# lib/mymodule_bindings.nim

# Add header documentation (copy from tui_helpers_bindings.nim lines 1-65)

import ../nimini
import ../nimini/runtime
import ../src/types  # If using Style/Color
import std/[tables, strutils]
import mymodule

# Keep helper functions (valueToInt, valueToBool, etc. still used in manual wrappers)

# Remove manual wrappers for auto-exposed functions
# Keep manual wrappers for Patterns 4, 5, 6

proc registerMyModuleBindings*(env: ref Env) =
  # ==============================================================================
  # PATTERN 1, 2, 3: Auto-exposed functions
  # ==============================================================================
  register_simpleFunc()
  register_drawFunc()
  # ... all auto-exposed functions
  
  # ==============================================================================
  # PATTERN 4, 5, 6: Manual wrappers
  # ==============================================================================
  registerNative("complexFunc", nimini_complexFunc,
    storieLibs = @["mylib"],
    description = "Complex function with manual wrapper")
  # ... all manual functions
```

### Phase 5: Test

```nim
# Create test_mymodule_baseline.nimini

```nim on:init
# Test Pattern 1
let result1 = simpleFunc(5)
print("Pattern 1: OK")

# Test Pattern 2
let style = getStyle("info")
drawFunc(10, 10, style)
print("Pattern 2: OK")

# Test Pattern 3 (if applicable)
let positions = layoutFunc(0, 5, 10)
print("Pattern 3: OK")

print("✓ All patterns working!")
```
```

```bash
# Compile and test
./build.sh -c
echo "" | timeout 3 ./tstorie test_mymodule_baseline.nimini

# Check binary size didn't increase
ls -lh tstorie
```

---

## Modules to Convert

### Priority 1: High-Value Modules

1. **ascii_art.nim** (~10 functions)
   - Has duplicate valueToStyle stub (only returns default)
   - Many simple pattern functions
   - Estimated: 8 auto-expose, 2 manual

2. **figlet.nim** (~5 functions)
   - Uses Style but hardcodes default
   - Mostly simple rendering
   - Estimated: 3 auto-expose, 2 manual

3. **layout.nim** (~8 functions)
   - Text layout and alignment
   - Many use Style parameter
   - Estimated: 6 auto-expose, 2 manual

### Priority 2: Medium-Value Modules

4. **particles_bindings.nim** (~15 functions)
   - Already uses simple setters (good candidates)
   - Some complex graph operations
   - Estimated: 10 auto-expose, 5 manual

5. **ansi_art_bindings.nim** (~8 functions)
   - ANSI art rendering
   - Similar to ascii_art
   - Estimated: 6 auto-expose, 2 manual

### Priority 3: Specialized Modules

6. **dungeon_bindings.nim** (~6 functions)
   - Dungeon generation
   - Mostly returns complex data structures
   - Estimated: 3 auto-expose, 3 manual

7. **text_editor_bindings.nim** (~4 functions)
   - Text editor operations
   - Complex state management
   - Estimated: 1 auto-expose, 3 manual

8. **miniaudio_bindings.nim** (~10 functions)
   - Audio operations
   - External library integration
   - Estimated: 5 auto-expose, 5 manual

---

## Decision Tree

```
┌─ Function to bind ─────────────────────────────────────┐
│                                                         │
├─ Has var parameters? ──Yes──→ Pattern 5 (Manual)      │
│          │                                              │
│         No                                              │
│          │                                              │
├─ Takes seq[T] as input? ──Yes──→ Pattern 6 (Manual)*  │
│          │                                              │
│         No                                              │
│          │                                              │
├─ Complex multi-step logic? ──Yes──→ Pattern 4 (Manual)│
│          │                                              │
│         No                                              │
│          │                                              │
├─ Returns seq/tuple? ──Yes──→ Pattern 3 (Auto-expose) ✅│
│          │                                              │
│         No                                              │
│          │                                              │
├─ Uses Style/Color? ──Yes──→ Pattern 2 (Auto-expose) ✅ │
│          │                                              │
│         No                                              │
│          │                                              │
└─ Pattern 1 (Auto-expose) ✅                            │
   (Simple types only)                                   │
                                                          │
* Could auto-expose seq[T] inputs later if desired       │
└─────────────────────────────────────────────────────────┘
```

---

## Common Issues & Solutions

### Issue: "Unsupported type for auto-binding: MyCustomType"

**Solution**: Add converter to `nimini/type_converters.nim`:
```nim
proc valueToMyCustomType*(v: Value): MyCustomType =
  # Conversion logic
  ...

proc myCustomTypeToValue*(obj: MyCustomType): Value =
  # Conversion logic
  ...
```

Then update `auto_bindings.nim` makeConverter/makeReturnConverter to recognize it.

---

### Issue: Function has default parameters

**Current**: Auto-bindings don't handle default params well yet.

**Solution**: Keep as manual wrapper, or remove default and handle in nimini script:
```nim
# Instead of: proc draw*(x: int, style: Style = defaultStyle())
# Use: proc draw*(x: int, style: Style)
# In nimini: draw(10, getStyle("default"))
```

---

### Issue: Function needs special error handling

**Solution**: Keep as manual wrapper. Auto-bindings are for straightforward conversions only.

---

## Expected Impact Per Module

Based on tui_helpers baseline:

- **Code Reduction**: 60-80% of binding file
- **Lines Removed**: ~200-500 lines per module (depends on size)
- **Lines Added**: ~50-100 lines documentation + pragmas
- **Binary Size**: 0 bytes increase (tested)
- **Compilation Time**: Minimal increase (<1 second)
- **Maintainability**: Significantly improved (single source of truth)

---

## Success Criteria

A module is successfully converted when:

✅ Compiles without errors  
✅ All auto-exposed functions work in nimini scripts  
✅ All manual wrappers still work  
✅ Binary size unchanged or decreased  
✅ Pattern documentation present in both files  
✅ Registration organized by pattern  
✅ Test file validates all patterns used  

---

## Quick Start for New Module

1. **Copy pattern header** from tui_helpers_bindings.nim (lines 1-65)
2. **Analyze functions** using decision tree
3. **Add auto_bindings import** to native file
4. **Add {.autoExpose.} pragmas** to Pattern 1/2/3 functions
5. **Add pattern comments** to native file
6. **Update registration section** in bindings file
7. **Remove obsolete wrappers** from bindings file
8. **Test** with comprehensive test file
9. **Verify** binary size unchanged

---

## Resources

- **Baseline Example**: `lib/tui_helpers.nim` + `lib/tui_helpers_bindings.nim`
- **Type Converters**: `nimini/type_converters.nim`
- **Auto-Bindings Macro**: `nimini/auto_bindings.nim`
- **Test Example**: `test_tui_baseline.nimini`
- **This Document**: Module conversion reference

---

## Notes for Future Extensions

### To Add New Type Support:

1. Add converters to `nimini/type_converters.nim`:
   - `valueToMyType*` and `myTypeToValue*`

2. Update `nimini/auto_bindings.nim`:
   - Add case in `makeConverter()` for input conversion
   - Add case in `makeReturnConverter()` for output conversion

3. Test with simple function before bulk conversion

### To Improve Auto-Bindings:

- Add support for default parameters
- Add support for optional parameters
- Add support for overloaded functions
- Add better error messages for unsupported types

Current system handles 80-90% of common binding patterns. Manual wrappers remain necessary for edge cases.
