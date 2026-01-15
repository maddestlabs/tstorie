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
import ../src/binding_utils  # For valueToStyle, toInt, toBool, toFloat
import std/[tables, strutils]
import tui_helpers  # Import the TUI helper functions

# ==============================================================================
# BOX DRAWING BINDINGS
# ==============================================================================

proc nimini_drawBox*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawBox(layer, x, y, w, h, style, boxType)
  ## Generic box drawing with style parameter: "single", "double", or "rounded"
  if args.len < 7:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  let h = toInt(args[4])
  let style = valueToStyle(args[5])
  let boxType = $args[6]
  
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
  
  let mouseX = toInt(args[0])
  let mouseY = toInt(args[1])
  
  # Convert arrays
  var widgetX: seq[int] = @[]
  var widgetY: seq[int] = @[]
  var widgetW: seq[int] = @[]
  var widgetH: seq[int] = @[]
  
  if args[2].kind == vkArray:
    for v in args[2].arr:
      widgetX.add(toInt(v))
  
  if args[3].kind == vkArray:
    for v in args[3].arr:
      widgetY.add(toInt(v))
  
  if args[4].kind == vkArray:
    for v in args[4].arr:
      widgetW.add(toInt(v))
  
  if args[5].kind == vkArray:
    for v in args[5].arr:
      widgetH.add(toInt(v))
  
  let result = findClickedWidget(mouseX, mouseY, widgetX, widgetY, widgetW, widgetH)
  return valInt(result)

# ==============================================================================
# INPUT HANDLING BINDINGS
# ==============================================================================

proc nimini_handleTextInput*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## handleTextInput(text, cursorPos, content) -> [newCursorPos, newContent, handled]
  if args.len < 3:
    return valArray(@[valInt(0), valString(""), valBool(false)])
  
  let text = $args[0]
  var cursorPos = toInt(args[1])
  var content = $args[2]
  
  let handled = handleTextInput(text, cursorPos, content)
  
  return valArray(@[valInt(cursorPos), valString(content), valBool(handled)])

proc nimini_handleBackspace*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## handleBackspace(cursorPos, content) -> [newCursorPos, newContent, handled]
  if args.len < 2:
    return valArray(@[valInt(0), valString(""), valBool(false)])
  
  var cursorPos = toInt(args[0])
  var content = $args[1]
  
  let handled = handleBackspace(cursorPos, content)
  
  return valArray(@[valInt(cursorPos), valString(content), valBool(handled)])

proc nimini_handleArrowKeys*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## handleArrowKeys(keyCode, value, minVal, maxVal, step) -> [newValue, handled]
  if args.len < 5:
    return valArray(@[valFloat(0.0), valBool(false)])
  
  let keyCode = toInt(args[0])
  var value = toFloat(args[1])
  let minVal = toFloat(args[2])
  let maxVal = toFloat(args[3])
  let step = toFloat(args[4])
  
  let handled = handleArrowKeys(keyCode, value, minVal, maxVal, step)
  
  return valArray(@[valFloat(value), valBool(handled)])

# ==============================================================================
# RADIO BUTTON BINDINGS
# ==============================================================================

proc nimini_drawRadioGroup*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawRadioGroup(layer, x, y, options, selected, focusIndex)
  if args.len < 6:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  
  var options: seq[string] = @[]
  if args[3].kind == vkArray:
    for v in args[3].arr:
      options.add($v)
  
  let selected = toInt(args[4])
  let focusIndex = toInt(args[5])
  
  drawRadioGroup(layer, x, y, options, selected, focusIndex)
  return valNil()

# ==============================================================================
# DROPDOWN BINDINGS
# ==============================================================================

proc nimini_drawDropdown*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawDropdown(layer, x, y, w, options, selected, isOpen, isFocused)
  if args.len < 8:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  
  var options: seq[string] = @[]
  if args[4].kind == vkArray:
    for v in args[4].arr:
      options.add($v)
  
  let selected = toInt(args[5])
  let isOpen = toBool(args[6])
  let isFocused = toBool(args[7])
  
  drawDropdown(layer, x, y, w, options, selected, isOpen, isFocused)
  return valNil()

# ==============================================================================
# LIST BINDINGS
# ==============================================================================

