# Input System Architecture

## Overview

The tStorie input system provides a unified, backend-agnostic API for handling keyboard, mouse, and other input events across multiple platforms:

- **Terminal**: Native ANSI/CSI escape sequence parsing
- **WASM**: JavaScript event callbacks with normalization
- **SDL3**: Native SDL3 event polling with scancode→keycode mapping

The system uses a **facade pattern** with compile-time backend selection to ensure zero overhead and consistent behavior across all platforms.

## Problem Statement

Prior to this architecture, different backends generated events inconsistently:

- **Terminal backend**: Sent only `TextEvent` for printable characters (e.g., pressing 'Q' → `TextEvent("Q")`)
- **WASM backend**: Sent BOTH `KeyEvent` AND `TextEvent` for the same keypress (e.g., pressing 'Q' → `KeyEvent(81)` + `TextEvent("Q")`)

This inconsistency forced user code to handle the same key in different ways depending on the platform, breaking the "write once, run everywhere" principle.

## Architecture

```
src/
├── input.nim                    # Unified facade (main entry point)
├── input/
│   ├── types.nim               # Shared types, constants, normalization
│   ├── terminput.nim           # Terminal backend (ANSI/CSI parsing)
│   ├── wasminput.nim           # WASM backend (JavaScript events)
│   └── sdl3input.nim           # SDL3 backend (native events)
└── types.nim                    # Core types (imports InputParser from input.nim)
```

### Module Responsibilities

#### `src/input.nim` (Facade)
- **Purpose**: Single API for all backends
- **Exports**: `InputParser` type, `newInputParser()` factory
- **Backend Selection**: Compile-time via `when defined(emscripten)` / `when defined(sdl3Backend)` / else terminal
- **Usage**: Always import this module, never import backend modules directly

#### `src/input/types.nim` (Shared)
- **Purpose**: Cross-platform event types and normalization logic
- **Exports**: 
  - Event types: `KeyEvent`, `TextEvent`, `MouseEvent`, `MouseMoveEvent`, `ResizeEvent`
  - Key constants: `KEY_ESCAPE`, `KEY_UP`, `KEY_DOWN`, `KEY_Q`, etc.
  - Modifier constants: `ModShift`, `ModAlt`, `ModCtrl`, `ModSuper`
  - Normalization: `normalizeEvents()` function
- **Dependencies**: None (imported by all backends)

#### `src/input/terminput.nim` (Terminal Backend)
- **Purpose**: Terminal-specific ANSI/CSI escape sequence parsing
- **Exports**: `TerminalInputParser`, `pollInput()`, backend-specific types
- **Features**:
  - CSI sequence parsing for special keys and mouse events
  - UTF-8 multi-byte character handling
  - Mouse tracking (click, drag, scroll)
  - Resize event detection
  - Escape sequence timeout handling
- **Dependencies**: `types`, `platform/terminal`

#### `src/input/wasminput.nim` (WASM Backend)
- **Purpose**: WASM input shim
- **Exports**: `WasmInputHandler`, `pollInput()`
- **Features**:
  - Minimal implementation (events arrive via JavaScript callbacks in tstorie.nim)
  - JavaScript keyCode normalization (`normalizeJSKeyCode`) to convert JS codes (37-40 for arrows) to unified codes (1000-1003)
  - Event normalization to match terminal behavior
- **Dependencies**: `types`
- **Note**: Actual event handling occurs via `emHandleKeyPress`, `emHandleTextInput`, etc. exported C functions called by JavaScript. JavaScript keyCodes are normalized to match the unified system before creating InputEvents.

#### `src/input/sdl3input.nim` (SDL3 Backend)
- **Purpose**: SDL3 native event handling for WASM builds
- **Exports**: `SDL3InputHandler`, `pollInput()`
- **Features**:
  - SDL scancode to KeyCode mapping (4-29→A-Z, 30-39→1-0)
  - Modifier detection via SDL_GetModState()
  - Character case handling (lowercase default, uppercase with shift)
  - Shift+number symbol mapping (1→!, 2→@, etc.)
  - Mouse events with modifier support
  - Resize event handling
- **Dependencies**: `types`, `backends/sdl3/sdl3_bindings`
- **Note**: Uses pointer-based canvas reference to avoid circular dependencies

## Event Types

### SDL3-Compatible Key Types

The input system uses SDL3-compatible type definitions for cross-platform compatibility:

```nim
type
  KeyCode* = distinct int
    ## Logical key (respects keyboard layout)
    ## Maps to SDL_Keycode in SDL3 backend
  
  ScanCode* = distinct int
    ## Physical key position (layout-independent)
    ## Maps to SDL_Scancode in SDL3 backend
    ## Based on USB HID Usage Tables
  
  KeyMod* = enum
    ## Keyboard modifiers - Maps to SDL_Keymod in SDL3 backend
    kmNone = 0
    kmShift = 1 shl 0
    kmCtrl = 1 shl 1
    kmAlt = 1 shl 2
    kmSuper = 1 shl 3     # Windows/Command key
    kmCapsLock = 1 shl 8
    kmNumLock = 1 shl 9
```

