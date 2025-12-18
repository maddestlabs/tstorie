---
title: "Test File"
author: "Test"
targetFPS: 60
---

```nim on:render
var msg = "Successfully loaded: " & title
var x = (getTermWidth() - len(msg)) / 2
var y = getTermHeight() / 2
fgWriteText(x, y, msg)

var file = "This is test_file.md!"
var fx = (getTermWidth() - len(file)) / 2
var fy = y + 2
fgWriteText(fx, fy, file)
```
