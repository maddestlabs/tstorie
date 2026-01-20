---
title: "TStorie Editor"
minWidth: 120
minHeight: 35
theme: "neotopia"
---

# 📝 TStorie Editor

Self-hosted markdown editor with save, load, and share capabilities

```nim on:init
# ===================================================================
# State Management
# ===================================================================

# Load initial content from URL parameter if provided
var initialContent = @[""]
let contentParam = getParam("load")
var currentFileName = "untitled"
var isSaved = 1
var lastSaveTime = ""

if contentParam != "":
  # Content will be loaded from browser:key or decode:xxx by tstorie itself
  # We just initialize with current content
  add(initialContent, "# Loading...")
else:
  # Default template
  add(initialContent, "---")
  add(initialContent, "title: My TStorie Document")
  add(initialContent, "minWidth: 100")
  add(initialContent, "minHeight: 30")
  add(initialContent, "theme: neotopia")
  add(initialContent, "---")
  add(initialContent, "")
  add(initialContent, "# Welcome to TStorie!")
  add(initialContent, "")
  add(initialContent, "Start writing your interactive story here...")
  add(initialContent, "")

var editor = newEditor(initialContent)

# UI State
var statusMessage = "Ready - Ctrl+S to save | Ctrl+O to open | Ctrl+H for help"
var showHelp = 0
var showSaveDialog = 0
var showLoadDialog = 0
var showShareDialog = 0
var saveFileName = ""
var shareUrl = ""
var savedFiles: seq[string] = @[]
var loadSelection = 0

# Update saved files list
proc refreshFileList() =
  let jsonStr = localStorage_list()
  # Parse JSON manually (simple case)
  savedFiles = @[]
  # Simple JSON parsing for array of objects with key field
  var i = 0
  var currentKey = ""
  var inKey = 0
  while i < len(jsonStr):
    let ch = jsonStr[i]
    if ch == '"' and i > 0 and jsonStr[i-1] != '\\':
      if inKey:
        if currentKey == "key":
          # Next string is the filename
          i = i + 1
          while i < len(jsonStr) and jsonStr[i] != '"':
            i = i + 1
          i = i + 1
          var filename = ""
          while i < len(jsonStr) and jsonStr[i] != '"':
            filename = filename & $jsonStr[i]
            i = i + 1
          if filename != "":
            savedFiles = savedFiles & @[filename]
        currentKey = ""
        inKey = 0
      else:
        inKey = 1
        currentKey = ""
        i = i + 1
        while i < len(jsonStr) and jsonStr[i] != '"':
          currentKey = currentKey & $jsonStr[i]
          i = i + 1
    i = i + 1

refreshFileList()

# Statistics
var keyPressCount = 0
var lastKeyCode = 0
```

