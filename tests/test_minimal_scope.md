# Minimal Scoping Test

```nim on:init
var globalCounter = 0
var globalMessage = "Init complete"
print("INIT: Created globalCounter = 0")
```

```nim on:update
# Local variable test
var localDelta = 1
globalCounter = globalCounter + localDelta

# Try to create a local that shadows (should create new local)
if globalCounter mod 30 == 0:
  print("UPDATE (frame " & $globalCounter & "): globalCounter incremented")
  globalMessage = "Updated at frame " & $globalCounter
```

```nim on:render
# This should be able to read globals
print("RENDER: globalCounter=" & $globalCounter & " globalMessage=" & globalMessage)

# Local variable in render
var renderLocal = "This is local to render block"
print("RENDER: renderLocal=" & renderLocal)
```
