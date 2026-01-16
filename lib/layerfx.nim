## Layer Effects Plugin for TStorie
## Provides visual effects for layers without modifying core layer types
## 
## Features:
## - Parallax offsets (offsetX, offsetY)
## - Darkness/brightness control
## - Desaturation effects
## - Auto-depth cueing (automatic atmospheric perspective)
## - Optional displacement effects (when terminal_shaders available)
##
## Usage:
##   import lib/layerfx
##   initLayerFxPlugin()
##   registerLayerFxBindings(env)

# Import core types
when not declared(TermBuffer):
  import ../src/types
  import ../src/layers
else:
  # Included in tstorie.nim - types already available
  discard

import std/[tables, math, algorithm]

# Import nimini for binding registration
when not declared(exportNiminiProcs):
  import ../nimini/runtime

# ================================================================
# TYPE DEFINITIONS
# ================================================================

type
  LayerEffects* = object
    ## Effects applied to a layer during compositing
    offsetX*, offsetY*: int           # Parallax/camera offset
    darkenFactor*: float              # Brightness multiplier (0.0-1.0)
    desaturation*: float              # Grayscale blend (0.0-1.0)
    
    # Plugin-dependent (only if terminal_shaders available)
    displacementEffect*: string       # "wave", "ripple", "noise", ""
    displacementIntensity*: float     # Displacement strength

  LayerFxRegistry* = ref object
    ## Global registry mapping layer IDs to their effects
    effects*: Table[string, LayerEffects]
    autoDepthing*: bool
    depthMin*, depthMax*: float
    enabled*: bool  # Master enable flag

# Global registry (only exists if plugin loaded)
var gLayerFxRegistry*: LayerFxRegistry = nil

# Hook for core compositor
type
  CompositeHook* = proc(state: AppState)

# Export hook so core can check for it
var gCompositeHook* {.global.}: CompositeHook = nil

# ================================================================
# SHADER PLUGIN DETECTION
# ================================================================

# Try to detect shader support at compile time
when not defined(emscripten):
  when declared(terminal_shaders) or defined(hasTerminalShaders):
    const hasShaderSupport* = true
  else:
    const hasShaderSupport* = false
else:
  const hasShaderSupport* = false

# ================================================================
# FORWARD DECLARATIONS
# ================================================================

# Helper functions
proc mix(a, b, t: float): float {.inline.} =
  ## Linear interpolation
  a * (1.0 - t) + b * t

proc compositeLayersWithEffects*(state: AppState)

# ================================================================
# PLUGIN INITIALIZATION
# ================================================================

proc initLayerFxPlugin*() =
  ## Initialize the layer effects plugin
  ## Call this during app startup after core initialization
  if gLayerFxRegistry.isNil:
    gLayerFxRegistry = LayerFxRegistry(
      effects: initTable[string, LayerEffects](),
      autoDepthing: false,
      depthMin: 0.3,
      depthMax: 1.0,
      enabled: true
    )
    
    # Register our enhanced compositor
    gCompositeHook = compositeLayersWithEffects

proc isLayerFxAvailable*(): bool =
  ## Check if layer effects plugin is loaded
  return not gLayerFxRegistry.isNil

proc isLayerFxEnabled*(): bool =
  ## Check if layer effects are enabled
  if gLayerFxRegistry.isNil:
    return false
  return gLayerFxRegistry.enabled

proc enableLayerFx*() =
  ## Enable layer effects processing
  if not gLayerFxRegistry.isNil:
    gLayerFxRegistry.enabled = true

proc disableLayerFx*() =
  ## Disable layer effects processing (use core compositing)
  if not gLayerFxRegistry.isNil:
    gLayerFxRegistry.enabled = false

# ================================================================
# EFFECT MANAGEMENT
# ================================================================

proc getOrCreateEffects(layerId: string): var LayerEffects =
  ## Get effects for a layer, creating if needed
  if layerId notin gLayerFxRegistry.effects:
    gLayerFxRegistry.effects[layerId] = LayerEffects(
      offsetX: 0,
      offsetY: 0,
      darkenFactor: 1.0,
      desaturation: 0.0,
      displacementEffect: "",
      displacementIntensity: 0.0
    )
  return gLayerFxRegistry.effects[layerId]

proc getEffects*(layerId: string): ptr LayerEffects =
  ## Get effects for a layer (returns nil if no effects set)
  if layerId in gLayerFxRegistry.effects:
    return addr gLayerFxRegistry.effects[layerId]
  return nil

