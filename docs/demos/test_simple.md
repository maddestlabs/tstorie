---
title: "Test Simple"
---

```nim on:init

var width = 79
var height = 25

proc test(w: int, h: int): seq =
  var result = newSeq(0)
  return result

var grid = test(width, height)

```

```nim on:render
clear()
draw(0, 0, 0, "Test passed!")
```
