# t|Stauri {"hidden": true}

```nim on:init
# Create animated matrix rain effect
particleCreate("matrix", 150, {
  char: ["│", "┃", "║", "▌", "▐"],
  color: "#00d98e",
  velocity: [0, 0.3]
})

# Create floating dots
particleCreate("dots", 50, {
  char: ["·", "•", "◦"],
  color: "#00d98e80",
  velocity: [0.1, 0.1]
})

# State
var pulseTime = 0.0
var showInstructions = true
```

```nim on:render
# Clear and render background particles
clear()
particleRender("matrix")
particleRender("dots")

# Calculate pulse for animations
pulseTime = pulseTime + 0.05
var pulse = (sin(pulseTime) + 1.0) / 2.0

# Title with glow effect
setCursorPos(width / 2 - 15, height / 2 - 8)
var titleColor = lerpColor("#00d98e", "#00ffaa", pulse)
setColor(titleColor)
echo "╔═══════════════════════════════╗"
setCursorPos(width / 2 - 15, height / 2 - 7)
echo "║                               ║"
setCursorPos(width / 2 - 15, height / 2 - 6)
echo "║      t|Stauri Desktop         ║"
setCursorPos(width / 2 - 15, height / 2 - 5)
echo "║                               ║"
setCursorPos(width / 2 - 15, height / 2 - 4)
echo "╚═══════════════════════════════╝"

# Pulsing separator
setCursorPos(width / 2 - 15, height / 2 - 2)
setColor("#00d98e")
var barChar = if pulse > 0.5: "━" else: "─"
echo barChar.repeat(33)

# Main instructions with animated cursor
setCursorPos(width / 2 - 15, height / 2)
setColor("#ffffff")
echo "  📄 Drop .md files here"

setCursorPos(width / 2 - 15, height / 2 + 1)
echo "  🖼️  Drop .png files here"

# Animated tip
setCursorPos(width / 2 - 15, height / 2 + 3)
setColor("#00d98e80")
var tipAlpha = int(pulse * 255)
echo "  💡 PNG files can contain workflows"

# Bottom hint
setCursorPos(width / 2 - 15, height / 2 + 6)
setColor("#00d98e60")
echo "     Press ESC to return here"

# Version info in corner
setCursorPos(2, height - 2)
setColor("#00d98e40")
echo "tStauri v0.1.0 | Powered by tStorie"
```

---

**Ready to run your tStorie documents!** ✨
