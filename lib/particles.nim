## High-Performance Particle System for tStorie
##
## This module provides a native particle system capable of handling 1000+
## particles at 60 FPS. It handles the performance-critical iteration bottleneck
## while exposing simple mutable parameters for environmental control.
##
## Features:
## - Native bulk update/render (100x faster than scripted iteration)
## - Mutable environmental parameters (gravity, wind, turbulence, damping)
## - Collision detection with buffer queries
## - Configurable collision responses (stick, bounce, destroy)
## - Built-in emitter behaviors (rain, snow, fire, sparkles)
## - Particle recycling for efficient memory management
##
## Usage:
##   var sys = initParticleSystem(maxParticles = 1000)
##   sys.gravity = 9.8
##   sys.windForce = (2.0, 0.0)
##   sys.collisionEnabled = true
##   sys.collisionResponse = crStick
##   sys.update(dt)
##   sys.render(layer)
##
## NIMINI BINDINGS:
## No functions are auto-exposed due to registry pattern.
## The native API takes ParticleSystem objects directly, but the nimini API
## uses string names with registry lookup (e.g., "rain", "fire").
## This avoids passing ref objects through the Value system.
## See particles_bindings.nim for the registry-based API.

import std/[math, random, tables]

when not declared(Color):
  import ../src/types
  import ../src/layers
import graph  # Import the unified node graph system

# ================================================================
# TYPES
# ================================================================

type
  Vec2* = tuple[x, y: float]
  
  TrailSegment* = object
    x*, y*: float          # Position
    char*: string          # Display character
    color*: Color          # Display color
    age*: float            # Age of this segment (for fading)
  
  ParticleDrawMode* = enum
    pdmReplace,      ## Replace entire cell (char + all colors) - default
    pdmBackground,   ## Change background only, preserve char + foreground
    pdmForeground,   ## Change foreground only, preserve char + background
    pdmCharacter     ## Change character only, preserve all colors
  
  CollisionResponse* = enum
    crNone,        ## Pass through cells (no collision)
    crBounce,      ## Reverse velocity on collision
    crStick,       ## Stop moving and change character
    crDestroy      ## Remove particle on collision
  
  ParticleEffectMode* = enum
    pemParticles,        ## Traditional particles (dots moving)
    pemSpatialField,     ## Evaluate graph per pixel (displacement/color field)
    pemHybrid            ## Both particles AND spatial effects
  
  ParticleEffectFlags* = object
    ## Combinable flags for what particles affect
    replaceChar*: bool       ## Replace cell character
    modulateColor*: bool     ## Affect cell foreground color
    modulateBg*: bool        ## Affect cell background color
    displace*: bool          ## Displace cell position
    emit*: bool              ## Emit new particles based on field
  
  Particle* = object
    x*, y*: float          # Position
    vx*, vy*: float        # Velocity
    life*: float           # Remaining lifetime
    maxLife*: float        # Initial lifetime (for fade calculations)
    char*: string          # Display character
    color*: Color          # Display color
    spawnColor*: Color     # Initial color for interpolation
    rotation*: float       # Optional rotation (for future use)
    rotationSpeed*: float  # Optional angular velocity
    active*: bool          # Whether particle is alive
    trail*: seq[TrailSegment]  # Trail segments following this particle
    trailLength*: int      # Current trail length
  
  EmitterShape* = enum
    esPoint,       ## Emit from single point
    esLine,        ## Emit along a line
    esCircle,      ## Emit from circle perimeter
    esRectangle,   ## Emit from rectangle edges
    esArea         ## Emit from filled area
  
  ParticleSystem* = ref object
    particles*: seq[Particle]
    maxParticles*: int
    activeCount: int
    
    # Environmental parameters (mutable at runtime - LEGACY)
    gravity*: float
    windForce*: Vec2
    turbulence*: float
    damping*: float
    
    # NEW: Graph-based behavior (replaces hardcoded parameters)
    effectMode*: ParticleEffectMode
    effectFlags*: ParticleEffectFlags
    
    # Graphs for different aspects
    motionGraph*: Graph          ## Controls particle velocity/position
    colorGraph*: Graph           ## Controls particle color over lifetime
    characterGraph*: Graph       ## Selects character based on particle state
    emissionGraph*: Graph        ## Controls emission rate/pattern
    lifetimeGraph*: Graph        ## Controls particle lifetime/fading
    
    # Spatial field graphs (for displacement effects)
    spatialDisplacementGraph*: Graph   ## Displacement field for buffer
    spatialColorGraph*: Graph          ## Color modulation field for buffer
    
    # Graph evaluation contexts (populated from particle state)
    particleContext*: EvalContext      ## Context for per-particle evaluation
    spatialContext*: EvalContext       ## Context for per-pixel evaluation
    
    # Emitter settings
    emitterPos*: Vec2
    emitterShape*: EmitterShape
    emitterSize*: Vec2        # Width/height or radius
    emitRate*: float          # Particles per second
    emitAccumulator: float    # Internal timing
    
    # Particle spawn parameters
    velocityMin*: Vec2
    velocityMax*: Vec2
    lifeMin*: float
    lifeMax*: float
    chars*: seq[string]       # Random character pool
    colorMin*: Color
    colorMax*: Color
    
    # Collision detection
    collisionEnabled*: bool
    collisionResponse*: CollisionResponse
    collisionBuffer*: ptr TermBuffer  # Buffer to query for collisions
    stickChar*: string        # Character to use when stuck
    bounceElasticity*: float  # Energy retained on bounce (0-1)
    
    # Trail settings
    trailEnabled*: bool       # Whether to spawn trails
    trailMaxLength*: int      # Maximum segments per trail
    trailSpacing*: float      # Distance between segments
    trailFade*: bool          # Whether trail fades with age
    trailChars*: seq[string]  # Character pool for trail segments
    
    # Rendering
    fadeOut*: bool            # Fade alpha based on life
    colorInterpolation*: bool # Interpolate from colorMin to colorMax over lifetime
    drawMode*: ParticleDrawMode  # How particles affect cells
    layerTarget*: ptr Layer   # Target layer for rendering
    backgroundColor*: Color   # Background color for particles (theme-aware)
    
    # Frame counter for graph evaluation
    frame*: int

# ================================================================
# INITIALIZATION
# ================================================================

