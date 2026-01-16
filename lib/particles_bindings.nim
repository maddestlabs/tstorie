## Nimini Bindings for Particle System
##
## Exposes the native particle system to nimini scripting with a simple API.
## The system handles all iteration natively for maximum performance.
##
## BINDING PATTERN:
## This module uses the REGISTRY PATTERN - no auto-exposed functions.
##
## Why no auto-expose?
## - Native functions: take ParticleSystem ref as first parameter
## - Nimini API: takes string name as first parameter, does registry lookup
## - These are fundamentally different signatures (string → lookup vs direct ref)
##
## Benefits of registry pattern:
## - Avoids passing ref objects through nimini Value system
## - Scripts use simple string names: "rain", "fire", "explosion"
## - Multiple particle systems can coexist with different names
## - Clean separation between native performance and script convenience
##
## All ~25 functions use manual wrappers with this pattern:
##   proc particleXxx(env, args): Value =
##     let name = args[0].s  # Get system name
##     gParticleSystems[name].nativeMethod()  # Lookup + call

import std/[tables, math]
import particles
import graph
import primitives
import ../nimini
import ../nimini/type_converters
import ../src/types
import ../src/layers
import nimini_helpers

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
  ## Args: name (string), layerId (string|int)
  ## Returns: nil
  if args.len < 2 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  
  if gAppStateRef.isNil:
    return valNil()
  
  let ps = gParticleSystems[name]
  
  # Get the layer from app state
  if gAppStateRef.layers.len == 0:
    return valNil()
  
  # Support both string and int layer references
  let layer = if args[1].kind == vkInt:
    let layerId = args[1].i
    if layerId == 0 and gAppStateRef.layers.len > 0:
      gAppStateRef.layers[0]
    elif layerId >= 0 and layerId < gAppStateRef.layers.len:
      gAppStateRef.layers[layerId]
    else:
      return valNil()
  elif args[1].kind == vkString:
    let layerId = args[1].s
    let foundLayer = getLayer(gAppStateRef, layerId)
    if foundLayer.isNil: return valNil()
    foundLayer
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
# PARAMETER SETTERS
# ================================================================

# Most simple setters are registered via templates in registerParticleBindings()
# Only complex procs are defined here

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

# Simple string/bool/int setters registered via templates in registerParticleBindings()


proc particleSetChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set custom character set for particles
  ## Args: name (string), chars (string) - each character in the string becomes a possible particle
  ## Example: particleSetChars("sys", "•○◦∘") or particleSetChars("sys", "█▓▒░")
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let charsStr = args[1].s
    var charSeq: seq[string] = @[]
    
    # Parse UTF-8 characters properly
    var i = 0
    while i < charsStr.len:
      var b = ord(charsStr[i])
      
      # Detect UTF-8 character length based on first byte
      var charLen = 1
      if b < 128:
        charLen = 1
      elif b >= 192 and b < 224:
        charLen = 2
      elif b >= 224 and b < 240:
        charLen = 3
      elif b >= 240:
        charLen = 4
      
      var endIdx = min(i + charLen, charsStr.len)
      charSeq.add(charsStr[i ..< endIdx])
      i = endIdx
    
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

proc particleSetTrailChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set custom character set for trail segments
  ## Args: name (string), chars (string) - each character becomes a possible trail segment
  ## Example: particleSetTrailChars("sys", "·°˙")
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let charsStr = args[1].s
    var charSeq: seq[string] = @[]
    
    # Parse UTF-8 characters properly
    var i = 0
    while i < charsStr.len:
      var b = ord(charsStr[i])
      
      # Detect UTF-8 character length based on first byte
      var charLen = 1
      if b < 128:
        charLen = 1
      elif b >= 192 and b < 224:
        charLen = 2
      elif b >= 224 and b < 240:
        charLen = 3
      elif b >= 240:
        charLen = 4
      
      var endIdx = min(i + charLen, charsStr.len)
      charSeq.add(charsStr[i ..< endIdx])
      i = endIdx
    
    gParticleSystems[args[0].s].trailChars = charSeq
  return valNil()

