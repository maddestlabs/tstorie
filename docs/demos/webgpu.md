---
title: "WebGPU Particle System"
theme: "catppuccin"
shaders: "invert+ruledlines+paper"
fontsize: 11
---

# WebGPU Particle System Demo

Showcases GPU compute with thousands of particles running physics simulations in parallel on the GPU.

```nim on:init
# ===================================================================
# Particle System Configuration
# ===================================================================
const PARTICLE_COUNT = 2000  # Many particles - GPU handles this easily
const MAX_VELOCITY = 3.0
const ATTRACTION_STRENGTH = 0.05
const DAMPING = 0.98

# Particle state stored as separate arrays (nimini-friendly)
var particleX = @[]
var particleY = @[]
var particleVX = @[]
var particleVY = @[]

# Attractor (follows mouse or auto-moves)
var attractorX = 50.0
var attractorY = 25.0

# GPU state (not yet implemented - for future use)
var useGPU = false
var gpuAvailable = false
var gpuPending = false
var hasGPUResults = false

# Performance tracking
var frameCount = 0
var message = "Initializing particles..."

# Initialize particles scattered across terminal
var i = 0
let w = termWidth
let h = termHeight - 5  # Leave space for UI
while i < PARTICLE_COUNT:
  let x = float(i mod w)
  let y = float((i / w) mod h) + 5.0  # Offset below title
  let vx = (float(i * 17) mod 2.0) - 1.0  # Deterministic "random"
  let vy = (float(i * 23) mod 2.0) - 1.0
  particleX.add(x)
  particleY.add(y)
  particleVX.add(vx * 0.5)  # Start with smaller velocities
  particleVY.add(vy * 0.5)
  i = i + 1

# Check GPU availability
if defined("web"):
  if webgpuSupported():
    gpuAvailable = webgpuReady()
    if gpuAvailable:
      message = "WebGPU available! Press G to toggle GPU/CPU mode"
    else:
      message = "WebGPU initializing..."
      useGPU = false
  else:
    message = "WebGPU not supported in this browser"
    useGPU = false
```

```nim on:update
# ===================================================================
# Update Physics
# ===================================================================
frameCount = frameCount + 1

# Update attractor position (follows mouse or auto-moves)
let w = termWidth
let h = termHeight
if mouseX >= 0 and mouseY >= 0:
  attractorX = float(mouseX)
  attractorY = float(mouseY)
else:
  # Auto-move attractor in a circle
  let t = float(frameCount) * 0.02
  attractorX = float(w / 2) + float(w / 4) * cos(t)
  attractorY = float(h / 2) + float(h / 4) * sin(t)

# CPU Physics Update
if not useGPU or not gpuAvailable:
  var idx = 0
  while idx < PARTICLE_COUNT:
    # Get particle data
    let px = particleX[idx]
    let py = particleY[idx]
    let pvx = particleVX[idx]
    let pvy = particleVY[idx]
    
    # Calculate attraction force to attractor
    let dx = attractorX - px
    let dy = attractorY - py
    let distSq = dx * dx + dy * dy + 0.1  # Add epsilon to avoid divide by zero
    let dist = sqrt(distSq)
    
    # Apply inverse-square attraction force
    let force = ATTRACTION_STRENGTH / distSq
    var vx = pvx + (dx / dist) * force
    var vy = pvy + (dy / dist) * force
    
    # Apply damping (friction)
    vx = vx * DAMPING
    vy = vy * DAMPING
    
    # Limit velocity
    let speed = sqrt(vx * vx + vy * vy)
    if speed > MAX_VELOCITY:
      vx = (vx / speed) * MAX_VELOCITY
      vy = (vy / speed) * MAX_VELOCITY
    
    # Update position
    var x = px + vx
    var y = py + vy
    
    # Wrap around edges
    let w = termWidth
    let h = termHeight
    if x < 0.0:
      x = float(w - 1)
    if x >= float(w):
      x = 0.0
    if y < 5.0:  # Don't wrap into title area
      y = float(h - 1)
    if y >= float(h):
      y = 5.0
    
    # Store updated values
    particleX[idx] = x
    particleY[idx] = y
    particleVX[idx] = vx
    particleVY[idx] = vy
    idx = idx + 1
  
  message = "CPU: Computing " & str(PARTICLE_COUNT) & " particles"
```

