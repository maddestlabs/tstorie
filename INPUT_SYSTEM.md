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
  - Minimal implementation (events arrive via JavaScript callbacks)
  - Event normalization to match terminal behavior
- **Dependencies**: `types`
- **Note**: Actual event handling occurs in `src/runtime_api.nim` via `emscripten_set_*_callback`

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

### InputEvent (Variant Object)

```nim
type
  InputEventKind* = enum
    KeyPress, TextInput, MouseClick, MouseMove, WindowResize
  
  InputEvent* = object
    case kind*: InputEventKind
    of KeyPress:
      keyCode*: int        # KEY_* constant (e.g., KEY_ESCAPE, KEY_UP)
      mods*: set[ModifierKey]
    of TextInput:
      text*: string        # UTF-8 character(s)
      textMods*: set[ModifierKey]  # ✨ NEW: Modifiers work on text events too!
    of MouseClick:
      button*: int         # 1=left, 2=middle, 3=right
      mouseX*, mouseY*: int
      isPress*: bool       # true=press, false=release
      clickMods*: set[ModifierKey]
    of MouseMove:
      moveX*, moveY*: int
    of WindowResize:
      width*, height*: int
```

**Note**: TextInput events now include modifiers (e.g., Alt+A is detected). This allows for consistent modifier detection across both text and special key events.

### Key Constants

```nim
# Special keys (>= 1000)
const
  KEY_ESCAPE* = 27
  KEY_UP* = 1000
  KEY_DOWN* = 1001
  KEY_LEFT* = 1002
  KEY_RIGHT* = 1003
  KEY_BACKSPACE* = 127
  KEY_DELETE* = 1004
  KEY_HOME* = 1005
  KEY_END* = 1006
  KEY_PAGEUP* = 1007
  KEY_PAGEDOWN* = 1008
  KEY_TAB* = 9
  KEY_ENTER* = 13
  # ... and more

# Printable keys (ASCII 32-126)
const
  KEY_SPACE* = 32
  KEY_A* = 65  # Uppercase 'A'
  KEY_Q* = 81  # Uppercase 'Q'
  # ... uppercase letters only
```

**Important**: Lowercase letters do not have KEY_* constants to avoid conflicts. Use `TextEvent` for character detection.

### Modifier Keys

```nim
type
  ModifierKey* = enum
    ModShift, ModAlt, ModCtrl, ModSuper
```

Access via `event.mods`, `event.textMods`, or `event.clickMods` depending on event type.

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
  InputEvent(kind: KeyPress, keyCode: 81, mods: {}),
  InputEvent(kind: TextInput, text: "Q", textMods: {})
]
```

**After Normalization:**
```nim
@[
  InputEvent(kind: TextInput, text: "Q", textMods: {})
]
```

The duplicate `KeyEvent(81)` is removed because a `TextEvent("Q")` exists.

## Usage Guide

### Basic Usage

```nim
import input

var parser = newInputParser()

while running:
  let events = parser.pollInput()
  for event in events:
    case event.kind
    of KeyPress:
      if event.keyCode == KEY_ESCAPE:
        quit = true
      elif event.keyCode == KEY_UP:
        moveUp()
      
    of TextInput:
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
      
    of MouseClick:
      if event.isPress and event.button == 1:
        if ModCtrl in event.clickMods:
          echo "CTRL+Click at ", event.mouseX, ",", event.mouseY
        else:
          handleClick(event.mouseX, event.mouseY)
      
    of MouseMove:
      handleMouseMove(event.moveX, event.moveY)
      
    of WindowResize:
      resizeWindow(event.width, event.height)
```

### Best Practices

#### ✅ DO: Use TextEvent for Character Detection

```nim
# Correct: Works on all backends
if event.kind == TextInput:
  if event.text == "q" or event.text == "Q":
    quit = true
```

#### ❌ DON'T: Use KeyEvent for Printable Characters

```nim
# Incorrect: Inconsistent across backends
if event.kind == KeyPress and event.keyCode == KEY_Q:
  quit = true  # Won't work reliably!
```

#### ✅ DO: Check Modifiers on Event Object

```nim
# Correct: Direct access to modifier set
if event.kind == TextInput and event.text == "Q":
  if ModShift in event.textMods:
    echo "Shift+Q detected!"
```

#### ❌ DON'T: Use Global Modifier Variables

```nim
# Incorrect: Global state may be stale
if shiftPressed and event.text == "Q":
  # Unreliable timing!
```

#### ✅ DO: Use KeyEvent for Special Keys

```nim
# Correct: Special keys always use KeyEvent
if event.kind == KeyPress:
  case event.keyCode
  of KEY_UP: moveUp()
  of KEY_DOWN: moveDown()
  of KEY_ESCAPE: quit = true
  else: discard
```

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
    check normalized[0].kind == KeyPress
    check normalized[0].keyCode == KEY_ESCAPE
```

## Troubleshooting

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
