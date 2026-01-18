---
title: "Kanji FX"
author: "Maddest Labs"
chars: "闇雲霧雨雪月星空夢幻影光風水火土木金銀鉄石砂爆雷虫符花"
doubleWidth: true
theme: "neonopia"
fontsize: 40
shaders: "bloom+crt"
font: "LXGW+WenKai+Mono+TC"
targetFPS: 60
---

```nim on:init
# Parse character set from front matter for background kanji
var kanjiChars = []

if len(chars) > 0:
  # Parse chars string with proper UTF-8 multi-byte character handling
  var i = 0
  while i < len(chars):
    var b = ord(chars[i])
    
    var charLen = 1
    # Detect UTF-8 character length based on first byte
    if b < 128:
      charLen = 1
    elif b >= 192 and b < 224:
      charLen = 2
    elif b >= 224 and b < 240:
      charLen = 3
    elif b >= 240:
      charLen = 4
    
    var endIdx = i + charLen
    if endIdx > len(chars):
      endIdx = len(chars)
    
    var ch = ""
    var j = i
    while j < endIdx:
      ch = ch & chars[j]
      j = j + 1
    
    kanjiChars = kanjiChars + [ch]
    i = endIdx

var charWidth = 1
# Calculate character width for rendering
if doubleWidth:
  charWidth = 2

# Random kanji character selection for background (static, no animation)
proc getRandomKanji(x: int, y: int): string =
  if len(kanjiChars) == 0:
    return " "
  # Hash-based pattern - pseudo-random but static
  var hash = (x * 73 + y * 37) mod 997  # Prime-based hash for randomness
  var wave = (x + y * 2) div 3  # Gentle diagonal wave component
  var idx = (hash + wave) mod len(kanjiChars)
  return kanjiChars[idx]

# Get style objects
var styleBackground = brightness(getStyle("default"), 0.2)
var styleSelected = getStyle("accent1")
var styleUnselected = getStyle("accent2")

# State
var selectedIndex = 0  # Currently selected character (0-7)
var displayChars = []  # The 8 random kanji to display at top
var colorMode = 0  # Color mode: 0=accent1, 1=accent2, 2=accent3, 3=monochrome, 4=rainbow
var nextFireworksTime = 0.5  # Time until next auto-trigger fireworks (in seconds)

# Particle systems (one per kanji character)
var particleSystems = ["p0", "p1", "p2", "p3", "p4", "p5", "p6", "p7"]

# Initialize displayChars with specific kanji for each particle effect
displayChars = ["爆", "符", "雪", "火", "星", "雷", "雨", "虫"]

# Initialize particle systems with different effects for each kanji
# All particles use foreground-only shader to only change foreground color

# System 0: Fireworks/Explosion
particleInit(particleSystems[0], 500)
particleConfigureExplosion(particleSystems[0])
particleSetShader(particleSystems[0], "foreground")
particleSetEmitRate(particleSystems[0], 0.0)  # Manual trigger only
particleSetEmitterPos(particleSystems[0], float(termWidth / 2), float(termHeight / 2))

# System 1: Matrix Rain with long trails
particleInit(particleSystems[1], 300)
particleConfigureMatrix(particleSystems[1], 15.0)
particleSetShader(particleSystems[1], "foreground")
particleSetTrailLength(particleSystems[1], 30)
particleSetEmitterPos(particleSystems[1], 0.0, 0.0)
particleSetEmitterSize(particleSystems[1], termWidth, 1.0)

# System 2: Snow
particleInit(particleSystems[2], 400)
particleConfigureSnow(particleSystems[2], 10.0)
particleSetShader(particleSystems[2], "foreground")
particleSetEmitterPos(particleSystems[2], 0.0, 0.0)
particleSetEmitterSize(particleSystems[2], termWidth, 1.0)
particleSetVelocityRange(particleSystems[2], 2.0, 0.25, 3.0, 0.5)

# System 3: Fire
particleInit(particleSystems[3], 600)
particleConfigureFire(particleSystems[3], 120.0)
particleSetShader(particleSystems[3], "foreground")
particleSetEmitterPos(particleSystems[3], 0.0, termHeight)
particleSetEmitterSize(particleSystems[3], termWidth, float(termHeight) / 2)
particleSetLifeRange(particleSystems[3], 3.0, 5.0)
particleSetVelocityRange(particleSystems[3], 0.0, -5.0, 0.0, -15.0)

# System 4: Sparkles
particleInit(particleSystems[4], 300)
particleConfigureSparkles(particleSystems[4], 30.0)
particleSetShader(particleSystems[4], "foreground")
particleSetEmitterPos(particleSystems[4], 0.0, 0.0)
particleSetEmitterSize(particleSystems[4], termWidth, termHeight)

# System 5: Colorblast (lightning-like)
particleInit(particleSystems[5], 400)
particleConfigureColorblast(particleSystems[5])
particleSetShader(particleSystems[5], "foreground")
particleSetEmitRate(particleSystems[5], 0.0)  # Start at zero, will pulse
particleSetEmitterSize(particleSystems[5], termWidth, termHeight)
particleSetEmitterPos(particleSystems[5], float(termWidth / 2), float(termHeight / 2))

# System 6: Rain
particleInit(particleSystems[6], 300)
particleConfigureRain(particleSystems[6], 40.0)
particleSetShader(particleSystems[6], "foreground")
particleSetEmitterPos(particleSystems[6], 0.0, 0.0)
particleSetEmitterSize(particleSystems[6], termWidth, 1.0)

# System 7: Bugs (organic movement with edge spawning and arcing motion)
particleInit(particleSystems[7], 200)
particleSetShader(particleSystems[7], "foreground")
particleSetEmitRate(particleSystems[7], 0.0)  # Manual emission only
particleSetTrailEnabled(particleSystems[7], true)
particleSetTrailLength(particleSystems[7], 10)  # 4-segment body
particleSetTrailSpacing(particleSystems[7], 0.8)  # Tight spacing
particleSetTrailFade(particleSystems[7], false)  # Solid body segments
particleSetLifeRange(particleSystems[7], 3.0, 5.0)  # Short lifetime - bugs disappear after crossing
particleSetTurbulence(particleSystems[7], 3.0)  # Light turbulence for slight wobble
particleSetDamping(particleSystems[7], 0.98)
particleSetEmitterPos(particleSystems[7], float(termWidth / 2), float(termHeight / 2))
particleSetEmitterSize(particleSystems[7], termWidth, termHeight)

# Bug spawning state
var bugTimer = 0.0
var bugSpawnInterval = 1.0

# Sparkles circular motion state
var sparklesAngle = 0.0
var sparklesRadius = float(termHeight / 3)
var sparklesCenterX = float(termWidth / 2)
var sparklesCenterY = float(termHeight / 2)
var sparklesAngularVel = 2.0  # radians per second
var sparklesPathChangeTime = 0.0  # Time when path should change
var sparklesPathDuration = 5.0  # seconds before changing path

# Lightning strike state
var lightningTimer = 0.0
var lightningStrikeInterval = 0.3  # seconds between strikes
var lightningIntensity = 0.0  # current emission intensity (0-1)
var lightningDecayRate = 8.0  # how fast intensity fades
var lightningStriking = false
var lightningX = float(termWidth / 2)
var lightningY = float(termHeight / 2)
var lightningSize = float(termHeight / 4)

# Set colors for all systems to use theme colors
var i = 0
while i < 8:
  particleSetForegroundFromStyle(particleSystems[i], getStyle("accent1"))
  i = i + 1

# Apply color mode to a system
proc applyColorMode(system: string) =
  if colorMode == 0:
    particleSetForegroundFromStyle(system, getStyle("accent1"))
  elif colorMode == 1:
    particleSetForegroundFromStyle(system, getStyle("accent2"))
  elif colorMode == 2:
    particleSetForegroundFromStyle(system, getStyle("accent3"))
  elif colorMode == 3:
    # default - use defaultStyle to reset to core monochrome
    particleSetForegroundFromStyle(system, getStyle("default"))
  elif colorMode == 4:
    # rainbow - full color range
    particleSetColorRange(system, 0, 0, 0, 255, 255, 255)

# Trigger fireworks at random position
proc triggerFireworks() =
  var randX = float(rand(3, termWidth - 3))
  var randY = float(rand(3, termHeight - 4))
  particleSetEmitterPos(particleSystems[0], randX, randY)
  particleSetLifeRange(particleSystems[0], rand(1.0, 3.0), rand(3.0, 10.0))
  particleEmit(particleSystems[0], rand(100, 200))
```

