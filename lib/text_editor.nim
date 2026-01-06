## Text Editor Module - Robust text editing with Unicode support
##
## Design principles:
## - Proper Unicode support using Runes
## - Efficient 2D text storage (gap buffer per line)
## - Separate state from rendering (stateless rendering)
## - Integrates with viewport for scrolling
## - Foundation for minimap with braille
## - Full cursor navigation and text operations
##
## Architecture:
## - EditorBuffer: Text storage and manipulation
## - EditorState: Cursor, selection, scroll position
## - Rendering: Uses tui_helpers viewport and drawing
## - Input: Handlers for keyboard and mouse

import unicode
import tables
import storie_types
import tui_helpers
import ../src/types
import ../src/layers

# ==============================================================================
# DATA STRUCTURES
# ==============================================================================

type
  EditorLine* = object
    ## A single line of text with gap buffer for efficient editing
    ## Gap buffer: [content_before][___gap___][content_after]
    text*: seq[Rune]         # All runes in the line
    gapStart*: int           # Start of gap
    gapEnd*: int             # End of gap (exclusive)
  
  EditorBuffer* = ref object
    ## The text buffer - collection of lines
    lines*: seq[EditorLine]
    modified*: bool          # Has the buffer been modified?
    
  CursorPos* = object
    ## Cursor position in the buffer
    line*: int               # Line index (0-based)
    col*: int                # Column index in runes (0-based)
  
  Selection* = object
    ## Text selection range
    active*: bool            # Is there a selection?
    start*: CursorPos        # Selection start
    `end`*: CursorPos        # Selection end
  
  EditorState* = ref object
    ## Complete editor state (separate from buffer for undo/redo potential)
    buffer*: EditorBuffer
    cursor*: CursorPos
    selection*: Selection
    scrollX*: int            # Horizontal scroll position
    scrollY*: int            # Vertical scroll position
    desiredCol*: int         # Column cursor tries to maintain when moving up/down
    tabWidth*: int           # Width of tab character (default 4)
    insertMode*: bool        # Insert vs overwrite mode
    
  EditorConfig* = object
    ## Editor display configuration
    showLineNumbers*: bool
    lineNumberWidth*: int
    showScrollbar*: bool
    highlightCurrentLine*: bool
    wrapLines*: bool
    useSoftTabs*: bool       # Convert tabs to spaces

# ==============================================================================
# EDITOR LINE OPERATIONS
# ==============================================================================

proc newEditorLine*(text: string = ""): EditorLine =
  ## Create a new editor line from a string
  result.text = toRunes(text)
  result.gapStart = result.text.len
  result.gapEnd = result.text.len

proc len*(line: EditorLine): int =
  ## Get the length of the line (excluding gap)
  result = line.text.len - (line.gapEnd - line.gapStart)

proc toString*(line: EditorLine): string =
  ## Convert line to string
  var runes: seq[Rune] = @[]
  for i in 0 ..< line.gapStart:
    runes.add(line.text[i])
  for i in line.gapEnd ..< line.text.len:
    runes.add(line.text[i])
  result = $runes

proc getRune*(line: EditorLine, col: int): Rune =
  ## Get rune at column position
  if col < 0 or col >= line.len:
    return Rune(0)
  
  if col < line.gapStart:
    return line.text[col]
  else:
    return line.text[col + (line.gapEnd - line.gapStart)]

proc moveGapTo(line: var EditorLine, pos: int) =
  ## Move the gap to a specific position (internal helper)
  if pos == line.gapStart:
    return
  
  if pos < line.gapStart:
    # Move gap left
    let moveCount = line.gapStart - pos
    for i in countdown(moveCount - 1, 0):
      line.text[line.gapEnd - 1 - i] = line.text[line.gapStart - 1 - i]
    line.gapEnd -= moveCount
    line.gapStart -= moveCount
  else:
    # Move gap right
    let moveCount = pos - line.gapStart
    for i in 0 ..< moveCount:
      line.text[line.gapStart + i] = line.text[line.gapEnd + i]
    line.gapStart += moveCount
    line.gapEnd += moveCount

