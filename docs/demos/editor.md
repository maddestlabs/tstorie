---
title: "t|Storie Editor"
minWidth: 20
minHeight: 10
theme: "futurism"
editorX: 0
editorY: 2
---

# t|Storie Text Editor

A fully-featured text editor with Unicode support, gap buffer optimization, and minimap visualization!

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
  add(initialContent, "# Welcome to TStorie Editor!")
  add(initialContent, "")
  add(initialContent, "This is a fully-featured text editor built with:")
  add(initialContent, "- Gap buffer for efficient editing")
  add(initialContent, "- Full Unicode support (emoji: 🎉 ✨ 🚀)")
  add(initialContent, "- Line numbers and scrollbar")
  add(initialContent, "- Minimap with braille characters")
  add(initialContent, "- Mouse and keyboard navigation")
  add(initialContent, "- Save/Load from browser storage")
  add(initialContent, "- Share via compressed URL")
  add(initialContent, "- GitHub Gist integration")
  add(initialContent, "")
  add(initialContent, "## Quick Start")
  add(initialContent, "")
  add(initialContent, "- **Ctrl+S** - Save to browser")
  add(initialContent, "- **Ctrl+O** - Open from browser")
  add(initialContent, "- **Ctrl+E** - Share URL")
  add(initialContent, "- **Ctrl+G** - Load from Gist")
  add(initialContent, "- **F1** - Help")
  add(initialContent, "")
  add(initialContent, "Start typing below this line:")
  add(initialContent, "")

var editor = newEditor(initialContent)

# Focus system: 0=editor, 1=menu, 2=dialog
var focusedComponent = 0

# Menu state
var activeMenu = ""
var hoveredMenuItem = -1

# Dialog state
var showHelp = 0
var showSaveDialog = 0
var showLoadDialog = 0
var showShareDialog = 0
var showLoadGistDialog = 0
var showSaveGistDialog = 0

# Dialog data
var statusMessage = "Ready - Click File menu or use Ctrl+S/O/E shortcuts"
var saveFileName = ""
var shareUrl = ""
var gistIdInput = ""
var gistDescription = ""
var gistResultUrl = ""
var savedFiles: seq[string] = @[]
var loadSelection = 0

# Update saved files list
proc refreshFileList() =
  let jsonStr = localStorage_list()
  savedFiles = @[]
  var i = 0
  var currentKey = ""
  var inKey = 0
  while i < len(jsonStr):
    let ch = jsonStr[i]
    if ch == '"' and i > 0 and jsonStr[i-1] != '\\':
      if inKey:
        if currentKey == "key":
          i = i + 1
          while i < len(jsonStr) and jsonStr[i] != '"':
            i = i + 1
          i = i + 1
          var filename = ""
          while i < len(jsonStr) and jsonStr[i] != '"':
            filename = filename & $jsonStr[i]
            i = i + 1
          if filename != "" and filename != "__temp_run__":
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

let w = getWidth()
let h = getHeight()

# Calculate responsive editor dimensions
let editorW = w - 1  # Full width with margins
let editorH = h - 7   # Full height minus title, status bar, and margins

# Title bar with filename
let titlePrefix = "t|Storie - "
let titleText = titlePrefix & currentFileName & (if isSaved == 0: " *" else: "")
drawLabel(0, 0, 1, titleText, getStyle("info"))

# Draw the main editor on layer 0
drawEditor(0, editorX, editorY, editorW, editorH, editor, 1)

# Status bar (automatically positioned at bottom)
let statusY = h - 5
drawPanel(0, 0, statusY, w - 1, 5, "Status", "single")

# Get cursor info
let cursor = editorGetCursor(editor)
let cursorLine = cursor["line"]
let cursorCol = cursor["col"]
let lineCount = editorLineCount(editor)
let isModified = editorIsModified(editor)
let scroll = editorGetScroll(editor)
let scrollX = scroll["scrollX"]
let scrollY = scroll["scrollY"]

# Status line 1: Cursor position and scroll
let modStr = if isModified: " [MODIFIED]" else: ""
let scrollInfo = if scrollX > 0 or scrollY > 0: " | Scroll X:" & str(scrollX) & " Y:" & str(scrollY) else: ""
let posInfo = "Line " & str(cursorLine + 1) & ", Col " & str(cursorCol + 1) & " | Total: " & str(lineCount) & " lines" & modStr & scrollInfo
drawLabel(0, 7, statusY + 1, posInfo, getStyle("info"))

