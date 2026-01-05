## ANSI Escape Sequence Parser
##
## Parses ANSI escape sequences and renders them into TermBuffer structures.
## This is designed for both embedded content (ansi:name blocks) and future
## terminal emulator implementations (e.g., SDL3-based).
##
## Supports:
## - SGR (Select Graphic Rendition): colors, bold, italic, underline, dim
## - 8-color, 16-color, 256-color, and RGB color modes
## - Cursor positioning (for terminal emulator use)
## - Basic cursor movement sequences
##
## Reference: https://en.wikipedia.org/wiki/ANSI_escape_code

import strutils, unicode
import ../src/types
import ../src/layers

export Cell, Style, TermBuffer

# ================================================================
# ANSI COLOR CONVERSION
# ================================================================

proc ansi8ToRgb*(colorNum: int): Color =
  ## Convert 8-color ANSI code (0-7 or 8-15 for bright) to RGB
  const baseColors = [
    (0'u8, 0'u8, 0'u8),       # 0: Black
    (205'u8, 49'u8, 49'u8),   # 1: Red
    (13'u8, 188'u8, 121'u8),  # 2: Green
    (229'u8, 229'u8, 16'u8),  # 3: Yellow
    (36'u8, 114'u8, 200'u8),  # 4: Blue
    (188'u8, 63'u8, 188'u8),  # 5: Magenta
    (17'u8, 168'u8, 205'u8),  # 6: Cyan
    (229'u8, 229'u8, 229'u8), # 7: White (light gray)
  ]
  
  const brightColors = [
    (102'u8, 102'u8, 102'u8), # 8: Bright Black (dark gray)
    (241'u8, 76'u8, 76'u8),   # 9: Bright Red
    (35'u8, 209'u8, 139'u8),  # 10: Bright Green
    (245'u8, 245'u8, 67'u8),  # 11: Bright Yellow
    (59'u8, 142'u8, 234'u8),  # 12: Bright Blue
    (214'u8, 112'u8, 214'u8), # 13: Bright Magenta
    (41'u8, 184'u8, 219'u8),  # 14: Bright Cyan
    (255'u8, 255'u8, 255'u8), # 15: Bright White
  ]
  
  let idx = colorNum mod 16
  if idx < 8:
    let c = baseColors[idx]
    return Color(r: c[0], g: c[1], b: c[2])
  else:
    let c = brightColors[idx - 8]
    return Color(r: c[0], g: c[1], b: c[2])

proc ansi256ToRgb*(colorNum: int): Color =
  ## Convert 256-color ANSI code to RGB
  ## Color space: 0-15 (system colors), 16-231 (6x6x6 RGB cube), 232-255 (grayscale)
  
  if colorNum < 16:
    return ansi8ToRgb(colorNum)
  elif colorNum < 232:
    # 6x6x6 RGB cube (216 colors)
    let idx = colorNum - 16
    let r = (idx div 36) mod 6
    let g = (idx div 6) mod 6
    let b = idx mod 6
    
    # Convert 0-5 range to 0-255 range
    let rVal = if r == 0: 0'u8 else: uint8(55 + r * 40)
    let gVal = if g == 0: 0'u8 else: uint8(55 + g * 40)
    let bVal = if b == 0: 0'u8 else: uint8(55 + b * 40)
    
    return Color(r: rVal, g: gVal, b: bVal)
  else:
    # Grayscale ramp (24 shades)
    let gray = uint8(8 + (colorNum - 232) * 10)
    return Color(r: gray, g: gray, b: gray)

# ================================================================
# SGR (SELECT GRAPHIC RENDITION) PARSER
# ================================================================

proc applySgrParams*(params: seq[int], style: var Style) =
  ## Apply SGR (Select Graphic Rendition) parameters to a style
  ## Handles colors, bold, italic, underline, dim, etc.
  var i = 0
  
  while i < params.len:
    let code = params[i]
    
    case code
    of 0:  # Reset all attributes to global default
      let defaultSty = defaultStyle()
      style.fg = defaultSty.fg
      style.bg = defaultSty.bg
      style.bold = defaultSty.bold
      style.italic = defaultSty.italic
      style.underline = defaultSty.underline
      style.dim = defaultSty.dim
    
    # Font styles
    of 1:  # Bold
      style.bold = true
    of 2:  # Dim/faint
      style.dim = true
    of 3:  # Italic
      style.italic = true
    of 4:  # Underline
      style.underline = true
    of 22:  # Normal intensity (not bold or dim)
      style.bold = false
      style.dim = false
    of 23:  # Not italic
      style.italic = false
    of 24:  # Not underlined
      style.underline = false
    
    # Foreground colors (8-color)
    of 30..37:
      style.fg = ansi8ToRgb(code - 30)
    
    # Background colors (8-color)
    of 40..47:
      style.bg = ansi8ToRgb(code - 40)
    
    # Extended foreground color
    of 38:
      if i + 2 < params.len:
        if params[i + 1] == 5:
          # 256-color mode: ESC[38;5;<n>m
          style.fg = ansi256ToRgb(params[i + 2])
          i += 2
        elif params[i + 1] == 2 and i + 4 < params.len:
          # RGB mode: ESC[38;2;<r>;<g>;<b>m
          let r = params[i + 2].uint8
          let g = params[i + 3].uint8
          let b = params[i + 4].uint8
          style.fg = Color(r: r, g: g, b: b)
          i += 4
    
    # Extended background color
    of 48:
      if i + 2 < params.len:
        if params[i + 1] == 5:
          # 256-color mode: ESC[48;5;<n>m
          style.bg = ansi256ToRgb(params[i + 2])
          i += 2
        elif params[i + 1] == 2 and i + 4 < params.len:
          # RGB mode: ESC[48;2;<r>;<g>;<b>m
          let r = params[i + 2].uint8
          let g = params[i + 3].uint8
          let b = params[i + 4].uint8
          style.bg = Color(r: r, g: g, b: b)
          i += 4
    
    # Default foreground color
    of 39:
      style.fg = white()
    
    # Default background color
    of 49:
      style.bg = black()
    
    # Bright foreground colors (90-97)
    of 90..97:
      style.fg = ansi8ToRgb(code - 90 + 8)
    
    # Bright background colors (100-107)
    of 100..107:
      style.bg = ansi8ToRgb(code - 100 + 8)
    
    else:
      discard  # Ignore unsupported codes
    
    inc i

# ================================================================
# ANSI ESCAPE SEQUENCE PARSER
# ================================================================

type
  AnsiParserState* = object
    ## State machine for parsing ANSI escape sequences
    x*, y*: int              ## Current cursor position
    style*: Style            ## Current text style
    savedX*, savedY*: int    ## Saved cursor position (DECSC/DECRC)
    maxX*, maxY*: int        ## Track maximum extents for auto-sizing

proc newAnsiParserState*(): AnsiParserState =
  ## Create a new ANSI parser state
  result.x = 0
  result.y = 0
  result.style = defaultStyle()
  result.savedX = 0
  result.savedY = 0
  result.maxX = 0
  result.maxY = 0

proc parseAnsiSequence*(content: string, startPos: int): tuple[seqLen: int, cmd: char, params: seq[int]] =
  ## Parse a single ANSI escape sequence starting at ESC[
  ## Returns: (length of sequence, command character, parameters)
  ## Returns seqLen=0 if invalid sequence
  
  result.seqLen = 0
  result.cmd = '\0'
  result.params = @[]
  
  var i = startPos
  if i >= content.len or content[i] != '\x1b':
    return
  
  inc i  # Skip ESC
  if i >= content.len or content[i] != '[':
    # Not a CSI sequence - might be other sequence types
    # For now we only handle CSI (Control Sequence Introducer)
    return
  
  inc i  # Skip [
  
  # Parse parameters (numbers separated by semicolons)
  var numStr = ""
  var foundCmd = false
  
  while i < content.len:
    let ch = content[i]
    
    case ch
    of '0'..'9':
      numStr.add(ch)
    of ';', ':':
      # Parameter separator
      if numStr.len > 0:
        try:
          result.params.add(parseInt(numStr))
        except:
          result.params.add(0)
        numStr = ""
      else:
        # Empty parameter defaults to 0
        result.params.add(0)
    of 'A'..'Z', 'a'..'z':
      # Command character - end of sequence
      if numStr.len > 0:
        try:
          result.params.add(parseInt(numStr))
        except:
          result.params.add(0)
      result.cmd = ch
      foundCmd = true
      inc i
      break
    else:
      # Invalid character, abort
      return (0, '\0', @[])
    
    inc i
  
  if foundCmd:
    result.seqLen = i - startPos
  else:
    result.seqLen = 0

proc parseAnsiToBuffer*(ansiContent: string, maxWidth: int = 120, maxHeight: int = 1000): TermBuffer =
  ## Parse ANSI escape sequences into a styled TermBuffer
  ## This is the main entry point for parsing ANSI content
  ## 
  ## Args:
  ##   ansiContent: Text with ANSI escape sequences
  ##   maxWidth: Maximum buffer width (default 120)
  ##   maxHeight: Maximum buffer height for allocation (default 1000)
  ## 
  ## Returns:
  ##   TermBuffer with parsed, styled content
  
  var state = newAnsiParserState()
  var buffer = newTermBuffer(maxWidth, maxHeight)
  
  # Convert to runes for proper UTF-8 handling
  let runes = ansiContent.toRunes()
  
  var i = 0
  while i < runes.len:
    # Check for ANSI escape sequence (ESC is always single-byte ASCII)
    if runes[i] == Rune('\x1b') and i + 1 < runes.len and runes[i + 1] == Rune('['):
      # Need to convert back to byte position for parseAnsiSequence
      # This is a bit inefficient, but necessary for compatibility
      var bytePos = 0
      for j in 0 ..< i:
        bytePos += runes[j].toUTF8().len
      
      let (seqLen, cmd, params) = parseAnsiSequence(ansiContent, bytePos)
      
      if seqLen > 0:
        # Valid sequence parsed
        case cmd
        of 'm':  # SGR - Select Graphic Rendition
          applySgrParams(params, state.style)
        
        of 'H', 'f':  # Cursor Position (row;col)
          let row = if params.len > 0 and params[0] > 0: params[0] - 1 else: 0
          let col = if params.len > 1 and params[1] > 0: params[1] - 1 else: 0
          state.y = row
          state.x = col
        
        of 'A':  # Cursor Up
          let n = if params.len > 0: params[0] else: 1
          state.y = max(0, state.y - n)
        
        of 'B':  # Cursor Down
          let n = if params.len > 0: params[0] else: 1
          state.y = state.y + n
        
        of 'C':  # Cursor Forward
          let n = if params.len > 0: params[0] else: 1
          state.x = min(maxWidth - 1, state.x + n)
        
        of 'D':  # Cursor Back
          let n = if params.len > 0: params[0] else: 1
          state.x = max(0, state.x - n)
        
        of 'E':  # Cursor Next Line
          let n = if params.len > 0: params[0] else: 1
          state.y = state.y + n
          state.x = 0
        
        of 'F':  # Cursor Previous Line
          let n = if params.len > 0: params[0] else: 1
          state.y = max(0, state.y - n)
          state.x = 0
        
        of 'G':  # Cursor Horizontal Absolute
          let col = if params.len > 0 and params[0] > 0: params[0] - 1 else: 0
          state.x = col
        
        of 'J':  # Erase in Display
          discard  # Not implementing clearing for now
        
        of 'K':  # Erase in Line
          discard  # Not implementing clearing for now
        
        of 's':  # Save Cursor Position (DECSC)
          state.savedX = state.x
          state.savedY = state.y
        
        of 'u':  # Restore Cursor Position (DECRC)
          state.x = state.savedX
          state.y = state.savedY
        
        else:
          discard  # Ignore unsupported sequences
        
        # Skip the runes that were part of the sequence
        # Calculate how many runes the sequence consumed
        var runesInSeq = 0
        var tempByteCount = 0
        while tempByteCount < seqLen and i + runesInSeq < runes.len:
          tempByteCount += runes[i + runesInSeq].toUTF8().len
          inc runesInSeq
        i += runesInSeq
        continue
    
    # Handle regular characters
    let rune = runes[i]
    case rune.int
    of ord('\n'):
      state.y += 1
      state.x = 0
    of ord('\r'):
      state.x = 0
    of ord('\t'):
      # Tab to next 8-column boundary
      state.x = ((state.x div 8) + 1) * 8
      if state.x >= maxWidth:
        state.x = 0
        state.y += 1
    else:
      # Write character to buffer
      if state.x < maxWidth and state.y < maxHeight:
        let idx = state.y * buffer.width + state.x
        buffer.cells[idx] = Cell(ch: $rune, style: state.style)
        
        # Track maximum extents
        if state.x > state.maxX:
          state.maxX = state.x
        if state.y > state.maxY:
          state.maxY = state.y
      
      state.x += 1
      if state.x >= maxWidth:
        # Auto-wrap to next line
        state.x = 0
        state.y += 1
    
    inc i
  
  # Trim buffer to actual content size (add 1 for current line)
  buffer.height = min(maxHeight, state.maxY + 1)
  
  return buffer

# ================================================================
# UTILITY FUNCTIONS
# ================================================================

proc bufferToString*(buffer: TermBuffer, includeStyles: bool = false): string =
  ## Convert a TermBuffer back to a string
  ## If includeStyles is true, includes ANSI escape codes for styling
  result = ""
  
  var lastStyle = defaultStyle()
  
  for y in 0 ..< buffer.height:
    for x in 0 ..< buffer.width:
      let idx = y * buffer.width + x
      let cell = buffer.cells[idx]
      
      if includeStyles:
        # TODO: Generate ANSI codes if style changed
        # This would be useful for terminal emulator output
        discard
      
      result.add(cell.ch)
    
    if y < buffer.height - 1:
      result.add('\n')

proc stripAnsi*(text: string): string =
  ## Remove all ANSI escape sequences from text
  ## Useful for getting plain text length/content
  result = ""
  var i = 0
  
  while i < text.len:
    if text[i] == '\x1b' and i + 1 < text.len and text[i + 1] == '[':
      let (seqLen, _, _) = parseAnsiSequence(text, i)
      if seqLen > 0:
        i += seqLen
        continue
    
    result.add(text[i])
    inc i

proc convertBracketNotationToAnsi*(text: string): string =
  ## Convert user-friendly bracket notation [1;36m to actual ANSI escape sequences \x1b[1;36m
  ## This allows users to write ANSI art in markdown without needing actual ESC bytes
  ## 
  ## Examples:
  ##   [1;31m -> \x1b[1;31m (red bold text)
  ##   [0m    -> \x1b[0m    (reset)
  ##   [1;36m -> \x1b[1;36m (cyan bold)
  result = ""
  var i = 0
  
  while i < text.len:
    if text[i] == '[':
      # Look ahead to see if this is an ANSI code pattern
      # Pattern: [<digits and semicolons>m
      var j = i + 1
      var isAnsiCode = false
      
      # Check for valid ANSI code format
      while j < text.len:
        case text[j]
        of '0'..'9', ';', ':':
          inc j
        of 'A'..'Z', 'a'..'z':
          # Found command character - this is an ANSI code
          isAnsiCode = true
          inc j
          break
        else:
          # Not an ANSI code
          break
      
      if isAnsiCode and j > i + 1:
        # Convert [XXXm to \x1b[XXXm
        result.add('\x1b')
        result.add(text[i ..< j])
        i = j
      else:
        # Not an ANSI code, keep literal bracket
        result.add(text[i])
        inc i
    else:
      result.add(text[i])
      inc i

proc getAnsiTextDimensions*(text: string): tuple[width: int, height: int] =
  ## Get the dimensions of text containing ANSI sequences
  ## Returns (width, height) where width is the longest line
  result.width = 0
  result.height = 1
  
  var currentX = 0
  var i = 0
  
  while i < text.len:
    if text[i] == '\x1b' and i + 1 < text.len and text[i + 1] == '[':
      let (seqLen, _, _) = parseAnsiSequence(text, i)
      if seqLen > 0:
        i += seqLen
        continue
    
    case text[i]
    of '\n':
      result.height += 1
      currentX = 0
    of '\r':
      currentX = 0
    else:
      currentX += 1
      if currentX > result.width:
        result.width = currentX
    
    inc i
