---
title: "Simple Sections Demo"
author: "TStorie"
targetFPS: 30
---

# First Section

Welcome to the sections demo! This demonstrates section navigation.

Use arrow keys to navigate:
- Down arrow (or ]) - next section
- Up arrow (or [) - previous section

```nim on:init
var currentIdx = 0
var maxSections = 0
```

```nim on:render
bgClear()

# Get section info
maxSections = nimini_getSectionCount()
currentIdx = nimini_getCurrentSectionIndex()

# Display section counter
let info = "Section " & $(currentIdx + 1) & " of " & $maxSections
bgWriteText(2, 2, info)

# Show section title
let sect = nimini_getCurrentSection()
let sectTitle = sect["id"]
bgWriteText(2, 4, "Section ID: " & sectTitle)
```

```nim on:input
# Navigate with arrow keys
if keyCode == 66:  # Down arrow
  if currentIdx < maxSections - 1:
    nimini_gotoSection(currentIdx + 1)
elif keyCode == 65:  # Up arrow
  if currentIdx > 0:
    nimini_gotoSection(currentIdx - 1)
```

# Second Section

This is the second section. Navigate back and forth to test!

```nim on:render
bgWriteText(2, 6, "This is section 2")
bgWriteText(2, 8, "Press arrows to navigate")
```

# Third Section

The final section. You can add more by adding more headings!

```nim on:render
bgWriteText(2, 10, "This is section 3")  
bgWriteText(2, 12, "End of demo!")
```