# Status line 2: Current message
drawLabel(0, 7, statusY + 2, statusMessage, getStyle("default"))

# Status line 3: Key stats
let statsInfo = "Keys pressed: " & str(keyPressCount) & " | Last key: " & str(lastKeyCode)
drawLabel(0, 7, statusY + 3, statsInfo, getStyle("warning"))

# ===================================================================
# Layer 1 - Menus and Dialogs (drawn on top of editor)
# ===================================================================
# Clear layer 1 with transparency so editor shows through
clear(1, true)

# Menu bar on layer 1
let menuY = 1
let menuStyle = getStyle("default")
let menuActiveStyle = getStyle("info")
let menuHoverStyle = getStyle("warning")
let fileMenuX = len(titleText) + 2
let editMenuX = fileMenuX + 8
let viewMenuX = editMenuX + 8
let helpMenuX = viewMenuX + 8

drawLabel(1, fileMenuX, menuY, "File", if activeMenu == "file": menuActiveStyle else: menuStyle)
drawLabel(1, editMenuX, menuY, "Edit", if activeMenu == "edit": menuActiveStyle else: menuStyle)
drawLabel(1, viewMenuX, menuY, "View", if activeMenu == "view": menuActiveStyle else: menuStyle)
drawLabel(1, helpMenuX, menuY, "Help", if activeMenu == "help": menuActiveStyle else: menuStyle)

# Menu dropdowns on layer 1
if activeMenu == "file":
  let menuW = 30
  let menuH = 10
  let menuDropX = fileMenuX
  let menuDropY = menuY + 1
  drawPanel(1, menuDropX, menuDropY, menuW, menuH, "", "single")
  
  # Menu items (track bounds for click detection)
  # Item 0: Save
  drawLabel(1, menuDropX + 2, menuDropY + 1, "Save (Ctrl+S)", if hoveredMenuItem == 0: menuHoverStyle else: getStyle("default"))
  # Item 1: Open
  drawLabel(1, menuDropX + 2, menuDropY + 2, "Open (Ctrl+O)", if hoveredMenuItem == 1: menuHoverStyle else: getStyle("default"))
  # Separator
  drawLabel(1, menuDropX + 2, menuDropY + 3, "───────────────────", getStyle("comment"))
  # Item 2: Share URL
  drawLabel(1, menuDropX + 2, menuDropY + 4, "Share URL (Ctrl+E)", if hoveredMenuItem == 2: menuHoverStyle else: getStyle("default"))
  # Separator
  drawLabel(1, menuDropX + 2, menuDropY + 5, "───────────────────", getStyle("comment"))
  # Item 3: Load Gist
  drawLabel(1, menuDropX + 2, menuDropY + 6, "Load Gist (Ctrl+G)", if hoveredMenuItem == 3: menuHoverStyle else: getStyle("default"))
  # Item 4: Save as Gist
  drawLabel(1, menuDropX + 2, menuDropY + 7, "Save as Gist", if hoveredMenuItem == 4: menuHoverStyle else: getStyle("default"))
  
elif activeMenu == "view":
  let menuW = 25
  let menuH = 4
  let menuDropX = viewMenuX
  let menuDropY = menuY + 1
  drawPanel(1, menuDropX, menuDropY, menuW, menuH, "", "single")
  # Item 0: Toggle Help
  drawLabel(1, menuDropX + 2, menuDropY + 1, "Toggle Help (F1)", if hoveredMenuItem == 0: menuHoverStyle else: getStyle("default"))
  
elif activeMenu == "help":
  let menuW = 25
  let menuH = 4
  let menuDropX = helpMenuX
  let menuDropY = menuY + 1
  drawPanel(1, menuDropX, menuDropY, menuW, menuH, "", "single")
  # Item 0: Shortcuts
  drawLabel(1, menuDropX + 2, menuDropY + 1, "Shortcuts (F1)", if hoveredMenuItem == 0: menuHoverStyle else: getStyle("default"))
let cursorLine = cursor["line"]
let cursorCol = cursor["col"]
let lineCount = editorLineCount(editor)
let isModified = editorIsModified(editor)
let scroll = editorGetScroll(editor)
let scrollX = scroll["scrollX"]
let scrollY = scroll["scrollY"]