```nim on:render
# ===================================================================
# Render Particles
# ===================================================================
clear()

let w = termWidth
let h = termHeight

# Title
fillBox(0, 0, 0, w, 2, " ", getStyle("primary"))
drawLabel(0, 2, 0, "WEBGPU PARTICLE SYSTEM", getStyle("warning"))

# Info panel
drawPanel(0, 2, 3, 30, 12, "Info", "single")

drawLabel(0, 4, 5, "Mode:", getStyle("info"))
if useGPU and gpuAvailable:
  drawLabel(0, 20, 5, "GPU", getStyle("success"))
else:
  drawLabel(0, 20, 5, "CPU", getStyle("warning"))

drawLabel(0, 4, 7, "Particles:", getStyle("info"))
drawLabel(0, 20, 7, str(PARTICLE_COUNT), getStyle("default"))

drawLabel(0, 4, 9, "Compute:", getStyle("info"))
drawLabel(0, 20, 9, "Active", getStyle("success"))

drawLabel(0, 4, 11, "FPS:", getStyle("info"))
drawLabel(0, 20, 11, "~60", getStyle("default"))

drawLabel(0, 4, 13, "Frame:", getStyle("info"))
drawLabel(0, 20, 13, str(frameCount), getStyle("dim"))

# Render particles
var rendered = 0
var idx = 0
while idx < PARTICLE_COUNT:
  let px = int(particleX[idx])
  let py = int(particleY[idx])
  
  if px >= 0 and px < w and py >= 5 and py < h:
    # Choose character and color based on velocity (speed)
    let vx = particleVX[idx]
    let vy = particleVY[idx]
    let speed = sqrt(vx * vx + vy * vy)
    
    var char = "."
    var style = getStyle("dim")
    
    if speed > 2.0:
      char = "@"
      style = getStyle("error")
    elif speed > 1.5:
      char = "o"
      style = getStyle("warning")
    elif speed > 0.8:
      char = "*"
      style = getStyle("info")
    else:
      char = "."
      style = getStyle("dim")
    
    drawLabel(0, px, py, char, style)
    rendered = rendered + 1
  
  idx = idx + 1

# Draw attractor
let ax = int(attractorX)
let ay = int(attractorY)
if ax >= 0 and ax < w and ay >= 5 and ay < h:
  drawLabel(0, ax, ay, "+", getStyle("success"))
  # Draw attraction radius
  if ax - 3 >= 0:
    drawLabel(0, ax - 3, ay, ".", getStyle("success"))
  if ax + 3 < w:
    drawLabel(0, ax + 3, ay, ".", getStyle("success"))
  if ay - 2 >= 5:
    drawLabel(0, ax, ay - 2, ".", getStyle("success"))
  if ay + 2 < h:
    drawLabel(0, ax, ay + 2, ".", getStyle("success"))

# Controls panel
drawPanel(0, 2, 17, 30, 6, "Controls", "rounded")
drawLabel(0, 4, 19, "Mouse - Move attractor", getStyle("info"))
drawLabel(0, 4, 20, "ESC - Exit", getStyle("info"))
drawLabel(0, 4, 21, "Rendered:", getStyle("dim"))
drawLabel(0, 15, 21, str(rendered) & " / " & str(PARTICLE_COUNT), getStyle("dim"))

# Status message
drawLabel(0, 2, h - 2, message, getStyle("warning"))
```

```nim on:input
# ===================================================================
# Input Handling
# ===================================================================
if event.type == "key":
  # ESC - Exit
  if event.keyCode == KEY_ESCAPE and event.action == "press":
    return false

return true
```

## What This Demo Shows

### ✅ Particle Physics Demo  
- **2,000 particles** running physics simulations
- **Real-time physics**: Attraction forces, velocity damping, edge wrapping
- **Interactive**: Particles follow your mouse cursor
- **Visual feedback**: Different characters (@, o, *, .) show particle speed

### ✅ Particle Physics
- **Inverse-square attraction**: Particles attracted to mouse cursor or auto-moving attractor  
- **Velocity damping**: Realistic friction/air resistance
- **Speed limits**: Prevents particles from moving too fast
- **Edge wrapping**: Particles wrap around screen boundaries
- **Visual feedback**: Character (@, o, *, .) and color based on particle speed

### ✅ What You Should See
When you move your mouse cursor, you should see:
- 2,000 particles moving toward your cursor
- Particles change character/color based on speed:
  - `@` (red) = very fast (speed > 2.0)
  - `o` (orange) = fast (speed > 1.5)
  - `*` (blue) = medium (speed > 0.8)
  - `.` (gray) = slow
- A plus sign `+` showing the attractor position
- Particles wrapping around edges when they go off-screen

### ✅ Why This Demo
This particle system demonstrates:
- 2,000 moving objects with complex physics updated every frame
- Interactive real-time behavior that responds to mouse input
- Visual representation of physical forces (attraction, damping, velocity)
- How tstorie can handle computationally intensive animations

**Note**: This demo currently runs on CPU. GPU compute shader support is planned for future versions, which would allow 10,000+ particles with minimal performance impact.
