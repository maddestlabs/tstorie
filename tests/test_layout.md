---
targetFPS: 30
title: Simple Layout Test
---

```nim on:render
# Simple test
var w = termWidth
var h = termHeight

bgWriteTextBox(5, 5, 30, 5, "Hello World", "AlignCenter", "AlignMiddle", "WrapWord")
```