proc ensureGapSize(line: var EditorLine, minSize: int) =
  ## Ensure the gap is at least minSize
  let currentGapSize = line.gapEnd - line.gapStart
  if currentGapSize >= minSize:
    return
  
  # Grow the buffer
  let growBy = max(minSize - currentGapSize, 32)  # Grow by at least 32
  let newSize = line.text.len + growBy
  var newText = newSeq[Rune](newSize)
  
  # Copy before gap
  for i in 0 ..< line.gapStart:
    newText[i] = line.text[i]
  
  # Copy after gap
  let afterStart = line.gapEnd
  let afterCount = line.text.len - line.gapEnd
  for i in 0 ..< afterCount:
    newText[line.gapStart + growBy + i] = line.text[afterStart + i]
  
  line.text = newText
  line.gapEnd = line.gapStart + growBy

proc insertRune*(line: var EditorLine, col: int, r: Rune) =
  ## Insert a rune at the specified column
  moveGapTo(line, col)
  ensureGapSize(line, 1)
  line.text[line.gapStart] = r
  line.gapStart += 1

proc deleteRune*(line: var EditorLine, col: int) =
  ## Delete the rune at the specified column
  if col < 0 or col >= line.len:
    return
  
  moveGapTo(line, col)
  if line.gapEnd < line.text.len:
    line.gapEnd += 1

proc deleteRuneBackward*(line: var EditorLine, col: int) =
  ## Delete the rune before the specified column (backspace)
  if col <= 0 or col > line.len:
    return
  
  moveGapTo(line, col)
  if line.gapStart > 0:
    line.gapStart -= 1

# ==============================================================================
# EDITOR BUFFER OPERATIONS
# ==============================================================================

proc newEditorBuffer*(content: string = ""): EditorBuffer =
  ## Create a new editor buffer from text content
  new(result)
  result.lines = @[]
  result.modified = false
  
  if content.len == 0:
    result.lines.add(newEditorLine(""))
  else:
    # Split by newlines
    var currentLine = ""
    for ch in content:
      if ch == '\n':
        result.lines.add(newEditorLine(currentLine))
        currentLine = ""
      else:
        currentLine.add(ch)
    
    # Add last line
    result.lines.add(newEditorLine(currentLine))

proc newEditorBuffer*(lines: seq[string]): EditorBuffer =
  ## Create buffer from array of strings
  new(result)
  result.lines = @[]
  result.modified = false
  
  if lines.len == 0:
    result.lines.add(newEditorLine(""))
  else:
    for line in lines:
      result.lines.add(newEditorLine(line))

proc lineCount*(buffer: EditorBuffer): int =
  ## Get number of lines in buffer
  buffer.lines.len

proc getLine*(buffer: EditorBuffer, lineIdx: int): string =
  ## Get line as string
  if lineIdx < 0 or lineIdx >= buffer.lines.len:
    return ""
  buffer.lines[lineIdx].toString()

proc getLines*(buffer: EditorBuffer): seq[string] =
  ## Get all lines as strings
  result = @[]
  for line in buffer.lines:
    result.add(line.toString())

proc lineLength*(buffer: EditorBuffer, lineIdx: int): int =
  ## Get length of line in runes
  if lineIdx < 0 or lineIdx >= buffer.lines.len:
    return 0
  buffer.lines[lineIdx].len

proc getText*(buffer: EditorBuffer): string =
  ## Get entire buffer as string
  result = ""
  for i, line in buffer.lines:
    result.add(line.toString())
    if i < buffer.lines.len - 1:
      result.add('\n')

proc insertChar*(buffer: EditorBuffer, line, col: int, ch: char) =
  ## Insert a character at position
  if line < 0 or line >= buffer.lines.len:
    return
  buffer.lines[line].insertRune(col, Rune(ch.ord))
  buffer.modified = true

proc insertRune*(buffer: EditorBuffer, line, col: int, r: Rune) =
  ## Insert a rune at position
  if line < 0 or line >= buffer.lines.len:
    return
  buffer.lines[line].insertRune(col, r)
  buffer.modified = true

proc insertText*(buffer: EditorBuffer, line, col: int, text: string) =
  ## Insert text at position
  if line < 0 or line >= buffer.lines.len:
    return
  
  let runes = toRunes(text)
  var currentCol = col
  for r in runes:
    buffer.lines[line].insertRune(currentCol, r)
    currentCol += 1
  buffer.modified = true

proc deleteChar*(buffer: EditorBuffer, line, col: int) =
  ## Delete character at position (forward delete)
  if line < 0 or line >= buffer.lines.len:
    return
  buffer.lines[line].deleteRune(col)
  buffer.modified = true

