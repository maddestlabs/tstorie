# Unified Node Graph System

The heart of tStorie's architecture - a single dataflow graph engine that handles audio processing, visual effects, and reactive control using the same composable node pattern.

## Overview

Inspired by WebAudio's proven node architecture, tStorie's graph system extends the concept to be domain-agnostic:

| Domain | What It Processes | Rate | Example |
|--------|------------------|------|---------|
| **Audio** | Time-domain signals | 44.1kHz samples | Oscillator → Filter → Speaker |
| **Visual** | Spatial-domain data | 60fps per pixel | Noise → Wave → Color → Buffer |
| **Control** | Scalar parameters | Per frame | MouseX → Map → Particle.emit |

All three use the **same graph, same nodes, same evaluation model**.

## Architecture

```
┌─────────────────────────────────────────┐
│   User Code (nimini or native)          │
│   - Build graphs declaratively           │
│   - Connect nodes together               │
│   - Set parameters                       │
├─────────────────────────────────────────┤
│   Graph Engine (lib/graph.nim)           │
│   - Pull-based evaluation                │
│   - Domain-agnostic nodes                │
│   - Cycle detection                      │
│   - Caching & optimization               │
├─────────────────────────────────────────┤
│   Primitives (lib/primitives.nim)        │
│   - isin/icos (audio & visual waves)    │
│   - noise (audio & visual)               │
│   - easing (audio envelopes & visual)   │
│   - color palettes                       │
├─────────────────────────────────────────┤
│   Platform Backend                       │
│   - WASM: WebAudio nodes                │
│   - Native: miniaudio nodes             │
└─────────────────────────────────────────┘
```

## Core Concepts

### 1. **Nodes** - Building Blocks

Every node has:
- **Inputs**: Where data comes from (0+ connections)
- **Outputs**: Where data goes (0+ connections)
- **Domain**: What it processes (audio/visual/control)
- **Kind**: What it does (oscillator, wave, color, etc.)

```nim
# Source nodes (generate data)
let osc = graph.oscillator("sine", 440.0)      # Audio oscillator
let noise = graph.noise("fractal", seed=42)    # Visual noise
let inputX = graph.input("x")                  # Context input

# Transform nodes (process data)
let filter = graph.wave("sin")                 # Wave transform
let colors = graph.color("plasma")             # Color mapping
let ease = graph.easing("inOutQuad")          # Easing curve

# Output nodes (terminal)
let speaker = graph.audioOut()                 # Audio destination
let buffer = graph.bufferOut()                # Visual destination
```

### 2. **Connections** - Dataflow

Nodes connect to form a directed graph:

```nim
# Method 1: Explicit connection
osc.connect(speaker)

# Method 2: Fluent chaining  
noise.connect(filter).connect(colors).connect(buffer)

# Method 3: Operator syntax (syntactic sugar)
osc -> speaker
```

Data flows **pull-based** (like WebAudio):
1. Evaluate output nodes
2. Output nodes pull from their inputs
3. Inputs recursively pull from their inputs
4. Source nodes generate data

This ensures:
- Only used nodes are evaluated
- No wasted computation
- Natural scheduling

### 3. **Evaluation Context** - Dynamic Inputs

The graph evaluates within a context:

```nim
# Visual context (per-pixel)
context.x = 10
context.y = 20
context.frame = 100

# Audio context (per-sample)
context.sampleIndex = 4410
context.time = 0.1
context.sampleRate = 44100

# Custom inputs
context.custom["mouseX"] = 0.5
context.custom["volume"] = 0.8
```

Input nodes read from this context.

## Examples

### Example 1: Audio Synthesis (Pure Audio Domain)

```nim
var graph = newGraph()

# Create nodes
let osc = graph.oscillator("sine", 440.0)     # 440 Hz sine wave
let gain = graph.math("mul")                   # Volume control
let volume = graph.constant(0.5)               # 50% volume
let out = graph.audioOut()                     # Speaker destination

# Connect graph
osc.connect(gain)
volume.connect(gain)
gain.connect(out)

# Evaluate for audio samples
for i in 0 ..< 1024:
  let sample = graph.evaluateForAudioSample(i, float(i) / 44100.0)
  # Send sample to audio output...
```

This generates a 440Hz sine wave at 50% volume.

### Example 2: Visual Effect (Pure Visual Domain)

```nim
var graph = newGraph()

# Create plasma effect using primitives
let x = graph.input("x")
let y = graph.input("y")
let frame = graph.input("frame")

# Wave 1: Horizontal
let wave1 = graph.wave("sin")
let xScaled = graph.math("mul")
x.connect(xScaled)
graph.constant(10.0).connect(xScaled)
xScaled.connect(wave1)

# Wave 2: Vertical
let wave2 = graph.wave("cos")
let yScaled = graph.math("mul")
y.connect(yScaled)
graph.constant(15.0).connect(yScaled)
yScaled.connect(wave2)

# Combine waves
let combined = graph.math("add")
wave1.connect(combined)
wave2.connect(combined)

# Map to color
let colors = graph.color("plasma", -2000, 2000)
combined.connect(colors)

# Output to buffer
let out = graph.bufferOut()
colors.connect(out)

# Evaluate per pixel
for y in 0 ..< height:
  for x in 0 ..< width:
    let output = graph.evaluateForPixel(x, y)
    # Draw output.visualColor to buffer...
```

