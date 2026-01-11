---
title: "Node-Based Particle System"
theme: "catppuccin"
minWidth: 80
minHeight: 24
---

# Node-Based Particle System

Welcome to the new graph-driven particle system! Instead of hardcoded behaviors,
particles now use composable node graphs from our primitives library.

**Controls:**
- **[Space]** - Pause/Resume
- **[1-6]** - Switch between demos
- **[Click left/right]** - Navigate demos
- **[Q]** - Quit

```nim on:init
# Initialize demo state
var frame = 0
var paused = 0
var currentDemo = 1
var numDemos = 6
var emitCounter = 0.0

# Create particle systems for each demo
particleInit("rain", 200)
particleInit("vortex", 300)
particleInit("explosion", 400)
particleInit("matrix", 100)
particleInit("custom", 200)
particleInit("ripple", 500)

# Demo 1: Rain with Graph-Based Motion
particleConfigureRain("rain", 50.0)
particleSetEmitterShape("rain", 1)
particleSetEmitterSize("rain", float(termWidth), 1.0)
particleSetEmitterPos("rain", 0.0, 0.0)

# Demo 2: Vortex - NEW graph-based circular motion
var centerX = float(termWidth) / 2.0
var centerY = float(termHeight) / 2.0
particleConfigureVortex("vortex", centerX, centerY, 1.0)
particleSetEmitterPos("vortex", centerX, centerY)

# Demo 3: Radial Explosion - NEW graph-based burst
particleConfigureRadialExplosion("explosion", centerX, centerY)

# Demo 4: Matrix Hybrid - NEW particles + spatial trails
particleConfigureMatrixHybrid("matrix", 20.0)
particleSetEmitterSize("matrix", float(termWidth), 1.0)
particleSetEmitterPos("matrix", 0.0, 0.0)

# Demo 5: Custom Multi-Force - NEW complex graph
particleConfigureCustomGraph("custom", 9.8, 3.0)
particleSetEmitterSize("custom", float(termWidth), 1.0)
particleSetEmitterPos("custom", float(termWidth) / 2.0, 0.0)

# Demo 6: Ripple Field - NEW pure spatial effect
particleConfigureRippleField("ripple")
particleSetEmitterSize("ripple", float(termWidth), 1.0)
particleSetEmitterPos("ripple", 0.0, 0.0)

# Build demo names array
var demoNames = []
demoNames = demoNames + ["1. Rain - Traditional (baseline)"]
demoNames = demoNames + ["2. Vortex - Graph Polar Motion"]
demoNames = demoNames + ["3. Explosion - Graph Radial Burst"]
demoNames = demoNames + ["4. Matrix - Hybrid Trails"]
demoNames = demoNames + ["5. Custom - Multi-Force Graph"]
demoNames = demoNames + ["6. Ripple - Spatial Field"]

print "Particle system initialized with 6 NEW graph-based demos"
```

```nim on:update
if paused == 0:
  frame = frame + 1
  
  var dt = 1.0 / 60.0
  
  # Only update the active particle system
  if currentDemo == 1:
    particleUpdate("rain", dt)
  elif currentDemo == 2:
    particleUpdate("vortex", dt)
  elif currentDemo == 3:
    emitCounter = emitCounter + dt
    if emitCounter > 2.0:
      var explodeX = float(10 + randInt(termWidth - 20))
      var explodeY = float(5 + randInt(termHeight - 10))
      particleSetEmitterPos("explosion", explodeX, explodeY)
      particleEmit("explosion", 80)
      emitCounter = 0.0
    particleUpdate("explosion", dt)
  elif currentDemo == 4:
    particleUpdate("matrix", dt)
  elif currentDemo == 5:
    particleUpdate("custom", dt)
  elif currentDemo == 6:
    particleUpdate("ripple", dt)
```

