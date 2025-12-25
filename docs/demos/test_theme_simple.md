---
title: "Test Theme Functions"
---

```nim on:init
print "Testing theme functions..."

# Test the theme functions directly
var themes = nimini_getThemes()
print "✓ nimini_getThemes() works, found themes: " & str(len(themes))

var current = nimini_getCurrentTheme()
print "✓ nimini_getCurrentTheme() works: " & current

var result = nimini_switchTheme("nord")
print "✓ nimini_switchTheme() works: " & str(result)

print "Done testing!"
```

```nim on:render
bgClear()
bgWriteText(2, 2, "Theme function test - check console", defaultStyle())
```
