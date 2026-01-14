# Node-Based Particle System Design

## Overview

Transform the particle system from **hardcoded behaviors** to **graph-driven effects** using the unified node graph architecture. This allows particles to:

- Use any combination of primitives for motion
- Evaluate spatial effects for buffer transformation
- React to audio/visual inputs
- Create infinitely customizable effects

## Core Concept

**Particles become mobile evaluation points for primitive graphs.**

Instead of:
```nim
ps.gravity = 9.8           # Hardcoded parameter
ps.turbulence = 3.0        # Hardcoded noise
```

You get:
```nim
ps.motionGraph = graph     # User-defined behavior
ps.colorGraph = graph      # User-defined appearance
ps.characterGraph = graph  # User-defined shape
```

## Architecture

### Particle System Changes

```nim
type
  ParticleEffectMode* = enum
    pemParticles        ## Traditional particles (dots moving)
    pemSpatialField     ## Evaluate graph per pixel (displacement/color field)
    pemHybrid           ## Both particles AND spatial effects
  
  ParticleEffectFlags* = object
    ## Combinable flags for what particles affect
    replaceChar*: bool       # Replace cell character
    modulateColor*: bool     # Affect cell foreground color
    modulateBg*: bool        # Affect cell background color
    displace*: bool          # Displace cell position
    emit*: bool              # Emit new particles based on field
  
  ParticleSystem* = ref object
    # ... existing fields ...
    
    # Graph-based behavior (replaces hardcoded parameters)
    effectMode*: ParticleEffectMode
    effectFlags*: ParticleEffectFlags
    
    # Graphs for different aspects
    motionGraph*: Graph          # Controls particle velocity/position
    colorGraph*: Graph           # Controls particle color over lifetime
    characterGraph*: Graph       # Selects character based on particle state
    emissionGraph*: Graph        # Controls emission rate/pattern
    lifetimeGraph*: Graph        # Controls particle lifetime/fading
    
    # Spatial field graphs (for displacement effects)
    spatialDisplacementGraph*: Graph   # Displacement field for buffer
    spatialColorGraph*: Graph          # Color modulation field for buffer
    
    # Graph evaluation contexts (populated from particle state)
    particleContext*: EvalContext      # Context for per-particle evaluation
    spatialContext*: EvalContext       # Context for per-pixel evaluation
```

## Evaluation Modes

### Mode 1: Traditional Particles (pemParticles)

Particles move and render as before, but behavior is graph-driven:

```nim
var ps = initParticleSystem(1000)
ps.effectMode = pemParticles

# Create motion graph (replaces gravity + turbulence)
var motionGraph = newGraph()
let py = motionGraph.input("py")          # Particle Y position
let frame = motionGraph.input("frame")
let noise = motionGraph.noise("fractal", scale=20)

# Gravity component
let gravity = motionGraph.constant(9.8)

# Turbulence component (noise-based)
let turbulence = motionGraph.math("mul")
noise.connect(turbulence)
motionGraph.constant(0.3).connect(turbulence)

# Combine
let totalForce = motionGraph.math("add")
gravity.connect(totalForce)
turbulence.connect(totalForce)

let velocityOut = motionGraph.valueOut()
totalForce.connect(velocityOut)

ps.motionGraph = motionGraph

# During update:
#   for each particle:
#     context.custom["px"] = particle.x
#     context.custom["py"] = particle.y
#     context.custom["pvx"] = particle.vx
#     context.custom["pvy"] = particle.vy
#     context.custom["page"] = particle.maxLife - particle.life
#     let force = motionGraph.evaluate(context)
#     particle.vy += force.controlValue * dt
```

**Particle Context Inputs:**
- `px`, `py` - Particle position
- `pvx`, `pvy` - Particle velocity
- `page` - Particle age (0 at spawn)
- `plife` - Remaining lifetime
- `plifeFraction` - Age/maxLife (0..1)
- `frame` - Global frame counter
- `time` - Time in seconds

### Mode 2: Spatial Fields (pemSpatialField)

No visible particles - graph is evaluated per-pixel to transform buffer:

```nim
var ps = initParticleSystem(0)  # No particles needed
ps.effectMode = pemSpatialField
ps.effectFlags.displace = true

# Create ripple displacement field
var displaceGraph = newGraph()
let x = displaceGraph.input("x")
let y = displaceGraph.input("y")
let frame = displaceGraph.input("frame")
let centerX = displaceGraph.constant(40.0)
let centerY = displaceGraph.constant(12.0)

# Distance from center
let dist = displaceGraph.polar("distance", 40.0, 12.0)
x.connect(dist)
y.connect(dist)

# Create ripple wave
let wave = displaceGraph.wave("sin")
let phase = displaceGraph.math("add")

let distScaled = displaceGraph.math("mul")
dist.connect(distScaled)
displaceGraph.constant(20.0).connect(distScaled)

let frameScaled = displaceGraph.math("mul")
frame.connect(frameScaled)
displaceGraph.constant(-10.0).connect(frameScaled)

distScaled.connect(phase)
frameScaled.connect(phase)
phase.connect(wave)

# Map to displacement
let displacement = displaceGraph.math("map")
displacement.mathParams = @[-1000.0, 1000.0, -3.0, 3.0]
wave.connect(displacement)

let out = displaceGraph.valueOut()
displacement.connect(out)

ps.spatialDisplacementGraph = displaceGraph

# During render:
#   for y in 0 ..< height:
#     for x in 0 ..< width:
#       context.x = x
#       context.y = y
#       context.frame = frame
#       let disp = displaceGraph.evaluate(context)
#       let sourceX = x + int(disp.controlValue)
#       let sourceY = y
#       buffer[x, y] = buffer[sourceX, sourceY]  # Sample displaced
```

**Spatial Context Inputs:**
- `x`, `y` - Pixel coordinates
- `width`, `height` - Buffer dimensions
- `frame` - Frame counter
- `time` - Time in seconds
- Plus any custom inputs (mouseX, audioLevel, etc.)

### Mode 3: Hybrid (pemHybrid)

Particles move AND generate spatial fields:

```nim
var ps = initParticleSystem(100)
ps.effectMode = pemHybrid
ps.effectFlags.modulateColor = true

# Particles create moving "heat spots"
# Each particle position becomes input to color modulation field

# Motion graph (particles drift)
var motionGraph = newGraph()
let wind = motionGraph.constant(2.0)
motionGraph.valueOut().connect(wind)
ps.motionGraph = motionGraph

# Spatial color graph (affected by particle positions)
var colorGraph = newGraph()
let x = colorGraph.input("x")
let y = colorGraph.input("y")

# For each particle, calculate distance and add contribution
# (This would actually be a special node type that knows about particles)
let particleInfluence = colorGraph.input("particleHeat")  # Computed value

# Map to color
let colors = colorGraph.color("fire", 0, 255)
particleInfluence.connect(colors)
let out = colorGraph.bufferOut()
colors.connect(out)

ps.spatialColorGraph = colorGraph

# During render:
#   # First pass: calculate particle influence at each pixel
#   for y in 0 ..< height:
#     for x in 0 ..< width:
#       var heat = 0.0
#       for particle in activeParticles:
#         let dist = sqrt((x - particle.x)^2 + (y - particle.y)^2)
#         heat += max(0, 10 - dist)  # Particles radiate heat
#       
#       context.custom["particleHeat"] = heat
#       let color = colorGraph.evaluate(context)
#       # Modulate existing cell color
```

## Graph Types and Their Uses

### 1. Motion Graph

**Controls**: Particle velocity/acceleration

**Inputs Available**:
- Particle state (position, velocity, age)
- Global state (frame, time)
- Custom inputs (audio, mouse, etc.)

**Output**: Force/velocity delta applied to particle

**Example - Vortex Motion**:
```nim
var graph = newGraph()
let px = graph.input("px")
let py = graph.input("py")
let centerX = graph.constant(40.0)
let centerY = graph.constant(12.0)

# Polar coordinates
let angle = graph.polar("angle", 40.0, 12.0)
px.connect(angle)
py.connect(angle)

# Rotate 90 degrees for tangential force
let tangentAngle = graph.math("add")
angle.connect(tangentAngle)
graph.constant(900.0).connect(tangentAngle)  # 90 degrees in decidegrees

# Convert to velocity
let vx = graph.wave("cos")
tangentAngle.connect(vx)

let vy = graph.wave("sin")
tangentAngle.connect(vy)

let strength = graph.constant(5.0)

let forceX = graph.math("mul")
vx.connect(forceX)
strength.connect(forceX)

let forceY = graph.math("mul")
vy.connect(forceY)
strength.connect(forceY)

# Output both X and Y (special handling needed)
```

### 2. Color Graph

**Controls**: Particle color over lifetime

**Inputs Available**:
- Particle lifetime fraction (0..1)
- Particle velocity (for speed-based coloring)
- Position (for location-based coloring)

**Output**: RGB color

