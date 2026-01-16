---
title: "Creative Particle Effects Demo"
---

# Creative Particle Effects Demo

Advanced particle effects showcasing shader-based rendering with creative visual styles.

```nim on:init
# Get theme background color
var bgStyle = getStyle("default")
var bgR = int(bgStyle.bg.r)
var bgG = int(bgStyle.bg.g)
var bgB = int(bgStyle.bg.b)

# Initialize particle systems for different effects
particleInit("matrix", 800)
particleInit("corruption", 400)
particleInit("static", 600)
particleInit("glow", 300)
particleInit("scanlines", 200)
particleInit("bugs", 150)

# Set background color to match theme for all systems
var systems = @["matrix", "corruption", "static", "glow", "scanlines", "bugs"]
for sys in systems:
  particleSetBackgroundColor(sys, bgR, bgG, bgB)

# Configure Matrix effect (falling characters)
particleConfigureMatrix("matrix", 50.0)
particleSetEmitterPos("matrix", float(termWidth / 2), 0.0)
particleSetEmitterSize("matrix", float(termWidth), 1.0)

# Configure Corruption effect (glitchy spreading)
particleInit("corruption", 300)
particleSetEmitterPos("corruption", float(termWidth / 2), float(termHeight / 2))
particleSetEmitRate("corruption", 0.0)  # Manual emission only
particleSetVelocityRange("corruption", -20.0, -20.0, 20.0, 20.0)
particleSetLifeRange("corruption", 0.8, 1.5)
particleSetGravity("corruption", 0.0)
particleSetDamping("corruption", 0.3)

# Configure Static effect (random noise)
particleInit("static", 500)
particleSetEmitterPos("static", float(termWidth / 2), float(termHeight / 2))
particleSetEmitterSize("static", float(termWidth), float(termHeight))
particleSetEmitRate("static", 100.0)
particleSetVelocityRange("static", -5.0, -5.0, 5.0, 5.0)
particleSetLifeRange("static", 0.1, 0.3)
particleSetGravity("static", 0.0)
particleSetDamping("static", 0.95)

# Configure Glow effect (bright additive particles)
particleConfigureSparkles("glow", 40.0)
particleSetEmitterPos("glow", float(termWidth / 2), float(termHeight / 2))
particleSetLifeRange("glow", 1.5, 2.5)

# Configure Scanlines effect (horizontal sweeping lines)
particleInit("scanlines", 150)
particleSetEmitterPos("scanlines", 0.0, 0.0)
particleSetEmitterSize("scanlines", 1.0, float(termHeight))
particleSetEmitRate("scanlines", 5.0)
particleSetVelocityRange("scanlines", 30.0, -5.0, 50.0, 5.0)
particleSetLifeRange("scanlines", 2.0, 3.0)
particleSetGravity("scanlines", 0.0)
particleSetDamping("scanlines", 0.98)

# Configure Bugs (crawling entities)
particleConfigureBugs("bugs", 20.0)
particleSetEmitterPos("bugs", float(termWidth / 2), float(termHeight / 2))
particleSetEmitterSize("bugs", float(termWidth), float(termHeight))

var currentEffect = "matrix"
var showHelp = true
var mouseX = float(termWidth / 2)
var mouseY = float(termHeight / 2)
var autoEmit = true
var lastBurstTime = 0.0
var burstInterval = 2.0
var effectIntensity = 1.0
```

```nim on:update
# Auto-burst for corruption effect
if currentEffect == "corruption" and autoEmit:
  lastBurstTime = lastBurstTime + deltaTime
  if lastBurstTime >= burstInterval:
    lastBurstTime = 0.0
    var randomX = float(rand(termWidth))
    var randomY = float(rand(termHeight))
    particleSetEmitterPos("corruption", randomX, randomY)
    particleEmit("corruption", int(30.0 * effectIntensity))

# Update emitter positions for responsive effects
particleSetEmitterPos("matrix", float(termWidth / 2), 0.0)
particleSetEmitterSize("matrix", float(termWidth), 1.0)
particleSetEmitterPos("glow", mouseX, mouseY)
particleSetEmitterSize("static", float(termWidth), float(termHeight))
particleSetEmitterSize("scanlines", 1.0, float(termHeight))

# Update active effect
if currentEffect == "matrix":
  particleUpdate("matrix", deltaTime)
elif currentEffect == "corruption":
  particleUpdate("corruption", deltaTime)
elif currentEffect == "static":
  particleUpdate("static", deltaTime)
elif currentEffect == "glow":
  particleUpdate("glow", deltaTime)
elif currentEffect == "scanlines":
  particleUpdate("scanlines", deltaTime)
elif currentEffect == "bugs":
  particleUpdate("bugs", deltaTime)
```

