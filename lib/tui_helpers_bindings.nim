## Nimini bindings for TUI Helpers
##
## This file demonstrates the BASELINE PATTERN for tstorie module bindings.
## Use this as a reference when creating or updating other binding files.
##
## BINDING PATTERNS:
##
## 1. SIMPLE FUNCTIONS → Auto-expose in native file
##    - Functions with only int/float/string/bool parameters
##    - Example: centerTextX, truncateText, pointInRect
##    - In tui_helpers.nim: Add {.autoExpose: "tui".} pragma
##    - In this file: Call register_functionName()
##    - Result: ~90% code reduction, automatic type conversion
##
## 2. STYLE/COLOR FUNCTIONS → Auto-expose in native file  
##    - Functions using Style or Color types
##    - Example: drawBoxSimple, fillBox, drawLabel
##    - type_converters.nim handles Style ↔ Value conversion automatically
##    - In tui_helpers.nim: Add {.autoExpose: "tui".} pragma
##    - In this file: Call register_functionName()
##    - Result: Eliminates duplicate valueToStyle conversions
##
## 3. SEQ/TUPLE RETURNS → Auto-expose in native file
##    - Functions returning seq[int], tuple[x, y: int], etc.
##    - Example: layoutVertical, layoutCentered, layoutGrid
##    - type_converters.nim handles automatic conversion to nimini arrays/maps
##    - In tui_helpers.nim: Add {.autoExpose: "tui".} pragma
##    - In this file: Call register_functionName()
##    - Result: No manual array/map construction needed
##
## 4. COMPLEX MULTI-STEP LOGIC → Manual wrapper (keep here)
##    - Functions with complex parameter validation
##    - Functions with multiple internal function calls
##    - Functions with conditional logic paths
##    - Example: drawButton (checks borderStyle, calls multiple draw funcs)
##    - Keep manual wrapper here with explanatory comment
##    - Result: Full control over complex behavior
##
## 5. VAR PARAMETERS → Manual wrapper (keep here)
##    - Functions that modify parameters (var params)
##    - Example: handleTextInput, handleBackspace
##    - Nimini doesn't support var params directly
##    - Manual wrapper returns tuple of modified values
##    - Result: Proper state management for mutable operations
##
## 6. SEQ INPUTS → Manual wrapper (keep here)
##    - Functions taking seq[int] or seq[string] as parameters  
##    - Example: findClickedWidget(widgetX, widgetY, widgetW, widgetH: seq[int])
##    - Auto-binding could handle this but manual gives more control
##    - Keep manual for now, could auto-expose later if desired
##
## SEE tui_helpers.nim for examples of each pattern in the native file.

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
      elif fgVal.kind == vkMap:
        # Parse RGB map (from getStyle())
        if fgVal.map.hasKey("r") and fgVal.map.hasKey("g") and fgVal.map.hasKey("b"):
          style.fg = Color(
            r: uint8(valueToInt(fgVal.map["r"])),
            g: uint8(valueToInt(fgVal.map["g"])),
            b: uint8(valueToInt(fgVal.map["b"]))
          )
    
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
      elif bgVal.kind == vkMap:
        # Parse RGB map (from getStyle())
        if bgVal.map.hasKey("r") and bgVal.map.hasKey("g") and bgVal.map.hasKey("b"):
          style.bg = Color(
            r: uint8(valueToInt(bgVal.map["r"])),
            g: uint8(valueToInt(bgVal.map["g"])),
            b: uint8(valueToInt(bgVal.map["b"]))
          )
    
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

proc nimini_drawBox*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawBox(layer, x, y, w, h, style, boxType)
  ## Generic box drawing with style parameter: "single", "double", or "rounded"
  if args.len < 7:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let style = valueToStyle(args[5])
  let boxType = valueToString(args[6])
  
  case boxType
  of "double":
    drawBoxDouble(layer, x, y, w, h, style)
  of "rounded":
    drawBoxRounded(layer, x, y, w, h, style)
  else:  # "single" or default
    drawBoxSimple(layer, x, y, w, h, style)
  
  return valNil()

