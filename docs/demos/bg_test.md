---
title: "Background Color Test"
theme: "catppuccin"
minWidth: 80
minHeight: 24
---

```nim on:init
print "Testing background colors with theme"
```

```nim on:render
# First clear to theme background
clear()

# Fill entire screen with spaces using theme background
# This should show the Catppuccin purple background
var w = termWidth
var h = termHeight

# Get styles from stylesheet
var bodyStyle = getStyle("body")
var headingStyle = getStyle("heading")
var linkStyle = getStyle("link")
var placeholderStyle = getStyle("placeholder")

# Fill with solid color blocks to test background rendering
fillRect(0, 0, 0, w, 5, "█", bodyStyle)
fillRect(0, 0, 5, w, 5, "▓", headingStyle)
fillRect(0, 0, 10, w, 5, "▒", linkStyle)
fillRect(0, 0, 15, w div 2, 5, "░", placeholderStyle)

# Write some text on the foreground
draw(0, 2, 2, "Body style (should have purple bg)", bodyStyle)
draw(0, 2, 7, "Heading style (should have purple bg)", headingStyle)
draw(0, 2, 12, "Link style (should have purple bg)", linkStyle)
draw(0, 2, 17, "Placeholder style (should have purple bg)", placeholderStyle)

# Bottom test area - plain text
draw(0, 2, 22, "Check console output for background RGB values", bodyStyle)
```

This test fills the screen with different styled rectangles to verify that:
1. The theme background color (Catppuccin purple) is applied to all styles
2. bgClear() properly clears to the theme background
3. Filled rectangles inherit the background color from their style

If any rectangles show **black backgrounds** instead of purple, the theme system isn't working correctly.