proc initParticleSystem*(maxParticles: int = 1000): ParticleSystem =
  ## Create a new particle system with specified capacity
  
  # Initialize random number generator (critical for WASM!)
  randomize()
  
  result = ParticleSystem(
    particles: newSeq[Particle](maxParticles),
    maxParticles: maxParticles,
    activeCount: 0,
    
    # Default environmental parameters
    gravity: 0.0,
    windForce: (0.0, 0.0),
    turbulence: 0.0,
    damping: 1.0,
    
    # NEW: Default graph-based settings
    effectMode: pemParticles,  # Default to traditional particles
    effectFlags: ParticleEffectFlags(
      replaceChar: false,
      modulateColor: false,
      modulateBg: false,
      displace: false,
      emit: false
    ),
    
    # Initialize as nil (legacy behavior until graphs are set)
    motionGraph: nil,
    colorGraph: nil,
    characterGraph: nil,
    emissionGraph: nil,
    lifetimeGraph: nil,
    spatialDisplacementGraph: nil,
    spatialColorGraph: nil,
    
    # Initialize evaluation contexts
    particleContext: EvalContext(
      frame: 0,
      deltaTime: 1.0 / 60.0,
      sampleRate: 44100,
      width: 80,
      height: 24,
      custom: initTable[string, float]()
    ),
    spatialContext: EvalContext(
      frame: 0,
      deltaTime: 1.0 / 60.0,
      sampleRate: 44100,
      width: 80,
      height: 24,
      custom: initTable[string, float]()
    ),
    
    # Default emitter
    emitterPos: (0.0, 0.0),
    emitterShape: esPoint,
    emitterSize: (1.0, 1.0),
    emitRate: 10.0,
    emitAccumulator: 0.0,
    
    # Default spawn parameters
    velocityMin: (0.0, -10.0),
    velocityMax: (0.0, -5.0),
    lifeMin: 1.0,
    lifeMax: 2.0,
    chars: @["•", "·", "°"],
    colorMin: Color(r: 255, g: 255, b: 255),
    colorMax: Color(r: 255, g: 255, b: 255),
    
    # Default collision settings
    collisionEnabled: false,
    collisionResponse: crNone,
    collisionBuffer: nil,
    stickChar: ".",
    bounceElasticity: 0.5,
    
    # Default trail settings
    trailEnabled: false,
    trailMaxLength: 5,
    trailSpacing: 1.0,
    trailFade: true,
    trailChars: @[],
    
    # Default rendering
    fadeOut: true,
    colorInterpolation: false,
    drawMode: pdmReplace,  # Default to full cell replacement
    layerTarget: nil,
    backgroundColor: rgb(0, 0, 0),  # Default to black
    
    # Frame counter
    frame: 0
  )
  
  # Initialize all particles as inactive
  for i in 0 ..< maxParticles:
    result.particles[i].active = false
    result.particles[i].trail = @[]
    result.particles[i].trailLength = 0

# ================================================================
# PARTICLE EMISSION
# ================================================================

proc findInactiveParticle(ps: ParticleSystem): int =
  ## Find first inactive particle slot, or -1 if all active
  for i in 0 ..< ps.maxParticles:
    if not ps.particles[i].active:
      return i
  return -1

proc randomInRange(min, max: float): float =
  ## Random float between min and max
  min + rand(1.0) * (max - min)

proc randomVec2(minVec, maxVec: Vec2): Vec2 =
  ## Random Vec2 with each component in range
  (randomInRange(minVec.x, maxVec.x), randomInRange(minVec.y, maxVec.y))

proc randomColor(minCol, maxCol: Color): Color =
  ## Random color with each component in range
  Color(
    r: uint8(randomInRange(float(minCol.r), float(maxCol.r))),
    g: uint8(randomInRange(float(minCol.g), float(maxCol.g))),
    b: uint8(randomInRange(float(minCol.b), float(maxCol.b)))
  )

proc getEmitPosition(ps: ParticleSystem): Vec2 =
  ## Get spawn position based on emitter shape
  case ps.emitterShape
  of esPoint:
    return ps.emitterPos
  
  of esLine:
    let t = rand(1.0)
    return (
      ps.emitterPos.x + t * ps.emitterSize.x,
      ps.emitterPos.y + t * ps.emitterSize.y
    )
  
  of esCircle:
    let angle = rand(TAU)
    let radius = ps.emitterSize.x
    return (
      ps.emitterPos.x + cos(angle) * radius,
      ps.emitterPos.y + sin(angle) * radius
    )
  
  of esRectangle:
    let side = rand(4)
    let t = rand(1.0)
    case side
    of 0: # Top
      return (ps.emitterPos.x + t * ps.emitterSize.x, ps.emitterPos.y)
    of 1: # Right
      return (ps.emitterPos.x + ps.emitterSize.x, ps.emitterPos.y + t * ps.emitterSize.y)
    of 2: # Bottom
      return (ps.emitterPos.x + t * ps.emitterSize.x, ps.emitterPos.y + ps.emitterSize.y)
    else: # Left
      return (ps.emitterPos.x, ps.emitterPos.y + t * ps.emitterSize.y)
  
  of esArea:
    return (
      ps.emitterPos.x + rand(1.0) * ps.emitterSize.x,
      ps.emitterPos.y + rand(1.0) * ps.emitterSize.y
    )

proc emit*(ps: ParticleSystem, count: int = 1) =
  ## Manually emit a specific number of particles
  for i in 0 ..< count:
    let idx = ps.findInactiveParticle()
    if idx < 0:
      break  # No free slots
    
    # Safety check for empty chars array
    if ps.chars.len == 0:
      continue
    
    let pos = ps.getEmitPosition()
    let vel = randomVec2(ps.velocityMin, ps.velocityMax)
    let life = randomInRange(ps.lifeMin, ps.lifeMax)
    # Safe array access - use modulo to ensure valid index
    let charIdx = if ps.chars.len > 0: rand(ps.chars.len - 1) else: 0
    let char = ps.chars[charIdx]
    let color = randomColor(ps.colorMin, ps.colorMax)
    
    ps.particles[idx] = Particle(
      x: pos.x,
      y: pos.y,
      vx: vel.x,
      vy: vel.y,
      life: life,
      maxLife: life,
      char: char,
      color: color,
      spawnColor: color,  # Store initial color for interpolation
      rotation: 0.0,
      rotationSpeed: 0.0,
      active: true,
      trail: @[],
      trailLength: 0
    )
    
    # Initialize trail if enabled
    if ps.trailEnabled and ps.trailMaxLength > 0:
      ps.particles[idx].trail = newSeq[TrailSegment](ps.trailMaxLength)
      for j in 0 ..< ps.trailMaxLength:
        ps.particles[idx].trail[j] = TrailSegment(
          x: pos.x,
          y: pos.y,
          char: if ps.trailChars.len > 0: ps.trailChars[rand(ps.trailChars.len - 1)] else: char,
          color: color,
          age: 0.0
        )
    
    inc ps.activeCount