```nim on:input
# Handle input
if event.type == "mouse":
  var mouseAction = event.action
  
  if mouseAction == "press":
    # Get mouse position
    var mouseX = getMouseX()
    var mouseY = getMouseY()
    
    # Check if clicking on the character selection area (top line)
    if mouseY == 0:
      # Calculate which character was clicked (accounting for charWidth)
      # Characters are centered, so we need to find the start position
      var totalWidth = 8 * charWidth + 7  # 8 chars + 7 spaces
      var startX = (termWidth - totalWidth) / 2
      
      var i = 0
      while i < 8:
        var charX = startX + (i * (charWidth + 1))
        if mouseX >= charX and mouseX < charX + charWidth:
          # Check if clicking on the currently selected character - cycle color mode
          if i == selectedIndex:
            colorMode = colorMode + 1
            if colorMode > 4:
              colorMode = 0
            applyColorMode(particleSystems[selectedIndex])
          else:
            selectedIndex = i
            # Trigger fireworks for system 0 when selected
            if selectedIndex == 0:
              triggerFireworks()
            applyColorMode(particleSystems[selectedIndex])
          return true
        i = i + 1
  
  return false

elif event.type == "text":
  var key = event.text
  
  # Refresh display characters
  if key == "r" or key == "R":
    initDisplayChars()
    return true
  
  # Trigger effects
  if key == " ":
    # Space bar triggers effect for current system
    if selectedIndex == 0:
      triggerFireworks()  # Fireworks burst at random position
    return true
  
  return false

elif event.type == "key":
  if event.action == "press" or event.action == "repeat":
    var code = event.keyCode
    
    # Arrow keys using SDL3-compatible KEY_* constants
    if code == KEY_UP:  # Up - cycle color mode forward
      colorMode = colorMode + 1
      if colorMode > 4:
        colorMode = 0
      applyColorMode(particleSystems[selectedIndex])
      return true
    elif code == KEY_DOWN:  # Down - cycle color mode backward
      colorMode = colorMode - 1
      if colorMode < 0:
        colorMode = 4
      applyColorMode(particleSystems[selectedIndex])
      return true
    elif code == KEY_LEFT:  # Left
      selectedIndex = selectedIndex - 1
      if selectedIndex < 0:
        selectedIndex = 7
      # Trigger fireworks when selecting system 0
      if selectedIndex == 0:
        triggerFireworks()
      applyColorMode(particleSystems[selectedIndex])
      return true
    elif code == KEY_RIGHT:  # Right
      selectedIndex = selectedIndex + 1
      if selectedIndex > 7:
        selectedIndex = 0
      # Trigger fireworks when selecting system 0
      if selectedIndex == 0:
        triggerFireworks()
      applyColorMode(particleSystems[selectedIndex])
      return true
  
  return false

return false
```

