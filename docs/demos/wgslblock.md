---
title: "WGSL Wave Effect Demo"
theme: "catppuccin"
---

# WGSL Wave Effect Demo

This demo showcases **GPU compute shaders** with **dynamic uniforms** in WGSL (WebGPU Shading Language).

Watch particles respond to mouse position with a rippling wave effect - all computed on the GPU!

## The Shader

This compute shader creates a wave effect with configurable parameters:

```wgsl compute:waveEffect
struct Uniforms {
    time: f32,
    mouseX: f32,
    mouseY: f32,
    amplitude: f32,
    frequency: f32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read> basePositions: array<vec2<f32>>;
@group(0) @binding(2) var<storage, read_write> positions: array<vec2<f32>>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
    let index = id.x;
    if (index >= arrayLength(&positions)) {
        return;
    }
    
    let basePos = basePositions[index];
    let mousePos = vec2<f32>(uniforms.mouseX, uniforms.mouseY);
    let dist = distance(basePos, mousePos);
    
    let wave = sin(dist * uniforms.frequency - uniforms.time) * uniforms.amplitude;
    positions[index] = basePos + vec2<f32>(0.0, wave);
}
```

```nim on:init
# Configuration
const GRID_WIDTH = 40
const GRID_HEIGHT = 20
const PARTICLE_COUNT = GRID_WIDTH * GRID_HEIGHT

# Particle data for GPU (flat arrays of vec2)
var basePositions = @[]  # Original positions (X,Y pairs)
var positions = @[]       # Current positions (X,Y pairs)

# Initialize particle grid
var py = 0
while py < GRID_HEIGHT:
  var px = 0
  while px < GRID_WIDTH:
    let x = float(px) / float(GRID_WIDTH - 1)
    let y = float(py) / float(GRID_HEIGHT - 1)
    basePositions.add(x)
    basePositions.add(y)
    positions.add(x)
    positions.add(y)
    px = px + 1
  py = py + 1

# Wave parameters
var time = 0.0
var mouseX = 0.5
var mouseY = 0.5
var amplitude = 0.1
var frequency = 10.0

# GPU status
var useGPU = false
var status = "Initializing..."
var shaderResult = false
if defined("web"):
  if webgpuSupported():
    if webgpuReady():
      status = "GPU compute enabled! Move your mouse!"
      useGPU = true
    else:
      status = "WebGPU initializing..."
  else:
    status = "WebGPU not supported in this browser"

echo ("Init complete:")
echo ("  Particles: " & $PARTICLE_COUNT)
echo ("  Base positions: " & $basePositions.len() )
echo ("  Positions: " & $positions.len() )
echo ("  useGPU: " & $useGPU)
echo ("  Status: " & status)
# Check if shaders were parsed
let shaderList = listShaders()
echo("Available shaders count: " & $shaderList.len())
if shaderList.len() > 0:
  echo("  Shader list works!")
  var idx = 0
  while idx < shaderList.len():
    echo("    Shader " & $idx & ": " & $shaderList[idx])
    idx = idx + 1
else:
  echo("  ERROR: No shaders in list!")

# Try getShader directly
let shaderStr = $getShader("waveEffect")
echo("getShader result: " & shaderStr)
if shaderStr == "nil":
  echo("  ERROR: waveEffect shader not found!")
else:
  echo("  Got waveEffect shader!")

# Debug: Show actual array structure  
echo("First 10 basePositions:")
var i = 0
while i < 10 and i < basePositions.len():
  let val = basePositions[i]
  echo("  [" & $i & "] = " & $val)
  i = i + 1
```

```nim on:update
time = time + 0.05

if useGPU and defined("web"):
  # Update shader uniforms using map literal syntax!
  updateShader("waveEffect", {time: time, mouseX: mouseX, mouseY: mouseY, amplitude: amplitude, frequency: frequency})
  
  # Run compute shader to update particle positions
  shaderResult = runComputeShader("waveEffect", basePositions, positions)
  if not shaderResult:
    status = "GPU compute failed!"
```