proc clearEffects*(layerId: string) =
  ## Remove all effects from a layer
  if not gLayerFxRegistry.isNil:
    gLayerFxRegistry.effects.del(layerId)

proc clearAllEffects*() =
  ## Remove all layer effects
  if not gLayerFxRegistry.isNil:
    gLayerFxRegistry.effects.clear()

# ================================================================
# CORE EFFECT FUNCTIONS (Always Available)
# ================================================================

proc setLayerOffset*(layerId: string, x, y: int) =
  ## Set parallax offset for a layer
  if gLayerFxRegistry.isNil:
    return
  var effects = getOrCreateEffects(layerId)
  effects.offsetX = x
  effects.offsetY = y

proc getLayerOffset*(layerId: string): tuple[x, y: int] =
  ## Get current offset for a layer
  if gLayerFxRegistry.isNil:
    return (0, 0)
  let effectsPtr = getEffects(layerId)
  if effectsPtr.isNil:
    return (0, 0)
  return (effectsPtr.offsetX, effectsPtr.offsetY)

proc setLayerDarkness*(layerId: string, factor: float) =
  ## Set brightness multiplier (0.0 = black, 1.0 = normal)
  if gLayerFxRegistry.isNil:
    return
  var effects = getOrCreateEffects(layerId)
  effects.darkenFactor = clamp(factor, 0.0, 1.0)

proc getLayerDarkness*(layerId: string): float =
  ## Get current darkness factor for a layer
  if gLayerFxRegistry.isNil:
    return 1.0
  let effectsPtr = getEffects(layerId)
  if effectsPtr.isNil:
    return 1.0
  return effectsPtr.darkenFactor

proc setLayerDesaturation*(layerId: string, amount: float) =
  ## Set desaturation amount (0.0 = full color, 1.0 = grayscale)
  if gLayerFxRegistry.isNil:
    return
  var effects = getOrCreateEffects(layerId)
  effects.desaturation = clamp(amount, 0.0, 1.0)

proc getLayerDesaturation*(layerId: string): float =
  ## Get current desaturation for a layer
  if gLayerFxRegistry.isNil:
    return 0.0
  let effectsPtr = getEffects(layerId)
  if effectsPtr.isNil:
    return 0.0
  return effectsPtr.desaturation

# ================================================================
# AUTO-DEPTHING
# ================================================================

proc enableAutoDepthing*(minBrightness: float = 0.3, maxBrightness: float = 1.0) =
  ## Automatically darken layers based on z-depth
  ## Lower z (background) = darker, Higher z (foreground) = brighter
  if gLayerFxRegistry.isNil:
    return
  gLayerFxRegistry.autoDepthing = true
  gLayerFxRegistry.depthMin = clamp(minBrightness, 0.0, 1.0)
  gLayerFxRegistry.depthMax = clamp(maxBrightness, 0.0, 1.0)

proc disableAutoDepthing*() =
  ## Disable automatic depth cueing
  if not gLayerFxRegistry.isNil:
    gLayerFxRegistry.autoDepthing = false

proc isAutoDepthing*(): bool =
  ## Check if auto-depthing is enabled
  if gLayerFxRegistry.isNil:
    return false
  return gLayerFxRegistry.autoDepthing

proc applyAutoDepthing*(state: AppState) =
  ## Apply auto-depthing to all layers
  if gLayerFxRegistry.isNil or not gLayerFxRegistry.autoDepthing or state.layers.len == 0:
    return
  
  # Find z-range
  var minZ = state.layers[0].z
  var maxZ = state.layers[0].z
  for layer in state.layers:
    minZ = min(minZ, layer.z)
    maxZ = max(maxZ, layer.z)
  
  let zRange = float(maxZ - minZ)
  if zRange < 0.01:  # All same z
    return
  
  # Apply brightness based on normalized z
  for layer in state.layers:
    let normalizedZ = float(layer.z - minZ) / zRange  # 0.0 to 1.0
    let brightness = mix(gLayerFxRegistry.depthMin, gLayerFxRegistry.depthMax, normalizedZ)
    setLayerDarkness(layer.id, brightness)

# ================================================================
# PLUGIN-ENHANCED EFFECTS (Conditional)
# ================================================================

proc setLayerDisplacement*(layerId: string, effect: string, intensity: float) =
  ## Set displacement effect (requires shader plugin)
  ## Gracefully ignored if shaders unavailable
  if gLayerFxRegistry.isNil:
    return
  when hasShaderSupport:
    var effects = getOrCreateEffects(layerId)
    effects.displacementEffect = effect
    effects.displacementIntensity = intensity
  else:
    discard  # Silently ignore