# ================================================================
# PARTICLE UPDATE (NATIVE - PERFORMANCE CRITICAL)
# ================================================================

proc simpleNoise(x, y: float): float =
  ## Simple noise function for turbulence
  ## Returns value in range -1 to 1
  ## Uses modulo to prevent overflow in WASM
  let ix = int(x * 0.1) mod 10000  # Prevent huge values
  let iy = int(y * 0.1) mod 10000
  # Use smaller multipliers to prevent overflow
  let seed = ((ix * 37471) + (iy * 66827)) xor 101393
  result = float(seed and 0xFFFF) / 32768.0 - 1.0

proc update*(ps: ParticleSystem, dt: float) =
  ## Update all particles (native tight loop for performance)
  
  # Increment frame counter
  inc ps.frame
  ps.particleContext.frame = ps.frame
  ps.particleContext.deltaTime = dt
  ps.spatialContext.frame = ps.frame
  ps.spatialContext.deltaTime = dt
  
  # Auto-emission based on emit rate
  if ps.emitRate > 0.0:
    ps.emitAccumulator += dt * ps.emitRate
    while ps.emitAccumulator >= 1.0:
      ps.emit(1)
      ps.emitAccumulator -= 1.0
  
  # Read environmental parameters once (not per particle)
  let grav = ps.gravity
  let wind = ps.windForce
  let turb = ps.turbulence
  let damp = ps.damping
  let checkCollision = ps.collisionEnabled and not ps.collisionBuffer.isNil
  let useMotionGraph = not ps.motionGraph.isNil
  let useColorGraph = not ps.colorGraph.isNil
  let useCharacterGraph = not ps.characterGraph.isNil
  
  # Update all active particles in tight loop
  var newActiveCount = 0
  for i in 0 ..< ps.maxParticles:
    if not ps.particles[i].active:
      continue
    
    # NEW: If motion graph exists, use it instead of legacy forces
    if useMotionGraph:
      # Populate particle context
      ps.particleContext.custom["px"] = ps.particles[i].x
      ps.particleContext.custom["py"] = ps.particles[i].y
      ps.particleContext.custom["pvx"] = ps.particles[i].vx
      ps.particleContext.custom["pvy"] = ps.particles[i].vy
      let age = ps.particles[i].maxLife - ps.particles[i].life
      ps.particleContext.custom["page"] = age
      ps.particleContext.custom["plife"] = ps.particles[i].life
      ps.particleContext.custom["plifeFraction"] = age / ps.particles[i].maxLife
      ps.particleContext.time = float(ps.frame) / 60.0  # Assume 60fps
      
      # Evaluate motion graph
      let outputs = ps.motionGraph.evaluate(ps.particleContext)
      if outputs.len > 0:
        # Apply force/velocity delta - handle both edControl and edVisual domains
        if outputs[0].domain == edControl:
          ps.particles[i].vy += outputs[0].controlValue * dt
        elif outputs[0].domain == edVisual:
          # Visual values are in range ~-1000..1000, convert to velocity
          ps.particles[i].vy += (float(outputs[0].visualValue) / 1000.0) * dt
        # Check for second output for horizontal component
        if outputs.len > 1:
          if outputs[1].domain == edControl:
            ps.particles[i].vx += outputs[1].controlValue * dt
          elif outputs[1].domain == edVisual:
            ps.particles[i].vx += (float(outputs[1].visualValue) / 1000.0) * dt
    else:
      # LEGACY: Use hardcoded gravity + turbulence
      # Direct access instead of pointer (safer for WASM)
      # Apply environmental forces
      ps.particles[i].vx += wind.x * dt
      ps.particles[i].vy += (wind.y + grav) * dt
      
      # Apply turbulence (noise-based)
      if turb > 0.0:
        let noise = simpleNoise(ps.particles[i].x, ps.particles[i].y)
        ps.particles[i].vx += noise * turb * dt
        ps.particles[i].vy += noise * turb * dt * 0.5  # Less vertical turbulence
    
    # Apply damping (air resistance)
    if damp != 1.0:
      ps.particles[i].vx *= damp
      ps.particles[i].vy *= damp
    
    # Integration
    let newX = ps.particles[i].x + ps.particles[i].vx * dt
    let newY = ps.particles[i].y + ps.particles[i].vy * dt
    
    # Collision detection
    var collided = false
    if checkCollision and not ps.collisionBuffer.isNil:
      let ix = int(newX)
      let iy = int(newY)
      if ix >= 0 and ix < ps.collisionBuffer.width and 
         iy >= 0 and iy < ps.collisionBuffer.height:
        let cell = ps.collisionBuffer[].getCell(ix, iy)
        if cell.ch != " " and cell.ch != "":
          collided = true
          
          case ps.collisionResponse
          of crStick:
            # Stop moving and change character
            ps.particles[i].vx = 0.0
            ps.particles[i].vy = 0.0
            ps.particles[i].char = ps.stickChar
          
          of crBounce:
            # Reverse velocity with elasticity
            ps.particles[i].vy *= -ps.bounceElasticity
            ps.particles[i].vx *= ps.bounceElasticity
          
          of crDestroy:
            # Kill particle
            ps.particles[i].life = 0.0
          
          of crNone:
            discard
    
    # Update position if no stick collision
    if not collided or ps.collisionResponse != crStick:
      ps.particles[i].x = newX
      ps.particles[i].y = newY
    
    # Update trail if enabled
    if ps.trailEnabled and ps.particles[i].trail.len > 0:
      # Shift trail segments backward (each follows the one ahead)
      for j in countdown(ps.particles[i].trail.len - 1, 1):
        let prevIdx = j - 1
        let dist = sqrt(
          (ps.particles[i].trail[prevIdx].x - ps.particles[i].trail[j].x) * 
          (ps.particles[i].trail[prevIdx].x - ps.particles[i].trail[j].x) +
          (ps.particles[i].trail[prevIdx].y - ps.particles[i].trail[j].y) * 
          (ps.particles[i].trail[prevIdx].y - ps.particles[i].trail[j].y)
        )
        
        # Only update if segments are far enough apart
        if dist > ps.trailSpacing:
          ps.particles[i].trail[j].x = ps.particles[i].trail[prevIdx].x
          ps.particles[i].trail[j].y = ps.particles[i].trail[prevIdx].y
          ps.particles[i].trail[j].age += dt
          
          # Update trail character if pool exists
          if ps.trailChars.len > 0:
            ps.particles[i].trail[j].char = ps.trailChars[rand(ps.trailChars.len - 1)]
      
      # Update head segment to follow particle
      let headDist = sqrt(
        (ps.particles[i].x - ps.particles[i].trail[0].x) * 
        (ps.particles[i].x - ps.particles[i].trail[0].x) +
        (ps.particles[i].y - ps.particles[i].trail[0].y) * 
        (ps.particles[i].y - ps.particles[i].trail[0].y)
      )
      
      if headDist > ps.trailSpacing:
        ps.particles[i].trail[0].x = ps.particles[i].x
        ps.particles[i].trail[0].y = ps.particles[i].y
        ps.particles[i].trail[0].char = ps.particles[i].char
        ps.particles[i].trail[0].color = ps.particles[i].color
        ps.particles[i].trail[0].age = 0.0
    
    # Update lifetime
    ps.particles[i].life -= dt
    
    # Deactivate dead particles
    if ps.particles[i].life <= 0.0:
      ps.particles[i].active = false
    else:
      inc newActiveCount
  
  ps.activeCount = newActiveCount