**Note**: `KeyCode` and `ScanCode` are `distinct int` types, requiring explicit conversion when needed.

### InputEvent (Variant Object)

```nim
type
  InputAction* = enum
    Press, Release, Repeat

  InputEventKind* = enum
    KeyEvent      # Special keys (arrows, escape, function keys, etc.)
    TextEvent     # Printable characters (ASCII 32-126)
    MouseEvent    # Mouse button press/release
    MouseMoveEvent
    ResizeEvent
  
  InputEvent* = object
    case kind*: InputEventKind
    of KeyEvent:
      keyCode*: int                # KEY_* constant value (e.g., 27 for KEY_ESCAPE)
      keyMods*: set[uint8]         # Modifiers: ModShift, ModAlt, ModCtrl, ModSuper
      keyAction*: InputAction      # Press, Release, or Repeat
    of TextEvent:
      text*: string                # UTF-8 character(s)
      textMods*: set[uint8]        # Modifiers work on text events too!
    of MouseEvent:
      button*: TerminalMouseButton # Left, Right, Middle, ScrollUp, ScrollDown, Unknown
      mouseX*, mouseY*: int
      mods*: set[uint8]
      action*: InputAction
    of MouseMoveEvent:
      moveX*, moveY*: int
      moveMods*: set[uint8]
    of ResizeEvent:
      newWidth*, newHeight*: int
```

**Important**: After normalization, printable characters (ASCII 32-126) ONLY appear as `TextEvent`, never as `KeyEvent`. This ensures consistent behavior across all backends.

### Key Constants

All key constants are defined as `KeyCode` types:

```nim
# Control characters
const
  KEY_BACKSPACE* = KeyCode(8)
  KEY_TAB* = KeyCode(9)
  KEY_RETURN* = KeyCode(13)
  KEY_ENTER* = KEY_RETURN           # Alias
  KEY_ESCAPE* = KeyCode(27)
  KEY_ESC* = KEY_ESCAPE             # Short alias
  KEY_DELETE* = KeyCode(127)

# Arrow keys & Navigation (custom codes 1000+)
const
  KEY_UP* = KeyCode(1000)
  KEY_DOWN* = KeyCode(1001)
  KEY_LEFT* = KeyCode(1002)
  KEY_RIGHT* = KeyCode(1003)
  KEY_HOME* = KeyCode(1004)
  KEY_END* = KeyCode(1005)
  KEY_PAGEUP* = KeyCode(1006)
  KEY_PAGEDOWN* = KeyCode(1007)
  KEY_INSERT* = KeyCode(1008)

# Function keys (1100+)
const
  KEY_F1* = KeyCode(1100)
  KEY_F2* = KeyCode(1101)
  # ... through KEY_F12

# Printable ASCII (32-126)
const
  KEY_SPACE* = KeyCode(32)
  KEY_A* = KeyCode(65)  # Uppercase letters A-Z
  KEY_0* = KeyCode(48)  # Numbers 0-9
  KEY_PLUS* = KeyCode(43)
  # ... and more symbols
```

**Note**: In native Nim code, use `KeyCode` type for parameters. When comparing with integers from scripting layer, use explicit conversion: `KeyCode(intValue)`.

### Modifier Constants

```nim
const
  ModShift* = 0'u8
  ModAlt* = 1'u8
  ModCtrl* = 2'u8
  ModSuper* = 3'u8
```

Access via `event.keyMods`, `event.textMods`, or `event.mods` depending on event type.
Test with `if ModShift in event.keyMods: ...`

## Event Normalization

The `normalizeEvents()` function ensures consistent behavior across backends:

### Rules

1. **Printable Characters (ASCII 32-126)**:
   - Only appear as `TextEvent` 
   - Any `KeyEvent` for printable characters is filtered out when a corresponding `TextEvent` exists
   
2. **Special Keys** (arrows, escape, function keys):
   - Only appear as `KeyEvent`
   - Never generate `TextEvent`

3. **Modifiers**:
   - Preserved in both `KeyEvent.mods` and `TextEvent.textMods`
   - Available for detection (e.g., CTRL+Click, SHIFT+Q)

### Example: Pressing 'Q'

**Before Normalization (WASM raw events):**
```nim
@[
  InputEvent(kind: KeyEvent, keyCode: 81, keyMods: {}, keyAction: Press),
  InputEvent(kind: TextEvent, text: "Q", textMods: {})
]
```

**After Normalization:**
```nim
@[
  InputEvent(kind: TextEvent, text: "Q", textMods: {})
]
```

The duplicate `KeyEvent(81)` is removed because a `TextEvent("Q")` exists.

### Example: Pressing Arrow Up

**Before & After Normalization (same):**
```nim
@[
  InputEvent(kind: KeyEvent, keyCode: 1000, keyMods: {}, keyAction: Press)
]
```

