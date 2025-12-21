# Transitions Working Demo

Simple transition demo using the registered Nimini API.

Press ESC to exit.

```nim on:init
var engine = nimini_newTransitionEngine()
var initialized = false  
```

```nim on:render
if not initialized:
  # Create two buffers
  var b1 = nimini_newBufferSnapshot(termWidth, termHeight)
  var b2 = nimini_newBufferSnapshot(termWidth, termHeight)
  
  # Create a fade effect and start transition
  var effect = nimini_fadeEffect(2.0, EASE_IN_OUT_QUAD)
  nimini_startTransition(engine, b1, b2, effect)
  
  initialized = true

state.currentBuffer.clear()

# Show status
var titleStyle = defaultStyle()
titleStyle.fg = white()
titleStyle.bold = true

if nimini_hasActiveTransitions(engine):
  state.currentBuffer.writeText(5, 5, "Transition in progress...", titleStyle)
else:
  state.currentBuffer.writeText(5, 5, "Transition complete!", titleStyle)
```

```nim on:update
if initialized:
  nimini_updateTransitions(engine, deltaTime)
```

```nim on:input
# ESC to quit is handled automatically by the engine
```