proc deleteCharBackward*(buffer: EditorBuffer, line, col: int) =
  ## Delete character before position (backspace)
  if line < 0 or line >= buffer.lines.len:
    return
  buffer.lines[line].deleteRuneBackward(col)
  buffer.modified = true

proc insertNewline*(buffer: EditorBuffer, line, col: int) =
  ## Split line at position
  if line < 0 or line >= buffer.lines.len:
    return
  
  let currentLine = buffer.lines[line]
  let lineText = currentLine.toString()
  
  # Split the line
  let beforeText = if col <= 0: "" else: lineText[0 ..< min(col, lineText.len)]
  let afterText = if col >= lineText.len: "" else: lineText[col ..< lineText.len]
  
  buffer.lines[line] = newEditorLine(beforeText)
  buffer.lines.insert(newEditorLine(afterText), line + 1)
  buffer.modified = true

proc deleteNewline*(buffer: EditorBuffer, line: int) =
  ## Join line with next line (delete newline at end)
  if line < 0 or line >= buffer.lines.len - 1:
    return
  
  let currentText = buffer.lines[line].toString()
  let nextText = buffer.lines[line + 1].toString()
  
  buffer.lines[line] = newEditorLine(currentText & nextText)
  buffer.lines.delete(line + 1)
  buffer.modified = true

# ==============================================================================
# EDITOR STATE OPERATIONS
# ==============================================================================

proc newEditorState*(content: string = ""): EditorState =
  ## Create a new editor state
  new(result)
  result.buffer = newEditorBuffer(content)
  result.cursor = CursorPos(line: 0, col: 0)
  result.selection = Selection(active: false)
  result.scrollX = 0
  result.scrollY = 0
  result.desiredCol = 0
  result.tabWidth = 4
  result.insertMode = true

proc newEditorState*(lines: seq[string]): EditorState =
  ## Create editor state from lines
  new(result)
  result.buffer = newEditorBuffer(lines)
  result.cursor = CursorPos(line: 0, col: 0)
  result.selection = Selection(active: false)
  result.scrollX = 0
  result.scrollY = 0
  result.desiredCol = 0
  result.tabWidth = 4
  result.insertMode = true

proc clampCursor(state: EditorState) =
  ## Ensure cursor is within valid bounds
  if state.cursor.line < 0:
    state.cursor.line = 0
  elif state.cursor.line >= state.buffer.lineCount:
    state.cursor.line = state.buffer.lineCount - 1
  
  let lineLen = state.buffer.lineLength(state.cursor.line)
  if state.cursor.col < 0:
    state.cursor.col = 0
  elif state.cursor.col > lineLen:
    state.cursor.col = lineLen

proc moveCursor*(state: EditorState, line, col: int) =
  ## Move cursor to absolute position
  state.cursor.line = line
  state.cursor.col = col
  clampCursor(state)
  state.desiredCol = state.cursor.col
  state.selection.active = false

proc moveCursorRelative*(state: EditorState, deltaLine, deltaCol: int) =
  ## Move cursor by delta
  state.cursor.line += deltaLine
  state.cursor.col += deltaCol
  clampCursor(state)
  state.desiredCol = state.cursor.col

proc moveCursorUp*(state: EditorState) =
  ## Move cursor up one line
  if state.cursor.line > 0:
    state.cursor.line -= 1
    state.cursor.col = min(state.desiredCol, state.buffer.lineLength(state.cursor.line))

proc moveCursorDown*(state: EditorState) =
  ## Move cursor down one line
  if state.cursor.line < state.buffer.lineCount - 1:
    state.cursor.line += 1
    state.cursor.col = min(state.desiredCol, state.buffer.lineLength(state.cursor.line))

proc moveCursorLeft*(state: EditorState) =
  ## Move cursor left one character
  if state.cursor.col > 0:
    state.cursor.col -= 1
    state.desiredCol = state.cursor.col
  elif state.cursor.line > 0:
    # Move to end of previous line
    state.cursor.line -= 1
    state.cursor.col = state.buffer.lineLength(state.cursor.line)
    state.desiredCol = state.cursor.col

