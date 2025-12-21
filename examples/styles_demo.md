# Styles Demo

This example demonstrates tstorie's new style system with front matter configuration.

---
targetFPS: 30
styles.default.fg: "255,255,255"
styles.default.bg: "0,0,0"
styles.heading1.fg: "255,255,0"
styles.heading1.bold: "true"
styles.heading2.fg: "0,255,255"
styles.heading2.bold: "true"
styles.success.fg: "0,255,0"
styles.success.bold: "true"
styles.error.fg: "255,0,0"
styles.error.bold: "true"
styles.warning.fg: "255,165,0"
styles.info.fg: "100,200,255"
styles.muted.fg: "128,128,128"
styles.muted.dim: "true"
---

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
bgWriteText(5, 2, "=== STYLE SYSTEM DEMO ===", h1Style)

# Section headings
bgWriteText(5, 4, "Message Types:", h2Style)

# Different message styles
bgWriteText(7, 6, "[SUCCESS] Operation completed", successStyle)
bgWriteText(7, 7, "[ERROR] Something went wrong", errorStyle)
bgWriteText(7, 8, "[WARNING] Please check this", warningStyle)
bgWriteText(7, 9, "[INFO] For your information", infoStyle)

# Normal text
bgWriteText(5, 11, "Counter with default style: " & $counter, defaultSty)

# Muted footer
bgWriteText(5, 13, "Tip: Edit styles in the front matter!", mutedStyle)

# Color palette demo
bgWriteText(5, 15, "Available Colors:", h2Style)
bgWriteText(7, 17, "Red      ", getStyle("error"))
bgWriteText(7, 18, "Green    ", getStyle("success"))
bgWriteText(7, 19, "Yellow   ", getStyle("heading1"))
bgWriteText(7, 20, "Cyan     ", getStyle("heading2"))
bgWriteText(7, 21, "Orange   ", getStyle("warning"))
bgWriteText(7, 22, "Blue     ", getStyle("info"))
bgWriteText(7, 23, "Gray     ", getStyle("muted"))
```
