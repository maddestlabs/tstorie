## Nimini bindings for TUI Components
##
## Exposes interactive UI widgets to nimini scripts, enabling
## rapid prototyping and the Rebuild Pattern workflow.

import ../nimini
import ../nimini/runtime
import tui
import textfield
import std/[tables, strutils]

when not declared(Style):
  import ../src/types

# Global widget manager (set by registerTUIBindings)
var gWidgetManager: WidgetManager = nil

# Global references for rendering (set by registerTUIBindings)
type DrawProc* = proc(layer, x, y: int, char: string, style: Style)
var gDrawProc: DrawProc = nil
var gCurrentLayer: ptr Layer = nil

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
  ## Convert nimini value to Style (simplified - could be expanded)
  return Style(
    fg: rgb(255, 255, 255),
    bg: rgb(0, 0, 0),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

# ==============================================================================
# WIDGET MANAGER BINDINGS
# ==============================================================================

proc nimini_newWidgetManager*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new widget manager. No args needed.
  ## Returns: pointer to WidgetManager
  if gWidgetManager.isNil:
    gWidgetManager = newWidgetManager()
  return valPointer(cast[pointer](gWidgetManager))

proc nimini_addWidget*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Add a widget to the manager. Args: widget (pointer)
  if args.len < 1 or gWidgetManager.isNil:
    return valNil()
  
  let widget = cast[Widget](args[0].ptrVal)
  if not widget.isNil:
    gWidgetManager.addWidget(widget)
  
  return valNil()

proc nimini_removeWidget*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Remove a widget by ID. Args: widgetId (string)
  if args.len < 1 or gWidgetManager.isNil:
    return valNil()
  
  let widgetId = valueToString(args[0])
  gWidgetManager.removeWidget(widgetId)
  
  return valNil()

proc nimini_focusWidget*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Focus a widget by ID. Args: widgetId (string)
  if args.len < 1 or gWidgetManager.isNil:
    return valNil()
  
  let widgetId = valueToString(args[0])
  gWidgetManager.focusWidgetById(widgetId)
  
  return valNil()

proc nimini_updateWidgets*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update all widgets. Args: deltaTime (float, optional)
  if gWidgetManager.isNil:
    return valNil()
  
  let dt = if args.len > 0: valueToFloat(args[0]) else: 0.016
  
  for widget in gWidgetManager.widgets:
    if not widget.isNil:
      widget.update(dt)
  
  return valNil()

proc nimini_renderWidgets*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render all widgets to the current layer. No args.
  if gWidgetManager.isNil or gCurrentLayer.isNil:
    return valNil()
  
  for widget in gWidgetManager.widgets:
    if not widget.isNil and widget.visible:
      widget.render(gCurrentLayer[])
  
  return valNil()

proc nimini_handleWidgetInput*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle input for widgets. Args: event (table/object representation)
  ## Returns: bool (true if event was consumed)
  if gWidgetManager.isNil:
    return valBool(false)
  
  # TODO: Convert nimini event to InputEvent
  # For now, return false
  return valBool(false)

# ==============================================================================
# BUTTON WIDGET BINDINGS
# ==============================================================================

proc nimini_newButton*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new button. Args: id (string), x (int), y (int), width (int), height (int), label (string, optional)
  ## Returns: pointer to Button
  if args.len < 5:
    return valNil()
  
  let id = valueToString(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let width = valueToInt(args[3])
  let height = valueToInt(args[4])
  let label = if args.len > 5: valueToString(args[5]) else: "Button"
  
  let button = newButton(id, x, y, width, height, label)
  return valPointer(cast[pointer](button))

proc nimini_buttonSetLabel*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set button label. Args: button (pointer), label (string)
  if args.len < 2:
    return valNil()
  
  let button = cast[Button](args[0].ptrVal)
  let label = valueToString(args[1])
  
  if not button.isNil:
    button.setLabel(label)
  
  return valNil()

proc nimini_buttonSetOnClick*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set button onClick callback. Args: button (pointer), callback (function)
  ## Note: Callback handling would need to be implemented with nimini function calls
  if args.len < 2:
    return valNil()
  
  # TODO: Implement callback registration
  # For now, just acknowledge the call
  return valNil()

# ==============================================================================
# SLIDER WIDGET BINDINGS
# ==============================================================================

proc nimini_newSlider*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new horizontal slider. Args: id (string), x (int), y (int), length (int), minVal (float), maxVal (float)
  ## Returns: pointer to Slider
  if args.len < 6:
    return valNil()
  
  let id = valueToString(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let length = valueToInt(args[3])
  let minVal = valueToFloat(args[4])
  let maxVal = valueToFloat(args[5])
  
  let slider = newSlider(id, x, y, length, minVal, maxVal)
  return valPointer(cast[pointer](slider))

proc nimini_newVerticalSlider*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new vertical slider. Args: id (string), x (int), y (int), length (int), minVal (float), maxVal (float)
  ## Returns: pointer to Slider
  if args.len < 6:
    return valNil()
  
  let id = valueToString(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let length = valueToInt(args[3])
  let minVal = valueToFloat(args[4])
  let maxVal = valueToFloat(args[5])
  
  let slider = newVerticalSlider(id, x, y, length, minVal, maxVal)
  return valPointer(cast[pointer](slider))

proc nimini_sliderGetValue*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get slider value. Args: slider (pointer)
  ## Returns: float
  if args.len < 1:
    return valFloat(0.0)
  
  let slider = cast[Slider](args[0].ptrVal)
  if slider.isNil:
    return valFloat(0.0)
  
  return valFloat(slider.value)

proc nimini_sliderSetValue*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set slider value. Args: slider (pointer), value (float)
  if args.len < 2:
    return valNil()
  
  let slider = cast[Slider](args[0].ptrVal)
  let value = valueToFloat(args[1])
  
  if not slider.isNil:
    slider.setValue(value)
  
  return valNil()

proc nimini_sliderSetShowValue*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Show/hide numeric value display. Args: slider (pointer), show (bool)
  if args.len < 2:
    return valNil()
  
  let slider = cast[Slider](args[0].ptrVal)
  let show = valueToBool(args[1])
  
  if not slider.isNil:
    slider.showValue = show
  
  return valNil()

proc nimini_sliderSetChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set slider visual characters. Args: slider (pointer), trackChar (string), fillChar (string), handleChar (string)
  if args.len < 4:
    return valNil()
  
  let slider = cast[Slider](args[0].ptrVal)
  let trackChar = valueToString(args[1])
  let fillChar = valueToString(args[2])
  let handleChar = valueToString(args[3])
  
  if not slider.isNil:
    slider.trackChar = trackChar
    slider.fillChar = fillChar
    slider.handleChar = handleChar
  
  return valNil()

# ==============================================================================
# TEXTFIELD WIDGET BINDINGS
# ==============================================================================

proc nimini_newTextField*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new text field. Args: x (int), y (int), width (int)
  ## Returns: pointer to TextField
  if args.len < 3:
    return valNil()
  
  let x = valueToInt(args[0])
  let y = valueToInt(args[1])
  let width = valueToInt(args[2])
  
  let textField = newTextField(x, y, width)
  return valPointer(cast[pointer](textField))

proc nimini_textFieldGetText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get text field content. Args: textField (pointer)
  ## Returns: string
  if args.len < 1:
    return valString("")
  
  let tf = cast[TextField](args[0].ptrVal)
  if tf.isNil:
    return valString("")
  
  return valString(tf.text)

proc nimini_textFieldSetText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set text field content. Args: textField (pointer), text (string)
  if args.len < 2:
    return valNil()
  
  let tf = cast[TextField](args[0].ptrVal)
  let text = valueToString(args[1])
  
  if not tf.isNil:
    tf.setText(text)
  
  return valNil()

proc nimini_textFieldClear*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Clear text field. Args: textField (pointer)
  if args.len < 1:
    return valNil()
  
  let tf = cast[TextField](args[0].ptrVal)
  if not tf.isNil:
    tf.clear()
  
  return valNil()

proc nimini_textFieldSetFocused*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set text field focus state. Args: textField (pointer), focused (bool)
  if args.len < 2:
    return valNil()
  
  let tf = cast[TextField](args[0].ptrVal)
  let focused = valueToBool(args[1])
  
  if not tf.isNil:
    tf.focused = focused
  
  return valNil()

# ==============================================================================
# CHECKBOX WIDGET BINDINGS
# ==============================================================================

proc nimini_newCheckBox*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new checkbox. Args: id (string), x (int), y (int), label (string, optional), checked (bool, optional)
  ## Returns: pointer to CheckBox
  if args.len < 3:
    return valNil()
  
  let id = valueToString(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let label = if args.len > 3: valueToString(args[3]) else: ""
  let checked = if args.len > 4: valueToBool(args[4]) else: false
  
  let checkBox = newCheckBox(id, x, y, label, checked)
  return valPointer(cast[pointer](checkBox))

proc nimini_newRadioButton*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new radio button. Args: id (string), x (int), y (int), label (string, optional), group (string, optional)
  ## Returns: pointer to CheckBox (in radio mode)
  if args.len < 3:
    return valNil()
  
  let id = valueToString(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let label = if args.len > 3: valueToString(args[3]) else: ""
  let group = if args.len > 4: valueToString(args[4]) else: "default"
  
  let radioButton = newRadioButton(id, x, y, label, group)
  return valPointer(cast[pointer](radioButton))

proc nimini_checkBoxIsChecked*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get checkbox state. Args: checkBox (pointer)
  ## Returns: bool
  if args.len < 1:
    return valBool(false)
  
  let cb = cast[CheckBox](args[0].ptrVal)
  if cb.isNil:
    return valBool(false)
  
  return valBool(cb.checked)

proc nimini_checkBoxSetChecked*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set checkbox state. Args: checkBox (pointer), checked (bool)
  if args.len < 2:
    return valNil()
  
  let cb = cast[CheckBox](args[0].ptrVal)
  let checked = valueToBool(args[1])
  
  if not cb.isNil:
    cb.setChecked(checked)
  
  return valNil()

proc nimini_checkBoxToggle*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Toggle checkbox state. Args: checkBox (pointer)
  if args.len < 1:
    return valNil()
  
  let cb = cast[CheckBox](args[0].ptrVal)
  if not cb.isNil:
    cb.toggle()
  
  return valNil()

proc nimini_checkBoxSetChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set checkbox visual characters. Args: checkBox (pointer), checkedChar (string), uncheckedChar (string)
  if args.len < 3:
    return valNil()
  
  let cb = cast[CheckBox](args[0].ptrVal)
  let checkedChar = valueToString(args[1])
  let uncheckedChar = valueToString(args[2])
  
  if not cb.isNil:
    cb.checkedChar = checkedChar
    cb.uncheckedChar = uncheckedChar
  
  return valNil()

# ==============================================================================
# PROGRESSBAR WIDGET BINDINGS
# ==============================================================================

# proc nimini_newProgressBar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Create a new progress bar. Args: id (string), x (int), y (int), length (int), orientation (string, optional: "horizontal" or "vertical")
#   ## Returns: pointer to ProgressBar
#   if args.len < 4:
#     return valNil()
#   
#   let id = valueToString(args[0])
#   let x = valueToInt(args[1])
#   let y = valueToInt(args[2])
#   let length = valueToInt(args[3])
#   
#   var orientation = Horizontal
#   if args.len > 4:
#     let orientStr = valueToString(args[4]).toLowerAscii()
#     if orientStr == "vertical" or orientStr == "v":
#       orientation = Vertical
#   
#   let progressBar = newProgressBar(id, x, y, length, orientation)
#   return valPointer(cast[pointer](progressBar))
# 
# proc nimini_progressBarSetValue*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Set progress bar value. Args: progressBar (pointer), value (float)
#   if args.len < 2:
#     return valNil()
#   
#   let pb = cast[ProgressBar](args[0].ptrVal)
#   let value = valueToFloat(args[1])
#   
#   if not pb.isNil:
#     pb.setValue(value)
#   
#   return valNil()
# 
# proc nimini_progressBarSetProgress*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Set progress (normalized 0.0-1.0). Args: progressBar (pointer), progress (float)
#   if args.len < 2:
#     return valNil()
#   
#   let pb = cast[ProgressBar](args[0].ptrVal)
#   let progress = valueToFloat(args[1])
#   
#   if not pb.isNil:
#     pb.setProgress(progress)
#   
#   return valNil()
# 
# proc nimini_progressBarGetProgress*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Get progress (normalized 0.0-1.0). Args: progressBar (pointer)
#   ## Returns: float
#   if args.len < 1:
#     return valFloat(0.0)
#   
#   let pb = cast[ProgressBar](args[0].ptrVal)
#   if pb.isNil:
#     return valFloat(0.0)
#   
#   return valFloat(pb.getProgress())
# 
# proc nimini_progressBarSetText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Set progress bar overlay text. Args: progressBar (pointer), text (string)
#   if args.len < 2:
#     return valNil()
#   
#   let pb = cast[ProgressBar](args[0].ptrVal)
#   let text = valueToString(args[1])
#   
#   if not pb.isNil:
#     pb.text = text
#   
#   return valNil()
# 
# proc nimini_progressBarSetShowPercentage*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Show/hide percentage display. Args: progressBar (pointer), show (bool)
#   if args.len < 2:
#     return valNil()
#   
#   let pb = cast[ProgressBar](args[0].ptrVal)
#   let show = valueToBool(args[1])
#   
#   if not pb.isNil:
#     pb.showPercentage = show
#   
#   return valNil()
# 
# proc nimini_progressBarSetChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
#   ## Set progress bar visual characters. Args: progressBar (pointer), emptyChar (string), fillChar (string), leftCap (string, optional), rightCap (string, optional)
#   if args.len < 3:
#     return valNil()
#   
#   let pb = cast[ProgressBar](args[0].ptrVal)
#   let emptyChar = valueToString(args[1])
#   let fillChar = valueToString(args[2])
#   
#   if not pb.isNil:
#     pb.emptyChar = emptyChar
#     pb.fillChar = fillChar
#     
#     if args.len > 3:
#       pb.leftCap = valueToString(args[3])
#     if args.len > 4:
#       pb.rightCap = valueToString(args[4])
#   
#   return valNil()

# ==============================================================================
# GENERIC WIDGET OPERATIONS
# ==============================================================================

proc nimini_widgetSetVisible*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set widget visibility. Args: widget (pointer), visible (bool)
  if args.len < 2:
    return valNil()
  
  let widget = cast[Widget](args[0].ptrVal)
  let visible = valueToBool(args[1])
  
  if not widget.isNil:
    widget.setVisible(visible)
  
  return valNil()

proc nimini_widgetSetEnabled*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set widget enabled state. Args: widget (pointer), enabled (bool)
  if args.len < 2:
    return valNil()
  
  let widget = cast[Widget](args[0].ptrVal)
  let enabled = valueToBool(args[1])
  
  if not widget.isNil:
    widget.setEnabled(enabled)
  
  return valNil()

proc nimini_widgetSetPosition*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set widget position. Args: widget (pointer), x (int), y (int)
  if args.len < 3:
    return valNil()
  
  let widget = cast[Widget](args[0].ptrVal)
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  
  if not widget.isNil:
    widget.setPosition(x, y)
  
  return valNil()

proc nimini_widgetSetSize*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set widget size. Args: widget (pointer), width (int), height (int)
  if args.len < 3:
    return valNil()
  
  let widget = cast[Widget](args[0].ptrVal)
  let width = valueToInt(args[1])
  let height = valueToInt(args[2])
  
  if not widget.isNil:
    widget.setSize(width, height)
  
  return valNil()

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerTUIBindings*(drawProc: DrawProc, layer: ptr Layer) =
  ## Register all TUI widget bindings with nimini runtime
  ## Call this during initialization
  gDrawProc = drawProc
  gCurrentLayer = layer
  
  # Initialize global widget manager
  if gWidgetManager.isNil:
    gWidgetManager = newWidgetManager()
  
  # Widget Manager
  registerNative("newWidgetManager", nimini_newWidgetManager,
    storieLibs = @["tui"],
    description = "Create a widget manager")
  
  registerNative("addWidget", nimini_addWidget,
    storieLibs = @["tui"],
    description = "Add widget to manager")
  
  registerNative("removeWidget", nimini_removeWidget,
    storieLibs = @["tui"],
    description = "Remove widget by ID")
  
  registerNative("focusWidget", nimini_focusWidget,
    storieLibs = @["tui"],
    description = "Focus widget by ID")
  
  registerNative("updateWidgets", nimini_updateWidgets,
    storieLibs = @["tui"],
    description = "Update all widgets")
  
  registerNative("renderWidgets", nimini_renderWidgets,
    storieLibs = @["tui"],
    description = "Render all widgets to current layer")
  
  # Button
  registerNative("newButton", nimini_newButton,
    storieLibs = @["tui"],
    description = "Create a button widget")
  
  registerNative("buttonSetLabel", nimini_buttonSetLabel,
    storieLibs = @["tui"],
    description = "Set button label text")
  
  # Slider
  registerNative("newSlider", nimini_newSlider,
    storieLibs = @["tui"],
    description = "Create a horizontal slider widget")
  
  registerNative("newVerticalSlider", nimini_newVerticalSlider,
    storieLibs = @["tui"],
    description = "Create a vertical slider widget")
  
  registerNative("sliderGetValue", nimini_sliderGetValue,
    storieLibs = @["tui"],
    description = "Get slider current value")
  
  registerNative("sliderSetValue", nimini_sliderSetValue,
    storieLibs = @["tui"],
    description = "Set slider value")
  
  registerNative("sliderSetShowValue", nimini_sliderSetShowValue,
    storieLibs = @["tui"],
    description = "Show/hide slider numeric display")
  
  registerNative("sliderSetChars", nimini_sliderSetChars,
    storieLibs = @["tui"],
    description = "Customize slider visual characters")
  
  # TextField
  registerNative("newTextField", nimini_newTextField,
    storieLibs = @["tui"],
    description = "Create a text input field")
  
  registerNative("textFieldGetText", nimini_textFieldGetText,
    storieLibs = @["tui"],
    description = "Get text field content")
  
  registerNative("textFieldSetText", nimini_textFieldSetText,
    storieLibs = @["tui"],
    description = "Set text field content")
  
  registerNative("textFieldClear", nimini_textFieldClear,
    storieLibs = @["tui"],
    description = "Clear text field")
  
  registerNative("textFieldSetFocused", nimini_textFieldSetFocused,
    storieLibs = @["tui"],
    description = "Set text field focus state")
  
  # CheckBox
  registerNative("newCheckBox", nimini_newCheckBox,
    storieLibs = @["tui"],
    description = "Create a checkbox widget")
  
  registerNative("newRadioButton", nimini_newRadioButton,
    storieLibs = @["tui"],
    description = "Create a radio button widget")
  
  registerNative("checkBoxIsChecked", nimini_checkBoxIsChecked,
    storieLibs = @["tui"],
    description = "Get checkbox/radio state")
  
  registerNative("checkBoxSetChecked", nimini_checkBoxSetChecked,
    storieLibs = @["tui"],
    description = "Set checkbox/radio state")
  
  registerNative("checkBoxToggle", nimini_checkBoxToggle,
    storieLibs = @["tui"],
    description = "Toggle checkbox state")
  
  registerNative("checkBoxSetChars", nimini_checkBoxSetChars,
    storieLibs = @["tui"],
    description = "Customize checkbox visual characters")
  
  #   # ProgressBar
  #   registerNative("newProgressBar", nimini_newProgressBar,
  #     storieLibs = @["tui"],
  #     description = "Create a progress bar widget")
  #   
  #   registerNative("progressBarSetValue", nimini_progressBarSetValue,
  #     storieLibs = @["tui"],
  #     description = "Set progress bar value")
  #   
  #   registerNative("progressBarSetProgress", nimini_progressBarSetProgress,
  #     storieLibs = @["tui"],
  #     description = "Set progress (normalized 0.0-1.0)")
  #   
  #   registerNative("progressBarGetProgress", nimini_progressBarGetProgress,
  #     storieLibs = @["tui"],
  #     description = "Get progress (normalized 0.0-1.0)")
  #   
  #   registerNative("progressBarSetText", nimini_progressBarSetText,
  #     storieLibs = @["tui"],
  #     description = "Set progress bar overlay text")
  #   
  #   registerNative("progressBarSetShowPercentage", nimini_progressBarSetShowPercentage,
  #     storieLibs = @["tui"],
  #     description = "Show/hide percentage display")
  #   
  #   registerNative("progressBarSetChars", nimini_progressBarSetChars,
  #     storieLibs = @["tui"],
  #     description = "Customize progress bar visual characters")
  #   
  #   # Generic Widget Operations
  #   registerNative("widgetSetVisible", nimini_widgetSetVisible,
  #     storieLibs = @["tui"],
  #     description = "Show/hide widget")
  #   
  registerNative("widgetSetEnabled", nimini_widgetSetEnabled,
    storieLibs = @["tui"],
    description = "Enable/disable widget")
  
  registerNative("widgetSetPosition", nimini_widgetSetPosition,
    storieLibs = @["tui"],
    description = "Set widget position")
  
  registerNative("widgetSetSize", nimini_widgetSetSize,
    storieLibs = @["tui"],
    description = "Set widget size")

export registerTUIBindings, DrawProc
export gWidgetManager  # Export for access from main application