# Status line 1: Cursor position and scroll
let modStr = if isModified: " [MODIFIED]" else: ""
let scrollInfo = if scrollX > 0 or scrollY > 0: " | Scroll X:" & str(scrollX) & " Y:" & str(scrollY) else: ""
let posInfo = "Line " & str(cursorLine + 1) & ", Col " & str(cursorCol + 1) & " | Total: " & str(lineCount) & " lines" & modStr & scrollInfo
drawLabel(0, 7, statusY + 1, posInfo, getStyle("info"))

# Status line 2: Current message
drawLabel(0, 7, statusY + 2, statusMessage, getStyle("default"))

# Status line 3: Key stats
let statsInfo = "Keys pressed: " & str(keyPressCount) & " | Last key: " & str(lastKeyCode)
drawLabel(0, 7, statusY + 3, statsInfo, getStyle("warning"))

# ===================================================================
# Dialogs on layer 1 (on top of everything)
# ===================================================================

# Save Dialog
if showSaveDialog:
  let dialogW = 60
  let dialogH = 10
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(1, dialogX, dialogY, dialogW, dialogH, "💾 Save to Browser", "double")
  drawLabel(1, dialogX + 2, dialogY + 2, "Enter filename (without extension):", getStyle("info"))
  drawLabel(1, dialogX + 2, dialogY + 4, " > " & saveFileName & "_", getStyle("default"))
  drawLabel(1, dialogX + 2, dialogY + 6, "Press Enter to save, Esc to cancel", getStyle("comment"))
  drawLabel(1, dialogX + 2, dialogY + 7, "Saved to localStorage in your browser", getStyle("comment"))

# Load Dialog  
if showLoadDialog:
  let dialogW = 70
  let dialogH = min(20, h - 10)
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(1, dialogX, dialogY, dialogW, dialogH, "📂 Load from Browser", "double")
  drawLabel(1, dialogX + 2, dialogY + 2, "Saved documents in localStorage:", getStyle("info"))
  
  if len(savedFiles) == 0:
    drawLabel(1, dialogX + 2, dialogY + 4, "(No saved documents found)", getStyle("comment"))
    drawLabel(1, dialogX + 2, dialogY + 6, "Save a document first with Ctrl+S", getStyle("comment"))
  else:
    var yPos = dialogY + 4
    var idx = 0
    while idx < len(savedFiles) and yPos < dialogY + dialogH - 3:
      let fileEntry = savedFiles[idx]
      let prefix = if idx == loadSelection: "> " else: "  "
      let style = if idx == loadSelection: getStyle("info") else: getStyle("default")
      drawLabel(1, dialogX + 4, yPos, prefix & str(idx + 1) & ". " & fileEntry, style)
      yPos = yPos + 1
      idx = idx + 1
  
  drawLabel(1, dialogX + 2, dialogY + dialogH - 2, "Arrow keys + Enter to load, Esc to cancel", getStyle("comment"))

# Share Dialog
if showShareDialog:
  let dialogW = min(80, w - 10)
  let dialogH = 14
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(1, dialogX, dialogY, dialogW, dialogH, "🔗 Share via URL", "double")
  drawLabel(1, dialogX + 2, dialogY + 2, "Shareable URL generated:", getStyle("info"))
  
  if shareUrl != "":
    drawLabel(1, dialogX + 2, dialogY + 4, "Copy this URL to share:", getStyle("comment"))
    let urlMaxLen = dialogW - 6
    var urlLine = shareUrl
    var urlY = dialogY + 5
    while len(urlLine) > 0 and urlY < dialogY + dialogH - 3:
      let chunk = if len(urlLine) > urlMaxLen: substr(urlLine, 0, urlMaxLen - 1) else: urlLine
      drawLabel(1, dialogX + 3, urlY, chunk, getStyle("default"))
      urlLine = if len(urlLine) > urlMaxLen: substr(urlLine, urlMaxLen, len(urlLine) - 1) else: ""
      urlY = urlY + 1
    
    drawLabel(1, dialogX + 2, dialogY + dialogH - 3, "✓ URL copied to clipboard!", getStyle("success"))
  else:
    drawLabel(1, dialogX + 2, dialogY + 4, "Generating...", getStyle("comment"))
  
  drawLabel(1, dialogX + 2, dialogY + dialogH - 2, "Press Esc to close", getStyle("comment"))

