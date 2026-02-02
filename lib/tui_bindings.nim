## Nimini bindings for tui module

import ../nimini/runtime
import tui
import ../src/types
import ../src/input/types  # Import KeyCode type
import storie_types
import ../backends/terminal/termbuffer
import tables

# Global references needed for buffer access (set by tstorie.nim)
var gDefaultLayerRef*: ptr Layer = nil
var gAppStateRef*: ptr AppState = nil
var gStorieStyleSheet*: ptr StyleSheet = nil

proc nimini_initTUI(env: ref Env; args: seq[Value]): Value =
  initTUI()
  return Value(kind: vkNil)

proc nimini_initButton(env: ref Env; args: seq[Value]): Value =
  if args.len < 6:
    return Value(kind: vkNil)
  let id = args[0].i
  let x = args[1].i
  let y = args[2].i
  let w = args[3].i
  let h = args[4].i
  let label = args[5].s
  let group = if args.len > 6: args[6].i else: 0
  initButton(id, x, y, w, h, label, group)
  return Value(kind: vkNil)

proc nimini_initLabel(env: ref Env; args: seq[Value]): Value =
  if args.len < 6:
    return Value(kind: vkNil)
  let id = args[0].i
  let x = args[1].i
  let y = args[2].i
  let w = args[3].i
  let h = args[4].i
  let text = args[5].s
  let align = if args.len > 6: args[6].s else: "left"
  let group = if args.len > 7: args[7].i else: 0
  initLabel(id, x, y, w, h, text, align, group)
  return Value(kind: vkNil)

proc nimini_initCheckbox(env: ref Env; args: seq[Value]): Value =
  if args.len < 6:
    return Value(kind: vkNil)
  let id = args[0].i
  let x = args[1].i
  let y = args[2].i
  let w = args[3].i
  let h = args[4].i
  let label = args[5].s
  let checked = if args.len > 6: args[6].b else: false
  let group = if args.len > 7: args[7].i else: 0
  initCheckbox(id, x, y, w, h, label, checked, group)
  return Value(kind: vkNil)

proc nimini_initSlider(env: ref Env; args: seq[Value]): Value =
  if args.len < 8:
    return Value(kind: vkNil)
  let id = args[0].i
  let x = args[1].i
  let y = args[2].i
  let w = args[3].i
  let h = args[4].i
  let label = args[5].s
  let minVal = args[6].i
  let maxVal = args[7].i
  let initialVal = if args.len > 8: args[8].i else: minVal
  let group = if args.len > 9: args[9].i else: 0
  initSlider(id, x, y, w, h, label, minVal, maxVal, initialVal, group)
  return Value(kind: vkNil)

proc nimini_updateTUI(env: ref Env; args: seq[Value]): Value =
  if args.len < 3:
    return Value(kind: vkNil)
  let mouseX = args[0].i
  let mouseY = args[1].i
  let mousePressed = args[2].b
  updateTUI(mouseX, mouseY, mousePressed)
  return Value(kind: vkNil)

proc nimini_drawTUI(env: ref Env; args: seq[Value]): Value =
  # Get buffer from layer 0 (default layer)
  if gAppStateRef.isNil or gDefaultLayerRef.isNil:
    return Value(kind: vkNil)
  
  let buffer = addr gDefaultLayerRef[].buffer
  
  # Get style
  let styleName = if args.len > 0: args[0].s else: "button"
  var style = defaultStyle()
  if not gStorieStyleSheet.isNil and gStorieStyleSheet[].hasKey(styleName):
    let sc = gStorieStyleSheet[][styleName]
    style = Style(
      fg: rgb(sc.fg.r, sc.fg.g, sc.fg.b),
      bg: rgb(sc.bg.r, sc.bg.g, sc.bg.b),
      bold: sc.bold,
      underline: sc.underline,
      italic: sc.italic,
      dim: sc.dim
    )
  
  drawTUI(buffer, style)
  return Value(kind: vkNil)

