## Nimini bindings for TUI Helpers
##
## Exposes TUI helper functions to nimini scripts, enabling rapid
## prototyping of terminal user interfaces.

import ../nimini
import ../nimini/runtime
import ../src/types
import std/[tables, strutils]
import tui_helpers  # Import the TUI helper functions

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

proc valueToFloat(v: Value): float =
  case v.kind
  of vkFloat: return v.f
  of vkInt: return float(v.i)
  else: return 0.0

proc valueToString(v: Value): string =
  if v.kind == vkString:
    return v.s
  return ""

proc valueToBool(v: Value): bool =
  case v.kind
  of vkBool: return v.b
  of vkInt: return v.i != 0
  else: return false

proc valueToStyle(v: Value): Style =
  ## Convert nimini value to Style
  if v.kind == vkMap:
    var style = Style()
    
    # Foreground color
    if v.map.hasKey("fg"):
      let fgVal = v.map["fg"]
      if fgVal.kind == vkString:
        # Parse hex color string
        let hexStr = fgVal.s
        if hexStr.len >= 7 and hexStr[0] == '#':
          let r = parseHexInt(hexStr[1..2])
          let g = parseHexInt(hexStr[3..4])
          let b = parseHexInt(hexStr[5..6])
          style.fg = Color(r: uint8(r), g: uint8(g), b: uint8(b))
    
    # Background color
    if v.map.hasKey("bg"):
      let bgVal = v.map["bg"]
      if bgVal.kind == vkString:
        let hexStr = bgVal.s
        if hexStr.len >= 7 and hexStr[0] == '#':
          let r = parseHexInt(hexStr[1..2])
          let g = parseHexInt(hexStr[3..4])
          let b = parseHexInt(hexStr[5..6])
          style.bg = Color(r: uint8(r), g: uint8(g), b: uint8(b))
    
    # Style attributes
    if v.map.hasKey("bold"):
      style.bold = valueToBool(v.map["bold"])
    if v.map.hasKey("italic"):
      style.italic = valueToBool(v.map["italic"])
    if v.map.hasKey("underline"):
      style.underline = valueToBool(v.map["underline"])
    if v.map.hasKey("dim"):
      style.dim = valueToBool(v.map["dim"])
    
    return style
  
  # Fallback
  return Style(
    fg: Color(r: 255'u8, g: 255'u8, b: 255'u8),
    bg: Color(r: 0'u8, g: 0'u8, b: 0'u8),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

# ==============================================================================
# BOX DRAWING BINDINGS
# ==============================================================================

proc nimini_drawBoxSimple*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawBoxSimple(layer, x, y, w, h, style)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let style = valueToStyle(args[5])
  
  drawBoxSimple(layer, x, y, w, h, style)
  return valNil()

proc nimini_drawBoxDouble*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawBoxDouble(layer, x, y, w, h, style)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let style = valueToStyle(args[5])
  
  drawBoxDouble(layer, x, y, w, h, style)
  return valNil()

proc nimini_drawBoxRounded*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawBoxRounded(layer, x, y, w, h, style)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let style = valueToStyle(args[5])
  
  drawBoxRounded(layer, x, y, w, h, style)
  return valNil()

proc nimini_fillBox*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## fillBox(layer, x, y, w, h, ch, style)
  if args.len < 7:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let ch = valueToString(args[5])
  let style = valueToStyle(args[6])
  
  fillBox(layer, x, y, w, h, ch, style)
  return valNil()

# ==============================================================================
# TEXT HELPER BINDINGS
# ==============================================================================

proc nimini_centerTextX*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## centerTextX(text, boxX, boxWidth) -> int
  if args.len < 3:
    return valInt(0)
  
  let text = valueToString(args[0])
  let boxX = valueToInt(args[1])
  let boxWidth = valueToInt(args[2])
  
  return valInt(centerTextX(text, boxX, boxWidth))

proc nimini_centerTextY*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## centerTextY(boxY, boxHeight) -> int
  if args.len < 2:
    return valInt(0)
  
  let boxY = valueToInt(args[0])
  let boxHeight = valueToInt(args[1])
  
  return valInt(centerTextY(boxY, boxHeight))

proc nimini_drawCenteredText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawCenteredText(layer, x, y, w, h, text, style)
  if args.len < 7:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let text = valueToString(args[5])
  let style = valueToStyle(args[6])
  
  drawCenteredText(layer, x, y, w, h, text, style)
  return valNil()

proc nimini_truncateText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## truncateText(text, maxWidth) -> string
  if args.len < 2:
    return valString("")
  
  let text = valueToString(args[0])
  let maxWidth = valueToInt(args[1])
  
  return valString(truncateText(text, maxWidth))

# ==============================================================================
# HIT TESTING BINDINGS
# ==============================================================================

proc nimini_pointInRect*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## pointInRect(px, py, rx, ry, rw, rh) -> bool
  if args.len < 6:
    return valBool(false)
  
  let px = valueToInt(args[0])
  let py = valueToInt(args[1])
  let rx = valueToInt(args[2])
  let ry = valueToInt(args[3])
  let rw = valueToInt(args[4])
  let rh = valueToInt(args[5])
  
  return valBool(pointInRect(px, py, rx, ry, rw, rh))

proc nimini_findClickedWidget*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## findClickedWidget(mouseX, mouseY, widgetX[], widgetY[], widgetW[], widgetH[]) -> int
  if args.len < 6:
    return valInt(-1)
  
  let mouseX = valueToInt(args[0])
  let mouseY = valueToInt(args[1])
  
  # Convert arrays
  var widgetX: seq[int] = @[]
  var widgetY: seq[int] = @[]
  var widgetW: seq[int] = @[]
  var widgetH: seq[int] = @[]
  
  if args[2].kind == vkArray:
    for v in args[2].arr:
      widgetX.add(valueToInt(v))
  
  if args[3].kind == vkArray:
    for v in args[3].arr:
      widgetY.add(valueToInt(v))
  
  if args[4].kind == vkArray:
    for v in args[4].arr:
      widgetW.add(valueToInt(v))
  
  if args[5].kind == vkArray:
    for v in args[5].arr:
      widgetH.add(valueToInt(v))
  
  let result = findClickedWidget(mouseX, mouseY, widgetX, widgetY, widgetW, widgetH)
  return valInt(result)

# ==============================================================================
# WIDGET RENDERING BINDINGS
# ==============================================================================

proc nimini_drawButton*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawButton(layer, x, y, w, h, label, isFocused, [isPressed], [borderStyle])
  if args.len < 7:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let label = valueToString(args[5])
  let isFocused = valueToBool(args[6])
  let isPressed = if args.len >= 8: valueToBool(args[7]) else: false
  let borderStyle = if args.len >= 9: valueToString(args[8]) else: "classic"
  
  drawButton(layer, x, y, w, h, label, isFocused, isPressed, borderStyle)
  return valNil()

proc nimini_drawLabel*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawLabel(layer, x, y, text, style)
  if args.len < 5:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let text = valueToString(args[3])
  let style = valueToStyle(args[4])
  
  drawLabel(layer, x, y, text, style)
  return valNil()

proc nimini_drawTextBox*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTextBox(layer, x, y, w, h, content, cursorPos, isFocused, [borderStyle])
  if args.len < 8:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let content = valueToString(args[5])
  let cursorPos = valueToInt(args[6])
  let isFocused = valueToBool(args[7])
  let borderStyle = if args.len >= 9: valueToString(args[8]) else: "classic"
  
  drawTextBox(layer, x, y, w, h, content, cursorPos, isFocused, borderStyle)
  return valNil()

proc nimini_drawSlider*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawSlider(layer, x, y, w, value, minVal, maxVal, isFocused)
  if args.len < 8:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let value = valueToFloat(args[4])
  let minVal = valueToFloat(args[5])
  let maxVal = valueToFloat(args[6])
  let isFocused = valueToBool(args[7])
  
  drawSlider(layer, x, y, w, value, minVal, maxVal, isFocused)
  return valNil()

proc nimini_drawCheckBox*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawCheckBox(layer, x, y, label, isChecked, isFocused)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let label = valueToString(args[3])
  let isChecked = valueToBool(args[4])
  let isFocused = valueToBool(args[5])
  
  drawCheckBox(layer, x, y, label, isChecked, isFocused)
  return valNil()

proc nimini_drawPanel*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawPanel(layer, x, y, w, h, title, [borderStyle])
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let title = valueToString(args[5])
  let borderStyle = if args.len >= 7: valueToString(args[6]) else: "classic"
  
  drawPanel(layer, x, y, w, h, title, borderStyle)
  return valNil()

proc nimini_drawProgressBar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawProgressBar(layer, x, y, w, progress, [showPercent])
  if args.len < 5:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let progress = valueToFloat(args[4])
  let showPercent = if args.len >= 6: valueToBool(args[5]) else: true
  
  drawProgressBar(layer, x, y, w, progress, showPercent)
  return valNil()

proc nimini_drawSeparator*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawSeparator(layer, x, y, w, style, [ch])
  if args.len < 5:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let style = valueToStyle(args[4])
  let ch = if args.len >= 6: valueToString(args[5]) else: "─"
  
  drawSeparator(layer, x, y, w, style, ch)
  return valNil()

# ==============================================================================
# LAYOUT HELPER BINDINGS
# ==============================================================================

proc nimini_layoutVertical*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## layoutVertical(startY, spacing, count) -> array of int
  if args.len < 3:
    return valArray(@[])
  
  let startY = valueToInt(args[0])
  let spacing = valueToInt(args[1])
  let count = valueToInt(args[2])
  
  let positions = layoutVertical(startY, spacing, count)
  var result: seq[Value] = @[]
  for pos in positions:
    result.add(valInt(pos))
  
  return valArray(result)

proc nimini_layoutHorizontal*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## layoutHorizontal(startX, spacing, count) -> array of int
  if args.len < 3:
    return valArray(@[])
  
  let startX = valueToInt(args[0])
  let spacing = valueToInt(args[1])
  let count = valueToInt(args[2])
  
  let positions = layoutHorizontal(startX, spacing, count)
  var result: seq[Value] = @[]
  for pos in positions:
    result.add(valInt(pos))
  
  return valArray(result)

proc nimini_layoutCentered*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## layoutCentered(containerX, containerY, containerW, containerH, itemW, itemH) -> {x, y}
  if args.len < 6:
    var emptyMap = initTable[string, Value]()
    return valMap(emptyMap)
  
  let containerX = valueToInt(args[0])
  let containerY = valueToInt(args[1])
  let containerW = valueToInt(args[2])
  let containerH = valueToInt(args[3])
  let itemW = valueToInt(args[4])
  let itemH = valueToInt(args[5])
  
  let pos = layoutCentered(containerX, containerY, containerW, containerH, itemW, itemH)
  
  var result = initTable[string, Value]()
  result["x"] = valInt(pos.x)
  result["y"] = valInt(pos.y)
  
  return valMap(result)

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerTUIHelperBindings*(env: ref Env) =
  ## Register all TUI helper functions with nimini
  
  # Box drawing
  registerNative("drawBoxSimple", nimini_drawBoxSimple,
    storieLibs = @["tui_helpers"],
    description = "Draw a box with classic corners")
  
  registerNative("drawBoxDouble", nimini_drawBoxDouble,
    storieLibs = @["tui_helpers"],
    description = "Draw a box with double-line borders")
  
  registerNative("drawBoxRounded", nimini_drawBoxRounded,
    storieLibs = @["tui_helpers"],
    description = "Draw a box with rounded corners")
  
  registerNative("fillBox", nimini_fillBox,
    storieLibs = @["tui_helpers"],
    description = "Fill a rectangular area with a character")
  
  # Text helpers
  registerNative("centerTextX", nimini_centerTextX,
    storieLibs = @["tui_helpers"],
    description = "Calculate X position to center text")
  
  registerNative("centerTextY", nimini_centerTextY,
    storieLibs = @["tui_helpers"],
    description = "Calculate Y position to center text vertically")
  
  registerNative("drawCenteredText", nimini_drawCenteredText,
    storieLibs = @["tui_helpers"],
    description = "Draw text centered in a box")
  
  registerNative("truncateText", nimini_truncateText,
    storieLibs = @["tui_helpers"],
    description = "Truncate text to fit width with ellipsis")
  
  # Hit testing
  registerNative("pointInRect", nimini_pointInRect,
    storieLibs = @["tui_helpers"],
    description = "Check if point is inside rectangle")
  
  registerNative("findClickedWidget", nimini_findClickedWidget,
    storieLibs = @["tui_helpers"],
    description = "Find which widget was clicked")
  
  # Widgets
  registerNative("drawButton", nimini_drawButton,
    storieLibs = @["tui_helpers"],
    description = "Draw a button widget")
  
  registerNative("drawLabel", nimini_drawLabel,
    storieLibs = @["tui_helpers"],
    description = "Draw a text label")
  
  registerNative("drawTextBox", nimini_drawTextBox,
    storieLibs = @["tui_helpers"],
    description = "Draw a text input box with cursor")
  
  registerNative("drawSlider", nimini_drawSlider,
    storieLibs = @["tui_helpers"],
    description = "Draw a horizontal slider")
  
  registerNative("drawCheckBox", nimini_drawCheckBox,
    storieLibs = @["tui_helpers"],
    description = "Draw a checkbox with label")
  
  registerNative("drawPanel", nimini_drawPanel,
    storieLibs = @["tui_helpers"],
    description = "Draw a titled panel/frame")
  
  registerNative("drawProgressBar", nimini_drawProgressBar,
    storieLibs = @["tui_helpers"],
    description = "Draw a progress bar")
  
  registerNative("drawSeparator", nimini_drawSeparator,
    storieLibs = @["tui_helpers"],
    description = "Draw a horizontal separator line")
  
  # Layout
  registerNative("layoutVertical", nimini_layoutVertical,
    storieLibs = @["tui_helpers"],
    description = "Calculate Y positions for vertical layout")
  
  registerNative("layoutHorizontal", nimini_layoutHorizontal,
    storieLibs = @["tui_helpers"],
    description = "Calculate X positions for horizontal layout")
  
  registerNative("layoutCentered", nimini_layoutCentered,
    storieLibs = @["tui_helpers"],
    description = "Center an item within a container")

export registerTUIHelperBindings
