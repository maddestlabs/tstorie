## TUI Editor Widgets
##
## Extended widgets for tstoried editor built on lib/tui.nim foundation.
## Provides TextBox (multi-line editor) and ListView (file/gist browser).
##
## Note: This module must be included after tui.nim to access Widget base type.

import std/[strutils, sequtils, unicode, tables]
import storie_types

# Widget, WidgetState, Layer, Style, etc. are available from tui.nim include

# ================================================================
# TEXTBOX - MULTI-LINE TEXT EDITOR
# ================================================================

type
  TextBox* = ref object of Widget
    ## Multi-line text editing widget with cursor, selection, and line numbers
    lines*: seq[string]                     ## Text content (one string per line)
    cursor*: tuple[row, col: int]          ## Cursor position (0-indexed)
    scroll*: int                            ## Vertical scroll offset
    scrollX*: int                           ## Horizontal scroll offset
    selectionStart*: tuple[row, col: int]  ## Selection start (if hasSelection)
    hasSelection*: bool                     ## Whether text is selected
    modified*: bool                         ## Whether content has been modified
    
    # Visual settings
    showLineNumbers*: bool                  ## Show line number gutter
    lineNumberWidth*: int                   ## Width of line number gutter
    tabWidth*: int                          ## Width of tab character
    showCursor*: bool                       ## Show cursor (can blink)
    readOnly*: bool                         ## Disable editing
    
    # Style names for different elements
    lineNumberStyle*: string                ## Style for line numbers
    activeLineNumberStyle*: string          ## Style for current line number
    cursorStyle*: string                    ## Style for cursor
    selectionStyle*: string                 ## Style for selected text
    
    # Undo/redo (simplified - just store full snapshots for now)
    undoStack*: seq[seq[string]]
    redoStack*: seq[seq[string]]
    maxUndoLevels*: int

proc newTextBox*(id: string, x, y, w, h: int): TextBox =
  ## Create a new multi-line text editor widget
  result = TextBox()
  result.id = id
  result.x = x
  result.y = y
  result.width = w
  result.height = h
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = true
  result.tabIndex = 0
  result.normalStyle = "editor.background"
  result.focusedStyle = "editor.background"
  result.useOverride = false
  result.styleSheet = initTable[string, StyleConfig]()
  
  # Text content
  result.lines = @[""]
  result.cursor = (0, 0)
  result.scroll = 0
  result.scrollX = 0
  result.selectionStart = (0, 0)
  result.hasSelection = false
  result.modified = false
  
  # Visual settings
  result.showLineNumbers = true
  result.lineNumberWidth = 4
  result.tabWidth = 2
  result.showCursor = true
  result.readOnly = false
  
  # Style names
  result.lineNumberStyle = "editor.linenumber"
  result.activeLineNumberStyle = "editor.linenumber.active"
  result.cursorStyle = "editor.cursor"
  result.selectionStyle = "editor.selection"
  
  # Undo
  result.undoStack = @[]
  result.redoStack = @[]
  result.maxUndoLevels = 100

# ================================================================
# TEXT MANIPULATION
# ================================================================

proc getText*(tb: TextBox): string =
  ## Get all text as a single string with newlines
  return tb.lines.join("\n")

proc setText*(tb: TextBox, text: string) =
  ## Set text content (splits on newlines)
  tb.lines = text.split('\n')
  if tb.lines.len == 0:
    tb.lines = @[""]
  tb.cursor = (0, 0)
  tb.scroll = 0
  tb.scrollX = 0
  tb.hasSelection = false
  tb.modified = true

proc getCurrentLine*(tb: TextBox): string =
  ## Get the current line text
  if tb.cursor.row >= 0 and tb.cursor.row < tb.lines.len:
    return tb.lines[tb.cursor.row]
  return ""

proc insertChar*(tb: TextBox, ch: char) =
  ## Insert character at cursor position
  if tb.readOnly:
    return
  
  let row = tb.cursor.row
  let col = tb.cursor.col
  
  if row >= 0 and row < tb.lines.len:
    var line = tb.lines[row]
    if col >= 0 and col <= line.len:
      line.insert($ch, col)
      tb.lines[row] = line
      tb.cursor.col += 1
      tb.modified = true

