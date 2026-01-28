# tStorie Exporter Issues

This document tracks issues found with the `./tstorie export` command when exporting markdown demos to standalone Nim files.

## Test Case: Minesweeper Demo

**Source:** `docs/demos/minesweeper.md`  
**Export Command:** `./tstorie export docs/demos/minesweeper.nim`  
**Generated File:** `minesweeper.nim`

---

## Issue 1: Global Variables Placed Inside main() Block

### Description
Variables declared in the markdown front matter or global scope are incorrectly placed as local variables inside the `main()` function within the `when not defined(emscripten)` block, instead of being declared at module level in the "User global variables" section.

### Impact
- **Compilation Error:** `undeclared identifier: 'grid'`
- Functions defined at module level (like `initGrid()`, `getCell()`, `setCell()`, etc.) cannot access these variables
- Variables that need to be shared across multiple functions end up scoped locally

### Expected Behavior
Global variables should be declared in the "User global variables" section at module level (around line 113), making them accessible to all functions.

### Actual Behavior
Variables were declared inside `main()` around line 329:
```nim
proc main() =
  # ... setup code ...
  
  var grid = []  # ❌ WRONG: Local variable
  var firstClick = true  # ❌ WRONG: Local variable
  var cellsRevealed = 0  # ❌ WRONG: Local variable
  # etc.
```

### Correct Output Should Be
```nim
# User global variables
var grid: seq[seq[int]]
var firstClick: bool
var cellsRevealed: int
var styleHidden: Style
var styleRevealed: Style
var styleMine: Style
var styleFlag: Style
var styleNumber: Style
var chars: string = ""
# ... other user globals ...

# User-defined functions
proc initGrid() =
  grid = @[]  # ✓ Can access global variable
  # ...
```

### Variables Affected
- `grid`
- `firstClick`
- `cellsRevealed`
- `styleHidden`
- `styleRevealed`
- `styleMine`
- `styleFlag`
- `styleNumber`
- `chars` (referenced but never declared)

---

## Issue 2: Array Literal Syntax Instead of Seq Syntax

### Description
The exporter generates array literal syntax `[]` and `[item]` instead of seq literal syntax `@[]` and `@[item]`.

### Impact
- **Compilation Error:** Type mismatch between arrays and seqs
- Cannot assign array literals to seq-typed variables
- Cannot concatenate arrays with seqs

### Examples

#### Empty Collection
```nim
# ❌ WRONG: Array literal
grid = []

# ✓ CORRECT: Seq literal
grid = @[]
```

#### Collection with Items
```nim
# ❌ WRONG: Array literal
grid = grid + [[0, 0, 0, 0]]

# ✓ CORRECT: Seq with add method
grid.add(@[0, 0, 0, 0])
```

#### Return Value
```nim
# ❌ WRONG: Returns array
return [0, 0, 0, 0]

# ✓ CORRECT: Returns seq
return @[0, 0, 0, 0]
```

#### Assignment
```nim
# ❌ WRONG: Array literal
grid[idx] = [revealed, isMine, flagged, adjacent]

# ✓ CORRECT: Seq literal
grid[idx] = @[revealed, isMine, flagged, adjacent]
```

### Root Cause
The exporter's code generation likely doesn't distinguish between Nim arrays (fixed-size, stack-allocated) and seqs (dynamic, heap-allocated). For the runtime API compatibility, seqs should be used.

---

## Issue 3: Function Scope Issues

### Description
The `getCell()` helper function was generated inside the `main()` function instead of at module level with other user-defined functions.

### Impact
- **Compilation Error:** Type mismatch - conflicts with existing `getCell` methods from imported modules
- Functions defined at module level cannot call functions defined inside `main()`

### Incorrect Output
```nim
proc placeMines(avoidX: int, avoidY: int) =
  # ...
  var cell = getCell(rx, ry)  # ❌ Calls wrong getCell
  # ...

proc main() =
  # ...
  proc getCell(x: int, y: int): seq[int] =  # ❌ WRONG: Defined inside main
    # ...
```

