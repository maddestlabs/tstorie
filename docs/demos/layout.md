---
targetFPS: 30
title: Layout Module Demo
---

# Layout Module Showcase

This demo shows the new layout module capabilities.

```nim on:render
# Clear screen
var w = getTermWidth()
var h = getTermHeight()
draw(0, 0, 0, w, h, " ")

# Title bar - centered
bgWriteTextBox(0, 0, w, 1, title, "AlignCenter", "AlignTop", "WrapNone")
draw(0, 0, 1, w, 1, "─")

# Create three columns to demonstrate horizontal alignment
var colWidth = (w div 3) - 2
var col1X = 1
var col2X = (w div 3) + 1
var col3X = ((w div 3) * 2) + 1
var startY = 3

# Column 1: Left-aligned text with word wrap
draw(0, col1X, startY - 1, "LEFT ALIGNED:")
var leftText = "This text demonstrates left alignment with automatic word wrapping when lines get too long for the column."
fgWriteTextBox(col1X, startY, colWidth, 8, 
               leftText, "AlignLeft", "AlignTop", "WrapWord")

# Column 2: Center-aligned with vertical centering
draw(0, col2X, startY - 1, "CENTER:")
var centerText = "Centered both horizontally and vertically in the box!"
fgWriteTextBox(col2X, startY, colWidth, 8,
               centerText, "AlignCenter", "AlignMiddle", "WrapWord")

# Column 3: Right-aligned
draw(0, col3X, startY - 1, "RIGHT ALIGNED:")
var rightText = "Right aligned text flows to the right edge of the column area."
fgWriteTextBox(col3X, startY, colWidth, 8,
               rightText, "AlignRight", "AlignTop", "WrapWord")

# Separator
draw(0, 0, startY + 9, w, 1, "─")

# Bottom section: Demonstrate ellipsis truncation
var bottomY = startY + 11
draw(0, 2, bottomY, "ELLIPSIS MODE (truncates long lines):")
var longText = "This is a very long line that will be truncated with ellipsis when it exceeds the available width"
fgWriteTextBox(2, bottomY + 1, w - 4, 1,
               longText, "AlignLeft", "AlignTop", "WrapEllipsis")

# Bottom right: Vertical alignment demo
var boxX = w - 22
var boxY = bottomY
draw(0, boxX, boxY, "VERTICAL ALIGN:")
draw(0, boxX, boxY + 1, 20, 5, "·")
fgWriteTextBox(boxX, boxY + 1, 20, 5,
               "BOTTOM", "AlignCenter", "AlignBottom", "WrapNone")

# Footer
var footer = "Frame: " & str(getFrameCount()) & " | Press Ctrl+C to exit"
bgWriteTextBox(0, h - 1, w, 1, footer, "AlignCenter", "AlignTop", "WrapNone")
```