# Load from Gist Dialog
if showLoadGistDialog:
  let dialogW = 70
  let dialogH = 12
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(1, dialogX, dialogY, dialogW, dialogH, "📥 Load from GitHub Gist", "double")
  drawLabel(1, dialogX + 2, dialogY + 2, "Enter Gist ID or URL:", getStyle("info"))
  drawLabel(1, dialogX + 2, dialogY + 4, " > " & gistIdInput & "_", getStyle("default"))
  drawLabel(1, dialogX + 2, dialogY + 6, "Examples:", getStyle("comment"))
  drawLabel(1, dialogX + 4, dialogY + 7, "abc123def456", getStyle("comment"))
  drawLabel(1, dialogX + 4, dialogY + 8, "https://gist.github.com/user/abc123def456", getStyle("comment"))
  drawLabel(1, dialogX + 2, dialogY + 10, "Press Enter to load, Esc to cancel", getStyle("comment"))

# Save to Gist Dialog
if showSaveGistDialog:
  let dialogW = 70
  let dialogH = 14
  let dialogX = (w - dialogW) div 2
  let dialogY = (h - dialogH) div 2
  
  drawPanel(1, dialogX, dialogY, dialogW, dialogH, "📤 Save as GitHub Gist", "double")
  
  if gistResultUrl == "":
    drawLabel(1, dialogX + 2, dialogY + 2, "Description (optional):", getStyle("info"))
    drawLabel(1, dialogX + 2, dialogY + 4, " > " & gistDescription & "_", getStyle("default"))
    drawLabel(1, dialogX + 2, dialogY + 6, "Filename: " & currentFileName & ".md", getStyle("comment"))
    drawLabel(1, dialogX + 2, dialogY + 8, "This will create a public gist", getStyle("comment"))
    drawLabel(1, dialogX + 2, dialogY + 9, "(No API key required)", getStyle("comment"))
    drawLabel(1, dialogX + 2, dialogY + 11, "Press Enter to create, Esc to cancel", getStyle("comment"))
  else:
    drawLabel(1, dialogX + 2, dialogY + 2, "✓ Gist created successfully!", getStyle("success"))
    drawLabel(1, dialogX + 2, dialogY + 4, "URL:", getStyle("info"))
    drawLabel(1, dialogX + 4, dialogY + 5, gistResultUrl, getStyle("default"))
    drawLabel(1, dialogX + 2, dialogY + 7, "Press Esc to close", getStyle("comment"))

# Help panel (toggle with F1) on layer 1
if showHelp:
  let helpX = w div 2 - 35
  let helpY = h div 2 - 12
  drawPanel(1, helpX, helpY, 70, 24, "⌨ Keyboard Shortcuts", "double")
  
  drawLabel(1, helpX + 2, helpY + 2, "File Operations:", getStyle("info"))
  drawLabel(1, helpX + 4, helpY + 3, "Ctrl+S - Save to browser storage", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 4, "Ctrl+O - Open from browser storage", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 5, "Ctrl+E - Share via compressed URL", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 6, "Ctrl+G - Load from GitHub Gist", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 7, "Ctrl+Shift+S - Save as GitHub Gist", getStyle("default"))
  
  drawLabel(1, helpX + 2, helpY + 9, "Navigation:", getStyle("info"))
  drawLabel(1, helpX + 4, helpY + 10, "Arrow Keys - Move cursor", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 11, "Home/End - Start/end of line", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 12, "Ctrl+Home/End - Start/end of file", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 13, "Page Up/Down - Scroll page", getStyle("default"))
  
  drawLabel(1, helpX + 2, helpY + 15, "Editing:", getStyle("info"))
  drawLabel(1, helpX + 4, helpY + 16, "Type - Insert text", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 17, "Backspace - Delete before cursor", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 18, "Delete - Delete at cursor", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 19, "Enter - New line", getStyle("default"))
  drawLabel(1, helpX + 4, helpY + 20, "Tab - Insert spaces", getStyle("default"))
  
  drawLabel(1, helpX + 20, helpY + 22, "Press F1 or Esc to close help", getStyle("warning"))
```

```nim on:input
# ===================================================================
# Input Handling
# ===================================================================

