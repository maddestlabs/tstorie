---
title: "Style System Demo"
targetFPS: 30
styles.default.fg: "#FFFFFF"
styles.default.bg: "#000000"
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
---

# Styles Demo

This example demonstrates tstorie's style system with front matter configuration.


```nim on:init
var counter = 0
```

```nim on:update
counter = counter + 1
```

```nim on:render
bgClear()
fgClear()

# Use predefined styles from front matter
var h1Style = getStyle("heading1")
var h2Style = getStyle("heading2")
var successStyle = getStyle("success")
var errorStyle = getStyle("error")
var warningStyle = getStyle("warning")
var infoStyle = getStyle("info")
var mutedStyle = getStyle("muted")
var defaultSty = defaultStyle()

# Title with heading style
fgWriteText(5, 2, "=== STYLE SYSTEM DEMO ===", h1Style)

# Section headings
fgWriteText(5, 4, "Message Types:", h2Style)

# Different message styles
fgWriteText(7, 6, "[SUCCESS] Operation completed", successStyle)
fgWriteText(7, 7, "[ERROR] Something went wrong", errorStyle)
fgWriteText(7, 8, "[WARNING] Please check this", warningStyle)
fgWriteText(7, 9, "[INFO] For your information", infoStyle)

# Normal text
fgWriteText(5, 11, "Counter with default style: " & $counter, defaultStyle)

# Muted footer
fgWriteText(5, 13, "Tip: Edit styles in the front matter!", mutedStyle)

# Color palette demo
fgWriteText(5, 15, "Available Colors:", h2Style)
fgWriteText(7, 17, "Red      ", getStyle("error"))
fgWriteText(7, 18, "Green    ", getStyle("success"))
fgWriteText(7, 19, "Yellow   ", getStyle("heading1"))
fgWriteText(7, 20, "Cyan     ", getStyle("heading2"))
fgWriteText(7, 21, "Orange   ", getStyle("warning"))
fgWriteText(7, 22, "Blue     ", getStyle("info"))
fgWriteText(7, 23, "Gray     ", getStyle("muted"))
```