```nim on:render
# Clear screen
clear()

# Render the active demo
if currentDemo == 1:
  particleRender("rain", 0)
elif currentDemo == 2:
  particleRender("vortex", 0)
elif currentDemo == 3:
  particleRender("explosion", 0)
elif currentDemo == 4:
  particleRender("matrix", 0)
elif currentDemo == 5:
  particleRender("custom", 0)
elif currentDemo == 6:
  particleRender("ripple", 0)

# UI - Demo title
var titleStyle = defaultStyle()
titleStyle.fg = cyan()
titleStyle.bold = 1
var demoTitle = demoNames[currentDemo - 1]
draw(0, 2, 1, demoTitle, titleStyle)

# UI - Stats
var statsY = termHeight - 3
var statStyle = defaultStyle()
statStyle.fg = rgb(150, 150, 150)

var activeCount = 0
if currentDemo == 1:
  activeCount = particleGetCount("rain")
elif currentDemo == 2:
  activeCount = particleGetCount("vortex")
elif currentDemo == 3:
  activeCount = particleGetCount("explosion")
elif currentDemo == 4:
  activeCount = particleGetCount("matrix")
elif currentDemo == 5:
  activeCount = particleGetCount("custom")
elif currentDemo == 6:
  activeCount = particleGetCount("ripple")

var statsText = "Active Particles: " & $activeCount & " | Frame: " & $frame
if paused == 1:
  statsText = statsText & " [PAUSED]"
draw(0, 2, statsY, statsText, statStyle)

# UI - Controls
var ctrlStyle = defaultStyle()
ctrlStyle.fg = rgb(100, 100, 100)
draw(0, 2, statsY + 1, "Space: Pause | 1-6: Switch | Click L/R: Navigate | Q: Quit", ctrlStyle)

# Demo-specific information
var infoY = 3
var infoStyle = defaultStyle()
infoStyle.fg = rgb(180, 180, 180)

if currentDemo == 1:
  draw(0, 2, infoY, "Rain uses a motion graph: gravity + noise-based wind", infoStyle)
  draw(0, 2, infoY + 1, "Graph nodes: constant(15) + noise(fractal) → velocity", infoStyle)
  
elif currentDemo == 2:
  draw(0, 2, infoY, "Vortex uses polar coordinates for circular motion", infoStyle)
  draw(0, 2, infoY + 1, "Graph nodes: polar(angle) + wave(cos) → tangent force", infoStyle)
  
elif currentDemo == 3:
  draw(0, 2, infoY, "Radial explosion from random points every 2 seconds", infoStyle)
  draw(0, 2, infoY + 1, "Graph nodes: polar(angle, dist) + decay → radial force", infoStyle)
  
elif currentDemo == 4:
  draw(0, 2, infoY, "Matrix effect - particles leave trails using spatial graphs", infoStyle)
  draw(0, 2, infoY + 1, "Hybrid mode: particle motion + buffer fade effects", infoStyle)
  
elif currentDemo == 5:
  draw(0, 2, infoY, "Complex behavior: gravity + wind + sine wave oscillation", infoStyle)
  draw(0, 2, infoY + 1, "Multiple forces combined in a single motion graph", infoStyle)
  
elif currentDemo == 6:
  draw(0, 2, infoY, "Ripple displacement field - particles distorted by water-like waves", infoStyle)
  draw(0, 2, infoY + 1, "Spatial graph: polar(distance) + wave(sin) → buffer displacement", infoStyle)
```

```nim on:input
if event.type == "text":
  var key = event.text
  
  # Space - pause/unpause
  if key == " ":
    if paused == 0:
      paused = 1
    else:
      paused = 0
  
  # Q - quit
  if key == "q" or key == "Q":
    stop()

if event.type == "key":
  var key = event.key
  # Number keys - switch demo
  if key == "1":
    currentDemo = 1
    particleClear("rain")
  if key == "2":
    currentDemo = 2
    particleClear("vortex")
  if key == "3":
    currentDemo = 3
    particleClear("explosion")
    emitCounter = 0.0
  if key == "4":
    currentDemo = 4
    particleClear("matrix")
  if key == "5":
    currentDemo = 5
    particleClear("custom")
  if key == "6":
    currentDemo = 6
    particleClear("ripple")

if event.type == "mouse":
  if event.action == "press":
    var mouseX = event.x
    var leftThird = termWidth / 3
    var rightThird = (termWidth * 2) / 3
    
    if mouseX < leftThird:
      # Click on left side - previous demo
      currentDemo = currentDemo - 1
      if currentDemo < 1:
        currentDemo = numDemos
      if currentDemo == 1:
        particleClear("rain")
      elif currentDemo == 2:
        particleClear("vortex")
      elif currentDemo == 3:
        particleClear("explosion")
        emitCounter = 0.0
      elif currentDemo == 4:
        particleClear("matrix")
      elif currentDemo == 5:
        particleClear("custom")
      elif currentDemo == 6:
        particleClear("ripple")
    elif mouseX > rightThird:
      # Click on right side - next demo
      currentDemo = currentDemo + 1
      if currentDemo > numDemos:
        currentDemo = 1
      if currentDemo == 1:
        particleClear("rain")
      elif currentDemo == 2:
        particleClear("vortex")
      elif currentDemo == 3:
        particleClear("explosion")
        emitCounter = 0.0
      elif currentDemo == 4:
        particleClear("matrix")
      elif currentDemo == 5:
        particleClear("custom")
      elif currentDemo == 6:
        particleClear("ripple")
```

## Technical Details

### What Makes This Different?

**Old System:** Hardcoded parameters
```nim
ps.gravity = 9.8
ps.turbulence = 3.0
ps.windForce = (2.0, 0.0)
```

**New System:** Composable graph nodes
```nim
var graph = newGraph()
let gravity = graph.constant(9.8)
let noise = graph.noise("fractal")
let wind = graph.math("mul")
noise → wind ← constant(3.0)
gravity + wind → totalForce → output
```

### Available Primitives

**Motion Nodes:**
- Constants, inputs (position, velocity, age)
- Math ops (add, mul, map, clamp)
- Waves (sin, cos, saw, square)
- Noise (white, fractal, perlin)
- Polar coordinates (angle, distance)

**Effect Modes:**
1. **pemParticles** - Traditional particles with graph behavior
2. **pemSpatialField** - No particles, pure buffer effects
3. **pemHybrid** - Particles + spatial effects combined

### Use Cases

**Gameplay:**
- Fire/smoke with realistic physics
- Magic effects with custom motion
- Weather systems with layered complexity

**Visuals:**
- Dynamic backgrounds
- Transitions and reveals
- Data visualization particles

**Audio:**
- Spectrum analyzers
- Beat-reactive effects
- Sound-driven animations

Try switching between demos to see the variety of effects possible with the
same unified system!
