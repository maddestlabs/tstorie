# Transitions Simple Demo

Minimal transitions demo. Press 1-3 for different effects, ESC to exit.

```nim on:init
var transEngine = newTransitionEngine()
var initialized = false  
var currentDemo = 0
```

```nim on:render
if not initialized:
  # Initialize two buffers
  var buffer1 = newBufferSnapshot(state.termWidth, state.termHeight)
  var buffer2 = newBufferSnapshot(state.termWidth, state.termHeight)
  
  # Fill buffer1 with pattern A
  for y in 0 ..< buffer1.height:
    for x in 0 ..< buffer1.width:
      var s1 = defaultStyle()
      s1.fg = rgb(100, 150, 255)
      buffer1.setCell(x, y, "A", s1)
  
  # Fill buffer2 with pattern B  
  for y in 0 ..< buffer2.height:
    for x in 0 ..< buffer2.width:
      var s2 = defaultStyle()
      s2.fg = rgb(255, 150, 100)
      buffer2.setCell(x, y, "B", s2)
  
  # Start a fade transition
  var effect = fadeEffect(1.0, easeInOutQuad)
  discard transEngine.startTransition(buffer1, buffer2, effect)
  
  initialized = true

state.currentBuffer.clear()

# Show transition or static buffer
if transEngine.hasActiveTransitions():
  var transBuffer = transEngine.getTransitionBuffer()
  for y in 0 ..< min(transBuffer.height, state.termHeight):
    for x in 0 ..< min(transBuffer.width, state.termWidth):
      var cell = transBuffer.getCell(x, y)
      state.currentBuffer.write(x, y, cell.ch, cell.style)
else:
  var titleStyle = defaultStyle()
  titleStyle.fg = white()
  titleStyle.bold = true
  state.currentBuffer.writeText(2, 2, "Transition complete! Press 1-3 for more", titleStyle)
```

```nim on:update
if not initialized:
  discard

transEngine.update(deltaTime)
```

```nim on:input
# ESC to quit is handled automatically by the engine
    elif event.keyCode == 49:  # Key 1 - restart fade
      var b1 = newBufferSnapshot(state.termWidth, state.termHeight)
      var b2 = newBufferSnapshot(state.termWidth, state.termHeight)
      for y in 0 ..< b1.height:
        for x in 0 ..< b1.width:
          var s1 = defaultStyle()
          s1.fg = rgb(100, 150, 255)
          b1.setCell(x, y, "A", s1)
      for y in 0 ..< b2.height:
        for x in 0 ..< b2.width:
          var s2 = defaultStyle()
          s2.fg = rgb(255, 150, 100)
          b2.setCell(x, y, "B", s2)
      var eff = fadeEffect(1.0, easeInOutQuad)
      discard transEngine.startTransition(b1, b2, eff)
```
