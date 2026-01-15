## Layer System Module
## Provides layer management, buffer operations, compositing, and display logic
##
## This module contains all layer-related functionality extracted from tstorie.nim
## including buffer operations, layer management, compositing, and terminal display.

import types
import std/[strutils, algorithm]
import charwidth

# ================================================================
# BUFFER OPERATIONS
# ================================================================

proc newTermBuffer*(w, h: int): TermBuffer =
  result.width = w
  result.height = h
  result.cells = newSeq[Cell](w * h)
  result.clipX = 0
  result.clipY = 0
  result.clipW = w
  result.clipH = h
  result.offsetX = 0
  result.offsetY = 0
  let defaultStyle = Style(fg: white(), bg: black(), bold: false)
  for i in 0 ..< result.cells.len:
    result.cells[i] = Cell(ch: " ", style: defaultStyle)

proc setClip*(tb: var TermBuffer, x, y, w, h: int) =
  tb.clipX = max(0, x)
  tb.clipY = max(0, y)
  tb.clipW = min(w, tb.width - tb.clipX)
  tb.clipH = min(h, tb.height - tb.clipY)

proc clearClip*(tb: var TermBuffer) =
  tb.clipX = 0
  tb.clipY = 0
  tb.clipW = tb.width
  tb.clipH = tb.height

proc setOffset*(tb: var TermBuffer, x, y: int) =
  tb.offsetX = x
  tb.offsetY = y

proc write*(tb: var TermBuffer, x, y: int, ch: string, style: Style) =
  let adjustedX = x + tb.offsetX
  let adjustedY = y + tb.offsetY
  
  if adjustedX < tb.clipX or adjustedX >= tb.clipX + tb.clipW:
    return
  if adjustedY < tb.clipY or adjustedY >= tb.clipY + tb.clipH:
    return
  
  let screenX = adjustedX
  let screenY = adjustedY
  
  if screenX < 0 or screenX >= tb.width or screenY < 0 or screenY >= tb.height:
    return
  
  if screenX >= 0 and screenX < tb.width and screenY >= 0 and screenY < tb.height:
    let idx = screenY * tb.width + screenX
    tb.cells[idx] = Cell(ch: ch, style: style)

proc writeText*(tb: var TermBuffer, x, y: int, text: string, style: Style) =
  var currentX = x
  var i = 0
  while i < text.len:
    let b = text[i].ord
    var charLen = 1
    var ch = ""
    
    if (b and 0x80) == 0:
      ch = $text[i]
    elif (b and 0xE0) == 0xC0 and i + 1 < text.len:
      ch = text[i..i+1]
      charLen = 2
    elif (b and 0xF0) == 0xE0 and i + 2 < text.len:
      ch = text[i..i+2]
      charLen = 3
    elif (b and 0xF8) == 0xF0 and i + 3 < text.len:
      ch = text[i..i+3]
      charLen = 4
    else:
      ch = "?"
    
    tb.write(currentX, y, ch, style)
    
    # Advance by the display width, not just 1
    let displayWidth = getCharDisplayWidth(ch)
    
    # For double-width characters, write a single-width space to second cell
    if displayWidth == 2 and currentX + 1 < tb.width:
      tb.write(currentX + 1, y, " ", style)  # Regular ASCII space (single-width)
    
    currentX += displayWidth
    i += charLen

proc fillRect*(tb: var TermBuffer, x, y, w, h: int, ch: string, style: Style) =
  for dy in 0 ..< h:
    for dx in 0 ..< w:
      tb.write(x + dx, y + dy, ch, style)