### Correct Output
```nim
proc getCell(x: int, y: int): seq[int] =  # ✓ At module level
  var idx = getCellIdx(x, y)
  if idx >= 0 and idx < len(grid):
    return grid[idx]
  return @[0, 0, 0, 0]

proc placeMines(avoidX: int, avoidY: int) =
  # ...
  var cell = getCell(rx, ry)  # ✓ Can call module-level function
  # ...
```

---

## Issue 4: Missing Type Conversions

### Description
Division operator `/` used for integer division instead of `div`, causing float results when integers are expected.

### Impact
- **Compilation Error:** Type mismatch between float and int

### Example
```nim
# ❌ WRONG: Float division
var gridX = (mouseX - offsetX) / charWidth  # Results in float

# ✓ CORRECT: Integer division
var gridX = (mouseX - offsetX) div charWidth  # Results in int
```

---

## Issue 5: Unused Return Values

### Description
Functions returning bool values are called without using or discarding the return value.

### Impact
- **Compilation Error:** Expression of type 'bool' must be used or discarded

### Examples
```nim
# ❌ WRONG: Return value not handled
revealCell(x + dx, y + dy)

# ✓ CORRECT: Return value discarded
discard revealCell(x + dx, y + dy)
```

### Affected Functions
- `revealCell()`
- `checkWin()`
- `toggleFlag()`

---

## Issue 6: Key Code Constants

### Description
Undefined key code constants like `KEY_R` used directly instead of using character codes or proper imports.

### Impact
- **Compilation Error:** Undeclared identifier 'KEY_R'

### Example
```nim
# ❌ WRONG: Undefined constant
if code == KEY_R:

# ✓ CORRECT: Use character codes or convert KeyCode to int
if code == ord('r') or code == ord('R'):
if code == KEY_ESCAPE.int:
```

---

## Issue 7: Incorrect Return Statement Conversion in Input Handler

### Description
**CRITICAL:** The exporter incorrectly converts `return` statements from the input handler into unconditional `gState.running = false` statements, causing the program to exit immediately after any input event.

### Impact
- **Runtime Error:** Game exits immediately after any mouse click or key press
- Completely breaks the main loop
- Makes the exported program unusable

### Original Markdown Code
```nim
# In on:input block
elif event.type == "key":
  if event.action == "press":
    var code = event.keyCode
    
    if code == KEY_R:
      initGrid()
      return true  # Continue running
    elif code == KEY_ESCAPE:
      return false  # Exit
  
  return false  # Exit on other key events

return false  # Default: exit
```

### Incorrect Export
```nim
elif event.type == "key":
  if event.action == "press":
    var code = event.keyCode
    
    if code == ord('r') or code == ord('R'):
      initGrid()
    elif code == KEY_ESCAPE.int:
      gState.running = false
  
  gState.running = false  # ❌ WRONG: Always executed!
  
gState.running = false  # ❌ WRONG: Always executed!
```

### Expected Behavior
Return statements in the input handler indicate whether to continue the main loop:
- `return true` → Continue running (do nothing special)
- `return false` → Exit program (set `gState.running = false`)

### Correct Export Should Be
```nim
elif event.type == "key":
  if event.action == "press":
    var code = event.keyCode
    
    if code == ord('r') or code == ord('R'):
      initGrid()
      # return true → Continue (no action needed)
    elif code == KEY_ESCAPE.int:
      gState.running = false  # return false → Exit
  # Other key events → Could exit or continue depending on logic
```

Or better yet, use a control flow variable:
```nim
var shouldExit = false

# In event handler
elif event.type == "key":
  if event.action == "press":
    var code = event.keyCode
    
    if code == ord('r') or code == ord('R'):
      initGrid()
      # Continue running
    elif code == KEY_ESCAPE.int:
      shouldExit = true  # Exit
    else:
      shouldExit = true  # Exit on other keys
  else:
    shouldExit = true

# After event loop
if shouldExit:
  gState.running = false
```

