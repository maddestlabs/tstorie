# TStorie entry point
# 
# Note: This file is included by tstorie.nim and has access to all tstorie types and lib modules.
# When compiling, use: nim c tstorie.nim -d:userFile=index (or ./build.sh / ./build-web.sh)

import strutils, tables, random, times, algorithm
when not defined(emscripten):
  import os
  import src/platform/terminal
import nimini

# Import library modules - customize this list based on what you need
import lib/storie_md          # Markdown parser (includes gEmbeddedFigletFonts)
import lib/section_manager    # Section navigation and management (includes nimini bindings)
import lib/layout             # Text layout utilities
import lib/figlet             # FIGlet font rendering (for parsing and rendering)

# These modules work directly with tstorie's core types (Layer, TermBuffer, Style, etc.)
# so they must be included to share the same namespace
include lib/events            # Event handling system
include lib/animation         # Animation helpers and easing
include lib/canvas            # Canvas navigation system
include lib/audio             # Audio system
include lib/tui               # TUI widget system
include lib/tui_editor

# Helper to convert Value to int (handles both int and float values)
proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  of vkString:
    # Try to parse string as integer
    try:
      return parseInt(v.s)
    except:
      return 0
  of vkBool: return if v.b: 1 else: 0
  else: return 0

# Helper to convert Value to bool
proc valueToBool(v: Value): bool =
  case v.kind
  of vkBool: return v.b
  of vkInt: return v.i != 0
  of vkFloat: return v.f != 0.0
  else: return false

# ================================================================
# NIMINI INTEGRATION
# ================================================================

type
  NiminiContext = ref object
    env: ref Env
  
  GlobalHandler* = object
    name*: string
    callback*: Value  # Nimini function/closure
    priority*: int    # Lower = executes first (default 0)
  
  StorieContext = ref object
    codeBlocks: seq[CodeBlock]
    niminiContext: NiminiContext
    frontMatter: FrontMatter  # Front matter from markdown
    styleSheet: StyleSheet    # Style configurations from front matter
    themeBackground: tuple[r, g, b: uint8]  # Theme's background color for terminal
    minWidth: int  # Minimum required terminal width (0 = no requirement)
    minHeight: int  # Minimum required terminal height (0 = no requirement)
    # Pre-compiled layer references
    bgLayer: Layer
    fgLayer: Layer
    # Section management
    sectionMgr: SectionManager   # Section manager handles all section state
    # Global event handlers
    globalRenderHandlers*: seq[GlobalHandler]
    globalUpdateHandlers*: seq[GlobalHandler]
    globalInputHandlers*: seq[GlobalHandler]


# ================================================================
# NIMINI WRAPPERS - Bridge storie functions to Nimini
# ================================================================

# Global references to layers (set in initStorieContext)
var gDefaultLayer: Layer  # Single default layer (layer 0)
var gTextStyle, gBorderStyle, gInfoStyle: Style
var gAppState: AppState  # Global reference to app state for state accessors

# Global TUI widget manager and widget registry
var gWidgetManager: WidgetManager
var gWidgetRegistry = initTable[string, Widget]()
var gLastClickedWidget: string = ""  # Track last clicked widget for polling

# Forward declaration for functions that will be defined later
var storieCtx: StorieContext

# Type conversion functions
proc nimini_int(env: ref Env; args: seq[Value]): Value =
  ## Convert a value to integer
  if args.len > 0:
    case args[0].kind
    of vkInt: return args[0]
    of vkFloat: return valInt(args[0].f.int)
    of vkString: 
      try:
        return valInt(parseInt(args[0].s))
      except:
        return valInt(0)
    of vkBool: return valInt(if args[0].b: 1 else: 0)
    else: return valInt(0)
  return valInt(0)

proc nimini_float(env: ref Env; args: seq[Value]): Value =
  ## Convert a value to float
  if args.len > 0:
    case args[0].kind
    of vkFloat: return args[0]
    of vkInt: return valFloat(args[0].i.float)
    of vkString: 
      try:
        return valFloat(parseFloat(args[0].s))
      except:
        return valFloat(0.0)
    of vkBool: return valFloat(if args[0].b: 1.0 else: 0.0)
    else: return valFloat(0.0)
  return valFloat(0.0)

proc nimini_str(env: ref Env; args: seq[Value]): Value =
  ## Convert a value to string
  if args.len > 0:
    return valString($args[0])
  return valString("")

# Print function
proc print(env: ref Env; args: seq[Value]): Value {.nimini.} =
  var output = ""
  for i, arg in args:
    if i > 0: output.add(" ")
    case arg.kind
    of vkInt: output.add($arg.i)
    of vkFloat: output.add($arg.f)
    of vkString: output.add(arg.s)
    of vkBool: output.add($arg.b)
    of vkNil: output.add("nil")
    else: output.add("<value>")
  echo output
  return valNil()

# Style conversion functions
proc styleConfigToValue(config: StyleConfig): Value =
  ## Convert StyleConfig to a nimini Value (map)
  let styleMap = valMap()
  let fgMap = valMap()
  fgMap.map["r"] = valInt(config.fg.r.int)
  fgMap.map["g"] = valInt(config.fg.g.int)
  fgMap.map["b"] = valInt(config.fg.b.int)
  styleMap.map["fg"] = fgMap
  
  let bgMap = valMap()
  bgMap.map["r"] = valInt(int(config.bg.r))
  bgMap.map["g"] = valInt(int(config.bg.g))
  bgMap.map["b"] = valInt(int(config.bg.b))
  styleMap.map["bg"] = bgMap
  
  styleMap.map["bold"] = valBool(config.bold)
  styleMap.map["italic"] = valBool(config.italic)
  styleMap.map["underline"] = valBool(config.underline)
  styleMap.map["dim"] = valBool(config.dim)
  return styleMap

proc valueToStyle(v: Value): Style =
  ## Convert nimini Value (map) to Style
  result = defaultStyle()
  if v.kind != vkMap:
    return
  
  if v.map.hasKey("fg"):
    let fgVal = v.map["fg"]
    if fgVal.kind == vkMap:
      let r = if fgVal.map.hasKey("r"): fgVal.map["r"].i.uint8 else: 255'u8
      let g = if fgVal.map.hasKey("g"): fgVal.map["g"].i.uint8 else: 255'u8
      let b = if fgVal.map.hasKey("b"): fgVal.map["b"].i.uint8 else: 255'u8
      result.fg = rgb(r, g, b)
  
  if v.map.hasKey("bg"):
    let bgVal = v.map["bg"]
    if bgVal.kind == vkMap:
      let r = if bgVal.map.hasKey("r"): bgVal.map["r"].i.uint8 else: 0'u8
      let g = if bgVal.map.hasKey("g"): bgVal.map["g"].i.uint8 else: 0'u8
      let b = if bgVal.map.hasKey("b"): bgVal.map["b"].i.uint8 else: 0'u8
      result.bg = rgb(r, g, b)
  
  if v.map.hasKey("bold"):
    result.bold = v.map["bold"].b
  if v.map.hasKey("italic"):
    result.italic = v.map["italic"].b
  if v.map.hasKey("underline"):
    result.underline = v.map["underline"].b
  if v.map.hasKey("dim"):
    result.dim = v.map["dim"].b

# ================================================================
# UNIFIED DRAWING API
# ================================================================
# Simplified drawing API that takes layer as first parameter
# Supports both "foreground"/"background" and custom layers created with addLayer()