if event.type == "key":
  let keyCode = event.keyCode
  let key = event.key
  let ctrl = if contains(event.mods, "ctrl"): 1 else: 0
  let shift = if contains(event.mods, "shift"): 1 else: 0
  lastKeyCode = keyCode
  
  # ===== Dialog Input Handling (dialogs have priority) =====
  
  # Save dialog
  if showSaveDialog:
    if keyCode == 27:  # Esc
      showSaveDialog = 0
      saveFileName = ""
      focusedComponent = 0
      statusMessage = "Save cancelled"
      return 1
    elif keyCode == 13:  # Enter
      if saveFileName != "":
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
    return 1
  
  # Load dialog
  if showLoadDialog:
    if keyCode == 27:  # Esc
      showLoadDialog = 0
      loadSelection = 0
      focusedComponent = 0
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
        let loadUrl = "?load=browser:" & filename
        navigateTo(loadUrl)
        return 1
    return 1
  
  # Share dialog
  if showShareDialog:
    if keyCode == 27:  # Esc
      showShareDialog = 0
      shareUrl = ""
      focusedComponent = 0
      statusMessage = "Share dialog closed"
      return 1
    return 1
  
  # Load from Gist dialog
  if showLoadGistDialog:
    if keyCode == 27:  # Esc
      showLoadGistDialog = 0
      gistIdInput = ""
      focusedComponent = 0
      statusMessage = "Load from Gist cancelled"
      return 1
    elif keyCode == 13:  # Enter
      if gistIdInput != "":
        # Extract gist ID from URL if needed
        var gistId = gistIdInput
        # Check if it's a URL by looking for "gist.github.com"
        var isUrl = 0
        var checkPos = 0
        let pattern = "gist.github.com"
        while checkPos <= len(gistId) - len(pattern):
          var matches = 1
          var j = 0
          while j < len(pattern):
            if gistId[checkPos + j] != pattern[j]:
              matches = 0
              break
            j = j + 1
          if matches:
            isUrl = 1
            break
          checkPos = checkPos + 1
        
        if isUrl:
          # Extract ID from URL (last part after /)
          var parts: seq[string] = @[]
          var current = ""
          var i = 0
          while i < len(gistId):
            if gistId[i] == '/':
              if current != "":
                parts = parts & @[current]
              current = ""
            else:
              current = current & $gistId[i]
            i = i + 1
          if current != "":
            parts = parts & @[current]
          if len(parts) > 0:
            gistId = parts[len(parts) - 1]
        
        statusMessage = "Loading gist " & gistId & "..."
        showLoadGistDialog = 0
        gistIdInput = ""
        let loadUrl = "?load=gist:" & gistId
        navigateTo(loadUrl)
        return 1
    elif keyCode == 8:  # Backspace
      if len(gistIdInput) > 0:
        gistIdInput = substr(gistIdInput, 0, len(gistIdInput) - 2)
      return 1
    return 1
  
  # Save to Gist dialog
  if showSaveGistDialog:
    if keyCode == 27:  # Esc
      showSaveGistDialog = 0
      gistDescription = ""
      gistResultUrl = ""
      focusedComponent = 0
      statusMessage = "Save to Gist cancelled"
      return 1
    elif keyCode == 13 and gistResultUrl == "":  # Enter (only if not showing result)
      let content = editorGetText(editor)
      let filename = currentFileName & ".md"
      let desc = if gistDescription == "": "TStorie document: " & currentFileName else: gistDescription
      
      # Create gist using gist API
      let result = gist_create(desc, filename, content)
      if result != "":
        gistResultUrl = result
        statusMessage = "✓ Gist created successfully!"
        let copied = copyToClipboard(gistResultUrl)
      else:
        statusMessage = "✗ Failed to create gist"
        showSaveGistDialog = 0
        gistDescription = ""
      return 1
    elif keyCode == 8 and gistResultUrl == "":  # Backspace (only for description input)
      if len(gistDescription) > 0:
        gistDescription = substr(gistDescription, 0, len(gistDescription) - 2)
      return 1
    return 1
  
  # Help dialog
  if showHelp:
    if keyCode == 112 or keyCode == 27:  # F1 or Esc
      showHelp = 0
      focusedComponent = 0
      statusMessage = "Help closed"
      return 1
    return 1
  
  # Menu navigation
  if activeMenu != "":
    if keyCode == 27:  # Esc
      activeMenu = ""
      hoveredMenuItem = -1
      focusedComponent = 0
      statusMessage = "Menu closed"
      return 1
    elif keyCode == 1000:  # Up arrow
      if hoveredMenuItem > 0:
        hoveredMenuItem = hoveredMenuItem - 1
        # Skip separators
        if activeMenu == "file" and (hoveredMenuItem == 3 or hoveredMenuItem == 5):
          hoveredMenuItem = hoveredMenuItem - 1
      return 1
    elif keyCode == 1001:  # Down arrow
      var maxItem = 0
      if activeMenu == "file":
        maxItem = 4
      elif activeMenu == "view":
        maxItem = 0
      else:
        maxItem = 0
      if hoveredMenuItem < maxItem:
        hoveredMenuItem = hoveredMenuItem + 1
        # Skip separators
        if activeMenu == "file" and (hoveredMenuItem == 3 or hoveredMenuItem == 5):
          hoveredMenuItem = hoveredMenuItem + 1
      return 1
    elif keyCode == 13:  # Enter - activate menu item
      if hoveredMenuItem >= 0:
        # Execute menu action
        if activeMenu == "file":
          if hoveredMenuItem == 0:  # Save
            showSaveDialog = 1
            focusedComponent = 2
            saveFileName = if currentFileName == "untitled": "" else: currentFileName
            statusMessage = "Enter filename to save"
          elif hoveredMenuItem == 1:  # Open
            refreshFileList()
            showLoadDialog = 1
            focusedComponent = 2
            loadSelection = 0
            statusMessage = "Select file to load"
          elif hoveredMenuItem == 2:  # Share
            showShareDialog = 1
            focusedComponent = 2
            let content = editorGetText(editor)
            shareUrl = compressToUrl(content)
            let copied = copyToClipboard(shareUrl)
            if copied:
              statusMessage = "✓ Share URL copied to clipboard!"
            else:
              statusMessage = "Share URL generated"
          elif hoveredMenuItem == 3:  # Load Gist
            showLoadGistDialog = 1
            focusedComponent = 2
            gistIdInput = ""
            statusMessage = "Enter Gist ID or URL"
          elif hoveredMenuItem == 4:  # Save as Gist
            showSaveGistDialog = 1
            focusedComponent = 2
            gistDescription = ""
            gistResultUrl = ""
            statusMessage = "Enter description for Gist"
        elif activeMenu == "view":
          if hoveredMenuItem == 0:  # Toggle Help
            showHelp = 1 - showHelp
            focusedComponent = if showHelp: 2 else: 0
            statusMessage = if showHelp != 0: "Help opened" else: "Help closed"
        elif activeMenu == "help":
          if hoveredMenuItem == 0:  # Shortcuts
            showHelp = 1
            focusedComponent = 2
            statusMessage = "Help opened"
        
        activeMenu = ""
        hoveredMenuItem = -1
        return 1
    return 1
  
  # ===== Global Shortcuts (only if no menu/dialog active) =====
  
  if focusedComponent == 0:
    if ctrl:
      # Ctrl+S - Save
      if keyCode == 83 and not shift:
        showSaveDialog = 1
        focusedComponent = 2
        saveFileName = if currentFileName == "untitled": "" else: currentFileName
        statusMessage = "Enter filename to save"
        return 1
      
      # Ctrl+Shift+S - Save to Gist
      elif keyCode == 83 and shift:
        showSaveGistDialog = 1
        focusedComponent = 2
        gistDescription = ""
        gistResultUrl = ""
        statusMessage = "Enter description for Gist"
        return 1
      
      # Ctrl+O - Open
      elif keyCode == 79:
        refreshFileList()
        showLoadDialog = 1
        focusedComponent = 2
        loadSelection = 0
        statusMessage = "Select file to load"
        return 1
      
      # Ctrl+E - Share
      elif keyCode == 69:
        showShareDialog = 1
        focusedComponent = 2
        let content = editorGetText(editor)
        shareUrl = compressToUrl(content)
        let copied = copyToClipboard(shareUrl)
        if copied:
          statusMessage = "✓ Share URL copied to clipboard!"
        else:
          statusMessage = "Share URL generated"
        return 1
      
      # Ctrl+G - Load from Gist
      elif keyCode == 71:
        showLoadGistDialog = 1
        focusedComponent = 2
        gistIdInput = ""
        statusMessage = "Enter Gist ID or URL"
        return 1
    
    # F1 - Toggle help
    if keyCode == 112:
      showHelp = 1 - showHelp
      focusedComponent = if showHelp: 2 else: 0
      statusMessage = if showHelp != 0: "Help panel opened" else: "Help panel closed"
      return 1
  
  # ===== Editor Input (only when editor has focus) =====
  
  # Editor only responds when it has focus
  if focusedComponent != 0:
    return 0
  
  # Track if content modified
  let wasModified = editorIsModified(editor)
  let handled = editorHandleKey(editor, keyCode, key, ctrl, shift, 0, 0)
  
  if handled:
    keyPressCount = keyPressCount + 1
    let nowModified = editorIsModified(editor)
    
    if not wasModified and nowModified:
      isSaved = 0
    
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
  # Handle text input for dialogs
  if showSaveDialog:
    # Add typed character to filename (only alphanumeric, dash, underscore)
    if len(event.text) == 1:
      let c = event.text[0]
      if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' or c == '_':
        saveFileName = saveFileName & event.text
    return 1
  
  if showLoadGistDialog:
    # Add typed character to gist ID
    gistIdInput = gistIdInput & event.text
    return 1
  
  if showSaveGistDialog and gistResultUrl == "":
    # Add typed character to description
    gistDescription = gistDescription & event.text
    return 1
  
  # Only process if editor has focus
  if focusedComponent != 0:
    return 0
  
  if showLoadDialog or showShareDialog or showHelp or activeMenu != "":
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
  if showSaveDialog or showLoadDialog or showShareDialog or showLoadGistDialog or showSaveGistDialog or showHelp:
    return 0
  
  let mx = event.x
  let my = event.y
  let action = event.action
  
  # Recalculate editor dimensions
  let w = getWidth()
  let h = getHeight()
  let editorW = w - 1
  let editorH = h - 7
  
  # Handle menu bar clicks
  if action == "press" and my == 1:
    let titlePrefix = "t|Storie - "
    let titleText = titlePrefix & currentFileName & (if isSaved == 0: " *" else: "")
    let fileMenuX = len(titleText) + 2
    let editMenuX = fileMenuX + 8
    let viewMenuX = editMenuX + 8
    let helpMenuX = viewMenuX + 8
    
    if mx >= fileMenuX and mx < fileMenuX + 4:
      activeMenu = if activeMenu == "file": "" else: "file"
      focusedComponent = if activeMenu == "file": 1 else: 0
      hoveredMenuItem = if activeMenu == "file": 0 else: -1
      statusMessage = if activeMenu == "file": "File menu opened - Use arrows + Enter or click items" else: "Menu closed"
      return 1
    elif mx >= editMenuX and mx < editMenuX + 4:
      activeMenu = if activeMenu == "edit": "" else: "edit"
      focusedComponent = if activeMenu == "edit": 1 else: 0
      hoveredMenuItem = -1
      statusMessage = if activeMenu == "edit": "Edit menu opened" else: "Menu closed"
      return 1
    elif mx >= viewMenuX and mx < viewMenuX + 4:
      activeMenu = if activeMenu == "view": "" else: "view"
      focusedComponent = if activeMenu == "view": 1 else: 0
      hoveredMenuItem = if activeMenu == "view": 0 else: -1
      statusMessage = if activeMenu == "view": "View menu opened" else: "Menu closed"
      return 1
    elif mx >= helpMenuX and mx < helpMenuX + 4:
      activeMenu = if activeMenu == "help": "" else: "help"
      focusedComponent = if activeMenu == "help": 1 else: 0
      hoveredMenuItem = if activeMenu == "help": 0 else: -1
      statusMessage = if activeMenu == "help": "Help menu opened" else: "Menu closed"
      return 1
  
  # Handle menu dropdown clicks
  if action == "press" and activeMenu != "":
    let titlePrefix = "t|Storie - "
    let titleText = titlePrefix & currentFileName & (if isSaved == 0: " *" else: "")
    let fileMenuX = len(titleText) + 2
    let viewMenuX = fileMenuX + 24
    let helpMenuX = viewMenuX + 8
    
    if activeMenu == "file":
      let menuDropX = fileMenuX
      let menuDropY = 2
      let menuW = 30
      let menuH = 10
      
      # Check if click is inside menu
      if mx >= menuDropX and mx < menuDropX + menuW and my >= menuDropY and my < menuDropY + menuH:
        let itemY = my - menuDropY - 1
        if itemY == 0:  # Save
          showSaveDialog = 1
          focusedComponent = 2
          saveFileName = if currentFileName == "untitled": "" else: currentFileName
          statusMessage = "Enter filename to save"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
        elif itemY == 1:  # Open
          refreshFileList()
          showLoadDialog = 1
          focusedComponent = 2
          loadSelection = 0
          statusMessage = "Select file to load"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
        elif itemY == 3:  # Share URL
          showShareDialog = 1
          focusedComponent = 2
          let content = editorGetText(editor)
          shareUrl = compressToUrl(content)
          let copied = copyToClipboard(shareUrl)
          if copied:
            statusMessage = "✓ Share URL copied to clipboard!"
          else:
            statusMessage = "Share URL generated"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
        elif itemY == 5:  # Load Gist
          showLoadGistDialog = 1
          focusedComponent = 2
          gistIdInput = ""
          statusMessage = "Enter Gist ID or URL"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
        elif itemY == 6:  # Save as Gist
          showSaveGistDialog = 1
          focusedComponent = 2
          gistDescription = ""
          gistResultUrl = ""
          statusMessage = "Enter description for Gist"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
      else:
        # Clicked outside menu - close it
        activeMenu = ""
        hoveredMenuItem = -1
        focusedComponent = 0
        statusMessage = "Menu closed"
    
    elif activeMenu == "view":
      let menuDropX = viewMenuX
      let menuDropY = 2
      let menuW = 25
      let menuH = 4
      
      if mx >= menuDropX and mx < menuDropX + menuW and my >= menuDropY and my < menuDropY + menuH:
        let itemY = my - menuDropY - 1
        if itemY == 0:  # Toggle Help
          showHelp = 1 - showHelp
          focusedComponent = if showHelp: 2 else: 0
          statusMessage = if showHelp != 0: "Help opened" else: "Help closed"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
      else:
        # Clicked outside
        activeMenu = ""
        hoveredMenuItem = -1
        focusedComponent = 0
    
    elif activeMenu == "help":
      let menuDropX = helpMenuX
      let menuDropY = 2
      let menuW = 25
      let menuH = 4
      
      if mx >= menuDropX and mx < menuDropX + menuW and my >= menuDropY and my < menuDropY + menuH:
        let itemY = my - menuDropY - 1
        if itemY == 0:  # Shortcuts
          showHelp = 1
          focusedComponent = 2
          statusMessage = "Help opened"
          activeMenu = ""
          hoveredMenuItem = -1
          return 1
      else:
        # Clicked outside
        activeMenu = ""
        hoveredMenuItem = -1
        focusedComponent = 0
  
  if action == "press":
    # Click in editor area - give it focus
    if mx >= editorX and mx < editorX + editorW and my >= editorY and my < editorY + editorH:
      focusedComponent = 0
      activeMenu = ""
      hoveredMenuItem = -1
      # Try minimap click first
      let minimapHandled = editorHandleMinimapClick(editor, mx, my, editorX, editorY, editorW, editorH, 1)
      if minimapHandled:
        statusMessage = "Minimap click: jumped to position"
        return 1
      
      # Then try regular editor click
      let handled = editorHandleClick(editor, mx, my, editorX, editorY, editorW, editorH, 1)
      if handled:
        let cursor = editorGetCursor(editor)
        statusMessage = "Clicked: moved to line " & str(cursor["line"] + 1) & ", col " & str(cursor["col"] + 1)
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

