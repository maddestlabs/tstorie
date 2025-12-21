---
targetFPS: 30
title: Layout Test
---

```nim on:render
# Simple layout test
bgFillRect(0, 0, getTermWidth(), getTermHeight(), " ")

var w = getTermWidth()
var h = getTermHeight()

# Test centered title
bgWriteTextBox(0, 0, w, 1, "LAYOUT DEMO", "AlignCenter", "AlignTop", "WrapNone")

# Test left aligned
fgWriteTextBox(5, 3, 40, 5, "This is left-aligned text that wraps nicely", "AlignLeft", "AlignTop", "WrapWord")

# Test center aligned
fgWriteTextBox(5, 10, w, 5, "This is centered text", "AlignCenter", "AlignMiddle", "WrapWord")
```