This creates an animated plasma effect.

### Example 3: Audio Visualization (Cross-Domain)

```nim
var graph = newGraph()

# Audio path: Generate tone
let osc = graph.oscillator("sine", 220.0)
let audioOut = graph.audioOut()
osc.connect(audioOut)

# Visual path: Sample from SAME oscillator
let abs = graph.math("abs")              # Rectify audio signal
osc.connect(abs)                         # <- Same oscillator!

let scale = graph.math("mul")            # Scale to visual range
abs.connect(scale)
graph.constant(100.0).connect(scale)

let colors = graph.color("heatmap", 0, 100)
scale.connect(colors)

let visualOut = graph.bufferOut()
colors.connect(visualOut)

# Now audio AND visuals are driven by the same oscillator!
# Changing osc.frequency affects both sound and appearance
```

### Example 4: Reactive Control (Visual → Audio)

```nim
var graph = newGraph()

# Visual input (e.g., mouse position)
let mouseX = graph.input("mouseX")      # 0..1 range

# Map to frequency (200-2000 Hz)
let freq = graph.math("map")
freq.mathParams = @[0.0, 1.0, 200.0, 2000.0]
mouseX.connect(freq)

# Connect to oscillator
let osc = graph.oscillator("sine")
freq.connect(osc)  # <- Frequency controlled by mouse!

let out = graph.audioOut()
osc.connect(out)

# Update context with mouse position
graph.context.custom["mouseX"] = mouseX / width
```

Mouse position now controls the pitch!

### Example 5: Ripple Displacement (Buffer Transformation)

```nim
var graph = newGraph()

# Get pixel position
let x = graph.input("x")
let y = graph.input("y")
let frame = graph.input("frame")

# Calculate distance from center
let dist = graph.polar("distance", 
                       centerX = width / 2, 
                       centerY = height / 2)
x.connect(dist)
y.connect(dist)

# Create ripple wave
let rippleWave = graph.wave("sin")
let distScaled = graph.math("mul")
dist.connect(distScaled)
graph.constant(20.0).connect(distScaled)

let frameScaled = graph.math("mul")
frame.connect(frameScaled)
graph.constant(-10.0).connect(frameScaled)

let phase = graph.math("add")
distScaled.connect(phase)
frameScaled.connect(phase)

phase.connect(rippleWave)

# Map to displacement
let displacement = graph.math("map")
displacement.mathParams = @[-1000.0, 1000.0, -5.0, 5.0]
rippleWave.connect(displacement)

let out = graph.bufferOut()
displacement.connect(out)

# Use displacement to sample from buffer
for y in 0 ..< height:
  for x in 0 ..< width:
    let disp = graph.evaluateForPixel(x, y)
    let sourceX = x + int(disp.controlValue)
    let sourceY = y
    # Sample from (sourceX, sourceY) and write to (x, y)
```

This creates a water ripple displacement effect.

## Advantages

### 1. **Unified Learning**
Learn the graph pattern once, apply everywhere:
- Audio synthesis? Build a graph
- Visual effects? Build a graph
- Transitions? Build a graph
- Reactive control? Build a graph

### 2. **Cross-Domain Composition**
Audio and visual naturally interact:
```nim
audioLevel → particleEmitRate
bassFrequency → colorPalette
mousePosition → synthPitch
```

### 3. **WebAudio Compatibility**
The API mirrors WebAudio, so:
- In WASM: Can map directly to actual WebAudio nodes
- In native: Use miniaudio with same API
- Code works identically on both platforms

### 4. **Primitives Power Everything**
All nodes use `lib/primitives.nim` functions:
- `isin()` for both audio sine waves and visual ripples
- `fractalNoise2D()` for both audio noise and visual textures
- `easeInQuad()` for both audio envelopes and visual animations
- `colorPlasma()` for visual effects

No duplication - one math library, used everywhere.

### 5. **Performance**
- Pull-based evaluation (no wasted computation)
- Cached results (nodes evaluated once per cycle)
- Native tight loops (no scripting overhead)
- Works at audio rate (44.1kHz) and visual rate (60fps per 1000s of pixels)

## Integration with Particle System

The particle system can now USE graphs instead of hardcoded behaviors:

```nim
# Old way (hardcoded)
ps.gravity = 9.8
ps.turbulence = 3.0

# New way (graph-based)
var motionGraph = newGraph()
let noise = motionGraph.noise("fractal")
let displacement = motionGraph.math("map")
noise.connect(displacement)
ps.motionGraph = motionGraph

# Particles evaluate the graph for their motion
# Much more flexible!
```

## Next Steps

1. **Audio Graph Nodes** - Wrap miniaudio filters, delays, etc. as nodes
2. **Visual Graph Nodes** - More specialized visual effect nodes
3. **Buffer Operations** - Apply graphs to entire buffers efficiently
4. **Graph Serialization** - Save/load graph configurations
5. **Visual Graph Editor** - GUI for building graphs (future)

## See Also

- [lib/primitives.nim](lib/primitives.nim) - Foundation functions used by nodes
- [lib/graph.nim](lib/graph.nim) - Core graph implementation
- [SHADER_PRIMITIVES.md](SHADER_PRIMITIVES.md) - Visual primitives overview
- [WebAudio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API) - Inspiration