proc nimini_drawList*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawList(layer, x, y, w, h, items, selected, scrollOffset, isFocused)
  if args.len < 9:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  let h = toInt(args[4])
  
  var items: seq[string] = @[]
  if args[5].kind == vkArray:
    for v in args[5].arr:
      items.add($v)
  
  let selected = toInt(args[6])
  let scrollOffset = toInt(args[7])
  let isFocused = toBool(args[8])
  
  drawList(layer, x, y, w, h, items, selected, scrollOffset, isFocused)
  return valNil()

# ==============================================================================
# TEXT AREA BINDINGS
# ==============================================================================

proc nimini_drawTextArea*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTextArea(layer, x, y, w, h, lines, cursorLine, cursorCol, scrollY, isFocused)
  if args.len < 10:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  let h = toInt(args[4])
  
  var lines: seq[string] = @[]
  if args[5].kind == vkArray:
    for v in args[5].arr:
      lines.add($v)
  
  let cursorLine = toInt(args[6])
  let cursorCol = toInt(args[7])
  let scrollY = toInt(args[8])
  let isFocused = toBool(args[9])
  
  drawTextArea(layer, x, y, w, h, lines, cursorLine, cursorCol, scrollY, isFocused)
  return valNil()

# ==============================================================================
# TOOLTIP BINDINGS
# ==============================================================================

proc nimini_drawTooltip*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTooltip(layer, x, y, text)
  if args.len < 4:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let text = $args[3]
  
  drawTooltip(layer, x, y, text)
  return valNil()

# ==============================================================================
# TAB CONTAINER BINDINGS
# ==============================================================================

proc nimini_drawTabBar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTabBar(layer, x, y, w, tabs, activeTab)
  if args.len < 6:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  
  var tabs: seq[string] = @[]
  if args[4].kind == vkArray:
    for v in args[4].arr:
      tabs.add($v)
  
  let activeTab = toInt(args[5])
  
  drawTabBar(layer, x, y, w, tabs, activeTab)
  return valNil()

proc nimini_drawTabContent*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## drawTabContent(layer, x, y, w, h, [borderStyle])
  if args.len < 5:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  let h = toInt(args[4])
  let borderStyle = if args.len >= 6: $args[5] else: "single"
  
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
  
  let startX = toInt(args[0])
  let startY = toInt(args[1])
  let labelWidth = toInt(args[2])
  let fieldWidth = toInt(args[3])
  let fieldHeight = toInt(args[4])
  let spacing = toInt(args[5])
  let fieldCount = toInt(args[6])
  
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
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  let h = toInt(args[4])
  let content = $args[5]
  let cursorPos = toInt(args[6])
  let scrollOffset = toInt(args[7])
  let isFocused = toBool(args[8])
  let borderStyle = if args.len >= 10: $args[9] else: "single"
  
  let newScrollOffset = drawTextBoxWithScroll(layer, x, y, w, h, content, cursorPos, 
                                              scrollOffset, isFocused, borderStyle)
  
  return valInt(newScrollOffset)

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerTUIHelperBindings*(env: ref Env) =
  ## Register all TUI helper functions with nimini
  
  # ==============================================================================
  # AUTO-EXPOSED FUNCTIONS (see tui_helpers.nim with {.autoExpose: "tui".})
  # ==============================================================================
  # These are automatically handled by auto_bindings:
  # - Simple utilities: centerTextX, centerTextY, truncateText, pointInRect
  # - Box drawing: drawBoxSimple, drawBoxSingle, drawBoxDouble, drawBoxRounded, fillBox
  # - Labels: drawLabel, drawCenteredText, drawSeparator
  # - Layout helpers: layoutVertical, layoutHorizontal, layoutCentered, layoutGrid
  # - Simple widgets: drawButton, drawTextBox, drawSlider, drawCheckBox, 
  #                   drawPanel, drawProgressBar, drawRadioButton
  # 
  # These functions are registered by initTUIHelpersModule() in tui_helpers.nim
  
  # ==============================================================================
  # COMPLEX MANUAL WRAPPERS (kept here - not auto-exposeable)
  # ==============================================================================
  
  # drawBox: Takes 11 string parameters for custom box characters
  registerNative("drawBox", nimini_drawBox,
    storieLibs = @["tui_helpers"],
    description = "Draw a box with custom characters for each part")
  
  # ==============================================================================
  # VAR PARAMETERS (manual wrappers return modified values)
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
  # SEQ/ARRAY INPUTS (manual wrappers for complex array handling)
  # ==============================================================================
  
  registerNative("findClickedWidget", nimini_findClickedWidget,
    storieLibs = @["tui_helpers"],
    description = "Find clicked widget from arrays - returns index or -1")
  
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
