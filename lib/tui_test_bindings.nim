## Nimini bindings for tui_test module

import ../nimini/runtime
import tui_test
import ../src/types
import storie_types
import ../backends/terminal/termbuffer
import tables

# Global references needed for buffer access (set by tstorie.nim)
var gDefaultLayerRef*: ptr Layer = nil
var gAppStateRef*: ptr AppState = nil
var gStorieStyleSheet*: ptr StyleSheet = nil

proc nimini_initButton(env: ref Env; args: seq[Value]): Value =
  if args.len < 6:
    return Value(kind: vkNil)
  let id = args[0].i
  let x = args[1].i
  let y = args[2].i
  let w = args[3].i
  let h = args[4].i
  let label = args[5].s
  initButton(id, x, y, w, h, label)
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
  
  # Get style - args is a seq[Value]
  let styleName = if len(args) > 0: args[0].s else: "button"
  var style = defaultStyle()
  if not gStorieStyleSheet.isNil and gStorieStyleSheet[].hasKey(styleName):
    let sc = gStorieStyleSheet[][styleName]
    style = Style(
      fg: rgb(sc.fg.r, sc.fg.g, sc.fg.b),
      bg: rgb(sc.bg.r, sc.bg.g, sc.bg.b),
      bold: sc.bold,
      italic: sc.italic,
      underline: sc.underline,
      dim: sc.dim
    )
  
  drawTUI(buffer, style)
  return Value(kind: vkNil)

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

proc registerTUITestBindings*(defaultLayer: ptr Layer, appState: ptr AppState, 
                              styleSheet: ptr StyleSheet) =
  ## Register TUI test functions with nimini runtime
  gDefaultLayerRef = defaultLayer
  gAppStateRef = appState
  gStorieStyleSheet = styleSheet
  
  registerNative("initButton", nimini_initButton,
    storieLibs = @["tui_test"],
    description = "Initialize a button: initButton(id, x, y, w, h, label) - id must be 0 or 1")
  
  registerNative("updateTUI", nimini_updateTUI,
    storieLibs = @["tui_test"],
    description = "Update all button states: updateTUI(mouseX, mouseY, mousePressed)")
  
  registerNative("drawTUI", nimini_drawTUI,
    storieLibs = @["tui_test"],
    description = "Draw all buttons: drawTUI(styleName='button')")
  
  registerNative("wasClicked", nimini_wasClicked,
    storieLibs = @["tui_test"],
    description = "Check if button was clicked: wasClicked(id)")
  
  registerNative("isHovered", nimini_isHovered,
    storieLibs = @["tui_test"],
    description = "Check if button is hovered: isHovered(id)")
  
  registerNative("isHovered", nimini_isHovered,
    storieLibs = @["tui_test"],
    description = "Check if button is hovered: isHovered()")
