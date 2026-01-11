## Example: Graph-Based Particle System
## 
## Demonstrates the new node-based particle system that uses
## modular graph primitives for flexible particle behaviors.

import ../lib/particles
import ../lib/graph
import ../lib/primitives
import ../src/layers  # For TermBuffer operations
import ../src/types    # For Style, Color types

# ================================================================
# Example 1: Rain with Motion Graph
# ================================================================

proc example1_rainWithGraphs*(buffer: var TermBuffer) =
  ## Traditional rain effect using graph-based motion
  
  var ps = initParticleSystem(100)
  ps.effectMode = pemParticles
  
  # Use preset graph builders
  let (motionGraph, colorGraph, charGraph) = configureRainGraph()
  ps.motionGraph = motionGraph
  ps.colorGraph = colorGraph
  ps.characterGraph = charGraph
  
  ps.chars = @["|", "¦", "│"]
  ps.emitRate = 50.0
  ps.emitterShape = esLine
  ps.emitterSize.x = float(buffer.width)
  
  # Update and render
  ps.update(0.016)  # ~60 fps
  ps.render(buffer)

# ================================================================
# Example 2: Custom Vortex Effect
# ================================================================

proc example2_customVortex*(buffer: var TermBuffer) =
  ## Particles swirl around a center point
  
  var ps = initParticleSystem(200)
  ps.effectMode = pemParticles
  
  let centerX = float(buffer.width) / 2.0
  let centerY = float(buffer.height) / 2.0
  
  # Use vortex graph builder
  ps.motionGraph = configureVortexGraph(centerX, centerY)
  
  # Custom color: speed-based coloring
  var colorGraph = newGraph()
  let pvx = colorGraph.input("pvx")
  let pvy = colorGraph.input("pvy")
  
  # Calculate speed magnitude
  let vxSq = colorGraph.math("mul")
  pvx.connect(vxSq)
  pvx.connect(vxSq)
  
  let vySq = colorGraph.math("mul")
  pvy.connect(vySq)
  pvy.connect(vySq)
  
  let speedSq = colorGraph.math("add")
  vxSq.connect(speedSq)
  vySq.connect(speedSq)
  
  # Map to color
  let colorVal = colorGraph.math("map")
  colorVal.mathParams = @[0.0, 400.0, 0.0, 255.0]
  speedSq.connect(colorVal)
  
  let colors = colorGraph.color("neon", 0, 255)
  colorVal.connect(colors)
  let outNode = colorGraph.bufferOut()
  colors.connect(outNode)
  
  ps.colorGraph = colorGraph
  ps.chars = @["*", "+", "·", "•"]
  
  # Emit from center
  ps.emitterShape = esPoint
  ps.emitterPos.x = centerX
  ps.emitterPos.y = centerY
  ps.emitRate = 30.0
  
  ps.update(0.016)
  ps.render(buffer)

# ================================================================
# Example 3: Audio-Reactive Particles
# ================================================================

proc example3_audioReactive*(buffer: var TermBuffer, audioLevel: float) =
  ## Emission and color respond to audio input
  
  var ps = initParticleSystem(500)
  ps.effectMode = pemParticles
  
  # Emission graph: More particles on loud sounds
  var emissionGraph = newGraph()
  let audio = emissionGraph.input("audioLevel")
  let emitCount = emissionGraph.math("mul")
  audio.connect(emitCount)
  emissionGraph.constant(100.0).connect(emitCount)
  let outNode1 = emissionGraph.valueOut()
  emitCount.connect(outNode1)
  ps.emissionGraph = emissionGraph
  
  # Motion: Radial explosion
  let centerX = float(buffer.width) / 2.0
  let centerY = float(buffer.height) / 2.0
  ps.motionGraph = configureExplosionGraph((centerX, centerY))
  
  # Color: Audio level determines brightness
  var colorGraph = newGraph()
  let audioIn = colorGraph.input("audioLevel")
  let colors = colorGraph.color("fire", 0, 255)
  audioIn.connect(colors)
  let outNode2 = colorGraph.bufferOut()
  colors.connect(outNode2)
  ps.colorGraph = colorGraph
  
  ps.chars = @["*", "@", "#", "+"]
  ps.emitterShape = esPoint
  ps.emitterPos.x = centerX
  ps.emitterPos.y = centerY
  
  # Update context with audio level
  ps.particleContext.custom["audioLevel"] = audioLevel
  ps.spatialContext.custom["audioLevel"] = audioLevel
  
  ps.update(0.016)
  ps.render(buffer)

# ================================================================
# Example 4: Hybrid Mode - Matrix Rain
# ================================================================