```nim on:update
# Auto-trigger fireworks when system 0 is selected
var currentTime = getTime()
if selectedIndex == 0 and currentTime >= nextFireworksTime:
  triggerFireworks()
  # Next trigger in 0.3-2.3 seconds
  nextFireworksTime = currentTime + (0.3 + float(rand(200)) / 100.0)

# Update the currently selected particle system
# deltaTime is automatically injected by the runtime with the actual frame time

# Special handling for sparkles system - move in circular paths
if selectedIndex == 4:
  # Update circular motion
  sparklesAngle = sparklesAngle + (sparklesAngularVel * deltaTime)
  
  # Calculate new emitter position on circular path
  var sparklesX = sparklesCenterX + (sparklesRadius * cos(sparklesAngle))
  var sparklesY = sparklesCenterY + (sparklesRadius * sin(sparklesAngle))
  particleSetEmitterPos(particleSystems[4], sparklesX, sparklesY)
  
  # Change to new random circular path periodically
  if currentTime >= sparklesPathChangeTime:
    # Random new center point (avoiding edges)
    sparklesCenterX = float(rand(termWidth / 4, (termWidth * 3) / 4))
    sparklesCenterY = float(rand(termHeight / 4, (termHeight * 3) / 4))
    # Random radius
    sparklesRadius = float(rand(termHeight / 6, termHeight / 3))
    # Random angular velocity (speed and direction)
    sparklesAngularVel = float(rand(10, 40)) / 10.0  # 1-4 radians/sec
    if rand(2) == 0:
      sparklesAngularVel = -sparklesAngularVel  # Random direction
    # Random duration for next path
    sparklesPathDuration = 3.0 + float(rand(40)) / 10.0  # 3-7 seconds
    sparklesPathChangeTime = currentTime + sparklesPathDuration

# Special handling for lightning system - random strikes with pulsing intensity
if selectedIndex == 5:
  lightningTimer = lightningTimer + deltaTime
  
  # Check if it's time for a new lightning strike
  if lightningTimer >= lightningStrikeInterval:
    lightningTimer = 0.0
    lightningStriking = true
    lightningIntensity = 1.0
    
    # Random strike location
    lightningX = float(rand(termWidth / 8, (termWidth * 7) / 8))
    lightningY = float(rand(termHeight / 8, (termHeight * 7) / 8))
    
    # Random strike size (tighter for bolt-like, wider for area effect)
    lightningSize = float(rand(termHeight / 8, termHeight / 3))
    
    # Random next strike interval (make it unpredictable)
    lightningStrikeInterval = 0.1 + float(rand(30)) / 100.0  # 0.1-0.4 seconds
    
    # Sometimes add a second quick flash
    if rand(3) == 0:
      lightningStrikeInterval = 0.05 + float(rand(10)) / 100.0  # 0.05-0.15 seconds
  
  # Update lightning intensity (decay over time)
  if lightningStriking:
    lightningIntensity = lightningIntensity - (lightningDecayRate * deltaTime)
    if lightningIntensity <= 0.0:
      lightningIntensity = 0.0
      lightningStriking = false
  
  # Apply current lightning state
  particleSetEmitterPos(particleSystems[5], lightningX, lightningY)
  particleSetEmitterSize(particleSystems[5], lightningSize, lightningSize)
  
  # Set emission rate based on intensity (0 to 200)
  var emitRate = lightningIntensity * 200.0
  particleSetEmitRate(particleSystems[5], emitRate)

# Special handling for bug system - spawn bugs from edges
if selectedIndex == 7:
  bugTimer = bugTimer + deltaTime
  if bugTimer >= bugSpawnInterval:
    bugTimer = 0.0
    
    # Randomly select which edge to spawn from (0=top, 1=right, 2=bottom, 3=left)
    var edge = rand(4)
    
    # Random arc direction for variety
    var arcDir = float(rand(2) * 2 - 1)  # -1 or 1
    var gravityStrength = 12.0 + float(rand(10))  # 12-21 for varied arc curves
    particleSetTrailLength(particleSystems[7], rand(4, 12))
    
    if edge == 0:
      # Spawn from TOP edge
      var spawnX = float(rand(termWidth - 4) + 2)
      particleSetEmitterPos(particleSystems[7], spawnX, 1.0)
      var horizontalDir = float(rand(3) - 1) * 40.0
      particleSetVelocityRange(particleSystems[7], horizontalDir - 15.0, 80.0, horizontalDir + 15.0, 80.0)
      particleSetGravity(particleSystems[7], gravityStrength * arcDir)
    elif edge == 1:
      # Spawn from RIGHT edge
      var spawnY = float(rand(termHeight - 4) + 2)
      particleSetEmitterPos(particleSystems[7], float(termWidth - 2), spawnY)
      particleSetVelocityRange(particleSystems[7], -80.0, -15.0, -80.0, 15.0)
      particleSetGravity(particleSystems[7], gravityStrength * arcDir)
    elif edge == 2:
      # Spawn from BOTTOM edge
      var spawnX = float(rand(termWidth - 4) + 2)
      particleSetEmitterPos(particleSystems[7], spawnX, float(termHeight - 2))
      var horizontalDir = float(rand(3) - 1) * 40.0
      particleSetVelocityRange(particleSystems[7], horizontalDir - 15.0, -80.0, horizontalDir + 15.0, -80.0)
      particleSetGravity(particleSystems[7], gravityStrength * arcDir)
    else:
      # Spawn from LEFT edge
      var spawnY = float(rand(termHeight - 4) + 2)
      particleSetEmitterPos(particleSystems[7], 1.0, spawnY)
      particleSetVelocityRange(particleSystems[7], 80.0, -15.0, 80.0, 15.0)
      particleSetGravity(particleSystems[7], gravityStrength * arcDir)
    
    # Emit bugs
    particleEmit(particleSystems[7], rand(2, 10))
    
    # Vary spawn interval
    bugSpawnInterval = 0.5 + (float(rand(20)) / 80.0)

# Update particle physics
particleUpdate(particleSystems[selectedIndex], deltaTime)
```

