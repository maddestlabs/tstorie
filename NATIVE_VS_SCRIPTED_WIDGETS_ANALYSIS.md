# Why Native TUI Widgets Cause Segfaults (While Scripted Ones Work)

## Summary

**Scripted widgets** (like [docs/demos/tui.md](docs/demos/tui.md)) work flawlessly because they use **value semantics** - simple integers, floats, strings, and arrays managed entirely by Nimini's garbage collector.

**Native widgets** (like [lib/tui.nim](lib/tui.nim)) crash due to **reference type complexity** - `ref object` inheritance hierarchies, pointer sharing, and cross-boundary memory management that breaks Nim's type system guarantees.

---

## The Core Problem: Reference vs Value Semantics

### What Nimini Handles Well: Values

Nimini's value system (`nimini/runtime.nim`):
```nim
type
  ValueKind* = enum
    vkNil, vkInt, vkFloat, vkBool, vkString,
    vkFunction, vkMap, vkArray, vkPointer, vkRand

  Value* = ref object
    case kind*: ValueKind
    of vkInt: i*: int
    of vkFloat: f*: float
    of vkMap: map*: Table[string, Value]
    of vkArray: arr*: seq[Value]
    # ...
```

**Key insight:** Objects in Nimini are represented as `vkMap` - simple key-value tables. When you write:

```nim
type Point = object
  x: int
  y: int

let p = Point(x: 10, y: 20)
```

Nimini creates a `Value` with `kind = vkMap` and `map = {"x": valInt(10), "y": valInt(20)}`. This is:
- ✅ **Flat** - No pointer indirection
- ✅ **Copyable** - Assignment creates deep copies
- ✅ **GC-safe** - Managed by Nimini's ref-counting
- ✅ **Self-contained** - No external references

### What Nimini Struggles With: References

Native widgets use `ref object` hierarchies:

```nim
type
  Widget* = ref object of RootObj
    id*: string
    x*, y*: int
    styleSheet*: StyleSheet  # <- Reference to shared table
    onFocus*: proc(w: Widget)  # <- Closure with captures
    userData*: pointer  # <- Raw pointer

  Button* = ref object of Widget
    label*: string
    # Inherits all Widget fields
```

**The problems:**

1. **Shared References**: `styleSheet` points to a `Table[string, StyleConfig]` that multiple widgets access. When crossing the Nim↔Nimini boundary:
   - Nimini doesn't know about the shared reference semantics
   - Multiple `valPointer()` wrappers can point to same memory
   - No ref-counting synchronization
   - Mutation from one wrapper doesn't notify others
   - **Result: Use-after-free, double-free, corruption**

2. **Closures with Captures**: Event callbacks like `onFocus: proc(w: Widget)` capture their environment:
   ```nim
   wm.onFocus = proc(w: Widget) =
     updateTheme(w)  # Captures 'updateTheme' and possibly other variables
   ```
   - Closures contain hidden pointers to captured variables
   - Nimini sees only the function pointer, not the captures
   - **Result: Dangling pointers when environment is freed**

3. **Inheritance Type Safety**: When you pass `Button` (which is `ref object of Widget`) through Nimini:
   ```nim
   proc nimini_addWidget(env: ref Env; args: seq[Value]): Value =
     let widget = cast[Widget](args[0].ptrVal)  # Type information lost!
   ```
   - Cast from `pointer` back to `Widget` loses type tag
   - Runtime can't verify if pointer is actually a `Widget` vs `Button`
   - Virtual method dispatch breaks
   - **Result: Method calls on wrong vtable = segfault**