proc particleCheckHit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if there's an active particle near the given position and remove it
  ## Args: name (string), x (int), y (int), radius (float, optional, default=1.0)
  ## Returns: bool (true if hit and removed a particle)
  if args.len < 3 or not gParticleSystems.hasKey(args[0].s):
    return valBool(false)
  
  let name = args[0].s
  let targetX = float(args[1].i)
  let targetY = float(args[2].i)
  let radius = if args.len >= 4: args[3].f else: 1.0
  
  let ps = gParticleSystems[name]
  
  # Check all active particles for proximity
  for i in 0 ..< ps.maxParticles:
    if not ps.particles[i].active:
      continue
    
    # Calculate distance to target point
    let dx = ps.particles[i].x - targetX
    let dy = ps.particles[i].y - targetY
    let dist = sqrt(dx * dx + dy * dy)
    
    # If within radius, deactivate particle and return true
    if dist <= radius:
      ps.particles[i].active = false
      return valBool(true)
  
  return valBool(false)

proc particleSetEmitterShape*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set emitter shape
  ## Args: name (string), shape (int)
  ##   0 = Point (single point)
  ##   1 = Line (emit along a line)
  ##   2 = Circle (emit from circle perimeter)
  ##   3 = Rectangle (emit from rectangle edges)
  ##   4 = Area (emit from filled area)
  if args.len >= 2 and gParticleSystems.hasKey(args[0].s):
    let shape = args[1].i
    if shape >= 0 and shape <= 4:
      gParticleSystems[args[0].s].emitterShape = EmitterShape(shape)
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
# NEW GRAPH-BASED CONFIGURATION
# ================================================================

proc particleConfigureVortex*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure vortex effect using graph-based motion
  ## Args: name (string), centerX (float), centerY (float), strength (float, optional, default=1.0)
  if args.len < 3 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let centerX = args[1].f
  let centerY = args[2].f
  let strength = if args.len >= 4: args[3].f else: 1.0
  
  let ps = gParticleSystems[name]
  
  # Configure vortex with graph-based motion
  ps.motionGraph = configureVortexGraph(centerX, centerY)
  ps.effectMode = pemParticles
  
  # Set basic parameters
  ps.emitRate = 30.0 * strength
  ps.velocityMin = (-5.0, -5.0)
  ps.velocityMax = (5.0, 5.0)
  ps.lifeMin = 3.0
  ps.lifeMax = 5.0
  ps.chars = @["*", "+", "·", "•", "○"]
  ps.colorMin = Color(r: 255, g: 150, b: 255)
  ps.colorMax = Color(r: 100, g: 200, b: 255)
  
  return valNil()

proc particleConfigureRadialExplosion*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure radial explosion effect using graph-based motion
  ## Args: name (string), centerX (float), centerY (float)
  if args.len < 3 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let centerX = args[1].f
  let centerY = args[2].f
  
  let ps = gParticleSystems[name]
  
  # Configure explosion with graph-based motion
  ps.motionGraph = configureExplosionGraph((x: centerX, y: centerY))
  ps.effectMode = pemParticles
  
  # Set basic parameters
  ps.emitRate = 0.0  # Manual emit only
  ps.velocityMin = (-15.0, -15.0)
  ps.velocityMax = (15.0, 15.0)
  ps.lifeMin = 1.0
  ps.lifeMax = 2.0
  ps.chars = @["*", "◆", "●", "■", "@", "#"]
  ps.colorMin = Color(r: 255, g: 200, b: 0)
  ps.colorMax = Color(r: 255, g: 100, b: 0)
  ps.gravity = 10.0
  
  return valNil()

