# Input Handling and DeltaTime Fix

## Issue

The transition helpers demo was crashing with "Undefined variable 'state'" when pressing SPACE. Two core issues were identified:

1. **Incorrect input event access**: Scripts were using `state.events` (plural) loop instead of single `event` variable
2. **Missing deltaTime**: The `deltaTime` variable was not exposed to Nimini scripts in `on:update` blocks

## Root Causes

### Input Event Access
In Nimini scripts, input events are NOT accessed via `state.events` array. Instead:
- Each `on:input` block receives a single `event` variable
- The event structure is:
  - `event.type` - "key", "mouse", or "text"
  - `event.keyCode` - Integer key code (e.g., 32 for SPACE)
  - `event.action` - "press", "release", or "repeat"
  - `event.mods` - Array of modifiers: ["shift", "alt", "ctrl", "super"]

### DeltaTime Exposure
- The `deltaTime` value was passed to `onUpdate` callback but not exposed to Nimini scripts
- Scripts were incorrectly trying to access `state.deltaTime` which doesn't exist

## Fixes Applied

### 1. Modified executeCodeBlock Signature
**File**: [index.nim](../index.nim#L1012)

Added `deltaTime` parameter:
```nim
proc executeCodeBlock(context: NiminiContext, codeBlock: CodeBlock, state: AppState, 
                      event: InputEvent = InputEvent(), deltaTime: float = 0.0): bool =
```

### 2. Exposed deltaTime to Scripts
**File**: [index.nim](../index.nim#L1033)

Added deltaTime as a local variable in script context:
```nim
scriptCode.add("var deltaTime = " & formatFloat(deltaTime, ffDecimal, 6) & "\n")
```

### 3. Updated onUpdate to Pass deltaTime
**File**: [index.nim](../index.nim#L1251)

```nim
discard executeCodeBlock(storieCtx.niminiContext, codeBlock, state, InputEvent(), dt)
```

### 4. Fixed Demo Input Handling
**File**: [examples/transition_helpers_demo.md](../examples/transition_helpers_demo.md)

**Before** (incorrect):
```nim
on:input
for event in state.events:
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == INPUT_ESCAPE:
      state.running = false
    elif event.keyCode == INPUT_SPACE:
      # ...
```

**After** (correct):
```nim
on:input
# SPACE key triggers a new transition (ESC to quit is handled by default)
if event.type == "key" and event.action == "press":
  if event.keyCode == 32:  # SPACE key
    # Start new transition
    trans = nimini_newTransition(1.5, EASE_IN_OUT_CUBIC)
    # ...
```

### 5. Fixed Demo Update Block
**Before**: `nimini_updateTransition(trans, state.deltaTime)`  
**After**: `nimini_updateTransition(trans, deltaTime)`

### 6. Updated Documentation
**File**: [docs/ANIMATION_HELPERS.md](ANIMATION_HELPERS.md)

Added "Available Variables" section explaining:
- `deltaTime` in `on:update` blocks
- `event` structure in `on:input` blocks
- Built-in ESC key handling

## Variables Available in Scripts

### All Blocks
- `termWidth`, `termHeight` - Terminal dimensions
- `fps` - Current frames per second
- `frameCount` - Total frames rendered

### on:update Blocks
- `deltaTime` - Time since last frame (seconds)

### on:input Blocks
- `event` - Input event with `.type`, `.keyCode`, `.action`, `.mods`

## Key Constants

Note: Key code constants like `INPUT_SPACE` are NOT exposed to Nimini. Use raw values:
- SPACE = 32
- ESC = 27 (but ESC is handled automatically by engine)
- Enter = 13
- etc.

## Testing

Demo now runs successfully:
```bash
./tstorie examples/transition_helpers_demo.md
```

- Color transitions render smoothly
- SPACE key starts new transitions without errors
- ESC key exits (built-in behavior)
- Progress percentage updates correctly

## Impact

This fix affects:
- All existing transition demos that used incorrect `state.events` syntax
- Any scripts that tried to access `state.deltaTime`
- Documentation examples that showed incorrect patterns

All animation helper examples have been updated to use the correct patterns.
