---
title: "Test Function Registration"
---

```nim on:init
print "Testing nimini_getThemes()..."
var themes = nimini_getThemes()
print "Success! Found " & str(len(themes)) & " themes"
var i = 0
while i < len(themes):
  print "  - " & themes[i]
  i = i + 1
```

```nim on:render
bgClear()
bgWriteText(2, 2, "Check console for debug output", defaultStyle())
```
