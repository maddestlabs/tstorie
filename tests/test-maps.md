# Map Literals Test

Testing map literal syntax in TStorie.

```nim on:init
var config = {"width": 80, "height": 24, "title": "Test"}
```

# TStorie Engine

Welcome to TStorie! Edit this file to create your interactive terminal app.

```nim on:render
# Clear the foreground layer each frame
fgFillRect(0, 1, termWidth, termHeight - 3, ".")
fgWriteText(2, 2, "Map test:")
fgWriteText(2, 3, "Width: " & $config["width"])
fgWriteText(2, 4, "Height: " & $config["height"])
fgWriteText(2, 5, "Title: " & config["title"])
```