```nim on:render
# Clear screen
clear()

# Render active particle effect
if currentEffect == "matrix":
  particleRender("matrix", 0)
elif currentEffect == "corruption":
  particleRender("corruption", 0)
elif currentEffect == "static":
  particleRender("static", 0)
elif currentEffect == "glow":
  particleRender("glow", 0)
elif currentEffect == "scanlines":
  particleRender("scanlines", 0)
elif currentEffect == "bugs":
  particleRender("bugs", 0)

# Show UI overlay
var titleStyle = getStyle("heading")
var infoStyle = getStyle("info")
var activeStyle = getStyle("success")
var dimStyle = getStyle("dim")

draw(0, 2, 1, "CREATIVE PARTICLE EFFECTS", titleStyle)

if showHelp:
  draw(0, 2, 3, "Effects:", infoStyle)
  draw(0, 4, 5, "[1] Matrix - Falling characters", getStyle("default"))
  draw(0, 4, 6, "[2] Corruption - Glitchy spread", getStyle("default"))
  draw(0, 4, 7, "[3] Static - TV noise", getStyle("default"))
  draw(0, 4, 8, "[4] Glow - Additive sparkles", getStyle("default"))
  draw(0, 4, 9, "[5] Scanlines - CRT sweep", getStyle("default"))
  draw(0, 4, 10, "[6] Bugs - Crawling entities", getStyle("default"))
  
  draw(0, 2, 12, "Controls:", infoStyle)
  draw(0, 4, 13, "[C] Clear particles", getStyle("default"))
  draw(0, 4, 14, "[A] Toggle auto-emit", getStyle("default"))
  draw(0, 4, 15, "[H] Toggle help", getStyle("default"))
  draw(0, 4, 16, "[+/-] Adjust intensity", getStyle("default"))
  draw(0, 4, 17, "Click to spawn burst!", activeStyle)

# Show stats
var activeCount = particleGetCount(currentEffect)
var statsY = termHeight - 4

var effectDesc = ""
if currentEffect == "matrix":
  effectDesc = "Digital rain cascading down the screen"
elif currentEffect == "corruption":
  effectDesc = "Reality fragmenting and glitching out"
elif currentEffect == "static":
  effectDesc = "Analog interference patterns"
elif currentEffect == "glow":
  effectDesc = "Ethereal light trails (follows mouse)"
elif currentEffect == "scanlines":
  effectDesc = "Retro CRT horizontal lines"
elif currentEffect == "bugs":
  effectDesc = "Crawling terminal creatures"

draw(0, 2, statsY, "Active: " & str(activeCount) & " particles", infoStyle)
draw(0, 2, statsY + 1, "Effect: " & currentEffect & " | Auto: " & (if autoEmit: "ON" else: "OFF"), activeStyle)
draw(0, 2, statsY + 2, "Intensity: " & str(int(effectIntensity * 100.0)) & "%", infoStyle)
draw(0, 2, statsY + 3, effectDesc, dimStyle)
```

```nim on:input
# Handle keyboard input
if event.type == "text":
  var key = event.text
  
  if key == "1":
    particleClear(currentEffect)
    currentEffect = "matrix"
    return true
  
  elif key == "2":
    particleClear(currentEffect)
    currentEffect = "corruption"
    lastBurstTime = 0.0
    return true
  
  elif key == "3":
    particleClear(currentEffect)
    currentEffect = "static"
    return true
  
  elif key == "4":
    particleClear(currentEffect)
    currentEffect = "glow"
    return true
  
  elif key == "5":
    particleClear(currentEffect)
    currentEffect = "scanlines"
    return true
  
  elif key == "6":
    particleClear(currentEffect)
    currentEffect = "bugs"
    return true
  
  elif key == "c":
    particleClear("matrix")
    particleClear("corruption")
    particleClear("static")
    particleClear("glow")
    particleClear("scanlines")
    particleClear("bugs")
    return true
  
  elif key == "a":
    autoEmit = not autoEmit
    return true
  
  elif key == "h":
    showHelp = not showHelp
    return true
  
  elif key == "+":
    effectIntensity = min(2.0, effectIntensity + 0.1)
    # Adjust emission rates based on intensity
    particleSetEmitRate("matrix", 50.0 * effectIntensity)
    particleSetEmitRate("static", 100.0 * effectIntensity)
    particleSetEmitRate("glow", 40.0 * effectIntensity)
    particleSetEmitRate("scanlines", 5.0 * effectIntensity)
    particleSetEmitRate("bugs", 20.0 * effectIntensity)
    return true
  
  elif key == "-":
    effectIntensity = max(0.1, effectIntensity - 0.1)
    # Adjust emission rates based on intensity
    particleSetEmitRate("matrix", 50.0 * effectIntensity)
    particleSetEmitRate("static", 100.0 * effectIntensity)
    particleSetEmitRate("glow", 40.0 * effectIntensity)
    particleSetEmitRate("scanlines", 5.0 * effectIntensity)
    particleSetEmitRate("bugs", 20.0 * effectIntensity)
    return true

# Handle mouse input
if event.type == "mouse":
  mouseX = float(event.x)
  mouseY = float(event.y)
  
  # Update glow emitter to follow mouse
  if currentEffect == "glow":
    particleSetEmitterPos("glow", mouseX, mouseY)
  
  # Mouse click spawns effect-specific bursts
  if event.action == "press":
    if currentEffect == "matrix":
      # Spawn extra column of matrix particles
      particleSetEmitterPos("matrix", mouseX, 0.0)
      particleEmit("matrix", int(50.0 * effectIntensity))
      particleSetEmitterPos("matrix", float(termWidth / 2), 0.0)
    
    elif currentEffect == "corruption":
      # Spawn corruption burst at cursor
      particleSetEmitterPos("corruption", mouseX, mouseY)
      particleEmit("corruption", int(40.0 * effectIntensity))
    
    elif currentEffect == "static":
      # Concentrated static burst
      particleSetEmitterPos("static", mouseX, mouseY)
      particleSetEmitterSize("static", 10.0, 10.0)
      particleEmit("static", int(100.0 * effectIntensity))
      particleSetEmitterSize("static", float(termWidth), float(termHeight))
    
    elif currentEffect == "glow":
      # Extra bright burst
      particleEmit("glow", int(50.0 * effectIntensity))
    
    elif currentEffect == "scanlines":
      # Spawn scanline from cursor
      particleSetEmitterPos("scanlines", mouseX, mouseY)
      particleEmit("scanlines", int(20.0 * effectIntensity))
      particleSetEmitterPos("scanlines", 0.0, 0.0)
    
    elif currentEffect == "bugs":
      # Spawn bugs at cursor
      particleSetEmitterPos("bugs", mouseX, mouseY)
      particleEmit("bugs", int(10.0 * effectIntensity))
      particleSetEmitterPos("bugs", float(termWidth / 2), float(termHeight / 2))
    
    return true

return false
```

