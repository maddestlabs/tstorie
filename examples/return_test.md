---
title: Return Value Test
---

# Test Return Values

This tests if return values work at all.

```nim on:init
var testCounter = 0
```

```nim on:input
# Increment counter for ANY event
testCounter = testCounter + 1

# Only consume 'a' key
if event.type == "key" and event.keyCode == 97:
  return 1  # Consume 'a'
else:
  return 0  # Don't consume others (q should work to quit)
```

```nim on:render
bgClear()
bgWriteText(2, 2, "Return Value Test")
bgWriteText(2, 4, "Events received: " & str(testCounter))
bgWriteText(2, 6, "Press 'a' (should be consumed)")
bgWriteText(2, 7, "Press 'q' (should quit if return 0 works)")
```