proc insertText*(tb: TextBox, text: string) =
  ## Insert multi-line text at cursor
  if tb.readOnly or text.len == 0:
    return
  
  let textLines = text.split('\n')
  let row = tb.cursor.row
  let col = tb.cursor.col
  
  if textLines.len == 1:
    # Single line insertion
    var line = tb.lines[row]
    line.insert(text, col)
    tb.lines[row] = line
    tb.cursor.col += text.len
  else:
    # Multi-line insertion
    var currentLine = tb.lines[row]
    let beforeCursor = if col <= currentLine.len: currentLine[0 ..< col] else: currentLine
    let afterCursor = if col <= currentLine.len: currentLine[col .. ^1] else: ""
    
    # First line gets prepended to first inserted line
    tb.lines[row] = beforeCursor & textLines[0]
    
    # Insert middle lines
    for i in 1 ..< textLines.len - 1:
      tb.lines.insert(textLines[i], row + i)
    
    # Last line gets remainder of current line appended
    tb.lines.insert(textLines[^1] & afterCursor, row + textLines.len - 1)
    
    # Move cursor to end of inserted text
    tb.cursor.row = row + textLines.len - 1
    tb.cursor.col = textLines[^1].len
  
  tb.modified = true

proc deleteChar*(tb: TextBox) =
  ## Delete character at cursor (backspace behavior)
  if tb.readOnly:
    return
  
  let row = tb.cursor.row
  let col = tb.cursor.col
  
  if col > 0:
    # Delete character before cursor
    var line = tb.lines[row]
    if col <= line.len:
      line.delete(col - 1 .. col - 1)
      tb.lines[row] = line
      tb.cursor.col -= 1
      tb.modified = true
  elif row > 0:
    # Join with previous line
    let prevLine = tb.lines[row - 1]
    let currentLine = tb.lines[row]
    tb.lines[row - 1] = prevLine & currentLine
    tb.lines.delete(row)
    tb.cursor.row -= 1
    tb.cursor.col = prevLine.len
    tb.modified = true

proc deleteCharForward*(tb: TextBox) =
  ## Delete character after cursor (delete key behavior)
  if tb.readOnly:
    return
  
  let row = tb.cursor.row
  let col = tb.cursor.col
  let line = tb.lines[row]
  
  if col < line.len:
    # Delete character at cursor
    var newLine = line
    newLine.delete(col .. col)
    tb.lines[row] = newLine
    tb.modified = true
  elif row < tb.lines.len - 1:
    # Join with next line
    let nextLine = tb.lines[row + 1]
    tb.lines[row] = line & nextLine
    tb.lines.delete(row + 1)
    tb.modified = true

proc insertNewline*(tb: TextBox) =
  ## Insert newline at cursor (Enter key)
  if tb.readOnly:
    return
  
  let row = tb.cursor.row
  let col = tb.cursor.col
  let line = tb.lines[row]
  
  # Split line at cursor
  let beforeCursor = if col <= line.len: line[0 ..< col] else: line
  let afterCursor = if col <= line.len: line[col .. ^1] else: ""
  
  tb.lines[row] = beforeCursor
  tb.lines.insert(afterCursor, row + 1)
  tb.cursor.row += 1
  tb.cursor.col = 0
  tb.modified = true

# ================================================================
# CURSOR MOVEMENT
# ================================================================

proc moveCursor*(tb: TextBox, drow, dcol: int) =
  ## Move cursor by relative offset
  var newRow = tb.cursor.row + drow
  var newCol = tb.cursor.col + dcol
  
  # Clamp row
  newRow = max(0, min(newRow, tb.lines.len - 1))
  
  # Clamp column to line length
  let lineLen = tb.lines[newRow].len
  newCol = max(0, min(newCol, lineLen))
  
  tb.cursor = (newRow, newCol)

proc moveCursorToLineStart*(tb: TextBox) =
  ## Move cursor to start of current line (Home key)
  tb.cursor.col = 0

proc moveCursorToLineEnd*(tb: TextBox) =
  ## Move cursor to end of current line (End key)
  if tb.cursor.row >= 0 and tb.cursor.row < tb.lines.len:
    tb.cursor.col = tb.lines[tb.cursor.row].len

proc ensureCursorVisible*(tb: TextBox) =
  ## Adjust scroll to keep cursor visible
  let gutterWidth = if tb.showLineNumbers: tb.lineNumberWidth + 1 else: 0
  let visibleHeight = tb.height
  let visibleWidth = tb.width - gutterWidth
  
  # Vertical scrolling
  if tb.cursor.row < tb.scroll:
    tb.scroll = tb.cursor.row
  elif tb.cursor.row >= tb.scroll + visibleHeight:
    tb.scroll = tb.cursor.row - visibleHeight + 1
  
  # Horizontal scrolling
  if tb.cursor.col < tb.scrollX:
    tb.scrollX = tb.cursor.col
  elif tb.cursor.col >= tb.scrollX + visibleWidth:
    tb.scrollX = tb.cursor.col - visibleWidth + 1

# ================================================================
# RENDERING
# ================================================================

