---
title: "Minimal Test"
theme: "default"
---

```nim on:init
print "Init: Starting minimal test"
```

```nim on:render
# Clear and draw a simple message
bgClear()
fgWrite(5, 5, "Hello from exported tStorie!", defaultStyle())
fgWrite(5, 7, "Press Ctrl-C to exit", defaultStyle())
```