# ================================================================
# SPATIAL EFFECTS (PHASE 2)
# ================================================================

proc applyDisplacementField*(ps: ParticleSystem, buffer: var TermBuffer) =
  ## Apply spatial displacement graph to entire buffer
  if ps.spatialDisplacementGraph.isNil:
    return
  
  # Create temporary buffer to sample from (avoid feedback loops)
  var tempCells = newSeq[tuple[ch: string, style: Style]](buffer.width * buffer.height)
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      tempCells[y * buffer.width + x] = buffer.getCell(x, y)
  
  # Apply displacement field
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      ps.spatialContext.x = x
      ps.spatialContext.y = y
      ps.spatialContext.width = buffer.width
      ps.spatialContext.height = buffer.height
      
      let outputs = ps.spatialDisplacementGraph.evaluate(ps.spatialContext)
      if outputs.len > 0:
        # Get displacement - spatial graphs output in edVisual domain
        let dx = if outputs[0].domain == edVisual:
          outputs[0].visualValue
        elif outputs[0].domain == edControl:
          int(outputs[0].controlValue)
        else:
          0
        
        let dy = if outputs.len > 1:
          if outputs[1].domain == edVisual:
            outputs[1].visualValue
          elif outputs[1].domain == edControl:
            int(outputs[1].controlValue)
          else:
            0
        else:
          0
        
        # Sample from displaced position
        let sourceX = clamp(x + dx, 0, buffer.width - 1)
        let sourceY = clamp(y + dy, 0, buffer.height - 1)
        let sourceCell = tempCells[sourceY * buffer.width + sourceX]
        
        # Write to current position
        buffer.write(x, y, sourceCell.ch, sourceCell.style)

proc applyColorField*(ps: ParticleSystem, buffer: var TermBuffer) =
  ## Apply spatial color modulation graph to buffer
  if ps.spatialColorGraph.isNil:
    return
  
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      ps.spatialContext.x = x
      ps.spatialContext.y = y
      ps.spatialContext.width = buffer.width
      ps.spatialContext.height = buffer.height
      
      let outputs = ps.spatialColorGraph.evaluate(ps.spatialContext)
      if outputs.len > 0 and outputs[0].domain == edVisual:
        # Get existing cell
        let cell = buffer.getCell(x, y)
        
        # Apply color modulation
        let newStyle = Style(
          fg: Color(
            r: outputs[0].visualColor.r,
            g: outputs[0].visualColor.g,
            b: outputs[0].visualColor.b
          ),
          bg: cell.style.bg,
          bold: cell.style.bold,
          underline: cell.style.underline,
          italic: cell.style.italic,
          dim: cell.style.dim
        )
        buffer.write(x, y, cell.ch, newStyle)

# ================================================================
# PARTICLE RENDERING
# ================================================================

