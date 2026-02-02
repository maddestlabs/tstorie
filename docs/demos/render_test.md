---
title: "Direct Rendering Test"
theme: "monokai"
---

# Direct Rendering Test

Testing if rendering works at all.

```nim on:render
clear()
drawLabel(0, 5, 5, "Hello World!", getStyle("info"))
drawBoxSingle(0, 10, 10, 20, 5, getStyle("default"))
drawCenteredText(0, 10, 10, 20, 5, "Box Test", getStyle("default"))
```

```nim on:input
if event.type == "text" and event.text == "q":
  quit(0)
```
