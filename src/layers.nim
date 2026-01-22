## Layer System Module
## Provides layer management, buffer operations, compositing, and display logic
##
## This module contains layer management, compositing, and terminal display logic.
## Buffer operations are now in backends/terminal/termbuffer.nim for the
## multi-backend architecture.

import types
import std/[strutils, algorithm, tables]
import charwidth

# Import buffer operations from the terminal backend
# In the future, this will be conditional based on backend selection
import ../backends/terminal/termbuffer
export termbuffer

# ================================================================
# LAYER MANAGEMENT
# ================================================================

proc newLayer*(id: string, width, height: int, z: int = 0): Layer =
  ## Create a new layer with the given dimensions
  result = Layer(
    id: id,
    z: z,
    visible: true,
    buffer: newTermBuffer(width, height)
  )
  result.buffer.clearTransparent()

# ================================================================
# LAYER CACHE MANAGEMENT
# ================================================================

proc rebuildLayerCache*(state: AppState) =
  ## Rebuild the layer name -> index cache
  ## This is called automatically when needed, but can be called manually
  ## after batch layer operations for performance
  state.layerIndexCache.clear()
  for i, layer in state.layers:
    state.layerIndexCache[layer.id] = i
  state.cacheValid = true

proc invalidateLayerCache*(state: AppState) =
  ## Mark the layer cache as invalid (will be rebuilt on next access)
  state.cacheValid = false

proc resolveLayerIndex*(state: AppState, layerId: string): int =
  ## Resolve a layer name to its index in the layers array
  ## Returns -1 if layer not found
  ## Special case: \"default\" or \"\" returns 0 (the default layer)
  if layerId == "default" or layerId == "":
    return 0
  
  # Rebuild cache if invalid
  if not state.cacheValid:
    rebuildLayerCache(state)
  
  # Look up in cache
  if state.layerIndexCache.hasKey(layerId):
    return state.layerIndexCache[layerId]
  else:
    return -1

proc resolveLayerIndex*(state: AppState, layerId: int): int =
  ## Resolve an integer layer index (bounds checking)
  ## Returns -1 if out of bounds
  if layerId >= 0 and layerId < state.layers.len:
    return layerId
  else:
    return -1

proc addLayer*(state: AppState, id: string, z: int): Layer =
  let layer = Layer(
    id: id,
    z: z,
    visible: true,
    buffer: newTermBuffer(state.termWidth, state.termHeight)
  )
  layer.buffer.clearTransparent()
  state.layers.add(layer)
  invalidateLayerCache(state)  # Cache is now stale
  return layer

proc getLayer*(state: AppState, id: string): Layer =
  for layer in state.layers:
    if layer.id == id:
      return layer
  return nil

proc removeLayer*(state: AppState, id: string) =
  var i = 0
  while i < state.layers.len:
    if state.layers[i].id == id:
      state.layers.delete(i)
      invalidateLayerCache(state)  # Cache is now stale
    else:
      i += 1

proc resizeLayers*(state: AppState, newWidth, newHeight: int) =
  ## Resize all layer buffers to match new terminal size
  for layer in state.layers:
    layer.buffer = newTermBuffer(newWidth, newHeight)
    layer.buffer.clearTransparent()

# Hook for plugins to replace compositing logic
type
  CompositeHook* = proc(state: AppState)

var gCompositeHook*: CompositeHook = nil

proc compositeLayers*(state: AppState) =
  # Check if a plugin has registered an enhanced compositor
  if not gCompositeHook.isNil:
    gCompositeHook(state)
    return
  
  # Standard compositing (no plugin enhancements)
  if state.layers.len == 0:
    return
  
  # Fill buffer with theme background color first
  state.currentBuffer.clear(state.themeBackground)
  
  # Sort layers by z-index (stable sort maintains insertion order for equal z values)
  # This matches behavior of game engines like Unity, Godot, and Phaser
  state.layers.sort(proc(a, b: Layer): int =
    cmp(a.z, b.z)
  )
  invalidateLayerCache(state)  # Cache is stale after reordering
  
  for layer in state.layers:
    if layer.visible:
      compositeBufferOnto(state.currentBuffer, layer.buffer)

# ================================================================
# DISPLAY
# ================================================================
# Terminal display logic - outputs ANSI escape codes to stdout
# In multi-backend architecture, this will move to backends/terminal/term_display.nim