proc render*(ps: ParticleSystem, layer: ptr Layer) =
  ## Render all active particles to a layer (Phase 3: supports effect modes/flags)
  if layer.isNil:
    return
  
  var buf = layer.buffer.addr
  
  # NEW Phase 3: Apply spatial effects first (if enabled)
  if ps.effectMode in {pemSpatialField, pemHybrid}:
    if ps.effectFlags.displace:
      ps.applyDisplacementField(buf[])
    
    if ps.effectFlags.modulateColor:
      ps.applyColorField(buf[])
  
  # Render particles (if mode includes them)
  if ps.effectMode in {pemParticles, pemHybrid}:
    for i in 0 ..< ps.maxParticles:
      if not ps.particles[i].active:
        continue
      
      # Render trail first (so particle appears on top)
      if ps.trailEnabled and ps.particles[i].trail.len > 0:
        for j in countdown(ps.particles[i].trail.len - 1, 0):
          let segment = ps.particles[i].trail[j]
          let ix = int(segment.x)
          let iy = int(segment.y)
          
          # Bounds check
          if ix < 0 or ix >= buf.width or iy < 0 or iy >= buf.height:
            continue
          
          # Calculate fade based on segment position and age
          var color = segment.color
          if ps.trailFade:
            # Fade based on position in trail (further = dimmer)
            let positionFade = 1.0 - (float(j) / float(ps.particles[i].trail.len))
            color.r = uint8(float(color.r) * positionFade)
            color.g = uint8(float(color.g) * positionFade)
            color.b = uint8(float(color.b) * positionFade)
          
          # Render trail segment based on draw mode
          case ps.drawMode
          of pdmReplace:
            let style = Style(fg: color, bg: ps.backgroundColor, bold: false, underline: false, italic: false, dim: false)
            buf[].write(ix, iy, segment.char, style)
          
          of pdmBackground:
            let existingCell = buf[].getCell(ix, iy)
            let style = Style(
              fg: existingCell.style.fg,
              bg: color,
              bold: existingCell.style.bold,
              underline: existingCell.style.underline,
              italic: existingCell.style.italic,
              dim: existingCell.style.dim
            )
            buf[].write(ix, iy, existingCell.ch, style)
          
          of pdmForeground:
            let existingCell = buf[].getCell(ix, iy)
            let style = Style(
              fg: color,
              bg: existingCell.style.bg,
              bold: existingCell.style.bold,
              underline: existingCell.style.underline,
              italic: existingCell.style.italic,
              dim: existingCell.style.dim
            )
            buf[].write(ix, iy, existingCell.ch, style)
          
          of pdmCharacter:
            let existingCell = buf[].getCell(ix, iy)
            buf[].write(ix, iy, segment.char, existingCell.style)
      
      # Render main particle
      let ix = int(ps.particles[i].x)
      let iy = int(ps.particles[i].y)
    
      # Bounds check
      if ix < 0 or ix >= buf.width or iy < 0 or iy >= buf.height:
        continue
      
      # NEW Phase 3: Evaluate color graph if available
      var color = ps.particles[i].color
      if not ps.colorGraph.isNil:
        ps.particleContext.custom["px"] = ps.particles[i].x
        ps.particleContext.custom["py"] = ps.particles[i].y
        ps.particleContext.custom["pvx"] = ps.particles[i].vx
        ps.particleContext.custom["pvy"] = ps.particles[i].vy
        let age = ps.particles[i].maxLife - ps.particles[i].life
        ps.particleContext.custom["page"] = age
        ps.particleContext.custom["plife"] = ps.particles[i].life
        ps.particleContext.custom["plifeFraction"] = age / ps.particles[i].maxLife
        
        let outputs = ps.colorGraph.evaluate(ps.particleContext)
        if outputs.len > 0 and outputs[0].domain == edVisual:
          color = Color(
            r: outputs[0].visualColor.r,
            g: outputs[0].visualColor.g,
            b: outputs[0].visualColor.b
          )
      else:
        # LEGACY: Apply color interpolation if enabled
        if ps.colorInterpolation:
          let t = 1.0 - (ps.particles[i].life / ps.particles[i].maxLife)  # 0 at birth, 1 at death
          # Lerp from spawnColor (colorMin) to colorMax
          color.r = uint8(float(ps.particles[i].spawnColor.r) * (1.0 - t) + float(ps.colorMax.r) * t)
          color.g = uint8(float(ps.particles[i].spawnColor.g) * (1.0 - t) + float(ps.colorMax.g) * t)
          color.b = uint8(float(ps.particles[i].spawnColor.b) * (1.0 - t) + float(ps.colorMax.b) * t)
      
      # Apply fade out if enabled (both graph and legacy modes)
      if ps.fadeOut:
        let alpha = ps.particles[i].life / ps.particles[i].maxLife
        color.r = uint8(float(color.r) * alpha)
        color.g = uint8(float(color.g) * alpha)
        color.b = uint8(float(color.b) * alpha)
      
      # NEW Phase 3: Evaluate character graph if available
      var particleChar = ps.particles[i].char
      if not ps.characterGraph.isNil:
        let outputs = ps.characterGraph.evaluate(ps.particleContext)
        if outputs.len > 0:
          let idx = clamp(int(outputs[0].controlValue), 0, ps.chars.len - 1)
          if ps.chars.len > 0:
            particleChar = ps.chars[idx]
      
      # Render based on draw mode
      case ps.drawMode
      of pdmReplace:
        # Replace entire cell (default behavior)
        let style = Style(fg: color, bg: ps.backgroundColor, bold: false, underline: false, italic: false, dim: false)
        buf[].write(ix, iy, particleChar, style)
      
      of pdmBackground:
        # Change background only, preserve char + foreground
        let existingCell = buf[].getCell(ix, iy)
        let style = Style(
          fg: existingCell.style.fg,
          bg: color,
          bold: existingCell.style.bold,
          underline: existingCell.style.underline,
          italic: existingCell.style.italic,
          dim: existingCell.style.dim
        )
        buf[].write(ix, iy, existingCell.ch, style)
      
      of pdmForeground:
        # Change foreground only, preserve char + background
        let existingCell = buf[].getCell(ix, iy)
        let style = Style(
          fg: color,
          bg: existingCell.style.bg,
          bold: existingCell.style.bold,
          underline: existingCell.style.underline,
          italic: existingCell.style.italic,
          dim: existingCell.style.dim
        )
        buf[].write(ix, iy, existingCell.ch, style)
      
      of pdmCharacter:
        # Change character only, preserve all colors
        let existingCell = buf[].getCell(ix, iy)
        buf[].write(ix, iy, particleChar, existingCell.style)

proc render*(ps: ParticleSystem, buffer: var TermBuffer) =
  ## Render all active particles directly to a buffer
  for i in 0 ..< ps.maxParticles:
    if not ps.particles[i].active:
      continue
    
    # Render trail first (so particle appears on top)
    if ps.trailEnabled and ps.particles[i].trail.len > 0:
      for j in countdown(ps.particles[i].trail.len - 1, 0):
        let segment = ps.particles[i].trail[j]
        let ix = int(segment.x)
        let iy = int(segment.y)
        
        # Bounds check
        if ix < 0 or ix >= buffer.width or iy < 0 or iy >= buffer.height:
          continue
        
        # Calculate fade based on segment position
        var color = segment.color
        if ps.trailFade:
          let positionFade = 1.0 - (float(j) / float(ps.particles[i].trail.len))
          color.r = uint8(float(color.r) * positionFade)
          color.g = uint8(float(color.g) * positionFade)
          color.b = uint8(float(color.b) * positionFade)
        
        # Render trail segment based on draw mode
        case ps.drawMode
        of pdmReplace:
          let style = Style(fg: color, bg: ps.backgroundColor, bold: false, underline: false, italic: false, dim: false)
          buffer.write(ix, iy, segment.char, style)
        
        of pdmBackground:
          let existingCell = buffer.getCell(ix, iy)
          let style = Style(
            fg: existingCell.style.fg,
            bg: color,
            bold: existingCell.style.bold,
            underline: existingCell.style.underline,
            italic: existingCell.style.italic,
            dim: existingCell.style.dim
          )
          buffer.write(ix, iy, existingCell.ch, style)
        
        of pdmForeground:
          let existingCell = buffer.getCell(ix, iy)
          let style = Style(
            fg: color,
            bg: existingCell.style.bg,
            bold: existingCell.style.bold,
            underline: existingCell.style.underline,
            italic: existingCell.style.italic,
            dim: existingCell.style.dim
          )
          buffer.write(ix, iy, existingCell.ch, style)
        
        of pdmCharacter:
          let existingCell = buffer.getCell(ix, iy)
          buffer.write(ix, iy, segment.char, existingCell.style)
    
    # Render main particle
    let ix = int(ps.particles[i].x)
    let iy = int(ps.particles[i].y)
    
    # Bounds check
    if ix < 0 or ix >= buffer.width or iy < 0 or iy >= buffer.height:
      continue
    
    # Calculate color with optional interpolation and fade
    var color = ps.particles[i].color
    
    # Apply color interpolation if enabled
    if ps.colorInterpolation:
      let t = 1.0 - (ps.particles[i].life / ps.particles[i].maxLife)  # 0 at birth, 1 at death
      # Lerp from spawnColor (colorMin) to colorMax
      color.r = uint8(float(ps.particles[i].spawnColor.r) * (1.0 - t) + float(ps.colorMax.r) * t)
      color.g = uint8(float(ps.particles[i].spawnColor.g) * (1.0 - t) + float(ps.colorMax.g) * t)
      color.b = uint8(float(ps.particles[i].spawnColor.b) * (1.0 - t) + float(ps.colorMax.b) * t)
    
    # Apply fade out if enabled
    if ps.fadeOut:
      let alpha = ps.particles[i].life / ps.particles[i].maxLife
      color.r = uint8(float(color.r) * alpha)
      color.g = uint8(float(color.g) * alpha)
      color.b = uint8(float(color.b) * alpha)
    
    # Render based on draw mode
    case ps.drawMode
    of pdmReplace:
      # Replace entire cell (default behavior)
      let style = Style(fg: color, bg: ps.backgroundColor, bold: false, underline: false, italic: false, dim: false)
      buffer.write(ix, iy, ps.particles[i].char, style)
    
    of pdmBackground:
      # Change background only, preserve char + foreground
      let existingCell = buffer.getCell(ix, iy)
      let style = Style(
        fg: existingCell.style.fg,
        bg: color,
        bold: existingCell.style.bold,
        underline: existingCell.style.underline,
        italic: existingCell.style.italic,
        dim: existingCell.style.dim
      )
      buffer.write(ix, iy, existingCell.ch, style)
    
    of pdmForeground:
      # Change foreground only, preserve char + background
      let existingCell = buffer.getCell(ix, iy)
      let style = Style(
        fg: color,
        bg: existingCell.style.bg,
        bold: existingCell.style.bold,
        underline: existingCell.style.underline,
        italic: existingCell.style.italic,
        dim: existingCell.style.dim
      )
      buffer.write(ix, iy, existingCell.ch, style)
    
    of pdmCharacter:
      # Change character only, preserve all colors
      let existingCell = buffer.getCell(ix, iy)
      buffer.write(ix, iy, ps.particles[i].char, existingCell.style)

