---
title: "Color Test"
styles.red.fg: "#FF0000"
styles.red.bold: "true"
styles.green.fg: "#00FF00"
styles.blue.fg: "#0000FF"
styles.yellow.fg: "#FFFF00"
---

# Color Test

```nim on:init
bgClear()
```

```nim on:render
bgClear()

var redStyle = getStyle("red")
var greenStyle = getStyle("green")
var blueStyle = getStyle("blue")
var yellowStyle = getStyle("yellow")

bgWriteText(10, 5, "This should be RED", redStyle)
bgWriteText(10, 7, "This should be GREEN", greenStyle)
bgWriteText(10, 9, "This should be BLUE", blueStyle)
bgWriteText(10, 11, "This should be YELLOW", yellowStyle)

# Also test default canvas styles
bgWriteText(10, 15, "Press Q to quit", defaultStyle())
```