Special keys (arrows, escape, function keys) remain as `KeyEvent` and never generate `TextEvent`.

## Usage Guide

### Core API Usage (Nim Code)

```nim
import input

var parser = newInputParser()

while running:
  let events = parser.pollInput()
  for event in events:
    case event.kind
    of KeyEvent:
      if event.keyCode == KEY_ESCAPE.int:  # Note: Compare with .int
        quit = true
      elif event.keyCode == KEY_UP.int:
        moveUp()
      
    of TextEvent:
      # Handle printable characters with full modifier support
      if event.text == "q" or event.text == "Q":
        if ModShift in event.textMods:
          echo "Shift+Q detected!"
        else:
          quit = true
      
      # Example: Alt+A for special action
      if event.text == "a" and ModAlt in event.textMods:
        echo "Alt+A pressed!"
        specialAction()
      
    of MouseEvent:
      if event.action == Press and event.button == Left:
        if ModCtrl in event.mods:
          echo "CTRL+Click at ", event.mouseX, ",", event.mouseY
        else:
          handleClick(event.mouseX, event.mouseY)
      
    of MouseMoveEvent:
      handleMouseMove(event.moveX, event.moveY)
      
    of ResizeEvent:
      resizeWindow(event.newWidth, event.newHeight)
```

**Important for Native Nim Functions**: When writing functions that accept key codes:

```nim
# Use KeyCode type for parameters
proc handleKey(keyCode: KeyCode) =
  if keyCode == KEY_ESCAPE:
    quit()

# When converting from int (e.g., from scripting layer):
let keyCode = KeyCode(intValue)

# In events, keyCode is stored as int, so compare directly:
if event.keyCode == KEY_ESCAPE.int:
  # or extract and convert:
  let key = KeyCode(event.keyCode)
  if key == KEY_ESCAPE:
    ...
```

### Scripting Guide (tStorie Markdown)

When writing tStorie markdown files, event handling happens in the `on:input` block. The event system is exposed through a simplified API that matches the core architecture.

#### Event Object Structure

In tStorie scripts, events have these properties:

**For KeyEvent (special keys):**
```nim
event.type: "key"
event.keyCode: int           # Raw integer value (e.g., 1000 for arrow up)
event.action: "press" | "release" | "repeat"
event.key: string            # Empty for special keys, character for printable
event.mods: array of string  # ["shift", "ctrl", "alt", "super"]
```

**For TextEvent (printable characters):**
```nim
event.type: "text"
event.text: string           # The character(s) entered
event.keyCode: int           # ASCII code of first character (for convenience)
event.mods: array of string  # ["shift", "ctrl", "alt", "super"]
```

**For MouseEvent:**
```nim
event.type: "mouse"
event.button: "left" | "middle" | "right" | "scroll_up" | "scroll_down" | "unknown"
event.action: "press" | "release" | "repeat"
event.x: int
event.y: int
event.mods: array of string  # ["shift", "ctrl", "alt", "super"]
```

**For MouseMoveEvent:**
```nim
event.type: "mouse_move"
event.x: int
event.y: int
event.mods: array of string
```

Global variables available in all event handlers:
```nim
mouseX: int        # Current mouse X position
mouseY: int        # Current mouse Y position
termWidth: int     # Terminal width
termHeight: int    # Terminal height
```

#### Complete Working Example

```markdown
---
title: "Input Demo"
---

\```nim on:init
var quit = false
var message = "Press some keys!"
\```

\```nim on:input
# === TEXT EVENTS (printable characters) ===
if event.type == "text":
  # Simple character detection
  if event.text == "q" or event.text == "Q":
    # Let default handler process Q/ESC for quit
    return false
  
  # Uppercase implies Shift was pressed
  if event.text == "A":
    message = "Uppercase A (Shift was held)"
    return true  # Mark as consumed
  
  # Check modifiers explicitly (works for both upper and lowercase)
  var hasCtrl = false
  var i = 0
  while i < len(event.mods):
    if event.mods[i] == "ctrl":
      hasCtrl = true
    i = i + 1
  
  if hasCtrl and event.text == "s":
    message = "Ctrl+S detected - Save!"
    return true  # Mark as consumed

# === KEY EVENTS (special keys like arrows, escape, function keys) ===
elif event.type == "key":
  # Arrow key detection (keyCode 1000-1003)
  if event.keyCode == 1000:  # KEY_UP
    message = "Arrow Up pressed"
    return true
  
  if event.keyCode == 1001:  # KEY_DOWN
    message = "Arrow Down pressed"
    return true
  
  # Function key example
  if event.keyCode == 1100:  # KEY_F1
    message = "F1 pressed - Help!"
    return true

# === MOUSE EVENTS ===
elif event.type == "mouse":
  if event.button == "left" and event.action == "press":
    message = "Clicked at (" + toString(event.x) + "," + toString(event.y) + ")"
    return true
  
  if event.button == "scroll_up":
    message = "Scrolled up"
    return true

# Let default handlers process unhandled events
return false
\```

\```nim on:render
# Draw the message
drawText(2, 2, message, "white", "black")
drawText(2, 4, "Press Q to quit", "gray", "black")
\```
```

