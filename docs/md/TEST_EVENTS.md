# Event Test - Mouse & Keyboard

Testing event handling in WASM build loaded from gist.

```nim on:init
# Initialize state
var clickCount = 0
var keyCount = 0
var lastKey = "none"
var mouseX = 0
var mouseY = 0
```

```nim on:input
# Handle events
if event.type == "mouse":
  mouseX = event.x
  mouseY = event.y
  if event.action == "press":
    clickCount = clickCount + 1
  return true

elif event.type == "key":
  keyCount = keyCount + 1
  if event.keyCode == 27:
    lastKey = "ESC"
  elif event.keyCode == 32:
    lastKey = "SPACE"
  else:
    lastKey = "KEY_" & str(event.keyCode)
  return false

return false
```

```nim on:render
# Clear and draw
bgClear()

# Title
bgWriteText(2, 2, "=== EVENT TEST (WASM) ===")

# Instructions
bgWriteText(2, 4, "Click anywhere or press any key")
bgWriteText(2, 5, "Events should be counted below:")

# Display counts
bgWriteText(2, 7, "Clicks: " & str(clickCount))
bgWriteText(2, 8, "Keys: " & str(keyCount))
bgWriteText(2, 9, "Last Key: " & lastKey)
bgWriteText(2, 10, "Mouse: (" & str(mouseX) & ", " & str(mouseY) & ")")

# Status indicator
if clickCount > 0 or keyCount > 0:
  bgWriteText(2, 12, "✓ EVENTS WORKING!")
else:
  bgWriteText(2, 12, "Waiting for events...")
```
