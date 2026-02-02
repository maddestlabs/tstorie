## Terminal Buffer Implementation
## Character-cell based rendering buffer for terminal backends
##
## This is the original tStorie rendering system - a 2D grid of characters
## with ANSI styling. Extracted from src/layers.nim for the multi-backend
## architecture.

import ../../src/types
import ../../src/charwidth
import std/[strutils]

# Re-export types for backward compatibility
export types.TermBuffer, types.Cell

# ================================================================
# BUFFER OPERATIONS
# ================================================================

proc newTermBuffer*(w, h: int): TermBuffer =
  ## Create a new terminal buffer with the given dimensions
  if w < 0 or h < 0:
    echo "[TermBuffer] ERROR: Negative dimensions! w=", w, " h=", h
    quit(1)
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
  ## Set clipping rectangle for rendering operations
  tb.clipX = max(0, x)
  tb.clipY = max(0, y)
  tb.clipW = min(w, tb.width - tb.clipX)
  tb.clipH = min(h, tb.height - tb.clipY)

proc clearClip*(tb: var TermBuffer) =
  ## Remove clipping rectangle (render to entire buffer)
  tb.clipX = 0
  tb.clipY = 0
  tb.clipW = tb.width
  tb.clipH = tb.height

proc setOffset*(tb: var TermBuffer, x, y: int) =
  ## Set rendering offset (for scrolling/camera effects)
  tb.offsetX = x
  tb.offsetY = y

proc writeCell*(tb: var TermBuffer, x, y: int, ch: string, style: Style) =
  ## Write a single character cell at the given position
  ## Respects clipping and offset settings
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

proc writeCellText*(tb: var TermBuffer, x, y: int, text: string, style: Style) =
  ## Write a string of text to character cells at the given position
  ## Handles UTF-8 multi-byte characters and double-width characters
  var currentX = x
  var i = 0
  while i < text.len:
    let b = text[i].ord
    var charLen = 1
    var ch = ""
    
    # Decode UTF-8 character
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
    
    tb.writeCell(currentX, y, ch, style)
    
    # Advance by the display width (handles double-width characters like CJK)
    let displayWidth = getCharDisplayWidth(ch)
    
    # For double-width characters, write a space to the second cell
    if displayWidth == 2 and currentX + 1 < tb.width:
      tb.writeCell(currentX + 1, y, " ", style)  # Regular ASCII space (single-width)
    
    currentX += displayWidth
    i += charLen

proc fillCellRect*(tb: var TermBuffer, x, y, w, h: int, ch: string, style: Style) =
  ## Fill a rectangle of cells with the given character and style
  for dy in 0 ..< h:
    for dx in 0 ..< w:
      tb.writeCell(x + dx, y + dy, ch, style)

proc clearCells*(tb: var TermBuffer, bgColor: tuple[r, g, b: uint8] = (0'u8, 0'u8, 0'u8)) =
  ## Clear the buffer to a solid background color
  let defaultStyle = Style(fg: white(), bg: Color(r: bgColor.r, g: bgColor.g, b: bgColor.b), bold: false)
  for i in 0 ..< tb.cells.len:
    tb.cells[i] = Cell(ch: " ", style: defaultStyle)

proc clearCellsTransparent*(tb: var TermBuffer) =
  ## Clear the buffer cells to transparent (empty strings allow compositing)
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
  ## Composite one buffer onto another (for layer system)
  ## Empty cells and pure-black backgrounds are treated as transparent
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
# BUFFER SNAPSHOT SYSTEM (for transitions)
# ================================================================

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
      buffer.writeCell(x, y, cell.ch, cell.style)

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