### Key Event Types Reference

| Event Type | When It Fires | Use For |
|------------|---------------|---------|
| `TextEvent` | Printable characters (space through ~) | Letter/number input, typing, text fields |
| `KeyEvent` | Special keys (arrows, escape, F1-F12, etc.) | Navigation, shortcuts, control keys |
| `MouseEvent` | Mouse button press/release, scroll | Click handling, button interactions |
| `MouseMoveEvent` | Mouse movement | Hover effects, drag operations |
| `ResizeEvent` | Terminal/window resize | Layout adjustments |

### Best Practices

#### ✅ DO: Use TextEvent for Character Detection

**Nim Core:**
```nim
# Correct: Works on all backends
if event.kind == TextEvent:
  if event.text == "q" or event.text == "Q":
    quit = true
```

**tStorie Script:**
```nim
# Correct: Check event.type == "text"
if event.type == "text":
  if event.text == "q" or event.text == "Q":
    quit = true
```

#### ❌ DON'T: Use KeyEvent for Printable Characters

**Nim Core:**
```nim
# Incorrect: Inconsistent across backends
if event.kind == KeyEvent and event.keyCode == KEY_Q.int:
  quit = true  # Won't work reliably!
```

**tStorie Script:**
```nim
# Incorrect: Never check keyCode for letters/numbers
if event.type == "key" and event.keyCode == 81:
  quit = true  # This will NOT work!
```

**Why this fails:** Printable characters only generate `TextEvent` after normalization. The `KEY_Q` constant exists but the corresponding `KeyEvent` is filtered out.

#### ✅ DO: Check Modifiers on Event Object

**Nim Core:**
```nim
# Correct: Direct access to modifier set
if event.kind == TextEvent and event.text == "Q":
  if ModShift in event.textMods:
    echo "Shift+Q detected!"
```

**tStorie Script:**
```nim
# Correct: Iterate through event.mods array
if event.type == "text" and event.text == "Q":
  var hasShift = false
  var i = 0
  while i < len(event.mods):
    if event.mods[i] == "shift":
      hasShift = true
    i = i + 1
  if hasShift:
    echo "Shift+Q detected!"

# Or simpler: uppercase implies Shift
if event.type == "text" and event.text == "Q":
  echo "Shift+Q detected!"  # Q is uppercase!
```

#### ✅ DO: Use KeyEvent for Special Keys

**Nim Core:**
```nim
# Correct: Special keys always use KeyEvent
if event.kind == KeyEvent:
  case event.keyCode
  of KEY_UP.int: moveUp()
  of KEY_DOWN.int: moveDown()
  of KEY_ESCAPE.int: quit = true
  else: discard
```

**tStorie Script:**
```nim
# Correct: Check event.type == "key" for arrows, ESC, etc.
if event.type == "key":
  if event.keyCode == 1000:  # KEY_UP
    moveUp()
  elif event.keyCode == 1001:  # KEY_DOWN
    moveDown()
  elif event.keyCode == 27:  # KEY_ESCAPE
    # Let default handler exit the app
    return false
```

#### ✅ DO: Handle Mouse Events with Modifiers

**tStorie Script:**
```nim
if event.type == "mouse" and event.action == "press":
  # Check which button
  if event.button == "left":
    # Check for Ctrl modifier
    var hasCtrl = false
    var i = 0
    while i < len(event.mods):
      if event.mods[i] == "ctrl":
        hasCtrl = true
      i = i + 1
    
    if hasCtrl:
      specialAction(mouseX, mouseY)
    else:
      normalClick(mouseX, mouseY)
  
  elif event.button == "right":
    contextMenu(mouseX, mouseY)
```

#### ✅ DO: Use KeyEvent for Special Keys

**Nim Core:**
```nim
# Correct: Special keys always use KeyEvent
if event.kind == KeyEvent:
  case event.keyCode
  of KEY_UP.int: moveUp()
  of KEY_DOWN.int: moveDown()
  of KEY_ESCAPE.int: quit()
  else: discard
```

**tStorie Script:**
```nim
# Correct: Check event.type == "key" for special keys
if event.type == "key":
  if event.keyCode == 1000:  # KEY_UP
    moveUp()
  elif event.keyCode == 27:  # KEY_ESCAPE
    quit()
```

#### ✅ DO: Track Arrow Key States Properly

**tStorie Script:**
```nim
# In on:init
var arrowUp = false
var arrowDown = false
var arrowLeft = false
var arrowRight = false

# In on:input
if event.type == "key":
  if event.keyCode == 1000:  # KEY_UP
    arrowUp = (event.action == "press" or event.action == "repeat")
    if event.action == "release":
      arrowUp = false
  
  elif event.keyCode == 1001:  # KEY_DOWN
    arrowDown = (event.action == "press" or event.action == "repeat")
    if event.action == "release":
      arrowDown = false
  
  # ... similar for left/right

# In on:update or on:render
if arrowUp:
  playerY = playerY - 1
if arrowDown:
  playerY = playerY + 1
```

