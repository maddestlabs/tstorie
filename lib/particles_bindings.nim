## Nimini Bindings for Particle System
##
## Exposes the native particle system to nimini scripting with a simple API.
## The system handles all iteration natively for maximum performance.

import std/tables
import particles
import ../nimini
import ../src/types
import ../src/layers

# Global particle systems registry (keyed by name for multiple systems)
var gParticleSystems: Table[string, ParticleSystem]

# Global reference to app state (for layer access)
var gAppStateRef: AppState = nil

proc initParticleSystemsRegistry() =
  # Initialize on first use
  discard

# ================================================================
# NIMINI BINDINGS
# ================================================================

proc particleInit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Initialize a particle system
  ## Args: name (string), maxParticles (int, optional, default=1000)
  ## Returns: nil
  initParticleSystemsRegistry()
  
  if args.len < 1:
    return valNil()
  
  let name = args[0].s
  let maxParticles = if args.len >= 2: args[1].i else: 1000
  
  gParticleSystems[name] = initParticleSystem(maxParticles)
  return valNil()

proc particleUpdate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update particle system
  ## Args: name (string), deltaTime (float)
  ## Returns: nil
  if args.len < 2 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let dt = case args[1].kind
    of vkFloat: args[1].f
    of vkInt: float(args[1].i)
    else: 0.016  # Default to ~60fps
  
  gParticleSystems[name].update(dt)
  return valNil()

proc particleRender*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render particle system to layer
  ## Args: name (string), layerId (int)
  ## Returns: nil
  if args.len < 2 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let layerId = args[1].i
  
  if gAppStateRef.isNil:
    return valNil()
  
  let ps = gParticleSystems[name]
  
  # Get the layer from app state
  if gAppStateRef.layers.len == 0:
    return valNil()
  
  let layer = if layerId == 0 and gAppStateRef.layers.len > 0:
    gAppStateRef.layers[0]
  elif layerId >= 0 and layerId < gAppStateRef.layers.len:
    gAppStateRef.layers[layerId]
  else:
    return valNil()
  
  if layer.isNil:
    return valNil()
  
  # Render particles to the layer (pass ptr Layer)
  ps.render(layer.unsafeAddr)
  
  return valNil()

proc particleEmit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Manually emit particles
  ## Args: name (string), count (int, optional, default=1)
  ## Returns: nil
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let count = if args.len >= 2: args[1].i else: 1
  
  gParticleSystems[name].emit(count)
  return valNil()

proc particleClear*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Clear all particles in system
  ## Args: name (string)
  ## Returns: nil
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  gParticleSystems[name].clear()
  return valNil()

proc particleGetCount*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get active particle count
  ## Args: name (string)
  ## Returns: int
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valInt(0)
  
  let name = args[0].s
  return valInt(gParticleSystems[name].getActiveCount())

# ================================================================
# PARAMETER SETTERS
# ================================================================

proc particleSetGravity*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set gravity
  ## Args: name (string), gravity (float)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].gravity = args[1].f
  return valNil()

proc particleSetWind*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set wind force
  ## Args: name (string), windX (float), windY (float)
  if args.len >= 3 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].windForce = (args[1].f, args[2].f)
  return valNil()

proc particleSetTurbulence*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set turbulence
  ## Args: name (string), turbulence (float)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].turbulence = args[1].f
  return valNil()

proc particleSetDamping*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set damping (air resistance)
  ## Args: name (string), damping (float, 0-1)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].damping = args[1].f
  return valNil()

proc particleSetEmitRate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set emission rate (particles per second)
  ## Args: name (string), rate (float)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].emitRate = args[1].f
  return valNil()

proc particleSetEmitterPos*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set emitter position
  ## Args: name (string), x (float), y (float)
  if args.len >= 3 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].emitterPos = (args[1].f, args[2].f)
  return valNil()

proc particleSetEmitterSize*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set emitter size (for line/area shapes)
  ## Args: name (string), width (float), height (float)
  if args.len >= 3 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].emitterSize = (args[1].f, args[2].f)
  return valNil()

proc particleSetVelocityRange*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set velocity range for spawned particles
  ## Args: name (string), minX, minY, maxX, maxY (floats)
  if args.len >= 5 and gParticleSystems.hasKey(args[0].s):
    let ps = gParticleSystems[args[0].s]
    ps.velocityMin = (args[1].f, args[2].f)
    ps.velocityMax = (args[3].f, args[4].f)
  return valNil()

proc particleSetLifeRange*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set lifetime range for spawned particles
  ## Args: name (string), minLife (float), maxLife (float)
  if args.len >= 3 and gParticleSystems.hasKey(args[0].s):
    let ps = gParticleSystems[args[0].s]
    ps.lifeMin = args[1].f
    ps.lifeMax = args[2].f
  return valNil()