method render*(tb: TextBox, layer: Layer) =
  ## Render text editor to layer
  if not tb.visible:
    return
  
  let baseStyle = tb.resolveStyle()
  let gutterWidth = if tb.showLineNumbers: tb.lineNumberWidth + 1 else: 0
  let textStartX = tb.x + gutterWidth
  
  # Resolve styles
  let lineNumStyle = if tb.styleSheet.hasKey(tb.lineNumberStyle):
    toStyle(tb.styleSheet[tb.lineNumberStyle])
  else:
    baseStyle
  
  let activeLineNumStyle = if tb.styleSheet.hasKey(tb.activeLineNumberStyle):
    toStyle(tb.styleSheet[tb.activeLineNumberStyle])
  else:
    lineNumStyle
  
  let cursorStyleResolved = if tb.styleSheet.hasKey(tb.cursorStyle):
    toStyle(tb.styleSheet[tb.cursorStyle])
  else:
    Style(fg: baseStyle.bg, bg: baseStyle.fg, bold: false, italic: false, underline: false, dim: false)
  
  # Clear widget area
  for dy in 0 ..< tb.height:
    for dx in 0 ..< tb.width:
      layer.buffer.write(tb.x + dx, tb.y + dy, " ", baseStyle)
  
  # Render visible lines
  let visibleStart = tb.scroll
  let visibleEnd = min(tb.scroll + tb.height, tb.lines.len)
  
  for i in visibleStart ..< visibleEnd:
    let screenY = tb.y + (i - visibleStart)
    let lineNum = i + 1  # Display as 1-indexed
    
    # Render line number
    if tb.showLineNumbers:
      let numStr = align($lineNum, tb.lineNumberWidth)
      let numStyle = if i == tb.cursor.row: activeLineNumStyle else: lineNumStyle
      layer.buffer.writeText(tb.x, screenY, numStr, numStyle)
      layer.buffer.write(tb.x + tb.lineNumberWidth, screenY, "│", numStyle)
    
    # Render line text
    let line = tb.lines[i]
    let visibleText = if tb.scrollX < line.len:
      let endIdx = min(tb.scrollX + (tb.width - gutterWidth), line.len)
      line[tb.scrollX ..< endIdx]
    else:
      ""
    
    if visibleText.len > 0:
      layer.buffer.writeText(textStartX, screenY, visibleText, baseStyle)
  
  # Render cursor (if focused and show enabled)
  if tb.showCursor and tb.state == wsFocused:
    let cursorScreenY = tb.y + (tb.cursor.row - tb.scroll)
    let cursorScreenX = textStartX + (tb.cursor.col - tb.scrollX)
    
    if cursorScreenY >= tb.y and cursorScreenY < tb.y + tb.height and
       cursorScreenX >= textStartX and cursorScreenX < tb.x + tb.width:
      # Get character at cursor (or space)
      let cursorChar = if tb.cursor.row < tb.lines.len:
        let line = tb.lines[tb.cursor.row]
        if tb.cursor.col < line.len: $line[tb.cursor.col] else: " "
      else:
        " "
      layer.buffer.write(cursorScreenX, cursorScreenY, cursorChar, cursorStyleResolved)

# ================================================================
# INPUT HANDLING
# ================================================================

method handleInput*(tb: TextBox, event: InputEvent): bool =
  ## Handle keyboard input for text editing
  if not tb.enabled or tb.state != wsFocused:
    return false
  
  if event.kind == KeyEvent and event.keyAction == Press:
    # Navigation keys
    case event.keyCode
    of 263:  # Left arrow
      tb.moveCursor(0, -1)
      tb.ensureCursorVisible()
      return true
    of 262:  # Right arrow
      tb.moveCursor(0, 1)
      tb.ensureCursorVisible()
      return true
    of 265:  # Up arrow
      tb.moveCursor(-1, 0)
      tb.ensureCursorVisible()
      return true
    of 264:  # Down arrow
      tb.moveCursor(1, 0)
      tb.ensureCursorVisible()
      return true
    of 268:  # Home
      tb.moveCursorToLineStart()
      tb.ensureCursorVisible()
      return true
    of 269:  # End
      tb.moveCursorToLineEnd()
      tb.ensureCursorVisible()
      return true
    of 259:  # Backspace
      tb.deleteChar()
      tb.ensureCursorVisible()
      return true
    of 261:  # Delete
      tb.deleteCharForward()
      return true
    of 257:  # Enter
      tb.insertNewline()
      tb.ensureCursorVisible()
      return true
    else:
      discard
  elif event.kind == TextEvent:
    # Printable text
    for ch in event.text:
      tb.insertChar(ch)
    tb.ensureCursorVisible()
    return true
  
  return false

# ================================================================
# LISTVIEW - SCROLLABLE LIST
# ================================================================

