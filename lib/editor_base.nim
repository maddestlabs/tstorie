## Editor Base Types
##
## Foundation types for tstoried that don't depend on full tstorie infrastructure.
## Provides Color, Style, Layer, and InputEvent types needed by TUI widgets.

import tables

# ================================================================
# COLOR AND STYLE
# ================================================================

type
  Color* = object
    r*, g*, b*: uint8

  Style* = object
    fg*: Color
    bg*: Color
    bold*: bool
    underline*: bool
    italic*: bool
    dim*: bool

# Color constructors
proc rgb*(r, g, b: uint8): Color =
  Color(r: r, g: g, b: b)

proc defaultStyle*(): Style =
  Style(
    fg: Color(r: 255, g: 255, b: 255),
    bg: Color(r: 0, g: 0, b: 0),
    bold: false,
    underline: false,
    italic: false,
    dim: false
  )

# ================================================================
# BUFFER/LAYER TYPES
# ================================================================

type
  Cell* = object
    ch*: string
    style*: Style
  
  Buffer* = object
    width*, height*: int
    cells*: seq[Cell]
  
  Layer* = ref object
    name*: string
    x*, y*: int
    width*, height*: int
    buffer*: Buffer
    visible*: bool

proc newBuffer*(w, h: int): Buffer =
  result.width = w
  result.height = h
  result.cells = newSeq[Cell](w * h)
  let defaultCell = Cell(ch: " ", style: defaultStyle())
  for i in 0 ..< result.cells.len:
    result.cells[i] = defaultCell

proc newLayer*(name: string, x, y, w, h: int): Layer =
  result = Layer()
  result.name = name
  result.x = x
  result.y = y
  result.width = w
  result.height = h
  result.buffer = newBuffer(w, h)
  result.visible = true

proc write*(buf: var Buffer, x, y: int, ch: string, style: Style) =
  if x >= 0 and x < buf.width and y >= 0 and y < buf.height:
    let idx = y * buf.width + x
    buf.cells[idx] = Cell(ch: ch, style: style)

proc writeText*(buf: var Buffer, x, y: int, text: string, style: Style) =
  var cx = x
  for ch in text:
    buf.write(cx, y, $ch, style)
    inc cx
    if cx >= buf.width:
      break

# ================================================================
# INPUT EVENTS
# ================================================================

type
  EventKind* = enum
    evNone
    evKey
    evMouse
    evResize
  
  InputEvent* = object
    case kind*: EventKind
    of evKey:
      key*: string          ## Key as string (e.g., "a", "ctrl+s", "up")
      keyCode*: int         ## Raw key code
      action*: string       ## "press", "release", "repeat"
    of evMouse:
      button*: int          ## Mouse button
      x*, y*: int          ## Mouse position
      mouseAction*: string  ## "press", "release", "move"
    of evResize:
      newWidth*, newHeight*: int
    of evNone:
      discard