proc getLayerDisplacement*(layerId: string): tuple[effect: string, intensity: float] =
  ## Get current displacement settings
  if gLayerFxRegistry.isNil:
    return ("", 0.0)
  let effectsPtr = getEffects(layerId)
  if effectsPtr.isNil:
    return ("", 0.0)
  return (effectsPtr.displacementEffect, effectsPtr.displacementIntensity)

# ================================================================
# EFFECT APPLICATION INTERNALS
# ================================================================

proc applyColorEffects(style: Style, effects: LayerEffects): Style =
  ## Apply color-based effects to a style
  result = style
  
  # Apply darkening
  if effects.darkenFactor < 1.0:
    result.fg.r = uint8(clamp(float(style.fg.r) * effects.darkenFactor, 0.0, 255.0))
    result.fg.g = uint8(clamp(float(style.fg.g) * effects.darkenFactor, 0.0, 255.0))
    result.fg.b = uint8(clamp(float(style.fg.b) * effects.darkenFactor, 0.0, 255.0))
  
  # Apply desaturation
  if effects.desaturation > 0.0:
    let gray = uint8(
      0.299 * float(result.fg.r) +
      0.587 * float(result.fg.g) +
      0.114 * float(result.fg.b)
    )
    result.fg.r = uint8(mix(float(result.fg.r), float(gray), effects.desaturation))
    result.fg.g = uint8(mix(float(result.fg.g), float(gray), effects.desaturation))
    result.fg.b = uint8(mix(float(result.fg.b), float(gray), effects.desaturation))

proc applyDisplacement(x, y: int, effects: LayerEffects): tuple[dx, dy: int] =
  ## Calculate displacement offset
  when hasShaderSupport:
    if effects.displacementEffect.len > 0:
      case effects.displacementEffect
      of "wave":
        let offset = sin(float(x) * 0.1 + float(y) * 0.05) * effects.displacementIntensity
        return (0, int(offset))
      of "ripple":
        let dist = sqrt(float(x * x + y * y))
        let offset = sin(dist * 0.1) * effects.displacementIntensity
        return (int(offset), int(offset))
      of "noise":
        # Simple pseudo-random displacement
        let val = sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
        let noise = (val - floor(val)) * 2.0 - 1.0
        let offset = noise * effects.displacementIntensity
        return (int(offset), int(offset))
      else:
        return (0, 0)
  
  return (0, 0)

# ================================================================
# ENHANCED COMPOSITING
# ================================================================

proc compositeLayersWithEffects*(state: AppState) =
  ## Enhanced layer compositing that applies effects
  ## This REPLACES the core compositeLayers when plugin is loaded and enabled
  if gLayerFxRegistry.isNil or not gLayerFxRegistry.enabled or state.layers.len == 0:
    # Fall back to core compositing
    compositeLayers(state)
    return
  
  # Apply auto-depthing if enabled
  if gLayerFxRegistry.autoDepthing:
    applyAutoDepthing(state)
  
  # Clear destination
  state.currentBuffer.clear(state.themeBackground)
  
  # Sort layers by z-index
  state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
  
  # Composite each layer with effects
  for layer in state.layers:
    if not layer.visible:
      continue
    
    # Get effects for this layer (if any)
    let effectsPtr = getEffects(layer.id)
    
    if effectsPtr.isNil:
      # No effects - use standard composite
      compositeBufferOnto(state.currentBuffer, layer.buffer)
    else:
      # Apply effects during composite
      let effects = effectsPtr[]
      let w = min(state.currentBuffer.width, layer.buffer.width)
      let h = min(state.currentBuffer.height, layer.buffer.height)
      
      for y in 0 ..< h:
        for x in 0 ..< w:
          # Calculate source position with offset
          let srcX = x - effects.offsetX
          let srcY = y - effects.offsetY
          
          if srcX < 0 or srcX >= layer.buffer.width or srcY < 0 or srcY >= layer.buffer.height:
            continue
          
          let srcIdx = srcY * layer.buffer.width + srcX
          var cell = layer.buffer.cells[srcIdx]
          
          # Skip transparent
          if cell.ch.len == 0 and cell.style.bg.r == 0 and 
             cell.style.bg.g == 0 and cell.style.bg.b == 0:
            continue
          
          # Apply displacement
          var finalX = x
          var finalY = y
          let (dx, dy) = applyDisplacement(x, y, effects)
          finalX += dx
          finalY += dy
          
          if finalX < 0 or finalX >= state.currentBuffer.width or 
             finalY < 0 or finalY >= state.currentBuffer.height:
            continue
          
          # Apply color effects
          cell.style = applyColorEffects(cell.style, effects)
          
          # Write to destination
          let destIdx = finalY * state.currentBuffer.width + finalX
          if destIdx >= 0 and destIdx < state.currentBuffer.cells.len:
            state.currentBuffer.cells[destIdx] = cell