#### ✅ DO: Use Mouse Wheel Events

**tStorie Script:**
```nim
if event.type == "mouse":
  if event.button == "scroll_up":
    zoom = zoom + 0.1
  elif event.button == "scroll_down":
    zoom = zoom - 0.1
```

#### ❌ DON'T: Mix Event Types

**tStorie Script:**
```nim
# Incorrect: Checking text on key event
if event.type == "key":
  if event.text == "Q":  # event.text doesn't exist on key events!
    quit = true

# Incorrect: Checking keyCode on text event
if event.type == "text":
  if event.keyCode == KEY_Q:  # This doesn't work!
    quit = true
```

### Common Patterns Reference

#### Pattern: Simple Quit Key

```nim
if event.type == "text":
  if event.text == "q" or event.text == "Q":
    return false  # Pass to default handler which will quit
```

Or to handle quit yourself:
```nim
if event.type == "text":
  if event.text == "q" or event.text == "Q":
    quit = true  # Set your own quit flag
    return true  # Mark as consumed so default handler doesn't also process it
```

#### Pattern: Modifier + Key Combo

```nim
if event.type == "text" and event.text == "s":
  var hasCtrl = false
  var i = 0
  while i < len(event.mods):
    if event.mods[i] == "ctrl":
      hasCtrl = true
    i = i + 1
  if hasCtrl:
    saveFile()  # Ctrl+S
```

#### Pattern: Shift Detection (Simplified)

```nim
if event.type == "text":
  if event.text == "Q":  # Uppercase means Shift was pressed
    specialAction()
  elif event.text == "q":  # Lowercase means no Shift
    normalAction()
```

#### Pattern: Arrow Key Movement

```nim
# On init
var playerX = 10
var playerY = 10

# On input
if event.type == "key" and event.action == "press":
  if event.keyCode == 1000:  # KEY_UP
    playerY = playerY - 1
  elif event.keyCode == 1001:  # KEY_DOWN
    playerY = playerY + 1
  elif event.keyCode == 1002:  # KEY_LEFT
    playerX = playerX - 1
  elif event.keyCode == 1003:  # KEY_RIGHT
    playerX = playerX + 1
```

#### Pattern: Click with Modifier Detection

```nim
if event.type == "mouse" and event.action == "press":
  if event.button == "left":
    var hasCtrl = false
    var i = 0
    while i < len(event.mods):
      if event.mods[i] == "ctrl":
        hasCtrl = true
      i = i + 1
    
    if hasCtrl:
      multiSelect(mouseX, mouseY)
    else:
      singleSelect(mouseX, mouseY)
```

#### Pattern: Drag and Drop

```nim
# On init
var dragging = false
var dragOffsetX = 0
var dragOffsetY = 0
var objectX = 10
var objectY = 10

# On input
if event.type == "mouse":
  if event.action == "press" and event.button == "left":
    # Check if clicking on object
    if mouseX >= objectX and mouseX < objectX + objectWidth and
       mouseY >= objectY and mouseY < objectY + objectHeight:
      dragging = true
      dragOffsetX = mouseX - objectX
      dragOffsetY = mouseY - objectY
  
  elif event.action == "release" and event.button == "left":
    dragging = false

elif event.type == "mouse_move":
  if dragging:
    objectX = mouseX - dragOffsetX
    objectY = mouseY - dragOffsetY
```

#### Pattern: Mouse Wheel Zoom

```nim
# On init
var zoom = 1.0

# On input
if event.type == "mouse":
  if event.button == "scroll_up":
    zoom = zoom * 1.1
    if zoom > 3.0:
      zoom = 3.0
  elif event.button == "scroll_down":
    zoom = zoom * 0.9
    if zoom < 0.5:
      zoom = 0.5
```

### Real-World Example from events.md

Here's a complete, working example from the events demo showing best practices:

```nim
# === INITIALIZATION ===
var shiftQDetected = false
var ctrlMouseDetected = false
var mouseWheelDir = "none"

# === INPUT HANDLER ===
if event.type == "text":
  # Shift+Q detection (uppercase Q implies Shift)
  if event.text == "Q":
    shiftQDetected = true
  return true

elif event.type == "key":
  # Arrow keys and special keys
  if event.keyCode == 27:  # KEY_ESCAPE
    return false  # Exit
  
  if event.action == "press":
    if event.keyCode == 1000:  # KEY_UP
      moveUp()
    elif event.keyCode == 1001:  # KEY_DOWN
      moveDown()
  
  return true

elif event.type == "mouse":
  if event.action == "press":
    # CTRL + Mouse click detection
    var ctrlHeld = false
    var j = 0
    while j < len(event.mods):
      if event.mods[j] == "ctrl":
        ctrlHeld = true
      j = j + 1
    if ctrlHeld:
      ctrlMouseDetected = true
    
    # Handle button clicks
    if event.button == "left":
      handleLeftClick(mouseX, mouseY)
    elif event.button == "right":
      handleRightClick(mouseX, mouseY)
  
  # Mouse wheel
  if event.button == "scroll_up":
    mouseWheelDir = "up"
  elif event.button == "scroll_down":
    mouseWheelDir = "down"
  
  return true

return true
```

