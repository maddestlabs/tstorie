---
title: "Rich Text Editor Demo"
minWidth: 100
minHeight: 30
theme: "futurism"
---

# TStorie Text Editor

A fully-featured text editor with Unicode support, gap buffer optimization, and minimap visualization!

```nim on:init
# ===================================================================
# State Management
# ===================================================================

# Create the editor with sample content
var sampleText = @[""]
add(sampleText, "# Welcome to TStorie Editor!")
add(sampleText, "")
add(sampleText, "This is a fully-featured text editor built with:")
add(sampleText, "- Gap buffer for efficient editing")
add(sampleText, "- Full Unicode support (emoji: 🎉 ✨ 🚀)")
add(sampleText, "- Line numbers and scrollbar")
add(sampleText, "- Minimap with braille characters")
add(sampleText, "- Mouse and keyboard navigation")
add(sampleText, "")
add(sampleText, "## Features")
add(sampleText, "")
add(sampleText, "- Arrow keys for navigation")
add(sampleText, "- Home/End for line start/end")
add(sampleText, "- Backspace and Delete")
add(sampleText, "- Enter for new lines")
add(sampleText, "- Tab for indentation")
add(sampleText, "- Click to position cursor")
add(sampleText, "- Scroll with Page Up/Down")
add(sampleText, "")
add(sampleText, "## Try it out!")
add(sampleText, "")
add(sampleText, "Start typing below this line:")
add(sampleText, "")

var editor = newEditor(sampleText)

# Editor UI state
var editorX = 5
var editorY = 4
var editorW = 70
var editorH = 22
var minimapX = 77
var minimapY = 4
var minimapW = 18
var minimapH = 22

# Status bar message
var statusMessage = "Ready - Arrow keys to navigate | Type to edit | Tab for indent"
var showHelp = 0
var showMinimap = 1

# Statistics
var keyPressCount = 0
var lastKeyCode = 0
```

```nim on:render
# ===================================================================
# Render
# ===================================================================
clear()

let w = getWidth()
let h = getHeight()

# Title
drawLabel(0, 5, 2, "TStorie Text Editor - Full Unicode Support", getStyle("info"))

# Draw the main editor
drawEditor(0, editorX, editorY, editorW, editorH, editor, 1)

# Draw minimap if enabled
if showMinimap:
  drawPanel(0, minimapX, minimapY, minimapW, minimapH, "Map", "single")
  drawMinimap(0, minimapX + 1, minimapY + 1, minimapW - 2, minimapH - 2, editor, editorH)

# Status bar
drawPanel(0, 5, h - 6, w - 10, 5, "Status", "single")

# Get cursor info
let cursor = editorGetCursor(editor)
let cursorLine = cursor["line"]
let cursorCol = cursor["col"]
let lineCount = editorLineCount(editor)
let isModified = editorIsModified(editor)

# Status line 1: Cursor position
let modStr = if isModified: " [MODIFIED]" else: ""
let posInfo = "Line " & str(cursorLine + 1) & ", Col " & str(cursorCol + 1) & " | Total: " & str(lineCount) & " lines" & modStr
drawLabel(0, 7, h - 5, posInfo, getStyle("info"))

# Status line 2: Current message
drawLabel(0, 7, h - 4, statusMessage, getStyle("default"))

# Status line 3: Key stats
let statsInfo = "Keys pressed: " & str(keyPressCount) & " | Last key: " & str(lastKeyCode)
drawLabel(0, 7, h - 3, statsInfo, getStyle("warning"))

# Help panel (toggle with F1)
if showHelp:
  let helpX = w div 2 - 25
  let helpY = h div 2 - 8
  drawPanel(0, helpX, helpY, 50, 16, "Keyboard Shortcuts", "double")
  
  drawLabel(0, helpX + 2, helpY + 2, "Navigation:", getStyle("info"))
  drawLabel(0, helpX + 4, helpY + 3, "Arrow Keys - Move cursor", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 4, "Home/End - Start/end of line", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 5, "Ctrl+Home/End - Start/end of file", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 6, "Page Up/Down - Scroll page", getStyle("default"))
  
  drawLabel(0, helpX + 2, helpY + 8, "Editing:", getStyle("info"))
  drawLabel(0, helpX + 4, helpY + 9, "Type - Insert text", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 10, "Backspace - Delete before cursor", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 11, "Delete - Delete at cursor", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 12, "Enter - New line", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 13, "Tab - Insert spaces", getStyle("default"))
  
  drawLabel(0, helpX + 14, helpY + 14, "Press F1 to close help", getStyle("warning"))
```