proc moveCursorRight*(state: EditorState) =
  ## Move cursor right one character
  let lineLen = state.buffer.lineLength(state.cursor.line)
  if state.cursor.col < lineLen:
    state.cursor.col += 1
    state.desiredCol = state.cursor.col
  elif state.cursor.line < state.buffer.lineCount - 1:
    # Move to start of next line
    state.cursor.line += 1
    state.cursor.col = 0
    state.desiredCol = 0

proc moveCursorToLineStart*(state: EditorState) =
  ## Move cursor to start of line (Home)
  state.cursor.col = 0
  state.desiredCol = 0

proc moveCursorToLineEnd*(state: EditorState) =
  ## Move cursor to end of line (End)
  state.cursor.col = state.buffer.lineLength(state.cursor.line)
  state.desiredCol = state.cursor.col

proc moveCursorToBufferStart*(state: EditorState) =
  ## Move cursor to start of buffer (Ctrl+Home)
  state.cursor.line = 0
  state.cursor.col = 0
  state.desiredCol = 0

proc moveCursorToBufferEnd*(state: EditorState) =
  ## Move cursor to end of buffer (Ctrl+End)
  state.cursor.line = state.buffer.lineCount - 1
  state.cursor.col = state.buffer.lineLength(state.cursor.line)
  state.desiredCol = state.cursor.col

# ==============================================================================
# TEXT EDITING OPERATIONS
# ==============================================================================

proc insertCharAtCursor*(state: EditorState, ch: char) =
  ## Insert character at cursor position
  state.buffer.insertChar(state.cursor.line, state.cursor.col, ch)
  state.cursor.col += 1
  state.desiredCol = state.cursor.col

proc insertTextAtCursor*(state: EditorState, text: string) =
  ## Insert text at cursor position
  let runes = toRunes(text)
  for r in runes:
    state.buffer.insertRune(state.cursor.line, state.cursor.col, r)
    state.cursor.col += 1
  state.desiredCol = state.cursor.col

proc deleteAtCursor*(state: EditorState) =
  ## Delete character at cursor (Delete key)
  let lineLen = state.buffer.lineLength(state.cursor.line)
  
  if state.cursor.col < lineLen:
    state.buffer.deleteChar(state.cursor.line, state.cursor.col)
  elif state.cursor.line < state.buffer.lineCount - 1:
    # At end of line - join with next line
    state.buffer.deleteNewline(state.cursor.line)

proc backspaceAtCursor*(state: EditorState) =
  ## Delete character before cursor (Backspace)
  if state.cursor.col > 0:
    state.buffer.deleteCharBackward(state.cursor.line, state.cursor.col)
    state.cursor.col -= 1
    state.desiredCol = state.cursor.col
  elif state.cursor.line > 0:
    # At start of line - join with previous line
    let prevLineLen = state.buffer.lineLength(state.cursor.line - 1)
    state.buffer.deleteNewline(state.cursor.line - 1)
    state.cursor.line -= 1
    state.cursor.col = prevLineLen
    state.desiredCol = state.cursor.col

proc insertNewlineAtCursor*(state: EditorState) =
  ## Insert newline at cursor (Enter)
  state.buffer.insertNewline(state.cursor.line, state.cursor.col)
  state.cursor.line += 1
  state.cursor.col = 0
  state.desiredCol = 0

proc insertTabAtCursor*(state: EditorState, useSoftTabs: bool = true) =
  ## Insert tab at cursor
  if useSoftTabs:
    let spaces = state.tabWidth - (state.cursor.col mod state.tabWidth)
    for i in 0 ..< spaces:
      state.buffer.insertChar(state.cursor.line, state.cursor.col, ' ')
      state.cursor.col += 1
  else:
    state.buffer.insertChar(state.cursor.line, state.cursor.col, '\t')
    state.cursor.col += 1
  state.desiredCol = state.cursor.col

# ==============================================================================
# MINIMAP GENERATION (Using Braille characters)
# ==============================================================================