# ================================================================
# INTROSPECTION
# ================================================================

proc getLayerFxInfo*(): tuple[
  available: bool,
  enabled: bool, 
  autoDepthing: bool,
  shaderSupport: bool,
  effectCount: int
] =
  ## Get information about layer effects status
  if gLayerFxRegistry.isNil:
    return (false, false, false, false, 0)
  
  return (
    available: true,
    enabled: gLayerFxRegistry.enabled,
    autoDepthing: gLayerFxRegistry.autoDepthing,
    shaderSupport: hasShaderSupport,
    effectCount: gLayerFxRegistry.effects.len
  )

proc listLayersWithEffects*(): seq[string] =
  ## Get list of layer IDs that have effects applied
  if gLayerFxRegistry.isNil:
    return @[]
  
  result = @[]
  for layerId in gLayerFxRegistry.effects.keys:
    result.add(layerId)

# ================================================================
# NIMINI BINDINGS
# ================================================================

# Helper to convert Value to int/float
proc layerfxValueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

proc layerfxValueToFloat(v: Value): float =
  case v.kind
  of vkFloat: return v.f
  of vkInt: return float(v.i)
  else: return 0.0

proc layerfxValueToString(v: Value): string =
  case v.kind
  of vkString: return v.s
  else: return ""

proc getLayerIdFromValue(v: Value, state: AppState): string =
  ## Get layer ID from Value (supports int index or string ID)
  case v.kind
  of vkInt:
    let idx = v.i
    if idx >= 0 and idx < state.layers.len:
      return state.layers[idx].id
    return ""
  of vkString:
    return v.s
  else:
    return ""

proc nimini_setLayerOffset(env: ref Env; args: seq[Value]): Value =
  ## setLayerOffset(layerId: string|int, x: int, y: int)
  ## Set parallax offset for a layer
  if args.len < 3:
    return valNil()
  
  when declared(gAppState):
    let layerId = getLayerIdFromValue(args[0], gAppState)
  else:
    let layerId = layerfxValueToString(args[0])
  
  if layerId.len == 0:
    return valNil()
  
  let x = layerfxValueToInt(args[1])
  let y = layerfxValueToInt(args[2])
  setLayerOffset(layerId, x, y)
  return valNil()

proc nimini_setLayerDarkness(env: ref Env; args: seq[Value]): Value =
  ## setLayerDarkness(layerId: string|int, factor: float)
  ## Set darkness/brightness (0.0 = black, 1.0 = normal)
  if args.len < 2:
    return valNil()
  
  when declared(gAppState):
    let layerId = getLayerIdFromValue(args[0], gAppState)
  else:
    let layerId = layerfxValueToString(args[0])
  
  if layerId.len == 0:
    return valNil()
  
  let factor = layerfxValueToFloat(args[1])
  setLayerDarkness(layerId, factor)
  return valNil()

proc nimini_setLayerDesaturation(env: ref Env; args: seq[Value]): Value =
  ## setLayerDesaturation(layerId: string|int, amount: float)
  ## Set desaturation (0.0 = full color, 1.0 = grayscale)
  if args.len < 2:
    return valNil()
  
  when declared(gAppState):
    let layerId = getLayerIdFromValue(args[0], gAppState)
  else:
    let layerId = layerfxValueToString(args[0])
  
  if layerId.len == 0:
    return valNil()
  
  let amount = layerfxValueToFloat(args[1])
  setLayerDesaturation(layerId, amount)
  return valNil()

proc nimini_enableAutoDepthing(env: ref Env; args: seq[Value]): Value =
  ## enableAutoDepthing([minBrightness: float, maxBrightness: float])
  ## Enable automatic depth cueing (back layers darker)
  let minB = if args.len >= 1: layerfxValueToFloat(args[0]) else: 0.3
  let maxB = if args.len >= 2: layerfxValueToFloat(args[1]) else: 1.0
  enableAutoDepthing(minB, maxB)
  return valNil()

proc nimini_disableAutoDepthing(env: ref Env; args: seq[Value]): Value =
  ## disableAutoDepthing()
  ## Disable automatic depth cueing
  disableAutoDepthing()
  return valNil()