## About This Editor

A complete TStorie editor with file management, sharing, and collaboration features!

### Architecture
- **Gap Buffer**: Efficient O(1) inserts at cursor position
- **Unicode-Safe**: All operations use Runes internally
- **Stateless Rendering**: Separate state from display logic
- **Modal Dialogs**: Clean UX for file operations
- **Menu System**: Traditional menu bar with dropdowns

### Features

**📝 Text Editing**
- Full text editing with gap buffer
- Unicode support (emoji: 🎉 ✨ 🚀)
- Line numbers and scrollbar
- Minimap visualization
- Mouse and keyboard navigation

**💾 File Management**
- **Save to Browser** (Ctrl+S) - Store in localStorage
- **Load from Browser** (Ctrl+O) - Browse saved files
- **Share via URL** (Ctrl+E) - Generate compressed URLs
- **Load from Gist** (Ctrl+G) - Import from GitHub
- **Save as Gist** (Ctrl+Shift+S) - Export to GitHub

**🔗 Collaboration**
- Share documents via compressed URL
- Load from public GitHub Gists
- Create new Gists (no API key needed)
- URL-based content loading

### Quick Start

1. **Type** your content
2. **Save** with Ctrl+S to browser storage
3. **Share** with Ctrl+E to get a URL
4. **Load** with Ctrl+G from a Gist ID

### Keyboard Shortcuts

- **Ctrl+S** - Save to browser
- **Ctrl+O** - Open from browser
- **Ctrl+E** - Share URL
- **Ctrl+G** - Load Gist
- **Ctrl+Shift+S** - Save as Gist
- **F1** - Show help

Try it now - edit, save, and share your content!