```nim on:render
# Clear screen
clear()

# Fill entire background with static kanji characters
var y = 1
while y < termHeight - 1:
  var x = 0
  while x < termWidth:
    draw(0, x, y, getRandomKanji(x, y), styleBackground)
    x = x + charWidth
  y = y + 1

# Render the currently selected particle system
particleRender(particleSystems[selectedIndex], 0)

# Draw the 8 selectable characters at top center
var totalWidth = 8 * charWidth + 7  # 8 chars + 7 spaces between
var startX = (termWidth - totalWidth) / 2

var i = 0
while i < 8:
  var charX = startX + (i * (charWidth + 1))
  var style = styleUnselected
  if i == selectedIndex:
    style = styleSelected
  
  draw(0, charX, 0, displayChars[i], style)
  i = i + 1

# Draw effect names at bottom of screen
var effectNames = ["Fireworks", "Matrix", "Snow", "Fire", "Sparkles", "Lightning", "Rain", "Bugs"]
var effectName = effectNames[selectedIndex]

# Add color mode name
var colorModeNames = ["Accent1", "Accent2", "Accent3", "Monochrome", "Rainbow"]
var colorModeName = colorModeNames[colorMode]
var fullName = effectName & " | " & colorModeName

var nameX = (termWidth - len(fullName)) / 2
draw(0, nameX, termHeight - 1, fullName, styleSelected)
```
