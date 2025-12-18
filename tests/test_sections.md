---
title: "Section Test"
targetFPS: 30
---

# Test Section

Simple test for section functions.

```nim on:render
# Test basic section access
bgClear()

# Test getting section count
let count = nimini_getSectionCount()
bgWriteText(2, 2, "Sections: " & $count)

# Test getting current index  
let idx = nimini_getCurrentSectionIndex()
bgWriteText(2, 3, "Current index: " & $idx)
```
