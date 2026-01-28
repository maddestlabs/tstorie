# Nimini Bridge - API Registration for tstorie
# 
# This module provides all the API functions that are exposed to
# nimini-interpreted code. It bridges between tstorie's native types
# and nimini's dynamic value system.

import tables
import times
import strutils
import "../nimini"

# Console logging for debugging
proc emConsoleLog(msg: cstring) {.importc: "emConsoleLog".}
import storie_types
import audio  # Unified audio system (includes audio_gen)
import terminal_shaders
import ../src/input     # Unified input system (was event_constants)
import ../src/timing    # High-precision timing and timers (core module)
import ../src/types
import ../src/layers
import ../src/appstate

# SDL3 canvas support (for shader rendering)
when defined(sdl3Backend):
  import ../backends/sdl3/sdl_canvas

# Dropped file tracking (defined here so nimini can access them directly)
var gDroppedFileName*: string = ""
var gDroppedFileData*: string = ""
var gDroppedFileSize*: int = 0

# ================================================================
# HELPER TEMPLATES
# ================================================================

# Helper templates to avoid symbol resolution conflicts with File.write
template tbWrite(layer: Layer, x, y: int, ch: string, style: Style) =
  bind write
  layer.buffer.write(x, y, ch, style)

template tbWriteText(layer: Layer, x, y: int, text: string, style: Style) =
  bind writeText
  layer.buffer.writeText(x, y, text, style)

template tbFillRect(layer: Layer, x, y, w, h: int, ch: string, style: Style) =
  bind fillRect
  layer.buffer.fillRect(x, y, w, h, ch, style)

template tbClear(layer: Layer, bgColor: tuple[r, g, b: uint8]) =
  bind clear
  layer.buffer.clear(bgColor)

template tbClearTransparent(layer: Layer) =
  bind clearTransparent
  layer.buffer.clearTransparent()

# ================================================================
# STYLE CONVERSION HELPERS
# ================================================================

proc styleConfigToValue*(config: StyleConfig): Value =
  ## Convert StyleConfig to a nimini Value (map)
  let styleMap = valMap()
  let fgMap = valMap()
  fgMap.map["r"] = valInt(config.fg.r.int)
  fgMap.map["g"] = valInt(config.fg.g.int)
  fgMap.map["b"] = valInt(config.fg.b.int)
  styleMap.map["fg"] = fgMap
  
  let bgMap = valMap()
  bgMap.map["r"] = valInt(config.bg.r.int)
  bgMap.map["g"] = valInt(config.bg.g.int)
  bgMap.map["b"] = valInt(config.bg.b.int)
  styleMap.map["bg"] = bgMap
  
  styleMap.map["bold"] = valBool(config.bold)
  styleMap.map["italic"] = valBool(config.italic)
  styleMap.map["underline"] = valBool(config.underline)
  styleMap.map["dim"] = valBool(config.dim)
  return styleMap

proc valueToStyle*(v: Value): Style =
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

