---
title: "Debug Colors"
styles.test.fg: "#FF0000"
styles.test.bold: "true"
---

# Debug

```nim on:init
print "=== INIT DEBUG ==="
```

```nim on:render
bgClear()

# Test 1: Manual RGB color
var manualStyle = defaultStyle()
manualStyle.fg.r = 255
manualStyle.fg.g = 0
manualStyle.fg.b = 0
manualStyle.bold = true

bgWriteText(5, 3, "Manual RED (255,0,0)", manualStyle)

# Test 2: Using color helpers
var yellowStyle = defaultStyle()
yellowStyle.fg = yellow()
bgWriteText(5, 5, "Yellow helper", yellowStyle)

# Test 3: Using getStyle (from stylesheet)
var testStyle = getStyle("test")
bgWriteText(5, 7, "Stylesheet RED", testStyle)

# Test 4: Check what we got
print "testStyle.fg.r = " & testStyle.fg.r
print "testStyle.fg.g = " & testStyle.fg.g  
print "testStyle.fg.b = " & testStyle.fg.b
print "testStyle.bold = " & testStyle.bold

bgWriteText(5, 10, "Press Q to quit", defaultStyle())
```