# Group management
proc nimini_setGroupVisible(env: ref Env; args: seq[Value]): Value =
  if args.len < 2:
    return Value(kind: vkNil)
  let group = args[0].i
  let visible = args[1].b
  setGroupVisible(group, visible)
  return Value(kind: vkNil)

proc nimini_isGroupVisible(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkBool, b: false)
  let group = args[0].i
  return Value(kind: vkBool, b: isGroupVisible(group))

# State queries
proc nimini_wasClicked(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkBool, b: false)
  let id = args[0].i
  return Value(kind: vkBool, b: wasClicked(id))

proc nimini_isHovered(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkBool, b: false)
  let id = args[0].i
  return Value(kind: vkBool, b: isHovered(id))

proc nimini_wasToggled(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkBool, b: false)
  let id = args[0].i
  return Value(kind: vkBool, b: wasToggled(id))

proc nimini_isChecked(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkBool, b: false)
  let id = args[0].i
  return Value(kind: vkBool, b: isChecked(id))

proc nimini_getSliderValue(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkInt, i: 0)
  let id = args[0].i
  return Value(kind: vkInt, i: getSliderValue(id))

proc nimini_setSliderValue(env: ref Env; args: seq[Value]): Value =
  if args.len < 2:
    return Value(kind: vkNil)
  let id = args[0].i
  let value = args[1].i
  setSliderValue(id, value)
  return Value(kind: vkNil)

# Widget visibility
proc nimini_setWidgetVisible(env: ref Env; args: seq[Value]): Value =
  if args.len < 2:
    return Value(kind: vkNil)
  let id = args[0].i
  let visible = args[1].b
  setWidgetVisible(id, visible)
  return Value(kind: vkNil)

proc nimini_isWidgetVisible(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkBool, b: false)
  let id = args[0].i
  return Value(kind: vkBool, b: isWidgetVisible(id))

# Text updates
proc nimini_setButtonLabel(env: ref Env; args: seq[Value]): Value =
  if args.len < 2:
    return Value(kind: vkNil)
  let id = args[0].i
  let label = args[1].s
  setButtonLabel(id, label)
  return Value(kind: vkNil)

proc nimini_setLabelText(env: ref Env; args: seq[Value]): Value =
  if args.len < 2:
    return Value(kind: vkNil)
  let id = args[0].i
  let text = args[1].s
  setLabelText(id, text)
  return Value(kind: vkNil)

