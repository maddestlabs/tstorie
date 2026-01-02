---
title: "Style System Demo"
targetFPS: 30
styles.heading1.fg: "#FFFF00"
styles.heading1.bold: "true"
styles.heading2.fg: "#00FFFF"
styles.heading2.bold: "true"
styles.success.fg: "#00FF00"
styles.success.bold: "true"
styles.error.fg: "#FF0000"
styles.error.bold: "true"
styles.warning.fg: "#FFA500"
styles.info.fg: "#64C8FF"
styles.muted.fg: "#808080"
styles.muted.dim: "true"
styles.counter.fg: "#FFFFFF"
styles.counter.bg: "#0000ff"
theme: "catppuccin"
---

# Styles Demo

This example demonstrates t|Storie's style system with front matter configuration. Theme selection sets defaults which are overriden by specifying styles during draw() operations.


```nim on:init
var counter = 0
```

```nim on:update
counter = counter + 1
```

```nim on:render
clear()

# Use predefined styles from front matter
var h1Style = getStyle("heading1")
var h2Style = getStyle("heading2")
var successStyle = getStyle("success")
var errorStyle = getStyle("error")
var warningStyle = getStyle("warning")
var infoStyle = getStyle("info")
var mutedStyle = getStyle("muted")
var counterStyle = getStyle("counter")

# Title with heading style
draw(0, 5, 2, "=== STYLE SYSTEM DEMO ===", h1Style)

# Section headings
draw(0, 5, 4, "Message Types:", h2Style)

# Different message styles
draw(0, 7, 6, "[SUCCESS] Operation completed", successStyle)
draw(0, 7, 7, "[ERROR] Something went wrong", errorStyle)
draw(0, 7, 8, "[WARNING] Please check this", warningStyle)
draw(0, 7, 9, "[INFO] For your information", infoStyle)

# Normal text
draw(0, 5, 11, "Counter with default style: " & $counter, counterStyle)

# Muted footer
draw(0, 5, 13, "Tip: Edit styles in the front matter!", mutedStyle)

# Color palette demo
draw(0, 5, 15, "Available Colors:", h2Style)
draw(0, 7, 17, "Red      ", getStyle("error"))
draw(0, 7, 18, "Green    ", getStyle("success"))
draw(0, 7, 19, "Yellow   ", getStyle("heading1"))
draw(0, 7, 20, "Cyan     ", getStyle("heading2"))
draw(0, 7, 21, "Orange   ", getStyle("warning"))
draw(0, 7, 22, "Blue     ", getStyle("info"))
draw(0, 7, 23, "Gray     ", getStyle("muted"))
```
