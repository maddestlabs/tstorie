# Transitions Demo

Demonstrates the transition system with various effects.

Press keys to see different transitions:
- `1` = Fade transition
- `2` = Slide Left
- `3` = Slide Right
- `4` = Wipe Left
- `5` = Wipe Center
- `6` = Dissolve
- `7` = Push Left
- `Space` = Cycle through demos automatically
- `ESC` = Exit

```nim on:init
var transEngine = newTransitionEngine()
var currentDemo = 0
var autoMode = false
var lastTransTime = 0.0
var initialized = false
```

```nim on:render
if not initialized:
  # Initialize buffers on first render
  var currentBuffer = newBufferSnapshot(state.termWidth, state.termHeight)
  var nextBuffer = newBufferSnapshot(state.termWidth, state.termHeight)
  
  # Fill current buffer with pattern A
  for y in 0 ..< currentBuffer.height:
    for x in 0 ..< currentBuffer.width:
      let style = Style(
        fg: rgb(100, 150, 255),
        bg: black(),
        bold: false, underline: false, italic: false, dim: false
      )
      let ch = if (x + y) mod 2 == 0: "▓" else: "░"
      currentBuffer.setCell(x, y, ch, style)
  
  # Fill next buffer with pattern B
  for y in 0 ..< nextBuffer.height:
    for x in 0 ..< nextBuffer.width:
      let style = Style(
        fg: rgb(255, 150, 100),
        bg: black(),
        bold: false, underline: false, italic: false, dim: false
      )
      let ch = if (x div 3 + y div 2) mod 2 == 0: "█" else: " "
      nextBuffer.setCell(x, y, ch, style)
  
  initialized = true

state.currentBuffer.clear()

if transEngine.hasActiveTransitions():
  # Get transition buffer and render it
  let transBuffer = transEngine.getTransitionBuffer()
  for y in 0 ..< min(transBuffer.height, state.termHeight):
    for x in 0 ..< min(transBuffer.width, state.termWidth):
      let cell = transBuffer.getCell(x, y)
      state.currentBuffer.write(x, y, cell.ch, cell.style)
else:
  # Render current buffer
  for y in 0 ..< min(currentBuffer.height, state.termHeight):
    for x in 0 ..< min(currentBuffer.width, state.termWidth):
      let cell = currentBuffer.getCell(x, y)
      state.currentBuffer.write(x, y, cell.ch, cell.style)

# Draw UI
let titleStyle = Style(fg: white(), bg: black(), bold: true, 
                       underline: false, italic: false, dim: false)
let normalStyle = Style(fg: rgb(200, 200, 200), bg: black(), bold: false,
                        underline: false, italic: false, dim: false)

state.currentBuffer.writeText(2, 2, "=== TRANSITION DEMO ===", titleStyle)
state.currentBuffer.writeText(2, 4, "Current effect index: " & $currentDemo, normalStyle)

if transEngine.hasActiveTransitions():
  state.currentBuffer.writeText(2, 5, "Transition in progress...", normalStyle)
else:
  state.currentBuffer.writeText(2, 5, "Press 1-7 for effects, SPACE for auto", normalStyle)

# Show keybindings
let y = state.termHeight - 10
state.currentBuffer.writeText(2, y, "Keybindings:", titleStyle)
state.currentBuffer.writeText(2, y + 1, "1 = Fade", normalStyle)
state.currentBuffer.writeText(2, y + 2, "2 = Slide Left", normalStyle)
state.currentBuffer.writeText(2, y + 3, "3 = Slide Right", normalStyle)
state.currentBuffer.writeText(2, y + 4, "4 = Wipe Left", normalStyle)
state.currentBuffer.writeText(2, y + 5, "5 = Wipe Center", normalStyle)
state.currentBuffer.writeText(2, y + 6, "6 = Dissolve", normalStyle)
state.currentBuffer.writeText(2, y + 7, "7 = Push Left", normalStyle)
state.currentBuffer.writeText(2, y + 8, "SPACE = Auto cycle", normalStyle)
```

```nim on:update
if not initialized:
  discard

# Update transitions
transEngine.update(deltaTime)

# Auto mode
if autoMode:
  lastTransTime += deltaTime
  if lastTransTime >= 2.0 and not transEngine.hasActiveTransitions():
    currentDemo = (currentDemo + 1) mod 7
    
    # Start next transition
    let effect = case currentDemo
      of 0: fadeEffect(1.0, easeInOutQuad)
      of 1: slideEffect(0.8, tdLeft, easeInOutCubic)
      of 2: slideEffect(0.8, tdRight, easeInOutCubic)
      of 3: wipeEffect(0.7, tdLeft, easeLinear)
      of 4: wipeEffect(1.0, tdCenter, easeInOutQuad)
      of 5: dissolveEffect(1.2, 2, easeInOutQuad)
      of 6: pushEffect(0.8, tdLeft, easeInOutCubic)
      else: fadeEffect(1.0, easeInOutQuad)
    
    discard transEngine.startTransition(currentBuffer, nextBuffer, effect)
    
    # Swap buffers
    let temp = currentBuffer
    currentBuffer = nextBuffer
    nextBuffer = temp
    
    lastTransTime = 0.0
```

```nim on:input
# Handle input (ESC to quit is handled automatically by engine)
if event.type == "key" and event.action == "press":
  if event.keyCode == 32:  # SPACE key
    autoMode = not autoMode
    lastTransTime = 0.0
  elif event.keyCode >= 49 and event.keyCode <= 55:  # Keys 1-7
    let idx = event.keyCode - 49
    if not transEngine.hasActiveTransitions():
      # Start transition
      currentDemo = idx
        
        let effect = case idx
          of 0: fadeEffect(1.0, easeInOutQuad)
          of 1: slideEffect(0.8, tdLeft, easeInOutCubic)
          of 2: slideEffect(0.8, tdRight, easeInOutCubic)
          of 3: wipeEffect(0.7, tdLeft, easeLinear)
          of 4: wipeEffect(1.0, tdCenter, easeInOutQuad)
          of 5: dissolveEffect(1.2, 2, easeInOutQuad)
          of 6: pushEffect(0.8, tdLeft, easeInOutCubic)
          else: fadeEffect(1.0, easeInOutQuad)
        
        discard transEngine.startTransition(currentBuffer, nextBuffer, effect)
        
        # Swap buffers for next transition
        let temp = currentBuffer
        currentBuffer = nextBuffer
        nextBuffer = temp
        
        autoMode = false
```
