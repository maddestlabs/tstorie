---
targetFPS: 60
title: TStorie Demo
author: Maddest Labs
---

# TStorie Engine

Welcome to TStorie! This is the default demo.

**Note:** The Canvas Interactive Fiction system has been created but requires integration into the main codebase. 

To see canvas examples, check out:
- `examples/canvas_demo.md` - Simple demo
- `depths_nim.md` - Complete adventure

Front matter values are accessible as global variables in your code blocks!

```nim on:render
# Clear the foreground layer each frame
fgFillRect(0, 1, getTermWidth(), getTermHeight() - 3, ".")

# Center a welcome message (using front matter variable)
var msg = "Hello from " & title & "!"
var x = (getTermWidth() - len(msg)) / 2
var y = getTermHeight() / 2
fgWriteText(x, y, msg)

# Draw a border using fillRect
bgFillRect(0, 0, getTermWidth(), 1, "─")
bgFillRect(0, getTermHeight() - 1, getTermWidth(), 1, "─")

# Show FPS and frame counter in top-left
var info = "FPS: " & str(int(getFps())) & " | Frame: " & str(getFrameCount()) & " | Target: " & str(int(getTargetFps()))
fgWriteText(2, 1, info)

# Show author from front matter
fgWriteText(2, 2, "Author: " & author)

# Note about canvas system
var note = "Canvas system: See examples/canvas_demo.md and depths_nim.md"
fgWriteText(2, getTermHeight() - 2, note)
```