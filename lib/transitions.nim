## Transitions Library for TStorie
##
## Provides smooth visual transitions between terminal buffer states.
## This module is standalone and has no dependencies on section_manager or canvas.
## It works purely with TermBuffer objects and provides a variety of transition effects.
##
## Features:
## - Multiple transition effects (fade, slide, wipe, dissolve, etc.)
## - Event system for transition lifecycle hooks
## - Regional transitions (transition specific screen areas)
## - Offscreen buffer support
## - Configurable easing functions
## - Extensible effect system
##
## Basic Usage:
##   var engine = newTransitionEngine()
##   let beforeBuffer = captureBuffer(state.currentBuffer)
##   # ... render new content ...
##   let afterBuffer = captureBuffer(state.currentBuffer)
##   engine.startTransition(beforeBuffer, afterBuffer, fadeEffect(0.5))
##   
##   # In main loop:
##   engine.update(deltaTime)
##   if engine.hasActiveTransitions():
##     renderTransition(engine, targetLayer)

import math
import tables
import sequtils

# Note: Color and Style types are imported from parent context (tstorie.nim)
# when this module is included/imported into tstorie environment
# Note: Easing functions are already available from lib/animation.nim

type
  EasingFunction* = proc(t: float): float

# ================================================================
# CORE TYPES
# ================================================================

type
  TransitionDirection* = enum
    tdNone
    tdLeft
    tdRight
    tdUp
    tdDown
    tdCenter
    tdRandom

  TransitionEvent* = enum
    teBeforeStart    ## Before transition begins
    teStart          ## Transition starts
    teProgress       ## Each frame during transition
    teComplete       ## Transition finished
    teCanceled       ## Transition interrupted
    
  TransitionCallback* = proc(trans: Transition, progress: float)
  
  TransitionRegion* = object
    ## Defines a rectangular region for regional transitions
    x*, y*: int
    width*, height*: int
  
  TransitionEffect* = object
    ## Defines a transition effect type and its configuration
    name*: string
    duration*: float
    easing*: EasingFunction
    direction*: TransitionDirection
    region*: TransitionRegion  ## If width/height = 0, use full buffer
    
    # Effect-specific parameters
    params*: Table[string, float]
  
  BufferSnapshot* = object
    ## A captured snapshot of a buffer state
    width*, height*: int
    cells*: seq[tuple[ch: string, style: Style]]
  
  # Note: Style and Color types are imported from tstorie.nim
  
  Transition* = ref object
    ## An active transition between two buffer states
    startBuffer*: BufferSnapshot
    endBuffer*: BufferSnapshot
    effect*: TransitionEffect
    startTime*: float
    elapsed*: float
    progress*: float          # 0.0 to 1.0
    easedProgress*: float     # After applying easing function
    isActive*: bool
    callbacks*: Table[TransitionEvent, seq[TransitionCallback]]
  
  TransitionEngine* = ref object
    ## Manages multiple concurrent transitions
    transitions*: seq[Transition]
    globalCallbacks*: Table[TransitionEvent, seq[TransitionCallback]]

# ================================================================
# COLOR AND STYLE HELPERS
# ================================================================

# Note: rgb() and lerpColor() are available from tstorie.nim and lib/animation.nim

proc lerpStyle*(a, b: Style, t: float): Style =
  ## Linear interpolation between two styles
  Style(
    fg: lerpColor(a.fg, b.fg, t),
    bg: lerpColor(a.bg, b.bg, t),
    bold: if t < 0.5: a.bold else: b.bold,
    underline: if t < 0.5: a.underline else: b.underline,
    italic: if t < 0.5: a.italic else: b.italic,
    dim: if t < 0.5: a.dim else: b.dim
  )

# ================================================================
# BUFFER SNAPSHOT OPERATIONS
# ================================================================

proc newBufferSnapshot*(width, height: int): BufferSnapshot =
  ## Create a new empty buffer snapshot
  result.width = width
  result.height = height
  result.cells = newSeq[tuple[ch: string, style: Style]](width * height)
  let defStyle = Style(fg: white(), bg: black(), bold: false, underline: false, italic: false, dim: false)
  for i in 0 ..< result.cells.len:
    result.cells[i] = (" ", defStyle)

proc captureFromCells*(cells: seq[tuple[ch: string, style: Style]], width, height: int): BufferSnapshot =
  ## Create a snapshot from a cell array
  result.width = width
  result.height = height
  result.cells = cells

