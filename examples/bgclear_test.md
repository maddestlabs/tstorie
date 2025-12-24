---
title: "bgClear Test"
theme: "catppuccin"
minWidth: 80
minHeight: 24
---

```nim on:init
print "Testing bgClear with Catppuccin theme"
```

```nim on:render
# Just call bgClear() - this should fill the screen with purple background
bgClear()

# Write some text to verify it's visible
var bodyStyle = getStyle("body")
fgWrite(2, 2, "If you see purple background, bgClear() works!", bodyStyle)
fgWrite(2, 4, "The entire screen should be Catppuccin purple (30,30,46)", bodyStyle)
```

This test verifies that bgClear() properly fills the screen with the theme's background color.
