# Test Export Simple

Simple app to test terminal cleanup in exported programs.

```nim [init]
var counter = 0
```

```nim [update]
counter += 1
```

```nim [render]
draw "default", 0, 0, "Counter: " & $counter, getStyle("default")
draw "default", 0, 1, "Press CTRL-C to exit", getStyle("default")
draw "default", 0, 2, "Terminal should be restored properly", getStyle("default")
```
