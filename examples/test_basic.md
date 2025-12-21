# Test

```nim on:init
var test = 42
```

```nim on:render
var style = defaultStyle()
style.fg = rgb(255, 0, 0)
state.currentBuffer.writeText(5, 5, "Test: " & $test, style)
```
