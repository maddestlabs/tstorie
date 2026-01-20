---
title: "Edit Demo Key Test"
theme: "catppuccin"
---

Quick test for edit.md key handling system.

```nim on:init
var testResults: seq[string] = @[]
var testsPassed = 0
var testsFailed = 0

# Test that KEY constants are accessible
proc testKeyConstants() =
  # Arrow keys (1000-1003)
  if KEY_UP == 1000:
    add(testResults, "✓ KEY_UP = 1000")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_UP != 1000")
    testsFailed = testsFailed + 1
  
  if KEY_DOWN == 1001:
    add(testResults, "✓ KEY_DOWN = 1001")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_DOWN != 1001")
    testsFailed = testsFailed + 1
  
  if KEY_LEFT == 1002:
    add(testResults, "✓ KEY_LEFT = 1002")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_LEFT != 1002")
    testsFailed = testsFailed + 1
  
  if KEY_RIGHT == 1003:
    add(testResults, "✓ KEY_RIGHT = 1003")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_RIGHT != 1003")
    testsFailed = testsFailed + 1
  
  # Navigation keys
  if KEY_HOME == 1004:
    add(testResults, "✓ KEY_HOME = 1004")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_HOME != 1004")
    testsFailed = testsFailed + 1
  
  if KEY_END == 1005:
    add(testResults, "✓ KEY_END = 1005")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_END != 1005")
    testsFailed = testsFailed + 1
  
  if KEY_PAGEUP == 1006:
    add(testResults, "✓ KEY_PAGEUP = 1006")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_PAGEUP != 1006")
    testsFailed = testsFailed + 1
  
  if KEY_PAGEDOWN == 1007:
    add(testResults, "✓ KEY_PAGEDOWN = 1007")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_PAGEDOWN != 1007")
    testsFailed = testsFailed + 1
  
  # Function keys
  if KEY_F1 == 1100:
    add(testResults, "✓ KEY_F1 = 1100")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_F1 != 1100")
    testsFailed = testsFailed + 1
  
  # Control keys
  if KEY_ESCAPE == 27:
    add(testResults, "✓ KEY_ESCAPE = 27")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_ESCAPE != 27")
    testsFailed = testsFailed + 1
  
  if KEY_RETURN == 13:
    add(testResults, "✓ KEY_RETURN = 13")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_RETURN != 13")
    testsFailed = testsFailed + 1
  
  if KEY_BACKSPACE == 8:
    add(testResults, "✓ KEY_BACKSPACE = 8")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_BACKSPACE != 8")
    testsFailed = testsFailed + 1
  
  if KEY_DELETE == 127:
    add(testResults, "✓ KEY_DELETE = 127")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_DELETE != 127")
    testsFailed = testsFailed + 1
  
  # Letter keys
  if KEY_S == 83:
    add(testResults, "✓ KEY_S = 83")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_S != 83")
    testsFailed = testsFailed + 1
  
  if KEY_O == 79:
    add(testResults, "✓ KEY_O = 79")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_O != 79")
    testsFailed = testsFailed + 1
  
  if KEY_Q == 81:
    add(testResults, "✓ KEY_Q = 81")
    testsPassed = testsPassed + 1
  else:
    add(testResults, "✗ KEY_Q != 81")
    testsFailed = testsFailed + 1

# Run tests
testKeyConstants()
```

```nim on:render
clear()

moveCursor(0, 0)
setFg(3)  # cyan
write("=== Edit.md Key Constant Test ===")

var y = 2
var i = 0
while i < len(testResults):
  moveCursor(0, y)
  let result = testResults[i]
  if result[0] == '✓':
    setFg(2)  # green
  else:
    setFg(1)  # red
  write(result)
  y = y + 1
  i = i + 1

moveCursor(0, y + 1)
setFg(7)
write("─────────────────────────────────────")

moveCursor(0, y + 2)
if testsFailed == 0:
  setFg(2)
  write("✓ All tests passed! (" & str(testsPassed) & "/" & str(testsPassed) & ")")
else:
  setFg(1)
  write("✗ Some tests failed: " & str(testsPassed) & " passed, " & str(testsFailed) & " failed")

moveCursor(0, y + 4)
setFg(7)
write("Press Q or ESC to quit")
```

```nim on:input
if event.type == "key":
  if event.keyCode == KEY_Q or event.keyCode == KEY_ESCAPE:
    exit()
return false
```