proc colorsEqual(a, b: Color): bool =
  a.r == b.r and a.g == b.g and a.b == b.b

proc stylesEqual(a, b: Style): bool =
  colorsEqual(a.fg, b.fg) and colorsEqual(a.bg, b.bg) and
  a.bold == b.bold and a.underline == b.underline and
  a.italic == b.italic and a.dim == b.dim

proc cellsEqual(a, b: Cell): bool =
  a.ch == b.ch and stylesEqual(a.style, b.style)

proc buildStyleCode(style: Style, colorSupport: int): string =
  result = "\e["
  var codes: seq[string] = @["0"]
  
  if style.bold: codes.add("1")
  if style.dim: codes.add("2")
  if style.italic: codes.add("3")
  if style.underline: codes.add("4")
  
  case colorSupport
  of 16777216:
    codes.add("38;2;" & $style.fg.r & ";" & $style.fg.g & ";" & $style.fg.b)
  of 256:
    codes.add("38;5;" & $toAnsi256(style.fg))
  else:
    codes.add($toAnsi8(style.fg))
  
  # Always output background color to ensure theme backgrounds are applied
  case colorSupport
  of 16777216:
    codes.add("48;2;" & $style.bg.r & ";" & $style.bg.g & ";" & $style.bg.b)
  of 256:
    codes.add("48;5;" & $toAnsi256(style.bg))
  else:
    codes.add($(toAnsi8(style.bg) + 10))
  
  result.add(codes.join(";") & "m")

proc display*(tb: var TermBuffer, prev: var TermBuffer, colorSupport: int) =
  when defined(emscripten):
    discard
  else:
    var output = ""
    let sizeChanged = prev.width != tb.width or prev.height != tb.height
    
    if sizeChanged:
      output.add("\e[2J")
      prev = newTermBuffer(tb.width, tb.height)
    
    # Pre-allocate string capacity for better performance (Windows consoles benefit)
    when defined(windows):
      output = newStringOfCap(tb.width * tb.height * 4)
    
    var haveLastStyle = false
    var lastStyle: Style
    var haveCursor = false
    var lastCursorY = -1
    var lastCursorXEnd = -1
    
    for y in 0 ..< tb.height:
      var x = 0
      while x < tb.width:
        let idx = y * tb.width + x
        let cell = tb.cells[idx]
        
        if not sizeChanged and prev.cells.len > 0 and idx < prev.cells.len and
           cellsEqual(prev.cells[idx], cell):
          x += 1
          continue
        
        var runLength = 1
        while x + runLength < tb.width:
          let nextIdx = idx + runLength
          let nextCell = tb.cells[nextIdx]
          
          if not sizeChanged and prev.cells.len > 0 and nextIdx < prev.cells.len and
             cellsEqual(prev.cells[nextIdx], nextCell):
            break
          
          if not cellsEqual(cell, nextCell):
            if stylesEqual(nextCell.style, cell.style):
              runLength += 1
            else:
              break
          else:
            runLength += 1
        
        # Calculate visual column position accounting for double-width characters
        var visualX = 0
        for cx in 0 ..< x:
          let cellIdx = y * tb.width + cx
          if cellIdx < tb.cells.len:
            let chWidth = getCharDisplayWidth(tb.cells[cellIdx].ch)
            visualX += chWidth
        
        if not haveCursor or lastCursorY != y or lastCursorXEnd != visualX:
          output.add("\e[" & $(y + 1) & ";" & $(visualX + 1) & "H")
        if (not haveLastStyle) or (not stylesEqual(cell.style, lastStyle)):
          output.add(buildStyleCode(cell.style, colorSupport))
          lastStyle = cell.style
          haveLastStyle = true
        
        for i in 0 ..< runLength:
          output.add(tb.cells[idx + i].ch)
        
        # Update visual cursor position
        for i in 0 ..< runLength:
          let chWidth = getCharDisplayWidth(tb.cells[idx + i].ch)
          visualX += chWidth
        
        x += runLength
        haveCursor = true
        lastCursorY = y
        lastCursorXEnd = visualX
    
    # Batch write for better Windows console performance
    stdout.write(output)
    stdout.flushFile()

# Note: BufferSnapshot system moved to backends/terminal/termbuffer.nim
# It's re-exported via the termbuffer import above for backward compatibility