# ================================================================
# UTILITY FUNCTIONS
# ================================================================

proc clear*(ps: ParticleSystem) =
  ## Deactivate all particles
  for i in 0 ..< ps.maxParticles:
    ps.particles[i].active = false
  ps.activeCount = 0
  ps.emitAccumulator = 0.0

proc getActiveCount*(ps: ParticleSystem): int =
  ## Get number of currently active particles
  ps.activeCount

proc isFull*(ps: ParticleSystem): bool =
  ## Check if particle system is at capacity
  ps.activeCount >= ps.maxParticles

# ================================================================
# PRESET EMITTERS
# ================================================================

proc configureRain*(ps: ParticleSystem, intensity: float = 50.0) =
  ## Configure system for rain effect
  ps.emitRate = intensity
  ps.emitterShape = esLine
  ps.velocityMin = (0.0, 15.0)
  ps.velocityMax = (0.0, 25.0)
  ps.lifeMin = 2.0
  ps.lifeMax = 4.0
  ps.chars = @["|", "¦", "│"]
  ps.colorMin = Color(r: 100, g: 150, b: 255)
  ps.colorMax = Color(r: 150, g: 200, b: 255)
  ps.gravity = 20.0
  ps.windForce = (0.0, 0.0)
  ps.damping = 0.98
  ps.fadeOut = false
  ps.drawMode = pdmReplace  # Use default mode for rain characters

proc configureSnow*(ps: ParticleSystem, intensity: float = 30.0) =
  ## Configure system for snow effect
  ps.emitRate = intensity
  ps.emitterShape = esLine
  ps.velocityMin = (-1.0, 2.0)
  ps.velocityMax = (1.0, 5.0)
  ps.lifeMin = 5.0
  ps.lifeMax = 10.0
  ps.chars = @["*", "❄", "·", "•"]
  ps.colorMin = Color(r: 240, g: 240, b: 255)
  ps.colorMax = Color(r: 255, g: 255, b: 255)
  ps.gravity = 2.0
  ps.windForce = (1.0, 0.0)
  ps.damping = 0.99
  ps.fadeOut = false
  ps.drawMode = pdmReplace  # Use default mode for snow characters
  ps.collisionEnabled = true
  ps.collisionResponse = crStick
  ps.stickChar = "."

proc configureFire*(ps: ParticleSystem, intensity: float = 100.0) =
  ## Configure system for fire effect
  ps.emitRate = intensity
  ps.emitterShape = esLine
  ps.velocityMin = (-2.0, -8.0)
  ps.velocityMax = (2.0, -4.0)
  ps.lifeMin = 0.3
  ps.lifeMax = 1.0
  ps.chars = @["▪", "▫", "·", "˙", "▴", "▵"]
  ps.colorMin = Color(r: 255, g: 100, b: 0)
  ps.colorMax = Color(r: 255, g: 200, b: 0)
  ps.gravity = -5.0  # Negative gravity (rises)
  ps.turbulence = 3.0
  ps.damping = 0.95
  ps.fadeOut = true
  ps.drawMode = pdmReplace  # Use default mode for fire particles
  ps.collisionEnabled = false  # Fire doesn't collide
  ps.collisionResponse = crNone

proc configureSparkles*(ps: ParticleSystem, intensity: float = 20.0) =
  ## Configure system for sparkle/star effect
  ps.emitRate = intensity
  ps.emitterShape = esPoint
  ps.velocityMin = (-5.0, -5.0)
  ps.velocityMax = (5.0, 5.0)
  ps.lifeMin = 0.5
  ps.lifeMax = 1.5
  ps.chars = @["*", "✦", "✧", "·", "+", "×"]
  ps.colorMin = Color(r: 255, g: 200, b: 100)
  ps.colorMax = Color(r: 255, g: 255, b: 255)
  ps.gravity = 0.0
  ps.damping = 0.92
  ps.fadeOut = true
  ps.drawMode = pdmReplace  # Use default mode for sparkles

proc configureExplosion*(ps: ParticleSystem) =
  ## Configure for one-shot explosion (use ps.emit(50) after)
  ps.emitRate = 0.0  # Manual emission only
  ps.emitterShape = esPoint
  ps.velocityMin = (-15.0, -15.0)
  ps.velocityMax = (15.0, 15.0)
  ps.lifeMin = 0.5
  ps.lifeMax = 1.5
  ps.chars = @["*", "•", "○", "◦", "·"]
  ps.colorMin = Color(r: 255, g: 150, b: 0)
  ps.colorMax = Color(r: 255, g: 255, b: 100)
  ps.gravity = 10.0
  ps.damping = 0.95
  ps.fadeOut = true
  ps.drawMode = pdmReplace  # Use default mode for explosion particles