proc generateMinimap*(buffer: EditorBuffer, width, height: int): seq[string] =
  ## Generate a minimap using braille characters
  ## Each braille character represents 2x4 pixels
  ## This provides a foundation for minimap rendering
  result = @[]
  
  # Braille patterns: U+2800 to U+28FF
  # Base: ⠀ (0x2800)
  # Add dots: ⠁ (dot 1), ⠂ (dot 2), etc.
  
  let linesPerBrailleRow = 4
  let charsPerBrailleCol = 2
  
  for row in 0 ..< height:
    var minimapLine = ""
    for col in 0 ..< width:
      let startLine = row * linesPerBrailleRow
      let endLine = min(startLine + linesPerBrailleRow, buffer.lineCount)
      
      # Simple density calculation
      var density = 0
      for lineIdx in startLine ..< endLine:
        let lineLen = buffer.lineLength(lineIdx)
        if lineLen > col * charsPerBrailleCol:
          density += 1
      
      # Map density to braille pattern
      let brailleChar = if density == 0: " "
                       elif density == 1: "⠂"
                       elif density == 2: "⠆"
                       elif density == 3: "⠇"
                       else: "⠿"
      
      minimapLine.add(brailleChar)
    result.add(minimapLine)

# ==============================================================================
# RENDERING
# ==============================================================================

proc drawEditor*(layer: int, x, y, w, h: int, state: EditorState, 
                config: EditorConfig) =
  ## Draw the editor using viewport
  ## This is the main stateless rendering function
  
  # Get styles
  let bgStyle = tuiGetStyle("editor.background")
  let borderStyle = tuiGetStyle("editor.border")
  let cursorStyle = tuiGetStyle("editor.cursor")
  let lineNumStyle = tuiGetStyle("editor.linenumber")
  let lineNumActiveStyle = tuiGetStyle("editor.linenumber.active")
  
  # Calculate dimensions
  let lineNumWidth = if config.showLineNumbers: config.lineNumberWidth else: 0
  let minimapWidth = 14  # Width for integrated minimap
  let contentX = x + lineNumWidth
  let contentW = w - lineNumWidth - minimapWidth
  
  # Draw border
  drawBoxSingle(layer, x, y, w, h, borderStyle)
  
  # Calculate visible area
  let contentHeight = h - 2
  let visibleStartLine = state.scrollY
  let visibleEndLine = min(state.scrollY + contentHeight, state.buffer.lineCount)
  
  # Draw line numbers if enabled
  if config.showLineNumbers and lineNumWidth > 0:
    for i in visibleStartLine ..< visibleEndLine:
      let screenY = y + 1 + (i - visibleStartLine)
      let lineNum = $(i + 1)
      let isCurrentLine = i == state.cursor.line
      let style = if isCurrentLine: lineNumActiveStyle else: lineNumStyle
      tuiDraw(layer, x + 1, screenY, lineNum, style)
  
  # Draw content lines with horizontal scroll
  let contentWidthChars = contentW - 4
  for i in visibleStartLine ..< visibleEndLine:
    let screenY = y + 1 + (i - visibleStartLine)
    let lineText = state.buffer.getLine(i)
    let runes = toRunes(lineText)
    let runeCount = runes.len
    
    # Apply horizontal scroll
    var visibleText = ""
    if state.scrollX < runeCount:
      let endCol = min(state.scrollX + contentWidthChars, runeCount)
      if endCol > state.scrollX:
        # Extract visible portion using unicode runes
        var visibleRunes: seq[Rune] = @[]
        for j in state.scrollX ..< endCol:
          visibleRunes.add(runes[j])
        visibleText = $visibleRunes
    
    tuiDraw(layer, contentX + 2, screenY, visibleText, bgStyle)
  
  # Draw cursor (inverted character at cursor position)
  if state.cursor.line >= visibleStartLine and state.cursor.line < visibleEndLine:
    let cursorScreenY = y + 1 + (state.cursor.line - visibleStartLine)
    let cursorScreenX = contentX + 2 + (state.cursor.col - state.scrollX)
    # Only draw cursor if it's visible horizontally
    if state.cursor.col >= state.scrollX and state.cursor.col < state.scrollX + contentWidthChars:
      # Get the character at cursor position (or space if at end of line)
      let lineText = state.buffer.getLine(state.cursor.line)
      let runes = toRunes(lineText)
      let cursorChar = if state.cursor.col < runes.len:
                         $runes[state.cursor.col]
                       else:
                         " "
      
      # Create inverted style by swapping fg and bg colors
      var invertedStyle = bgStyle
      let tempColor = invertedStyle.fg
      invertedStyle.fg = invertedStyle.bg
      invertedStyle.bg = tempColor
      
      tuiDraw(layer, cursorScreenX, cursorScreenY, cursorChar, invertedStyle)
  
  # Draw integrated minimap (replaces scrollbar)
  if config.showScrollbar and state.buffer.lineCount > contentHeight:
    let minimapX = x + w - minimapWidth
    let minimapH = contentHeight
    let minimap = generateMinimap(state.buffer, minimapWidth - 1, minimapH)
    
    # Draw minimap content (no border)
    for i, line in minimap:
      if i < minimapH:
        tuiDraw(layer, minimapX, y + 1 + i, line, tuiGetStyle("default"))
    
    # Draw viewport indicator on minimap
    let minimapStartY = if state.buffer.lineCount > contentHeight:
                          int((float(state.scrollY) / float(state.buffer.lineCount - contentHeight)) * float(minimapH - 1))
                        else:
                          0
    let minimapVisibleHeight = max(1, int((float(contentHeight) / float(state.buffer.lineCount)) * float(minimapH)))
    
    for dy in 0 ..< minimapVisibleHeight:
      if minimapStartY + dy < minimapH:
        tuiDraw(layer, minimapX + minimapWidth - 1, y + 1 + minimapStartY + dy, "█", tuiGetStyle("info"))