proc particleSetCollision*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Enable/disable collision detection
  ## Args: name (string), enabled (bool), response (int: 0=none, 1=bounce, 2=stick, 3=destroy)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let ps = gParticleSystems[args[0].s]
    ps.collisionEnabled = args[1].b
    if args.len >= 3:
      ps.collisionResponse = CollisionResponse(args[2].i)
  return valNil()

proc particleSetStickChar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set character to use when particles stick
  ## Args: name (string), char (string)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].stickChar = args[1].s
  return valNil()

proc particleSetChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set custom character set for particles
  ## Args: name (string), chars (string) - each character in the string becomes a possible particle
  ## Example: particleSetChars("sys", "•○◦∘") or particleSetChars("sys", "█▓▒░")
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let charsStr = args[1].s
    var charSeq: seq[string] = @[]
    for ch in charsStr:
      charSeq.add($ch)
    gParticleSystems[args[0].s].chars = charSeq
  return valNil()

proc particleSetBackgroundColor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set background color for particles (theme-aware)
  ## Args: name (string), r (int), g (int), b (int)
  if args.len >= 4 and gParticleSystems.hasKey(args[0].s):
    let r = uint8(args[1].i)
    let g = uint8(args[2].i)
    let b = uint8(args[3].i)
    gParticleSystems[args[0].s].backgroundColor = rgb(r, g, b)
  return valNil()

proc particleSetColorRange*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set foreground color range for spawned particles
  ## Args: name (string), minR, minG, minB, maxR, maxG, maxB (ints 0-255)
  if args.len >= 7 and gParticleSystems.hasKey(args[0].s):
    let ps = gParticleSystems[args[0].s]
    ps.colorMin = Color(
      r: uint8(args[1].i),
      g: uint8(args[2].i),
      b: uint8(args[3].i)
    )
    ps.colorMax = Color(
      r: uint8(args[4].i),
      g: uint8(args[5].i),
      b: uint8(args[6].i)
    )
  return valNil()

proc particleSetTrailEnabled*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Enable/disable particle trails
  ## Args: name (string), enabled (bool)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].trailEnabled = args[1].b
  return valNil()

proc particleSetTrailLength*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set maximum trail length (number of segments)
  ## Args: name (string), length (int)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].trailMaxLength = args[1].i
  return valNil()

proc particleSetTrailSpacing*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set spacing between trail segments
  ## Args: name (string), spacing (float)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    gParticleSystems[args[0].s].trailSpacing = args[1].f
  return valNil()

proc particleSetDrawMode*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set how particles affect cells they render to
  ## Args: name (string), mode (int)
  ##   0 = Replace entire cell (default)
  ##   1 = Background only (preserves text/char)
  ##   2 = Foreground only (preserves char)
  ##   3 = Character only (preserves colors)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let mode = args[1].i
    if mode >= 0 and mode <= 3:
      gParticleSystems[args[0].s].drawMode = ParticleDrawMode(mode)
  return valNil()

proc particleSetBackgroundFromStyle*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set particle background color from a style object's background
  ## Args: name (string), style (map with bg field)
  ## Example: var style = getStyle("default"); particleSetBackgroundFromStyle("sparkles", style)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let styleObj = args[1]
    if styleObj.kind == vkMap and styleObj.map.hasKey("bg"):
      let bgColor = styleObj.map["bg"]
      if bgColor.kind == vkMap:
        let r = if bgColor.map.hasKey("r"): uint8(bgColor.map["r"].i) else: 0u8
        let g = if bgColor.map.hasKey("g"): uint8(bgColor.map["g"].i) else: 0u8
        let b = if bgColor.map.hasKey("b"): uint8(bgColor.map["b"].i) else: 0u8
        gParticleSystems[args[0].s].backgroundColor = rgb(r, g, b)
  return valNil()

proc particleSetForegroundFromStyle*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set particle foreground colors from a style object's foreground
  ## Args: name (string), style (map with fg field)
  ## Example: var style = getStyle("accent1"); particleSetForegroundFromStyle("sparkles", style)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let styleObj = args[1]
    if styleObj.kind == vkMap and styleObj.map.hasKey("fg"):
      let fgColor = styleObj.map["fg"]
      if fgColor.kind == vkMap:
        let r = if fgColor.map.hasKey("r"): uint8(fgColor.map["r"].i) else: 255u8
        let g = if fgColor.map.hasKey("g"): uint8(fgColor.map["g"].i) else: 255u8
        let b = if fgColor.map.hasKey("b"): uint8(fgColor.map["b"].i) else: 255u8
        # Set both min and max to same color for solid color particles
        gParticleSystems[args[0].s].colorMin = Color(r: r, g: g, b: b)
        gParticleSystems[args[0].s].colorMax = Color(r: r, g: g, b: b)
  return valNil()

# ================================================================
# PRESET CONFIGURATIONS
# ================================================================

