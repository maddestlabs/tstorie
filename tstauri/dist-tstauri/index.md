---
title: "Welcome to t|Stauri"
author: "Maddest Labs"
theme: "default"
---

# Welcome to t|Stauri Desktop

A terminal-based storytelling environment powered by **t|Storie**.

```nim on:init
# Get theme background and accent colors
var bgStyle = getStyle("default")
var bgR = int(bgStyle.bg.r)
var bgG = int(bgStyle.bg.g)
var bgB = int(bgStyle.bg.b)

# Get accent1 color for rain particles
var accentStyle = getStyle("accent1")

# Initialize rain particle system
particleInit("rain", 150)
particleSetBackgroundColor("rain", bgR, bgG, bgB)
particleConfigureRain("rain", 30.0)
particleSetEmitterPos("rain", 0.0, 0.0)
particleSetEmitterSize("rain", float(termWidth), 1.0)
particleSetCollision("rain", false, 0)

# Set rain color to theme accent1
particleSetForegroundFromStyle("rain", accentStyle)

# Animation state variables
var pulsePhase = 0.0
var instructionBlink = 0.0
```

```nim on:update
# Update particle emitter size based on terminal width
particleSetEmitterSize("rain", float(termWidth), 1.0)

# Frame-independent animation timing
pulsePhase = pulsePhase + (deltaTime * 2.0)
instructionBlink = instructionBlink + (deltaTime * 4.0)

# Update rain particle system
particleUpdate("rain", deltaTime)
```

```nim on:render
# Clear screen
clear()

# Render rain particles behind UI
particleRender("rain", 0)

# Calculate pulsing values for animations
var pulse = (sin(pulsePhase) + 1.0) / 2.0
var blinkVal = (sin(instructionBlink) + 1.0) / 2.0

# Header styles
var titleStyle = getStyle("heading")
var infoStyle = getStyle("info")
var successStyle = getStyle("success")

# Title box at center-top
var centerX = termWidth / 2
var titleY = 3

draw(0, centerX - 18, titleY, "╔════════════════════════════════════╗")
draw(0, centerX - 18, titleY + 1, "║                                    ║")
draw(0, centerX - 18, titleY + 2, "║      t|Stauri Desktop v0.1         ║", titleStyle)
draw(0, centerX - 18, titleY + 3, "║         Terminal Engine            ║", infoStyle)
draw(0, centerX - 18, titleY + 4, "║                                    ║")
draw(0, centerX - 18, titleY + 5, "╚════════════════════════════════════╝")

# Animated separator
var sepY = titleY + 7
var sepChar = "─"
if pulse > 0.5:
  sepChar = "═"

var i = 0
var sepStr = ""
while i < 36:
  sepStr = sepStr & sepChar
  i = i + 1
draw(0, centerX - 18, sepY, sepStr, successStyle)

# Main instructions - drop files here
var instrY = sepY + 2
draw(0, centerX - 16, instrY, "DROP A t|Storie FILE TO BEGIN", successStyle)

var detailY = instrY + 2
draw(0, centerX - 18, detailY, "  📄  .md files (t|Storie markdown)")
draw(0, centerX - 18, detailY + 1, "  🖼️   .png files (embedded workflows)")
draw(0, centerX - 18, detailY + 2, "  📦  .t|Storie files (packaged stories)")

# Pulsing hint
var hintY = detailY + 4
var hintIntensity = int(blinkVal * 100)
if hintIntensity > 40:
  draw(0, centerX - 15, hintY, ">>> Drag & drop to get started <<<", successStyle)
else:
  draw(0, centerX - 15, hintY, "    Drag & drop to get started    ")

# Controls hint
var ctrlY = termHeight - 4
draw(0, 2, ctrlY, "Controls:", infoStyle)
draw(0, 4, ctrlY + 1, "[Q] or [ESC] Quit")

# Footer
var footerY = termHeight - 2
draw(0, 2, footerY, "t|Stauri Desktop | Powered by t|Storie Engine", infoStyle)
draw(0, termWidth - 25, footerY, "github.com/maddestlabs", infoStyle)
```

```nim on:input
# Handle keyboard input
if event.type == "text":
  var key = event.text
  
  if key == "q":
    return false

# Handle key events for ESC
if event.type == "key":
  if event.keyCode == KEY_ESCAPE:
    return false
  if event.keyCode == KEY_Q:
    return false

return true
```
