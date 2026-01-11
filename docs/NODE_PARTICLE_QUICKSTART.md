# Node-Based Particle System - Quick Start

## Overview

The new particle system uses **composable node graphs** instead of hardcoded parameters. This allows infinite customization while maintaining ease of use through preset builders.

## Basic Usage

### Option 1: Use Preset Graphs (Easy)

```nim
# Create particle system
var ps = particlesCreate(200)

# Configure with preset (same as before)
particlesConfigureRain(ps, 50.0)

# Now the motion is graph-driven internally!
particlesUpdate(ps, dt)
particlesRender(ps, layer)
```

### Option 2: Build Custom Graphs (Advanced)

```nim
import lib/graph
import lib/primitives

# Create motion graph
var motionGraph = newGraph()
let gravity = motionGraph.constant(9.8)
let noise = motionGraph.noise("fractal", scale=20)
let wind = motionGraph.math("map")
wind.mathParams = @[0.0, 65535.0, -5.0, 5.0]
noise.connect(wind)

let totalForce = motionGraph.math("add")
gravity.connect(totalForce)
wind.connect(totalForce)

let outNode = motionGraph.valueOut()
totalForce.connect(outNode)

# Attach to particle system
var ps = particlesCreate(200)
ps.motionGraph = motionGraph
particlesUpdate(ps, dt)
```

## Available Preset Graph Builders

These return pre-built graphs you can use or modify:

```nim
# Rain: downward motion + wind noise
let (motion, color, char) = configureRainGraph()

# Fire: upward + turbulence
let (motion, color, char) = configureFireGraph()

# Vortex: swirl around a center point
let motionGraph = configureVortexGraph(centerX, centerY)

# Explosion: radial burst from center
let motionGraph = configureExplosionGraph((x, y))

# Ripple: water-like displacement field
let displaceGraph = configureRippleDisplacementGraph()

# Matrix trails: fade effect
let colorGraph = configureMatrixTrailGraph()
```

## Effect Modes

### 1. Particles Mode (pemParticles)
Traditional particles with graph-driven behavior:

```nim
ps.effectMode = pemParticles
ps.motionGraph = myMotionGraph  # Controls movement
ps.colorGraph = myColorGraph    # Controls color over lifetime
ps.characterGraph = myCharGraph # Controls which character to display
```

### 2. Spatial Field Mode (pemSpatialField)
No particles - pure buffer effects:

```nim
ps.effectMode = pemSpatialField
ps.effectFlags.displace = true
ps.spatialDisplacementGraph = rippleGraph  # Affects entire buffer
```

### 3. Hybrid Mode (pemHybrid)
Particles + spatial effects:

```nim
ps.effectMode = pemHybrid
ps.motionGraph = motionGraph           # Particles move
ps.spatialColorGraph = trailFadeGraph  # Buffer fades
```

## Node Types Quick Reference

### Input Nodes
Get data from particle or environment:
```nim
let px = graph.input("px")         # Particle X position
let py = graph.input("py")         # Particle Y position
let pvx = graph.input("pvx")       # Particle X velocity
let pvy = graph.input("pvy")       # Particle Y velocity
let page = graph.input("page")     # Particle age
let plife = graph.input("plife")   # Remaining lifetime
let frame = graph.input("frame")   # Global frame counter
let time = graph.input("time")     # Time in seconds
```

### Math Nodes
Basic operations:
```nim
let add = graph.math("add")        # Add two inputs
let mul = graph.math("mul")        # Multiply two inputs
let map = graph.math("map")        # Remap range
map.mathParams = @[inMin, inMax, outMin, outMax]
```

### Wave Nodes
Oscillations:
```nim
let sine = graph.wave("sin")       # Sine wave (0-1000)
let cos = graph.wave("cos")        # Cosine wave
let saw = graph.wave("saw")        # Sawtooth
```

### Noise Nodes
Randomness:
```nim
let noise = graph.noise("white")          # Random noise
let fractal = graph.noise("fractal",      # Layered noise
                         scale=20,
                         octaves=3)
```