proc getCell*(snapshot: BufferSnapshot, x, y: int): tuple[ch: string, style: Style] =
  ## Get a cell from the snapshot
  if x < 0 or x >= snapshot.width or y < 0 or y >= snapshot.height:
    let defStyle = Style(fg: white(), bg: black(), bold: false, underline: false, italic: false, dim: false)
    return (" ", defStyle)
  let idx = y * snapshot.width + x
  if idx >= 0 and idx < snapshot.cells.len:
    return snapshot.cells[idx]
  let defStyle = Style(fg: white(), bg: black(), bold: false, underline: false, italic: false, dim: false)
  return (" ", defStyle)

proc setCell*(snapshot: var BufferSnapshot, x, y: int, ch: string, style: Style) =
  ## Set a cell in the snapshot
  if x < 0 or x >= snapshot.width or y < 0 or y >= snapshot.height:
    return
  let idx = y * snapshot.width + x
  if idx >= 0 and idx < snapshot.cells.len:
    snapshot.cells[idx] = (ch, style)

proc regionSnapshot*(snapshot: BufferSnapshot, region: TransitionRegion): BufferSnapshot =
  ## Extract a regional snapshot
  result = newBufferSnapshot(region.width, region.height)
  for y in 0 ..< region.height:
    for x in 0 ..< region.width:
      let cell = snapshot.getCell(region.x + x, region.y + y)
      result.setCell(x, y, cell.ch, cell.style)

# ================================================================
# TRANSITION EFFECT CONSTRUCTORS
# ================================================================

proc fadeEffect*(duration: float = 0.5, easing: EasingFunction = easeInOutQuad): TransitionEffect =
  ## Fade transition effect
  TransitionEffect(
    name: "fade",
    duration: duration,
    easing: easing,
    direction: tdNone,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: initTable[string, float]()
  )

proc slideEffect*(
  duration: float = 0.5,
  direction: TransitionDirection = tdLeft,
  easing: EasingFunction = easeInOutCubic
): TransitionEffect =
  ## Slide transition effect
  TransitionEffect(
    name: "slide",
    duration: duration,
    easing: easing,
    direction: direction,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: initTable[string, float]()
  )

proc wipeEffect*(
  duration: float = 0.5,
  direction: TransitionDirection = tdLeft,
  easing: EasingFunction = easeLinear
): TransitionEffect =
  ## Wipe transition effect
  TransitionEffect(
    name: "wipe",
    duration: duration,
    easing: easing,
    direction: direction,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: initTable[string, float]()
  )

proc dissolveEffect*(
  duration: float = 0.8,
  blockSize: int = 2,
  easing: EasingFunction = easeInOutQuad
): TransitionEffect =
  ## Dissolve/pixelate transition effect
  var params = initTable[string, float]()
  params["blockSize"] = float(blockSize)
  TransitionEffect(
    name: "dissolve",
    duration: duration,
    easing: easing,
    direction: tdRandom,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: params
  )

proc pushEffect*(
  duration: float = 0.5,
  direction: TransitionDirection = tdLeft,
  easing: EasingFunction = easeInOutCubic
): TransitionEffect =
  ## Push transition (both buffers move together)
  TransitionEffect(
    name: "push",
    duration: duration,
    easing: easing,
    direction: direction,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: initTable[string, float]()
  )

proc regionalEffect*(
  baseEffect: TransitionEffect,
  x, y, width, height: int
): TransitionEffect =
  ## Apply an effect to a specific region
  result = baseEffect
  result.region = TransitionRegion(x: x, y: y, width: width, height: height)

# ================================================================
# TRANSITION ENGINE
# ================================================================

proc newTransitionEngine*(): TransitionEngine =
  ## Create a new transition engine
  TransitionEngine(
    transitions: @[],
    globalCallbacks: initTable[TransitionEvent, seq[TransitionCallback]]()
  )

proc newTransition*(
  startBuffer, endBuffer: BufferSnapshot,
  effect: TransitionEffect
): Transition =
  ## Create a new transition
  Transition(
    startBuffer: startBuffer,
    endBuffer: endBuffer,
    effect: effect,
    elapsed: 0.0,
    progress: 0.0,
    easedProgress: 0.0,
    isActive: true,
    callbacks: initTable[TransitionEvent, seq[TransitionCallback]]()
  )

proc registerCallback*(
  trans: Transition,
  event: TransitionEvent,
  callback: TransitionCallback
) =
  ## Register a callback for a transition event
  if event notin trans.callbacks:
    trans.callbacks[event] = @[]
  trans.callbacks[event].add(callback)