proc particleConfigureMatrixHybrid*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure Matrix rain with hybrid mode (particles + spatial trails)
  ## Args: name (string), intensity (float, optional, default=20.0)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let intensity = if args.len >= 2: args[1].f else: 20.0
  
  let ps = gParticleSystems[name]
  
  # Configure Matrix with hybrid mode
  ps.spatialDisplacementGraph = configureMatrixTrailGraph()
  ps.spatialColorGraph = configureMatrixTrailGraph()
  ps.effectMode = pemHybrid
  ps.effectFlags = ParticleEffectFlags(replaceChar: true, modulateColor: true)
  
  # Set basic parameters
  ps.emitRate = intensity
  ps.emitterShape = esLine  # Spawn across top of screen
  ps.velocityMin = (0.0, 8.0)
  ps.velocityMax = (0.0, 12.0)
  ps.lifeMin = 3.0
  ps.lifeMax = 6.0
  ps.chars = @["0", "1", "A", "B", "Z", "Ω", "∑", "π"]
  ps.colorMin = Color(r: 0, g: 255, b: 0)
  ps.colorMax = Color(r: 100, g: 255, b: 100)
  ps.gravity = 0.0
  ps.trailEnabled = true
  ps.trailMaxLength = 12
  ps.trailSpacing = 0.8
  ps.trailFade = true
  
  return valNil()

proc particleConfigureRippleField*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure ripple displacement field with static rain particles to displace
  ## Args: name (string)
  if args.len < 1 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let ps = gParticleSystems[name]
  
  # Configure as hybrid: particles + spatial displacement
  ps.spatialDisplacementGraph = configureRippleDisplacementGraph()
  ps.effectMode = pemHybrid  # Emit particles AND apply displacement
  ps.effectFlags = ParticleEffectFlags(displace: true)
  
  # Emit gentle rain to have something to displace
  ps.emitRate = 5.0
  ps.emitterShape = esLine
  ps.velocityMin = (0.0, 3.0)
  ps.velocityMax = (0.0, 5.0)
  ps.lifeMin = 8.0
  ps.lifeMax = 12.0
  ps.chars = @["·", "•", "○", "◦"]
  ps.colorMin = Color(r: 100, g: 150, b: 255)
  ps.colorMax = Color(r: 150, g: 200, b: 255)
  ps.gravity = 0.0
  ps.fadeOut = false
  
  return valNil()

proc particleConfigureCustomGraph*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Configure custom multi-force graph (gravity + wind + oscillation)
  ## Args: name (string), gravityStrength (float), windStrength (float)
  if args.len < 3 or not gParticleSystems.hasKey(args[0].s):
    return valNil()
  
  let name = args[0].s
  let gravityStr = args[1].f
  let windStr = args[2].f
  
  let ps = gParticleSystems[name]
  
  # For now, use simple parameters  (TODO: build actual graph)
  ps.effectMode = pemParticles
  
  # Set basic parameters
  ps.emitRate = 20.0
  ps.velocityMin = (-2.0, 0.0)
  ps.velocityMax = (2.0, 5.0)
  ps.lifeMin = 2.0
  ps.lifeMax = 4.0
  ps.chars = @[".", "o", "O", "@", "◉"]
  ps.colorMin = Color(r: 100, g: 200, b: 255)
  ps.colorMax = Color(r: 200, g: 255, b: 255)
  ps.gravity = gravityStr
  ps.windForce = (windStr, 0.0)
  
  return valNil()

# ================================================================
# REGISTRATION
# ================================================================