proc nimini_handleTUIKey(env: ref Env; args: seq[Value]): Value =
  if args.len < 2:
    return Value(kind: vkNil)
  let keyCode = KeyCode(args[0].i)
  let action = args[1].s
  
  # Optional third parameter: modifiers array
  var mods: set[uint8] = {}
  if args.len >= 3 and args[2].kind == vkArray:
    for modVal in args[2].arr:
      if modVal.kind == vkString:
        case modVal.s
        of "shift": mods.incl(0'u8)  # ModShift
        of "alt": mods.incl(1'u8)    # ModAlt
        of "ctrl": mods.incl(2'u8)   # ModCtrl
        of "super": mods.incl(3'u8) # ModSuper
        else: discard
  
  handleTUIKey(keyCode, action, mods)
  return Value(kind: vkNil)

proc nimini_getFocusedWidget(env: ref Env; args: seq[Value]): Value =
  return Value(kind: vkInt, i: getFocusedWidget())

proc nimini_setFocusedWidget(env: ref Env; args: seq[Value]): Value =
  if args.len < 1:
    return Value(kind: vkNil)
  let id = args[0].i
  setFocusedWidget(id)
  return Value(kind: vkNil)

proc nimini_clearFocus(env: ref Env; args: seq[Value]): Value =
  clearFocus()
  return Value(kind: vkNil)

proc registerTUIBindings*(env: ref Env) =
  ## Register all TUI functions with Nimini - Note: global references must be set separately!
  registerNative("initTUI", nimini_initTUI,
    storieLibs = @["tui"],
    description = "Initialize the TUI system: initTUI()")
  
  registerNative("initButton", nimini_initButton,
    storieLibs = @["tui"],
    description = "Initialize a button: initButton(id, x, y, w, h, label, [group])")
  
  registerNative("initLabel", nimini_initLabel,
    storieLibs = @["tui"],
    description = "Initialize a label: initLabel(id, x, y, w, h, text, [align], [group])")
  
  registerNative("initCheckbox", nimini_initCheckbox,
    storieLibs = @["tui"],
    description = "Initialize a checkbox: initCheckbox(id, x, y, w, h, label, [checked], [group])")
  
  registerNative("initSlider", nimini_initSlider,
    storieLibs = @["tui"],
    description = "Initialize a slider: initSlider(id, x, y, w, h, label, min, max, [initial], [group])")
  
  registerNative("updateTUI", nimini_updateTUI,
    storieLibs = @["tui"],
    description = "Update all widget states: updateTUI(mouseX, mouseY, mousePressed)")
  
  registerNative("drawTUI", nimini_drawTUI,
    storieLibs = @["tui"],
    description = "Draw all visible widgets: drawTUI([styleName])")
  
  # Group management
  registerNative("setGroupVisible", nimini_setGroupVisible,
    storieLibs = @["tui"],
    description = "Set group visibility: setGroupVisible(group, visible)")
  
  registerNative("isGroupVisible", nimini_isGroupVisible,
    storieLibs = @["tui"],
    description = "Check group visibility: isGroupVisible(group)")
  
  # State queries
  registerNative("wasClicked", nimini_wasClicked,
    storieLibs = @["tui"],
    description = "Check if button was clicked: wasClicked(id)")
  
  registerNative("isHovered", nimini_isHovered,
    storieLibs = @["tui"],
    description = "Check if widget is hovered: isHovered(id)")
  
  registerNative("wasToggled", nimini_wasToggled,
    storieLibs = @["tui"],
    description = "Check if checkbox was toggled: wasToggled(id)")
  
  registerNative("isChecked", nimini_isChecked,
    storieLibs = @["tui"],
    description = "Get checkbox state: isChecked(id)")
  
  registerNative("getSliderValue", nimini_getSliderValue,
    storieLibs = @["tui"],
    description = "Get slider value: getSliderValue(id)")
  
  registerNative("setSliderValue", nimini_setSliderValue,
    storieLibs = @["tui"],
    description = "Set slider value: setSliderValue(id, value)")
  
  # Widget visibility
  registerNative("setWidgetVisible", nimini_setWidgetVisible,
    storieLibs = @["tui"],
    description = "Set widget visibility: setWidgetVisible(id, visible)")
  
  registerNative("isWidgetVisible", nimini_isWidgetVisible,
    storieLibs = @["tui"],
    description = "Check widget visibility: isWidgetVisible(id)")
  
  # Text updates
  registerNative("setButtonLabel", nimini_setButtonLabel,
    storieLibs = @["tui"],
    description = "Update button label: setButtonLabel(id, label)")
  
  registerNative("setLabelText", nimini_setLabelText,
    storieLibs = @["tui"],
    description = "Update label text: setLabelText(id, text)")
  
  # Keyboard input and focus management
  registerNative("handleTUIKey", nimini_handleTUIKey,
    storieLibs = @["tui"],
    description = "Handle keyboard input: handleTUIKey(keyCode, action[, mods])")
  
  registerNative("getFocusedWidget", nimini_getFocusedWidget,
    storieLibs = @["tui"],
    description = "Get focused widget ID: getFocusedWidget()")
  
  registerNative("setFocusedWidget", nimini_setFocusedWidget,
    storieLibs = @["tui"],
    description = "Set focused widget: setFocusedWidget(id)")
  
  registerNative("clearFocus", nimini_clearFocus,
    storieLibs = @["tui"],
    description = "Clear keyboard focus: clearFocus()")
