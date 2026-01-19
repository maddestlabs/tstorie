---
title: "Hex Viewer Demo"
dropTarget: true
theme: "neotopia"
shader: "invert+sand+ruledlines+paper"
---

# Hex Viewer 🔍

Drop any file to view its hexadecimal representation!

```nim on:init
# State for tracking dropped file
var hasFile = false
var fileName = ""
var fileSize = 0
var bytesPerRow = 16
var scrollOffset = 0
var maxVisibleRows = 0
```

```nim on:ondrop
# Called when a file is dropped
fileName = getDroppedFileName()
fileSize = getDroppedFileSize()
hasFile = true
scrollOffset = 0

# Clear screen and show immediately
clear(0)
```

```nim on:update
# Keep render loop active for input handling
```

```nim on:render
clear(0)

let width = termWidth
let height = termHeight

# Calculate how many rows we can show
maxVisibleRows = height - 8

if not hasFile:
  # Show drop instructions
  let msg = "⬇ Drop any file here to view its hex content"
  draw(0, (width - msg.len) div 2, height div 2, msg)
  
  let hint = "Files will be displayed as hexadecimal bytes"
  draw(0, (width - hint.len) div 2, height div 2 + 2, hint)
else:
  # Show header
  draw(0, 2, 1, "File: " & fileName)
  draw(0, 2, 2, "Size: " & $fileSize & " bytes")
  draw(0, 2, 3, "─".repeat(width - 4))
  
  # Get file data
  let data = getDroppedFileData()
  
  # Calculate total rows and scroll bounds
  let totalRows = (fileSize + bytesPerRow - 1) div bytesPerRow
  let maxScroll = max(0, totalRows - maxVisibleRows)
  
  # Clamp scroll offset
  if scrollOffset < 0:
    scrollOffset = 0
  elif scrollOffset > maxScroll:
    scrollOffset = maxScroll
  
  # Display hex dump
  var row = 5
  let startByte = scrollOffset * bytesPerRow
  let endByte = min(fileSize, startByte + maxVisibleRows * bytesPerRow)
  
  var byteOffset = startByte
  while byteOffset < endByte:
    if row >= height - 2:
      break
    
    # Offset column
    let offsetStr = toHex(byteOffset, 8)
    draw(0, 2, row, offsetStr & ":")
    
    # Hex bytes
    var hexCol = 13
    var asciiCol = 13 + bytesPerRow * 3 + 2
    
    for i in 0..<bytesPerRow:
      let pos = byteOffset + i
      if pos < fileSize:
        let b = getByte(data, pos)
        let hexByte = toHex(b, 2)
        
        # Choose color based on byte value
        var byteStyle = getStyle("default")
        if b == 0:
          # NUL character - default style
          byteStyle = getStyle("default")
        elif b == 9 or b == 10 or b == 13 or b == 32:
          # ASCII whitespace (tab, LF, CR, space)
          byteStyle = getStyle("accent2")
        elif b >= 32 and b <= 126:
          # Printable ASCII
          byteStyle = getStyle("accent1")
        else:
          # All other chars (control chars, extended ASCII)
          byteStyle = getStyle("accent3")
        
        # Draw hex byte with color
        draw(0, hexCol, row, hexByte, byteStyle)
        
        # Draw ASCII character with same color
        var asciiChar = "."
        if b >= 32 and b <= 126:
          asciiChar = $chr(b)
        
        draw(0, asciiCol, row, asciiChar, byteStyle)
        
        hexCol += 3
        asciiCol += 1
    
    row = row + 1
    byteOffset = byteOffset + bytesPerRow
  
  # Show scroll info if file is large
  if totalRows > maxVisibleRows:
    let scrollInfo = "Row " & $(scrollOffset + 1) & "/" & $totalRows & " (↑↓ to scroll)"
    draw(0, 2, height - 2, scrollInfo)
```

```nim on:input
# Handle arrow key scrolling
# === KEYBOARD EVENTS ===
if event.type == "key":
  lastKeyCode = event.keyCode
  lastKeyAction = event.action
  if event.keyCode == KEY_DOWN:
    scrollOffset = scrollOffset + 1
  elif event.keyCode == KEY_UP:
    scrollOffset = scrollOffset - 1
  elif event.keyCode == KEY_PAGEDOWN:
    scrollOffset = scrollOffset + maxVisibleRows
  elif event.keyCode == KEY_PAGEUP:
    scrollOffset = scrollOffset - maxVisibleRows
  elif event.keyCode == KEY_HOME:
    scrollOffset = 0
  elif event.keyCode == KEY_END:
    let totalRows = (fileSize + bytesPerRow - 1) div bytesPerRow
    scrollOffset = max(0, totalRows - maxVisibleRows)
```

## Features

- **Hexadecimal display**: View file contents as hex bytes
- **ASCII preview**: See readable characters alongside hex
- **Scrolling support**: Use arrow keys to navigate large files
- **Address offsets**: Each row shows its byte offset
- **Drop target**: Drag and drop any file type

## Try It!

Drop a `.ans` file, an image, or any binary file to explore its contents.
