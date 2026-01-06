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

import std/[math, random, tables]

when not declared(Color):
  import ../src/types
  import ../src/layers

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
  
  Particle* = object
    x*, y*: float          # Position
    vx*, vy*: float        # Velocity
    life*: float           # Remaining lifetime
    maxLife*: float        # Initial lifetime (for fade calculations)
    char*: string          # Display character
    color*: Color          # Display color
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
    
    # Environmental parameters (mutable at runtime)
    gravity*: float
    windForce*: Vec2
    turbulence*: float
    damping*: float
    
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
    drawMode*: ParticleDrawMode  # How particles affect cells
    layerTarget*: ptr Layer   # Target layer for rendering
    backgroundColor*: Color   # Background color for particles (theme-aware)

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
    drawMode: pdmReplace,  # Default to full cell replacement
    layerTarget: nil,
    backgroundColor: rgb(0, 0, 0)  # Default to black
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
  
  # Update all active particles in tight loop
  var newActiveCount = 0
  for i in 0 ..< ps.maxParticles:
    if not ps.particles[i].active:
      continue
    
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
# PARTICLE RENDERING
# ================================================================

proc render*(ps: ParticleSystem, layer: ptr Layer) =
  ## Render all active particles to a layer
  if layer.isNil:
    return
  
  let buf = layer.buffer.addr
  
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
    
    # Calculate alpha fade
    var color = ps.particles[i].color
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
      buf[].write(ix, iy, ps.particles[i].char, style)
    
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
      buf[].write(ix, iy, ps.particles[i].char, existingCell.style)

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
    
    # Calculate alpha fade
    var color = ps.particles[i].color
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
