---
theme: "cyberpunk"
title: "ASCII Art Demo"
---

# ASCII Art Demo

This demo shows ASCII art support using tStorie's content blocks.

```nim on:init
# Load ASCII art into global variables using getContent()
var robotArt = getContent("ascii:robot")
var bannerArt = getContent("ascii:banner")
var frameArt = getContent("ascii:frame")
```

```nim on:render
clear()

# Basic ASCII Art
draw(0, 2, 2, "Basic ASCII Art:")
drawAscii(0, 2, 3, "robot")

# With Style
draw(0, 2, 12, "With Style:")
var style = getStyle("accent")
drawAscii(0, 2, 13, "banner", style)

# Manual processing with pre-loaded globals
draw(0, 40, 2, "Manual (using globals):")
var y = 3
for line in frameArt:
  draw(0, 40, y, line)
  y = y + 1
draw(0, 40, y + 1, "Lines: " & $(len(frameArt)))

# Show loaded art info
draw(0, 40, y + 3, "Loaded art pieces:")
draw(0, 40, y + 4, "  robot: " & $(len(robotArt)) & " lines")
draw(0, 40, y + 5, "  banner: " & $(len(bannerArt)) & " lines")
draw(0, 40, y + 6, "  frame: " & $(len(frameArt)) & " lines")
```

```ascii:robot
    ___
   [o_o]
   |\_/|
  //   \\
 (|     |)
/'\_   _/`\
\___)=(___/
```

```ascii:banner
 █████╗ ███████╗ ██████╗██╗██╗
██╔══██╗██╔════╝██╔════╝██║██║
███████║███████╗██║     ██║██║
██╔══██║╚════██║██║     ██║██║
██║  ██║███████║╚██████╗██║██║
╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝╚═╝
```

```ascii:frame
╔═══════════════╗
║               ║
║   CONTENT     ║
║   GOES HERE   ║
║               ║
╚═══════════════╝
```