4. **Manual Memory Management**: From [lib/tui.nim#L196](lib/tui.nim#L196):
   ```nim
   # Don't set stylesheet - causes memory corruption with multiple widgets
   # widget.styleSheet = wm.styleSheet
   ```
   The code explicitly disables stylesheet sharing because of crashes. This is a **worked-around symptom**, not a fix.

---

## Evidence from the Codebase

### 1. TUI Module Explicitly Avoids Stylesheets

[lib/tui.nim#L136-137](lib/tui.nim#L136-L137):
```nim
# TEMPORARY: Skip stylesheet lookup to avoid memory corruption issues
# TODO: Fix styleSheet handling for multi-widget scenarios
```

The native implementation **knows** it can't safely share references.

### 2. Transitions Module Had Same Issues

[docs/md/TRANSITIONS_STATUS.md](docs/md/TRANSITIONS_STATUS.md):
```markdown
## Nimini Integration: ATTEMPTED BUT DEFERRED

### Technical Challenges
1. **Memory Management** - Objects created in Nimini need careful heap allocation
2. **Pointer Safety** - Raw pointer casting (`cast[BufferSnapshot]`) causes segfaults
3. **Type System Mismatch** - Nimini's value system doesn't map to Nim's types
```

Transitions API was fully implemented in native Nim but **couldn't be safely exposed to Nimini** due to identical issues.

### 3. Scripted TUI Works Because It Uses Values

[docs/demos/tui.md](docs/demos/tui.md) implements a complete TUI system with:
- 8 interactive widgets (TextBox, Button, Slider, Checkbox)
- Focus management
- Tab navigation
- Mouse interaction
- Event callbacks

**All state is value-based:**
```nim
# Widget types: just integers
var widgetTypes = @[0, 0, 2, 2, 3, 3, 1, 1]

# Positions: just integers in arrays
var widgetX = @[10, 10, 10, 10, 12, 12, 15, 32]
var widgetY = @[5, 9, 13, 17, 21, 22, 26, 26]

# Text: just strings in arrays
var tbTexts = @["", ""]

# Slider state: just floats
var sliderValues = @[50.0, 75.0]
```

No pointers, no references, no sharing - everything is a **value**. Nimini can copy, move, and garbage collect these trivially.

---

## Why the Architecture Matters

### Scripted Approach (Works)

```
┌─────────────────────────┐
│   Nimini Script         │
│   - All values          │
│   - Simple types        │
│   - No pointers         │
└───────────┬─────────────┘
            │
            │ draw(), fillRect(), getStyle()
            │ (Simple C-style functions)
            ▼
┌─────────────────────────┐
│   Native Rendering      │
│   - Direct buffer ops   │
│   - Stateless           │
│   - Safe FFI boundary   │
└─────────────────────────┘
```

**Benefits:**
- Clear separation of concerns
- Type-safe boundary (only primitives cross)
- No lifecycle management complexity
- GC handles everything

### Native Widget Approach (Crashes)

```
┌─────────────────────────┐
│   Nimini Script         │
│   - Holds pointers      │
│   - Calls methods       │
└───────────┬─────────────┘
            │
            │ cast[Widget](ptr)
            │ widget.render()
            │ (Complex object model crosses boundary)
            ▼
┌─────────────────────────┐
│   Native Widgets        │
│   - ref object tree     │
│   - Shared references   │
│   - Virtual methods     │
│   - Closures            │
└─────────────────────────┘
         │    ▲
         │    │ Shared StyleSheet reference
         │    │ (Multiple widgets point to same table)
         ▼    │
    ┌─────────────┐
    │ StyleSheet  │ ← Memory corruption happens here
    └─────────────┘
```

**Problems:**
- Complex object graph crosses boundary
- Type information lost in pointer casts
- Shared mutable state
- GC doesn't understand cross-boundary references

---

## Technical Deep Dive: Why `ref object` + Nimini = 💥

### Problem 1: Type Erasure on Boundary

**Native Nim code:**
```nim
type
  Widget = ref object of RootObj
    id: string
  Button = ref object of Widget
    label: string

let btn = Button(id: "btn1", label: "Click Me")
# Nim compiler knows:
# - btn is Button (subtype of Widget)
# - Virtual method dispatch works
# - Memory layout is known
```

**Passing to Nimini:**
```nim
proc nimini_newButton(...): Value =
  let btn = Button(...)
  return valPointer(cast[pointer](btn))
  # Type information LOST!
  # Now just a raw memory address
```

**In Nimini script:**
```nim
let btn = newButton(10, 10, 30, 3, "Click")
# btn is Value(kind: vkPointer, ptrVal: 0x7fff...)
# Nimini has NO IDEA this is a Button
```

**Calling method:**
```nim
proc nimini_renderWidget(env: ref Env; args: seq[Value]): Value =
  let widget = cast[Widget](args[0].ptrVal)
  # DANGER: What if ptrVal is actually a Button?
  # What if it's been freed?
  # What if it's not even a widget?
  widget.render(layer)  # Potential segfault
```

### Problem 2: Shared Mutable References

**The scenario:**
```nim
# Native code creates widget manager
let wm = newWidgetManager(styleSheet)
# wm.styleSheet = reference to table

# Add button1
let btn1 = newButton(...)
btn1.styleSheet = wm.styleSheet  # Shares reference
wm.addWidget(btn1)

# Add button2
let btn2 = newButton(...)
btn2.styleSheet = wm.styleSheet  # SAME reference
wm.addWidget(btn2)
```

**Memory layout:**
```
┌─────────┐
│   wm    │
└────┬────┘
     │
     ├──> styleSheet: Table[string, StyleConfig]
     │                ▲          ▲
     │                │          │
     │           ┌────┴────┐     │
     │           │  btn1   │     │
     │           └─────────┘     │
     │                            │
     │           ┌────────────────┘
     │           │  btn2   │
     │           └─────────┘
```

**What happens when one widget is freed:**
```
# Widget removed from manager
wm.removeWidget("btn1")
# btn1 goes out of scope
# Nim GC sees btn1 is dead
# BUT: btn1.styleSheet might be the only reference!
# GC frees the StyleSheet
# btn2.styleSheet now points to freed memory
# Next render: SEGFAULT
```

**Nimini makes this worse:**
- Each `valPointer()` creates new wrapper
- Nimini's GC doesn't know about reference counts
- No way to track "who owns this pointer"
- When Nimini value is GC'd, does it free the pointer?
  - If YES: double-free when Nim GC runs
  - If NO: memory leak

### Problem 3: Closure Lifetime

**Creating event handler:**
```nim
var globalState = initTable[string, int]()

proc setupButton(btn: Button) =
  btn.onClick = proc(w: Widget) =
    globalState["clicks"] = globalState["clicks"] + 1
    echo "Button clicked!"
    # ^ Closure captures: globalState, echo
```

**The closure is a hidden object:**
```
Closure = object
  fnPtr: pointer              # Code address
  envPtr: pointer             # Captures: {globalState, echo}
```

**Passed to Nimini:**
```nim
proc nimini_setOnClick(env: ref Env; args: seq[Value]): Value =
  let widget = cast[Widget](args[0].ptrVal)
  let callback = cast[proc(w: Widget)](args[1].ptrVal)
  widget.onClick = callback
  # Now widget holds closure
  # Nimini doesn't know about envPtr!
```

**When disaster strikes:**
```
1. setupButton() returns
2. globalState goes out of scope (in some contexts)
3. Nim GC frees globalState
4. Button's onClick still has pointer to freed envPtr
5. User clicks button
6. onClick() tries to access freed memory
7. SEGFAULT
```

---

## Why Scripted Widgets Don't Have These Problems

### No Shared References

**Scripted approach uses indices:**
```nim
# Instead of: widget.styleSheet = sharedTable
# We do:
var widgetX = @[10, 10, 10]  # Each widget has its own value
var widgetY = @[5, 9, 13]

# Access by index:
let x = widgetX[focusIndex]  # Copy of value
```

No sharing = no lifetime issues.

### No Type Casting

**Everything is a Value:**
```nim
# No casting needed
var widgetTypes = @[0, 0, 2]  # 0=TextBox, 2=Slider
if widgetTypes[i] == 0:
  renderTextBox(i)  # Pass index, not pointer
```

Type information never leaves the script environment.

### No Closures

**Callbacks are just event flags:**
```nim
# Instead of: btn.onClick = proc() = doSomething()
# We do:
var btnWasClicked = @[false, false]

# In input handler:
if btnPressed[0]:
  btnWasClicked[0] = true  # Set flag

# In render:
if btnWasClicked[0]:
  message = "Button 1 clicked!"  # React to flag
  btnWasClicked[0] = false
```

No function pointers = no capture issues.

### Self-Contained State

All widget state is in plain Nimini values:
```nim
var widgetX = @[10, 10, 10]
var widgetY = @[5, 9, 13]
var tbTexts = @["", ""]
var sliderValues = @[50.0, 75.0]
```

**Nimini's GC sees the whole graph:**
- Arrays are `vkArray` with `arr: seq[Value]`
- Strings are `vkString` with `s: string`
- Floats are `vkFloat` with `f: float`

Everything is **value-contained** - no external references to track.

---

## Lessons Learned

### 1. FFI Boundaries Should Be Thin

**Bad:** Expose complex object hierarchies across FFI
```nim
# FRAGILE
proc nimini_newWidget(): Value =
  return valPointer(cast[pointer](Widget(...)))
```

**Good:** Expose simple data-oriented interfaces
```nim
# ROBUST
proc nimini_drawBox(x, y, w, h: int; style: Style) =
  # Direct operation, no object lifecycle
```

### 2. Value Semantics Scale Better Than References

**Scripted TUI:**
- 400 lines of Nimini code
- 8 widget types
- Full interaction model
- **Zero crashes**

**Native TUI:**
- 1000+ lines of Nim code
- Type-safe within Nim
- **Unusable from Nimini** (segfaults)

### 3. Stateless Operations > Stateful Objects

The successful pattern in tstorie:
```nim
# These work great:
draw(layer, x, y, text, style)
fillRect(layer, x, y, w, h, char, style)
getStyle(name) -> Style

# These don't:
widget.render(layer)  # Object carries state across boundary
manager.addWidget(widget)  # Object lifetime management
```

---

## Recommendations

### ✅ DO: Keep Using Scripted Widgets

The [docs/demos/tui.md](docs/demos/tui.md) approach is **architecturally superior** for tstorie:
- Safer (value semantics)
- Simpler (no FFI complexity)
- More flexible (users can customize)
- Easier to debug (all state visible)

### ✅ DO: Add More Stateless Helper Functions

Expand the scripting API with:
```nim
proc drawButton(layer, x, y, w, h: int; label: string; focused: bool) =
  # Render button in one call, no state
  
proc measureText(text: string): int =
  # Pure function, no side effects
  
proc isPointInRect(px, py, rx, ry, rw, rh: int): bool =
  # Math helper, stateless
```

### ❌ DON'T: Try to "Fix" Native Widget FFI

The problems are **fundamental to mixing ref objects with FFI**, not bugs to fix:
- Type safety requires compile-time information
- Reference semantics require GC coordination  
- Closures require environment tracking

All three are **lost** when passing through `pointer`.

### 💡 ALTERNATIVE: Opaque Handles (If Native is Required)

If you absolutely need native widgets, use handle system:

```nim
# Handle-based approach (like OpenGL)
var widgetRegistry: Table[int, Widget]
var nextHandle = 1

proc nimini_createButton(...): Value =
  let btn = Button(...)
  let handle = nextHandle
  widgetRegistry[handle] = btn
  nextHandle += 1
  return valInt(handle)  # Return integer handle

proc nimini_renderWidget(env: ref Env; args: seq[Value]): Value =
  let handle = toInt(args[0])
  if handle in widgetRegistry:
    widgetRegistry[handle].render(layer)
```

**Advantages:**
- Registry owns all widgets (clear lifetime)
- No pointers across boundary
- Handle validity can be checked
- Type information stays in registry

**Still complex but safer than raw pointers.**

---

## Conclusion

The scripted approach works because it **respects Nimini's value-based architecture**. Native widgets crash because they **violate FFI safety principles**:

1. Complex types don't cross boundaries safely
2. Shared references need coordinated GC
3. Type information is lost in pointer casts
4. Closure lifetimes are invisible to Nimini

**The scripted TUI isn't a workaround - it's the right architecture.**

Rather than fight the type system, embrace **data-oriented design**:
- Store state as primitive values
- Use indices instead of pointers
- Provide stateless rendering functions
- Let Nimini manage its own memory

This is why procedural graphics APIs (OpenGL, DirectX) use handles and IDs, not object references. The same principles apply here.