### Root Cause
The exporter doesn't understand that `return` statements in the `on:input` block are control flow indicators for the main loop, not actual function returns. It naively converts them to exit commands and places them unconditionally outside their conditional blocks.

### Fix Priority
🔴 **CRITICAL** - Without this fix, exported programs are completely non-functional. Users cannot interact with the program at all.

---

## Issue 8: Duplicate Import

### Description
Minor: `lib/storie_themes` is imported twice (lines 11 and 16).

### Impact
- Warning but not an error
- Unnecessary duplication

### Example
```nim
import lib/storie_themes  # Line 11
# ...
import lib/storie_themes  # Line 16 - duplicate
```

---

## Recommendations for Exporter Fixes

### Priority Order
1. 🔴 **CRITICAL:** Fix Issue 7 (return statement conversion) - Without this, exported programs don't work at all
2. 🟠 **HIGH:** Fix Issue 1 (variable scope) - Causes compilation failures
3. 🟠 **HIGH:** Fix Issue 2 (array/seq syntax) - Causes compilation failures
4. 🟡 **MEDIUM:** Fix Issues 3-6 - Cause compilation failures but easier to work around
5. 🟢 **LOW:** Fix Issue 8 (duplicate imports) - Only produces warnings

### 1. Input Handler Return Statement Conversion
- **Critical:** Understand that `return true/false` in `on:input` blocks controls the main loop
- `return true` means "continue running" (no code needed)
- `return false` means "exit program" (set `gState.running = false`)
- Must preserve conditional logic - don't place exit code unconditionally
- Consider using a control variable to collect the exit decision, then act on it after event processing

### 2. Variable Scope Detection
- Analyze variable usage across function boundaries
- Variables used by multiple functions at module level should be declared in "User global variables" section
- Only variables used exclusively within `main()` should be local

### 2. Type System Awareness
- Use seq syntax (`@[]`, `@[...]`) instead of array syntax for dynamic collections
- Use `.add()` method instead of `+` concatenation for seqs
- Ensure type annotations match the literal syntax used

### 3. Function Placement
- Helper functions referenced by module-level code should be placed at module level
- Only functions used exclusively within `main()` should be nested

### 4. Operator Selection
- Use `div` for integer division when both operands are integers
- Use `/` only for floating-point division

### 5. Return Value Handling
- When calling functions with return values in statement position, prefix with `discard`
- Or use the return value in an expression

### 6. Key Code Handling
- Use `ord('x')` for character keys
- Use `KEY_CONSTANT.int` for special keys that are KeyCode enums
- Ensure proper imports are in place for key constants

### 7. Import Deduplication
- Check for duplicate imports and remove them

---

## Testing Checklist

When fixing the exporter, verify:

- [ ] **CRITICAL:** Input events don't cause program to exit unexpectedly
- [ ] Return statements in input handlers are converted correctly
- [ ] All global variables are declared at module level
- [ ] Seq syntax is used consistently (`@[]` not `[]`)
- [ ] Helper functions are at appropriate scope level
- [ ] Integer division uses `div` operator
- [ ] Bool return values are handled (used or discarded)
- [ ] Key codes use proper constants or `ord()`
- [ ] No duplicate imports
- [ ] Exported file compiles without modification
- [ ] **CRITICAL:** Exported file runs correctly and responds to input

---

## Additional Notes

The core issue appears to be that the exporter doesn't properly analyze variable scope and usage patterns. A potential solution would be to:

1. First pass: Collect all variable and function declarations
2. Second pass: Analyze usage patterns (which functions use which variables)
3. Third pass: Determine proper scope (module vs local)
4. Fourth pass: Generate code with correct placement

The exporter should aim to produce code that compiles without manual intervention.
