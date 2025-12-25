## TStoried - TStorie Editor/Daemon
##
## Standalone terminal markdown editor for TStorie content.
## Built independently to identify core vs. application concerns.
##
## Usage:
##   tstoried                    # Start with empty document
##   tstoried file.md            # Load file
##   tstoried --gist abc123      # Load gist
##
## Keyboard shortcuts:
##   Ctrl+Q - Quit
##   Ctrl+W - Save file
##   Ctrl+G - Create/update gist
##   Ctrl+O - Open file/gist browser
##   Esc    - Cancel/back

import std/[os, strutils, parseopt, terminal, times]

when not defined(js):
  import osproc  # For shell commands in native builds

when defined(js):
  # Import tstorie rendering modules for WASM preview
  import lib/[canvas, storie_md, section_manager, layout, drawing]

import lib/[storie_types, storie_themes, gist_api, editor_base]

# ================================================================
# APPLICATION STATE
# ================================================================

type
  EditorMode = enum
    modeEdit      ## Text editing
    modeBrowse    ## File/gist browser
    modePreview   ## Live preview (WASM only, native shells out)
  
  EditorApp = object
    mode: EditorMode
    previousMode: EditorMode
    
    # Document state
    lines: seq[string]
    cursor: tuple[row, col: int]
    scroll: int
    filename: string
    gistId: string
    modified: bool
    
    # Browser state
    browserItems: seq[tuple[text, data: string]]
    browserSelected: int
    
    # Display
    termWidth: int
    termHeight: int
    showLineNumbers: bool
    
    # Preview state
    when defined(js):
      previewCanvas: Canvas
    currentSection: int
    splitMode: bool
    
    # Theme
    stylesheet: StyleSheet
    statusMsg: string
    running: bool

var app: EditorApp

# ================================================================
# INITIALIZATION
# ================================================================

proc initApp*() =
  app.mode = modeEdit
  app.previousMode = modeEdit
  app.lines = @[""]
  app.cursor = (0, 0)
  app.scroll = 0
  app.filename = ""
  app.gistId = ""
  app.modified = false
  app.browserItems = @[]
  app.browserSelected = 0
  app.showLineNumbers = true
  app.running = true
  app.currentSection = 0
  app.splitMode = false
  
  # Get terminal size
  app.termWidth = terminalWidth()
  app.termHeight = terminalHeight()
  
  when defined(js):
    # Initialize preview canvas for WASM
    app.previewCanvas = newCanvas(app.termWidth div 2, app.termHeight)
  
  # Setup theme
  app.stylesheet = applyFullTheme("miami-vice")
  app.statusMsg = "Ready | Ctrl+Q: Quit | Ctrl+R: Preview"

# ================================================================
# DOCUMENT OPERATIONS
# ================================================================

proc getText(): string =
  return app.lines.join("\n")

proc setText(text: string) =
  app.lines = text.split('\n')
  if app.lines.len == 0:
    app.lines = @[""]
  app.cursor = (0, 0)
  app.scroll = 0
  app.modified = true

proc insertChar(ch: char) =
  let row = app.cursor.row
  let col = app.cursor.col
  if row >= 0 and row < app.lines.len:
    var line = app.lines[row]
    line.insert($ch, col)
    app.lines[row] = line
    app.cursor.col += 1
    app.modified = true

proc deleteChar() =
  let row = app.cursor.row
  let col = app.cursor.col
  
  if col > 0:
    var line = app.lines[row]
    if col <= line.len:
      line.delete(col - 1 .. col - 1)
      app.lines[row] = line
      app.cursor.col -= 1
      app.modified = true
  elif row > 0:
    let prevLine = app.lines[row - 1]
    let currentLine = app.lines[row]
    app.lines[row - 1] = prevLine & currentLine
    app.lines.delete(row)
    app.cursor.row -= 1
    app.cursor.col = prevLine.len
    app.modified = true

proc insertNewline() =
  let row = app.cursor.row
  let col = app.cursor.col
  let line = app.lines[row]
  
  let beforeCursor = if col <= line.len: line[0 ..< col] else: line
  let afterCursor = if col <= line.len: line[col .. ^1] else: ""
  
  app.lines[row] = beforeCursor
  app.lines.insert(afterCursor, row + 1)
  app.cursor.row += 1
  app.cursor.col = 0
  app.modified = true

proc moveCursor(drow, dcol: int) =
  var newRow = app.cursor.row + drow
  var newCol = app.cursor.col + dcol
  
  newRow = max(0, min(newRow, app.lines.len - 1))
  let lineLen = app.lines[newRow].len
  newCol = max(0, min(newCol, lineLen))
  
  app.cursor = (newRow, newCol)

