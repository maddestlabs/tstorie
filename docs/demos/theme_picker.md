---
title: "Interactive Theme Picker"
minWidth: 80
minHeight: 24
theme: "catppuccin"
---

```nim on:init
# Simple interactive theme picker demo
var themes = nimini_getThemes()
var selectedIndex = 0

# Find current theme
var currentTheme = nimini_getCurrentTheme()
if currentTheme == "":
  currentTheme = "catppuccin"

var i = 0
while i < len(themes):
  if themes[i] == currentTheme:
    selectedIndex = i
  i = i + 1

print "Theme picker initialized with " & str(len(themes)) & " themes"
```

```nim on:input
if event.type == "key" and event.action == "press":
  # Up arrow: previous theme
  if event.keyCode == 1000:  # INPUT_UP
    selectedIndex = (selectedIndex - 1 + len(themes)) % len(themes)
    nimini_switchTheme(themes[selectedIndex])
    return true
  
  # Down arrow: next theme
  elif event.keyCode == 1001:  # INPUT_DOWN
    selectedIndex = (selectedIndex + 1) % len(themes)
    nimini_switchTheme(themes[selectedIndex])
    return true
  
  # T key: also cycle themes
  elif event.keyCode == 116 or event.keyCode == 84:  # 't' or 'T'
    selectedIndex = (selectedIndex + 1) % len(themes)
    nimini_switchTheme(themes[selectedIndex])
    return true

return false
```

```nim on:render
bgClear()
fgClear()

# Title
var titleStyle = getStyle("heading")
titleStyle.bold = true
var title = "🎨 Interactive Theme Picker"
var titleLen = len(title)
var titleX = termWidth - titleLen
titleX = titleX div 2
fgWriteText(titleX, 3, title, titleStyle)

# Instructions
var bodyStyle = getStyle("body")
fgWriteText(10, 6, "Use ↑/↓ arrow keys or press T to cycle through themes", bodyStyle)
fgWriteText(10, 7, "Watch the colors change in real-time!", bodyStyle)

# Current theme display
var currentStyle = getStyle("heading2")
currentStyle.bold = true
var currentLabel = "Current Theme: " & themes[selectedIndex]
var currentLen = len(currentLabel)
var currentX = termWidth - currentLen
currentX = currentX div 2
fgWriteText(currentX, 10, currentLabel, currentStyle)

# Theme list
var listY = 13
var i = 0
while i < len(themes):
  var themeName = themes[i]
  var displayStyle = if i == selectedIndex: getStyle("link_focused") else: getStyle("link")
  
  # Add indicator for selected theme
  var prefix = if i == selectedIndex: "▶ " else: "  "
  var display = prefix & themeName
  
  fgWriteText(30, listY + i, display, displayStyle)
  i = i + 1

# Sample content to show theme colors
var sampleY = listY + len(themes) + 3
var h3Style = getStyle("heading3")
fgWriteText(10, sampleY, "Sample Text Elements:", h3Style)

var linkStyle = getStyle("link")
fgWriteText(10, sampleY + 2, "• Regular body text (readable)", bodyStyle)
fgWriteText(10, sampleY + 3, "• Highlighted link text", linkStyle)

var codeStyle = getStyle("code")
fgWriteText(10, sampleY + 4, "• Code snippet: var x = 42", codeStyle)

var emphasisStyle = getStyle("emphasis")
fgWriteText(10, sampleY + 5, "• Emphasized content", emphasisStyle)

# Footer
var footerStyle = getStyle("placeholder")
fgWriteText(2, termHeight - 2, "Press Q to quit", footerStyle)
```

```nim on:update
# Nothing to update
```
