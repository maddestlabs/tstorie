---
title: "Interactive Theme Picker"
theme: "neotopia"
---

# 🎨 Interactive Theme Picker

Select a theme to see it applied instantly!

```nim
import storie_themes
import tui3

# Get current theme
let currentParam = getParam("theme")
let currentTheme = getTheme(currentParam)

# List of built-in themes
let themes = @[
  ("Neotopia", "neotopia"),
  ("Neonopia", "neonopia"),
  ("Catppuccin", "catppuccin"),
  ("Nord", "nord"),
  ("Dracula", "dracula"),
  ("Outrun", "outrun"),
  ("Alleycat", "alleycat"),
  ("Terminal", "terminal"),
  ("Solarized Dark", "solardark"),
  ("Solarized Light", "solarlight"),
  ("Coffee", "coffee"),
  ("Stone Garden", "stonegarden"),
  ("WAT", "wat")
]

# Create theme selector UI
print("\nCurrent Theme: " & (if currentParam == "": "neotopia" else: currentParam))
print("")

# Draw theme buttons in a grid
let canvas = canvas(70, 30)

# Title
let title = "Choose Your Theme:"
for i, c in title:
  canvas.plot(i + 2, 1, $c, currentTheme.accent1, currentTheme.bg)

# Draw theme buttons (3 columns)
var row = 3
var col = 2
let buttonWidth = 20
let buttonHeight = 2

for i, themePair in themes:
  let (name, themeId) = themePair
  let theme = getTheme(themeId)
  
  # Calculate position
  let x = col
  let y = row
  
  # Draw button background
  for by in 0..<buttonHeight:
    for bx in 0..<buttonWidth:
      let plotX = x + bx
      let plotY = y + by
      
      if plotX < 70 and plotY < 30:
        # Use theme's primary accent for button background
        canvas.plot(plotX, plotY, " ", theme.fg, theme.accent1)
  
  # Draw button text (centered)
  let padding = (buttonWidth - name.len) div 2
  for j, c in name:
    let plotX = x + padding + j
    let plotY = y
    if plotX < 70 and plotY < 30:
      canvas.plot(plotX, plotY, $c, theme.bg, theme.accent1)
  
  # Draw theme ID hint
  let hint = "?" & themeId
  for j, c in hint:
    let plotX = x + j + 1
    let plotY = y + 1
    if plotX < 70 and plotY < 30:
      canvas.plot(plotX, plotY, $c, theme.bgAlt, theme.accent1)
  
  # Move to next position
  col += buttonWidth + 3
  if col > 50:
    col = 2
    row += buttonHeight + 2

canvas.render()

# Instructions
print("\n" & repeat("─", 60))
print("\n📋 To switch themes, add ?theme= to the URL:")
print("   Example: ?theme=dracula")
print("   Example: ?theme=#001111#09343a#e0e0e0#909090#00d98e#ffff00#ff006e")
print("\n💡 Use the theme builder for custom colors:")
print("   http://localhost:8001/theme-builder.html")
```

## Color Preview

```nim
import tui3

print("\n\n🎨 Current Theme Colors:")
print("")

# Create color swatches
let swatchCanvas = canvas(60, 15)

# Background swatches
for y in 0..2:
  for x in 0..19:
    swatchCanvas.plot(x + 2, y + 2, "█", currentTheme.bg, currentTheme.bg)
    swatchCanvas.plot(x + 25, y + 2, "█", currentTheme.bgAlt, currentTheme.bgAlt)

# Foreground swatches
for y in 0..2:
  for x in 0..19:
    swatchCanvas.plot(x + 2, y + 6, "█", currentTheme.fg, currentTheme.fg)
    swatchCanvas.plot(x + 25, y + 6, "█", currentTheme.fgAlt, currentTheme.fgAlt)

# Accent swatches
for y in 0..2:
  for x in 0..19:
    swatchCanvas.plot(x + 2, y + 10, "█", currentTheme.accent1, currentTheme.accent1)
for y in 0..2:
  for x in 0..19:
    swatchCanvas.plot(x + 22, y + 10, "█", currentTheme.accent2, currentTheme.accent2)
for y in 0..2:
  for x in 0..19:
    swatchCanvas.plot(x + 42, y + 10, "█", currentTheme.accent3, currentTheme.accent3)

# Labels
let labels = @[
  (2, 1, "BG Primary"),
  (25, 1, "BG Secondary"),
  (2, 5, "FG Primary"),
  (25, 5, "FG Secondary"),
  (2, 9, "Accent 1"),
  (22, 9, "Accent 2"),
  (42, 9, "Accent 3")
]

for label in labels:
  let (x, y, text) = label
  for i, c in text:
    swatchCanvas.plot(x + i, y, $c, currentTheme.fg, currentTheme.bg)

swatchCanvas.render()

# Hex values
print("\n\n📐 Hex Values:")
print("  BG Primary:   #" & toHexString(currentTheme.bg))
print("  BG Secondary: #" & toHexString(currentTheme.bgAlt))
print("  FG Primary:   #" & toHexString(currentTheme.fg))
print("  FG Secondary: #" & toHexString(currentTheme.fgAlt))
print("  Accent 1:     #" & toHexString(currentTheme.accent1))
print("  Accent 2:     #" & toHexString(currentTheme.accent2))
print("  Accent 3:     #" & toHexString(currentTheme.accent3))

# Shareable URL
print("\n\n🔗 Shareable URL:")
print("  ?theme=" & toHexString(currentTheme))
```
