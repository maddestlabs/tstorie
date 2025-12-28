---
title: "Minimal Test"
theme: "default"
---

```nim on:init
print "Init: Starting minimal test"
```

```nim on:render
# Clear and draw a simple message
clear()
draw(0, 5, 5, "Hello from exported tStorie!", defaultStyle())
draw(0, 5, 7, "Press Ctrl-C to exit", defaultStyle())
```
