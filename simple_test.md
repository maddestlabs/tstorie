---
title: "Test"
---

# Test

```nim on:render
bgClear()
bgWriteText(5, 5, "WHITE", defaultStyle())

var redMap = getStyle("red")
if redMap.kind == "map":
  print "Red is a map with keys"
```