proc configureColorblast*(ps: ParticleSystem) =
  ## Configure for color blast effect that paints existing cells (use ps.emit(100) after)
  ps.emitRate = 0.0  # Manual emission only
  ps.emitterShape = esPoint
  ps.velocityMin = (-20.0, -20.0)
  ps.velocityMax = (20.0, 20.0)
  ps.lifeMin = 0.3
  ps.lifeMax = 1.0
  ps.chars = @["●", "◆", "■", "▲", "★"]  # Visible particles
  ps.colorMin = Color(r: 255, g: 0, b: 0)
  ps.colorMax = Color(r: 255, g: 255, b: 0)
  ps.gravity = 0.0
  ps.damping = 0.90
  ps.fadeOut = true
  ps.drawMode = pdmReplace  # Render visible colored particles
  ps.trailEnabled = false

proc configureMatrix*(ps: ParticleSystem, intensity: float = 20.0) =
  ## Configure system for Matrix-style falling code effect with trails
  ps.emitRate = intensity
  ps.emitterShape = esLine
  ps.velocityMin = (0.0, 8.0)   # Downward movement
  ps.velocityMax = (0.0, 15.0)
  ps.lifeMin = 5.0
  ps.lifeMax = 10.0
  
  # Matrix characters (numbers, letters, katakana-like)
  ps.chars = @["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
               "A", "B", "C", "D", "E", "F", "Z", ":", ".", "=",
               "¦", "|", "^", "<", ">", "*", "+", "-"]
  
  # Bright green at head
  ps.colorMin = Color(r: 100, g: 255, b: 100)
  ps.colorMax = Color(r: 150, g: 255, b: 150)
  
  ps.gravity = 0.0  # Consistent fall speed
  ps.windForce = (0.0, 0.0)
  ps.damping = 1.0  # No resistance
  ps.fadeOut = false  # Trail handles fading
  ps.drawMode = pdmReplace
  
  # Enable trails for cascading effect
  ps.trailEnabled = true
  ps.trailMaxLength = 12  # Long trails like Matrix
  ps.trailSpacing = 0.8   # Tight spacing
  ps.trailFade = true     # Fade to dark green
  ps.trailChars = ps.chars  # Same character set
  
  ps.collisionEnabled = false

proc configureBugs*(ps: ParticleSystem, intensity: float = 5.0) =
  ## Configure system for crawling bug/centipede effect with segmented bodies
  ps.emitRate = intensity
  ps.emitterShape = esArea  # Spawn from various locations
  
  # Random darting movements
  ps.velocityMin = (-8.0, -8.0)
  ps.velocityMax = (8.0, 8.0)
  ps.lifeMin = 3.0
  ps.lifeMax = 8.0
  
  # Bug head characters
  ps.chars = @["@", "0", "O", "●", "◉"]
  
  # Bug colors (dark browns, grays)
  ps.colorMin = Color(r: 80, g: 60, b: 40)
  ps.colorMax = Color(r: 120, g: 100, b: 80)
  
  ps.gravity = 0.0
  ps.windForce = (0.0, 0.0)
  ps.turbulence = 5.0  # Erratic movement
  ps.damping = 0.85    # Some drag
  ps.fadeOut = false
  ps.drawMode = pdmReplace
  
  # Enable trails for segmented body
  ps.trailEnabled = true
  ps.trailMaxLength = 5   # 5-segment centipedes
  ps.trailSpacing = 0.5   # Tight segments
  ps.trailFade = false    # All segments same brightness
  
  # Body segment characters
  ps.trailChars = @[".", "\\", "/", "-", "|", "*", "·", "o"]
  
  ps.collisionEnabled = false

# ================================================================
# GRAPH-BASED PRESET BUILDERS
# ================================================================

proc configureRainGraph*(): tuple[motion: Graph, color: Graph, char: Graph] =
  ## Build graphs for rain effect using node-based system
  
  # Motion: Constant downward + slight horizontal drift
  var motionGraph = newGraph()
  let baseVelocity = motionGraph.constant(15.0)
  let wind = motionGraph.noise("white", scale=100)
  let windScaled = motionGraph.math("map")
  windScaled.mathParams = @[0.0, 65535.0, -2.0, 2.0]
  wind.connect(windScaled)
  
  let totalVelocity = motionGraph.math("add")
  baseVelocity.connect(totalVelocity)
  windScaled.connect(totalVelocity)
  
  let outNode = motionGraph.valueOut()
  totalVelocity.connect(outNode)
  
  # Color: Blue-ish rain colors based on lifetime
  var colorGraph = newGraph()
  let lifeFrac = colorGraph.input("plifeFraction")
  let colorVal = colorGraph.math("map")
  colorVal.mathParams = @[0.0, 1.0, 100.0, 200.0]
  lifeFrac.connect(colorVal)
  
  let colors = colorGraph.color("water", 0, 255)
  colorVal.connect(colors)
  let colorOutNode = colorGraph.bufferOut()
  colors.connect(colorOutNode)
  
  # Character: Simple rain characters
  var charGraph = newGraph()
  let age = charGraph.input("page")
  let charIdx = charGraph.math("map")
  charIdx.mathParams = @[0.0, 4.0, 0.0, 2.0]  # Map age to 0-2
  age.connect(charIdx)
  let charOutNode = charGraph.valueOut()
  charIdx.connect(charOutNode)
  
  result = (motionGraph, colorGraph, charGraph)

proc configureFireGraph*(): tuple[motion: Graph, color: Graph, char: Graph] =
  ## Build graphs for fire effect using node-based system
  
  # Motion: Upward + turbulent noise
  var motionGraph = newGraph()
  let upwardForce = motionGraph.constant(-20.0)  # Negative Y = up
  
  let turbulence = motionGraph.noise("fractal", scale=20, octaves=3)
  let turbScaled = motionGraph.math("map")
  turbScaled.mathParams = @[0.0, 65535.0, -5.0, 5.0]
  turbulence.connect(turbScaled)
  
  let totalForce = motionGraph.math("add")
  upwardForce.connect(totalForce)
  turbScaled.connect(totalForce)
  
  let outNode = motionGraph.valueOut()
  totalForce.connect(outNode)
  
  # Color: Fire palette (yellow-orange-red) based on age
  var colorGraph = newGraph()
  let lifeFrac = colorGraph.input("plifeFraction")
  let colorVal = colorGraph.math("map")
  colorVal.mathParams = @[0.0, 1.0, 255.0, 50.0]  # Bright to dark
  lifeFrac.connect(colorVal)
  
  let colors = colorGraph.color("fire", 0, 255)
  colorVal.connect(colors)
  let colorOutNode = colorGraph.bufferOut()
  colors.connect(colorOutNode)
  
  # Character: Fire chars (larger = younger)
  var charGraph = newGraph()
  let age = charGraph.input("page")
  let charIdx = charGraph.math("map")
  charIdx.mathParams = @[0.0, 1.0, 0.0, 3.0]
  age.connect(charIdx)
  let charOutNode = charGraph.valueOut()
  charIdx.connect(charOutNode)
  
  result = (motionGraph, colorGraph, charGraph)