```nim on:render
# ===================================================================
# Render
# ===================================================================
clear()

let w = termWidth
let h = termHeight

# Calculate responsive editor dimensions
let editorX = 3
let editorY = 5
let editorW = w - 6
let editorH = h - 9

# Title bar with file name
let titleText = "📝 TStorie Editor - " & currentFileName & (if isSaved == 0: " *" else: "")
drawLabel(0, 3, 2, titleText, getStyle("info"))

# Quick help on title bar
let helpText = "Ctrl+S=Save | Ctrl+O=Open | Ctrl+E=Share | Ctrl+H=Help"
drawLabel(0, w - len(helpText) - 3, 2, helpText, getStyle("comment"))

# Border around editor
drawBox(0, editorX - 1, editorY - 1, editorW + 2, editorH + 2, getStyle("default"), "single")

# Draw the main editor
drawEditor(0, editorX, editorY, editorW, editorH, editor, 1)

# Status bar
let statusY = h - 3
drawBox(0, 2, statusY - 1, w - 4, 3, getStyle("default"), "single")

# Get cursor info
let cursor = editorGetCursor(editor)
let cursorLine = cursor["line"]
let cursorCol = cursor["col"]
let lineCount = editorLineCount(editor)
let isModified = editorIsModified(editor)

# Status line
let modStr = if isModified: " [MODIFIED]" else: ""
let posInfo = "Ln " & str(cursorLine + 1) & ", Col " & str(cursorCol + 1) & " | " & str(lineCount) & " lines" & modStr
drawLabel(0, 4, statusY, posInfo, getStyle("info"))
drawLabel(0, 4, statusY + 1, statusMessage, getStyle("default"))

# ===================================================================
# Dialogs
# ===================================================================

# Save Dialog
if showSaveDialog:
  let dialogW = 60
  let dialogH = 10
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(0, dialogX, dialogY, dialogW, dialogH, "💾 Save Document", "double")
  drawLabel(0, dialogX + 2, dialogY + 2, "Enter filename (without extension):", getStyle("info"))
  drawLabel(0, dialogX + 2, dialogY + 4, "> " & saveFileName & "_", getStyle("default"))
  drawLabel(0, dialogX + 2, dialogY + 6, "Press Enter to save, Esc to cancel", getStyle("comment"))
  drawLabel(0, dialogX + 2, dialogY + 7, "File will be saved to browser storage", getStyle("comment"))

# Load Dialog  
if showLoadDialog:
  let dialogW = 70
  let dialogH = min(20, h - 10)
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(0, dialogX, dialogY, dialogW, dialogH, "📂 Load Document", "double")
  drawLabel(0, dialogX + 2, dialogY + 2, "Available documents in browser storage:", getStyle("info"))
  
  if len(savedFiles) == 0:
    drawLabel(0, dialogX + 2, dialogY + 4, "(No saved documents found)", getStyle("comment"))
    drawLabel(0, dialogX + 2, dialogY + 6, "Save a document first with Ctrl+S", getStyle("comment"))
  else:
    var yPos = dialogY + 4
    var idx = 0
    while idx < len(savedFiles) and yPos < dialogY + dialogH - 3:
      let fileEntry = savedFiles[idx]
      let prefix = if idx == loadSelection: "> " else: "  "
      let style = if idx == loadSelection: getStyle("info") else: getStyle("default")
      drawLabel(0, dialogX + 4, yPos, prefix & str(idx + 1) & ". " & fileEntry, style)
      yPos = yPos + 1
      idx = idx + 1
  
  drawLabel(0, dialogX + 2, dialogY + dialogH - 2, "Arrow keys + Enter to load, Esc to cancel", getStyle("comment"))

# Share Dialog
if showShareDialog:
  let dialogW = min(80, w - 10)
  let dialogH = 14
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(0, dialogX, dialogY, dialogW, dialogH, "🔗 Share Document", "double")
  drawLabel(0, dialogX + 2, dialogY + 2, "Shareable URL generated:", getStyle("info"))
  
  if shareUrl != "":
    drawLabel(0, dialogX + 2, dialogY + 4, "Copy the URL below to share this document:", getStyle("comment"))
    # Show URL in multiple lines if needed
    let urlMaxLen = dialogW - 6
    var urlLine = shareUrl
    var urlY = dialogY + 5
    while len(urlLine) > 0 and urlY < dialogY + dialogH - 3:
      let chunk = if len(urlLine) > urlMaxLen: substr(urlLine, 0, urlMaxLen - 1) else: urlLine
      drawLabel(0, dialogX + 3, urlY, chunk, getStyle("default"))
      urlLine = if len(urlLine) > urlMaxLen: substr(urlLine, urlMaxLen, len(urlLine) - 1) else: ""
      urlY = urlY + 1
    
    drawLabel(0, dialogX + 2, dialogY + dialogH - 3, "✓ URL copied to clipboard!", getStyle("success"))
  else:
    drawLabel(0, dialogX + 2, dialogY + 4, "Generating shareable URL...", getStyle("comment"))
  
  drawLabel(0, dialogX + 2, dialogY + dialogH - 2, "Press Esc to close", getStyle("comment"))

# Help Panel
if showHelp:
  let helpW = 70
  let helpH = 22
  let helpX = (w - helpW) div 2
  let helpY = (h - helpH) div 2
  
  drawPanel(0, helpX, helpY, helpW, helpH, "⌨ Keyboard Shortcuts", "double")
  
  drawLabel(0, helpX + 2, helpY + 2, "File Operations:", getStyle("info"))
  drawLabel(0, helpX + 4, helpY + 3, "Ctrl+S - Save to browser storage", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 4, "Ctrl+O - Open from browser storage", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 5, "Ctrl+E - Share via compressed URL", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 6, "Ctrl+R - Run current document", getStyle("default"))
  
  drawLabel(0, helpX + 2, helpY + 8, "Navigation:", getStyle("info"))
  drawLabel(0, helpX + 4, helpY + 9, "Arrow Keys - Move cursor", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 10, "Home/End - Start/end of line", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 11, "Ctrl+Home/End - Start/end of file", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 12, "Page Up/Down - Scroll page", getStyle("default"))
  
  drawLabel(0, helpX + 2, helpY + 14, "Editing:", getStyle("info"))
  drawLabel(0, helpX + 4, helpY + 15, "Type - Insert text", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 16, "Backspace/Delete - Delete characters", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 17, "Enter - New line", getStyle("default"))
  drawLabel(0, helpX + 4, helpY + 18, "Tab - Insert spaces", getStyle("default"))
  
  drawLabel(0, helpX + 20, helpY + helpH - 2, "Press Ctrl+H or Esc to close", getStyle("warning"))
```