proc ensureCursorVisible() =
  let gutterWidth = if app.showLineNumbers: 5 else: 0
  let visibleHeight = app.termHeight - 1  # Reserve 1 for status
  
  if app.cursor.row < app.scroll:
    app.scroll = app.cursor.row
  elif app.cursor.row >= app.scroll + visibleHeight:
    app.scroll = app.cursor.row - visibleHeight + 1

# ================================================================
# FILE OPERATIONS  
# ================================================================

proc loadFile(path: string) =
  if not fileExists(path):
    app.statusMsg = "Error: File not found"
    return
  
  try:
    let content = readFile(path)
    setText(content)
    app.filename = path
    app.modified = false
    app.statusMsg = "Loaded: " & path
  except IOError as e:
    app.statusMsg = "Error: " & e.msg

proc saveFile() =
  if app.filename == "":
    app.statusMsg = "Error: No filename"
    return
  
  try:
    writeFile(app.filename, getText())
    app.modified = false
    app.statusMsg = "Saved: " & app.filename
  except IOError as e:
    app.statusMsg = "Error: " & e.msg

proc loadGistById(gistId: string) =
  try:
    let gist = loadGist(gistId)
    if not gist.hasMarkdownFile():
      app.statusMsg = "Error: No markdown files in gist"
      return
    
    let mdFile = gist.getFirstMarkdownFile()
    setText(mdFile.content)
    app.gistId = gistId
    app.filename = mdFile.filename
    app.modified = false
    app.statusMsg = "Loaded gist: " & gistId
  except GistError as e:
    app.statusMsg = "Error: " & e.msg

proc createOrUpdateGist() =
  if not hasGithubToken():
    app.statusMsg = "Error: Set GITHUB_TOKEN"
    return
  
  let content = getText()
  let filename = if app.filename != "": app.filename else: "tstorie.md"
  
  try:
    if app.gistId != "":
      var gist = Gist(
        id: app.gistId,
        description: "TStorie content",
        public: true,
        files: @[GistFile(filename: filename, content: content)]
      )
      updateGist(gist)
      app.statusMsg = "Updated gist: " & app.gistId
    else:
      var gist = Gist(
        description: "TStorie content",
        public: true,
        files: @[GistFile(filename: filename, content: content)]
      )
      let newId = createGist(gist)
      app.gistId = newId
      app.statusMsg = "Created gist: " & newId
    app.modified = false
  except GistError as e:
    app.statusMsg = "Error: " & e.msg

# ================================================================
# BROWSER MODE
# ================================================================

proc populateBrowser() =
  app.browserItems = @[]
  
  # Add local markdown files
  try:
    for kind, path in walkDir("."):
      if kind == pcFile and path.endsWith(".md"):
        app.browserItems.add((path, path))
  except OSError:
    discard
  
  # Add gists if token available
  if hasGithubToken():
    try:
      let gists = listUserGists()
      for gist in gists:
        if gist.hasMarkdownFile():
          let desc = if gist.description != "": gist.description else: gist.id
          app.browserItems.add(("[GIST] " & desc, gist.id))
    except GistError:
      discard
  
  app.browserSelected = 0

proc switchMode(newMode: EditorMode) =
  app.previousMode = app.mode
  app.mode = newMode
  
  if newMode == modeBrowse:
    populateBrowser()
    app.statusMsg = "BROWSE | Enter: Open | Esc: Cancel"
  elif newMode == modePreview:
    when defined(js):
      app.splitMode = true
      app.statusMsg = "PREVIEW | Esc: Exit | Space/Enter: Next section"
    else:
      app.statusMsg = "Starting preview..."
  else:
    when defined(js):
      app.splitMode = false
    app.statusMsg = if app.filename != "": app.filename else: "[No File]"

# ================================================================
# PREVIEW MODE
# ================================================================

when not defined(js):
  # Native: Shell out to tstorie
  proc launchPreview() =
    # Save current content to temp file
    let tempFile = "/tmp/tstoried_preview.md"
    try:
      writeFile(tempFile, getText())
      
      # Check if running in tmux
      if getEnv("TMUX") != "":
        # Split window and run tstorie
        let cmd = "tmux split-window -h './tstorie " & tempFile & "'"
        let exitCode = execShellCmd(cmd)
        if exitCode == 0:
          app.statusMsg = "Preview launched in split pane"
        else:
          app.statusMsg = "Error: Could not split tmux window"
      else:
        # Not in tmux, just run tstorie in same terminal
        app.statusMsg = "Launching preview (not in tmux, will take over terminal)..."
        stdout.flushFile()
        sleep(1000)  # Let user see message
        discard execShellCmd("./tstorie " & tempFile)
        # When tstorie exits, we return here
        app.statusMsg = "Preview closed. Back to editing."
    except IOError as e:
      app.statusMsg = "Error: " & e.msg
    
    # Return to edit mode
    app.mode = modeEdit