proc configureVortexGraph*(centerX, centerY: float): Graph =
  ## Build motion graph for vortex/swirl effect (edControl domain)
  var graph = newGraph()
  let px = graph.input("px", edControl)
  let py = graph.input("py", edControl)
  
  # Calculate angle from center (manual node creation for edControl)
  let angle = graph.addNode(nkPolar, edControl)
  angle.polarOp = "angle"
  angle.centerX = centerX
  angle.centerY = centerY
  px.connect(angle)
  py.connect(angle)
  
  # Rotate 90 degrees for tangential force
  let tangentAngle = graph.addNode(nkMath, edControl)
  tangentAngle.mathOp = "add"
  angle.connect(tangentAngle)
  
  let ninetyDeg = graph.addNode(nkConstant, edControl)
  ninetyDeg.constValue = 900.0  # 90 degrees in decidegrees
  ninetyDeg.connect(tangentAngle)
  
  # Convert to velocity
  let vx = graph.addNode(nkWave, edControl)
  vx.waveType = "cos"
  tangentAngle.connect(vx)
  
  let strength = graph.addNode(nkConstant, edControl)
  strength.constValue = 5.0
  
  let forceX = graph.addNode(nkMath, edControl)
  forceX.mathOp = "mul"
  vx.connect(forceX)
  strength.connect(forceX)
  
  # Convert from edVisual (waveValue ~-1000..1000) to edControl (float)
  # by dividing by 1000
  let normalized = graph.addNode(nkMath, edControl)
  normalized.mathOp = "mul"
  forceX.connect(normalized)
  let scale = graph.addNode(nkConstant, edControl)
  scale.constValue = 0.001  # Divide by 1000
  scale.connect(normalized)
  
  let outNode = graph.addNode(nkValueOut, edControl)
  normalized.connect(outNode)
  
  result = graph

proc configureExplosionGraph*(center: tuple[x, y: float]): Graph =
  ## Build motion graph for radial explosion (edControl domain)
  var graph = newGraph()
  let px = graph.input("px", edControl)
  let py = graph.input("py", edControl)
  
  # Calculate angle from explosion center
  let angle = graph.addNode(nkPolar, edControl)
  angle.polarOp = "angle"
  angle.centerX = center.x
  angle.centerY = center.y
  px.connect(angle)
  py.connect(angle)
  
  # Distance affects strength (further = weaker)
  let dist = graph.addNode(nkPolar, edControl)
  dist.polarOp = "distance"
  dist.centerX = center.x
  dist.centerY = center.y
  px.connect(dist)
  py.connect(dist)
  
  # Radial velocity based on angle
  let vx = graph.addNode(nkWave, edControl)
  vx.waveType = "cos"
  angle.connect(vx)
  
  # Initial explosion strength
  let strength = graph.addNode(nkConstant, edControl)
  strength.constValue = 30.0
  
  # Decay over distance
  let decay = graph.addNode(nkMath, edControl)
  decay.mathOp = "map"
  decay.mathParams = @[0.0, 50.0, 1.0, 0.1]
  dist.connect(decay)
  
  let decayedStrength = graph.addNode(nkMath, edControl)
  decayedStrength.mathOp = "mul"
  strength.connect(decayedStrength)
  decay.connect(decayedStrength)
  
  let forceX = graph.addNode(nkMath, edControl)
  forceX.mathOp = "mul"
  vx.connect(forceX)
  decayedStrength.connect(forceX)
  
  let outNode = graph.addNode(nkValueOut, edControl)
  forceX.connect(outNode)
  
  result = graph

proc configureRippleDisplacementGraph*(): Graph =
  ## Build spatial displacement graph for water ripple effect (edVisual domain)
  var graph = newGraph()
  let x = graph.input("x", edVisual)
  let y = graph.input("y", edVisual)
  let frame = graph.input("frame", edVisual)
  
  # Distance from center (will be set dynamically)
  let dist = graph.addNode(nkPolar, edVisual)
  dist.polarOp = "distance"
  dist.centerX = 40.0  # Default center
  dist.centerY = 12.0
  x.connect(dist)
  y.connect(dist)
  
  # Create ripple wave
  let wave = graph.addNode(nkWave, edVisual)
  wave.waveType = "sin"
  
  let phase = graph.addNode(nkMath, edVisual)
  phase.mathOp = "add"
  
  let distScaled = graph.addNode(nkMath, edVisual)
  distScaled.mathOp = "mul"
  dist.connect(distScaled)
  
  let distConst = graph.addNode(nkConstant, edVisual)
  distConst.constValue = 20.0
  distConst.connect(distScaled)
  
  let frameScaled = graph.addNode(nkMath, edVisual)
  frameScaled.mathOp = "mul"
  frame.connect(frameScaled)
  
  let frameConst = graph.addNode(nkConstant, edVisual)
  frameConst.constValue = -10.0
  frameConst.connect(frameScaled)
  
  distScaled.connect(phase)
  frameScaled.connect(phase)
  phase.connect(wave)
  
  # Convert wave output (edVisual) to displacement pixels (-3 to +3)
  let displacement = graph.addNode(nkMath, edVisual)
  displacement.mathOp = "map"
  displacement.mathParams = @[0.0, 1000.0, -3.0, 3.0]
  wave.connect(displacement)
  
  let outNode = graph.addNode(nkValueOut, edVisual)
  displacement.connect(outNode)
  
  result = graph

proc configureMatrixTrailGraph*(): Graph =
  ## Build spatial color graph for Matrix-style trail fade
  var graph = newGraph()
  
  # Darken existing cells each frame
  let existing = graph.input("cellBrightness", edVisual)  # 0-255
  let dimmed = graph.math("mul")
  existing.connect(dimmed)
  graph.constant(0.92).connect(dimmed)  # Keep 92% each frame
  
  let outNode = graph.bufferOut()
  dimmed.connect(outNode)
  
  result = graph
