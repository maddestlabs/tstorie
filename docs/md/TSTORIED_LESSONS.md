# TStoried Standalone: Lessons Learned

## Context
Built tstoried as a **standalone terminal editor** to avoid touching tstorie.nim while identifying refactoring needs.

## What We Learned

### 1. **Terminal Primitives Needed**
The minimal terminal editor requires:
```nim
# Terminal setup (from std/terminal)
- hideCursor() / showCursor()
- terminalWidth() / terminalHeight()  
- getch() for input reading
- resetAttributes() for cleanup

# What we DON'T need from tstorie.nim:
- Full Layer/Buffer system (overkill for simple editing)
- Canvas navigation
- Section management
- Animation system
```

### 2. **Input Handling is Distinct**
tstorie.nim has complex input parsing for game events. Editor needs:
```nim
# Simple character reading
- Read raw char with getch()
- Detect control sequences (Ctrl+Q = '\x11')
- Handle escape sequences for arrow keys
- No need for mouse events or complex event types
```

**Refactoring insight**: tstorie.nim's input system could be extracted to `lib/input.nim` as reusable primitives.

### 3. **Rendering is Different**
tstorie.nim uses Layer buffers and compositing. Editor uses:
```nim
# Direct terminal output
- ANSI escape codes ("\e[2J\e[H" for clear)
- Direct cursor positioning ("\e[row;colH")
- Simple color codes ("\e[1;35m")
- No layer compositing needed
```

**Refactoring insight**: tstorie.nim's rendering could split into:
- `lib/term_buffer.nim` - Low-level ANSI/buffering
- `lib/layer_system.nim` - High-level compositing
- `lib/canvas.nim` - Game-specific camera/sections

### 4. **State Management Patterns**
Editor uses simple flat struct:
```nim
type EditorApp = object
  lines: seq[string]      # Document state
  cursor: (row, col)      # Position
  scroll: int             # Viewport
  filename: string        # File tracking
  mode: EditorMode        # UI state
```

tstorie.nim has more complex state scattered across:
- Global variables (currentSection, etc.)
- Canvas state
- Animation state  
- Section manager state

**Refactoring insight**: Game state should be centralized in a `GameApp` object similar to `EditorApp`.

### 5. **Module Dependencies Revealed**
Building standalone forced us to see what's truly reusable:

**Already Good** (lib/ modules):
- ✅ `lib/storie_types.nim` - Core types work independently
- ✅ `lib/storie_themes.nim` - Theme system is self-contained
- ✅ `lib/gist_api.nim` - API wrapper has no tstorie deps

**Needs Extraction** (currently in tstorie.nim):
- 🔨 Terminal initialization/cleanup
- 🔨 Input reading/parsing  
- 🔨 ANSI code generation
- 🔨 Basic Layer/Buffer types (not full system)

**Should Stay in tstorie.nim** (game-specific):
- ✅ includeUserFile macro
- ✅ Main game loop
- ✅ Section navigation logic
- ✅ Camera panning
- ✅ Animation timing

### 6. **The Widget System Gap**
Created `lib/tui_editor.nim` with TextBox/ListView but they depend on types from tstorie.nim.

**Refactoring insight**: Widget system needs its own foundation:
```
lib/tui_base.nim      # Basic Widget, Style, InputEvent types
lib/tui_widgets.nim   # TextBox, ListView, Label, etc.
lib/tui_manager.nim   # WidgetManager, focus handling
```

These can be used by BOTH tstoried and tstorie.nim.

## Recommended Refactoring Plan

### Phase 1: Extract Terminal Primitives
Move from tstorie.nim to `lib/terminal.nim`:
```nim
proc initTerminal*()
proc shutdownTerminal*()
proc getTerminalSize*(): (int, int)
proc readChar*(): char
proc writeAnsi*(code: string)
proc hideCursor*()
proc showCursor*()
```

### Phase 2: Extract Core Types  
Move from tstorie.nim to `lib/core_types.nim`:
```nim
type
  Color*
  Style*
  Layer*
  TermBuffer*
```

### Phase 3: Reorganize TUI System
```
lib/tui_base.nim      # Widget base, InputEvent, basic types
lib/tui_widgets.nim   # Concrete widget implementations  
lib/tui_manager.nim   # WidgetManager, focus, state
```

### Phase 4: Update tstorie.nim
```nim
import lib/[terminal, core_types, tui_base]
# Keep game-specific logic:
# - includeUserFile macro
# - Section management
# - Canvas/camera system
# - Main loop
```

### Phase 5: Update tstoried.nim
```nim
import lib/[terminal, core_types, tui_base, tui_widgets, tui_manager]
# Pure editor logic, no tstorie.nim dependency
```

## What Tstoried Accomplished

1. **Proved minimal editor is viable** - 463 lines, compiles in 5.7s, 236KB binary
2. **Identified exactly what's core vs. game-specific**
3. **Created reference for "how simple can it be"**
4. **No tstorie.nim dependency achieved** - proves refactor path exists
5. **Highlighted gaps** - Widget system, terminal primitives, type organization

## Next Steps

### For tstoried (Short Term):
- [ ] Add arrow key support (currently only j/k in browser)
- [ ] Implement Ctrl+S for save as (with filename prompt)
- [ ] Add syntax highlighting hooks
- [ ] Test gist create/load/update flow

### For tstorie.nim (Medium Term):
- [ ] Extract `lib/terminal.nim` with primitives
- [ ] Extract `lib/core_types.nim` with Color/Style/Layer
- [ ] Reorganize TUI system into tui_base/widgets/manager
- [ ] Update tstorie.nim to import extracted modules
- [ ] Update index.nim to match new structure

### For Both (Long Term):
- [ ] Shared widget library both can use
- [ ] Unified theme system
- [ ] Live preview integration (tstoried renders using tstorie canvas)
- [ ] Plugin system for custom widgets

## Key Insight

**Building tstoried standalone didn't just avoid refactoring tstorie.nim - it created the blueprint FOR that refactoring.**

Every time we had to "work around" something in tstorie.nim, we discovered:
1. What should be extracted
2. What should stay game-specific  
3. What the API boundaries should be

This is architectural discovery through implementation, not theory.