```nim on:input
# ===================================================================
# Input Handling
# ===================================================================

if event.type == "key":
  let keyCode = event.keyCode
  let key = event.key
  lastKeyCode = keyCode
  
  # F1 - Toggle help
  if keyCode == 112:
    showHelp = 1 - showHelp
    statusMessage = if showHelp != 0: "Help panel opened" else: "Help panel closed"
    return 1
  
  # F2 - Toggle minimap
  if keyCode == 113:
    showMinimap = 1 - showMinimap
    statusMessage = if showMinimap != 0: "Minimap enabled" else: "Minimap disabled"
    return 1
  
  # Handle editor key input
  let handled = editorHandleKey(editor, keyCode, key, event.mods)
  
  if handled:
    keyPressCount = keyPressCount + 1
    
    # Update status message based on action
    if keyCode == 13:
      statusMessage = "Inserted new line"
    elif keyCode == 8 or keyCode == 127:
      statusMessage = "Deleted character"
    elif keyCode == 9:
      statusMessage = "Inserted tab (spaces)"
    elif keyCode == 46:
      statusMessage = "Deleted forward"
    elif keyCode == 37 or keyCode == 38 or keyCode == 39 or keyCode == 40 or keyCode == 1000 or keyCode == 1001 or keyCode == 1002 or keyCode == 1003:
      let cursor = editorGetCursor(editor)
      statusMessage = "Moved to line " & str(cursor["line"] + 1) & ", col " & str(cursor["col"] + 1)
    elif keyCode == 36:
      statusMessage = "Moved to line start"
    elif keyCode == 35:
      statusMessage = "Moved to line end"
    elif keyCode == 33:
      statusMessage = "Scrolled up"
    elif keyCode == 34:
      statusMessage = "Scrolled down"
    
    return 1
  
  return 0

# ===================================================================
# Text Input Handling
# ===================================================================
elif event.type == "text":
  # Insert the typed character
  editorInsertText(editor, event.text)
  keyPressCount = keyPressCount + 1
  statusMessage = "Typed: '" & event.text & "'"
  return 1

# ===================================================================
# Mouse Input Handling
# ===================================================================
elif event.type == "mouse":
  let mx = event.x
  let my = event.y
  let action = event.action
  
  if action == "press":
    # Click in editor area
    if mx >= editorX and mx < editorX + editorW and my >= editorY and my < editorY + editorH:
      let handled = editorHandleClick(editor, mx, my, editorX, editorY, editorW, editorH, 1)
      if handled:
        let cursor = editorGetCursor(editor)
        statusMessage = "Clicked: moved to line " & str(cursor["line"] + 1) & ", col " & str(cursor["col"] + 1)
        return 1
    
    # Click in minimap area (future: jump to position)
    if showMinimap != 0 and mx >= minimapX and mx < minimapX + minimapW and my >= minimapY and my < minimapY + minimapH:
      statusMessage = "Clicked minimap (navigation coming soon!)"
      return 1
  
  # Mouse wheel scrolling
  if action == "wheel":
    if mx >= editorX and mx < editorX + editorW and my >= editorY and my < editorY + editorH:
      
      # Scroll up
      if event.wheelDelta > 0:
        # Move cursor up multiple times for smooth scrolling
        var i = 0
        while i < 3:
          editorMoveUp(editor)
          i = i + 1
        statusMessage = "Scrolled up with mouse wheel"
      else:
        # Scroll down
        var i = 0
        while i < 3:
          editorMoveDown(editor)
          i = i + 1
        statusMessage = "Scrolled down with mouse wheel"
      
      return 1
  
  return 0

return 0
```

## About This Demo

This demonstrates the complete text editor system built for TStorie:

### Architecture
- **Gap Buffer**: Efficient O(1) inserts at cursor position
- **Unicode-Safe**: All operations use Runes internally
- **Stateless Rendering**: Separate state from display logic
- **Composable**: Uses tui_helpers viewport and drawing primitives

### Features Showcased
1. **Full text editing** - Insert, delete, newlines, tabs
2. **Navigation** - Arrow keys, Home/End, Ctrl+Home/End
3. **Mouse support** - Click to position, wheel to scroll
4. **Line numbers** - Dynamic display with active line highlight
5. **Scrollbar** - Automatic when content exceeds viewport
6. **Minimap** - Braille-based code overview
7. **Status bar** - Real-time cursor position and stats
8. **Help system** - Built-in keyboard shortcuts (F1)

### Try These
- Type some text and watch it flow
- Use arrow keys to navigate around
- Click anywhere to jump cursor
- Add emoji: 🎨 🔥 ⚡ 💻 ✨
- Press F1 for help, F2 to toggle minimap
- Try Home/End for line navigation
- Use Ctrl+Home/End for buffer navigation

The editor is production-ready and can handle large files efficiently!