when defined(js):
  # WASM: Render preview inline using bundled tstorie engine
  proc renderPreview() =
    try:
      # Parse markdown content
      let content = getText()
      let sections = parseMarkdown(content)
      
      if sections.len == 0:
        return
      
      # Ensure current section is valid
      if app.currentSection < 0:
        app.currentSection = 0
      elif app.currentSection >= sections.len:
        app.currentSection = sections.len - 1
      
      # Render current section to preview canvas
      let section = sections[app.currentSection]
      renderSectionToCanvas(section, app.previewCanvas)
      
    except:
      # If parsing/rendering fails, show error
      discard
  
  proc nextSection() =
    let sections = parseMarkdown(getText())
    if app.currentSection < sections.len - 1:
      inc app.currentSection
      app.statusMsg = "Section " & $(app.currentSection + 1) & "/" & $sections.len
  
  proc prevSection() =
    if app.currentSection > 0:
      dec app.currentSection
      let sections = parseMarkdown(getText())
      app.statusMsg = "Section " & $(app.currentSection + 1) & "/" & $sections.len

# ================================================================
# RENDERING
# ================================================================

proc render() =
  # Clear screen
  stdout.write("\e[2J\e[H")
  
  when defined(js):
    # WASM: Handle split view rendering
    if app.splitMode and app.mode == modePreview:
      let splitX = app.termWidth div 2
      
      # Render editor on left half
      let gutterWidth = if app.showLineNumbers: 5 else: 0
      let visibleHeight = app.termHeight - 1
      let visibleStart = app.scroll
      let visibleEnd = min(app.scroll + visibleHeight, app.lines.len)
      
      for i in visibleStart ..< visibleEnd:
        let screenY = i - visibleStart
        
        # Line number
        if app.showLineNumbers:
          let lineNum = i + 1
          let numStr = align($lineNum, 4)
          let isCurrentLine = (i == app.cursor.row)
          stdout.write(if isCurrentLine: "\e[1;35m" else: "\e[2;37m")
          stdout.write(numStr)
          stdout.write("\e[0m│")
        
        # Line content (truncate at split)
        let lineContent = if app.lines[i].len > splitX - gutterWidth:
                           app.lines[i][0 ..< (splitX - gutterWidth - 3)] & "..."
                         else:
                           app.lines[i]
        stdout.write(lineContent)
        
        # Move to divider position
        stdout.write("\e[" & $(screenY + 1) & ";" & $splitX & "H")
        stdout.write("\e[2;37m│\e[0m")
        stdout.write("\n")
      
      # Render preview on right half
      renderPreview()
      
      # Draw status bar
      stdout.write("\e[" & $app.termHeight & ";1H")
      stdout.write("\e[1;35;40m")
      stdout.write(app.statusMsg)
      let padding = app.termWidth - app.statusMsg.len
      if padding > 0:
        stdout.write(repeat(" ", padding))
      stdout.write("\e[0m")
      stdout.flushFile()
      return
  
  case app.mode
  of modeEdit, modePreview:
    # Render text editor
    let gutterWidth = if app.showLineNumbers: 5 else: 0
    let visibleHeight = app.termHeight - 1
    let visibleStart = app.scroll
    let visibleEnd = min(app.scroll + visibleHeight, app.lines.len)
    
    for i in visibleStart ..< visibleEnd:
      let screenY = i - visibleStart
      
      # Line number
      if app.showLineNumbers:
        let lineNum = i + 1
        let numStr = align($lineNum, 4)
        let isCurrentLine = (i == app.cursor.row)
        stdout.write(if isCurrentLine: "\e[1;35m" else: "\e[2;37m")
        stdout.write(numStr)
        stdout.write("\e[0m│")
      
      # Line content
      stdout.write(app.lines[i])
      stdout.write("\n")
    
    # Position cursor
    let cursorScreenY = app.cursor.row - app.scroll
    let cursorScreenX = app.cursor.col + gutterWidth
    if cursorScreenY >= 0 and cursorScreenY < visibleHeight:
      stdout.write("\e[" & $(cursorScreenY + 1) & ";" & $(cursorScreenX + 1) & "H")
  
  of modeBrowse:
    # Render file browser
    let visibleHeight = app.termHeight - 1
    for i, item in app.browserItems:
      if i >= visibleHeight:
        break
      
      let isSelected = (i == app.browserSelected)
      if isSelected:
        stdout.write("\e[1;35;40m")
      stdout.write(item.text)
      if isSelected:
        stdout.write("\e[0m")
      stdout.write("\n")
  
  # Status bar at bottom
  stdout.write("\e[" & $app.termHeight & ";1H")
  stdout.write("\e[1;35;40m")
  stdout.write(app.statusMsg)
  # Pad to full width
  let padding = app.termWidth - app.statusMsg.len
  if padding > 0:
    stdout.write(repeat(" ", padding))
  stdout.write("\e[0m")
  
  stdout.flushFile()

