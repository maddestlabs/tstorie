# TStorie Engine

Welcome to TStorie! Edit this file to create your interactive terminal app.

```nim on:render
# Clear the foreground layer each frame
fgFillRect(0, 1, termWidth, termHeight - 3, ".")

# Center a welcome message
var msg = "Hello from TStorie!"
var x = (termWidth - 19) / 2
var y = termHeight / 2
fgWriteText(x, y, msg)

# Draw a border using fillRect
bgFillRect(0, 0, termWidth, 1, "─")
bgFillRect(0, termHeight - 1, termWidth, 1, "─")

# Show FPS and frame counter in top-left
fgWriteText(2, 1, "FPS: " & $int(fps) & " | Frame: " & $frameCount)
```