proc drawEditorSimple*(layer: int, x, y, w, h: int, state: EditorState) =
  ## Simplified editor rendering with default config
  let config = EditorConfig(
    showLineNumbers: true,
    lineNumberWidth: 5,
    showScrollbar: true,
    highlightCurrentLine: false,
    wrapLines: false,
    useSoftTabs: true
  )
  drawEditor(layer, x, y, w, h, state, config)

# ==============================================================================
# INPUT HANDLING
# ==============================================================================

proc handleEditorKeyPress*(state: EditorState, keyCode: int, key: string,
                          mods: seq[string]): bool =
  ## Handle keyboard input for editor
  ## Returns true if input was handled
  
  let ctrl = "ctrl" in mods
  let shift = "shift" in mods
  
  case keyCode
  of 37, 1002:  # Left arrow (browser: 37, terminal: 1002)
    moveCursorLeft(state)
    return true
  of 38, 1000:  # Up arrow (browser: 38, terminal: 1000)
    moveCursorUp(state)
    return true
  of 39, 1003:  # Right arrow (browser: 39, terminal: 1003)
    moveCursorRight(state)
    return true
  of 40, 1001:  # Down arrow (browser: 40, terminal: 1001)
    moveCursorDown(state)
    return true
  of 36:  # Home
    if ctrl:
      moveCursorToBufferStart(state)
    else:
      moveCursorToLineStart(state)
    return true
  of 35:  # End
    if ctrl:
      moveCursorToBufferEnd(state)
    else:
      moveCursorToLineEnd(state)
    return true
  of 8:   # Backspace
    backspaceAtCursor(state)
    return true
  of 46:  # Delete
    deleteAtCursor(state)
    return true
  of 13:  # Enter
    insertNewlineAtCursor(state)
    return true
  of 9:   # Tab
    insertTabAtCursor(state, useSoftTabs = true)
    return true
  else:
    # Regular character input
    if key.len == 1 and not ctrl:
      insertCharAtCursor(state, key[0])
      return true
  
  return false

proc handleEditorMouseClick*(state: EditorState, mouseX, mouseY: int,
                            editorX, editorY, editorW, editorH: int,
                            config: EditorConfig): bool =
  ## Handle mouse click in editor
  ## Returns true if click was inside editor
  
  if not pointInRect(mouseX, mouseY, editorX, editorY, editorW, editorH):
    return false
  
  # Calculate which line was clicked
  let lineNumWidth = if config.showLineNumbers: config.lineNumberWidth else: 0
  let contentX = editorX + lineNumWidth + 2  # Account for border and padding
  let contentY = editorY + 1                 # Account for border
  
  if mouseX < contentX:
    # Clicked in line number area
    return true
  
  # Calculate line
  let clickedLine = state.scrollY + (mouseY - contentY)
  if clickedLine < 0 or clickedLine >= state.buffer.lineCount:
    return true
  
  # Calculate column (adjust for horizontal scroll)
  let clickedCol = max(0, state.scrollX + (mouseX - contentX))
  
  # Move cursor
  moveCursor(state, clickedLine, clickedCol)
  
  return true

