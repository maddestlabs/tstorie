---
title: "StyleConfig Conversion Test"
theme: "catppuccin"
minWidth: 40
minHeight: 10
---

```nim on:init
# Test StyleConfig to Value conversion
print "=== StyleConfig Conversion Test ==="

# Get a style from the stylesheet
var bodyStyle = getStyle("body")

# Check what RGB values we got back
print "Body style bg.r = " & $bodyStyle.bg.r
print "Body style bg.g = " & $bodyStyle.bg.g  
print "Body style bg.b = " & $bodyStyle.bg.b

# Expected: (30, 30, 46) for Catppuccin
# If we see (0, 0, 0), the conversion is broken
```

```nim on:render
# Just clear and show a message
bgClear()
fgWrite(2, 2, "Check terminal output above for test results", getStyle("body"))
```

Test to verify StyleConfig → Nimini Value conversion preserves RGB values.
Check the terminal output when running this file - it should show the RGB values.