**Example - Velocity-Based Color**:
```nim
var graph = newGraph()
let pvx = graph.input("pvx")
let pvy = graph.input("pvy")

# Calculate speed
let vxSq = graph.math("mul")
pvx.connect(vxSq)
pvx.connect(vxSq)

let vySq = graph.math("mul")
pvy.connect(vySq)
pvy.connect(vySq)

let speedSq = graph.math("add")
vxSq.connect(speedSq)
vySq.connect(speedSq)

# Map to 0..255
let colorValue = graph.math("map")
colorValue.mathParams = @[0.0, 400.0, 0.0, 255.0]
speedSq.connect(colorValue)

# Apply color palette
let colors = graph.color("neon")
colorValue.connect(colors)

let out = graph.bufferOut()
colors.connect(out)
```

### 3. Character Graph

**Controls**: Which character to display

**Inputs Available**:
- Particle age
- Velocity
- Position
- Random seed

**Output**: Character index or character directly

**Example - Age-Based Characters**:
```nim
var graph = newGraph()
let age = graph.input("page")

# Young particles: "."
# Middle-aged: "o"
# Old: "O"
# Very old: "@"

let ageScaled = graph.math("map")
ageScaled.mathParams = @[0.0, 2.0, 0.0, 3.0]  # Assume 2s max life
age.connect(ageScaled)

# Convert to character index
let charIdx = graph.valueOut()
ageScaled.connect(charIdx)

# In particle system:
#   let idx = clamp(int(result.controlValue), 0, chars.len - 1)
#   particle.char = chars[idx]
```

### 4. Emission Graph

**Controls**: Emission rate and pattern

**Inputs Available**:
- Time
- Audio levels
- Custom triggers

**Output**: Number of particles to emit this frame

**Example - Beat-Reactive Emission**:
```nim
var graph = newGraph()
let bassLevel = graph.input("bassLevel")  # From audio analysis

# Baseline emission
let baseline = graph.constant(10.0)

# Burst on bass
let burst = graph.math("mul")
bassLevel.connect(burst)
graph.constant(50.0).connect(burst)

# Total
let total = graph.math("add")
baseline.connect(total)
burst.connect(total)

let out = graph.valueOut()
total.connect(out)

# In particle system:
#   let emitCount = int(result.controlValue)
#   emit(emitCount)
```

### 5. Spatial Displacement Graph

**Controls**: How buffer cells are displaced

**Inputs Available**:
- Pixel position (x, y)
- Frame, time
- Custom inputs

**Output**: Displacement vector (dx, dy)

**Example - Noise-Based Distortion**:
```nim
var graph = newGraph()
let x = graph.input("x")
let y = graph.input("y")
let frame = graph.input("frame")

# Horizontal noise
let noiseX = graph.noise("fractal", scale=20, octaves=3)
x.connect(noiseX)
y.connect(noiseX)

let xDisp = graph.math("map")
xDisp.mathParams = @[0.0, 65535.0, -5.0, 5.0]
noiseX.connect(xDisp)

# Vertical noise (different seed)
let noiseY = graph.noise("fractal", scale=20, octaves=3)
noiseY.noiseSeed = 1000
x.connect(noiseY)
y.connect(noiseY)

let yDisp = graph.math("map")
yDisp.mathParams = @[0.0, 65535.0, -3.0, 3.0]
noiseY.connect(yDisp)

# Output (need dual output support)
```

## Preset Builders

Keep convenient presets but implement them as graphs:

```nim
proc configureRainGraph*(): tuple[motion: Graph, color: Graph, char: Graph] =
  ## Build graphs for rain effect
  
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
  
  let out = motionGraph.valueOut()
  totalVelocity.connect(out)
  
  # Color: Blue gradient
  var colorGraph = newGraph()
  let constant = colorGraph.constant(200.0)
  let colors = colorGraph.color("ocean", 180, 220)
  constant.connect(colors)
  let colorOut = colorGraph.bufferOut()
  colors.connect(colorOut)
  
  # Character: Random from set
  var charGraph = newGraph()
  let random = charGraph.noise("white")
  let charIdx = charGraph.math("map")
  charIdx.mathParams = @[0.0, 65535.0, 0.0, 2.0]  # 3 chars
  random.connect(charIdx)
  let charOut = charGraph.valueOut()
  charIdx.connect(charOut)
  
  result = (motionGraph, colorGraph, charGraph)

# Usage:
let (motion, color, char) = configureRainGraph()
ps.motionGraph = motion
ps.colorGraph = color
ps.characterGraph = char
ps.chars = @["|", "¦", "│"]
```

## Implementation Strategy

### Phase 1: Graph Integration (Minimal Changes)

Add graph fields to ParticleSystem without breaking existing code:

```nim
type ParticleSystem = ref object
  # ... existing fields ...
  
  # New: Optional graphs (nil = use legacy behavior)
  motionGraph*: Graph
  colorGraph*: Graph
  characterGraph*: Graph
  
  # New: Evaluation contexts
  particleContext*: EvalContext
  spatialContext*: EvalContext
```

Update `update()`:
```nim
proc update*(ps: ParticleSystem, dt: float) =
  # ... existing code ...
  
  for i in 0 ..< ps.maxParticles:
    if not ps.particles[i].active: continue
    
    # NEW: If motion graph exists, use it
    if not ps.motionGraph.isNil:
      ps.particleContext.custom["px"] = ps.particles[i].x
      ps.particleContext.custom["py"] = ps.particles[i].y
      ps.particleContext.custom["pvx"] = ps.particles[i].vx
      ps.particleContext.custom["pvy"] = ps.particles[i].vy
      ps.particleContext.custom["page"] = ps.particles[i].maxLife - ps.particles[i].life
      ps.particleContext.frame = ps.frame
      
      let outputs = ps.motionGraph.evaluate(ps.particleContext)
      if outputs.len > 0:
        ps.particles[i].vy += outputs[0].controlValue * dt
    else:
      # Legacy: Use hardcoded gravity + turbulence
      ps.particles[i].vy += (ps.windForce.y + ps.gravity) * dt
      # ... existing turbulence code ...
```

### Phase 2: Spatial Effects

Add buffer transformation using spatial graphs:

```nim
proc applyDisplacementField*(ps: ParticleSystem, buffer: var TermBuffer) =
  ## Apply spatial displacement graph to entire buffer
  if ps.spatialDisplacementGraph.isNil: return
  
  # Create temporary buffer to sample from
  let tempBuffer = buffer.copy()
  
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      ps.spatialContext.x = x
      ps.spatialContext.y = y
      ps.spatialContext.frame = ps.frame
      
      let outputs = ps.spatialDisplacementGraph.evaluate(ps.spatialContext)
      if outputs.len > 0:
        let dx = int(outputs[0].controlValue)
        let dy = if outputs.len > 1: int(outputs[1].controlValue) else: 0
        
        let sourceX = clamp(x + dx, 0, buffer.width - 1)
        let sourceY = clamp(y + dy, 0, buffer.height - 1)
        
        let cell = tempBuffer.getCell(sourceX, sourceY)
        buffer.write(x, y, cell.ch, cell.style)

proc applyColorField*(ps: ParticleSystem, buffer: var TermBuffer) =
  ## Apply spatial color graph to buffer
  if ps.spatialColorGraph.isNil: return
  
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      ps.spatialContext.x = x
      ps.spatialContext.y = y
      
      let outputs = ps.spatialColorGraph.evaluate(ps.spatialContext)
      if outputs.len > 0 and outputs[0].domain == edVisual:
        let cell = buffer.getCell(x, y)
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
```

### Phase 3: Effect Flags

Add combinable flags for fine control:

```nim
proc render*(ps: ParticleSystem, buffer: var TermBuffer) =
  # Apply spatial effects first (if enabled)
  if ps.effectFlags.displace:
    ps.applyDisplacementField(buffer)
  
  if ps.effectFlags.modulateColor:
    ps.applyColorField(buffer)
  
  # Then render particles (if mode includes them)
  if ps.effectMode in {pemParticles, pemHybrid}:
    # ... existing particle rendering ...
    
    # But use graphs for color/character if available
    for i in 0 ..< ps.maxParticles:
      if not ps.particles[i].active: continue
      
      # Evaluate color graph
      if not ps.colorGraph.isNil:
        ps.particleContext.custom["plifeFraction"] = 
          (ps.particles[i].maxLife - ps.particles[i].life) / ps.particles[i].maxLife
        let outputs = ps.colorGraph.evaluate(ps.particleContext)
        if outputs.len > 0:
          ps.particles[i].color = Color(
            r: outputs[0].visualColor.r,
            g: outputs[0].visualColor.g,
            b: outputs[0].visualColor.b
          )
      
      # Evaluate character graph
      if not ps.characterGraph.isNil:
        let outputs = ps.characterGraph.evaluate(ps.particleContext)
        if outputs.len > 0:
          let idx = clamp(int(outputs[0].controlValue), 0, ps.chars.len - 1)
          ps.particles[i].char = ps.chars[idx]
      
      # Render particle...
```

## Example Use Cases

### 1. Matrix Rain with Graph