proc nimini_setLayerDisplacement(env: ref Env; args: seq[Value]): Value =
  ## setLayerDisplacement(layerId: string|int, effect: string, intensity: float)
  ## Set displacement effect (requires shader plugin)
  ## Effects: "wave", "ripple", "noise", ""
  if args.len < 3:
    return valNil()
  
  when declared(gAppState):
    let layerId = getLayerIdFromValue(args[0], gAppState)
  else:
    let layerId = layerfxValueToString(args[0])
  
  if layerId.len == 0:
    return valNil()
  
  let effect = layerfxValueToString(args[1])
  let intensity = layerfxValueToFloat(args[2])
  setLayerDisplacement(layerId, effect, intensity)
  return valNil()

proc nimini_getLayerFxInfo(env: ref Env; args: seq[Value]): Value =
  ## getLayerFxInfo() -> { available, enabled, autoDepthing, shaderSupport, effectCount }
  ## Get information about layer effects status
  let info = getLayerFxInfo()
  
  result = valMap()
  result.map["available"] = valBool(info.available)
  result.map["enabled"] = valBool(info.enabled)
  result.map["autoDepthing"] = valBool(info.autoDepthing)
  result.map["shaderSupport"] = valBool(info.shaderSupport)
  result.map["effectCount"] = valInt(info.effectCount)

proc nimini_enableLayerFx(env: ref Env; args: seq[Value]): Value =
  ## enableLayerFx()
  ## Enable layer effects processing
  enableLayerFx()
  return valNil()

proc nimini_disableLayerFx(env: ref Env; args: seq[Value]): Value =
  ## disableLayerFx()
  ## Disable layer effects processing
  disableLayerFx()
  return valNil()

proc nimini_clearLayerEffects(env: ref Env; args: seq[Value]): Value =
  ## clearLayerEffects([layerId: string|int])
  ## Clear effects from a specific layer, or all layers if no arg
  if args.len == 0:
    clearAllEffects()
  else:
    when declared(gAppState):
      let layerId = getLayerIdFromValue(args[0], gAppState)
    else:
      let layerId = layerfxValueToString(args[0])
    
    if layerId.len > 0:
      clearEffects(layerId)
  
  return valNil()

# ================================================================
# PLUGIN REGISTRATION
# ================================================================

proc registerLayerFxBindings*(env: ref Env) =
  ## Register all layer effects functions to nimini environment
  ## Call this after initializing the plugin
  if gLayerFxRegistry.isNil:
    return
  
  # Core effect functions
  defineVar(env, "setLayerOffset", valNativeFunc(nimini_setLayerOffset))
  defineVar(env, "setLayerDarkness", valNativeFunc(nimini_setLayerDarkness))
  defineVar(env, "setLayerDesaturation", valNativeFunc(nimini_setLayerDesaturation))
  
  # Auto-depthing
  defineVar(env, "enableAutoDepthing", valNativeFunc(nimini_enableAutoDepthing))
  defineVar(env, "disableAutoDepthing", valNativeFunc(nimini_disableAutoDepthing))
  
  # Displacement
  defineVar(env, "setLayerDisplacement", valNativeFunc(nimini_setLayerDisplacement))
  
  # Control and introspection
  defineVar(env, "getLayerFxInfo", valNativeFunc(nimini_getLayerFxInfo))
  defineVar(env, "enableLayerFx", valNativeFunc(nimini_enableLayerFx))
  defineVar(env, "disableLayerFx", valNativeFunc(nimini_disableLayerFx))
  defineVar(env, "clearLayerEffects", valNativeFunc(nimini_clearLayerEffects))

# ================================================================
# EXPORTS FOR NATIVE CODE
# ================================================================

# Export all public API
export LayerEffects, LayerFxRegistry
export gLayerFxRegistry, gCompositeHook, CompositeHook
export hasShaderSupport

# Plugin lifecycle
export initLayerFxPlugin, isLayerFxAvailable, isLayerFxEnabled
export enableLayerFx, disableLayerFx

# Effect management
export getEffects, clearEffects, clearAllEffects

# Core effects
export setLayerOffset, getLayerOffset
export setLayerDarkness, getLayerDarkness
export setLayerDesaturation, getLayerDesaturation

# Auto-depthing
export enableAutoDepthing, disableAutoDepthing, isAutoDepthing
export applyAutoDepthing

# Displacement
export setLayerDisplacement, getLayerDisplacement

# Compositing
export compositeLayersWithEffects

# Introspection
export getLayerFxInfo, listLayersWithEffects

# Nimini bindings
export registerLayerFxBindings
