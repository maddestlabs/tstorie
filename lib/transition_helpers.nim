## Transition Integration Helpers
##
## Helper functions for integrating the transitions module with TStorie's
## rendering system. These bridge the gap between TermBuffer and BufferSnapshot.

import transitions

# Forward declare types we expect from tstorie.nim
# These will be available when this module is included
type
  TermBuffer* = object
    width*, height*: int
    cells*: seq[tuple[ch: string, style: Style]]
    clipX*, clipY*, clipW*, clipH*: int
    offsetX*, offsetY*: int

# ================================================================
# BUFFER CAPTURE HELPERS
# ================================================================

proc captureTermBuffer*(tb: TermBuffer): BufferSnapshot =
  ## Capture a TermBuffer as a BufferSnapshot for transitions
  result = newBufferSnapshot(tb.width, tb.height)
  
  # Copy all cells
  for i in 0 ..< min(tb.cells.len, result.cells.len):
    result.cells[i] = tb.cells[i]

proc captureTermBufferRegion*(
  tb: TermBuffer,
  x, y, width, height: int
): BufferSnapshot =
  ## Capture a specific region of a TermBuffer
  result = newBufferSnapshot(width, height)
  
  for dy in 0 ..< height:
    for dx in 0 ..< width:
      let srcX = x + dx
      let srcY = y + dy
      if srcX >= 0 and srcX < tb.width and srcY >= 0 and srcY < tb.height:
        let idx = srcY * tb.width + srcX
        if idx >= 0 and idx < tb.cells.len:
          result.setCell(dx, dy, tb.cells[idx].ch, tb.cells[idx].style)

# ================================================================
# BUFFER RENDERING HELPERS
# ================================================================

proc renderSnapshotToBuffer*(
  snapshot: BufferSnapshot,
  tb: var TermBuffer,
  offsetX: int = 0,
  offsetY: int = 0
) =
  ## Render a BufferSnapshot to a TermBuffer
  for y in 0 ..< snapshot.height:
    for x in 0 ..< snapshot.width:
      let destX = x + offsetX
      let destY = y + offsetY
      
      if destX >= 0 and destX < tb.width and destY >= 0 and destY < tb.height:
        let cell = snapshot.getCell(x, y)
        let idx = destY * tb.width + destX
        if idx >= 0 and idx < tb.cells.len:
          tb.cells[idx] = (cell.ch, cell.style)

# ================================================================
# HIGH-LEVEL TRANSITION HELPERS
# ================================================================

proc transitionBuffers*(
  engine: TransitionEngine,
  fromBuffer, toBuffer: var TermBuffer,
  effect: TransitionEffect
): Transition {.discardable.} =
  ## Convenience function to transition between two TermBuffers
  let beforeSnap = captureTermBuffer(fromBuffer)
  let afterSnap = captureTermBuffer(toBuffer)
  result = engine.startTransition(beforeSnap, afterSnap, effect)

proc applyActiveTransition*(
  engine: TransitionEngine,
  targetBuffer: var TermBuffer
) =
  ## Apply the current transition state to a target buffer
  if engine.hasActiveTransitions():
    let transSnap = engine.getTransitionBuffer()
    renderSnapshotToBuffer(transSnap, targetBuffer)

# ================================================================
# REGIONAL TRANSITION HELPERS
# ================================================================

proc transitionRegion*(
  engine: TransitionEngine,
  buffer: var TermBuffer,
  x, y, width, height: int,
  beforeCells, afterCells: seq[tuple[ch: string, style: Style]],
  effect: TransitionEffect
): Transition {.discardable.} =
  ## Transition a specific region of a buffer
  let beforeSnap = captureFromCells(beforeCells, width, height)
  let afterSnap = captureFromCells(afterCells, width, height)
  
  let regionalEffect = regionalEffect(effect, x, y, width, height)
  result = engine.startTransition(beforeSnap, afterSnap, regionalEffect)

# ================================================================
# EXAMPLE USAGE PATTERNS
# ================================================================

## Example 1: Simple full-screen transition
## ```nim
## var transEngine = newTransitionEngine()
## 
## # Capture before state
## let beforeSnap = captureTermBuffer(state.currentBuffer)
## 
## # Render new content
## renderNewFrame(state)
## 
## # Capture after state
## let afterSnap = captureTermBuffer(state.currentBuffer)
## 
## # Start transition
## transEngine.startTransition(beforeSnap, afterSnap, fadeEffect(0.5))
## 
## # In main loop:
## transEngine.update(deltaTime)
## if transEngine.hasActiveTransitions():
##   let transSnap = transEngine.getTransitionBuffer()
##   renderSnapshotToBuffer(transSnap, state.currentBuffer)
## ```

## Example 2: Regional transition (panel update)
## ```nim
## let panelX = 10
## let panelY = 5
## let panelW = 40
## let panelH = 15
## 
## # Capture panel before
## let beforeSnap = captureTermBufferRegion(
##   state.currentBuffer, panelX, panelY, panelW, panelH
## )
## 
## # Update panel content
## renderPanel(state, panelX, panelY, panelW, panelH)
## 
## # Capture panel after
## let afterSnap = captureTermBufferRegion(
##   state.currentBuffer, panelX, panelY, panelW, panelH
## )
## 
## # Transition just the panel
## let effect = regionalEffect(
##   fadeEffect(0.3),
##   panelX, panelY, panelW, panelH
## )
## transEngine.startTransition(beforeSnap, afterSnap, effect)
## ```

## Example 3: Using convenience functions
## ```nim
## # Before state captured automatically
## let beforeBuf = state.currentBuffer
## 
## # Make changes
## renderNewContent(state)
## 
## # Transition using helper
## transitionBuffers(
##   transEngine,
##   beforeBuf,
##   state.currentBuffer,
##   slideEffect(0.5, tdLeft)
## )
## 
## # In main loop:
## transEngine.update(deltaTime)
## applyActiveTransition(transEngine, state.currentBuffer)
## ```
