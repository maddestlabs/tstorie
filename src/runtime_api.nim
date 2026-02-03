# Runtime API Implementation
# 
# This file contains the runtime API and lifecycle management for tStorie.
# It was previously named index.nim but has been moved to src/ for better organization.
#
# Contents:
# - Nimini integration helpers (type conversion, print, etc.)
# - Style conversion between nimini and native types
# - Unified drawing API (draw, clear, fillRect)
# - Random number generation wrappers
# - Global event handler management (render/update/input hooks)
# - Theme and stylesheet management  
# - Mouse handling wrappers
# - Browser API wrappers (localStorage, window.open, etc.)
# - Canvas system initialization
# - Layout module wrappers
# - Animation and easing functions
# - FIGlet font loading and rendering
# - Nimini context creation and API registration
# - Code block execution engine
# - Markdown loading and variable expansion
# - Lifecycle callbacks (onInit, onUpdate, onRender, onInput, onShutdown)
#
# This file is included (not imported) by tstorie.nim to share namespace.
# All tstorie types, lib modules, and globals are available from the parent scope.
#
# Future refactoring opportunities:
# - Split into focused modules: drawing_api.nim, style_api.nim, animation_api.nim,
#   figlet_api.nim, event_handlers.nim, lifecycle.nim
# - Convert from 'include' to 'import' pattern once circular dependencies are resolved
# - Move lifecycle callbacks to a separate lifecycle.nim module
# - Consider creating a unified API registration module

# ================================================================
# METADATA REGISTRATION - For Export System
# ================================================================
# Register function metadata at module load time so exports can discover them

proc registerTStorieMetadata*() =
  ## Register metadata for tStorie functions
  ## This must be called before exports to ensure metadata is available
  
  # Figlet functions
  gFunctionMetadata["figletLoadFont"] = FunctionMetadata(
    storieLibs: @["figlet"],
    description: "Load a FIGlet font by name")
  gFunctionMetadata["figletIsFontLoaded"] = FunctionMetadata(
    storieLibs: @["figlet"],
    description: "Check if a FIGlet font is loaded")
  gFunctionMetadata["figletRender"] = FunctionMetadata(
    storieLibs: @["figlet"],
    description: "Render text using a loaded FIGlet font")
  gFunctionMetadata["figletListAvailableFonts"] = FunctionMetadata(
    storieLibs: @["figlet"],
    description: "List all available FIGlet fonts")
  gFunctionMetadata["drawFigletText"] = FunctionMetadata(
    storieLibs: @["figlet"],
    dependencies: @["draw"],
    description: "Draw FIGlet text to a layer")

# Register metadata at module load
registerTStorieMetadata()

# ================================================================
# NIMINI INTEGRATION - Helper Functions
# ================================================================

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
when defined(emscripten) and not defined(sdl3Backend):
  # JavaScript console log helper (defined in console_bridge.js)
  proc emConsoleLog(msg: cstring) {.importc: "emConsoleLog".}

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
  
  when defined(emscripten) and not defined(sdl3Backend):
    # In WASM, also log to browser console
    emConsoleLog(output.cstring)
  else:
    echo output
  
  return valNil()

# ================================================================
# SDL3 PIXEL-BASED RENDERING API
# ================================================================