proc registerGlobalCallback*(
  engine: TransitionEngine,
  event: TransitionEvent,
  callback: TransitionCallback
) =
  ## Register a global callback for all transitions
  if event notin engine.globalCallbacks:
    engine.globalCallbacks[event] = @[]
  engine.globalCallbacks[event].add(callback)

proc triggerEvent(trans: Transition, event: TransitionEvent) =
  ## Trigger callbacks for an event
  if event in trans.callbacks:
    for callback in trans.callbacks[event]:
      callback(trans, trans.progress)

proc triggerGlobalEvent(engine: TransitionEngine, trans: Transition, event: TransitionEvent) =
  ## Trigger global callbacks for an event
  if event in engine.globalCallbacks:
    for callback in engine.globalCallbacks[event]:
      callback(trans, trans.progress)

proc startTransition*(
  engine: TransitionEngine,
  startBuffer, endBuffer: BufferSnapshot,
  effect: TransitionEffect
): Transition {.discardable.} =
  ## Start a new transition
  let trans = newTransition(startBuffer, endBuffer, effect)
  trans.triggerEvent(teBeforeStart)
  engine.triggerGlobalEvent(trans, teBeforeStart)
  engine.transitions.add(trans)
  trans.triggerEvent(teStart)
  engine.triggerGlobalEvent(trans, teStart)
  return trans

proc cancelTransition*(engine: TransitionEngine, trans: Transition) =
  ## Cancel an active transition
  let idx = engine.transitions.find(trans)
  if idx >= 0:
    trans.triggerEvent(teCanceled)
    engine.triggerGlobalEvent(trans, teCanceled)
    trans.isActive = false
    engine.transitions.delete(idx)

proc hasActiveTransitions*(engine: TransitionEngine): bool =
  ## Check if there are any active transitions
  return engine.transitions.len > 0

proc update*(engine: TransitionEngine, deltaTime: float) =
  ## Update all active transitions
  var i = 0
  while i < engine.transitions.len:
    let trans = engine.transitions[i]
    
    if not trans.isActive:
      engine.transitions.delete(i)
      continue
    
    # Update elapsed time and progress
    trans.elapsed += deltaTime
    trans.progress = min(1.0, trans.elapsed / trans.effect.duration)
    trans.easedProgress = trans.effect.easing(trans.progress)
    
    # Trigger progress event
    trans.triggerEvent(teProgress)
    engine.triggerGlobalEvent(trans, teProgress)
    
    # Check completion
    if trans.progress >= 1.0:
      trans.isActive = false
      trans.triggerEvent(teComplete)
      engine.triggerGlobalEvent(trans, teComplete)
      engine.transitions.delete(i)
      continue
    
    inc i

# ================================================================
# TRANSITION EFFECT IMPLEMENTATIONS
# ================================================================

proc applyFadeEffect(trans: Transition): BufferSnapshot =
  ## Apply fade transition effect
  let t = trans.easedProgress
  result = newBufferSnapshot(trans.endBuffer.width, trans.endBuffer.height)
  
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      let startCell = trans.startBuffer.getCell(x, y)
      let endCell = trans.endBuffer.getCell(x, y)
      
      # Interpolate style (colors fade)
      let style = lerpStyle(startCell.style, endCell.style, t)
      
      # Character switches at midpoint
      let ch = if t < 0.5: startCell.ch else: endCell.ch
      
      result.setCell(x, y, ch, style)