proc getDefaultStyleConfig(): StyleConfig =
  ## Get the default style configuration
  StyleConfig(
    fg: (255'u8, 255'u8, 255'u8),
    bg: (0'u8, 0'u8, 0'u8),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

# ================================================================
# API REGISTRATION
# ================================================================

proc registerTstorieApis*(env: ref Env, appState: AppState) =
  ## Register all tstorie API functions in the nimini environment
  ## This makes them available to interpreted modules
  
  # Initialize auto-exposed timing module functions
  timing.initTimingModule()
  
  let defaultStyle = defaultStyle() # Default style for drawing
  
  # ============================================================================
  # Drawing APIs
  # ============================================================================
  
  env.vars["write"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## write(layerId: string, x: int, y: int, ch: string)
    if args.len < 4:
      raise newException(ValueError, "write() requires 4 arguments: layerId, x, y, ch")
    
    let layerId = args[0].s
    let x = args[1].i
    let y = args[2].i
    let ch = args[3].s
    
    var layer = getLayer(appState, layerId)
    if not layer.isNil:
      tbWrite(layer, x, y, ch, defaultStyle)
    return valNil()
  
  env.vars["writeText"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## writeText(layerId: string, x: int, y: int, text: string)
    if args.len < 4:
      raise newException(ValueError, "writeText() requires 4 arguments: layerId, x, y, text")
    
    let layerId = args[0].s
    let x = args[1].i
    let y = args[2].i
    let text = args[3].s
    
    var layer = getLayer(appState, layerId)
    if not layer.isNil:
      tbWriteText(layer, x, y, text, defaultStyle)
    return valNil()
  
  env.vars["fillRect"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## fillRect(layerId: string, x: int, y: int, w: int, h: int, ch: string)
    if args.len < 6:
      raise newException(ValueError, "fillRect() requires 6 arguments: layerId, x, y, w, h, ch")
    
    let layerId = args[0].s
    let x = args[1].i
    let y = args[2].i
    let w = args[3].i
    let h = args[4].i
    let ch = args[5].s
    
    var layer = getLayer(appState, layerId)
    if not layer.isNil:
      tbFillRect(layer, x, y, w, h, ch, defaultStyle)
    return valNil()
  
  env.vars["clearLayer"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## clearLayer(layerId: string)
    if args.len < 1:
      raise newException(ValueError, "clearLayer() requires 1 argument: layerId")
    
    let layerId = args[0].s
    var layer = getLayer(appState, layerId)
    if not layer.isNil:
      tbClear(layer, appState.themeBackground)
    return valNil()
  
  env.vars["clearLayerTransparent"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## clearLayerTransparent(layerId: string)
    if args.len < 1:
      raise newException(ValueError, "clearLayerTransparent() requires 1 argument: layerId")
    
    let layerId = args[0].s
    var layer = getLayer(appState, layerId)
    if not layer.isNil:
      tbClearTransparent(layer)
    return valNil()
  
  # ============================================================================
  # Layer Management
  # ============================================================================
  
  env.vars["addLayer"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## addLayer(id: string, z: int) - Create and add a new layer
    if args.len < 2:
      raise newException(ValueError, "addLayer() requires 2 arguments: id, z")
    
    let id = args[0].s
    let z = args[1].i
    discard addLayer(appState, id, z)
    return valNil()
  
  env.vars["layerExists"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## layerExists(id: string) -> bool
    if args.len < 1:
      raise newException(ValueError, "layerExists() requires 1 argument: id")
    
    let layer = getLayer(appState, args[0].s)
    return valBool(not layer.isNil)
  
  # ============================================================================
  # Color Utilities
  # ============================================================================
  
  env.vars["rgb"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## rgb(r: int, g: int, b: int) -> color map
    if args.len < 3:
      raise newException(ValueError, "rgb() requires 3 arguments: r, g, b")
    
    let colorMap = valMap()
    colorMap.map["r"] = valInt(args[0].i)
    colorMap.map["g"] = valInt(args[1].i)
    colorMap.map["b"] = valInt(args[2].i)
    return colorMap
  
  env.vars["unpackColor"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## unpackColor(packedRGB: int) -> color map {r, g, b}
    ## Extracts RGB components from packed integer (0xRRGGBB)
    ## Useful for converting color primitive outputs to usable colors
    if args.len < 1:
      raise newException(ValueError, "unpackColor() requires 1 argument: packed RGB integer")
    
    let packed = args[0].i
    let r = (packed div 65536) mod 256  # (packed >> 16) & 0xFF
    let g = (packed div 256) mod 256    # (packed >> 8) & 0xFF  
    let b = packed mod 256              # packed & 0xFF
    
    let colorMap = valMap()
    colorMap.map["r"] = valInt(r)
    colorMap.map["g"] = valInt(g)
    colorMap.map["b"] = valInt(b)
    return colorMap
  
  proc makeColorMap(r, g, b: int): Value =
    let m = valMap()
    m.map["r"] = valInt(r)
    m.map["g"] = valInt(g)
    m.map["b"] = valInt(b)
    return m
  
  env.vars["black"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 0, 0)
  
  env.vars["white"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(255, 255, 255)
  
  env.vars["red"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(255, 0, 0)
  
  env.vars["green"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 255, 0)
  
  env.vars["blue"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 0, 255)
  
  env.vars["cyan"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 255, 255)
  
  env.vars["magenta"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(255, 0, 255)
  
  env.vars["yellow"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(255, 255, 0)
  
  env.vars["gray"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## gray(level: int) -> color map
    if args.len < 1:
      return makeColorMap(128, 128, 128)  # Default medium gray
    let level = args[0].i
    return makeColorMap(level, level, level)
  
  # ============================================================================
  # Style System
  # ============================================================================
  
  env.vars["defaultStyle"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## defaultStyle() -> Style map
    return styleConfigToValue(getDefaultStyleConfig())
  
  env.vars["getStyle"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getStyle(name: string) -> Style map
    ## Retrieve a named style from the stylesheet defined in front matter
    if args.len < 1:
      return styleConfigToValue(getDefaultStyleConfig())
    
    let styleName = args[0].s
    
    # Access the stylesheet from appState
    if not appState.isNil and appState.styleSheet.hasKey(styleName):
      return styleConfigToValue(appState.styleSheet[styleName])
    
    # Fallback to default style
    return styleConfigToValue(getDefaultStyleConfig())
  
  env.vars["brightness"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## brightness(style: Style, factor: float) -> Style
    ## Adjusts the brightness of a style's foreground color
    ## factor < 1.0 = darker, factor > 1.0 = brighter
    ## Example: brightness(getStyle("default"), 0.3) for 30% brightness
    if args.len < 2:
      raise newException(ValueError, "brightness() requires 2 arguments: style and factor")
    
    let styleMap = args[0].map
    let factor = args[1].f
    
    # Clone the style map
    var newStyle = initTable[string, Value]()
    for k, v in styleMap:
      newStyle[k] = v
    
    # Adjust foreground color
    if newStyle.hasKey("fg"):
      let fg = newStyle["fg"].map
      var newFg = initTable[string, Value]()
      newFg["r"] = valInt(int(clamp(float(fg["r"].i) * factor, 0.0, 255.0)))
      newFg["g"] = valInt(int(clamp(float(fg["g"].i) * factor, 0.0, 255.0)))
      newFg["b"] = valInt(int(clamp(float(fg["b"].i) * factor, 0.0, 255.0)))
      newStyle["fg"] = valMap(newFg)
    
    return valMap(newStyle)
  
  # ============================================================================
  # Input Handling
  # ============================================================================
  
  env.vars["getInput"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getInput() -> array of input events
    # Return empty array for now
    return valArray()
  
  # ============================================================================
  # Font Metrics and Scaling Functions (WASM only)
  # ============================================================================
  
  when defined(emscripten):
    when not defined(sdl3Backend):
      # Old WASM build with custom JS bridge
      proc emGetCharPixelWidth(): float {.importc.}
      proc emGetCharPixelHeight(): float {.importc.}
      proc emGetViewportPixelWidth(): int {.importc.}
      proc emGetViewportPixelHeight(): int {.importc.}
      proc emSetFontSize(size: int) {.importc.}
      proc emSetFontScale(scale: float) {.importc.}
    else:
      # SDL3 web build - stub functions  
      proc emGetCharPixelWidth(): float = 8.0
      proc emGetCharPixelHeight(): float = 12.0
      proc emGetViewportPixelWidth(): int = 1024
      proc emGetViewportPixelHeight(): int = 768
      proc emSetFontSize(size: int) = discard
      proc emSetFontScale(scale: float) = discard
  
  env.vars["getCharPixelWidth"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the pixel width of a character in the current font
    when defined(emscripten):
      return valFloat(emGetCharPixelWidth())
    else:
      return valFloat(10.0)  # Default fallback for native
  
  env.vars["getCharPixelHeight"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the pixel height of a character in the current font
    when defined(emscripten):
      return valFloat(emGetCharPixelHeight())
    else:
      return valFloat(20.0)  # Default fallback for native
  
  env.vars["getViewportPixelWidth"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the pixel width of the viewport/window
    when defined(emscripten):
      return valInt(emGetViewportPixelWidth())
    else:
      return valInt(800)  # Default fallback for native
  
  env.vars["getViewportPixelHeight"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the pixel height of the viewport/window
    when defined(emscripten):
      return valInt(emGetViewportPixelHeight())
    else:
      return valInt(600)  # Default fallback for native
  
  env.vars["setFontSize"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Set the font size in pixels. Args: size (int)
    if args.len > 0:
      let size = case args[0].kind
        of vkInt: args[0].i
        of vkFloat: args[0].f.int
        else: 16
      when defined(emscripten):
        emSetFontSize(size)
    return valNil()
  
  env.vars["setFontScale"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Scale the current font size by a multiplier. Args: scale (float)
    if args.len > 0:
      let scale = case args[0].kind
        of vkFloat: args[0].f
        of vkInt: args[0].i.float
        else: 1.0
      when defined(emscripten):
        emSetFontScale(scale)
    return valNil()
  
  # ============================================================================
  # Performance Functions
  # ============================================================================
  
  env.vars["getTargetFps"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the target FPS
    return valFloat(appState.targetFps)
  
  env.vars["setTargetFps"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Set the target FPS. Args: fps (number)
    if args.len > 0:
      let fps = case args[0].kind
        of vkFloat: args[0].f
        of vkInt: args[0].i.float
        else: 60.0
      appState.targetFps = fps
    return valNil()
  
  env.vars["getFps"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the current actual FPS
    return valFloat(appState.fps)
  
  # Note: getFrameCount, getTotalTime, getDeltaTime, getTime, getTimeMs
  # are now auto-exposed from src/timing.nim via {.autoExpose: "timing".}
  
  # Timer callbacks
  env.vars["setTimeout"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setTimeout(callback, delay) -> int - Call function once after delay seconds
    if args.len < 2:
      raise newException(ValueError, "setTimeout() requires 2 arguments: callback, delay")
    if args[0].kind != vkFunction:
      raise newException(ValueError, "setTimeout() first argument must be a function")
    let delayVal = case args[1].kind
      of vkFloat: args[1].f
      of vkInt: args[1].i.float
      else: 0.0
    
    let callback = args[0]
    let timerId = timing.setTimeout(proc() =
      discard callback.fnVal.native(e, @[])
    , delayVal)
    return valInt(timerId)
  
  env.vars["setInterval"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setInterval(callback, interval) -> int - Call function repeatedly
    if args.len < 2:
      raise newException(ValueError, "setInterval() requires 2 arguments: callback, interval")
    if args[0].kind != vkFunction:
      raise newException(ValueError, "setInterval() first argument must be a function")
    let intervalVal = case args[1].kind
      of vkFloat: args[1].f
      of vkInt: args[1].i.float
      else: 0.0
    
    let callback = args[0]
    let timerId = timing.setInterval(proc() =
      discard callback.fnVal.native(e, @[])
    , intervalVal)
    return valInt(timerId)
  
  env.vars["clearTimeout"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## clearTimeout(timerId) - Cancel a setTimeout or setInterval
    if args.len < 1:
      raise newException(ValueError, "clearTimeout() requires 1 argument: timerId")
    let timerId = case args[0].kind
      of vkInt: args[0].i
      else: 0
    timing.clearTimeout(timerId)
    return valNil()
  
  env.vars["clearInterval"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## clearInterval(timerId) - Cancel a setInterval (alias for clearTimeout)
    if args.len < 1:
      raise newException(ValueError, "clearInterval() requires 1 argument: timerId")
    let timerId = case args[0].kind
      of vkInt: args[0].i
      else: 0
    timing.clearInterval(timerId)
    return valNil()
  
  # ============================================================================
  # Event Constants (SDL3-Compatible)
  # ============================================================================
  
  # Key constants - Control characters
  env.vars["KEY_BACKSPACE"] = valInt(KEY_BACKSPACE.int)
  env.vars["KEY_TAB"] = valInt(KEY_TAB.int)
  env.vars["KEY_RETURN"] = valInt(KEY_RETURN.int)
  env.vars["KEY_ENTER"] = valInt(KEY_ENTER.int)
  env.vars["KEY_ESCAPE"] = valInt(KEY_ESCAPE.int)
  env.vars["KEY_ESC"] = valInt(KEY_ESC.int)
  env.vars["KEY_DELETE"] = valInt(KEY_DELETE.int)
  env.vars["KEY_SPACE"] = valInt(KEY_SPACE.int)
  
  # Arrow keys
  env.vars["KEY_UP"] = valInt(KEY_UP.int)
  env.vars["KEY_DOWN"] = valInt(KEY_DOWN.int)
  env.vars["KEY_LEFT"] = valInt(KEY_LEFT.int)
  env.vars["KEY_RIGHT"] = valInt(KEY_RIGHT.int)
  env.vars["KEY_HOME"] = valInt(KEY_HOME.int)
  env.vars["KEY_END"] = valInt(KEY_END.int)
  env.vars["KEY_PAGEUP"] = valInt(KEY_PAGEUP.int)
  env.vars["KEY_PAGEDOWN"] = valInt(KEY_PAGEDOWN.int)
  env.vars["KEY_INSERT"] = valInt(KEY_INSERT.int)
  
  # Function keys
  env.vars["KEY_F1"] = valInt(KEY_F1.int)
  env.vars["KEY_F2"] = valInt(KEY_F2.int)
  env.vars["KEY_F3"] = valInt(KEY_F3.int)
  env.vars["KEY_F4"] = valInt(KEY_F4.int)
  env.vars["KEY_F5"] = valInt(KEY_F5.int)
  env.vars["KEY_F6"] = valInt(KEY_F6.int)
  env.vars["KEY_F7"] = valInt(KEY_F7.int)
  env.vars["KEY_F8"] = valInt(KEY_F8.int)
  env.vars["KEY_F9"] = valInt(KEY_F9.int)
  env.vars["KEY_F10"] = valInt(KEY_F10.int)
  env.vars["KEY_F11"] = valInt(KEY_F11.int)
  env.vars["KEY_F12"] = valInt(KEY_F12.int)
  
  # Numbers
  env.vars["KEY_0"] = valInt(KEY_0.int)
  env.vars["KEY_1"] = valInt(KEY_1.int)
  env.vars["KEY_2"] = valInt(KEY_2.int)
  env.vars["KEY_3"] = valInt(KEY_3.int)
  env.vars["KEY_4"] = valInt(KEY_4.int)
  env.vars["KEY_5"] = valInt(KEY_5.int)
  env.vars["KEY_6"] = valInt(KEY_6.int)
  env.vars["KEY_7"] = valInt(KEY_7.int)
  env.vars["KEY_8"] = valInt(KEY_8.int)
  env.vars["KEY_9"] = valInt(KEY_9.int)
  
  # Letters (uppercase)
  env.vars["KEY_A"] = valInt(KEY_A.int)
  env.vars["KEY_B"] = valInt(KEY_B.int)
  env.vars["KEY_C"] = valInt(KEY_C.int)
  env.vars["KEY_D"] = valInt(KEY_D.int)
  env.vars["KEY_E"] = valInt(KEY_E.int)
  env.vars["KEY_F"] = valInt(KEY_F.int)
  env.vars["KEY_G"] = valInt(KEY_G.int)
  env.vars["KEY_H"] = valInt(KEY_H.int)
  env.vars["KEY_I"] = valInt(KEY_I.int)
  env.vars["KEY_J"] = valInt(KEY_J.int)
  env.vars["KEY_K"] = valInt(KEY_K.int)
  env.vars["KEY_L"] = valInt(KEY_L.int)
  env.vars["KEY_M"] = valInt(KEY_M.int)
  env.vars["KEY_N"] = valInt(KEY_N.int)
  env.vars["KEY_O"] = valInt(KEY_O.int)
  env.vars["KEY_P"] = valInt(KEY_P.int)
  env.vars["KEY_Q"] = valInt(KEY_Q.int)
  env.vars["KEY_R"] = valInt(KEY_R.int)
  env.vars["KEY_S"] = valInt(KEY_S.int)
  env.vars["KEY_T"] = valInt(KEY_T.int)
  env.vars["KEY_U"] = valInt(KEY_U.int)
  env.vars["KEY_V"] = valInt(KEY_V.int)
  env.vars["KEY_W"] = valInt(KEY_W.int)
  env.vars["KEY_X"] = valInt(KEY_X.int)
  env.vars["KEY_Y"] = valInt(KEY_Y.int)
  env.vars["KEY_Z"] = valInt(KEY_Z.int)
  
  # Special symbols
  env.vars["KEY_BACKQUOTE"] = valInt(KEY_BACKQUOTE.int)  # `
  
  # ============================================================================
  # Time Functions
  # ============================================================================
  
  env.vars["now"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## now() -> map with datetime properties (year, month, day, hour, minute, second, weekday, yearday)
    let dt = now()
    let timeMap = valMap()
    timeMap.map["year"] = valInt(dt.year)
    timeMap.map["month"] = valInt(dt.month.int)  # 1-12
    timeMap.map["day"] = valInt(dt.monthday)     # 1-31
    timeMap.map["hour"] = valInt(dt.hour)        # 0-23
    timeMap.map["minute"] = valInt(dt.minute)    # 0-59
    timeMap.map["second"] = valInt(dt.second)    # 0-59
    timeMap.map["weekday"] = valInt(dt.weekday.int)  # 0=Monday, 6=Sunday
    timeMap.map["yearday"] = valInt(dt.yearday)  # 1-366
    return timeMap
  
  # ============================================================================
  # Utility Functions
  # ============================================================================
  
  env.vars["echo"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## echo(...) - print to console/stdout
    var output = ""
    for i, arg in args:
      if i > 0: output.add(" ")
      output.add($arg)
    echo output
    return valNil()
  
  env.vars["len"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## len(array or string) -> int
    if args.len < 1:
      raise newException(ValueError, "len() requires 1 argument")
    
    case args[0].kind
    of vkArray:
      return valInt(args[0].arr.len)
    of vkString:
      return valInt(args[0].s.len)
    else:
      raise newException(ValueError, "len() requires array or string")
  
  # ============================================================================
  # Audio System (Procedural Sound Generation)
  # ============================================================================
  
  # Helper to get AudioSystem from app state (lazy init)
  proc getAudioSys(): audio.AudioSystem =
    if appState.audioSystemPtr.isNil:
      appState.audioSystemPtr = cast[pointer](audio.initAudio(44100))
    result = cast[audio.AudioSystem](appState.audioSystemPtr)
  
  env.vars["audioPlayTone"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayTone(frequency: float, duration: float, waveform: string, volume: float)
    ## waveform: "sine", "square", "sawtooth", "triangle", "noise"
    if args.len < 2:
      raise newException(ValueError, "audioPlayTone() requires at least 2 arguments: frequency, duration")
    
    let frequency = case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 440.0
    
    let duration = case args[1].kind
      of vkFloat: args[1].f
      of vkInt: args[1].i.float
      else: 0.2
    
    let waveform = if args.len > 2 and args[2].kind == vkString:
      case args[2].s.toLowerAscii()
      of "square": wfSquare
      of "sawtooth", "saw": wfSawtooth
      of "triangle": wfTriangle
      of "noise": wfNoise
      else: wfSine
    else: wfSine
    
    let volume = if args.len > 3:
      case args[3].kind
      of vkFloat: args[3].f
      of vkInt: args[3].i.float
      else: 0.5
    else: 0.5
    
    getAudioSys().playTone(frequency, duration, waveform, volume)
    return valNil()
  
  env.vars["audioPlayBleep"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayBleep(frequency: float = 440.0, volume: float = 0.4)
    let frequency = if args.len > 0:
      case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 440.0
    else: 440.0
    
    let volume = if args.len > 1:
      case args[1].kind
      of vkFloat: args[1].f
      of vkInt: args[1].i.float
      else: 0.4
    else: 0.4
    
    getAudioSys().playBleep(frequency, volume)
    return valNil()
  
  env.vars["audioPlayJump"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayJump(volume: float = 0.4) - Play jump sound effect
    let volume = if args.len > 0:
      case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 0.4
    else: 0.4
    
    getAudioSys().playJump(volume)
    return valNil()
  
  env.vars["audioPlayLanding"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayLanding(volume: float = 0.5) - Play landing sound effect
    let volume = if args.len > 0:
      case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 0.5
    else: 0.5
    
    getAudioSys().playLanding(volume)
    return valNil()
  
  env.vars["audioPlayHit"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayHit(volume: float = 0.4) - Play hit/damage sound effect
    let volume = if args.len > 0:
      case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 0.4
    else: 0.4
    
    getAudioSys().playHit(volume)
    return valNil()
  
  env.vars["audioPlayPowerUp"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayPowerUp(volume: float = 0.4) - Play power-up sound effect
    let volume = if args.len > 0:
      case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 0.4
    else: 0.4
    
    getAudioSys().playPowerUp(volume)
    return valNil()
  
  env.vars["audioPlayLaser"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## audioPlayLaser(volume: float = 0.35) - Play laser sound effect
    let volume = if args.len > 0:
      case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 0.35
    else: 0.35
    
    getAudioSys().playLaser(volume)
  
  # ================================================================
  # TERMINAL SHADERS API
  # ================================================================
  
  env.vars["initShader"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## initShader(effectId: int, layerId: int, x: int, y: int, width: int, height: int)
    if args.len < 6:
      raise newException(ValueError, "initShader() requires 6 arguments: effectId, layerId, x, y, width, height")
    
    let effectId = args[0].i
    let layerId = args[1].i
    let x = args[2].i
    let y = args[3].i
    let width = args[4].i
    let height = args[5].i
    
    initShader(effectId, layerId, x, y, width, height)
    return valNil()
  
  env.vars["updateShader"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## updateShader() - Update shader animation (call in on:update)
    updateShader()
    return valNil()
  
  env.vars["drawShader"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## drawShader(layerId: int|string) - Draw shader to specified layer (call in on:render)
    if args.len < 1:
      raise newException(ValueError, "drawShader() requires 1 argument: layerId")
    
    # Use unified layer system (gAppState.layers for both terminal and SDL3)
    var layer: Layer = nil
    if args[0].kind == vkInt:
      let idx = args[0].i
      # Access layer by index in layers array
      if idx >= 0 and idx < appState.layers.len:
        layer = appState.layers[idx]
    elif args[0].kind == vkString:
      let layerId = args[0].s
      layer = getLayer(appState, layerId)
    
    if not layer.isNil:
      drawShader(layer.buffer)
    
    return valNil()
  
  env.vars["setShaderEffect"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setShaderEffect(effectId: int) - Change shader effect and reset animation
    if args.len < 1:
      raise newException(ValueError, "setShaderEffect() requires 1 argument: effectId")
    
    let effectId = args[0].i
    setShaderEffect(effectId)
    return valNil()
  
  env.vars["pauseShader"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## pauseShader() - Pause shader animation
    pauseShader()
    return valNil()
  
  env.vars["resumeShader"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## resumeShader() - Resume shader animation
    resumeShader()
    return valNil()
  
  env.vars["resetShader"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## resetShader() - Reset shader to frame 0
    resetShader()
    return valNil()
  
  # ================================================================
  # DISPLACEMENT SHADERS API
  # ================================================================
  
  env.vars["initDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## initDisplacement(effectId: int, layerId: int, x: int, y: int, width: int, height: int, intensity: float = 1.0)
    if args.len < 6:
      raise newException(ValueError, "initDisplacement() requires at least 6 arguments: effectId, layerId, x, y, width, height, [intensity]")
    
    let effectId = args[0].i
    let layerId = args[1].i
    let x = args[2].i
    let y = args[3].i
    let width = args[4].i
    let height = args[5].i
    let intensity = if args.len > 6: args[6].f else: 1.0
    
    initDisplacement(effectId, layerId, x, y, width, height, intensity)
    return valNil()
  
  env.vars["updateDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## updateDisplacement() - Update displacement animation (call in on:update)
    updateDisplacement()
    return valNil()
  
  env.vars["drawDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## drawDisplacement(destLayerId: int|string, sourceLayerId: int|string) - Apply displacement from source to dest
    if args.len < 2:
      raise newException(ValueError, "drawDisplacement() requires 2 arguments: destLayerId, sourceLayerId")
    
    var destLayer: Layer = nil
    var sourceLayer: Layer = nil
    
    # Get destination layer
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < appState.layers.len:
        destLayer = appState.layers[idx]
    elif args[0].kind == vkString:
      destLayer = getLayer(appState, args[0].s)
    
    # Get source layer
    if args[1].kind == vkInt:
      let idx = args[1].i
      if idx >= 0 and idx < appState.layers.len:
        sourceLayer = appState.layers[idx]
    elif args[1].kind == vkString:
      sourceLayer = getLayer(appState, args[1].s)
    
    if not destLayer.isNil and not sourceLayer.isNil:
      drawDisplacement(destLayer.buffer, sourceLayer.buffer)
    
    return valNil()
  
  env.vars["drawDisplacementInPlace"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## drawDisplacementInPlace(layerId: int|string) - Apply displacement in-place (creates temp copy)
    if args.len < 1:
      raise newException(ValueError, "drawDisplacementInPlace() requires 1 argument: layerId")
    
    var layer: Layer = nil
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < appState.layers.len:
        layer = appState.layers[idx]
    elif args[0].kind == vkString:
      layer = getLayer(appState, args[0].s)
    
    if not layer.isNil:
      drawDisplacementInPlace(layer.buffer)
    
    return valNil()
  
  env.vars["drawDisplacementFromLayer"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## drawDisplacementFromLayer(destLayerId, sourceLayerId, displacementLayerId, strength, mode)
    ## Use content from displacementLayer to displace sourceLayer content onto destLayer
    ## mode: 0=vertical (rain), 1=radial, 2=horizontal, 3=both axes
    if args.len < 3:
      raise newException(ValueError, "drawDisplacementFromLayer() requires at least 3 arguments: destLayerId, sourceLayerId, displacementLayerId, [strength], [mode]")
    
    var destLayer: Layer = nil
    var sourceLayer: Layer = nil
    var dispLayer: Layer = nil
    
    # Get destination layer
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < appState.layers.len:
        destLayer = appState.layers[idx]
    elif args[0].kind == vkString:
      destLayer = getLayer(appState, args[0].s)
    
    # Get source layer
    if args[1].kind == vkInt:
      let idx = args[1].i
      if idx >= 0 and idx < appState.layers.len:
        sourceLayer = appState.layers[idx]
    elif args[1].kind == vkString:
      sourceLayer = getLayer(appState, args[1].s)
    
    # Get displacement layer
    if args[2].kind == vkInt:
      let idx = args[2].i
      if idx >= 0 and idx < appState.layers.len:
        dispLayer = appState.layers[idx]
    elif args[2].kind == vkString:
      dispLayer = getLayer(appState, args[2].s)
    
    let strength = if args.len > 3: args[3].f else: 1.0
    let mode = if args.len > 4: args[4].i else: 0
    
    if not destLayer.isNil and not sourceLayer.isNil and not dispLayer.isNil:
      applyDisplacementFromLayer(
        destLayer.buffer, 
        sourceLayer.buffer, 
        dispLayer.buffer,
        0, 0, 
        destLayer.buffer.width, 
        destLayer.buffer.height,
        strength,
        mode
      )
    
    return valNil()
  
  env.vars["setDisplacementEffect"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## strength: displacement amount (default 1.0)
    ## mode: 0=radial, 1=horizontal, 2=vertical, 3=both (default 0)
    if args.len < 3:
      raise newException(ValueError, "drawDisplacementFromLayer() requires at least 3 arguments: destLayer, sourceLayer, displacementLayer")
    
    var destLayer: Layer = nil
    var sourceLayer: Layer = nil
    var dispLayer: Layer = nil
    
    # Get destination layer
    if args[0].kind == vkInt:
      let idx = args[0].i
      if idx >= 0 and idx < appState.layers.len:
        destLayer = appState.layers[idx]
    elif args[0].kind == vkString:
      destLayer = getLayer(appState, args[0].s)
    
    # Get source layer
    if args[1].kind == vkInt:
      let idx = args[1].i
      if idx >= 0 and idx < appState.layers.len:
        sourceLayer = appState.layers[idx]
    elif args[1].kind == vkString:
      sourceLayer = getLayer(appState, args[1].s)
    
    # Get displacement layer
    if args[2].kind == vkInt:
      let idx = args[2].i
      if idx >= 0 and idx < appState.layers.len:
        dispLayer = appState.layers[idx]
    elif args[2].kind == vkString:
      dispLayer = getLayer(appState, args[2].s)
    
    # Get strength (optional, default 1.0)
    let strength = if args.len > 3: args[3].f else: 1.0
    
    # Get mode (optional, default 0)
    let mode = if args.len > 4: args[4].i else: 0
    
    if not destLayer.isNil and not sourceLayer.isNil and not dispLayer.isNil:
      applyDisplacementFromLayer(
        destLayer.buffer, 
        sourceLayer.buffer, 
        dispLayer.buffer,
        0, 0, 
        destLayer.buffer.width, 
        destLayer.buffer.height,
        strength,
        mode
      )
    
    return valNil()
  
  env.vars["setDisplacementEffect"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setDisplacementEffect(effectId: int) - Change displacement effect
    ## Effects: 0=horiz wave, 1=vert wave, 2=ripple, 3=noise, 4=heat haze, 5=swirl, 6=fisheye, 7=bulge
    if args.len < 1:
      raise newException(ValueError, "setDisplacementEffect() requires 1 argument: effectId")
    
    let effectId = args[0].i
    setDisplacementEffect(effectId)
    return valNil()
  
  env.vars["setDisplacementIntensity"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setDisplacementIntensity(intensity: float) - Change displacement strength (0.0 to 1.0+)
    if args.len < 1:
      raise newException(ValueError, "setDisplacementIntensity() requires 1 argument: intensity")
    
    let intensity = args[0].f
    setDisplacementIntensity(intensity)
    return valNil()
  
  env.vars["setDisplacementSpeed"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setDisplacementSpeed(speed: float) - Change animation speed (1.0 = normal, 0.5 = half, 2.0 = double)
    if args.len < 1:
      raise newException(ValueError, "setDisplacementSpeed() requires 1 argument: speed")
    
    let speed = args[0].f
    setDisplacementSpeed(speed)
    return valNil()
  
  env.vars["setDisplacementAmplitude"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## setDisplacementAmplitude(amplitude: float) - Change base displacement (1.0 = normal, 0.3 = subtle, 0.1 = very subtle)
    if args.len < 1:
      raise newException(ValueError, "setDisplacementAmplitude() requires 1 argument: amplitude")
    
    let amplitude = args[0].f
    setDisplacementAmplitude(amplitude)
    return valNil()
  
  env.vars["pauseDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## pauseDisplacement() - Pause displacement animation
    pauseDisplacement()
    return valNil()
  
  env.vars["resumeDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## resumeDisplacement() - Resume displacement animation
    resumeDisplacement()
    return valNil()
  
  env.vars["resetDisplacement"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## resetDisplacement() - Reset displacement to frame 0
    resetDisplacement()
    return valNil()
  
  # ================================================================
  # DROPPED FILE API (for dropTarget functionality)
  # ================================================================
  
  env.vars["getDroppedFileName"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getDroppedFileName() -> string - Get the name of the dropped file
    ## Available in on:ondrop lifecycle hooks when a file is dropped
    return valString(gDroppedFileName)
  
  env.vars["getDroppedFileData"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getDroppedFileData() -> string - Get the raw binary data of the dropped file
    ## Available in on:ondrop lifecycle hooks when a file is dropped
    ## Returns binary data as a string (can be processed byte by byte)
    return valString(gDroppedFileData)
  
  env.vars["getDroppedFileSize"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getDroppedFileSize() -> int - Get the size in bytes of the dropped file
    ## Available in on:ondrop lifecycle hooks when a file is dropped
    return valInt(gDroppedFileSize)
  
  env.vars["toHex"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## toHex(value: int, width: int) -> string - Convert integer to hexadecimal string
    ## width parameter pads the output with leading zeros
    if args.len < 2:
      raise newException(ValueError, "toHex() requires 2 arguments: value, width")
    let value = args[0].i
    let width = args[1].i
    return valString(strutils.toHex(value, width))
  
  env.vars["getByte"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getByte(data: string, index: int) -> int - Get byte value at index from binary string
    ## Returns the byte value (0-255) at the specified position
    if args.len < 2:
      raise newException(ValueError, "getByte() requires 2 arguments: data, index")
    if args[0].kind != vkString:
      raise newException(ValueError, "getByte() first argument must be a string")
    let data = args[0].s
    let index = args[1].i
    if index < 0 or index >= data.len:
      return valInt(0)  # Out of bounds returns 0
    return valInt(data[index].ord)
  
  env.vars["inc"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## inc(variable) -> void - Increment an integer variable by 1
    ## Note: In nimini, use 'variable = variable + 1' instead, as inc requires mutable references
    raise newException(ValueError, "inc() is not supported in nimini. Use 'variable = variable + 1' instead")