proc draw(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## draw(layer: string|int, x: int, y: int, text: string, [style])
  ## Unified drawing function that works with any layer
  ## Layer 0 is the default layer. Use addLayer() to create additional layers.
  if args.len < 4:
    return valNil()
  
  # Determine layer from first arg (supports both string and int)
  let layer = if args[0].kind == vkInt:
                let idx = args[0].i
                if idx == 0: gDefaultLayer
                else:
                  # Try to get by z-order index from app state
                  if idx < gAppState.layers.len: gAppState.layers[idx]
                  else: return valNil()
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let text = args[3].s
  let style = if args.len >= 5: valueToStyle(args[4]) else: gTextStyle
  
  layer.buffer.writeText(x, y, text, style)
  return valNil()

proc clear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## clear([layer: string|int], [transparent: bool])
  ## Clear layer(s). With no args, clears all layers.
  ## Layer 0 is the default layer.
  
  # No args - clear all layers
  if args.len == 0:
    for layer in gAppState.layers:
      layer.buffer.clear(storieCtx.themeBackground)
    return valNil()
  
  # Determine layer from first arg (supports both string and int)
  let layer = if args[0].kind == vkInt:
                let idx = args[0].i
                if idx == 0: gDefaultLayer
                else:
                  # Try to get by z-order index from app state
                  if idx < gAppState.layers.len: gAppState.layers[idx]
                  else: return valNil()
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let transparent = if args.len >= 2: valueToBool(args[1]) else: false
  
  if transparent:
    layer.buffer.clearTransparent()
  else:
    layer.buffer.clear(storieCtx.themeBackground)
  return valNil()

proc fillRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## fillRect(layer: string|int, x: int, y: int, w: int, h: int, char: string, [style])
  ## Fill a rectangle on the specified layer
  ## Layer 0 is the default layer. Use addLayer() to create additional layers.
  if args.len < 6:
    return valNil()
  
  # Determine layer from first arg (supports both string and int)
  let layer = if args[0].kind == vkInt:
                let idx = args[0].i
                if idx == 0: gDefaultLayer
                else:
                  # Try to get by z-order index from app state
                  if idx < gAppState.layers.len: gAppState.layers[idx]
                  else: return valNil()
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let ch = args[5].s
  let style = if args.len >= 7: valueToStyle(args[6]) else: gTextStyle
  
  layer.buffer.fillRect(x, y, w, h, ch, style)
  return valNil()

# Random number generator - consistent across WASM and native
var globalRng: Rand

proc initGlobalRng*() =
  ## Initialize the global RNG with a time-based seed
  let seed = getTime().toUnix() * 1000000000 + getTime().nanosecond()
  globalRng = initRand(seed)

# Random number functions - now consistent across platforms
proc randInt(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate random integer: randInt(max) returns 0..max-1, randInt(min, max) returns min..max-1
  if args.len == 0:
    return valInt(0)
  elif args.len == 1:
    let max = valueToInt(args[0])
    return valInt(rand(globalRng, max - 1))
  else:
    let min = valueToInt(args[0])
    let max = valueToInt(args[1])
    return valInt(rand(globalRng, max - min - 1) + min)

proc randFloat(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate random float: randFloat() returns 0.0..1.0, randFloat(max) returns 0.0..max
  if args.len == 0:
    return valFloat(rand(globalRng, 1.0))
  else:
    let max = case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 1.0
    return valFloat(rand(globalRng, max))

# ================================================================
# GLOBAL EVENT HANDLER MANAGEMENT
# ================================================================
# Note: State accessors (getTermWidth, getFps, etc.) are in tstorie.nim's
# registerTstorieApis() and are automatically available to all nimini code.

proc registerGlobalRender*(name: string, callback: Value, priority: int = 0): bool =
  ## Register a global render handler
  if storieCtx.isNil:
    return false
  
  # Check if handler with this name already exists
  for i, handler in storieCtx.globalRenderHandlers:
    if handler.name == name:
      # Update existing handler
      storieCtx.globalRenderHandlers[i] = GlobalHandler(name: name, callback: callback, priority: priority)
      return true
  
  # Add new handler and sort by priority
  storieCtx.globalRenderHandlers.add(GlobalHandler(name: name, callback: callback, priority: priority))
  storieCtx.globalRenderHandlers.sort(proc(a, b: GlobalHandler): int = cmp(a.priority, b.priority))
  return true

proc registerGlobalUpdate*(name: string, callback: Value, priority: int = 0): bool =
  ## Register a global update handler
  if storieCtx.isNil:
    return false
  
  for i, handler in storieCtx.globalUpdateHandlers:
    if handler.name == name:
      storieCtx.globalUpdateHandlers[i] = GlobalHandler(name: name, callback: callback, priority: priority)
      return true
  
  storieCtx.globalUpdateHandlers.add(GlobalHandler(name: name, callback: callback, priority: priority))
  storieCtx.globalUpdateHandlers.sort(proc(a, b: GlobalHandler): int = cmp(a.priority, b.priority))
  return true

proc registerGlobalInput*(name: string, callback: Value, priority: int = 0): bool =
  ## Register a global input handler
  if storieCtx.isNil:
    return false
  
  for i, handler in storieCtx.globalInputHandlers:
    if handler.name == name:
      storieCtx.globalInputHandlers[i] = GlobalHandler(name: name, callback: callback, priority: priority)
      return true
  
  storieCtx.globalInputHandlers.add(GlobalHandler(name: name, callback: callback, priority: priority))
  storieCtx.globalInputHandlers.sort(proc(a, b: GlobalHandler): int = cmp(a.priority, b.priority))
  return true

proc unregisterGlobalHandler*(name: string): bool =
  ## Unregister a global handler by name (searches all handler types)
  if storieCtx.isNil:
    return false
  
  var found = false
  
  # Remove from render handlers
  for i in countdown(storieCtx.globalRenderHandlers.len - 1, 0):
    if storieCtx.globalRenderHandlers[i].name == name:
      storieCtx.globalRenderHandlers.delete(i)
      found = true
  
  # Remove from update handlers
  for i in countdown(storieCtx.globalUpdateHandlers.len - 1, 0):
    if storieCtx.globalUpdateHandlers[i].name == name:
      storieCtx.globalUpdateHandlers.delete(i)
      found = true
  
  # Remove from input handlers
  for i in countdown(storieCtx.globalInputHandlers.len - 1, 0):
    if storieCtx.globalInputHandlers[i].name == name:
      storieCtx.globalInputHandlers.delete(i)
      found = true
  
  return found

proc clearGlobalHandlers*() =
  ## Clear all global handlers
  if not storieCtx.isNil:
    storieCtx.globalRenderHandlers = @[]
    storieCtx.globalUpdateHandlers = @[]
    storieCtx.globalInputHandlers = @[]

# Style functions
proc nimini_defaultStyle(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## defaultStyle() -> Style map
  return styleConfigToValue(getDefaultStyleConfig())

proc nimini_getStyle(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## getStyle(name: string) -> Style map
  ## Retrieve a named style from the stylesheet defined in front matter
  if args.len < 1:
    return styleConfigToValue(getDefaultStyleConfig())
  
  let styleName = args[0].s
  
  # Access the stylesheet from storieCtx
  if not storieCtx.isNil and storieCtx.styleSheet.hasKey(styleName):
    return styleConfigToValue(storieCtx.styleSheet[styleName])
  
  # Fallback to default style
  return styleConfigToValue(getDefaultStyleConfig())

proc nimini_getThemes(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get list of available theme names. Returns array of strings
  let themes = getAvailableThemes()
  var themeValues: seq[Value] = @[]
  for theme in themes:
    themeValues.add(valString(theme))
  return valArray(themeValues)

proc nimini_switchTheme(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Switch to a different theme at runtime. Args: themeName (string)
  ## Returns: bool (true if successful)
  if args.len == 0 or storieCtx.isNil:
    return valBool(false)
  
  let themeName = args[0].s
  
  # Apply the new theme
  let newStyleSheet = applyThemeByName(themeName)
  
  # Update the stored stylesheet
  storieCtx.styleSheet = newStyleSheet
  
  # Also need to update the canvas stylesheet pointer if canvas is active
  if not canvasState.isNil:
    # Re-register canvas bindings to update the stylesheet pointer
    registerCanvasBindings(addr gDefaultLayer.buffer, addr gAppState, addr storieCtx.styleSheet)
  
  return valBool(true)

proc nimini_getCurrentTheme(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the currently active theme name (if set in front matter)
  ## Returns string or empty string if no theme was set
  if storieCtx.isNil or not storieCtx.frontMatter.hasKey("theme"):
    return valString("")
  return valString(storieCtx.frontMatter["theme"])

# Nimini wrapper functions
proc nimini_registerGlobalRender(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Register a global render handler. Args: name (string), callback (function), [priority (int)]
  if args.len < 2:
    return valBool(false)
  let name = args[0].s
  let callback = args[1]
  let priority = if args.len >= 3 and args[2].kind == vkInt: args[2].i else: 0
  return valBool(registerGlobalRender(name, callback, priority))

proc nimini_registerGlobalUpdate(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Register a global update handler. Args: name (string), callback (function), [priority (int)]
  if args.len < 2:
    return valBool(false)
  let name = args[0].s
  let callback = args[1]
  let priority = if args.len >= 3 and args[2].kind == vkInt: args[2].i else: 0
  return valBool(registerGlobalUpdate(name, callback, priority))

proc nimini_registerGlobalInput(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Register a global input handler. Args: name (string), callback (function), [priority (int)]
  if args.len < 2:
    return valBool(false)
  let name = args[0].s
  let callback = args[1]
  let priority = if args.len >= 3 and args[2].kind == vkInt: args[2].i else: 0
  return valBool(registerGlobalInput(name, callback, priority))

proc nimini_unregisterGlobalHandler(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Unregister a global handler by name. Args: name (string)
  if args.len == 0:
    return valBool(false)
  return valBool(unregisterGlobalHandler(args[0].s))

proc nimini_clearGlobalHandlers(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Clear all global handlers
  clearGlobalHandlers()
  return valNil()

# ================================================================
# MOUSE HANDLING
# ================================================================

proc nimini_enableMouse(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Enable mouse input reporting
  when not defined(emscripten):
    enableMouseReporting()
  return valNil()

proc nimini_disableMouse(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Disable mouse input reporting
  when not defined(emscripten):
    disableMouseReporting()
  return valNil()

# ================================================================
# TUI WIDGET SYSTEM WRAPPERS
# ================================================================

# Test function to verify nimini registration works
proc nimini_tuiTest(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Simple test function
  return valString("TUI functions are loaded!")

proc nimini_newWidgetManager(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new widget manager. Optional arg: use document styleSheet (bool, default true)
  let useStyleSheet = if args.len > 0: args[0].b else: true
  if useStyleSheet and not storieCtx.isNil and storieCtx.styleSheet.len > 0:
    gWidgetManager = newWidgetManager(storieCtx.styleSheet)
  else:
    gWidgetManager = newWidgetManager()
  return valNil()

proc nimini_newLabel(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a label widget. Args: id, x, y, width, height, text
  if args.len >= 6:
    let id = args[0].s
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    let w = valueToInt(args[3])
    let h = valueToInt(args[4])
    let text = args[5].s
    let label = newLabel(id, x, y, w, h, text)
    gWidgetRegistry[id] = label
    gWidgetManager.addWidget(label)
  return valNil()

proc nimini_newButton(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a button widget. Args: id, x, y, width, height, label
  if args.len >= 6:
    let id = args[0].s
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    let w = valueToInt(args[3])
    let h = valueToInt(args[4])
    let labelText = args[5].s
    let button = newButton(id, x, y, w, h, labelText)
    
    # Set default onClick to record the click
    button.onClick = proc(w: Widget) {.nimcall.} =
      gLastClickedWidget = w.id
    
    gWidgetRegistry[id] = button
    gWidgetManager.addWidget(button)
  return valNil()

proc nimini_newCheckBox(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a checkbox widget. Args: id, x, y, label, checked (optional)
  if args.len >= 4:
    let id = args[0].s
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    let labelText = args[3].s
    let checked = if args.len >= 5: args[4].b else: false
    let checkbox = newCheckBox(id, x, y, labelText, checked)
    gWidgetRegistry[id] = checkbox
    gWidgetManager.addWidget(checkbox)
  return valNil()

proc nimini_newRadioButton(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a radio button widget. Args: id, x, y, label, group
  if args.len >= 5:
    let id = args[0].s
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    let labelText = args[3].s
    let group = args[4].s
    let radio = newRadioButton(id, x, y, labelText, group)
    gWidgetRegistry[id] = radio
    gWidgetManager.addWidget(radio)
  return valNil()

proc nimini_newSlider(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a horizontal slider widget. Args: id, x, y, length, minVal, maxVal
  if args.len >= 6:
    let id = args[0].s
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    let length = valueToInt(args[3])
    let minVal = if args[4].kind == vkFloat: args[4].f else: float(args[4].i)
    let maxVal = if args[5].kind == vkFloat: args[5].f else: float(args[5].i)
    let slider = newSlider(id, x, y, length, minVal, maxVal)
    gWidgetRegistry[id] = slider
    gWidgetManager.addWidget(slider)
  return valNil()

proc nimini_newTextBox(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a multi-line text editor widget. Args: id, x, y, width, height
  if args.len >= 5:
    let id = args[0].s
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    let w = valueToInt(args[3])
    let h = valueToInt(args[4])
    let textbox = newTextBox(id, x, y, w, h)
    gWidgetRegistry[id] = textbox
    gWidgetManager.addWidget(textbox)
  return valNil()

proc nimini_widgetSetText(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set text on a label or textbox widget. Args: id, text
  if args.len >= 2:
    let id = args[0].s
    if gWidgetRegistry.hasKey(id):
      let widget = gWidgetRegistry[id]
      if widget of Label:
        Label(widget).setText(args[1].s)
      elif widget of TextBox:
        TextBox(widget).setText(args[1].s)
  return valNil()

proc nimini_widgetGetText(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get text from a label or textbox widget. Args: id
  if args.len >= 1:
    let id = args[0].s
    if gWidgetRegistry.hasKey(id):
      let widget = gWidgetRegistry[id]
      if widget of Label:
        return valString(Label(widget).text)
      elif widget of TextBox:
        return valString(TextBox(widget).getText())
  return valString("")

proc nimini_widgetGetValue(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get value from a widget (checkbox checked state or slider value). Args: id
  if args.len >= 1:
    let id = args[0].s
    if gWidgetRegistry.hasKey(id):
      let widget = gWidgetRegistry[id]
      if widget of CheckBox:
        return valBool(CheckBox(widget).checked)
      elif widget of Slider:
        return valFloat(Slider(widget).value)
  return valNil()

proc nimini_widgetSetValue(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set value on a widget (checkbox checked or slider value). Args: id, value
  if args.len >= 2:
    let id = args[0].s
    if gWidgetRegistry.hasKey(id):
      let widget = gWidgetRegistry[id]
      if widget of CheckBox:
        CheckBox(widget).setChecked(args[1].b)
      elif widget of Slider:
        let val = if args[1].kind == vkFloat: args[1].f else: float(args[1].i)
        Slider(widget).setValue(val)
  return valNil()

proc nimini_widgetSetCallback(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set a callback for a widget. Args: id, callbackType, callback
  ## callbackType can be: "click", "change", "focus", "blur"
  if args.len >= 3:
    let id = args[0].s
    let callbackType = args[1].s
    let callback = args[2]
    
    if callback.kind != vkFunction:
      return valNil()
    
    if gWidgetRegistry.hasKey(id):
      let widget = gWidgetRegistry[id]
      
      # Store the callback in userData as a pointer to the Value
      # We'll need to call it manually from a wrapper
      let callbackPtr = create(Value)
      callbackPtr[] = callback
      widget.userData = cast[pointer](callbackPtr)
      
      case callbackType
      of "click":
        # Set onClick callback that calls the stored nimini function
        widget.onClick = proc(w: Widget) {.nimcall.} =
          if not w.userData.isNil:
            let cb = cast[ptr Value](w.userData)
            if cb[].kind == vkFunction:
              try:
                let callEnv = storieCtx.niminiContext.env
                if cb[].fnVal.isNative:
                  discard cb[].fnVal.native(callEnv, @[])
              except:
                discard
      
      of "change":
        # Set onChange callback
        widget.onChange = proc(w: Widget) {.nimcall.} =
          if not w.userData.isNil:
            let cb = cast[ptr Value](w.userData)
            if cb[].kind == vkFunction:
              try:
                let callEnv = storieCtx.niminiContext.env
                if cb[].fnVal.isNative:
                  discard cb[].fnVal.native(callEnv, @[])
              except:
                discard
      
      of "focus":
        # Set onFocus callback
        widget.onFocus = proc(w: Widget) {.nimcall.} =
          if not w.userData.isNil:
            let cb = cast[ptr Value](w.userData)
            if cb[].kind == vkFunction:
              try:
                let callEnv = storieCtx.niminiContext.env
                if cb[].fnVal.isNative:
                  discard cb[].fnVal.native(callEnv, @[])
              except:
                discard
      
      of "blur":
        # Set onBlur callback
        widget.onBlur = proc(w: Widget) {.nimcall.} =
          if not w.userData.isNil:
            let cb = cast[ptr Value](w.userData)
            if cb[].kind == vkFunction:
              try:
                let callEnv = storieCtx.niminiContext.env
                if cb[].fnVal.isNative:
                  discard cb[].fnVal.native(callEnv, @[])
              except:
                discard
      
      else:
        discard
  
  return valNil()

proc nimini_widgetWasClicked(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if a widget was just clicked. Args: id
  ## Returns true and clears the flag, so only returns true once per click
  if args.len >= 1:
    let id = args[0].s
    if gLastClickedWidget == id:
      gLastClickedWidget = ""
      return valBool(true)
  return valBool(false)

proc nimini_widgetGetLastClicked(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the ID of the last clicked widget and clear it
  let result = gLastClickedWidget
  gLastClickedWidget = ""
  return valString(result)

proc nimini_widgetManagerUpdate(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update widget manager. Args: dt (float, optional)
  let dt = if args.len > 0 and args[0].kind == vkFloat: args[0].f else: 0.016
  if not gWidgetManager.isNil:
    gWidgetManager.update(dt)
  return valNil()

proc nimini_widgetManagerRender(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render widgets to a layer. Args: layerId (string, optional, default "foreground")
  let layerId = if args.len > 0: args[0].s else: "foreground"
  
  if not gWidgetManager.isNil and not gAppState.isNil:
    # Find the layer
    for layer in gAppState.layers:
      if layer.id == layerId:
        gWidgetManager.render(layer)
        break
  
  return valNil()

proc nimini_widgetManagerHandleInput(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle input event with widget manager. 
  ## The event is available in the environment from the input lifecycle
  ## Returns: bool (true if event was consumed)
  
  if gWidgetManager.isNil:
    return valBool(false)
  
  # Get the event from the environment - it should be set by executeCodeBlock
  # Use getVar to walk the scope chain (event is in child scope!)
  let eventVar = getVar(env, "event")
  if eventVar.kind == vkNil:
    return valBool(false)
  
  # We need to decode the event back into an InputEvent
  # For now, we'll handle basic keyboard and mouse events
  if eventVar.kind != vkMap:
    return valBool(false)
  
  let eventMap = eventVar.map
  let eventType = if eventMap.hasKey("type"): eventMap["type"].s else: ""
  
  # Create an InputEvent based on the type
  var inputEvent: InputEvent
  
  case eventType
  of "key":
    let keyCode = if eventMap.hasKey("keyCode"): eventMap["keyCode"].i else: 0
    let action = if eventMap.hasKey("action"): eventMap["action"].s else: "press"
    
    inputEvent = InputEvent(
      kind: KeyEvent,
      keyCode: keyCode,
      keyAction: case action
        of "press": Press
        of "release": Release
        of "repeat": Repeat
        else: Press,
      keyMods: {}  # TODO: decode modifiers if needed
    )
  
  of "mouse":
    let x = if eventMap.hasKey("x"): eventMap["x"].i else: 0
    let y = if eventMap.hasKey("y"): eventMap["y"].i else: 0
    let button = if eventMap.hasKey("button"): eventMap["button"].s else: "left"
    let action = if eventMap.hasKey("action"): eventMap["action"].s else: "press"
    
    inputEvent = InputEvent(
      kind: MouseEvent,
      mouseX: x,
      mouseY: y,
      button: case button
        of "left": Left
        of "right": Right
        of "middle": Middle
        of "scroll_up": ScrollUp
        of "scroll_down": ScrollDown
        else: Unknown,
      action: case action
        of "press": Press
        of "release": Release
        of "repeat": Repeat
        else: Press,
      mods: {}  # TODO: decode modifiers if needed
    )
  
  of "mouse_move":
    let x = if eventMap.hasKey("x"): eventMap["x"].i else: 0
    let y = if eventMap.hasKey("y"): eventMap["y"].i else: 0
    
    inputEvent = InputEvent(
      kind: MouseMoveEvent,
      moveX: x,
      moveY: y,
      moveMods: {}  # TODO: decode modifiers if needed
    )
  
  else:
    return valBool(false)
  
  # Pass the event to the widget manager
  let consumed = gWidgetManager.handleInput(inputEvent)
  return valBool(consumed)

# ================================================================
# BROWSER API WRAPPERS (localStorage, window.open)
# ================================================================

# localStorage functionality temporarily disabled for web build due to FFI issues
# TODO: Re-enable with proper emscripten bindings
#
# The issue is that emscripten doesn't support direct importc with JavaScript object
# methods like "localStorage.setItem". To fix this, we need to:
# 1. Add emscripten.h include to get EM_ASM macros
# 2. Use proper EM_ASM/EM_ASM_PTR syntax for calling JavaScript from C
# 3. Handle UTF8 string conversion correctly
# 4. Test that window.open works with the same approach
#
# Alternatively, we could create JavaScript wrapper functions that are called
# via simpler C function names (e.g., js_localstorage_set instead of localStorage.setItem)

when false: # disabled
  when defined(emscripten):
    # JavaScript FFI for localStorage using EM_ASM
    proc js_localStorage_setItem(key: cstring, value: cstring) =
      {.emit: """
      EM_ASM({
        localStorage.setItem(UTF8ToString($0), UTF8ToString($1));
      }, `key`, `value`);
      """.}
    
    proc js_localStorage_getItem(key: cstring): cstring =
      var result: cstring
      {.emit: """
      `result` = (char*)EM_ASM_PTR({
        var item = localStorage.getItem(UTF8ToString($0));
        if (item === null) return 0;
        var len = lengthBytesUTF8(item) + 1;
        var str = _malloc(len);
        stringToUTF8(item, str, len);
        return str;
      }, `key`);
      """.}
      return result
    
    proc js_window_open(url: cstring, target: cstring) =
      {.emit: """
      EM_ASM({
        window.open(UTF8ToString($0), UTF8ToString($1));
      }, `url`, `target`);
      """.}

proc nimini_localStorage_setItem(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Save content to browser localStorage. Args: key, value (temporarily disabled)
  if args.len >= 2:
    let key = args[0].s
    let value = args[1].s
    when false: # disabled
      when defined(emscripten):
        js_localStorage_setItem(key.cstring, value.cstring)
    # Stub - localStorage temporarily disabled
    when not defined(emscripten):
      echo "localStorage_setItem (disabled): ", key
  return valNil()

proc nimini_localStorage_getItem(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Load content from browser localStorage. Args: key (temporarily disabled)
  if args.len >= 1:
    let key = args[0].s
    when false: # disabled
      when defined(emscripten):
        let value = js_localStorage_getItem(key.cstring)
        if not value.isNil:
          return valString($value)
    # Stub - localStorage temporarily disabled
    when not defined(emscripten):
      echo "localStorage_getItem (disabled): ", key
  return valString("")

proc nimini_window_open(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Open URL in new browser window/tab. Args: url, target (temporarily disabled)
  if args.len >= 1:
    let url = args[0].s
    let target = if args.len >= 2: args[1].s else: "_blank"
    when false: # disabled
      when defined(emscripten):
        js_window_open(url.cstring, target.cstring)
    # Stub - window.open temporarily disabled
    when not defined(emscripten):
      echo "window_open (disabled): ", url, " in ", target
  return valNil()

# ================================================================
# CANVAS SYSTEM WRAPPERS
# ================================================================

proc initCanvas(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Initialize canvas system with all sections. 
  ## Args: currentIdx (int, optional, default 0), presentationMode (bool, optional, default false)
  if storieCtx.isNil:
    return valBool(false)
  let currentIdx = if args.len > 0: valueToInt(args[0]) else: 0
  let presentationMode = if args.len > 1: valueToBool(args[1]) else: false
  let sections = storieCtx.sectionMgr.getAllSections()
  initCanvas(sections, currentIdx, presentationMode)
  
  # Set up the execution callback for on:enter and on:exit lifecycle hooks
  setExecuteCallback(proc(codeBlock: CodeBlock, lifecycle: string): bool =
    # Create a temporary AppState with current values
    # Note: We can't easily access the real AppState from here, so we create a minimal one
    # The executeCodeBlock will inject state variables from the actual state
    if not storieCtx.isNil and not storieCtx.niminiContext.isNil:
      # Execute in a child scope to avoid polluting global namespace
      try:
        let tokens = tokenizeDsl(codeBlock.code)
        let program = parseDsl(tokens)
        let execEnv = newEnv(storieCtx.niminiContext.env)
        execProgram(program, execEnv)
        return true
      except Exception as e:
        when not defined(emscripten):
          echo "Error in on:", lifecycle, " block: ", e.msg
        return false
    return false
  )
  
  # Execute on:enter hook for the initial section
  if currentIdx >= 0 and currentIdx < sections.len:
    let initialSection = sections[currentIdx]
    for contentBlock in initialSection.blocks:
      if contentBlock.kind == CodeBlock_Content:
        let codeBlock = contentBlock.codeBlock
        if codeBlock.lifecycle == "enter":
          try:
            let tokens = tokenizeDsl(codeBlock.code)
            let program = parseDsl(tokens)
            let execEnv = newEnv(storieCtx.niminiContext.env)
            execProgram(program, execEnv)
          except Exception as e:
            when not defined(emscripten):
              echo "Error in initial on:enter block: ", e.msg
  
  return valBool(true)

proc encodeInputEvent(event: InputEvent): Value =
  ## Convert InputEvent to a Nimini Value table
  var table = initTable[string, Value]()
  
  case event.kind
  of KeyEvent:
    table["type"] = valString("key")
    table["keyCode"] = valInt(event.keyCode)
    table["action"] = valString(case event.keyAction
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat")
    
    # Encode modifiers
    var mods: seq[string] = @[]
    if ModShift in event.keyMods: mods.add("shift")
    if ModAlt in event.keyMods: mods.add("alt")
    if ModCtrl in event.keyMods: mods.add("ctrl")
    if ModSuper in event.keyMods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
  of TextEvent:
    table["type"] = valString("text")
    table["text"] = valString(event.text)
    # Include character code for first character (useful for key handling)
    table["keyCode"] = if event.text.len > 0: valInt(int(event.text[0])) else: valInt(0)
  
  of MouseEvent:
    table["type"] = valString("mouse")
    table["x"] = valInt(event.mouseX)
    table["y"] = valInt(event.mouseY)
    table["button"] = valString(case event.button
      of Left: "left"
      of Right: "right"
      of Middle: "middle"
      of ScrollUp: "scroll_up"
      of ScrollDown: "scroll_down"
      of Unknown: "unknown")
    table["action"] = valString(case event.action
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat")
    
    # Encode modifiers
    var mods: seq[string] = @[]
    if ModShift in event.mods: mods.add("shift")
    if ModAlt in event.mods: mods.add("alt")
    if ModCtrl in event.mods: mods.add("ctrl")
    if ModSuper in event.mods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
  of MouseMoveEvent:
    table["type"] = valString("mouse_move")
    table["x"] = valInt(event.moveX)
    table["y"] = valInt(event.moveY)
    
    # Encode modifiers
    var mods: seq[string] = @[]
    if ModShift in event.moveMods: mods.add("shift")
    if ModAlt in event.moveMods: mods.add("alt")
    if ModCtrl in event.moveMods: mods.add("ctrl")
    if ModSuper in event.moveMods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
  of ResizeEvent:
    table["type"] = valString("resize")
    table["width"] = valInt(event.newWidth)
    table["height"] = valInt(event.newHeight)
  
  return valMap(table)

# ================================================================
# LAYOUT MODULE WRAPPERS
# ================================================================

proc writeTextBox(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Write text in a box with alignment and wrapping
  ## Args: layer, x, y, width, height, text, [hAlign], [vAlign], [wrapMode], [style]
  if args.len < 6:
    return valNil()
  
  # Determine layer from first arg (supports both string and int)
  let layer = if args[0].kind == vkInt:
                let idx = args[0].i
                if idx == 0: gDefaultLayer
                else:
                  # Try to get by z-order index from app state
                  if idx < gAppState.layers.len: gAppState.layers[idx]
                  else: return valNil()
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let width = valueToInt(args[3])
  let height = valueToInt(args[4])
  let text = args[5].s
  
  # Default alignment and wrap mode
  var hAlign = AlignLeft
  var vAlign = AlignTop
  var wrapMode = WrapWord
  
  # Parse optional hAlign parameter (arg 6)
  if args.len >= 7:
    case args[6].s
    of "AlignLeft": hAlign = AlignLeft
    of "AlignCenter": hAlign = AlignCenter
    of "AlignRight": hAlign = AlignRight
    of "AlignJustify": hAlign = AlignJustify
    else: discard
  
  # Parse optional vAlign parameter (arg 7)
  if args.len >= 8:
    case args[7].s
    of "AlignTop": vAlign = AlignTop
    of "AlignMiddle": vAlign = AlignMiddle
    of "AlignBottom": vAlign = AlignBottom
    else: discard
  
  # Parse optional wrapMode parameter (arg 8)
  if args.len >= 9:
    case args[8].s
    of "WrapNone": wrapMode = WrapNone
    of "WrapWord": wrapMode = WrapWord
    of "WrapChar": wrapMode = WrapChar
    of "WrapEllipsis": wrapMode = WrapEllipsis
    of "WrapJustify": wrapMode = WrapJustify
    else: discard
  
  discard layout.writeTextBox(layer.buffer, x, y, width, height, text, 
                       hAlign, vAlign, wrapMode, gTextStyle)
  return valNil()

# ================================================================
# ANIMATION HELPERS (Nimini wrappers)
# ================================================================

proc nimini_newTransition(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a transition state tracker: newTransition(duration, easingId)
  if args.len < 1:
    return valNil()
  let duration = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  let easingId = if args.len > 1: valueToInt(args[1]) else: 0
  
  let easing = case easingId
    of 0: easeLinear
    of 1: easeInQuad
    of 2: easeOutQuad
    of 3: easeInOutQuad
    of 4: easeInCubic
    of 5: easeOutCubic
    of 6: easeInOutCubic
    of 7: easeInSine
    of 8: easeOutSine
    of 9: easeInOutSine
    else: easeLinear
  
  # Allocate on heap so it persists
  let trans = create(TransitionState)
  trans[] = newTransition(duration, easing)
  return valInt(cast[int](trans))

proc nimini_updateTransition(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update transition: updateTransition(transId, deltaTime)
  if args.len < 2:
    return valNil()
  var transPtr = cast[ptr TransitionState](valueToInt(args[0]))
  let dt = if args[1].kind == vkFloat: args[1].f else: float(args[1].i)
  transPtr[].update(dt)
  return valNil()

proc nimini_transitionProgress(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get linear progress: transitionProgress(transId) -> 0.0 to 1.0
  if args.len < 1:
    return valFloat(0.0)
  let transPtr = cast[ptr TransitionState](valueToInt(args[0]))
  return valFloat(transPtr[].progress())

proc nimini_transitionEasedProgress(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get eased progress: transitionEasedProgress(transId) -> 0.0 to 1.0
  if args.len < 1:
    return valFloat(0.0)
  let transPtr = cast[ptr TransitionState](valueToInt(args[0]))
  return valFloat(transPtr[].easedProgress())

proc nimini_transitionIsActive(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if transition is active: transitionIsActive(transId) -> bool
  if args.len < 1:
    return valBool(false)
  let transPtr = cast[ptr TransitionState](valueToInt(args[0]))
  return valBool(transPtr[].isActive())

proc nimini_resetTransition(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Reset transition: resetTransition(transId)
  if args.len < 1:
    return valNil()
  var transPtr = cast[ptr TransitionState](valueToInt(args[0]))
  transPtr[].reset()
  return valNil()

proc nimini_lerp(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Linear interpolation: lerp(a, b, t)
  if args.len < 3:
    return valFloat(0.0)
  let a = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  let b = if args[1].kind == vkFloat: args[1].f else: float(args[1].i)
  let t = if args[2].kind == vkFloat: args[2].f else: float(args[2].i)
  return valFloat(lerp(a, b, t))

proc nimini_lerpInt(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Integer interpolation: lerpInt(a, b, t)
  if args.len < 3:
    return valInt(0)
  let a = valueToInt(args[0])
  let b = valueToInt(args[1])
  let t = if args[2].kind == vkFloat: args[2].f else: float(args[2].i)
  return valInt(lerpInt(a, b, t))

proc nimini_smoothstep(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Smooth interpolation: smoothstep(t)
  if args.len < 1:
    return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(smoothstep(t))

proc nimini_easeLinear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeLinear(t))

proc nimini_easeInQuad(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeInQuad(t))

proc nimini_easeOutQuad(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeOutQuad(t))

proc nimini_easeInOutQuad(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeInOutQuad(t))

proc nimini_easeInCubic(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeInCubic(t))

proc nimini_easeOutCubic(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeOutCubic(t))

proc nimini_easeInOutCubic(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeInOutCubic(t))

proc nimini_easeInSine(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeInSine(t))

proc nimini_easeOutSine(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeOutSine(t))

proc nimini_easeInOutSine(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valFloat(0.0)
  let t = if args[0].kind == vkFloat: args[0].f else: float(args[0].i)
  return valFloat(easeInOutSine(t))

# Easing function constants
const
  EASE_LINEAR* = 0
  EASE_IN_QUAD* = 1
  EASE_OUT_QUAD* = 2
  EASE_IN_OUT_QUAD* = 3
  EASE_IN_CUBIC* = 4
  EASE_OUT_CUBIC* = 5
  EASE_IN_OUT_CUBIC* = 6

# Direction constants
const
  DIR_LEFT* = 0
  DIR_RIGHT* = 1
  DIR_UP* = 2
  DIR_DOWN* = 3
  DIR_CENTER* = 4

# ================================================================
# FIGLET FONT HELPERS (Nimini wrappers)
# ================================================================

# Global cache for loaded figlet fonts
var gFigletFonts = initTable[string, FIGfont]()

proc figletLoadFont(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Load a figlet font embedded in the markdown. Args: fontName (string)
  ## Returns: bool (true if loaded successfully)
  if args.len < 1:
    return valBool(false)
  
  let fontName = args[0].s
  
  # Check if already loaded
  if gFigletFonts.hasKey(fontName):
    return valBool(true)
  
  # Check if font is embedded in markdown
  if not gEmbeddedFigletFonts.hasKey(fontName):
    return valBool(false)
  
  # Parse the embedded font
  try:
    let font = parseFontFromString(fontName, gEmbeddedFigletFonts[fontName])
    gFigletFonts[fontName] = font
    return valBool(true)
  except:
    # Suppress figlet loading errors to avoid noisy output during demos
    discard
    return valBool(false)

proc figletIsFontLoaded(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if a font is loaded. Args: fontName (string)
  if args.len < 1:
    return valBool(false)
  let fontName = args[0].s
  return valBool(gFigletFonts.hasKey(fontName))

proc figletRender(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render text with a loaded figlet font. Args: fontName (string), text (string), [layoutMode (int)]
  ## Returns: array of strings (lines)
  if args.len < 2:
    return valArray(@[])
  
  let fontName = args[0].s
  if not gFigletFonts.hasKey(fontName):
    echo "[figletRender] Font not loaded: ", fontName
    return valArray(@[])
  
  let text = args[1].s
  let layout = if args.len >= 3: 
    case valueToInt(args[2])
    of 1: HorizontalFitting
    of 2: HorizontalSmushing
    else: FullWidth
  else: FullWidth
  
  let lines = render(gFigletFonts[fontName], text, layout)
  # Silent render: return lines without logging to stdout to keep demos clean
  
  var result: seq[Value] = @[]
  for line in lines:
    result.add(valString(line))
  return valArray(result)

proc figletListAvailableFonts(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get list of embedded figlet fonts
  var result: seq[Value] = @[]
  # Debug: check if table has any keys at all
  try:
    for fontName in gEmbeddedFigletFonts.keys:
      result.add(valString(fontName))
  except:
    discard
  return valArray(result)

proc createNiminiContext(state: AppState): NiminiContext =
  ## Create a Nimini interpreter context with exposed APIs
  initRuntime()
  initStdlib()  # Register standard library functions (add, len, etc.)
  registerParamFuncs(runtimeEnv)  # Register parameter functions (getParam, hasParam, etc.)
  
  # Register core framework APIs (state accessors, colors, etc.) from tstorie.nim
  registerTstorieApis(runtimeEnv, cast[pointer](state))
  
  # Register type conversion functions with custom names
  registerNative("int", nimini_int)
  registerNative("float", nimini_float)
  registerNative("str", nimini_str)
  
  # Auto-register all {.nimini.} pragma functions from index.nim
  exportNiminiProcs(
    print,
    draw, clear, fillRect, writeTextBox,
    randInt, randFloat,
    nimini_registerGlobalRender, nimini_registerGlobalUpdate, nimini_registerGlobalInput,
    nimini_unregisterGlobalHandler, nimini_clearGlobalHandlers,
    nimini_enableMouse, nimini_disableMouse,
    initCanvas,
    nimini_defaultStyle, nimini_getStyle,
    nimini_getThemes, nimini_switchTheme, nimini_getCurrentTheme,
    # Figlet font rendering
    figletLoadFont, figletIsFontLoaded, figletRender, figletListAvailableFonts,
    # TUI widget system
    nimini_tuiTest, nimini_newWidgetManager,
    nimini_newLabel, nimini_newButton, nimini_newCheckBox, nimini_newRadioButton, nimini_newSlider,
    nimini_newTextBox,
    nimini_widgetSetText, nimini_widgetGetText, nimini_widgetGetValue, nimini_widgetSetValue, nimini_widgetSetCallback,
    nimini_widgetWasClicked, nimini_widgetGetLastClicked,
    nimini_widgetManagerUpdate, nimini_widgetManagerRender, nimini_widgetManagerHandleInput,
    # Browser API
    nimini_localStorage_setItem, nimini_localStorage_getItem, nimini_window_open,
    # Animation/transition helpers (simple, safe)
    nimini_newTransition, nimini_updateTransition, nimini_transitionProgress,
    nimini_transitionEasedProgress, nimini_transitionIsActive, nimini_resetTransition,
    nimini_lerp, nimini_lerpInt, nimini_smoothstep,
    nimini_easeLinear, nimini_easeInQuad, nimini_easeOutQuad, nimini_easeInOutQuad,
    nimini_easeInCubic, nimini_easeOutCubic, nimini_easeInOutCubic,
    nimini_easeInSine, nimini_easeOutSine, nimini_easeInOutSine
    # Complex transition engine disabled - use BufferSnapshot helpers instead
    # nimini_newTransitionEngine, nimini_fadeEffect, nimini_slideEffect, nimini_wipeEffect,
    # nimini_dissolveEffect, nimini_pushEffect, nimini_newBufferSnapshot,
    # nimini_bufferSetCell, nimini_startTransition, nimini_updateTransitions,
    # nimini_hasActiveTransitions, nimini_getTransitionBuffer, nimini_bufferGetCell,
    # nimini_bufferWidth, nimini_bufferHeight
  )
  
  # Register platform-specific figlet functions - removed, now unified
  
  # Register transition constants
  defineVar(runtimeEnv, "EASE_LINEAR", valInt(EASE_LINEAR))
  defineVar(runtimeEnv, "EASE_IN_QUAD", valInt(EASE_IN_QUAD))
  defineVar(runtimeEnv, "EASE_OUT_QUAD", valInt(EASE_OUT_QUAD))
  defineVar(runtimeEnv, "EASE_IN_OUT_QUAD", valInt(EASE_IN_OUT_QUAD))
  defineVar(runtimeEnv, "EASE_IN_CUBIC", valInt(EASE_IN_CUBIC))
  defineVar(runtimeEnv, "EASE_OUT_CUBIC", valInt(EASE_OUT_CUBIC))
  defineVar(runtimeEnv, "EASE_IN_OUT_CUBIC", valInt(EASE_IN_OUT_CUBIC))
  defineVar(runtimeEnv, "EASE_IN_SINE", valInt(7))
  defineVar(runtimeEnv, "EASE_OUT_SINE", valInt(8))
  defineVar(runtimeEnv, "EASE_IN_OUT_SINE", valInt(9))
  defineVar(runtimeEnv, "DIR_LEFT", valInt(DIR_LEFT))
  defineVar(runtimeEnv, "DIR_RIGHT", valInt(DIR_RIGHT))
  defineVar(runtimeEnv, "DIR_UP", valInt(DIR_UP))
  defineVar(runtimeEnv, "DIR_DOWN", valInt(DIR_DOWN))
  defineVar(runtimeEnv, "DIR_CENTER", valInt(DIR_CENTER))
  
  let ctx = NiminiContext(env: runtimeEnv)
  
  return ctx

proc executeInputCodeBlock(context: NiminiContext, codeBlock: CodeBlock, state: AppState, event: InputEvent): tuple[success: bool, consumed: bool] =
  ## Execute an input code block and return both success status and event consumption
  ## Returns (true, true/false) on success with event consumption status
  ## Returns (false, false) on error
  if codeBlock.code.strip().len == 0:
    return (true, false)
  
  try:
    # Build a wrapper that includes state access
    var scriptCode = ""
    
    # Add state field accessors as local variables
    scriptCode.add("var termWidth = " & $state.termWidth & "\n")
    scriptCode.add("var termHeight = " & $state.termHeight & "\n")
    scriptCode.add("var fps = " & formatFloat(state.fps, ffDecimal, 2) & "\n")
    scriptCode.add("var frameCount = " & $state.frameCount & "\n")
    scriptCode.add("var deltaTime = 0.0\n")  # Not used in input blocks
    scriptCode.add("\n")
    
    # Add user code
    scriptCode.add(codeBlock.code)
    
    let tokens = tokenizeDsl(scriptCode)
    let program = parseDsl(tokens)
    
    # Input blocks run in child scope
    let execEnv = newEnv(context.env)
    
    # Expose the event object
    let eventValue = encodeInputEvent(event)
    defineVar(execEnv, "event", eventValue)
    
    # Execute and capture return value
    let returnValue = execProgramWithResult(program, execEnv)
    
    # Check if event was consumed
    # Scripts return 1 (or true) to indicate consumption, 0 (or false) otherwise
    var consumed = false
    case returnValue.kind
    of vkInt:
      consumed = returnValue.i != 0
    of vkBool:
      consumed = returnValue.b
    else:
      consumed = false
    
    return (true, consumed)
  except Exception as e:
    when not defined(emscripten):
      echo "Error in input block: ", e.msg
    when defined(emscripten):
      lastError = "Error in on:input - " & e.msg
    return (false, false)

proc executeCodeBlock(context: NiminiContext, codeBlock: CodeBlock, state: AppState, event: InputEvent = InputEvent(), deltaTime: float = 0.0): bool =
  ## Execute a code block using Nimini
  ## 
  ## Scoping rules:
  ## - 'init' blocks execute in global scope (all vars become global)
  ## - Other blocks execute in child scope:
  ##   - 'var x = 5' creates local variable
  ##   - 'x = 5' updates parent scope if exists, else creates local
  ##   - Reading variables walks up scope chain automatically
  if codeBlock.code.strip().len == 0:
    return true
  
  try:
    # Build a wrapper that includes state access
    # We expose common variables directly in the script context
    var scriptCode = ""
    
    # Add state field accessors as local variables
    scriptCode.add("var termWidth = " & $state.termWidth & "\n")
    scriptCode.add("var termHeight = " & $state.termHeight & "\n")
    scriptCode.add("var fps = " & formatFloat(state.fps, ffDecimal, 2) & "\n")
    scriptCode.add("var frameCount = " & $state.frameCount & "\n")
    scriptCode.add("var deltaTime = " & formatFloat(deltaTime, ffDecimal, 6) & "\n")
    
    # For input blocks, we'll inject the event variable later
    if codeBlock.lifecycle == "input":
      # Add a placeholder - the actual event will be set in the environment
      scriptCode.add("# event variable will be provided by runtime\n")
    
    scriptCode.add("\n")
    
    # Add user code
    scriptCode.add(codeBlock.code)
    
    let tokens = tokenizeDsl(scriptCode)
    let program = parseDsl(tokens)
    
    # Choose execution environment based on lifecycle
    # 'init' blocks run in global scope to define persistent state
    # Other blocks run in child scope for local variables
    let execEnv = if codeBlock.lifecycle == "init":
      context.env  # Global scope
    else:
      newEnv(context.env)  # Child scope with parent link
    
    # For input blocks, expose the event object
    if codeBlock.lifecycle == "input":
      let eventValue = encodeInputEvent(event)
      defineVar(execEnv, "event", eventValue)
    
    execProgram(program, execEnv)
    
    return true
  except Exception as e:
    when not defined(emscripten):
      echo "Error in ", codeBlock.lifecycle, " block: ", e.msg
    # In WASM, we can't echo, so we'll just fail silently but return false
    when defined(emscripten):
      lastError = "Error in on:" & codeBlock.lifecycle & " - " & e.msg
    return false

# ================================================================
# LIFECYCLE MANAGEMENT
# ================================================================

# Note: gMarkdownFile and gWaitingForGist are now defined in tstorie.nim

proc expandVariablesInText(text: string, frontMatter: FrontMatter): string =
  ## Expand `? variable` expressions in text using front matter values
  ## This is done once at parse time, before rendering
  ## NOTE: Only expands front matter variables. Nimini variables (like explorerLevel)
  ## are expanded at render time since they can change.
  result = text
  var pos = 0
  
  while pos < result.len:
    # Find backtick-wrapped variable references
    let btStart = result.find('`', pos)
    if btStart < 0:
      break
    
    let btEnd = result.find('`', btStart + 1)
    if btEnd < 0:
      break
    
    # Check if it's a variable reference (starts with ?)
    let content = result[btStart + 1 ..< btEnd]
    
    if content.len > 1 and content[0] == '?' and content[1] == ' ':
      let varName = content[2..^1].strip()
      
      # Look up value in front matter only
      if frontMatter.hasKey(varName):
        let value = frontMatter[varName]
        # Replace the entire backtick expression with the value
        result = result[0 ..< btStart] & value & result[btEnd + 1 .. ^1]
        pos = btStart + value.len
      else:
        # Not in front matter - leave the `? varName` syntax intact
        # It will be expanded at render time if it's a nimini variable
        pos = btEnd + 1
    else:
      # Not a variable reference, skip this backtick pair
      pos = btEnd + 1

proc expandVariablesInSections(sections: var seq[Section], frontMatter: FrontMatter) =
  ## Expand all `? variable` expressions in section text blocks
  for section in sections.mitems:
    for blk in section.blocks.mitems:
      case blk.kind
      of TextBlock:
        blk.text = expandVariablesInText(blk.text, frontMatter)
      of HeadingBlock:
        blk.title = expandVariablesInText(blk.title, frontMatter)
      else:
        discard

proc loadAndParseMarkdown(): MarkdownDocument =
  ## Load markdown file and parse it for code blocks and front matter
  when defined(emscripten):
    # Check if we're waiting for gist content
    if gWaitingForGist:
      # Return empty document - gist content will be loaded via JavaScript
      return MarkdownDocument()
    
    # In WASM, embed the markdown at compile time
    # Use staticRead with the markdown content
    const mdContent = staticRead("index.md")
    const mdLines = mdContent.splitLines()
    const mdLineCount = mdLines.len
    
    # Debug: detailed parsing info
    when defined(emscripten):
      lastError = "MD:" & $mdContent.len & "ch," & $mdLineCount & "ln"
      
    let doc = parseMarkdownDocument(mdContent)
    
    when defined(emscripten):
      if doc.codeBlocks.len == 0:
        lastError = lastError & "|0blocks"
        # Show first few lines of markdown to debug
        var preview = ""
        for i in 0 ..< min(3, mdLineCount):
          if i > 0: preview.add(";")
          let line = mdLines[i]
          preview.add(if line.len > 20: line[0..19] else: line)
        lastError = lastError & "|" & preview
      else:
        lastError = "" # Success!
    return doc
  else:
    # In native builds, read from filesystem
    let mdPath = gMarkdownFile
    
    if not fileExists(mdPath):
      echo "Warning: ", mdPath, " not found, using default behavior"
      return MarkdownDocument()
    
    try:
      let content = readFile(mdPath)
      return parseMarkdownDocument(content)
    except:
      echo "Error reading ", mdPath, ": ", getCurrentExceptionMsg()
      return MarkdownDocument()

# ================================================================
# INITIALIZE CONTEXT AND LAYERS
# ================================================================

proc exposeFrontMatterVariables*() =
  ## Expose front matter variables to the Nimini environment as globals
  ## This must be called after the Nimini context is created and after
  ## frontMatter is populated
  if storieCtx.isNil or storieCtx.niminiContext.isNil:
    return
  
  for key, value in storieCtx.frontMatter.pairs:
    # Try to parse as number first, otherwise store as string
    try:
      let numVal = parseFloat(value)
      if '.' in value:
        setGlobal(key, valFloat(numVal))
      else:
        setGlobal(key, valInt(numVal.int))
    except:
      # Not a number, store as string
      setGlobal(key, valString(value))

proc initStorieContext(state: AppState) =
  ## Initialize the Storie context, parse Markdown, and set up layers
  if storieCtx.isNil:
    storieCtx = StorieContext()
  
  # Initialize global random number generator
  initGlobalRng()
  
  # Connect Nimini stdlib random functions to use the same RNG
  setNiminiRng(addr globalRng)
  
  # Load and parse markdown document (with front matter and sections)
  let doc = loadAndParseMarkdown()
  storieCtx.codeBlocks = doc.codeBlocks
  storieCtx.frontMatter = doc.frontMatter
  storieCtx.styleSheet = doc.styleSheet
  
  # Expand `? variable` expressions in section text before creating section manager
  var sections = doc.sections
  expandVariablesInSections(sections, doc.frontMatter)
  storieCtx.sectionMgr = newSectionManager(sections)
  
  # Also store styleSheet in state for API access
  state.styleSheet = doc.styleSheet
  
  # Extract theme background color from stylesheet (body style or default to black)
  if doc.styleSheet.hasKey("body"):
    storieCtx.themeBackground = doc.styleSheet["body"].bg
    state.themeBackground = storieCtx.themeBackground
    # Debug: print stylesheet contents
    when not defined(emscripten):
      echo "Stylesheet loaded with ", doc.styleSheet.len, " styles:"
      for name, style in doc.styleSheet:
        echo "  ", name, " -> bg=(", style.bg.r, ",", style.bg.g, ",", style.bg.b, ") fg=(", style.fg.r, ",", style.fg.g, ",", style.fg.b, ")"
  else:
    storieCtx.themeBackground = (0'u8, 0'u8, 0'u8)
    state.themeBackground = (0'u8, 0'u8, 0'u8)
  
  when defined(emscripten):
    if storieCtx.codeBlocks.len == 0 and lastError.len == 0 and not gWaitingForGist:
      lastError = "No code blocks parsed"
  
  # Apply front matter settings to state
  if storieCtx.frontMatter.hasKey("targetFPS"):
    try:
      let fps = parseFloat(storieCtx.frontMatter["targetFPS"])
      state.setTargetFps(fps)
      when not defined(emscripten):
        echo "Set target FPS from front matter: ", fps
    except:
      when not defined(emscripten):
        echo "Warning: Invalid targetFPS value in front matter"
  
  # Parse minWidth and minHeight from front matter
  storieCtx.minWidth = 0
  storieCtx.minHeight = 0
  if storieCtx.frontMatter.hasKey("minWidth"):
    try:
      storieCtx.minWidth = parseInt(storieCtx.frontMatter["minWidth"])
      when defined(emscripten):
        globalMinWidth = storieCtx.minWidth
      when not defined(emscripten):
        echo "Minimum width set from front matter: ", storieCtx.minWidth
    except:
      when not defined(emscripten):
        echo "Warning: Invalid minWidth value in front matter"
  if storieCtx.frontMatter.hasKey("minHeight"):
    try:
      storieCtx.minHeight = parseInt(storieCtx.frontMatter["minHeight"])
      when defined(emscripten):
        globalMinHeight = storieCtx.minHeight
      when not defined(emscripten):
        echo "Minimum height set from front matter: ", storieCtx.minHeight
    except:
      when not defined(emscripten):
        echo "Warning: Invalid minHeight value in front matter"
  
  # Create single default layer (layer 0)
  gDefaultLayer = state.addLayer("default", 0)
  
  # Initialize styles
  var textStyle = defaultStyle()
  textStyle.fg = cyan()
  textStyle.bold = true

  var borderStyle = defaultStyle()
  borderStyle.fg = green()

  var infoStyle = defaultStyle()
  infoStyle.fg = yellow()
  
  # Set global references for Nimini wrappers
  gTextStyle = textStyle
  gBorderStyle = borderStyle
  gInfoStyle = infoStyle
  gAppState = state  # Store state reference for accessors
  
  when not defined(emscripten):
    echo "Loaded ", storieCtx.codeBlocks.len, " code blocks from ", gMarkdownFile
    if storieCtx.frontMatter.len > 0:
      echo "Front matter keys: ", toSeq(storieCtx.frontMatter.keys).join(", ")
  
  # Create nimini context first (initializes runtime)
  storieCtx.niminiContext = createNiminiContext(state)
  
  # Flush pending parameters (URL params that were set before runtime was initialized)
  flushPendingParams()
  
  # Now register module bindings (must be after runtime init)
  registerSectionManagerBindings(addr storieCtx.sectionMgr)
  registerCanvasBindings(addr gDefaultLayer.buffer, addr gAppState, addr storieCtx.styleSheet)
  
  # Expose front matter to user scripts as global variables
  exposeFrontMatterVariables()
  
  # Check for theme parameter and apply if present (overrides front matter theme)
  if hasParamDirect("theme"):
    let themeName = getParamDirect("theme")
    if themeName.len > 0:
      when not defined(emscripten):
        echo "Applying theme from parameter: ", themeName
      try:
        let newStyleSheet = applyThemeByName(themeName)
        # Update storieCtx and state with new stylesheet
        storieCtx.styleSheet = newStyleSheet
        state.styleSheet = newStyleSheet
        # Update theme background
        if newStyleSheet.hasKey("body"):
          storieCtx.themeBackground = newStyleSheet["body"].bg
          state.themeBackground = storieCtx.themeBackground
        # Re-register canvas bindings with new stylesheet pointer
        # (necessary because styleSheet is a value type, not ref)
        registerCanvasBindings(addr gDefaultLayer.buffer, addr gAppState, addr storieCtx.styleSheet)
        # Clear and redraw all layers with new theme background
        for layer in state.layers:
          layer.buffer.clear(state.themeBackground)
      except:
        when not defined(emscripten):
          echo "Warning: Theme '", themeName, "' not found"
  
  # Execute init code blocks
  when not defined(emscripten):
    echo "Found ", storieCtx.codeBlocks.len, " code blocks total"
    var initCount = 0
    for cb in storieCtx.codeBlocks:
      if cb.lifecycle == "init":
        initCount += 1
    echo "Found ", initCount, " init blocks"
  
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "init":
      when not defined(emscripten):
        echo "Executing init block..."
      let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
      when not defined(emscripten):
        echo "Init block execution result: ", success
      if not success:
        when defined(emscripten):
          if lastError.len == 0:
            lastError = "init block failed"
        when not defined(emscripten):
          echo "WARNING: Init block failed to execute"

proc checkMinimumDimensions*(state: AppState): bool =
  ## Check if current terminal dimensions meet minimum requirements.
  ## Returns true if dimensions are OK, false if too small.
  ## When false, renders a centered warning message.
  if storieCtx.isNil:
    gShowingDimensionWarning = false
    return true  # No requirements if context not initialized
  
  # Check if minimum dimensions are required
  if storieCtx.minWidth <= 0 and storieCtx.minHeight <= 0:
    gShowingDimensionWarning = false
    return true  # No minimum requirements
  
  let needsWidth = storieCtx.minWidth > 0 and state.termWidth < storieCtx.minWidth
  let needsHeight = storieCtx.minHeight > 0 and state.termHeight < storieCtx.minHeight
  
  if not needsWidth and not needsHeight:
    gShowingDimensionWarning = false
    return true  # Dimensions are sufficient
  
  # Set flag to prevent layer compositing from overwriting our message
  gShowingDimensionWarning = true
  
  # Clear screen and render centered warning message
  state.currentBuffer.clear((0'u8, 0'u8, 0'u8))
  
  # Build the message lines
  var lines: seq[string] = @[]
  let reqWidth = if storieCtx.minWidth > 0: storieCtx.minWidth else: state.termWidth
  let reqHeight = if storieCtx.minHeight > 0: storieCtx.minHeight else: state.termHeight
  
  lines.add($reqWidth & " x " & $reqHeight & " dimensions required.")
  lines.add("Resize terminal to continue. Press CTRL-C to quit.")
  
  # Calculate centering
  let maxLen = max(lines[0].len, lines[1].len)
  let centerY = state.termHeight div 2
  let centerX = (state.termWidth - maxLen) div 2
  
  # Render lines centered
  var warnStyle = defaultStyle()
  #warnStyle.fg = yellow()
  warnStyle.bold = true
  
  for i, line in lines:
    let lineX = (state.termWidth - line.len) div 2
    let lineY = centerY + i
    if lineY >= 0 and lineY < state.termHeight:
      state.currentBuffer.writeText(lineX, lineY, line, warnStyle)
  
  return false

# ================================================================
# CALLBACK IMPLEMENTATIONS
# ================================================================

onInit = proc(state: AppState) =
  initStorieContext(state)

onUpdate = proc(state: AppState, dt: float) =
  if storieCtx.isNil:
    return
  
  # 1. Execute global update handlers first (modules like canvas)
  for handler in storieCtx.globalUpdateHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        discard handler.callback.fnVal.native(env, @[valFloat(dt)])
    except Exception as e:
      when not defined(emscripten):
        echo "Error in global update handler '", handler.name, "': ", e.msg
  
  # 2. Execute section-specific on:update blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "update":
      discard executeCodeBlock(storieCtx.niminiContext, codeBlock, state, InputEvent(), dt)

onRender = proc(state: AppState) =
  # Check if dimensions meet requirements first
  if not checkMinimumDimensions(state):
    # Warning message already rendered, skip all normal rendering
    # Note: gShowingDimensionWarning flag prevents compositeLayers from running
    return
  
  if storieCtx.isNil:
    when defined(emscripten):
      lastRenderExecutedCount = 0
      # Write error directly to currentBuffer so it's visible
      var errStyle = defaultStyle()
      errStyle.fg = red()
      errStyle.bold = true
      state.currentBuffer.writeText(5, 5, "ERROR: storieCtx is nil!", errStyle)
    # Fallback rendering if no context
    let msg = "No " & gMarkdownFile & " found or parsing failed"
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackStyle = defaultStyle()
    fallbackStyle.fg = cyan()
    state.currentBuffer.writeText(x, y, msg, fallbackStyle)
    return
  
  # 1. Execute global render handlers first (modules like canvas)
  for handler in storieCtx.globalRenderHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        discard handler.callback.fnVal.native(env, @[])
    except Exception as e:
      when not defined(emscripten):
        echo "Error in global render handler '", handler.name, "': ", e.msg
  
  # Check if we have any render blocks
  var hasRenderBlocks = false
  var renderBlockCount = 0
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      hasRenderBlocks = true
      renderBlockCount += 1
  
  if not hasRenderBlocks and storieCtx.globalRenderHandlers.len == 0:
    when defined(emscripten):
      lastRenderExecutedCount = 0
      if lastError.len == 0:
        lastError = "No on:render blocks"
    # Fallback if no render blocks found
    state.currentBuffer.clear()
    let msg = "No render blocks found in " & gMarkdownFile
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackInfoStyle = defaultStyle()
    fallbackInfoStyle.fg = yellow()
    state.currentBuffer.writeText(x, y, msg, fallbackInfoStyle)
    
    # Show what blocks we DO have
    when defined(emscripten):
      var debugStyle = defaultStyle()
      debugStyle.fg = cyan()
      var debugY = y + 2
      for codeBlock in storieCtx.codeBlocks:
        let info = "Found: on:" & codeBlock.lifecycle
        state.currentBuffer.writeText(x, debugY, info, debugStyle)
        debugY += 1
    return
  
  # 2. Execute section-specific on:render code blocks
  var executedCount = 0
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
      if success:
        executedCount += 1
  
  # Debug: Show execution status in WASM
  # Write to foreground layer so user code renders, then we overlay debug on layers
  when defined(emscripten):
    var debugStyle = defaultStyle()
    debugStyle.fg = green()
    debugStyle.bold = true
    gDefaultLayer.buffer.writeText(2, 2, "Blocks: " & $storieCtx.codeBlocks.len & " Render: " & $renderBlockCount & " Exec: " & $executedCount, debugStyle)

    # Publish executedCount to WASM HUD
    lastRenderExecutedCount = executedCount
    
    if executedCount == 0 and renderBlockCount > 0:
      var errorStyle = defaultStyle()
      errorStyle.fg = red()
      errorStyle.bold = true
      gDefaultLayer.buffer.writeText(2, 3, "Render execution FAILED!", errorStyle)
      # Also show last error if available
      if lastError.len > 0:
        gDefaultLayer.buffer.writeText(2, 4, "Error: " & lastError, errorStyle)
    
    # Also show frame count to verify rendering is happening
    var fpsStyle = defaultStyle()
    fpsStyle.fg = yellow()
    gDefaultLayer.buffer.writeText(2, 0, "Frame: " & $state.frameCount, fpsStyle)

# Define input handler as a separate proc, then assign
proc inputHandler(state: AppState, event: InputEvent): bool =
  if storieCtx.isNil:
    return false
  
  # 1. Execute global input handlers first (allow modules to intercept)
  for handler in storieCtx.globalInputHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        # Encode input event as a Nimini Value
        let eventValue = encodeInputEvent(event)
        let result = handler.callback.fnVal.native(env, @[eventValue])
        # If handler returns true, it consumed the event
        if result.kind == vkBool and result.b:
          return true
    except Exception as e:
      when not defined(emscripten):
        echo "Error in global input handler '", handler.name, "': ", e.msg
  
  # 2. Execute section-specific on:input blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "input":
      let (success, consumed) = executeInputCodeBlock(storieCtx.niminiContext, codeBlock, state, event)
      if success and consumed:
        return true
  
  # 3. Default handlers (only if not consumed by user code)
  
  # Handle canvas input if canvas is initialized
  if not canvasState.isNil and event.kind == KeyEvent and event.keyAction == Press:
    if canvasHandleKey(event.keyCode, {}):
      return true
  
  # Default quit behavior (Q or ESC)
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == ord('q') or event.keyCode == ord('Q') or event.keyCode == INPUT_ESCAPE:
      state.running = false
      return true
  
  return false

# Don't assign here in WASM - it will be done in tstorie.nim after include
when not defined(emscripten):
  onInput = inputHandler

onShutdown = proc(state: AppState) =
  if storieCtx.isNil:
    return
  
  # Execute shutdown code blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "shutdown":
      discard executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