type
  ListViewItem* = object
    ## An item in a list view
    text*: string
    data*: string  # User data (e.g., file path, gist ID)
    icon*: string  # Optional icon/prefix
  
  ListView* = ref object of Widget
    ## Scrollable list widget for file/gist browsing
    items*: seq[ListViewItem]
    selected*: int                  ## Currently selected item index
    scroll*: int                    ## Vertical scroll offset
    itemHeight*: int                ## Height of each item (usually 1)
    
    # Styles
    itemStyle*: string              ## Normal item style
    selectedStyle*: string          ## Selected item style
    
    # Callbacks
    onSelectChange*: proc(lv: ListView) {.nimcall.}

proc newListView*(id: string, x, y, w, h: int): ListView =
  ## Create a new scrollable list widget
  result = ListView()
  result.id = id
  result.x = x
  result.y = y
  result.width = w
  result.height = h
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = true
  result.tabIndex = 0
  result.normalStyle = "browser.item"
  result.focusedStyle = "browser.item"
  result.useOverride = false
  result.styleSheet = initTable[string, StyleConfig]()
  
  result.items = @[]
  result.selected = 0
  result.scroll = 0
  result.itemHeight = 1
  
  result.itemStyle = "browser.item"
  result.selectedStyle = "browser.item.selected"

proc addItem*(lv: ListView, text: string, data: string = "", icon: string = "") =
  ## Add an item to the list
  lv.items.add(ListViewItem(text: text, data: data, icon: icon))

proc clearItems*(lv: ListView) =
  ## Remove all items from the list
  lv.items = @[]
  lv.selected = 0
  lv.scroll = 0

proc getSelectedItem*(lv: ListView): ListViewItem =
  ## Get the currently selected item
  if lv.selected >= 0 and lv.selected < lv.items.len:
    return lv.items[lv.selected]
  return ListViewItem(text: "", data: "", icon: "")

proc selectNext*(lv: ListView) =
  ## Move selection down
  if lv.selected < lv.items.len - 1:
    lv.selected += 1
    
    # Adjust scroll if needed
    let visibleItems = lv.height div lv.itemHeight
    if lv.selected >= lv.scroll + visibleItems:
      lv.scroll = lv.selected - visibleItems + 1
    
    if not lv.onSelectChange.isNil:
      lv.onSelectChange(lv)

proc selectPrev*(lv: ListView) =
  ## Move selection up
  if lv.selected > 0:
    lv.selected -= 1
    
    # Adjust scroll if needed
    if lv.selected < lv.scroll:
      lv.scroll = lv.selected
    
    if not lv.onSelectChange.isNil:
      lv.onSelectChange(lv)

method render*(lv: ListView, layer: Layer) =
  ## Render list view to layer
  if not lv.visible:
    return
  
  let baseStyle = lv.resolveStyle()
  
  # Resolve styles
  let itemStyleResolved = if lv.styleSheet.hasKey(lv.itemStyle):
    toStyle(lv.styleSheet[lv.itemStyle])
  else:
    baseStyle
  
  let selectedStyleResolved = if lv.styleSheet.hasKey(lv.selectedStyle):
    toStyle(lv.styleSheet[lv.selectedStyle])
  else:
    Style(fg: baseStyle.bg, bg: baseStyle.fg, bold: true, italic: false, underline: false, dim: false)
  
  # Clear widget area
  for dy in 0 ..< lv.height:
    for dx in 0 ..< lv.width:
      layer.buffer.write(lv.x + dx, lv.y + dy, " ", baseStyle)
  
  # Render visible items
  let visibleItems = lv.height div lv.itemHeight
  let visibleStart = lv.scroll
  let visibleEnd = min(lv.scroll + visibleItems, lv.items.len)
  
  for i in visibleStart ..< visibleEnd:
    let screenY = lv.y + ((i - visibleStart) * lv.itemHeight)
    let item = lv.items[i]
    let itemIsSelected = (i == lv.selected)
    let style = if itemIsSelected: selectedStyleResolved else: itemStyleResolved
    
    # Build display text
    let displayText = if item.icon != "":
      item.icon & " " & item.text
    else:
      item.text
    
    # Truncate to fit width
    let maxLen = min(displayText.len, lv.width)
    let finalText = if maxLen < displayText.len:
      displayText[0 ..< maxLen]
    else:
      displayText & repeat(" ", lv.width - displayText.len)
    
    layer.buffer.writeText(lv.x, screenY, finalText, style)

method handleInput*(lv: ListView, event: InputEvent): bool =
  ## Handle keyboard/mouse input for list navigation
  if not lv.enabled:
    return false
  
  if event.kind == KeyEvent and event.keyAction == Press:
    case event.keyCode
    of 265:  # Up arrow
      lv.selectPrev()
      return true
    of 264:  # Down arrow
      lv.selectNext()
      return true
    of 257:  # Enter
      # Trigger click callback if set
      if not lv.onClick.isNil:
        lv.onClick(lv)
      return true
    else:
      discard
  
  return false