proc particleConfigureRain*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for rain effect
  ## Args: name (string), intensity (float, optional, default=50)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 50.0
  
  gParticleSystems[name].configureRain(intensity)
  return valNil()

proc particleConfigureSnow*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for snow effect
  ## Args: name (string), intensity (float, optional, default=30)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 30.0
  
  gParticleSystems[name].configureSnow(intensity)
  return valNil()

proc particleConfigureFire*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for fire effect
  ## Args: name (string), intensity (float, optional, default=100)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 100.0
  
  gParticleSystems[name].configureFire(intensity)
  return valNil()

proc particleConfigureSparkles*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for sparkle effect
  ## Args: name (string), intensity (float, optional, default=20)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 20.0
  
  gParticleSystems[name].configureSparkles(intensity)
  return valNil()

proc particleConfigureExplosion*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for explosion effect
  ## Args: name (string)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  gParticleSystems[name].configureExplosion()
  return valNil()

proc particleConfigureColorblast*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for colorblast effect
  ## Args: name (string)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  gParticleSystems[name].configureColorblast()
  return valNil()

proc particleConfigureMatrix*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for Matrix rain effect
  ## Args: name (string), intensity (float, optional, default=20)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 20.0
  
  gParticleSystems[name].configureMatrix(intensity)
  return valNil()

proc particleConfigureBugs*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure particle system for bug/centipede effect
  ## Args: name (string), intensity (float, optional, default=5)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 5.0
  
  gParticleSystems[name].configureBugs(intensity)
  return valNil()

# ================================================================
# REGISTRATION
# ================================================================

proc registerParticleBindings*(env: ref Env, appState: AppState) =
  ## Register all particle system functions with nimini runtime
  gAppStateRef = appState
  env.vars["particleInit"] = valNativeFunc(particleInit)
  env.vars["particleUpdate"] = valNativeFunc(particleUpdate)
  env.vars["particleRender"] = valNativeFunc(particleRender)
  env.vars["particleEmit"] = valNativeFunc(particleEmit)
  env.vars["particleClear"] = valNativeFunc(particleClear)
  env.vars["particleGetCount"] = valNativeFunc(particleGetCount)
  
  # Parameter setters
  env.vars["particleSetEmitterSize"] = valNativeFunc(particleSetEmitterSize)
  env.vars["particleSetGravity"] = valNativeFunc(particleSetGravity)
  env.vars["particleSetWind"] = valNativeFunc(particleSetWind)
  env.vars["particleSetTurbulence"] = valNativeFunc(particleSetTurbulence)
  env.vars["particleSetDamping"] = valNativeFunc(particleSetDamping)
  env.vars["particleSetEmitRate"] = valNativeFunc(particleSetEmitRate)
  env.vars["particleSetEmitterPos"] = valNativeFunc(particleSetEmitterPos)
  env.vars["particleSetVelocityRange"] = valNativeFunc(particleSetVelocityRange)
  env.vars["particleSetLifeRange"] = valNativeFunc(particleSetLifeRange)
  env.vars["particleSetCollision"] = valNativeFunc(particleSetCollision)
  env.vars["particleSetStickChar"] = valNativeFunc(particleSetStickChar)
  env.vars["particleSetChars"] = valNativeFunc(particleSetChars)
  env.vars["particleSetBackgroundColor"] = valNativeFunc(particleSetBackgroundColor)
  env.vars["particleSetColorRange"] = valNativeFunc(particleSetColorRange)
  env.vars["particleSetTrailEnabled"] = valNativeFunc(particleSetTrailEnabled)
  env.vars["particleSetTrailLength"] = valNativeFunc(particleSetTrailLength)
  env.vars["particleSetTrailSpacing"] = valNativeFunc(particleSetTrailSpacing)
  env.vars["particleSetDrawMode"] = valNativeFunc(particleSetDrawMode)
  env.vars["particleSetBackgroundFromStyle"] = valNativeFunc(particleSetBackgroundFromStyle)
  env.vars["particleSetForegroundFromStyle"] = valNativeFunc(particleSetForegroundFromStyle)
  
  # Presets
  env.vars["particleConfigureRain"] = valNativeFunc(particleConfigureRain)
  env.vars["particleConfigureSnow"] = valNativeFunc(particleConfigureSnow)
  env.vars["particleConfigureFire"] = valNativeFunc(particleConfigureFire)
  env.vars["particleConfigureSparkles"] = valNativeFunc(particleConfigureSparkles)
  env.vars["particleConfigureExplosion"] = valNativeFunc(particleConfigureExplosion)
  env.vars["particleConfigureColorblast"] = valNativeFunc(particleConfigureColorblast)
  env.vars["particleConfigureMatrix"] = valNativeFunc(particleConfigureMatrix)
  env.vars["particleConfigureBugs"] = valNativeFunc(particleConfigureBugs)
