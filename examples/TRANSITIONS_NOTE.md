# Transitions System - Usage Note

## Current Status

The transitions system (**lib/transitions.nim**) is fully implemented and functional, but it's designed for **native compilation** rather than runtime Nimini execution.

##Why?

The transitions module:
- Uses complex Nim features (generic types, closures, advanced proc types)
- Requires direct buffer manipulation
- Works best when compiled into the binary

Nimini (the embedded scripting engine) has limitations that make it unsuitable for the full transitions system.

## How to Use Transitions

### For Native Applications

When building native terminal applications with TStorie:

```nim
# In your main .nim file (not .md)
import tstorie
import lib/transitions

var transEngine = newTransitionEngine()

# ... rest of your application
```

Then compile:
```bash
nim c -d:release myapp.nim
```

### For TUI Library (Coming Soon)

The TUI widget library will have transitions built-in and work seamlessly:

```nim on:render
# This will work once TUI is implemented
let button = newButton("Click Me", fadeTransition(0.3))
button.show()  # Automatically transitions in
```

## Demonstrations

Since the transitions system requires native compilation, demonstration examples will be added as standalone `.nim` files rather than `.md` files.

### Example: Simple Fade Transition

Create `transition_test.nim`:

```nim
import tstorie
import lib/transitions

# Your application code here
var transEngine = newTransitionEngine()

proc captureCurrentState(): BufferSnapshot =
  result = newBufferSnapshot(state.termWidth, state.termHeight)
  for y in 0 ..< state.termHeight:
    for x in 0 ..< state.termWidth:
      # Capture cells from current buffer
      discard

# In your render loop:
if keyPressed('1'):
  let before = captureCurrentState()
  # ... change something ...
  let after = captureCurrentState()
  transEngine.startTransition(before, after, fadeEffect(0.5))

transEngine.update(deltaTime)
if transEngine.hasActiveTransitions():
  let buf = transEngine.getTransitionBuffer()
  # render buf
```

## Integration Points

The transitions system is designed to integrate with:

1. **Section Manager** (via `lib/section_transitions.nim` - to be created)
2. **Canvas System** (via `lib/canvas_transitions.nim` - to be created)  
3. **TUI Widgets** (via `lib/ui.nim` - to be created)

These integration layers will make transitions available in more convenient ways.

## Technical Details

For full documentation, see:
- [TRANSITIONS.md](../docs/TRANSITIONS.md) - Complete guide
- [TRANSITIONS_QUICK_REF.md](../docs/TRANSITIONS_QUICK_REF.md) - Quick reference
- [TUI_ROADMAP.md](../docs/TUI_ROADMAP.md) - Future integration plans

## Next Steps

1. **TUI Library Development** - Build widget system with built-in transition support
2. **Integration Layers** - Create optional bridges for sections/canvas
3. **Native Examples** - Add `.nim` example files demonstrating transitions
4. **WASM Support** - Explore making transitions work in web builds

The core foundation is solid and ready for native use. The focus now shifts to building the TUI layer on top of it.