```nim on:input
# ===================================================================
# Input Handling
# ===================================================================

if event.type == "key":
  let keyCode = event.keyCode
  let key = event.key
  let ctrl = event.mods["ctrl"]
  lastKeyCode = keyCode
  
  # ===== Dialog Input Handling =====
  
  # Save dialog
  if showSaveDialog:
    if keyCode == 27:  # Esc
      showSaveDialog = 0
      saveFileName = ""
      statusMessage = "Save cancelled"
      return 1
    elif keyCode == 13:  # Enter
      if saveFileName != "":
        # Save to browser storage
        let content = editorGetText(editor)
        let success = localStorage_setItem(saveFileName, content)
        if success:
          currentFileName = saveFileName
          isSaved = 1
          editorClearModified(editor)
          statusMessage = "✓ Saved as '" & saveFileName & "' to browser storage"
          refreshFileList()
        else:
          statusMessage = "✗ Failed to save to browser storage"
        showSaveDialog = 0
        saveFileName = ""
        return 1
    elif keyCode == 8:  # Backspace
      if len(saveFileName) > 0:
        saveFileName = substr(saveFileName, 0, len(saveFileName) - 2)
      return 1
    else:
      # Add character to filename
      if len(key) == 1:
        let c = key[0]
        # Only allow alphanumeric, dash, underscore
        if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' or c == '_':
          saveFileName = saveFileName & key
      return 1
  
  # Load dialog
  if showLoadDialog:
    if keyCode == 27:  # Esc
      showLoadDialog = 0
      loadSelection = 0
      statusMessage = "Load cancelled"
      return 1
    elif keyCode == 38:  # Up arrow
      if loadSelection > 0:
        loadSelection = loadSelection - 1
      return 1
    elif keyCode == 40:  # Down arrow
      if loadSelection < len(savedFiles) - 1:
        loadSelection = loadSelection + 1
      return 1
    elif keyCode == 13:  # Enter
      if loadSelection >= 0 and loadSelection < len(savedFiles):
        let filename = savedFiles[loadSelection]
        statusMessage = "Loading '" & filename & "'..."
        showLoadDialog = 0
        loadSelection = 0
        # Load the content via URL navigation
        let loadUrl = "?content=browser:" & filename
        navigateTo(loadUrl)
        return 1
    return 1
  
  # Share dialog
  if showShareDialog:
    if keyCode == 27:  # Esc
      showShareDialog = 0
      shareUrl = ""
      statusMessage = "Share dialog closed"
      return 1
    return 1
  
  # Help dialog
  if showHelp:
    if (keyCode == 72 and ctrl) or keyCode == 27:  # Ctrl+H or Esc
      showHelp = 0
      statusMessage = "Help closed"
      return 1
    return 1
  
  # ===== Global Shortcuts =====
  
  if ctrl:
    # Ctrl+S - Save
    if keyCode == 83:
      showSaveDialog = 1
      saveFileName = if currentFileName == "untitled": "" else: currentFileName
      statusMessage = "Enter filename to save"
      return 1
    
    # Ctrl+O - Open
    elif keyCode == 79:
      refreshFileList()
      showLoadDialog = 1
      loadSelection = 0
      statusMessage = "Select file to load"
      return 1
    
    # Ctrl+H - Help
    elif keyCode == 72:
      showHelp = 1 - showHelp
      statusMessage = if showHelp != 0: "Help opened" else: "Help closed"
      return 1
    
    # Ctrl+E - Share
    elif keyCode == 69:
      showShareDialog = 1
      let content = editorGetText(editor)
      shareUrl = compressToUrl(content)
      let copied = copyToClipboard(shareUrl)
      if copied:
        statusMessage = "✓ Share URL copied to clipboard!"
      else:
        statusMessage = "Share URL generated"
      return 1
    
    # Ctrl+R - Run document (save and reload)
    elif keyCode == 82:
      statusMessage = "Saving and running..."
      let content = editorGetText(editor)
      let tempKey = "__temp_run__"
      let saved = localStorage_setItem(tempKey, content)
      if saved:
        navigateTo("?content=browser:__temp_run__")
      return 1
  
  # ===== Editor Input =====
  
  # Track if content modified
  let wasModified = editorIsModified(editor)
  let handled = editorHandleKey(editor, keyCode, key, event.mods)
  
  if handled:
    keyPressCount = keyPressCount + 1
    let nowModified = editorIsModified(editor)
    
    if not wasModified and nowModified:
      isSaved = 0
    
    # Update status message based on action
    if keyCode == 13:
      statusMessage = "New line inserted"
    elif keyCode == 8 or keyCode == 127:
      statusMessage = "Character deleted"
    elif keyCode == 9:
      statusMessage = "Tab inserted"
    elif keyCode == 46:
      statusMessage = "Character deleted forward"
    
    return 1
  
  return 0

# ===================================================================
# Text Input Handling
# ===================================================================
elif event.type == "text":
  if showSaveDialog or showLoadDialog or showShareDialog or showHelp:
    return 0
  
  let wasModified = editorIsModified(editor)
  editorInsertText(editor, event.text)
  
  if not wasModified:
    isSaved = 0
  
  keyPressCount = keyPressCount + 1
  statusMessage = "Ready"
  return 1

# ===================================================================
# Mouse Input Handling
# ===================================================================
elif event.type == "mouse":
  if showSaveDialog or showLoadDialog or showShareDialog or showHelp:
    return 0
  
  let mx = event.x
  let my = event.y
  let action = event.action
  
  # Recalculate editor dimensions
  let w = termWidth
  let h = termHeight
  let editorX = 3
  let editorY = 5
  let editorW = w - 6
  let editorH = h - 9
  
  if action == "press":
    if mx >= editorX and mx < editorX + editorW and my >= editorY and my < editorY + editorH:
      let minimapHandled = editorHandleMinimapClick(editor, mx, my, editorX, editorY, editorW, editorH, 1)
      if minimapHandled:
        statusMessage = "Minimap: jumped to position"
        return 1
      
      let handled = editorHandleClick(editor, mx, my, editorX, editorY, editorW, editorH, 1)
      if handled:
        let cursor = editorGetCursor(editor)
        statusMessage = "Cursor: line " & str(cursor["line"] + 1) & ", col " & str(cursor["col"] + 1)
        return 1
  
  if action == "wheel":
    if mx >= editorX and mx < editorX + editorW and my >= editorY and my < editorY + editorH:
      if event.wheelDelta > 0:
        var i = 0
        while i < 3:
          editorMoveUp(editor)
          i = i + 1
      else:
        var i = 0
        while i < 3:
          editorMoveDown(editor)
          i = i + 1
      return 1
  
  return 0

return 0
```