# ==============================================================================
# PATTERN 2 & 3: Functions auto-exposed with Style/seq/tuple types
# ==============================================================================
# The following functions are now auto-exposed in tui_helpers.nim:
# - drawBoxSingle, drawBoxDouble, drawBoxRounded (Style params)
# - fillBox (Style param)
# - drawCenteredText (Style param)
# - drawLabel (Style param)
# - drawSeparator (Style param + default string param)
# - layoutVertical, layoutHorizontal (seq[int] returns)
# - layoutCentered (tuple[x, y: int] return)
# - layoutGrid (seq[tuple[x, y: int]] return)
#
# No manual wrappers needed - type_converters.nim handles all conversions!
# ==============================================================================

# ==============================================================================
# HIT TESTING BINDINGS
# ==============================================================================
# PATTERN 6: Seq inputs → Manual wrapper for control

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
# PATTERN 4: Complex multi-step widgets → Manual wrappers

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
# INPUT HANDLING BINDINGS
# ==============================================================================

proc nimini_handleTextInput*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## handleTextInput(text, cursorPos, content) -> [newCursorPos, newContent, handled]
  if args.len < 3:
    return valArray(@[valInt(0), valString(""), valBool(false)])
  
  let text = valueToString(args[0])
  var cursorPos = valueToInt(args[1])
  var content = valueToString(args[2])
  
  let handled = handleTextInput(text, cursorPos, content)
  
  return valArray(@[valInt(cursorPos), valString(content), valBool(handled)])

proc nimini_handleBackspace*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## handleBackspace(cursorPos, content) -> [newCursorPos, newContent, handled]
  if args.len < 2:
    return valArray(@[valInt(0), valString(""), valBool(false)])
  
  var cursorPos = valueToInt(args[0])
  var content = valueToString(args[1])
  
  let handled = handleBackspace(cursorPos, content)
  
  return valArray(@[valInt(cursorPos), valString(content), valBool(handled)])

proc nimini_handleArrowKeys*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## handleArrowKeys(keyCode, value, minVal, maxVal, step) -> [newValue, handled]
  if args.len < 5:
    return valArray(@[valFloat(0.0), valBool(false)])
  
  let keyCode = valueToInt(args[0])
  var value = valueToFloat(args[1])
  let minVal = valueToFloat(args[2])
  let maxVal = valueToFloat(args[3])
  let step = valueToFloat(args[4])
  
  let handled = handleArrowKeys(keyCode, value, minVal, maxVal, step)
  
  return valArray(@[valFloat(value), valBool(handled)])

# ==============================================================================
# RADIO BUTTON BINDINGS
# ==============================================================================

proc nimini_drawRadioButton*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawRadioButton(layer, x, y, label, isSelected, isFocused)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let label = valueToString(args[3])
  let isSelected = valueToBool(args[4])
  let isFocused = valueToBool(args[5])
  
  drawRadioButton(layer, x, y, label, isSelected, isFocused)
  return valNil()

proc nimini_drawRadioGroup*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawRadioGroup(layer, x, y, options, selected, focusIndex)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  
  var options: seq[string] = @[]
  if args[3].kind == vkArray:
    for v in args[3].arr:
      options.add(valueToString(v))
  
  let selected = valueToInt(args[4])
  let focusIndex = valueToInt(args[5])
  
  drawRadioGroup(layer, x, y, options, selected, focusIndex)
  return valNil()

# ==============================================================================
# DROPDOWN BINDINGS
# ==============================================================================

proc nimini_drawDropdown*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawDropdown(layer, x, y, w, options, selected, isOpen, isFocused)
  if args.len < 8:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  
  var options: seq[string] = @[]
  if args[4].kind == vkArray:
    for v in args[4].arr:
      options.add(valueToString(v))
  
  let selected = valueToInt(args[5])
  let isOpen = valueToBool(args[6])
  let isFocused = valueToBool(args[7])
  
  drawDropdown(layer, x, y, w, options, selected, isOpen, isFocused)
  return valNil()

# ==============================================================================
# LIST BINDINGS
# ==============================================================================

proc nimini_drawList*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawList(layer, x, y, w, h, items, selected, scrollOffset, isFocused)
  if args.len < 9:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  
  var items: seq[string] = @[]
  if args[5].kind == vkArray:
    for v in args[5].arr:
      items.add(valueToString(v))
  
  let selected = valueToInt(args[6])
  let scrollOffset = valueToInt(args[7])
  let isFocused = valueToBool(args[8])
  
  drawList(layer, x, y, w, h, items, selected, scrollOffset, isFocused)
  return valNil()

# ==============================================================================
# TEXT AREA BINDINGS
# ==============================================================================

