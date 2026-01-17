---
title: "Font & Shader Demo"
theme: "catppuccin-mocha"
font: "VT323"
fontsize: 20
shaders: "crt"
minWidth: 60
minHeight: 20
---

# Font & Shader Demo

This demo showcases front matter configuration for fonts and shaders.

**Current Settings:**
- **Font:** VT323 (retro terminal font from Google Fonts)
- **Font Size:** 20px
- **Theme:** Catppuccin Mocha
- **Shaders:** CRT effect
- **Min Size:** 60×20 characters

Try changing the URL parameters to override these defaults:
- `?font=Press+Start+2P` - Use a different font
- `?fontsize=16` - Change font size
- `?shader=invert` - Use a different shader
- `?shader=invert+crt` - Chain multiple shaders

```nim on:init
# Front matter values are exposed as global variables
# They can be used in your code like any other variable
# (This demo displays them in the render block instead)
```

```nim on:render
clear()

var style = getStyle("accent1")
style.bold = true

# Title
draw(0, 2, 2, "╔════════════════════════════════════════════════════════╗", style)
draw(0, 2, 3, "║  FRONT MATTER CONFIGURATION TEST                       ║", style)
draw(0, 2, 4, "╚════════════════════════════════════════════════════════╝", style)

var infoStyle = getStyle("default")
var y = 6

# Show front matter values
draw(0, 4, y, "Front Matter Settings:", getStyle("accent2"))
y = y + 2

# Use string concatenation for all values
var titleStr = "Title:     " & $title
var themeStr = "Theme:     " & $theme
var fontStr = "Font:      " & $font
var fontsizeStr = "Font Size: " & $fontsize & "px"
var shadersStr = "Shaders:   " & $shaders

draw(0, 6, y, titleStr, infoStyle)
y = y + 1
draw(0, 6, y, themeStr, infoStyle)
y = y + 1
draw(0, 6, y, fontStr, infoStyle)
y = y + 1
draw(0, 6, y, fontsizeStr, infoStyle)
y = y + 1
draw(0, 6, y, shadersStr, infoStyle)
y = y + 2

# Instructions
var dimStyle = getStyle("dim")
draw(0, 4, y, "Try These URLs:", getStyle("info"))
y = y + 2

draw(0, 6, y, "?font=Fira+Code&fontsize=16", dimStyle)
y = y + 1
draw(0, 6, y, "?shader=invert+scanlines", dimStyle)
y = y + 1
draw(0, 6, y, "?theme=github-light", dimStyle)
y = y + 2

# Visual test pattern
draw(0, 4, y, "Visual Test Pattern:", getStyle("accent2"))
y = y + 2

var chars = "░▒▓█ ●◐◑◒◓◔◕⬤ ▁▂▃▄▅▆▇█"
draw(0, 6, y, chars, style)
y = y + 1
draw(0, 6, y, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", infoStyle)
y = y + 1
draw(0, 6, y, "abcdefghijklmnopqrstuvwxyz", infoStyle)
y = y + 1
draw(0, 6, y, "0123456789 !@#$%^&*()_+-=", infoStyle)
```
