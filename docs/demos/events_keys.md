# Keyboard Event Test

This example demonstrates keyboard event handling in tstorie.

```nim on:init
# Track keyboard state
var lastKey = "none"
var lastKeyCode = 0
var lastAction = "none"
var keyPressCount = 0
var shiftPressed = false
var ctrlPressed = false
var altPressed = false
```

```nim on:input
# Handle keyboard events through the normal input lifecycle
if event.type == "key":
  lastKeyCode = event.keyCode
  lastAction = event.action
  
  # Convert keyCode to readable name for common keys
  if lastKeyCode == 27:
    lastKey = "ESC"
  elif lastKeyCode == 13:
    lastKey = "ENTER"
  elif lastKeyCode == 32:
    lastKey = "SPACE"
  elif lastKeyCode == 9:
    lastKey = "TAB"
  elif lastKeyCode == 127:
    lastKey = "BACKSPACE"
  elif lastKeyCode == 1000:
    lastKey = "UP"
  elif lastKeyCode == 1001:
    lastKey = "DOWN"
  elif lastKeyCode == 1002:
    lastKey = "LEFT"
  elif lastKeyCode == 1003:
    lastKey = "RIGHT"
  elif lastKeyCode >= 32 and lastKeyCode < 127:
    # Printable ASCII character
    lastKey = "'" & str(lastKeyCode) & "'"
  else:
    lastKey = "KEY_" & str(lastKeyCode)
  
  if event.action == "press":
    keyPressCount = keyPressCount + 1
  
  return false  # Don't consume - allow default quit behavior

elif event.type == "text":
  # Handle text input (alphanumeric keys)
  lastKey = "'" & event.text & "'"
  lastKeyCode = 0
  lastAction = "text"
  keyPressCount = keyPressCount + 1
  return false

return false
```

```nim on:render
# Clear screen
bgClear()

# Draw title  
bgWriteText(2, 2, "=== KEYBOARD EVENT TEST ===")

# Draw instructions
bgWriteText(2, 4, "Press any key to test keyboard input")
bgWriteText(2, 5, "Press Q or ESC to quit")

# Display keyboard state
bgWriteText(2, 7, "Last Key: " & lastKey)
bgWriteText(2, 8, "Key Code: " & str(lastKeyCode))
bgWriteText(2, 9, "Action: " & lastAction)
bgWriteText(2, 10, "Press Count: " & str(keyPressCount))

# Draw a visual keyboard hint
bgWriteText(2, 13, "Common Keys:")
bgWriteText(4, 15, "Arrows: UP/DOWN/LEFT/RIGHT")
bgWriteText(4, 16, "Special: ESC, ENTER, SPACE, TAB")
bgWriteText(4, 17, "Letters: a-z, A-Z")
bgWriteText(4, 18, "Numbers: 0-9")

# Show a press counter box
bgWriteText(50, 7, "+-------------------+")
bgWriteText(50, 8, "| Total Key Presses |")
bgWriteText(50, 9, "|                   |")
var countStr = str(keyPressCount)
var padding = 19 - countStr.len
var leftPad = padding / 2
var rightPad = padding - leftPad
var i = 0
var paddedCount = ""
while i < leftPad:
  paddedCount = paddedCount & " "
  i = i + 1
paddedCount = paddedCount & countStr
i = 0
while i < rightPad:
  paddedCount = paddedCount & " "
  i = i + 1
bgWriteText(50, 10, "| " & paddedCount & " |")
bgWriteText(50, 11, "+-------------------+")

# Visual feedback for last action
if lastAction == "press":
  bgWriteText(2, 20, ">>> KEY PRESSED <<<")
elif lastAction == "release":
  bgWriteText(2, 20, ">>> KEY RELEASED <<<")
elif lastAction == "repeat":
  bgWriteText(2, 20, ">>> KEY REPEATING <<<")
```

```nim on:shutdown
# Cleanup
```