### Key Takeaways for AI Assistants

When generating tStorie markdown input handling code:

1. **Always use `event.type == "text"` for letters, numbers, and symbols**
2. **Always use `event.type == "key"` for arrow keys, ESC, Enter, etc.**
3. **Never check `event.keyCode` for printable characters**
4. **Always read modifiers from `event.mods` array, never use global variables**
5. **Remember: Uppercase letters imply Shift was pressed**
6. **Use `event.action` to distinguish "press", "release", and "repeat"**
7. **Mouse events use `event.button` and `event.action`**
8. **Return `true` from `on:input` to mark an event as handled/consumed (stops further processing)**
9. **Return `false` to allow the event to pass through to default handlers (like Q/ESC for quit)**
10. **Use `mouseX` and `mouseY` global variables for cursor position**
11. **Check working examples in [docs/demos/events.md](docs/demos/events.md)**

## Backend Details

### Terminal Backend

**File**: `src/input/terminput.nim`

**Parsing Strategy**:
- Reads raw bytes from stdin
- State machine for ANSI/CSI escape sequences
- UTF-8 multi-byte character assembly
- Mouse tracking via CSI sequences (`\e[<b;x;yM/m`)

**Special Features**:
- Escape timeout: Detects standalone ESC key vs. escape sequences
- Mouse tracking disable/re-enable: Prevents stale mouse events
- Resize detection: Responds to terminal window changes

**Event Generation**:
- Special keys → `KeyEvent`
- Printable characters → `TextEvent`
- Mouse actions → `MouseEvent` / `MouseMoveEvent`
- Window resize → `ResizeEvent`

### WASM Backend

**File**: `src/input/wasminput.nim`

**Event Sources**:
- JavaScript `keydown`/`keyup` events → `KeyEvent` + `TextEvent`
- JavaScript `mousedown`/`mouseup` events → `MouseEvent`
- JavaScript `mousemove` events → `MouseMoveEvent`
- JavaScript `resize` events → `ResizeEvent`

**Normalization**:
- Raw events are passed to `normalizeEvents()` before user code sees them
- This removes duplicate `KeyEvent` instances for printable characters
- Called in `src/runtime_api.nim` at 3 locations before `encodeInputEvent()`

**Implementation**:
- `pollInput()` returns empty array (events arrive via callbacks)
- Actual event handling in `runtime_api.nim` via Emscripten callbacks:
  - `emscripten_set_keydown_callback_on_thread`
  - `emscripten_set_mousedown_callback_on_thread`
  - etc.

### SDL3 Backend

**File**: `src/input/sdl3input.nim`

**Polling Strategy**:
- Uses SDL_PollEvent() to get native SDL events
- Converts SDL scancodes to unified KeyCode values
- Extracts modifiers via SDL_GetModState() for all event types

**Key Mapping**:
- SDL scancodes 4-29 (A-Z) → ASCII 65-90
- SDL scancodes 30-39 (1-0) → ASCII 49-57, 48
- Special keys (arrows, function keys) → KEY_* constants (1000+)

**Character Handling**:
- Letters default to lowercase (a-z) unless shift is pressed
- Shift modifier converts to uppercase (A-Z)
- Shift+numbers produce symbols: 1→!, 2→@, 3→#, 4→$, 5→%, 6→^, 7→&, 8→*, 9→(, 0→)
- Implemented via `applyShiftToChar()` helper function

**Modifier Detection**:
- SDL_GetModState() returns uint16 with modifier flags
- Converted to set[uint8] via `sdlModsToSet()`: 0=Shift, 1=Alt, 2=Ctrl, 3=Super
- Modifiers attached to all event types (keyboard, mouse, wheel)

**Event Generation**:
- Printable keys → `TextEvent` (with proper case/symbols) + `KeyEvent` (filtered by normalization)
- Special keys → `KeyEvent` only
- Mouse actions → `MouseEvent` with modifiers
- Mouse motion → `MouseMoveEvent` with modifiers  
- Mouse wheel → `MouseEvent` (ScrollUp/ScrollDown) with modifiers
- Window resize → `ResizeEvent`

**Build**: Use `./build-modular.sh` to compile with SDL3 backend

## Adding a New Backend (Example)

To add a hypothetical new backend (e.g., SDL2):

### 1. Create Backend Module

Create `src/input/sdlinput.nim`:

```nim
import types
export types

type
  SDL3InputHandler* = object
    # SDL-specific state

proc newSDL3InputHandler*(): SDL3InputHandler =
  result = SDL3InputHandler()

proc pollInput*(handler: var SDL3InputHandler): seq[InputEvent] =
  result = @[]
  
  # Poll SDL3 events
  var sdlEvent: SDL_Event
  while SDL_PollEvent(addr sdlEvent) != 0:
    case sdlEvent.type
    of SDL_EVENT_KEY_DOWN:
      # Convert SDL key to InputEvent
      let keyCode = sdlKeyToKeyCode(sdlEvent.key.keysym.sym)
      if isPrintableKey(keyCode):
        # Generate TextEvent for printable keys
        result.add(InputEvent(
          kind: TextInput,
          text: $char(keyCode),
          textMods: sdlModsToModSet(sdlEvent.key.keysym.mod)
        ))
      else:
        # Generate KeyEvent for special keys
        result.add(InputEvent(
          kind: KeyPress,
          keyCode: keyCode,
          mods: sdlModsToModSet(sdlEvent.key.keysym.mod)
        ))
    
    of SDL_EVENT_MOUSE_BUTTON_DOWN:
      # Convert SDL mouse button to InputEvent
      result.add(InputEvent(
        kind: MouseClick,
        button: int(sdlEvent.button.button),
        mouseX: int(sdlEvent.button.x),
        mouseY: int(sdlEvent.button.y),
        isPress: true,
        clickMods: sdlModsToModSet(SDL_GetModState())
      ))
    
    # ... handle other SDL events
  
  # Apply normalization to match other backends
  result = normalizeEvents(result)
```

### 2. Update Facade

Edit `src/input.nim`:

```nim
when defined(emscripten):
  import input/wasminput
  export wasminput
  type InputParser* = WasmInputHandler
  proc newInputParser*(): InputParser = newWasmInputHandler()
  
elif defined(sdl3Backend):
  import input/sdlinput  # Add this
  export sdlinput
  type InputParser* = SDL3InputHandler
  proc newInputParser*(): InputParser = newSDL3InputHandler()
  
else:
  import input/terminput
  export terminput
  type InputParser* = TerminalInputParser
  proc newInputParser*(): InputParser = newTerminalInputParser()
```

### 3. Test Backend

```bash
# Compile with SDL3 backend
nim c -d:sdl3Backend -d:release tstorie.nim

# Test events demo
./ts events
```

### 4. Ensure Normalization

**Critical**: Always call `normalizeEvents()` on the raw event sequence before returning from `pollInput()`. This ensures consistent behavior across all backends.

## Migration Guide

### From Old API (Pre-Refactoring)

**Old Code**:
```nim
import input  # Was monolithic terminal-only module

var parser = newTerminalInputParser()
let events = parser.pollInput()
```

**New Code**:
```nim
import input  # Now a facade

var parser = newInputParser()  # Backend selected at compile time
let events = parser.pollInput()
```

### Event Detection Changes

**Old Code** (WASM-specific workaround):
```nim
# Had to check both KeyEvent AND TextEvent
if (event.kind == KeyPress and event.keyCode == KEY_Q) or
   (event.kind == TextInput and event.text == "Q"):
  quit = true
```

**New Code** (Works on all backends):
```nim
# Just check TextEvent
if event.kind == TextInput and (event.text == "q" or event.text == "Q"):
  quit = true
```

### Modifier Detection

**Old Code** (Global state):
```nim
var shiftPressed = false
# ... update shiftPressed somewhere ...
if event.text == "Q" and shiftPressed:
  specialAction()
```

**New Code** (Event-local state):
```nim
if event.kind == TextInput and event.text == "Q":
  if ModShift in event.textMods:
    specialAction()
```

## Testing

### Terminal Testing

```bash
nim c -d:release tstorie.nim
./ts events
# Press Q, Shift+Q, CTRL+Click, arrow keys, etc.
```

### WASM Testing

```bash
./build-web.sh
cd docs && python3 -m http.server 8000
# Open http://localhost:8000
# Test events demo in browser
```

### SDL3 Testing

```bash
./build-web-sdl3-modular.sh
cd docs && python3 -m http.server 8000
# Open http://localhost:8000/index-modular.html
# Test events demo - verify modifiers, lowercase, shift+symbols
```

### Automated Testing

Consider adding unit tests:

```nim
import unittest
import input/types

suite "Event Normalization":
  test "removes duplicate KeyEvent for printable chars":
    let raw = @[
      InputEvent(kind: KeyPress, keyCode: 81, mods: {}),
      InputEvent(kind: TextInput, text: "Q", textMods: {})
    ]
    let normalized = normalizeEvents(raw)
    check normalized.len == 1
    check normalized[0].kind == TextInput
    check normalized[0].text == "Q"
  
  test "preserves KeyEvent for special keys":
    let raw = @[
      InputEvent(kind: KeyPress, keyCode: KEY_ESCAPE, mods: {})
    ]
    let normalized = normalizeEvents(raw)
    check normalized.len == 1
    check normalized[0].kind == KeyEvent
    check normalized[0].keyCode == KEY_ESCAPE.int
```

## Quick Reference: Key Code Values