proc clear*(tb: var TermBuffer, bgColor: tuple[r, g, b: uint8] = (0'u8, 0'u8, 0'u8)) =
  let defaultStyle = Style(fg: white(), bg: Color(r: bgColor.r, g: bgColor.g, b: bgColor.b), bold: false)
  for i in 0 ..< tb.cells.len:
    tb.cells[i] = Cell(ch: " ", style: defaultStyle)

proc clearTransparent*(tb: var TermBuffer) =
  let defaultStyle = Style(fg: white(), bg: black(), bold: false)
  for i in 0 ..< tb.cells.len:
    tb.cells[i] = Cell(ch: "", style: defaultStyle)

proc getCell*(tb: TermBuffer, x, y: int): tuple[ch: string, style: Style] =
  ## Get a cell from the buffer (returns default style if out of bounds)
  if x < 0 or x >= tb.width or y < 0 or y >= tb.height:
    let defStyle = Style(fg: white(), bg: black(), bold: false, underline: false, italic: false, dim: false)
    return (" ", defStyle)
  let idx = y * tb.width + x
  if idx >= 0 and idx < tb.cells.len:
    return (tb.cells[idx].ch, tb.cells[idx].style)
  let defStyle = Style(fg: white(), bg: black(), bold: false, underline: false, italic: false, dim: false)
  return (" ", defStyle)

proc compositeBufferOnto*(dest: var TermBuffer, src: TermBuffer) =
  let w = min(dest.width, src.width)
  let h = min(dest.height, src.height)
  for y in 0 ..< h:
    let dr = y * dest.width
    let sr = y * src.width
    for x in 0 ..< w:
      let s = src.cells[sr + x]
      # Composite if there's a character OR if there's a non-black background
      if s.ch.len > 0 or (s.style.bg.r != 0 or s.style.bg.g != 0 or s.style.bg.b != 0):
        dest.cells[dr + x] = s

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

proc addLayer*(state: AppState, id: string, z: int): Layer =
  let layer = Layer(
    id: id,
    z: z,
    visible: true,
    buffer: newTermBuffer(state.termWidth, state.termHeight)
  )
  layer.buffer.clearTransparent()
  state.layers.add(layer)
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
  
  for layer in state.layers:
    if layer.visible:
      compositeBufferOnto(state.currentBuffer, layer.buffer)

# ================================================================
# DISPLAY
# ================================================================

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

# ================================================================
# BUFFER SNAPSHOT SYSTEM
# ================================================================
# Moved from lib/animation.nim - provides buffer capture for transitions

type
  BufferSnapshot* = object
    ## A captured snapshot of a buffer state for manual transitions
    width*, height*: int
    cells*: seq[tuple[ch: string, style: Style]]

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
  ## Get a cell from the snapshot (returns default style if out of bounds)
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

proc captureBuffer*(buffer: TermBuffer): BufferSnapshot =
  ## Capture the current state of a TermBuffer into a snapshot
  result = newBufferSnapshot(buffer.width, buffer.height)
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      let idx = y * buffer.width + x
      if idx < buffer.cells.len:
        result.setCell(x, y, buffer.cells[idx].ch, buffer.cells[idx].style)

proc applySnapshot*(snapshot: BufferSnapshot, buffer: var TermBuffer) =
  ## Apply a snapshot to a TermBuffer
  for y in 0 ..< min(snapshot.height, buffer.height):
    for x in 0 ..< min(snapshot.width, buffer.width):
      let cell = snapshot.getCell(x, y)
      buffer.write(x, y, cell.ch, cell.style)

proc blendSnapshots*(a, b: BufferSnapshot, t: float): BufferSnapshot =
  ## Blend two buffer snapshots together using linear interpolation
  ## t=0.0 returns snapshot a, t=1.0 returns snapshot b
  let width = min(a.width, b.width)
  let height = min(a.height, b.height)
  result = newBufferSnapshot(width, height)
  
  for y in 0 ..< height:
    for x in 0 ..< width:
      let cellA = a.getCell(x, y)
      let cellB = b.getCell(x, y)
      
      # Interpolate style (colors fade)
      let style = lerpStyle(cellA.style, cellB.style, t)
      
      # Character switches at midpoint
      let ch = if t < 0.5: cellA.ch else: cellB.ch
      
      result.setCell(x, y, ch, style)