# ================================================================
# INPUT HANDLING
# ================================================================

proc handleInput(ch: char): bool =
  case app.mode
  of modeEdit:
    case ch
    of '\x11':  # Ctrl+Q
      return false
    of '\x17':  # Ctrl+W
      saveFile()
    of '\x07':  # Ctrl+G
      createOrUpdateGist()
    of '\x0F':  # Ctrl+O
      switchMode(modeBrowse)
    of '\x12':  # Ctrl+R - Preview
      when not defined(js):
        launchPreview()
      else:
        switchMode(modePreview)
    of '\x7F':  # Backspace
      deleteChar()
      ensureCursorVisible()
    of '\r', '\n':  # Enter
      insertNewline()
      ensureCursorVisible()
    of '\x1B':  # Escape sequence
      discard  # Would need to read more chars for arrow keys
    of ' '..'~':  # Printable characters
      insertChar(ch)
      ensureCursorVisible()
    else:
      discard
  
  of modeBrowse:
    case ch
    of '\x1B':  # Escape
      switchMode(modeEdit)
    of '\r', '\n':  # Enter
      if app.browserSelected >= 0 and app.browserSelected < app.browserItems.len:
        let item = app.browserItems[app.browserSelected]
        if item.data.endsWith(".md"):
          loadFile(item.data)
        else:
          loadGistById(item.data)
        switchMode(modeEdit)
    of 'j', 'J':  # Down
      if app.browserSelected < app.browserItems.len - 1:
        inc app.browserSelected
    of 'k', 'K':  # Up
      if app.browserSelected > 0:
        dec app.browserSelected
    of '\x11':  # Ctrl+Q
      return false
    else:
      discard
  
  of modePreview:
    when defined(js):
      case ch
      of '\x1B':  # Escape
        switchMode(modeEdit)
      of ' ', '\r', '\n':  # Space or Enter - next section
        nextSection()
      of 'b', 'B':  # Back - previous section
        prevSection()
      of '\x11':  # Ctrl+Q
        return false
      else:
        discard
    else:
      # Native doesn't stay in preview mode
      discard
  
  return true

# ================================================================
# MAIN LOOP
# ================================================================

proc main() =
  # Parse command line
  var filename = ""
  var gistId = ""
  
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "gist", "g":
        gistId = p.val
      of "help", "h":
        echo "TStoried - TStorie Editor"
        echo "Usage: tstoried [file.md]"
        echo "       tstoried --gist ID"
        echo ""
        echo "Keyboard Shortcuts:"
        echo "  Ctrl+Q - Quit"
        echo "  Ctrl+W - Save file"
        echo "  Ctrl+G - Create/update gist"
        echo "  Ctrl+O - Browse files/gists"
        echo "  Ctrl+R - Preview (tmux split or full screen)"
        echo ""
        echo "Preview Mode:"
        echo "  Space/Enter - Next section (WASM only)"
        echo "  B - Previous section (WASM only)"
        echo "  Esc - Exit preview"
        quit(0)
      else:
        discard
    of cmdArgument:
      filename = p.key
  
  # Initialize
  initApp()
  
  # Load initial content
  if gistId != "":
    loadGistById(gistId)
  elif filename != "":
    loadFile(filename)
  
  # Setup terminal
  hideCursor()
  system.addQuitProc(resetAttributes)
  
  try:
    # Main loop
    while app.running:
      # Update terminal size
      app.termWidth = terminalWidth()
      app.termHeight = terminalHeight()
      
      # Render
      render()
      
      # Handle input
      if not getch().handleInput():
        app.running = false
      
      # Small delay to reduce CPU
      sleep(10)
  finally:
    # Cleanup
    showCursor()
    resetAttributes()
    stdout.write("\e[2J\e[H")
    stdout.write("Goodbye!\n")
    stdout.flushFile()

when isMainModule:
  main()