proc nimini_drawTextArea*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTextArea(layer, x, y, w, h, lines, cursorLine, cursorCol, scrollY, isFocused)
  if args.len < 10:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  
  var lines: seq[string] = @[]
  if args[5].kind == vkArray:
    for v in args[5].arr:
      lines.add(valueToString(v))
  
  let cursorLine = valueToInt(args[6])
  let cursorCol = valueToInt(args[7])
  let scrollY = valueToInt(args[8])
  let isFocused = valueToBool(args[9])
  
  drawTextArea(layer, x, y, w, h, lines, cursorLine, cursorCol, scrollY, isFocused)
  return valNil()

# ==============================================================================
# TOOLTIP BINDINGS
# ==============================================================================

proc nimini_drawTooltip*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTooltip(layer, x, y, text)
  if args.len < 4:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let text = valueToString(args[3])
  
  drawTooltip(layer, x, y, text)
  return valNil()

# ==============================================================================
# TAB CONTAINER BINDINGS
# ==============================================================================

proc nimini_drawTabBar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTabBar(layer, x, y, w, tabs, activeTab)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  
  var tabs: seq[string] = @[]
  if args[4].kind == vkArray:
    for v in args[4].arr:
      tabs.add(valueToString(v))
  
  let activeTab = valueToInt(args[5])
  
  drawTabBar(layer, x, y, w, tabs, activeTab)
  return valNil()

proc nimini_drawTabContent*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTabContent(layer, x, y, w, h, [borderStyle])
  if args.len < 5:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let borderStyle = if args.len >= 6: valueToString(args[5]) else: "single"
  
  drawTabContent(layer, x, y, w, h, borderStyle)
  return valNil()

# ==============================================================================
# FORM LAYOUT BINDINGS
# ==============================================================================

proc nimini_layoutForm*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## layoutForm(startX, startY, labelWidth, fieldWidth, fieldHeight, spacing, fieldCount)
  ## Returns array of maps with keys: labelX, labelY, fieldX, fieldY
  if args.len < 7:
    return valArray(@[])
  
  let startX = valueToInt(args[0])
  let startY = valueToInt(args[1])
  let labelWidth = valueToInt(args[2])
  let fieldWidth = valueToInt(args[3])
  let fieldHeight = valueToInt(args[4])
  let spacing = valueToInt(args[5])
  let fieldCount = valueToInt(args[6])
  
  let positions = layoutForm(startX, startY, labelWidth, fieldWidth, fieldHeight, spacing, fieldCount)
  
  var result: seq[Value] = @[]
  for pos in positions:
    var map = initTable[string, Value]()
    map["labelX"] = valInt(pos.labelX)
    map["labelY"] = valInt(pos.labelY)
    map["fieldX"] = valInt(pos.fieldX)
    map["fieldY"] = valInt(pos.fieldY)
    result.add(valMap(map))
  
  return valArray(result)

# ==============================================================================
# ENHANCED TEXT BOX BINDINGS
# ==============================================================================

