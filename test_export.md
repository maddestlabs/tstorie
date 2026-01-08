# Test Export

Simple app to test terminal cleanup in exported programs.

```nim [init]
var counter = 0
```

```nim [update]
counter += 1
```

```nim [render]
text 0, 0, "Counter: " & $counter
text 0, 1, "Press CTRL-C to exit"
text 0, 2, "Terminal should be restored properly"
```
