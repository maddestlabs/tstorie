# Test Crash Recovery

This document tests terminal cleanup on crashes.

```nim [init]
var counter = 0
```

```nim [update]
counter += 1

# After 1 second, trigger a crash
if counter > 60:
  # This will cause a runtime error
  var arr: array[1, int]
  echo arr[999]  # Out of bounds access
```

```nim [render]
text 0, 0, "Counter: " & $counter
text 0, 1, "Waiting for crash..."
```
