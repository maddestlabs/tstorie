# Debugging Guide for TStorie Scripts

This guide provides tools and techniques for debugging nimini scripts embedded in markdown files.

## Table of Contents

**Part 1: Syntax Errors** - Line number mapping and parse errors
- [The Problem](#the-problem)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Common Syntax Issues](#common-issues--solutions)

**Part 2: Runtime Errors** - Undefined functions and variables
- [Beyond Syntax](#part-2-runtime-errors---beyond-syntax)
- [Symbol Checker](#solution-symbol-checker)
- [Real Debugging Example](#real-debugging-example)
- [Complete Workflow](#complete-validation-workflow)

**Reference**
- [Tools Summary](#debugging-tools-summary)
- [Best Practices](#best-practices)
- [Claude Integration](#for-claude-reporting-runtime-issues)

---

# Part 1: Syntax Errors - Line Number Mapping

## The Problem

When tstorie scripts have errors, the line numbers reported are relative to the extracted script, not the markdown file. This makes it difficult to locate and fix issues since you see:
```
Error in render block: Unexpected token in expression at line 85
```

But you don't know which line in your markdown that corresponds to!

## The Solution: debugger.nim

A debugging tool (`debugger.nim`) that:
1. **Extracts code blocks** with full line number mapping
2. **Validates syntax** and shows both script and markdown line numbers
3. **Provides context** around errors with source code display
4. **Works with all lifecycle blocks**: `on:init`, `on:render`, `on:input`

## Quick Start

### Basic validation (recommended for quick checks):
```bash
nim r debugger.nim docs/demos/yourfile.md
# Or use the wrapper:
./validate.sh yourfile
```

This gives you a quick summary:
```
Found 3 code block(s):
  - on:init (38 lines, MD lines 14-52)
  - on:render (83 lines, MD lines 55-138)
  - on:input (184 lines, MD lines 141-325)

=== QUICK VALIDATION ===

✓ on:init - OK
✗ on:render - ERROR at script line 79 (MD line 134)
✓ on:input - OK
```

### Detailed validation with error context:
```bash
nim r debugger.nim docs/demos/yourfile.md --validate
# Or:
./validate.sh yourfile --validate
```

This shows full error details with code context:
```
Validating on:render...
  ✗ ERROR

Unexpected token in expression at line 79
  Script line: 79
  Markdown line: 134

Code Context (around error):
Script Line | MD Line | Code
------------|---------|------------------------------------------------------------
         76 |     131 |     drawSlider(0, sliderX, sliderY, sliderWidth, ...
         77 |     132 |   
         78 |     133 |   # Checkbox
 >>>     79 |     134 |   elif wType == 3:
         80 |     135 |     let cbIndex = i - 4
```

### Inspect a specific block:
```bash
nim r debugger.nim docs/demos/yourfile.md render
```

Shows the full code with line mappings for just the `on:render` block.

### Show line mappings for all blocks:
```bash
nim r debugger.nim docs/demos/yourfile.md --lines
# Or:
./validate.sh yourfile --lines
```

## Usage Examples

### Example 1: Quick validation before running
```bash
# Before running your demo
./validate.sh tui2

# If OK, run it
./ts tui2
```

### Example 2: Fix a reported error
```bash
# You see this error when running:
# Error in render block: Unexpected token in expression at line 85

# Run debug tool to find exact location:
./validate.sh tui2 --validate

# Output shows:
# ✗ on:render - ERROR at script line 79 (MD line 134)
# Now you know to check line 134 in your markdown!
```

### Example 3: Working with Claude
When asking Claude to help fix a script:

```bash
# Run validation
./validate.sh myfile --validate

# Copy the full output and paste into Claude's chat
# Claude can now see:
# - Exact error message
# - Both script and markdown line numbers
# - Code context around the error
```

## Common Issues & Solutions

### 1. Multi-line function calls
**Problem:** Nimini doesn't support all Nim's multi-line syntax
```nim
# This causes errors:
drawSlider(0, x, y, width, value,
           min, max, focused)  # ❌ Parser gets confused
```

**Solution:** Keep function calls on one line
```nim
# This works:
drawSlider(0, x, y, width, value, min, max, focused)  # ✓ OK
```

### 2. Missing elif/else
**Problem:** "Unexpected token" often means improper if/elif/else structure
```nim
if condition:
  doSomething()
  
elif otherCondition:  # ❌ If prev block has syntax error
  doOther()
```

**Solution:** Check indentation and syntax of the previous block

### 3. Unbalanced brackets/parentheses
**Problem:** Easy to miss in long expressions
```nim
let value = calculate(a, b, c  # ❌ Missing closing )
let other = 5
```

**Solution:** Use the debug tool to find the exact line

## Integration with Development Workflow

### 1. Pre-commit validation
Add to your workflow:
```bash
#!/bin/bash
# validate-all.sh
for file in docs/demos/*.md; do
  echo "Validating $file..."
  ./validate.sh "$file" || exit 1
done
echo "All demos validated!"
```

### 2. VS Code task
Add to `.vscode/tasks.json`:
```json
{
  "label": "Validate TStorie Script",
  "type": "shell",
  "command": "./validate.sh ${fileBasenameNoExtension}",
  "problemMatcher": [],
  "presentation": {
    "reveal": "always",
    "panel": "new"
  }
}
```

### 3. Quick fix script
Create `run-demo.sh`:
```bash
#!/bin/bash
# Quick validation and run
DEMO=$1
echo "Validating $DEMO..."
if ./validate.sh "$DEMO"; then
  echo "✓ Validation passed. Running demo..."
  ./ts "$DEMO"
else
  echo "✗ Validation failed. Fix errors above."
fi
```

Usage: `./run-demo.sh tui2`

## Advanced: Adding Debug Output to Scripts

You can add debug output directly in your scripts:

```nim
# In on:init or on:render
proc debugPrint(msg: string) =
  # This will show in terminal (not in WASM)
  when not defined(emscripten):
    echo "[DEBUG] " & msg

# Use it:
debugPrint("Widget count: " & $widgetCount)
debugPrint("Focus index: " & $focusIndex)
```

## Tips for Claude Integration

When asking Claude to help debug:

1. **Always include the full validation output**
   ```bash
   ./validate.sh myfile --validate > debug.txt
   ```
   
2. **Share the specific block if needed**
   ```bash
   nim r debugger.nim myfile.md render > render-block.txt
   ```

3. **Mention both line numbers**
   "Line 79 in the script (line 134 in the markdown) has an error..."

4. **Include context**
   Show a few lines before and after the error line

## Building the Debug Tool

The debug tool compiles to a standalone binary:
```bash
# Compile once for faster repeated use
nim c -d:release debugger.nim

# Now you can use it directly
./debugger docs/demos/tui2.md --validate

# Or just use validate.sh which auto-compiles when needed
./validate.sh tui2 --validate
```

## Future Enhancements

Possible improvements to the debug tool:

1. **Interactive mode** - Step through execution
2. **Variable inspection** - Show variable values at each line
3. **Breakpoint support** - Pause execution at specific lines
4. **AST visualization** - See how code is parsed
5. **Better error messages** - Context-aware suggestions

These would require integration with the nimini runtime and are more complex to implement.

---

# Part 2: Runtime Errors - Beyond Syntax

While `debugger.nim` catches syntax errors, **runtime errors** happen when code executes. These are harder to debug because:

- ❌ **Terminal version** silently exits (uses `quit` internally)
- ❌ **No error messages** in terminal output
- ✅ **WASM console** shows errors, but you may not test there first

## Common Runtime Errors

### Scenario: Script Passes Validation But Fails Silently

```bash
./validate.sh tui2    # ✓ Passes
./ts tui2             # Screen is blank, no error!
```

**Possible causes:**
- Undefined function (not registered in nimini)
- Undefined variable (not in `on:init`)
- Type mismatch
- Array out of bounds

## Why Terminal Errors Are Silent

The nimini runtime uses `quit` for errors:

```nim
proc getVar*(env: ref Env; name: string): Value =
  var e = env
  while e != nil:
    if name in e.vars:
      return e.vars[name]
    e = e.parent
  quit "Runtime Error: Undefined variable '" & name & "'"  # ← Exits silently!
```

## Solution: Symbol Checker

`check_symbols.nim` statically analyzes code for undefined symbols:

### Usage
```bash
# Compile once
nim c -d:release check_symbols.nim

# Check for undefined functions/variables
./check_symbols docs/demos/tui2.md
```

### Example Output
```
Symbol Check: docs/demos/tui2.md

Found 3 code block(s)
Found 22 variables defined in on:init

Checking on:render...
  ✗ Undefined functions:
    - drawBoxSingle
      Hint: Check if this function is registered in lib/nimini_bridge.nim
```

## Real Debugging Example

### Problem: tui2.md renders nothing

```bash
./validate.sh tui2           # ✓ Syntax OK
./ts tui2                    # Blank screen, no error
```

### Step 1: Check WASM (if available)
Browser console shows:
```
Runtime Error: Undefined variable 'drawBoxSingle'
```

### Step 2: Use Symbol Checker
```bash
./check_symbols docs/demos/tui2.md
```

Output:
```
✗ Undefined functions:
  - drawBoxSingle
    Hint: Check if this function is registered in lib/nimini_bridge.nim
```

### Step 3: Investigate
```bash
# Does function exist in library?
grep -r "proc drawBoxSingle" lib/
# lib/tui_helpers.nim:97:proc drawBoxSingle*(layer: int...) = ✓

# Is it bound to nimini?
grep "drawBoxSingle" lib/tui_helpers_bindings.nim
# (no matches) ✗ BUG FOUND!
```

### Step 4: Fix

**Option A:** Use registered alternative
```nim
# Replace:
drawBoxSingle(0, x, y, w, h, style)

# With:
drawBoxSimple(0, x, y, w, h, style)  # This IS registered
```

**Option B:** Add the binding (advanced)
See "Extending the API" section below.

## Complete Validation Workflow

### Full Check Script

Create `check.sh`:
```bash
#!/bin/bash
# Full validation: syntax + symbols

./validate.sh "$1" || exit 1
./check_symbols "$1.md" || exit 1
echo "✅ All validation passed!"
```

Usage:
```bash
./check.sh tui2
```

### Recommended Workflow

```bash
# Before running ANY demo:
./validate.sh myfile        # 1. Syntax check
./check_symbols myfile.md   # 2. Symbol check  
./ts myfile                 # 3. Run if both pass
```

## Common Runtime Error Patterns

### 1. Undefined Function
```
Runtime Error: 'functionName' is not callable
```

**Causes:**
- Function not registered in `*_bindings.nim`
- Typo in function name

**Fix:** Use `check_symbols` to identify, then check bindings

### 2. Undefined Variable
```
Runtime Error: Undefined variable 'varName'
```

**Causes:**
- Not defined in `on:init`
- Typo
- Wrong scope

**Fix:** Define all variables in `on:init`, check spelling

### 3. Type Errors
```
Runtime Error: Cannot convert string 'abc' to int
```

**Causes:**
- Passing wrong type to function
- Math on non-numeric values

**Fix:** Add explicit conversions: `int(value)`, `float(value)`

### 4. Array Bounds
```
Runtime Error: Array index out of bounds: 5 (length: 3)
```

**Fix:** Add bounds checking:
```nim
if index >= 0 and index < len(myArray):
  value = myArray[index]
```

## Debugging Tools Summary

| Tool | Catches | When to Use |
|------|---------|-------------|
| `./validate.sh` | Syntax errors | Always, first |
| `./check_symbols` | Undefined symbols | Before running |
| WASM console | All runtime errors | When available |
| Debug logging | Logic errors | When behavior is wrong |

## Adding Debug Logging

When logic is wrong but no errors occur:

```nim
# In your on:init or on:render
proc debugLog(msg: string) =
  when not defined(emscripten):
    echo "[DEBUG] ", msg

# Use it:
debugLog("Widget count: " & $widgetCount)
debugLog("Focus: " & $focusIndex & " Type: " & $widgetTypes[focusIndex])
```

## Best Practices

### 1. Define All Variables in on:init
```nim
# ✓ Good: All state defined upfront
var widgetCount = 8
var focusIndex = 0
var message = ""
```

### 2. Always Run Both Checks
```bash
./validate.sh myfile && ./check_symbols myfile.md && ./ts myfile
```

### 3. Test Incrementally
- Start minimal
- Add features one at a time
- Test after each addition

### 4. Check Available Functions
```bash
# List all registered nimini functions
grep "registerNative" lib/*_bindings.nim | grep -o '"[^"]*"' | sort -u
```

## For Claude: Reporting Runtime Issues

When asking Claude for help, include:

1. **Syntax validation output**
   ```bash
   ./validate.sh myfile --validate
   ```

2. **Symbol check output**
   ```bash
   ./check_symbols myfile.md
   ```

3. **WASM console errors** (if available)

4. **The failing code block**

Claude can diagnose much faster with all three!

## Extending the API (Advanced)

If `check_symbols` reports a missing function that you need:

### Add Nimini Binding

In `lib/tui_helpers_bindings.nim`:

```nim
proc nimini_drawBoxSingle*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawBoxSingle(layer, x, y, w, h, style)
  if args.len != 6:
    quit "drawBoxSingle() requires 6 arguments"
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let style = valueToStyle(args[5])
  
  drawBoxSingle(layer, x, y, w, h, style)
  return valNil()
```

### Register It

In the same file's `registerTuiHelpers` proc:

```nim
registerNative("drawBoxSingle", nimini_drawBoxSingle,
  doc="Draw a box with single-line borders")
```

### Update Symbol Checker

Add to `check_symbols.nim` KNOWN_FUNCTIONS list:
```nim
"drawBoxSingle",
```

---

## Complete Summary

### Syntax Errors (Part 1)
- ✓ Use `debugger.nim` / `./validate.sh`
- ✓ Maps script lines to markdown lines
- ✓ Shows context around errors

### Runtime Errors (Part 2)  
- ✓ Use `check_symbols.nim`
- ✓ Finds undefined functions/variables
- ✓ Catches 80% of runtime issues before running

### The Complete Workflow
```bash
# 1. Syntax check
./validate.sh myfile

# 2. Symbol check
./check_symbols myfile.md

# 3. Run (only if both pass)
./ts myfile
```

Always validate before running! 🐛🔍