proc registerParticleBindings*(env: ref Env, appState: AppState) =
  ## Register all particle system functions with nimini runtime
  gAppStateRef = appState
  
  # Register simple setters via templates (executed at runtime, not module init)
  defSetter1Float(gParticleSystems, ParticleSystem, "particleSetGravity", "particles", "Set gravity", gravity)
  defSetter1Float(gParticleSystems, ParticleSystem, "particleSetTurbulence", "particles", "Set turbulence", turbulence)
  defSetter1Float(gParticleSystems, ParticleSystem, "particleSetDamping", "particles", "Set damping (air resistance)", damping)
  defSetter1Float(gParticleSystems, ParticleSystem, "particleSetEmitRate", "particles", "Set emission rate (particles per second)", emitRate)
  
  defSetter2Float(gParticleSystems, ParticleSystem, "particleSetWind", "particles", "Set wind force", windForce)
  defSetter2Float(gParticleSystems, ParticleSystem, "particleSetEmitterPos", "particles", "Set emitter position", emitterPos)
  defSetter2Float(gParticleSystems, ParticleSystem, "particleSetEmitterSize", "particles", "Set emitter size (for line/area shapes)", emitterSize)
  
  defSetter1String(gParticleSystems, ParticleSystem, "particleSetStickChar", "particles", "Set character to use when particles stick", stickChar)
  defSetter1Bool(gParticleSystems, ParticleSystem, "particleSetTrailEnabled", "particles", "Enable/disable particle trails", trailEnabled)
  defSetter1Int(gParticleSystems, ParticleSystem, "particleSetTrailLength", "particles", "Set maximum trail length (number of segments)", trailMaxLength)
  defSetter1Float(gParticleSystems, ParticleSystem, "particleSetTrailSpacing", "particles", "Set spacing between trail segments", trailSpacing)
  defSetter1Bool(gParticleSystems, ParticleSystem, "particleSetTrailFade", "particles", "Enable/disable trail fading", trailFade)
  
  defSetter1Float(gParticleSystems, ParticleSystem, "particleSetBounceElasticity", "particles", "Set bounce elasticity (0.0-1.0, energy retained on bounce)", bounceElasticity)
  defSetter1Bool(gParticleSystems, ParticleSystem, "particleSetFadeOut", "particles", "Enable/disable particle fade out over lifetime", fadeOut)
  defSetter1Bool(gParticleSystems, ParticleSystem, "particleSetColorInterpolation", "particles", "Enable/disable color interpolation from colorMin to colorMax over lifetime", colorInterpolation)
  
  # Register complex functions manually
  env.vars["particleInit"] = valNativeFunc(particleInit)
  env.vars["particleUpdate"] = valNativeFunc(particleUpdate)
  env.vars["particleRender"] = valNativeFunc(particleRender)
  env.vars["particleEmit"] = valNativeFunc(particleEmit)
  env.vars["particleClear"] = valNativeFunc(particleClear)
  env.vars["particleGetCount"] = valNativeFunc(particleGetCount)
  env.vars["particleCheckHit"] = valNativeFunc(particleCheckHit)
  
  env.vars["particleSetEmitterShape"] = valNativeFunc(particleSetEmitterShape)
  env.vars["particleSetVelocityRange"] = valNativeFunc(particleSetVelocityRange)
  env.vars["particleSetLifeRange"] = valNativeFunc(particleSetLifeRange)
  env.vars["particleSetCollision"] = valNativeFunc(particleSetCollision)
  env.vars["particleSetChars"] = valNativeFunc(particleSetChars)
  env.vars["particleSetBackgroundColor"] = valNativeFunc(particleSetBackgroundColor)
  env.vars["particleSetColorRange"] = valNativeFunc(particleSetColorRange)
  env.vars["particleSetTrailChars"] = valNativeFunc(particleSetTrailChars)
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
  
  # NEW: Graph-based configurations
  env.vars["particleConfigureVortex"] = valNativeFunc(particleConfigureVortex)
  env.vars["particleConfigureRadialExplosion"] = valNativeFunc(particleConfigureRadialExplosion)
  env.vars["particleConfigureMatrixHybrid"] = valNativeFunc(particleConfigureMatrixHybrid)
  env.vars["particleConfigureRippleField"] = valNativeFunc(particleConfigureRippleField)
  env.vars["particleConfigureCustomGraph"] = valNativeFunc(particleConfigureCustomGraph)

