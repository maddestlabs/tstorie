---
title: Test Input Return Values
---

# Test Input Return Values

This tests that return values from on:input blocks properly control event consumption.

```nim on:init
var keyPresses = 0
var unhandledKeys = 0
```

```nim on:input
# Only handle 'a' key, let others pass through
if event.type == "key" and event.action == "press":
  if event.keyCode == 97:  # 'a' key
    keyPresses = keyPresses + 1
    return 1  # Consume this event
  else:
    unhandledKeys = unhandledKeys + 1
    return 0  # Don't consume, let it propagate to default handlers

return 0  # Don't consume other events
```

```nim on:render
bgClear()

bgWriteText(2, 2, "=== Input Return Value Test ===")
bgWriteText(2, 4, "Press 'a' to increment counter")
bgWriteText(2, 5, "Press 'q' to quit")
bgWriteText(2, 7, "A key presses: " & str(keyPresses))
bgWriteText(2, 8, "Other keys: " & str(unhandledKeys))
bgWriteText(2, 10, "If 'q' works to quit, return values work!")
```