```nim on:render
# Debug: Check if render is being called
if frameCount mod 60 == 0:
  echo ("Render frame " & $frameCount & " - positions[0]=" & $positions[0] )

clear()

let w = termWidth
let h = termHeight

# Title
fillBox(0, 0, 0, w, 2, " ", getStyle("primary"))
drawLabel(0, 2, 0, "WGSL WAVE EFFECT - GPU COMPUTE", getStyle("warning"))

# Info panel
drawPanel(0, 2, 3, 35, 14, "GPU Status", "single")

drawLabel(0, 4, 5, "Particles:", getStyle("info"))
drawLabel(0, 15, 5, str(PARTICLE_COUNT), getStyle("success"))

drawLabel(0, 4, 7, "Amplitude:", getStyle("info"))
drawLabel(0, 15, 7, str(amplitude)[0..3], getStyle("default"))

drawLabel(0, 4, 9, "Frequency:", getStyle("info"))
drawLabel(0, 15, 9, str(frequency)[0..4], getStyle("default"))

drawLabel(0, 4, 11, "Mouse:", getStyle("info"))
drawLabel(0, 15, 11, str(mouseX)[0..3] & "," & str(mouseY)[0..3], getStyle("default"))

drawLabel(0, 4, 13, "Time:", getStyle("info"))
drawLabel(0, 15, 13, str(time)[0..4], getStyle("default"))

# Controls panel
drawPanel(0, 2, 19, 35, 9, "Controls", "rounded")
drawLabel(0, 4, 21, "+ / - Amplitude", getStyle("info"))
drawLabel(0, 4, 22, "[ / ] Frequency", getStyle("info"))
drawLabel(0, 4, 23, "Mouse - Move cursor", getStyle("info"))
drawLabel(0, 4, 24, "ESC - Exit", getStyle("info"))

# Render particles with displacement-based characters
var i = 0
while i < PARTICLE_COUNT * 2:
  let x = positions[i]
  let y = positions[i + 1]
  
  # Map to screen coordinates
  let screenX = int(x * float(w - 40)) + 40
  let screenY = int(y * float(h - 5)) + 3
  
  # Calculate displacement intensity for character selection
  let baseY = basePositions[i + 1]
  let displacement = abs(y - baseY)
  
  var ch = "."
  if displacement > 0.08:
    ch = "@"
  elif displacement > 0.05:
    ch = "o"
  elif displacement > 0.02:
    ch = "*"
  
  # Draw particle
  if screenX >= 40 and screenX < w and screenY >= 3 and screenY < h:
    var style = getStyle("dim")
    if displacement > 0.05:
      style = getStyle("success")
    elif displacement > 0.02:
      style = getStyle("info")
    drawLabel(0, screenX, screenY, ch, style)
  
  i = i + 2

# Mouse cursor indicator (draw over particles)
let cursorScreenX = int(mouseX * float(w - 40)) + 40
let cursorScreenY = int(mouseY * float(h - 5)) + 3
if cursorScreenX >= 40 and cursorScreenX < w and cursorScreenY >= 3 and cursorScreenY < h:
  drawLabel(0, cursorScreenX, cursorScreenY, "+", getStyle("warning"))

# Status message
drawLabel(0, 2, h - 2, status, getStyle("warning"))

# Debug info - show first few particles
drawLabel(0, 2, h - 3, "First particle: x=" & str(positions[0])[0..4] & " y=" & str(positions[1])[0..4], getStyle("dim"))
drawLabel(0, 2, h - 4, "Rendering from col 40, rows 3-" & $(h-5), getStyle("dim"))
```

```nim on:input
if event.type == "text":
  let ch = event.text
  
  # Amplitude control
  if ch == "+":
    amplitude = amplitude + 0.01
    if amplitude > 0.3:
      amplitude = 0.3
  elif ch == "-":
    amplitude = amplitude - 0.01
    if amplitude < 0.0:
      amplitude = 0.0
  
  # Frequency control
  elif ch == "[":
    frequency = frequency - 0.5
    if frequency < 1.0:
      frequency = 1.0
  elif ch == "]":
    frequency = frequency + 0.5
    if frequency > 30.0:
      frequency = 30.0

elif event.type == "mouse":
  # Update mouse position for wave center
  let w = termWidth
  let h = termHeight
  
  if event.x >= 40 and event.x < w and event.y >= 3 and event.y < h:
    mouseX = float(event.x - 40) / float(w - 40)
    mouseY = float(event.y - 3) / float(h - 5)

elif event.type == "key":
  # ESC - Exit
  if event.keyCode == KEY_ESCAPE and event.action == "press":
    return false

return true
```

## What This Demonstrates

### ✅ WGSL Code Block
The `wgsl compute:doubleValues` block contains standard WGSL shader code. Tstorie automatically:
- Detects it's a compute shader (`@compute`)
- Extracts the workgroup size (64)
- Identifies storage bindings (input and output arrays)

### ✅ Auto-Detection
No manual registration! The parser finds:
- **Shader name**: `doubleValues` (from block header)
- **Entry point**: `main` (from `@compute` decorator)
- **Bindings**: 2 buffers (input + output storage)

### ✅ Simple API
One function call:
1. `runComputeShader(name, input, output)` - Execute on GPU
2. Results appear in output array automatically

### ✅ GPU Acceleration
- **100 values** processed in parallel on GPU
- Simple doubling operation per value
- Demonstrates basic GPU compute workflow
- Same pattern works for complex physics!

### ✅ Interactive Demo
- Press SPACE to run the shader
- See input/output comparison
- R to reset and run again

## How It Works

1. **Shader Definition**: WGSL code in markdown (just paste from examples!)
2. **Parse Time**: Tstorie extracts metadata automatically
3. **Runtime**: Shader compiled to GPU bytecode by browser
4. **Each Frame**:
   - Update uniforms with map literals: `{mouseX: x, mouseY: y, time: t, ...}`
   - Copy data to GPU buffers
   - Execute compute shader (1000 particles in parallel!)
   - Read results back
   - Render with updated positions

## Browser Support

**WebGPU Required:**
- ✅ Chrome/Edge 113+
- ✅ Safari 17+
- ❌ Firefox (in development)

**Fallback:** CPU mode (particles render but no wave effect)

## Try It Yourself!

1. Move your mouse over the particle grid
2. Watch the wave effect ripple from your cursor
3. Adjust amplitude with `+/-` keys
4. Change frequency with `[/]` keys
5. All computed on GPU in parallel!

---

*This demo uses the new `wgsl` code block feature. The shader runs entirely on your GPU!*
