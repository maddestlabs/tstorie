# Simple Scoping Test

```nim on:init
var counter = 0
var message = "Starting"
```

```nim on:update
counter = counter + 1

if counter mod 30 == 0:
  message = "Count: " & $counter
```

```nim on:render
bgClear()

var style = defaultStyle()
style.fg = cyan()
style.bold = true

bgWriteText(5, 5, "Counter: " & $counter, style)
bgWriteText(5, 7, message, style)

var localInfo = "This is local to render"
bgWriteText(5, 9, localInfo, style)
```
