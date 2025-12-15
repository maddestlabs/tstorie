---
targetFPS: 60
title: TStorie Demo
author: Maddest Labs
---

# TStorie Engine

Welcome to TStorie! Edit this file to create your interactive terminal app.

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
```