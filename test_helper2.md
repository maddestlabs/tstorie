---
title: Test Helper 2
theme: "futurism"
---

# Test

```nim on:init
# Try calling directly
let result = drawLabel(0, 5, 7, "Test from init", getStyle("info"))
print("drawLabel returned: ")
print(result)
```

```nim on:render
clear()
draw(0, 5, 5, "Init done, now render", getStyle("info"))
```