## About This Editor

This is a self-hosted TStorie markdown editor with full save/load/share capabilities!

### Features

**📁 File Management**
- **Save to Browser** (Ctrl+S) - Store documents in localStorage
- **Load from Browser** (Ctrl+O) - Browse and open saved documents
- **Share via URL** (Ctrl+E) - Generate compressed shareable URLs
- **Run Document** (Ctrl+R) - Execute your TStorie markdown live

**✏️ Full Text Editing**
- Gap buffer for efficient editing
- Full Unicode support (emoji: 🎉 ✨ 🚀)
- Line numbers and scrollbar
- Minimap visualization
- Mouse and keyboard navigation

**💾 Persistence Options**
- Browser localStorage for local drafts
- Compressed URLs for sharing
- GitHub Gist integration (via content param)

### Quick Start

1. **Create a story** - Start typing your TStorie markdown
2. **Save it** - Press Ctrl+S and give it a name
3. **Share it** - Press Ctrl+E to get a shareable URL
4. **Run it** - Press Ctrl+R to see it in action

### Keyboard Shortcuts

- **Ctrl+S** - Save to browser storage
- **Ctrl+O** - Open from browser storage
- **Ctrl+E** - Share via compressed URL
- **Ctrl+R** - Run document
- **Ctrl+H** - Show help

Try editing this document and running it with Ctrl+R!