---

## Effect Descriptions

### Matrix
The classic "digital rain" effect with falling green characters. Creates columns of cascading text that evoke the aesthetic of terminal-based sci-fi interfaces.

**Visual Style:** Bright green characters falling vertically with varying speeds.

### Corruption
Simulates digital corruption spreading across the screen. Particles spawn in bursts and create glitchy, fragmenting patterns that feel like reality breaking down.

**Visual Style:** Erratic movement, rapid flickering, chaotic spread patterns.

### Static
TV-style static noise with rapid particle spawning and decay. Creates analog interference patterns reminiscent of old CRT displays.

**Visual Style:** High-frequency random character placement with very short lifetimes.

### Glow
Additive sparkle particles that create bright, luminous trails. Follows mouse position for interactive light painting effects.

**Visual Style:** Bright colors with slow-moving particles that create ethereal light trails.

### Scanlines
Horizontal sweeping lines that mimic CRT scanline artifacts. Creates a retro terminal aesthetic with periodic horizontal movements.

**Visual Style:** Fast horizontal movement, periodic emission, creates classic retro display look.

### Bugs
Crawling entities with erratic movement patterns. Particles behave like small creatures exploring the screen with natural-looking locomotion.

**Visual Style:** Random walk patterns with directional changes, persistent presence.

---

## Shader Integration Notes

These effects demonstrate different rendering approaches:

- **Matrix/Static**: Character-only replacement shaders
- **Glow**: Additive color blending for brightness
- **Corruption**: Color modulation for glitch effects
- **Scanlines**: Foreground-only rendering to preserve background
- **Bugs**: Full cell replacement with character animation

Future versions will allow runtime shader switching to create hybrid effects (e.g., glowing matrix rain with scanline overlays).

---

## Performance Tips

**For best performance:**
1. Adjust intensity with +/- keys to find optimal particle count for your terminal
2. Disable auto-emit (A key) for manual burst control
3. Clear particles (C key) before switching effects
4. Static effect is most intensive - reduce intensity if needed

**Typical performance:**
- Matrix: 800 particles @ 60 FPS
- Static: 500-600 particles @ 60 FPS  
- Corruption: 300 particles @ 60 FPS (burst mode)
- Glow: 300 particles @ 60 FPS
- Scanlines: 150-200 particles @ 60 FPS
- Bugs: 100-150 particles @ 60 FPS

---

## Creative Combinations

Try these effect parameters for unique visuals:

**Slow-motion Matrix:**
```nim
particleSetGravity("matrix", 20.0)  # Slower fall
particleSetLifeRange("matrix", 5.0, 8.0)  # Longer trails
```

**Explosive Corruption:**
```nim
particleSetVelocityRange("corruption", -80.0, -80.0, 80.0, 80.0)  # Faster spread
particleSetLifeRange("corruption", 0.3, 0.6)  # Quick bursts
```

**Thick Static:**
```nim
particleSetEmitRate("static", 300.0)  # Dense noise
particleSetLifeRange("static", 0.2, 0.4)  # Persistent
```