proc applySlideEffect(trans: Transition): BufferSnapshot =
  ## Apply slide transition effect
  let t = trans.easedProgress
  result = newBufferSnapshot(trans.endBuffer.width, trans.endBuffer.height)
  
  let w = result.width
  let h = result.height
  
  case trans.effect.direction
  of tdLeft:
    let offset = int(float(w) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        let srcX = x + offset
        if srcX < w:
          let cell = trans.startBuffer.getCell(srcX, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.endBuffer.getCell(srcX - w, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdRight:
    let offset = int(float(w) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        let srcX = x - offset
        if srcX >= 0:
          let cell = trans.startBuffer.getCell(srcX, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.endBuffer.getCell(w + srcX, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdUp:
    let offset = int(float(h) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        let srcY = y + offset
        if srcY < h:
          let cell = trans.startBuffer.getCell(x, srcY)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.endBuffer.getCell(x, srcY - h)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdDown:
    let offset = int(float(h) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        let srcY = y - offset
        if srcY >= 0:
          let cell = trans.startBuffer.getCell(x, srcY)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.endBuffer.getCell(x, h + srcY)
          result.setCell(x, y, cell.ch, cell.style)
  
  else:
    # Default to left
    result = applyFadeEffect(trans)

proc applyWipeEffect(trans: Transition): BufferSnapshot =
  ## Apply wipe transition effect
  let t = trans.easedProgress
  result = newBufferSnapshot(trans.endBuffer.width, trans.endBuffer.height)
  
  let w = result.width
  let h = result.height
  
  case trans.effect.direction
  of tdLeft:
    let wipeX = int(float(w) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        if x < wipeX:
          let cell = trans.endBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.startBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdRight:
    let wipeX = w - int(float(w) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        if x >= wipeX:
          let cell = trans.endBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.startBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdUp:
    let wipeY = int(float(h) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        if y < wipeY:
          let cell = trans.endBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.startBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdDown:
    let wipeY = h - int(float(h) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        if y >= wipeY:
          let cell = trans.endBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.startBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  of tdCenter:
    let maxDist = sqrt(float(w * w + h * h)) / 2.0
    let currentDist = maxDist * t
    let cx = w / 2
    let cy = h / 2
    for y in 0 ..< h:
      for x in 0 ..< w:
        let dx = float(x) - cx
        let dy = float(y) - cy
        let dist = sqrt(dx * dx + dy * dy)
        if dist < currentDist:
          let cell = trans.endBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let cell = trans.startBuffer.getCell(x, y)
          result.setCell(x, y, cell.ch, cell.style)
  
  else:
    result = applyFadeEffect(trans)

proc applyDissolveEffect(trans: Transition): BufferSnapshot =
  ## Apply dissolve/pixelate transition effect
  let t = trans.easedProgress
  result = newBufferSnapshot(trans.endBuffer.width, trans.endBuffer.height)
  
  # Simple threshold-based dissolve using position hash
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      # Generate pseudo-random threshold for this cell
      let hash = float((x * 2654435761 + y * 2246822519) mod 1000) / 1000.0
      
      if t > hash:
        let cell = trans.endBuffer.getCell(x, y)
        result.setCell(x, y, cell.ch, cell.style)
      else:
        let cell = trans.startBuffer.getCell(x, y)
        result.setCell(x, y, cell.ch, cell.style)

proc applyPushEffect(trans: Transition): BufferSnapshot =
  ## Apply push transition effect (both buffers move)
  let t = trans.easedProgress
  result = newBufferSnapshot(trans.endBuffer.width, trans.endBuffer.height)
  
  let w = result.width
  let h = result.height
  
  case trans.effect.direction
  of tdLeft:
    let offset = int(float(w) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        # Start buffer moves out
        let startX = x - offset
        if startX >= 0 and startX < w:
          let cell = trans.startBuffer.getCell(startX, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          # End buffer pushes in
          let endX = w + startX
          if endX >= 0 and endX < w:
            let cell = trans.endBuffer.getCell(endX, y)
            result.setCell(x, y, cell.ch, cell.style)
  
  of tdRight:
    let offset = int(float(w) * t)
    for y in 0 ..< h:
      for x in 0 ..< w:
        let startX = x + offset
        if startX < w:
          let cell = trans.startBuffer.getCell(startX, y)
          result.setCell(x, y, cell.ch, cell.style)
        else:
          let endX = startX - w
          if endX >= 0:
            let cell = trans.endBuffer.getCell(endX, y)
            result.setCell(x, y, cell.ch, cell.style)
  
  else:
    result = applySlideEffect(trans)

proc applyTransition*(trans: Transition): BufferSnapshot =
  ## Apply the appropriate effect based on transition type
  case trans.effect.name
  of "fade": return applyFadeEffect(trans)
  of "slide": return applySlideEffect(trans)
  of "wipe": return applyWipeEffect(trans)
  of "dissolve": return applyDissolveEffect(trans)
  of "push": return applyPushEffect(trans)
  else: return trans.endBuffer

proc getTransitionBuffer*(engine: TransitionEngine): BufferSnapshot =
  ## Get the current composite buffer from all active transitions
  ## If multiple transitions are active, returns the most recent one
  if engine.transitions.len == 0:
    return newBufferSnapshot(0, 0)
  
  # For now, just return the first transition's result
  # Could be extended to composite multiple transitions
  return applyTransition(engine.transitions[0])