proc handleMinimapClick*(state: EditorState, mouseX, mouseY: int,
                        editorX, editorY, editorW, editorH: int,
                        config: EditorConfig): bool =
  ## Handle mouse click on minimap for scrolling
  ## Returns true if click was on minimap
  
  let minimapWidth = 14
  let minimapX = editorX + editorW - minimapWidth
  let contentY = editorY + 1
  let contentHeight = editorH - 2
  
  # Check if click is in minimap area
  if mouseX < minimapX or mouseX >= editorX + editorW - 1:
    return false
  if mouseY < contentY or mouseY >= contentY + contentHeight:
    return false
  
  # Calculate which line to scroll to based on minimap click
  let relativeY = mouseY - contentY
  let targetLine = int((float(relativeY) / float(contentHeight)) * float(state.buffer.lineCount))
  
  # Scroll to center the clicked line
  let halfHeight = contentHeight div 2
  state.scrollY = max(0, min(targetLine - halfHeight, state.buffer.lineCount - contentHeight))
  
  return true

# ==============================================================================
# SCROLL MANAGEMENT
# ==============================================================================

proc updateEditorScroll*(state: EditorState, viewportHeight: int, viewportWidth: int) =
  ## Update scroll position to keep cursor visible
  let contentHeight = viewportHeight - 2
  let contentWidth = viewportWidth - 4  # Account for borders and padding
  
  # Vertical scrolling
  if state.cursor.line < state.scrollY:
    state.scrollY = state.cursor.line
  elif state.cursor.line >= state.scrollY + contentHeight:
    state.scrollY = state.cursor.line - contentHeight + 1
  
  # Horizontal scrolling
  if state.cursor.col < state.scrollX:
    state.scrollX = state.cursor.col
  elif state.cursor.col >= state.scrollX + contentWidth:
    state.scrollX = state.cursor.col - contentWidth + 1
  
  # Clamp vertical scroll
  let maxScrollY = max(0, state.buffer.lineCount - contentHeight)
  if state.scrollY < 0:
    state.scrollY = 0
  elif state.scrollY > maxScrollY:
    state.scrollY = maxScrollY
  
  # Clamp horizontal scroll
  if state.scrollX < 0:
    state.scrollX = 0

# ==============================================================================
# STANDALONE MINIMAP (for separate rendering)
# ==============================================================================

proc drawMinimap*(layer: int, x, y, w, h: int, buffer: EditorBuffer, 
                 scrollY: int, viewportHeight: int) =
  ## Draw a minimap of the buffer
  let minimap = generateMinimap(buffer, w - 2, h - 2)
  
  # Draw border
  drawBoxSingle(layer, x, y, w, h, tuiGetStyle("border"))
  
  # Draw minimap content
  for i, line in minimap:
    tuiDraw(layer, x + 1, y + 1 + i, line, tuiGetStyle("default"))
  
  # Draw viewport indicator
  let contentHeight = viewportHeight - 2
  let minimapStartY = int((float(scrollY) / float(buffer.lineCount)) * float(h - 2))
  let minimapHeight = max(1, int((float(contentHeight) / float(buffer.lineCount)) * float(h - 2)))
  
  for dy in 0 ..< minimapHeight:
    if minimapStartY + dy < h - 2:
      tuiDraw(layer, x + w - 2, y + 1 + minimapStartY + dy, "█", tuiGetStyle("info"))

# ==============================================================================
# EXPORTS
# ==============================================================================

export EditorLine, EditorBuffer, CursorPos, Selection, EditorState, EditorConfig
export newEditorLine, newEditorBuffer, newEditorState
export lineCount, getLine, getLines, getText, lineLength
export insertChar, insertRune, insertText, deleteChar, deleteCharBackward
export insertNewline, deleteNewline
export moveCursor, moveCursorRelative, moveCursorUp, moveCursorDown
export moveCursorLeft, moveCursorRight, moveCursorToLineStart, moveCursorToLineEnd
export moveCursorToBufferStart, moveCursorToBufferEnd
export insertCharAtCursor, insertTextAtCursor, deleteAtCursor, backspaceAtCursor
export insertNewlineAtCursor, insertTabAtCursor
export drawEditor, drawEditorSimple
export handleEditorKeyPress, handleEditorMouseClick, handleMinimapClick
export updateEditorScroll
export generateMinimap, drawMinimap
