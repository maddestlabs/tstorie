# Nimini Bridge - API Registration for tstorie
# 
# This module provides all the API functions that are exposed to
# nimini-interpreted code. It bridges between tstorie's native types
# and nimini's dynamic value system.

import tables
import times
import strutils
import "../nimini"
import storie_types
import audio_gen
import ../src/types
import ../src/layers
import ../src/appstate

# Import audio as a module to avoid name conflicts
import audio as audioModule

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
  
  # ============================================================================
  # Input Handling
  # ============================================================================
  
  env.vars["getInput"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getInput() -> array of input events
    # Return empty array for now
    return valArray()
  
  # ============================================================================
  # State Access
  # ============================================================================
  
  env.vars["getTermWidth"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get current terminal width
    return valInt(appState.termWidth)
  
  env.vars["getTermHeight"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get current terminal height
    return valInt(appState.termHeight)
  
  env.vars["getWidth"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getWidth() -> int (alias for getTermWidth)
    return valInt(appState.termWidth)
  
  env.vars["getHeight"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getHeight() -> int (alias for getTermHeight)
    return valInt(appState.termHeight)
  
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
  
  env.vars["getFrameCount"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the total frame count
    return valInt(appState.frameCount)
  
  env.vars["getTotalTime"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## Get the total elapsed time in seconds
    return valFloat(appState.totalTime)
  
  env.vars["getDeltaTime"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getDeltaTime() -> float (alias for getting frame delta)
    return valFloat(1.0 / appState.targetFps)
  
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
  
  # Helper to get AudioSystem from pointer
  template getAudioSys(): untyped =
    if appState.audioSystemPtr.isNil:
      # Lazy initialization
      appState.audioSystemPtr = cast[pointer](audioModule.initAudio(44100))
    cast[audioModule.AudioSystem](appState.audioSystemPtr)
  
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
    return valNil()