when defined(sdl3Backend):
  # Global SDL3 rendering state
  var gSDL3Canvas: SDLCanvas = nil
  var gSDL3FillColor: Color = rgb(255, 255, 255)
  
  proc setSDL3Canvas*(canvas: SDLCanvas) =
    ## Set the global SDL3 canvas for rendering
    gSDL3Canvas = canvas
  
  proc setFillColor(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## setFillColor(r, g, b) - Set the fill color for SDL3 rendering
    if args.len >= 3:
      gSDL3FillColor = rgb(toInt(args[0]).uint8, toInt(args[1]).uint8, toInt(args[2]).uint8)
    return valNil()
  
  proc sdl3FillRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## fillRect(x, y, w, h) - Fill a rectangle with current color
    if args.len >= 4 and not gSDL3Canvas.isNil:
      let x = toInt(args[0])
      let y = toInt(args[1])
      let w = toInt(args[2])
      let h = toInt(args[3])
      # Create a style with the fill color as background
      var fillStyle = defaultStyle()
      fillStyle.bg = gSDL3FillColor
      gSDL3Canvas.fillRect(x, y, w, h, " ", fillStyle)
    return valNil()
  
  proc width(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## width() - Get canvas width in pixels
    if not gSDL3Canvas.isNil:
      return valInt(gSDL3Canvas.width)
    return valInt(800)
  
  proc height(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## height() - Get canvas height in pixels
    if not gSDL3Canvas.isNil:
      return valInt(gSDL3Canvas.height)
    return valInt(600)
  
  proc text(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## text(str, x, y) - Draw text (placeholder - no TTF support yet)
    # TODO: Implement TTF text rendering when font support is added
    return valNil()
  
  # ================================================================
  # CELL-BASED TERMINAL EMULATION FOR SDL3
  # ================================================================
  # These functions write to the virtual terminal grid in the SDL3 canvas
  # The grid is rendered to pixels each frame
  
  proc sdl3DrawCell(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## draw(layer, x, y, text, style) - Draw text to layer buffer for SDL3
    
    if gSDL3Canvas.isNil:
      return valNil()
    
    if args.len < 4:
      return valNil()
    
    # Resolve layer from first argument (string or int)
    var layer: Layer = nil
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < gAppState.layers.len:
        layer = gAppState.layers[idx]
      elif idx == 0 and gAppState.layers.len == 0:
        # Auto-create default layer only if it doesn't exist
        layer = gAppState.getLayer("default")
        if layer.isNil:
          layer = gAppState.addLayer("default", 0)
    elif args[0].kind == vkString:
      let layerId = args[0].s
      layer = gAppState.getLayer(layerId)
      if layer.isNil and (layerId == "default" or layerId == ""):
        # Auto-create default layer only if it doesn't exist
        layer = gAppState.addLayer("default", 0)
    
    if layer.isNil:
      return valNil()
    
    let x = toInt(args[1])
    let y = toInt(args[2])
    let text = args[3].s
    let style = if args.len >= 5: valueToStyle(args[4]) else: defaultStyle()
    
    # Write to layer buffer (not directly to canvas)
    layer.buffer.writeCellText(x, y, text, style)
    
    return valNil()
  
  proc sdl3ClearCells(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## clear([layer], [transparent]) - Clear layer buffer for SDL3
    
    if gSDL3Canvas.isNil:
      return valNil()
    
    # Determine background color
    let bg = if not storieCtx.isNil: 
      (storieCtx.themeBackground.r, storieCtx.themeBackground.g, storieCtx.themeBackground.b)
    else:
      (0'u8, 0'u8, 0'u8)
    
    # No args - clear all layers
    if args.len == 0:
      for layer in gAppState.layers:
        layer.buffer.clearCells(bg)
      return valNil()
    
    # Resolve layer from first argument
    var layer: Layer = nil
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < gAppState.layers.len:
        layer = gAppState.layers[idx]
    elif args[0].kind == vkString:
      layer = gAppState.getLayer(args[0].s)
    
    if layer.isNil:
      return valNil()
    
    let transparent = if args.len >= 2: toBool(args[1]) else: false
    
    if transparent:
      layer.buffer.clearCellsTransparent()
    else:
      layer.buffer.clearCells(bg)
    
    return valNil()
  
  proc sdl3FillCellRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## fillRect(layer, x, y, w, h, char, style) - Fill cell rectangle in layer buffer
    if args.len < 6 or gSDL3Canvas.isNil:
      return valNil()
    
    # Resolve layer from first argument
    var layer: Layer = nil
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < gAppState.layers.len:
        layer = gAppState.layers[idx]
      elif idx == 0 and gAppState.layers.len == 0:
        # Auto-create default layer only if it doesn't exist
        layer = gAppState.getLayer("default")
        if layer.isNil:
          layer = gAppState.addLayer("default", 0)
    elif args[0].kind == vkString:
      let layerId = args[0].s
      layer = gAppState.getLayer(layerId)
      if layer.isNil and (layerId == "default" or layerId == ""):
        # Auto-create default layer only if it doesn't exist
        layer = gAppState.addLayer("default", 0)
    
    if layer.isNil:
      return valNil()
    
    let x = toInt(args[1])
    let y = toInt(args[2])
    let w = toInt(args[3])
    let h = toInt(args[4])
    let ch = args[5].s
    let style = if args.len >= 7: valueToStyle(args[6]) else: defaultStyle()
    
    layer.buffer.fillCellRect(x, y, w, h, ch, style)
    
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

# Note: valueToStyle is available for use in binding files since runtime_api.nim
# is included by tstorie.nim and shares the same scope

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
                if idx == 0:
                  gDefaultLayer
                elif idx < 0:
                  return valNil()  # Negative index is invalid
                elif idx >= gAppState.layers.len:
                  # Auto-create layer if it doesn't exist (z-value = index)
                  discard gAppState.addLayer("layer" & $idx, idx)
                  gAppState.layers[idx]
                else:
                  gAppState.layers[idx]
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let x = toInt(args[1])
  let y = toInt(args[2])
  let text = args[3].s
  
  # Use theme's default style if no style is provided
  let style = if args.len >= 5:
    valueToStyle(args[4])
  elif not storieCtx.isNil and storieCtx.styleSheet.hasKey("default"):
    storieCtx.styleSheet["default"].toStyle()
  else:
    gTextStyle
  
  layer.buffer.writeCellText(x, y, text, style)
  return valNil()

proc clear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## clear([layer: string|int], [transparent: bool])
  ## Clear layer(s). With no args, clears all layers.
  ## Layer 0 is the default layer.
  
  # No args - clear all layers
  if args.len == 0:
    for layer in gAppState.layers:
      layer.buffer.clearCells(storieCtx.themeBackground)
    return valNil()
  
  # Determine layer from first arg (supports both string and int)
  let layer = if args[0].kind == vkInt:
                let idx = args[0].i
                if idx == 0: gDefaultLayer
                elif idx < 0 or idx >= gAppState.layers.len:
                  # Invalid index or layer doesn't exist - auto-create if positive
                  if idx > 0:
                    discard gAppState.addLayer("layer" & $idx, idx)
                    gAppState.layers[idx]
                  else:
                    return valNil()  # Negative index is invalid
                else:
                  gAppState.layers[idx]
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let transparent = if args.len >= 2: toBool(args[1]) else: false
  
  if transparent:
    layer.buffer.clearCellsTransparent()
  else:
    layer.buffer.clearCells(storieCtx.themeBackground)
  return valNil()

proc forceRedraw(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## forceRedraw()
  ## Force a complete screen redraw on the next frame.
  ## Useful after font changes, theme changes, or when display needs refreshing.
  ## Works across all backends (SDL3, terminal, WebGL).
  
  when defined(sdl3Backend):
    # SDL3: Invalidate dirty tracking to force complete redraw
    if not globalCanvas.isNil:
      globalCanvas.firstFrame = true
      for i in 0..<globalCanvas.prevCells.len:
        globalCanvas.prevCells[i].ch = ""
  # Terminal/WebGL: Layers are redrawn every frame, no action needed
  
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
                elif idx < 0:
                  return valNil()  # Negative index is invalid
                elif idx >= gAppState.layers.len:
                  # Auto-create layer if it doesn't exist (z-value = index)
                  discard gAppState.addLayer("layer" & $idx, idx)
                  gAppState.layers[idx]
                else:
                  gAppState.layers[idx]
              elif args[0].kind == vkString:
                let layerId = args[0].s
                let foundLayer = getLayer(gAppState, layerId)
                if foundLayer.isNil: return valNil()
                foundLayer
              else:
                return valNil()
  
  let x = toInt(args[1])
  let y = toInt(args[2])
  let w = toInt(args[3])
  let h = toInt(args[4])
  let ch = args[5].s
  
  # Use theme's default style if no style is provided
  let style = if args.len >= 7:
    valueToStyle(args[6])
  elif not storieCtx.isNil and storieCtx.styleSheet.hasKey("default"):
    storieCtx.styleSheet["default"].toStyle()
  else:
    gTextStyle
  
  layer.buffer.fillCellRect(x, y, w, h, ch, style)
  return valNil()

# ================================================================
# LAYER MANAGEMENT
# ================================================================

proc nimini_addLayer(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## addLayer(id: string, z: int) -> creates a new layer
  ## Higher z values are drawn on top of lower z values
  ## Returns the layer index for use with drawing functions
  if args.len < 2:
    return valNil()
  
  let id = args[0].s
  let z = toInt(args[1])
  
  # Add layer to AppState (unified for all backends)
  let layer = gAppState.addLayer(id, z)
  if not layer.isNil:
    # Return the array index for convenience
    for i in 0 ..< gAppState.layers.len:
        if gAppState.layers[i] == layer:
          return valInt(i)
  
  return valNil()

proc nimini_removeLayer(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## removeLayer(id: string) -> removes a layer by ID
  if args.len < 1:
    return valNil()
  
  let id = args[0].s
  gAppState.removeLayer(id)
  return valNil()

proc nimini_setLayerVisible(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## setLayerVisible(id: string, visible: bool) -> show/hide a layer
  if args.len < 2:
    return valNil()
  
  let id = args[0].s
  let visible = toBool(args[1])
  
  let layer = getLayer(gAppState, id)
  if not layer.isNil:
    layer.visible = visible
  
  return valNil()

proc nimini_getLayerCount(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## getLayerCount() -> returns the number of layers
  return valInt(gAppState.layers.len)

# Random number generator and functions are now in tstorie.nim

# Random number functions - now consistent across platforms
proc randInt(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate random integer: randInt(max) returns 0..max-1, randInt(min, max) returns min..max-1
  if args.len == 0:
    return valInt(0)
  elif args.len == 1:
    let max = toInt(args[0])
    return valInt(rand(globalRng, max - 1))
  else:
    let min = toInt(args[0])
    let max = toInt(args[1])
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
# Note: State accessors are in tstorie.nim's
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

proc nimini_setDefaultStyle(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## setDefaultStyle(style: map) -> nil
  ## Override the global default style used throughout the system
  if args.len < 1 or args[0].kind != vkMap:
    return valNil()
  
  var config = getDefaultStyleConfig()  # Start with current defaults
  let styleMap = args[0].map
  
  # Update fields if present in the map
  if styleMap.hasKey("fg"):
    let fgVal = styleMap["fg"]
    if fgVal.kind == vkArray and fgVal.arr.len == 3:
      config.fg = (
        uint8(fgVal.arr[0].i),
        uint8(fgVal.arr[1].i),
        uint8(fgVal.arr[2].i)
      )
  
  if styleMap.hasKey("bg"):
    let bgVal = styleMap["bg"]
    if bgVal.kind == vkArray and bgVal.arr.len == 3:
      config.bg = (
        uint8(bgVal.arr[0].i),
        uint8(bgVal.arr[1].i),
        uint8(bgVal.arr[2].i)
      )
  
  if styleMap.hasKey("bold") and styleMap["bold"].kind == vkBool:
    config.bold = styleMap["bold"].b
  
  if styleMap.hasKey("italic") and styleMap["italic"].kind == vkBool:
    config.italic = styleMap["italic"].b
  
  if styleMap.hasKey("underline") and styleMap["underline"].kind == vkBool:
    config.underline = styleMap["underline"].b
  
  if styleMap.hasKey("dim") and styleMap["dim"].kind == vkBool:
    config.dim = styleMap["dim"].b
  
  setDefaultStyleConfig(config)
  return valNil()

proc nimini_getStyle(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## getStyle(name: string) -> Style map
  ## Retrieve a named style from the stylesheet defined in front matter
  if args.len < 1:
    # No style name provided, try to get "default" from stylesheet first
    if not storieCtx.isNil and storieCtx.styleSheet.hasKey("default"):
      return styleConfigToValue(storieCtx.styleSheet["default"])
    return styleConfigToValue(getDefaultStyleConfig())
  
  let styleName = args[0].s
  
  # Access the stylesheet from storieCtx
  if not storieCtx.isNil and storieCtx.styleSheet.hasKey(styleName):
    return styleConfigToValue(storieCtx.styleSheet[styleName])
  
  # Fallback to "default" entry in stylesheet, then hardcoded default
  if not storieCtx.isNil and storieCtx.styleSheet.hasKey("default"):
    return styleConfigToValue(storieCtx.styleSheet["default"])
  return styleConfigToValue(getDefaultStyleConfig())

proc nimini_getThemes(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get list of available theme names. Returns array of strings
  let themes = getAvailableThemes()
  var themeValues: seq[Value] = @[]
  for theme in themes:
    themeValues.add(valString(theme))
  return valArray(themeValues)

proc nimini_switchTheme(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Switch to a different theme at runtime. Args: themeName (string), [clearScreen (bool)]
  ## Returns: bool (true if successful)
  ## If clearScreen is true, all layers will be cleared after theme switch (default: true)
  if args.len == 0 or storieCtx.isNil:
    return valBool(false)
  
  let themeName = args[0].s
  let clearScreen = if args.len >= 2: toBool(args[1]) else: true
  
  # Apply the new theme
  let newStyleSheet = applyThemeByName(themeName)
  
  # Update the stored stylesheet
  storieCtx.styleSheet = newStyleSheet
  
  # Update theme background color if stylesheet has "default" style
  if newStyleSheet.hasKey("default"):
    storieCtx.themeBackground = newStyleSheet["default"].bg

  when defined(emscripten):
    proc js_setThemeBackground(r, g, b: cint) {.importc: "tStorie_setThemeBackground".}
    js_setThemeBackground(storieCtx.themeBackground.r.cint, storieCtx.themeBackground.g.cint, storieCtx.themeBackground.b.cint)
  
  # Also need to update the canvas stylesheet pointer if canvas is active
  if not canvasState.isNil:
    # Re-register canvas bindings to update the stylesheet pointer
    registerCanvasBindings(addr gDefaultLayer.buffer, addr gAppState, addr storieCtx.styleSheet)
    registerCanvasEditorBindings()
  
  # Optionally clear all layers to apply new theme immediately
  if clearScreen:
    for layer in gAppState.layers:
      layer.buffer.clearCells(storieCtx.themeBackground)
    when defined(sdl3Backend):
      if not globalCanvas.isNil:
        globalCanvas.firstFrame = true
        for i in 0..<globalCanvas.prevCells.len:
          globalCanvas.prevCells[i].ch = ""
  
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
# BROWSER API (WASM)
# ================================================================

# JavaScript interop for browser functions
when defined(emscripten) and not defined(sdl3Backend):
  # Old WASM build JS bridge
  proc js_callFunction(funcName: cstring): cstring {.importc: "tStorie_callFunction".}
  proc js_callFunctionWithArg(funcName: cstring, arg: cstring): cstring {.importc: "tStorie_callFunctionWithArg".}
  proc js_callFunctionWith2Args(funcName: cstring, arg1: cstring, arg2: cstring): cstring {.importc: "tStorie_callFunctionWith2Args".}

proc nimini_localStorage_setItem(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Save content to browser localStorage. Args: key, value
  if args.len >= 2:
    let key = args[0].s
    let value = args[1].s
    when defined(emscripten) and not defined(sdl3Backend):
      let result = js_callFunctionWith2Args("tStorie_saveLocal".cstring, key.cstring, value.cstring)
      return valBool($result == "true")
    else:
      echo "localStorage_setItem: ", key, " (", value.len, " bytes)"
      return valBool(true)
  return valBool(false)

proc nimini_localStorage_getItem(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Load content from browser localStorage. Args: key
  if args.len >= 1:
    let key = args[0].s
    when defined(emscripten) and not defined(sdl3Backend):
      let value = js_callFunctionWithArg("tStorie_loadLocal".cstring, key.cstring)
      return valString($value)
    else:
      echo "localStorage_getItem: ", key
      return valString("")
  return valString("")

proc nimini_localStorage_list(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## List all saved documents in localStorage. Returns JSON string
  when defined(emscripten) and not defined(sdl3Backend):
    let json = js_callFunction("tStorie_listLocal".cstring)
    return valString($json)
  else:
    return valString("[]")

proc nimini_localStorage_delete(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Delete item from localStorage. Args: key
  if args.len >= 1:
    let key = args[0].s
    when defined(emscripten) and not defined(sdl3Backend):
      let result = js_callFunctionWithArg("tStorie_deleteLocal".cstring, key.cstring)
      return valBool($result == "true")
    else:
      echo "localStorage_delete: ", key
      return valBool(true)
  return valBool(false)

proc nimini_copyToClipboard(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Copy text to clipboard. Args: text
  if args.len >= 1:
    let text = args[0].s
    when defined(emscripten) and not defined(sdl3Backend):
      let result = js_callFunctionWithArg("tStorie_copyToClipboard".cstring, text.cstring)
      return valBool($result == "true")
    else:
      echo "copyToClipboard: ", text[0..min(50, text.len-1)], "..."
      return valBool(true)
  return valBool(false)

proc nimini_pasteFromClipboard(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Paste text from clipboard. Returns empty string on native builds.
  when defined(emscripten) and not defined(sdl3Backend):
    let text = js_callFunction("tStorie_pasteFromClipboard".cstring)
    return valString($text)
  else:
    echo "pasteFromClipboard: (not available in native build)"
    return valString("")

proc nimini_compressToUrl(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Compress content and return shareable URL. Args: content
  ## Note: This is async in JS, so the URL may not be immediately available
  if args.len >= 1:
    let content = args[0].s
    when defined(emscripten) and not defined(sdl3Backend):
      let url = js_callFunctionWithArg("tStorie_compressToUrl".cstring, content.cstring)
      return valString($url)
    else:
      return valString("http://localhost:8000/?content=demo:edit")
  return valString("")

proc nimini_generateAndCopyShareUrl(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Trigger async URL generation and clipboard copy. Args: content
  ## Returns immediately. Check with checkShareUrlReady() for completion.
  if args.len >= 1:
    let content = args[0].s
    when defined(emscripten) and not defined(sdl3Backend):
      discard js_callFunctionWithArg("tStorie_generateAndCopyShareUrl".cstring, content.cstring)
    else:
      echo "generateAndCopyShareUrl: ", content.len, " bytes"
  return valNil()

proc nimini_checkShareUrlReady(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if async URL generation is complete. Returns "true" or "false"
  when defined(emscripten) and not defined(sdl3Backend):
    let ready = js_callFunction("tStorie_checkShareUrlReady".cstring)
    return valString($ready)
  else:
    return valString("true")

proc nimini_getShareUrl(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the generated share URL (call after checkShareUrlReady returns true)
  when defined(emscripten) and not defined(sdl3Backend):
    let url = js_callFunction("tStorie_getShareUrl".cstring)
    return valString($url)
  else:
    return valString("http://localhost:8000/?content=demo:edit")

proc nimini_checkShareUrlCopied(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if URL was successfully copied to clipboard. Returns "true" or "false"
  when defined(emscripten) and not defined(sdl3Backend):
    let copied = js_callFunction("tStorie_checkShareUrlCopied".cstring)
    return valString($copied)
  else:
    return valString("true")

proc nimini_exportToPNG(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Export content as PNG with embedded workflow (ComfyUI-style). Args: content, filename
  ## Captures terminal canvas screenshot and embeds compressed content in PNG metadata.
  ## Returns immediately. Check with checkPngExportReady() for completion.
  if args.len >= 1:
    let content = args[0].s
    let filename = if args.len >= 2: args[1].s else: "tstorie-workflow"
    when defined(emscripten) and not defined(sdl3Backend):
      discard js_callFunctionWith2Args("tStorie_exportToPNG".cstring, content.cstring, filename.cstring)
    else:
      echo "exportToPNG: ", content.len, " bytes -> ", filename, ".png"
  return valNil()

proc nimini_checkPngExportReady(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if PNG export is complete. Returns "true" or "false"
  when defined(emscripten) and not defined(sdl3Backend):
    let ready = js_callFunction("tStorie_checkPngExportReady".cstring)
    return valString($ready)
  else:
    return valString("true")

proc nimini_getPngExportError(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get PNG export error message if export failed. Returns empty string if no error.
  when defined(emscripten) and not defined(sdl3Backend):
    let error = js_callFunction("tStorie_getPngExportError".cstring)
    return valString($error)
  else:
    return valString("")

proc nimini_importFromPNG(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Trigger file picker to import workflow from PNG. Returns immediately.
  ## Check with checkPngImportReady() and get content with getPngImportContent()
  when defined(emscripten) and not defined(sdl3Backend):
    discard js_callFunction("tStorie_importFromPNG".cstring)
  else:
    echo "importFromPNG: file picker opened"
  return valNil()

proc nimini_checkPngImportReady(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if PNG import has content ready. Returns "true" or "false"
  when defined(emscripten) and not defined(sdl3Backend):
    let ready = js_callFunction("tStorie_checkPngImportReady".cstring)
    return valString($ready)
  else:
    return valString("false")

proc nimini_getPngImportContent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get imported workflow content from PNG. Returns empty string if none available.
  ## This clears the imported content, so call only once per import.
  when defined(emscripten) and not defined(sdl3Backend):
    let content = js_callFunction("tStorie_getPngImportContent".cstring)
    return valString($content)
  else:
    return valString("")

proc nimini_navigateTo(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Navigate to a URL (useful for loading saved documents)
  if args.len >= 1:
    let url = args[0].s
    when defined(emscripten) and not defined(sdl3Backend):
      discard js_callFunctionWithArg("tStorie_navigate".cstring, url.cstring)
    else:
      echo "navigateTo: ", url
  return valNil()

proc nimini_window_open(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Open URL in new browser window/tab. Args: url, target (temporarily disabled)
  if args.len >= 1:
    let url = args[0].s
    let target = if args.len >= 2: args[1].s else: "_blank"
    when false: # disabled
      when defined(emscripten) and not defined(sdl3Backend):
        discard js_callFunctionWith2Args("tStorie_windowOpen".cstring, url.cstring, target.cstring)
    # Stub - window.open temporarily disabled

when defined(emscripten) and not defined(sdl3Backend):
  proc setDocumentTitleJS(title: cstring) {.importc: "tStorie_setDocumentTitle".}

proc setDocumentTitle(title: string) =
  ## Set the browser tab title (emscripten only)
  when defined(emscripten) and not defined(sdl3Backend):
    setDocumentTitleJS(title.cstring)

proc registerBrowserApiFuncs*(env: ref Env) =
  ## Register browser API functions in nimini environment
  registerNative("localStorage_setItem", nimini_localStorage_setItem)
  registerNative("localStorage_getItem", nimini_localStorage_getItem)
  registerNative("localStorage_list", nimini_localStorage_list)
  registerNative("localStorage_delete", nimini_localStorage_delete)
  registerNative("copyToClipboard", nimini_copyToClipboard)
  registerNative("pasteFromClipboard", nimini_pasteFromClipboard)
  registerNative("compressToUrl", nimini_compressToUrl)
  registerNative("generateAndCopyShareUrl", nimini_generateAndCopyShareUrl)
  registerNative("checkShareUrlReady", nimini_checkShareUrlReady)
  registerNative("getShareUrl", nimini_getShareUrl)
  registerNative("checkShareUrlCopied", nimini_checkShareUrlCopied)
  registerNative("exportToPNG", nimini_exportToPNG)
  registerNative("checkPngExportReady", nimini_checkPngExportReady)
  registerNative("getPngExportError", nimini_getPngExportError)
  registerNative("importFromPNG", nimini_importFromPNG)
  registerNative("checkPngImportReady", nimini_checkPngImportReady)
  registerNative("getPngImportContent", nimini_getPngImportContent)
  registerNative("navigateTo", nimini_navigateTo)

# ================================================================
# CANVAS SYSTEM WRAPPERS
# ================================================================

proc initCanvas(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Initialize canvas system with all sections. 
  ## Args: currentIdx (int, optional, default 0), presentationMode (bool, optional, default false)
  if storieCtx.isNil:
    return valBool(false)
  var currentIdx = if args.len > 0: toInt(args[0]) else: 0
  let presentationMode = if args.len > 1: toBool(args[1]) else: false
  let sections = storieCtx.sectionMgr.getAllSections()
  
  # Auto-skip Section 0 if it has no title (just lifecycle hooks/init code)
  if currentIdx == 0 and sections.len > 1:
    if sections[0].title.len == 0:
      currentIdx = 1  # Navigate to first real section
  
  initCanvas(sections, currentIdx, presentationMode, storieCtx.frontMatter)
  
  # Set section manager's current index (source of truth)
  storieCtx.sectionMgr.currentIndex = currentIdx
  
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
  ## Note: Events should be normalized before encoding for consistent behavior
  var table = initTable[string, Value]()
  
  case event.kind
  of KeyEvent:
    table["type"] = valString("key")
    table["keyCode"] = valInt(event.keyCode)
    table["action"] = valString(case event.keyAction
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat")
    
    # Set key field - for printable characters, convert keyCode to string
    if event.keyCode >= 32 and event.keyCode < 127:
      table["key"] = valString($char(event.keyCode))
    else:
      table["key"] = valString("")
    
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
    
    # Encode modifiers for text events
    var mods: seq[string] = @[]
    if ModShift in event.textMods: mods.add("shift")
    if ModAlt in event.textMods: mods.add("alt")
    if ModCtrl in event.textMods: mods.add("ctrl")
    if ModSuper in event.textMods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
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
    
    # Add content-relative coordinates if canvas is initialized
    if not canvasState.isNil:
      let bounds = canvasState.currentContentBounds
      let relX = event.mouseX - bounds.x
      let relY = event.mouseY - bounds.y
      
      # Only set contentX/contentY if within content bounds
      # Use -1 to indicate "outside content area" (easier to check in nimini than nil)
      if relX >= 0 and relY >= 0 and relX < bounds.width and relY < bounds.height:
        table["contentX"] = valInt(relX)
        table["contentY"] = valInt(relY)
      else:
        table["contentX"] = valInt(-1)
        table["contentY"] = valInt(-1)
      
      # Add buffer-relative coordinates (for games and dynamic content)
      let bufferBounds = canvasState.currentContentBufferBounds
      let bufferX = event.mouseX - bufferBounds.x
      let bufferY = event.mouseY - bufferBounds.y
      
      # Only set bufferX/bufferY if within buffer bounds
      if bufferX >= 0 and bufferY >= 0 and bufferX < bufferBounds.width and bufferY < bufferBounds.height:
        table["bufferX"] = valInt(bufferX)
        table["bufferY"] = valInt(bufferY)
      else:
        table["bufferX"] = valInt(-1)
        table["bufferY"] = valInt(-1)
    else:
      table["contentX"] = valInt(-1)
      table["contentY"] = valInt(-1)
      table["bufferX"] = valInt(-1)
      table["bufferY"] = valInt(-1)
    
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
# ANIMATION HELPERS (Nimini wrappers)
# ================================================================

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
  let a = toInt(args[0])
  let b = toInt(args[1])
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
# Note: Figlet function implementations have been moved to lib/figlet_bindings.nim
# They are imported and registered below

proc getEmbeddedContent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get embedded content by name. Args: name (string)
  ## Returns: content string or empty string if not found
  if args.len < 1:
    return valString("")
  
  let name = args[0].s
  
  # Check if storieCtx has embedded content
  if storieCtx.isNil or storieCtx.embeddedContent.len == 0:
    return valString("")
  
  # Search for the content by name
  for content in storieCtx.embeddedContent:
    if content.name == name:
      return valString(content.content)
  
  return valString("")

# ================================================================
# NOISE COMPOSER API (Nimini wrappers)
# ================================================================

# Store NoiseConfig objects in a table keyed by handle ID
var gNoiseConfigs {.threadvar.}: Table[int, NoiseConfig]
var gNextNoiseId {.threadvar.}: int
var gNoiseSystemInit {.threadvar.}: bool

proc initNoiseSystem() =
  ## Initialize the noise config storage
  if not gNoiseSystemInit:
    gNoiseConfigs = initTable[int, NoiseConfig]()
    gNextNoiseId = 1
    gNoiseSystemInit = true

proc nimini_noise(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a noise configuration: noise(noiseType)
  ## Returns a handle to the noise configuration
  if args.len < 1:
    return valNil()
  
  # Initialize if needed
  if not gNoiseSystemInit:
    initNoiseSystem()
  
  let noiseTypeInt = args[0].i
  let noiseType = NoiseType(noiseTypeInt)
  
  # Create noise config
  let config = noise(noiseType)
  
  # Store it and return handle
  let handle = gNextNoiseId
  gNextNoiseId += 1
  gNoiseConfigs[handle] = config
  
  return valPointer(cast[pointer](handle))

proc getNoiseConfig(v: Value): NoiseConfig =
  ## Extract NoiseConfig from a handle value
  if v.kind != vkPointer:
    raise newException(ValueError, "Expected noise config handle")
  let handle = cast[int](v.ptrVal)
  if not gNoiseConfigs.hasKey(handle):
    raise newException(ValueError, "Invalid noise config handle")
  return gNoiseConfigs[handle]

proc setNoiseConfig(v: Value, config: NoiseConfig) =
  ## Update a stored NoiseConfig
  if v.kind != vkPointer:
    raise newException(ValueError, "Expected noise config handle")
  let handle = cast[int](v.ptrVal)
  gNoiseConfigs[handle] = config

proc nimini_noiseSeed(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set noise seed: config.seed(value)
  if args.len < 2:
    return args[0]
  var config = getNoiseConfig(args[0])
  config = config.seed(args[1].i)
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseScale(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set noise scale: config.scale(value)
  if args.len < 2:
    return args[0]
  var config = getNoiseConfig(args[0])
  config = config.scale(args[1].i)
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseOctaves(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set noise octaves: config.octaves(value)
  if args.len < 2:
    return args[0]
  var config = getNoiseConfig(args[0])
  config = config.octaves(args[1].i)
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseGain(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set noise gain: config.gain(value)
  if args.len < 2:
    return args[0]
  var config = getNoiseConfig(args[0])
  config = config.gain(args[1].i)
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseLacunarity(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set noise lacunarity: config.lacunarity(value)
  if args.len < 2:
    return args[0]
  var config = getNoiseConfig(args[0])
  config = config.lacunarity(args[1].i)
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseRidged(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set ridged FBM mode: config.ridged()
  if args.len < 1:
    return valNil()
  var config = getNoiseConfig(args[0])
  config = config.ridged()
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseBillow(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set billow FBM mode: config.billow()
  if args.len < 1:
    return valNil()
  var config = getNoiseConfig(args[0])
  config = config.billow()
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseTurbulence(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set turbulence FBM mode: config.turbulent()
  if args.len < 1:
    return valNil()
  var config = getNoiseConfig(args[0])
  config = config.turbulent()
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseWarp(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set domain warp: config.warp(strength, [octaves])
  if args.len < 2:
    return args[0]
  var config = getNoiseConfig(args[0])
  let strength = args[1].i
  let octaves = if args.len >= 3: args[2].i else: 1
  config = config.warp(strength, octaves)
  setNoiseConfig(args[0], config)
  return args[0]

proc nimini_noiseSample2D(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Sample 2D noise: config.sample2D(x, y)
  if args.len < 3:
    return valInt(0)
  let config = getNoiseConfig(args[0])
  let x = args[1].i
  let y = args[2].i
  let value = config.sample2D(x, y)
  return valInt(value)

proc nimini_noiseSample3D(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Sample 3D noise: config.sample3D(x, y, z)
  if args.len < 4:
    return valInt(0)
  let config = getNoiseConfig(args[0])
  let x = args[1].i
  let y = args[2].i
  let z = args[3].i
  let value = config.sample3D(x, y, z)
  return valInt(value)

proc nimini_noiseToWGSL(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate WGSL shader: config.toWGSL()
  if args.len < 1:
    return valString("")
  let config = getNoiseConfig(args[0])
  let wgsl = config.toWGSL()
  return valString(wgsl)

# ============================================================================
# Platform Detection
# ============================================================================

proc nimini_defined(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if a compile-time symbol is defined: defined("emscripten")
  ## This mirrors Nim's compile-time defined() but works at runtime
  ## 
  ## Supported symbols:
  ##   emscripten, web      - Web/WASM build
  ##   native              - Native build (not web)
  ##   windows             - Windows platform
  ##   macosx, macos       - macOS platform
  ##   linux               - Linux platform
  ##   debug               - Debug build
  ##   release             - Release build
  if args.len < 1:
    return valBool(false)
  
  let symbol = args[0].s
  
  # Web/WASM detection (case-insensitive)
  when defined(emscripten):
    if symbol == "emscripten" or symbol == "web" or 
       symbol == "Emscripten" or symbol == "Web":
      return valBool(true)
    if symbol == "native" or symbol == "Native":
      return valBool(false)
  else:
    if symbol == "emscripten" or symbol == "web" or
       symbol == "Emscripten" or symbol == "Web":
      return valBool(false)
    if symbol == "native" or symbol == "Native":
      return valBool(true)
  
  # Platform detection (case-insensitive)
  when defined(windows):
    if symbol == "windows" or symbol == "Windows":
      return valBool(true)
  
  when defined(macosx):
    if symbol == "macosx" or symbol == "macos" or
       symbol == "MacOSX" or symbol == "MacOS" or symbol == "Macos":
      return valBool(true)
  
  when defined(linux):
    if symbol == "linux" or symbol == "Linux":
      return valBool(true)
  
  # Build mode detection (case-insensitive)
  when defined(debug):
    if symbol == "debug" or symbol == "Debug":
      return valBool(true)
  
  when defined(release):
    if symbol == "release" or symbol == "Release":
      return valBool(true)
  
  # Unknown symbol
  return valBool(false)

# ============================================================================
# WebGPU Compute Execution (Web Only)
# ============================================================================

when defined(emscripten):
  # JavaScript interop for WebGPU
  proc js_webgpuIsSupported(): cint {.importc: "tStorie_webgpuIsSupported".}
  proc js_webgpuIsReady(): cint {.importc: "tStorie_webgpuIsReady".}
  proc js_webgpuStartExecution(wgslPtr: cstring, width, height, offsetX, offsetY: cint): cint {.importc: "tStorie_webgpuStartExecution".}
  proc js_webgpuIsResultReady(): cint {.importc: "tStorie_webgpuIsResultReady".}
  proc js_webgpuGetValue(index: cint): cint {.importc: "tStorie_webgpuGetValue".}
  proc js_webgpuGetResultSize(): cint {.importc: "tStorie_webgpuGetResultSize".}
  proc js_webgpuCancel() {.importc: "tStorie_webgpuCancel".}

  proc nimini_webgpuSupported(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Check if WebGPU is supported in the browser
    return valBool(js_webgpuIsSupported() != 0)

  proc nimini_webgpuReady(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Check if WebGPU is initialized and ready to use
    return valBool(js_webgpuIsReady() != 0)

  proc nimini_webgpuStart(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Start GPU execution: webgpuStart(config, width, height, offsetX, offsetY)
    ## Returns true if operation started, false if failed
    ## Use webgpuIsReady() to check completion, then webgpuGet() to retrieve results
    if args.len < 5:
      return valBool(false)
    
    let config = getNoiseConfig(args[0])
    let width = args[1].i
    let height = args[2].i
    let offsetX = args[3].i
    let offsetY = args[4].i
    
    # Generate WGSL shader
    let wgsl = config.toWGSL()
    
    # Start execution
    let success = js_webgpuStartExecution(
      wgsl.cstring,
      width.cint,
      height.cint,
      offsetX.cint,
      offsetY.cint
    )
    
    return valBool(success != 0)

  proc nimini_webgpuIsReady(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Check if GPU execution has completed and results are ready
    return valBool(js_webgpuIsResultReady() != 0)

  proc nimini_webgpuGet(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Get result value at index: webgpuGet(index)
    ## Returns noise value [0..65535] or 0 if not ready/invalid index
    if args.len < 1:
      return valInt(0)
    
    let idx = args[0].i
    let value = js_webgpuGetValue(idx.cint)
    return valInt(value.int)

  proc nimini_webgpuSize(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Get size of result buffer
    return valInt(js_webgpuGetResultSize().int)

  proc nimini_webgpuCancel(env: ref Env; args: seq[Value]): Value {.nimini.} =
    ## Cancel any pending GPU operation
    js_webgpuCancel()
    return valNil()

proc createNiminiContext(state: AppState): NiminiContext =
  ## Create a Nimini interpreter context with exposed APIs
  initRuntime()
  initStdlib()  # Register standard library functions (add, len, etc.)
  registerParamFuncs(runtimeEnv)  # Register parameter functions (getParam, hasParam, etc.)
  registerBrowserApiFuncs(runtimeEnv)  # Register browser API functions (localStorage, clipboard, etc.)
  
  # Register KEY_* constants for input event handling
  defineVar(runtimeEnv, "KEY_ESCAPE", valInt(KEY_ESCAPE.int))
  defineVar(runtimeEnv, "KEY_RETURN", valInt(KEY_RETURN.int))
  defineVar(runtimeEnv, "KEY_ENTER", valInt(KEY_ENTER.int))
  defineVar(runtimeEnv, "KEY_SPACE", valInt(KEY_SPACE.int))
  defineVar(runtimeEnv, "KEY_TAB", valInt(KEY_TAB.int))
  defineVar(runtimeEnv, "KEY_BACKSPACE", valInt(KEY_BACKSPACE.int))
  defineVar(runtimeEnv, "KEY_DELETE", valInt(KEY_DELETE.int))
  defineVar(runtimeEnv, "KEY_UP", valInt(KEY_UP.int))
  defineVar(runtimeEnv, "KEY_DOWN", valInt(KEY_DOWN.int))
  defineVar(runtimeEnv, "KEY_LEFT", valInt(KEY_LEFT.int))
  defineVar(runtimeEnv, "KEY_RIGHT", valInt(KEY_RIGHT.int))
  defineVar(runtimeEnv, "KEY_HOME", valInt(KEY_HOME.int))
  defineVar(runtimeEnv, "KEY_END", valInt(KEY_END.int))
  defineVar(runtimeEnv, "KEY_PAGEUP", valInt(KEY_PAGEUP.int))
  defineVar(runtimeEnv, "KEY_PAGEDOWN", valInt(KEY_PAGEDOWN.int))
  defineVar(runtimeEnv, "KEY_F1", valInt(KEY_F1.int))
  defineVar(runtimeEnv, "KEY_F2", valInt(KEY_F2.int))
  defineVar(runtimeEnv, "KEY_F3", valInt(KEY_F3.int))
  defineVar(runtimeEnv, "KEY_F4", valInt(KEY_F4.int))
  defineVar(runtimeEnv, "KEY_F5", valInt(KEY_F5.int))
  defineVar(runtimeEnv, "KEY_F6", valInt(KEY_F6.int))
  defineVar(runtimeEnv, "KEY_F7", valInt(KEY_F7.int))
  defineVar(runtimeEnv, "KEY_F8", valInt(KEY_F8.int))
  defineVar(runtimeEnv, "KEY_F9", valInt(KEY_F9.int))
  defineVar(runtimeEnv, "KEY_F10", valInt(KEY_F10.int))
  defineVar(runtimeEnv, "KEY_F11", valInt(KEY_F11.int))
  defineVar(runtimeEnv, "KEY_F12", valInt(KEY_F12.int))
  
  # Register core framework APIs (state accessors, colors, etc.) from lib/nimini_bridge.nim
  registerTstorieApis(runtimeEnv, state)
  
  # Create DrawProc wrapper for ASCII/ANSI art bindings
  proc drawWrapper(layer, x, y: int, char: string, style: Style) =
    # Write to layer buffer (unified for all backends)
    if gDefaultLayer.isNil:
      echo "[drawWrapper] ERROR: gDefaultLayer is NIL at ", x, ",", y
      return
    if gDefaultLayer.buffer.cells.len == 0:
      echo "[drawWrapper] ERROR: gDefaultLayer.buffer has no cells"
      return
    gDefaultLayer.buffer.writeCell(x, y, char, style)
  
  # Register ASCII art bindings and dungeon generator
  registerAsciiArtBindings(drawWrapper, addr state)
  registerAnsiArtBindings(runtimeEnv, drawWrapper)
  registerTextEditorBindings(runtimeEnv)
  registerParticleBindings(runtimeEnv, state)
  
  # NOTE: Particles now use gAppState.layers (unified for both terminal and SDL3)
  
  # Register TUI helper bindings with polymorphic int/string layer support
  # NOTE: Some auto-exposed versions are disabled in initTUIHelpersModule()
  # to avoid conflicts with these polymorphic wrappers
  registerTUIHelperBindings(runtimeEnv)
  
  # Register figlet bindings with font cache references and layer system
  registerFigletBindings(addr gFigletFonts, addr gEmbeddedFigletFonts, 
                          addr gDefaultLayer, addr gAppState)
  
  # Register TUI terminal bindings with layer system (for auto-rendering widgets)
  initTUITerminalModule(addr gDefaultLayer, addr gAppState)
  
  # Note: TUI test module registration moved outside createNiminiContext
  # since it needs storieCtx.styleSheet which isn't available here
  
  # Explicitly initialize plugin modules BEFORE calling initPlugins()
  # This ensures registration functions are queued properly in WASM
  initDungeonGenModule()
  initPrimitivesModule()
  initGraphModule()
  initTUIHelpersModule()
  registerWGSLBindings()
  
  # Initialize all auto-registered plugins (from lib/ modules with pragmas)
  initPlugins()
  
  # Register type conversion functions with custom names
  registerNative("int", nimini_int)
  registerNative("float", nimini_float)
  registerNative("str", nimini_str)
  
  # Auto-register all {.nimini.} pragma functions from runtime_api.nim
  # Note: Functions that need clean script-facing names (without nimini_ prefix)
  # are registered manually below with registerNative("cleanName", nimini_function)
  when defined(sdl3Backend):
    # SDL3 rendering API - both pixel and cell-based
    exportNiminiProcs(
      print,
      randInt, randFloat,
      initCanvas,
      getEmbeddedContent,
      setFillColor, width, height, text
    )
    # Register cell-based terminal functions for SDL3
    registerNative("draw", sdl3DrawCell)
    registerNative("clear", sdl3ClearCells)
    registerNative("fillRect", sdl3FillCellRect)
    registerNative("forceRedraw", forceRedraw)
  else:
    # Terminal character-based rendering API
    exportNiminiProcs(
      print,
      draw, clear, fillRect,
      randInt, randFloat,
      initCanvas,
      getEmbeddedContent
    )
    # Force redraw works on all backends
    registerNative("forceRedraw", forceRedraw)
  
  # Register layer management functions
  registerNative("addLayer", nimini_addLayer)
  registerNative("removeLayer", nimini_removeLayer)
  registerNative("setLayerVisible", nimini_setLayerVisible)
  registerNative("getLayerCount", nimini_getLayerCount)
  
  # Register global handler functions
  registerNative("registerGlobalRender", nimini_registerGlobalRender)
  registerNative("registerGlobalUpdate", nimini_registerGlobalUpdate)
  registerNative("registerGlobalInput", nimini_registerGlobalInput)
  registerNative("unregisterGlobalHandler", nimini_unregisterGlobalHandler)
  registerNative("clearGlobalHandlers", nimini_clearGlobalHandlers)
  
  # Register mouse handling
  registerNative("enableMouse", nimini_enableMouse)
  registerNative("disableMouse", nimini_disableMouse)
  
  # Register style functions
  registerNative("defaultStyle", nimini_defaultStyle)
  registerNative("setDefaultStyle", nimini_setDefaultStyle)
  registerNative("getStyle", nimini_getStyle)
  registerNative("getThemes", nimini_getThemes)
  registerNative("switchTheme", nimini_switchTheme)
  registerNative("getCurrentTheme", nimini_getCurrentTheme)
  
  # Register section management functions
  registerNative("getCurrentSection", nimini_getCurrentSection)
  registerNative("getAllSections", nimini_getAllSections)
  registerNative("getSectionById", nimini_getSectionById)
  registerNative("gotoSection", nimini_gotoSection)
  registerNative("createSection", nimini_createSection)
  registerNative("deleteSection", nimini_deleteSection)
  registerNative("updateSectionTitle", nimini_updateSectionTitle)
  registerNative("setMultiSectionMode", nimini_setMultiSectionMode)
  registerNative("getMultiSectionMode", nimini_getMultiSectionMode)
  registerNative("setScrollY", nimini_setScrollY)
  registerNative("getScrollY", nimini_getScrollY)
  registerNative("getSectionCount", nimini_getSectionCount)
  registerNative("getCurrentSectionIndex", nimini_getCurrentSectionIndex)
  
  # Register code block access functions
  registerNative("getSectionCodeBlocks", nimini_getSectionCodeBlocks)
  registerNative("getCodeBlock", nimini_getCodeBlock)
  registerNative("getCurrentSectionCodeBlocks", nimini_getCurrentSectionCodeBlocks)
  registerNative("getCodeBlockText", nimini_getCodeBlockText)
  registerNative("getContent", nimini_getContent)
  
  # Register browser API functions
  registerNative("localStorage_setItem", nimini_localStorage_setItem)
  registerNative("localStorage_getItem", nimini_localStorage_getItem)
  registerNative("window_open", nimini_window_open)
  
  # Register animation/easing functions
  registerNative("lerp", nimini_lerp)
  registerNative("lerpInt", nimini_lerpInt)
  registerNative("smoothstep", nimini_smoothstep)
  registerNative("easeLinear", nimini_easeLinear)
  registerNative("easeInQuad", nimini_easeInQuad)
  registerNative("easeOutQuad", nimini_easeOutQuad)
  registerNative("easeInOutQuad", nimini_easeInOutQuad)
  registerNative("easeInCubic", nimini_easeInCubic)
  registerNative("easeOutCubic", nimini_easeOutCubic)
  registerNative("easeInOutCubic", nimini_easeInOutCubic)
  registerNative("easeInSine", nimini_easeInSine)
  registerNative("easeOutSine", nimini_easeOutSine)
  registerNative("easeInOutSine", nimini_easeInOutSine)
  
  # Register noise composer API
  registerNative("noise", nimini_noise)
  registerNative("noiseSeed", nimini_noiseSeed)
  registerNative("noiseScale", nimini_noiseScale)
  registerNative("noiseOctaves", nimini_noiseOctaves)
  registerNative("noiseGain", nimini_noiseGain)
  registerNative("noiseLacunarity", nimini_noiseLacunarity)
  registerNative("noiseRidged", nimini_noiseRidged)
  registerNative("noiseBillow", nimini_noiseBillow)
  registerNative("noiseTurbulence", nimini_noiseTurbulence)
  registerNative("noiseTurbulent", nimini_noiseTurbulence)  # Alias
  registerNative("noiseWarp", nimini_noiseWarp)
  registerNative("noiseSample", nimini_noiseSample2D)  # Alias for 2D sampling
  registerNative("noiseSample2D", nimini_noiseSample2D)
  registerNative("noiseSample3D", nimini_noiseSample3D)
  registerNative("noiseToWGSL", nimini_noiseToWGSL)
  
  # Register platform detection
  registerNative("defined", nimini_defined)
  
  # Register WebGPU compute API (web only)
  when defined(emscripten):
    registerNative("webgpuSupported", nimini_webgpuSupported)
    registerNative("webgpuReady", nimini_webgpuReady)
    registerNative("webgpuStart", nimini_webgpuStart)
    registerNative("webgpuIsReady", nimini_webgpuIsReady)
    registerNative("webgpuGet", nimini_webgpuGet)
    registerNative("webgpuSize", nimini_webgpuSize)
    registerNative("webgpuCancel", nimini_webgpuCancel)
  
  # Note: Figlet functions are now registered via exportNiminiProcs above.
  # The metadata (storieLibs, description, dependencies) for the export system
  # can be re-added later as pragma parameters when we enhance the macro system.
  
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
  
  # Register noise type constants
  defineVar(runtimeEnv, "ntPerlin2D", valInt(ord(ntPerlin2D)))
  defineVar(runtimeEnv, "ntPerlin3D", valInt(ord(ntPerlin3D)))
  defineVar(runtimeEnv, "ntSimplex2D", valInt(ord(ntSimplex2D)))
  defineVar(runtimeEnv, "ntSimplex3D", valInt(ord(ntSimplex3D)))
  defineVar(runtimeEnv, "ntWorley2D", valInt(ord(ntWorley2D)))
  defineVar(runtimeEnv, "ntWorley3D", valInt(ord(ntWorley3D)))
  defineVar(runtimeEnv, "ntValue2D", valInt(ord(ntValue2D)))
  defineVar(runtimeEnv, "ntFractal2D", valInt(ord(ntFractal2D)))
  
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
    scriptCode.add("var mouseX = " & $state.lastMouseX & "\n")
    scriptCode.add("var mouseY = " & $state.lastMouseY & "\n")
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
    
    # Expose the event object (already normalized by backend's pollInput)
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
    when defined(emscripten) and not defined(sdl3Backend):
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
    scriptCode.add("var mouseX = " & $state.lastMouseX & "\n")
    scriptCode.add("var mouseY = " & $state.lastMouseY & "\n")
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
      # Expose the event object (already normalized by backend's pollInput)
      let eventValue = encodeInputEvent(event)
      defineVar(execEnv, "event", eventValue)
    
    execProgram(program, execEnv)
    
    return true
  except Exception as e:
    when not defined(emscripten):
      echo "Error in ", codeBlock.lifecycle, " block: ", e.msg
    # In WASM, we can't echo, so we'll just fail silently but return false
    when defined(emscripten) and not defined(sdl3Backend):
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
      of PreformattedBlock:
        blk.content = expandVariablesInText(blk.content, frontMatter)
      else:
        discard

proc loadAndParseMarkdown(): MarkdownDocument =
  ## Load markdown file and parse it for code blocks and front matter
  when defined(emscripten):
    # Emscripten builds (both old WASM and SDL3): check for runtime content first
    when not defined(sdl3Backend):
      # Old WASM backend specific checks
      if gWaitingForGist:
        return MarkdownDocument()
    
    # Fallback: Use staticRead to embed index.md in the WASM binary
    const mdContent = staticRead("../index.md")
    static:
      echo "[Compile-time] Embedding index.md: ", mdContent.len, " bytes"
    
    let doc = parseMarkdownDocument(mdContent)
    
    when not defined(sdl3Backend):
      # Old WASM backend: additional debug info
      const mdLines = mdContent.splitLines()
      const mdLineCount = mdLines.len
      lastError = "MD:" & $mdContent.len & "ch," & $mdLineCount & "ln"
      
      if doc.codeBlocks.len == 0:
        lastError = lastError & "|0blocks"
        var preview = ""
        for i in 0 ..< min(3, mdLineCount):
          if i > 0: preview.add(";")
          let line = mdLines[i]
          preview.add(if line.len > 20: line[0..19] else: line)
        lastError = lastError & "|" & preview
      else:
        lastError = ""
    
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
      # Check if it's a boolean
      let lowerVal = value.toLowerAscii()
      if lowerVal == "true" or lowerVal == "false":
        setGlobal(key, valBool(lowerVal == "true"))
      else:
        # Not a number or bool, store as string
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
  storieCtx.embeddedContent = doc.embeddedContent
  
  # Debug: print embedded content
  when not defined(emscripten):
    if doc.embeddedContent.len > 0:
      echo "Found ", doc.embeddedContent.len, " embedded content blocks:"
      for ec in doc.embeddedContent:
        echo "  - ", ec.name, " (", ec.kind, ") - ", ec.content.len, " bytes"
  
  # Set up TUI helper stylesheet (layer and state refs were set earlier)
  tui_helpers.gStorieStyleSheet = addr storieCtx.styleSheet
  
  # Expand `? variable` expressions in section text before creating section manager
  var sections = doc.sections
  expandVariablesInSections(sections, doc.frontMatter)
  storieCtx.sectionMgr = newSectionManager(sections)
  
  # Also store styleSheet in state for API access
  state.styleSheet = doc.styleSheet
  
  # Update global default style from stylesheet
  if doc.styleSheet.hasKey("default"):
    # Use explicit "default" style if defined
    setDefaultStyleConfig(doc.styleSheet["default"])
  elif doc.styleSheet.hasKey("body"):
    # Fallback: use "body" style background/foreground for default
    setDefaultStyleConfig(doc.styleSheet["body"])
  
  # Extract theme background color from stylesheet (body style or default to black)
  if doc.styleSheet.hasKey("body"):
    storieCtx.themeBackground = doc.styleSheet["body"].bg
    state.themeBackground = storieCtx.themeBackground

    when defined(emscripten):
      proc js_setThemeBackground(r, g, b: cint) {.importc: "tStorie_setThemeBackground".}
      js_setThemeBackground(storieCtx.themeBackground.r.cint, storieCtx.themeBackground.g.cint, storieCtx.themeBackground.b.cint)
    # Debug: print stylesheet contents
    when not defined(emscripten):
      echo "Stylesheet loaded with ", doc.styleSheet.len, " styles:"
      for name, style in doc.styleSheet:
        echo "  ", name, " -> bg=(", style.bg.r, ",", style.bg.g, ",", style.bg.b, ") fg=(", style.fg.r, ",", style.fg.g, ",", style.fg.b, ")"
  else:
    storieCtx.themeBackground = (0'u8, 0'u8, 0'u8)
    state.themeBackground = (0'u8, 0'u8, 0'u8)

    when defined(emscripten):
      proc js_setThemeBackground(r, g, b: cint) {.importc: "tStorie_setThemeBackground".}
      js_setThemeBackground(0.cint, 0.cint, 0.cint)
  
  when defined(emscripten) and not defined(sdl3Backend):
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
      when defined(emscripten) and not defined(sdl3Backend):
        globalMinWidth = storieCtx.minWidth
      when not defined(emscripten):
        echo "Minimum width set from front matter: ", storieCtx.minWidth
    except:
      when not defined(emscripten):
        echo "Warning: Invalid minWidth value in front matter"
  if storieCtx.frontMatter.hasKey("minHeight"):
    try:
      storieCtx.minHeight = parseInt(storieCtx.frontMatter["minHeight"])
      when defined(emscripten) and not defined(sdl3Backend):
        globalMinHeight = storieCtx.minHeight
      when not defined(emscripten):
        echo "Minimum height set from front matter: ", storieCtx.minHeight
    except:
      when not defined(emscripten):
        echo "Warning: Invalid minHeight value in front matter"
  
  # Create single default layer (layer 0) on gAppState (unified for all backends)
  gDefaultLayer = state.getLayer("default")
  if gDefaultLayer.isNil:
    gDefaultLayer = state.addLayer("default", 0)
  
  # Set TUI helper default layer reference immediately
  tui_helpers.gDefaultLayerRef = gDefaultLayer
  tui_helpers.gAppStateRef = state
  
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
  
  # Initialize canvas module (import mode - sets up references)
  initCanvasModule(addr gAppState, addr storieCtx.sectionMgr, addr storieCtx.styleSheet)
  
  # Register canvas bindings (stores references in canvasState)
  registerCanvasBindings(addr gDefaultLayer.buffer, addr gAppState, addr storieCtx.styleSheet)
  registerCanvasEditorBindings()
  
  # Register TUI module (production retained mode UI system)
  # Set TUI module global references first
  tui_bindings.gDefaultLayerRef = addr gDefaultLayer
  tui_bindings.gAppStateRef = addr gAppState
  tui_bindings.gStorieStyleSheet = addr storieCtx.styleSheet
  tui.gStorieStyleSheet = addr storieCtx.styleSheet  # Also set in tui module for themed styles
  registerTUIBindings(storieCtx.niminiContext.env)
  
  # Register layer effects bindings
  registerLayerFxBindings(storieCtx.niminiContext.env)
  
  # Expose front matter to user scripts as global variables
  exposeFrontMatterVariables()
  
  # Update browser tab title if title is defined in frontmatter (emscripten only)
  when defined(emscripten) and not defined(sdl3Backend):
    if storieCtx.frontMatter.hasKey("title"):
      setDocumentTitle(storieCtx.frontMatter["title"])
  
  # Check for theme parameter and apply if present (overrides front matter theme)
  when defined(emscripten):
    proc js_logUrlThemeDetected(name: cstring) {.importc: "tStorie_logUrlThemeDetected".}
    proc js_logUrlThemeSuccess() {.importc: "tStorie_logUrlThemeSuccess".}
    proc js_logUrlThemeFailed(name: cstring) {.importc: "tStorie_logUrlThemeFailed".}
    proc js_logNoUrlTheme() {.importc: "tStorie_logNoUrlTheme".}
  
  if hasParamDirect("theme"):
    let themeName = getParamDirect("theme")
    when defined(emscripten):
      js_logUrlThemeDetected(themeName.cstring)
    if themeName.len > 0:
      when not defined(emscripten):
        echo "Applying theme from parameter: ", themeName
      try:
        let newStyleSheet = applyThemeByName(themeName)
        when defined(emscripten):
          js_logUrlThemeSuccess()
        # Update storieCtx and state with new stylesheet
        storieCtx.styleSheet = newStyleSheet
        state.styleSheet = newStyleSheet
        # Update theme background
        if newStyleSheet.hasKey("body"):
          storieCtx.themeBackground = newStyleSheet["body"].bg
          state.themeBackground = storieCtx.themeBackground

        when defined(emscripten):
          proc js_setThemeBackground(r, g, b: cint) {.importc: "tStorie_setThemeBackground".}
          js_setThemeBackground(storieCtx.themeBackground.r.cint, storieCtx.themeBackground.g.cint, storieCtx.themeBackground.b.cint)
        # Re-initialize canvas module with new stylesheet
        initCanvasModule(addr gAppState, addr storieCtx.sectionMgr, addr storieCtx.styleSheet)
        # Re-register canvas bindings with new stylesheet pointer
        registerCanvasBindings(addr gDefaultLayer.buffer, addr gAppState, addr storieCtx.styleSheet)
        registerCanvasEditorBindings()
        # Re-register layer effects bindings
        registerLayerFxBindings(storieCtx.niminiContext.env)
        # Clear and redraw all layers with new theme background
        for layer in state.layers:
          layer.buffer.clearCells(state.themeBackground)
      except:
        when not defined(emscripten):
          echo "Warning: Theme '", themeName, "' not found"
        when defined(emscripten):
          js_logUrlThemeFailed(themeName.cstring)
  else:
    when defined(emscripten):
      js_logNoUrlTheme()
  
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
        when defined(emscripten) and not defined(sdl3Backend):
          if lastError.len == 0:
            lastError = "init block failed"
        when not defined(emscripten):
          echo "WARNING: Init block failed to execute"

proc checkMinimumDimensions*(state: AppState): bool =
  ## Check if current terminal dimensions meet minimum requirements.
  ## Returns true if dimensions are OK, false if too small.
  ## When false, renders a centered warning message.
  
  when defined(emscripten) and defined(sdl3Backend):
    # Skip dimension checks for SDL3 - it's pixel-based not character-based
    gShowingDimensionWarning = false
    return true
  
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
  state.currentBuffer.clearCells((0'u8, 0'u8, 0'u8))
  
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
      state.currentBuffer.writeCellText(lineX, lineY, line, warnStyle)
  
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
    when defined(emscripten) and not defined(sdl3Backend):
      lastRenderExecutedCount = 0
      # Write error directly to currentBuffer so it's visible
      var errStyle = defaultStyle()
      errStyle.fg = red()
      errStyle.bold = true
      state.currentBuffer.writeCellText(5, 5, "ERROR: storieCtx is nil!", errStyle)
    # Fallback rendering if no context
    let msg = "No " & gMarkdownFile & " found or parsing failed"
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackStyle = defaultStyle()
    fallbackStyle.fg = cyan()
    state.currentBuffer.writeCellText(x, y, msg, fallbackStyle)
    return
  
  # UIContext integration: Reset per-frame state for immediate-mode UI
  # This allows UI widgets to track hover/click state properly
  if not storieCtx.niminiContext.isNil and not storieCtx.niminiContext.env.isNil:
    let env = storieCtx.niminiContext.env
    # Check if there's a "ui" variable in the environment
    if "ui" in env.vars:
      let uiValue = getVar(env, "ui")
      if uiValue.kind == vkPointer:
        # Cast to UIContext and begin frame
        let uiCtx = cast[UIContext](uiValue.ptrVal)
        uiBeginFrame(uiCtx, state.lastMouseX, state.lastMouseY)
  
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
  
  when defined(emscripten):
    var renderBlockCount = 0
  
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      hasRenderBlocks = true
      when defined(emscripten):
        renderBlockCount += 1
      break
  
  # Debug logging removed
  
  if not hasRenderBlocks and storieCtx.globalRenderHandlers.len == 0:
    when defined(emscripten) and not defined(sdl3Backend):
      lastRenderExecutedCount = 0
      if lastError.len == 0:
        lastError = "No on:render blocks"
    # No render blocks
    # Fallback if no render blocks found
    state.currentBuffer.clearCells()
    let msg = "No render blocks found in " & gMarkdownFile
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackInfoStyle = defaultStyle()
    fallbackInfoStyle.fg = yellow()
    state.currentBuffer.writeCellText(x, y, msg, fallbackInfoStyle)
    
    # Show what blocks we DO have
    when defined(emscripten) and not defined(sdl3Backend):
      var debugStyle = defaultStyle()
      debugStyle.fg = cyan()
      var debugY = y + 2
      for codeBlock in storieCtx.codeBlocks:
        let info = "Found: on:" & codeBlock.lifecycle
        state.currentBuffer.writeCellText(x, debugY, info, debugStyle)
        debugY += 1
    return
  
  # 2. Execute section-specific on:render code blocks
  var executedCount = 0
  
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      try:
        let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
        if success:
          executedCount += 1
      except Exception as e:
        discard  # Silent error handling
  
  
  # Debug: Show execution status in WASM
  # Write to foreground layer so user code renders, then we overlay debug on layers
  when defined(emscripten) and not defined(sdl3Backend):
    var debugStyle = defaultStyle()
    debugStyle.fg = green()
    debugStyle.bold = true
    gDefaultLayer.buffer.writeCellText(2, 2, "Blocks: " & $storieCtx.codeBlocks.len & " Render: " & $renderBlockCount & " Exec: " & $executedCount, debugStyle)

    # Publish executedCount to WASM HUD
    lastRenderExecutedCount = executedCount
    
    if executedCount == 0 and renderBlockCount > 0:
      var errorStyle = defaultStyle()
      errorStyle.fg = red()
      errorStyle.bold = true
      gDefaultLayer.buffer.writeCellText(2, 3, "Render execution FAILED!", errorStyle)
      # Also show last error if available
      if lastError.len > 0:
        gDefaultLayer.buffer.writeCellText(2, 4, "Error: " & lastError, errorStyle)
    
    # Also show frame count to verify rendering is happening
    var fpsStyle = defaultStyle()
    fpsStyle.fg = yellow()
    gDefaultLayer.buffer.writeCellText(2, 0, "Frame: " & $state.frameCount, fpsStyle)

# Define input handler as a separate proc, then assign
proc inputHandler(state: AppState, event: InputEvent): bool =
  if storieCtx.isNil:
    return false
  
  # Update mouse position tracking (these values are injected as mouseX/mouseY globals)
  case event.kind
  of MouseEvent:
    state.lastMouseX = event.mouseX
    state.lastMouseY = event.mouseY
  of MouseMoveEvent:
    state.lastMouseX = event.moveX
    state.lastMouseY = event.moveY
  else:
    discard
  
  # Filter out Release events for KeyEvents - most apps only care about Press
  # Apps that need Release events can check event.action in their handlers
  if event.kind == KeyEvent and event.keyAction == Release:
    return false
  
  # UIContext integration: Let UI system capture input first (if any UI contexts exist)
  # This allows immediate-mode UI widgets to respond to events before user code
  # UI contexts are stored in nimini environment by initUI()
  if not storieCtx.niminiContext.isNil and not storieCtx.niminiContext.env.isNil:
    let env = storieCtx.niminiContext.env
    # Check if there's a "ui" variable in the environment
    if "ui" in env.vars:
      let uiValue = getVar(env, "ui")
      if uiValue.kind == vkPointer:
        # Cast to UIContext and process input
        let uiCtx = cast[UIContext](uiValue.ptrVal)
        uiProcessInput(uiCtx, event)
  
  # 1. Execute global input handlers first (allow modules to intercept)
  for handler in storieCtx.globalInputHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        # Encode input event as a Nimini Value (already normalized by backend's pollInput)
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
    if event.keyCode == ord('q') or event.keyCode == ord('Q') or event.keyCode == 27:  # KEY_ESCAPE
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