```nim
var ps = initParticleSystem(100)
ps.effectMode = pemHybrid
ps.effectFlags = (
  replaceChar: true,
  modulateColor: true,
  displace: false,
  modulateBg: false,
  emit: false
)

# Motion: Straight down
var motion = newGraph()
let down = motion.constant(12.0)
motion.valueOut().connect(down)
ps.motionGraph = motion

# Color: Bright green at head, fading to dark
var colors = newGraph()
let lifeFrac = colors.input("plifeFraction")
let colorVal = colors.math("map")
colorVal.mathParams = @[0.0, 1.0, 255.0, 50.0]  # Bright to dim
lifeFrac.connect(colorVal)
let matrixColors = colors.color("matrix")
colorVal.connect(matrixColors)
colors.bufferOut().connect(matrixColors)
ps.colorGraph = colors

# Spatial: Trail fade effect
var trail = newGraph()
# Each frame, darken existing cells slightly
let y = trail.input("y")
let existing = trail.input("cellColor")  # Would need special node
let dimmed = trail.math("mul")
existing.connect(dimmed)
trail.constant(0.95).connect(dimmed)
trail.bufferOut().connect(dimmed)
ps.spatialColorGraph = trail

ps.chars = @["0", "1", "2", "3", "4", "5", "A", "B", "Z"]
```

### 2. Audio-Reactive Particles

```nim
var ps = initParticleSystem(500)

# Emission based on bass level
var emission = newGraph()
let bass = emission.input("bassLevel")  # Updated from audio
let emitCount = emission.math("mul")
bass.connect(emitCount)
emission.constant(100.0).connect(emitCount)
emission.valueOut().connect(emitCount)
ps.emissionGraph = emission

# Motion: Explode outward
var motion = newGraph()
let age = motion.input("page")
let speed = motion.math("map")
speed.mathParams = @[0.0, 1.0, 20.0, 2.0]  # Fast start, slow down
age.connect(speed)
motion.valueOut().connect(speed)
ps.motionGraph = motion

# Color: Audio level determines palette
var colors = newGraph()
let audioLevel = colors.input("audioLevel")
let palette = colors.color("neon")
audioLevel.connect(palette)
colors.bufferOut().connect(palette)
ps.colorGraph = colors
```

### 3. Water Ripple (Pure Spatial)

```nim
var ps = initParticleSystem(0)  # No particles!
ps.effectMode = pemSpatialField
ps.effectFlags.displace = true

# Graph creates ripple pattern
var ripple = newGraph()
let x = ripple.input("x")
let y = ripple.input("y")
let frame = ripple.input("frame")
let mouseX = ripple.input("mouseX")
let mouseY = ripple.input("mouseY")

# Distance from mouse
let dist = ripple.polar("distance")
x.connect(dist)
y.connect(dist)
dist.centerX = 0  # Will be set from mouseX
dist.centerY = 0  # Will be set from mouseY

# Wave
let wave = ripple.wave("sin")
let phase = ripple.math("add")

let distScaled = ripple.math("mul")
dist.connect(distScaled)
ripple.constant(25.0).connect(distScaled)

let frameScaled = ripple.math("mul")
frame.connect(frameScaled)
ripple.constant(-15.0).connect(frameScaled)

distScaled.connect(phase)
frameScaled.connect(phase)
phase.connect(wave)

# Map to displacement
let disp = ripple.math("map")
disp.mathParams = @[-1000.0, 1000.0, -4.0, 4.0]
wave.connect(disp)

ripple.valueOut().connect(disp)

ps.spatialDisplacementGraph = ripple

# Update mouse position each frame:
ps.spatialContext.custom["mouseX"] = float(mouseX)
ps.spatialContext.custom["mouseY"] = float(mouseY)
ps.spatialDisplacementGraph.polar nodes update their centers dynamically
```

## Benefits

1. **Infinite Flexibility**: Any combination of primitives, not limited to presets
2. **Composability**: Mix and match graphs for different aspects
3. **Reusability**: Same graph can be used by multiple systems
4. **Performance**: Graphs compile to tight native loops
5. **Audio-Visual Unity**: Audio and particles use same graph system
6. **Debuggability**: Can inspect/visualize graph structure
7. **Transitions**: Particles + displacement = natural transition effects

## Next Steps

1. Implement Phase 1 (add graph fields, preserve legacy behavior)
2. Create graph builder helpers for common patterns
3. Add dual-output support for vector results (dx, dy)
4. Create special node types (particleInfluence, cellSample, etc.)
5. Build example gallery showing graph-based effects
6. Create visual graph editor (future)

This design transforms particles from a fixed-behavior system into a universal effects engine powered by composable primitives! 🎨✨