proc example4_matrixRain*(buffer: var TermBuffer) =
  ## Particles create trails that fade using spatial effects
  
  var ps = initParticleSystem(50)
  ps.effectMode = pemHybrid
  ps.effectFlags = (
    replaceChar: true,
    replaceColor: true,
    modulateColor: false,
    displace: false,
    emit: false
  )
  
  # Motion: Straight down
  var motionGraph = newGraph()
  let downForce = motionGraph.constant(10.0)
  let outNode1 = motionGraph.valueOut()
  downForce.connect(outNode1)
  ps.motionGraph = motionGraph
  
  # Color: Bright at head, fading
  var colorGraph = newGraph()
  let lifeFrac = colorGraph.input("plifeFraction")
  let colorVal = colorGraph.math("map")
  colorVal.mathParams = @[0.0, 1.0, 255.0, 50.0]
  lifeFrac.connect(colorVal)
  let matrixColors = colorGraph.color("matrix", 0, 255)
  colorVal.connect(matrixColors)
  let outNode2 = colorGraph.bufferOut()
  matrixColors.connect(outNode2)
  ps.colorGraph = colorGraph
  
  # Spatial: Trail fade effect
  ps.spatialColorGraph = configureMatrixTrailGraph()
  
  ps.chars = @["0", "1", "2", "3", "4", "5", "A", "B", "Z"]
  ps.emitRate = 20.0
  ps.emitterShape = esLine
  ps.emitterSize.x = float(buffer.width)
  
  ps.update(0.016)
  ps.render(buffer)

# ================================================================
# Example 5: Pure Spatial Effect - Water Ripple
# ================================================================

proc example5_waterRipple*(buffer: var TermBuffer, mouseX, mouseY: int) =
  ## No particles - just spatial displacement field
  
  var ps = initParticleSystem(0)  # No particles needed!
  ps.effectMode = pemSpatialField
  ps.effectFlags = (
    replaceChar: false,
    replaceColor: false,
    modulateColor: false,
    displace: true,
    emit: false
  )
  
  # Create ripple from mouse position
  ps.spatialDisplacementGraph = configureRippleDisplacementGraph()
  
  # Update mouse position in context
  ps.spatialContext.custom["mouseX"] = float(mouseX)
  ps.spatialContext.custom["mouseY"] = float(mouseY)
  
  # Could also update the polar node centers directly:
  # (would need to traverse graph and find polar nodes)
  
  ps.update(0.016)
  ps.render(buffer)

# ================================================================
# Example 6: Complex Custom Graph
# ================================================================

proc example6_complexBehavior*(buffer: var TermBuffer) =
  ## Build a complex motion graph from scratch
  
  var ps = initParticleSystem(150)
  ps.effectMode = pemParticles
  
  # Motion: Gravity + wind noise + sine wave oscillation
  var motionGraph = newGraph()
  
  # Input: particle Y position
  let py = motionGraph.input("py")
  let time = motionGraph.input("frame")
  
  # Gravity component
  let gravity = motionGraph.constant(9.8)
  
  # Wind (horizontal noise)
  let windNoise = motionGraph.noise("fractal", scale=30, octaves=2)
  py.connect(windNoise)
  let wind = motionGraph.math("map")
  wind.mathParams = @[0.0, 65535.0, -3.0, 3.0]
  windNoise.connect(wind)
  
  # Sine wave oscillation
  let sinePhase = motionGraph.math("mul")
  time.connect(sinePhase)
  motionGraph.constant(0.1).connect(sinePhase)
  
  let sineWave = motionGraph.wave("sin")
  sinePhase.connect(sineWave)
  
  let sineScaled = motionGraph.math("map")
  sineScaled.mathParams = @[0.0, 1000.0, -2.0, 2.0]
  sineWave.connect(sineScaled)
  
  # Combine all forces
  let forceY = motionGraph.math("add")
  gravity.connect(forceY)
  
  let forceX = motionGraph.math("add")
  wind.connect(forceX)
  sineScaled.connect(forceX)
  
  # For now, output just Y force (would need multi-output support)
  let outNode = motionGraph.valueOut()
  forceY.connect(outNode)
  
  ps.motionGraph = motionGraph
  
  # Age-based characters
  var charGraph = newGraph()
  let age = charGraph.input("page")
  let charIdx = charGraph.math("map")
  charIdx.mathParams = @[0.0, 2.0, 0.0, 3.0]
  age.connect(charIdx)
  let charOut = charGraph.valueOut()
  charIdx.connect(charOut)
  ps.characterGraph = charGraph
  
  ps.chars = @[".", "o", "O", "@"]
  ps.emitRate = 25.0
  ps.emitterShape = esLine
  ps.emitterSize.x = float(buffer.width)
  
  ps.update(0.016)
  ps.render(buffer)

# ================================================================
# Main Demo
# ================================================================

when isMainModule:
  import ../src/types
  
  # Initialize buffer
  var buffer = newTermBuffer(80, 24)
  
  echo "Graph-Based Particle System Examples"
  echo "====================================="
  echo ""
  echo "This demonstrates the new node-based particle system"
  echo "where particle behaviors are defined using composable"
  echo "graph primitives instead of hardcoded parameters."
  echo ""
  echo "Examples included:"
  echo "  1. Rain with motion graphs"
  echo "  2. Custom vortex effect"
  echo "  3. Audio-reactive particles"
  echo "  4. Hybrid mode - Matrix rain with trails"
  echo "  5. Pure spatial effect - water ripple"
  echo "  6. Complex custom graph behavior"
  echo ""
  echo "Compile successful! Integration ready."