### Polar Nodes
Angle/distance from a point:
```nim
let angle = graph.polar("angle")
angle.centerX = 40.0
angle.centerY = 12.0

let dist = graph.polar("distance")
dist.centerX = 40.0
dist.centerY = 12.0
```

### Color Nodes
Color palettes:
```nim
let colors = graph.color("fire", 0, 255)    # Fire palette
let plasma = graph.color("plasma", 0, 255)  # Plasma colors
let neon = graph.color("neon", 0, 255)      # Neon colors
```

### Output Nodes
Final outputs:
```nim
let outNode = graph.valueOut()      # Single value output
let bufOut = graph.bufferOut()      # Visual/color output
```

## Example Recipes

### Recipe 1: Gravity + Wind
```nim
var graph = newGraph()
let g = graph.constant(9.8)
let w = graph.noise("white", scale=100)
let wScaled = graph.math("map")
wScaled.mathParams = @[0.0, 65535.0, -3.0, 3.0]
w.connect(wScaled)

let force = graph.math("add")
g.connect(force)
wScaled.connect(force)

let outNode = graph.valueOut()
force.connect(outNode)
```

### Recipe 2: Speed-Based Color
```nim
var graph = newGraph()
let vx = graph.input("pvx")
let vy = graph.input("pvy")

# Calculate speed squared
let vxSq = graph.math("mul")
vx.connect(vxSq)
vx.connect(vxSq)

let vySq = graph.math("mul")
vy.connect(vySq)
vy.connect(vySq)

let speedSq = graph.math("add")
vxSq.connect(speedSq)
vySq.connect(speedSq)

# Map to color
let colorVal = graph.math("map")
colorVal.mathParams = @[0.0, 400.0, 0.0, 255.0]
speedSq.connect(colorVal)

let colors = graph.color("neon", 0, 255)
colorVal.connect(colors)

let outNode = graph.bufferOut()
colors.connect(outNode)
```

### Recipe 3: Vortex Motion
```nim
var graph = newGraph()
let px = graph.input("px")
let py = graph.input("py")

# Get angle from center
let angle = graph.polar("angle")
angle.centerX = centerX
angle.centerY = centerY
px.connect(angle)
py.connect(angle)

# Rotate 90° for tangential motion
let tangent = graph.math("add")
angle.connect(tangent)
graph.constant(900.0).connect(tangent)  # 90° in decidegrees

# Convert to velocity
let vx = graph.wave("cos")
tangent.connect(vx)

let strength = graph.constant(5.0)
let force = graph.math("mul")
vx.connect(force)
strength.connect(force)

let outNode = graph.valueOut()
force.connect(outNode)
```

## Demos

Try these demos to see the system in action:

1. **nodeparticles.md** - Interactive showcase of 6 different effects
2. **particle_graphs.nim** - Code examples (in examples/ folder)
3. **PARTICLE_GRAPH_DESIGN.md** - Full technical documentation

## Tips

1. **Start with presets** - Use `configureRainGraph()` etc. as templates
2. **Use math("map")** liberally - It's essential for scaling values
3. **Debug with constants** - Replace complex nodes with constants to isolate issues
4. **Combine effects** - Multiple forces in one graph create complex behavior
5. **Think in pipelines** - Data flows through nodes like water through pipes

## Performance

- Graphs are evaluated per-particle per-frame
- Keep graphs shallow (< 20 nodes) for best performance
- Spatial effects are expensive (per-pixel evaluation)
- Use hybrid mode sparingly - it's powerful but costly

## Migration from Old System

Old hardcoded parameters still work! The system is backward compatible:

```nim
# Old way (still works)
ps.gravity = 9.8
ps.windForce = (2.0, 0.0)

# New way (more flexible)
ps.motionGraph = customMotionGraph
```

You can mix and match - use old-style for simple effects, graphs for complex ones.

## Next Steps

1. Run `./ts nodeparticles` to see the system in action
2. Read `docs/PARTICLE_GRAPH_DESIGN.md` for architecture details
3. Check `examples/particle_graphs.nim` for code examples
4. Experiment with graph builders in your own projects

Happy particle crafting! 🎆