For use in tStorie scripts when checking `event.keyCode`:

### Control Keys
| Constant | Value | Key |
|----------|-------|-----|
| KEY_BACKSPACE | 8 | Backspace |
| KEY_TAB | 9 | Tab |
| KEY_RETURN / KEY_ENTER | 13 | Enter/Return |
| KEY_ESCAPE / KEY_ESC | 27 | Escape |
| KEY_SPACE | 32 | Space |
| KEY_DELETE | 127 | Delete |

### Arrow & Navigation Keys (1000+)
| Constant | Value | Key |
|----------|-------|-----|
| KEY_UP | 1000 | Arrow Up |
| KEY_DOWN | 1001 | Arrow Down |
| KEY_LEFT | 1002 | Arrow Left |
| KEY_RIGHT | 1003 | Arrow Right |
| KEY_HOME | 1004 | Home |
| KEY_END | 1005 | End |
| KEY_PAGEUP | 1006 | Page Up |
| KEY_PAGEDOWN | 1007 | Page Down |
| KEY_INSERT | 1008 | Insert |

### Function Keys (1100+)
| Constant | Value | Key |
|----------|-------|-----|
| KEY_F1 | 1100 | F1 |
| KEY_F2 | 1101 | F2 |
| KEY_F3 | 1102 | F3 |
| ... | ... | ... |
| KEY_F12 | 1111 | F12 |

### Printable Characters (32-126)
**Note**: These should be handled via `TextEvent` (event.type == "text"), not `KeyEvent`!

| Constant | Value | Character |
|----------|-------|-----------|
| KEY_SPACE | 32 | (space) |
| KEY_0 - KEY_9 | 48-57 | 0-9 |
| KEY_A - KEY_Z | 65-90 | A-Z (uppercase) |
| KEY_PLUS, KEY_MINUS, etc. | 43, 45, ... | Various symbols |

## Troubleshooting

### Q: Arrow keys don't work in WASM build

**A**: The pure WASM build (not SDL3-WASM) receives JavaScript keyCodes which use different values for special keys. The system now automatically normalizes these via `normalizeJSKeyCode()` in tstorie.nim:
- JavaScript arrow keys (37-40) → Unified codes (1000-1003)
- JavaScript function keys (112-123) → Unified codes (1100-1111)
- Other special keys are also mapped

If you're still experiencing issues, check that you're using a recent build where this normalization is implemented.

### Q: Events not detected in WASM

**A**: Ensure `normalizeEvents()` is called in `runtime_api.nim` before encoding events. Check that JavaScript callbacks are properly registered.

### Q: Duplicate events in one backend

**A**: Verify `normalizeEvents()` is called in the backend's `pollInput()`. Check that backend isn't generating redundant events.

### Q: Modifiers not detected

**A**: Use event-specific modifier fields (`event.mods`, `event.textMods`, `event.clickMods`), not global variables.

### Q: Compilation error "undeclared identifier"

**A**: Make sure to import `input` module, not `input/terminput` or other backend modules directly. The facade handles backend selection.

### Q: Character detection doesn't work

**A**: Use `TextEvent` for printable characters (letters, numbers, symbols). Use `KeyEvent` only for special keys (arrows, escape, function keys).

## Performance Considerations

- **Zero Overhead**: Backend selection happens at compile time via `when defined()`, so there's no runtime cost
- **Normalization**: O(n) scan of event sequence, typically very small (< 10 events per frame)
- **Memory**: Event sequences are allocated per frame, but typically small (< 1KB)
- **Terminal Parsing**: State machine is optimized for streaming input with minimal allocations

## Future Enhancements

### Planned Features

1. **Gamepad Support**: Button, axis, and vibration APIs (can be added to SDL3 backend)
2. **Touch Events**: Multi-touch support for mobile/tablet
3. **IME Support**: Input Method Editor for complex scripts (Chinese, Japanese, Korean)
4. **Gesture Recognition**: Swipe, pinch, rotate detection
5. **Backend-specific optimizations**: Per-platform performance tuning

### Extension Points

The architecture supports:
- Custom event types (extend `InputEventKind` enum)
- Backend-specific features (via backend module exports)
- Event filtering/transformation pipelines
- Event recording/playback for testing

## References

- **Event Types**: [src/input/types.nim](src/input/types.nim)
- **Terminal Backend**: [src/input/terminput.nim](src/input/terminput.nim)
- **WASM Backend**: [src/input/wasminput.nim](src/input/wasminput.nim)
- **SDL3 Backend**: [src/input/sdl3input.nim](src/input/sdl3input.nim)
- **Facade**: [src/input.nim](src/input.nim)
- **Demo**: [docs/md/events.md](docs/md/events.md)
- **Runtime Integration**: [src/runtime_api.nim](src/runtime_api.nim)
- **SDL3 Bindings**: [backends/sdl3/bindings/events.nim](backends/sdl3/bindings/events.nim)

## License

This input system is part of tStorie and follows the same license as the main project.