proc nimini_drawTextBoxWithScroll*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTextBoxWithScroll(layer, x, y, w, h, content, cursorPos, scrollOffset, isFocused, [borderStyle])
  ## Returns new scroll offset
  if args.len < 9:
    return valInt(0)
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let content = valueToString(args[5])
  let cursorPos = valueToInt(args[6])
  let scrollOffset = valueToInt(args[7])
  let isFocused = valueToBool(args[8])
  let borderStyle = if args.len >= 10: valueToString(args[9]) else: "single"
  
  let newScrollOffset = drawTextBoxWithScroll(layer, x, y, w, h, content, cursorPos, 
                                              scrollOffset, isFocused, borderStyle)
  
  return valInt(newScrollOffset)

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerTUIHelperBindings*(env: ref Env) =
  ## Register all TUI helper functions with nimini
  
  # ==============================================================================
  # PATTERN 1 & 2 & 3: Auto-exposed functions (see tui_helpers.nim)
  # ==============================================================================
  # Simple utilities (int/string/bool)
  register_centerTextX()
  register_centerTextY()
  register_truncateText()
  register_pointInRect()
  
  # Style functions (Style type auto-converted)
  register_drawBoxSimple()
  register_drawBoxSingle()
  register_drawBoxDouble()
  register_drawBoxRounded()
  register_fillBox()
  register_drawCenteredText()
  register_drawLabel()
  register_drawSeparator()
  
  # Layout functions (seq/tuple returns auto-converted)
  register_layoutVertical()
  register_layoutHorizontal()
  register_layoutCentered()
  register_layoutGrid()
  
  # ==============================================================================
  # PATTERN 4: Complex widgets with multi-step logic (manual wrappers)
  # ==============================================================================
  # ==============================================================================
  # PATTERN 4: Complex widgets with multi-step logic (manual wrappers)
  # ==============================================================================
  
  # drawBox: Takes 11 string parameters for custom box characters - keep manual
  registerNative("drawBox", nimini_drawBox,
    storieLibs = @["tui_helpers"],
    description = "Draw a box with custom characters for each part")
  
  registerNative("drawButton", nimini_drawButton,
    storieLibs = @["tui_helpers"],
    description = "Draw a button widget with border style logic")
  
  registerNative("drawTextBox", nimini_drawTextBox,
    storieLibs = @["tui_helpers"],
    description = "Draw a text input box with cursor positioning")
  
  registerNative("drawSlider", nimini_drawSlider,
    storieLibs = @["tui_helpers"],
    description = "Draw a horizontal slider with value normalization")
  
  registerNative("drawCheckBox", nimini_drawCheckBox,
    storieLibs = @["tui_helpers"],
    description = "Draw a checkbox with conditional rendering")
  
  registerNative("drawPanel", nimini_drawPanel,
    storieLibs = @["tui_helpers"],
    description = "Draw a titled panel with fill and border logic")
  
  registerNative("drawProgressBar", nimini_drawProgressBar,
    storieLibs = @["tui_helpers"],
    description = "Draw a progress bar with fill calculation")
  
  # ==============================================================================
  # PATTERN 5: Var parameters (manual wrappers return modified values)
  # ==============================================================================
  
  registerNative("handleTextInput", nimini_handleTextInput,
    storieLibs = @["tui_helpers"],
    description = "Handle text input - returns [cursorPos, content, handled]")
  
  registerNative("handleBackspace", nimini_handleBackspace,
    storieLibs = @["tui_helpers"],
    description = "Handle backspace - returns [cursorPos, content, handled]")
  
  registerNative("handleArrowKeys", nimini_handleArrowKeys,
    storieLibs = @["tui_helpers"],
    description = "Handle arrow keys - returns [value, handled]")
  
  # ==============================================================================
  # PATTERN 6: Seq inputs (manual wrapper for array conversion control)
  # ==============================================================================
  
  registerNative("findClickedWidget", nimini_findClickedWidget,
    storieLibs = @["tui_helpers"],
    description = "Find clicked widget from arrays - returns index or -1")
  
  # Radio buttons
  registerNative("drawRadioButton", nimini_drawRadioButton,
    storieLibs = @["tui_helpers"],
    description = "Draw a single radio button with label")
  
  registerNative("drawRadioGroup", nimini_drawRadioGroup,
    storieLibs = @["tui_helpers"],
    description = "Draw a group of radio buttons")
  
  # Dropdown
  registerNative("drawDropdown", nimini_drawDropdown,
    storieLibs = @["tui_helpers"],
    description = "Draw a dropdown/select widget")
  
  # List
  registerNative("drawList", nimini_drawList,
    storieLibs = @["tui_helpers"],
    description = "Draw a scrollable list with keyboard navigation")
  
  # Text area
  registerNative("drawTextArea", nimini_drawTextArea,
    storieLibs = @["tui_helpers"],
    description = "Draw a multi-line text area with scrolling")
  
  # Tooltip
  registerNative("drawTooltip", nimini_drawTooltip,
    storieLibs = @["tui_helpers"],
    description = "Draw a tooltip (floating help text)")
  
  # Tab container
  registerNative("drawTabBar", nimini_drawTabBar,
    storieLibs = @["tui_helpers"],
    description = "Draw a tab bar at the top of a container")
  
  registerNative("drawTabContent", nimini_drawTabContent,
    storieLibs = @["tui_helpers"],
    description = "Draw the content area below tabs")
  
  # Form layout
  registerNative("layoutForm", nimini_layoutForm,
    storieLibs = @["tui_helpers"],
    description = "Calculate positions for form fields")
  
  # Enhanced text box
  registerNative("drawTextBoxWithScroll", nimini_drawTextBoxWithScroll,
    storieLibs = @["tui_helpers"],
    description = "Draw a text input box with horizontal scrolling")

export registerTUIHelperBindings
