import tables, streams, sequtils, strutils
import ../nimini/auto_bindings

when not defined(js) and not defined(emscripten):
  import os

# --- figlet_types ---
type
  LayoutMode* = enum
    FullWidth
    HorizontalFitting
    HorizontalSmushing
    VerticalFitting
    VerticalSmushing

  HorizontalSmushRule* = enum
    EqualCharacter      = 1
    Underscore          = 2
    Hierarchy           = 4
    OppositePair        = 8
    BigX                = 16
    Hardblank           = 32

  VerticalSmushRule* = enum
    EqualCharacterVert  = 256
    UnderscoreVert      = 512
    HierarchyVert       = 1024
    HorizontalLineVert  = 2048
    VerticalLineVert    = 4096

  PrintDirection* = enum
    LeftToRight = 0
    RightToLeft = 1

  FIGcharacter* = object
    lines*: seq[string]
    width*: int

  FIGfont* = object
    signature*: string
    hardblank*: char
    height*: int
    baseline*: int
    maxLength*: int
    oldLayout*: int
    commentLines*: int
    printDirection*: PrintDirection
    fullLayout*: int
    codetagCount*: int
    comments*: seq[string]
    chars*: Table[int, FIGcharacter]
    defaultHorizontalLayout*: LayoutMode
    defaultVerticalLayout*: LayoutMode
    horizontalSmushRules*: set[HorizontalSmushRule]
    verticalSmushRules*: set[VerticalSmushRule]

  FIGletError* = object of CatchableError

# --- figlet_parser ---
proc parseLayoutInfo(fullLayout: int): tuple[
  horizMode: LayoutMode,
  vertMode: LayoutMode,
  horizRules: set[HorizontalSmushRule],
  vertRules: set[VerticalSmushRule]
] =
  result.horizRules = {}
  result.vertRules = {}
  
  # Horizontal rules
  if (fullLayout and 1) != 0: result.horizRules.incl(EqualCharacter)
  if (fullLayout and 2) != 0: result.horizRules.incl(Underscore)
  if (fullLayout and 4) != 0: result.horizRules.incl(Hierarchy)
  if (fullLayout and 8) != 0: result.horizRules.incl(OppositePair)
  if (fullLayout and 16) != 0: result.horizRules.incl(BigX)
  if (fullLayout and 32) != 0: result.horizRules.incl(Hardblank)
  
  # Vertical rules
  if (fullLayout and 256) != 0: result.vertRules.incl(EqualCharacterVert)
  if (fullLayout and 512) != 0: result.vertRules.incl(UnderscoreVert)
  if (fullLayout and 1024) != 0: result.vertRules.incl(HierarchyVert)
  if (fullLayout and 2048) != 0: result.vertRules.incl(HorizontalLineVert)
  if (fullLayout and 4096) != 0: result.vertRules.incl(VerticalLineVert)
  
  # Horizontal layout mode
  if (fullLayout and 128) != 0:
    result.horizMode = if result.horizRules.len > 0: HorizontalSmushing else: HorizontalSmushing
  elif (fullLayout and 64) != 0:
    result.horizMode = HorizontalFitting
  else:
    result.horizMode = FullWidth
  
  # Vertical layout mode
  if (fullLayout and 16384) != 0:
    result.vertMode = if result.vertRules.len > 0: VerticalSmushing else: VerticalSmushing
  elif (fullLayout and 8192) != 0:
    result.vertMode = VerticalFitting
  else:
    result.vertMode = FullWidth

proc parseHeader(line: string): tuple[
  hardblank: char,
  height, baseline, maxLength, oldLayout, commentLines: int,
  printDirection: PrintDirection,
  fullLayout, codetagCount: int
] =
  if not line.startsWith("flf2a"):
    raise newException(FIGletError, "Invalid FIGfont signature")
  
  result.hardblank = line[5]
  let parts = line[6..^1].strip().split(Whitespace)
  
  if parts.len < 5:
    raise newException(FIGletError, "Invalid header format")
  
  result.height = parseInt(parts[0])
  result.baseline = parseInt(parts[1])
  result.maxLength = parseInt(parts[2])
  result.oldLayout = parseInt(parts[3])
  result.commentLines = parseInt(parts[4])
  
  result.printDirection = if parts.len > 5 and parseInt(parts[5]) == 1: RightToLeft else: LeftToRight
  result.fullLayout = if parts.len > 6: parseInt(parts[6]) else: result.oldLayout
  result.codetagCount = if parts.len > 7: parseInt(parts[7]) else: 0

proc parseCharacter(stream: Stream, height: int, hardblank: char): FIGcharacter =
  result.lines = newSeq[string](height)
  result.width = 0
  
  for i in 0..<height:
    var line = stream.readLine()
    if line.len == 0:
      raise newException(FIGletError, "Unexpected end of character data")
    
    # Find endmark (last char is the delimiter).
    # If the last line of the character uses a doubled delimiter ("@@"),
    # remove both delimiters; otherwise remove the single trailing delimiter.
    var endPos = line.len - 1
    let endChar = line[endPos]
    if i == height - 1 and endPos > 0 and line[endPos - 1] == endChar:
      # last line uses doubled delimiter -> remove two chars
      endPos = endPos - 1
    line = line[0..<endPos]
    
    # Replace hardblanks with spaces
    for j in 0..<line.len:
      if line[j] == hardblank:
        line[j] = ' '
    
    result.lines[i] = line
    if line.len > result.width:
      result.width = line.len

proc loadFIGfont*(stream: Stream): FIGfont =
  if stream.isNil:
    raise newException(FIGletError, "Invalid stream")
  
  # Parse header
  let headerLine = stream.readLine()
  let header = parseHeader(headerLine)
  
  result.signature = "flf2a"
  result.hardblank = header.hardblank
  result.height = header.height
  result.baseline = header.baseline
  result.maxLength = header.maxLength
  result.oldLayout = header.oldLayout
  result.commentLines = header.commentLines
  result.printDirection = header.printDirection
  result.fullLayout = header.fullLayout
  result.codetagCount = header.codetagCount
  
  # Parse layout info
  let layoutInfo = parseLayoutInfo(result.fullLayout)
  result.defaultHorizontalLayout = layoutInfo.horizMode
  result.defaultVerticalLayout = layoutInfo.vertMode
  result.horizontalSmushRules = layoutInfo.horizRules
  result.verticalSmushRules = layoutInfo.vertRules
  
  # Parse comments
  result.comments = newSeq[string](result.commentLines)
  for i in 0..<result.commentLines:
    result.comments[i] = stream.readLine()
  
  result.chars = initTable[int, FIGcharacter]()
  
  # Parse required characters (32-126, then 196, 214, 220, 228, 246, 252, 223)
  const requiredChars = [
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
    64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95,
    96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
    112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126,
    196, 214, 220, 228, 246, 252, 223
  ]
  
  for charCode in requiredChars:
    result.chars[charCode] = parseCharacter(stream, result.height, result.hardblank)
  
  # Parse code-tagged characters
  while not stream.atEnd():
    let line = stream.readLine().strip()
    if line.len == 0:
      continue
    
    # Parse character code
    let parts = line.split(Whitespace)
    if parts.len == 0:
      continue
    
    var charCode: int
    try:
      if parts[0].startsWith("0x") or parts[0].startsWith("0X"):
        charCode = parseHexInt(parts[0])
      elif parts[0].startsWith("0") and parts[0].len > 1:
        charCode = parseOctInt(parts[0])
      else:
        charCode = parseInt(parts[0])
    except:
      continue
    
    if charCode == -1:
      continue
    
    result.chars[charCode] = parseCharacter(stream, result.height, result.hardblank)

proc loadFIGfont*(filepath: string): FIGfont =
  var stream = newFileStream(filepath, fmRead)
  if stream.isNil:
    raise newException(FIGletError, "Cannot open file: " & filepath)
  
  defer: stream.close()
  result = loadFIGfont(stream)

# --- figlet_render ---
proc canSmushHorizontal(left, right: char, rules: set[HorizontalSmushRule], hardblank: char): tuple[can: bool, result: char] =
  if left == ' ': return (true, right)
  if right == ' ': return (true, left)
  
  if rules.len == 0:
    # No smushing rules specified -> do not smush
    return (false, left)
  
  # Equal character
  if EqualCharacter in rules and left == right:
    return (true, left)
  
  # Underscore
  if Underscore in rules:
    if left == '_' and right in "|/\\[]{}()<>":
      return (true, right)
    if right == '_' and left in "|/\\[]{}()<>":
      return (true, left)
  
  # Hierarchy
  if Hierarchy in rules:
    const hierarchy = "|/\\[]{}()<>"
    let leftIdx = hierarchy.find(left)
    let rightIdx = hierarchy.find(right)
    if leftIdx >= 0 and rightIdx >= 0:
      return (true, if leftIdx > rightIdx: left else: right)
  
  # Opposite pair
  if OppositePair in rules:
    const pairs = [('[', ']'), ('{', '}'), ('(', ')')]
    for pair in pairs:
      if (left == pair[0] and right == pair[1]) or (left == pair[1] and right == pair[0]):
        return (true, '|')
  
  # BigX
  if BigX in rules:
    if (left == '/' and right == '\\') or (left == '\\' and right == '/'):
      return (true, if left == '/': 'Y' else: 'X')
  
  # Hardblank (Note: hardblanks converted to spaces during parsing)
  if Hardblank in rules and left == ' ' and right == ' ':
    return (true, ' ')
  
  return (false, left)

proc smushAmount(left: FIGcharacter, right: FIGcharacter, rules: set[HorizontalSmushRule], hardblank: char): int =
  if left.lines.len == 0 or right.lines.len == 0:
    return 0
  
  var maxSmush = left.width
  
  for i in 0..<left.lines.len:
    let leftLine = left.lines[i]
    let rightLine = right.lines[i]
    
    var lineSmush = 0
    for j in countdown(leftLine.len - 1, 0):
      if leftLine[j] != ' ':
        let rightPos = (left.width - 1 - j)
        if rightPos < rightLine.len:
          let smush = canSmushHorizontal(leftLine[j], rightLine[rightPos], rules, hardblank)
          if smush.can:
            lineSmush = j + 1
          else:
            break
        break
    
    if lineSmush < maxSmush:
      maxSmush = lineSmush
  
  return left.width - maxSmush

proc renderLine(chars: seq[FIGcharacter], lineIdx: int, layout: LayoutMode, rules: set[HorizontalSmushRule], hardblank: char): string =
  if chars.len == 0:
    return ""
  
  result = ""
  
  case layout
  of FullWidth:
    for ch in chars:
      if lineIdx < ch.lines.len:
        result.add(ch.lines[lineIdx])
  
  of HorizontalFitting:
    result = if lineIdx < chars[0].lines.len: chars[0].lines[lineIdx] else: ""
    for i in 1..<chars.len:
      let ch = chars[i]
      if lineIdx < ch.lines.len:
        # Trim trailing spaces from result and leading spaces from ch
        result = result.strip(trailing = true, leading = false)
        let nextLine = ch.lines[lineIdx].strip(trailing = false, leading = true)
        result.add(nextLine)
  
  of HorizontalSmushing:
    result = if lineIdx < chars[0].lines.len: chars[0].lines[lineIdx] else: ""
    for i in 1..<chars.len:
      let ch = chars[i]
      if lineIdx < ch.lines.len:
        let chLine = ch.lines[lineIdx]
        let smush = smushAmount(chars[i-1], ch, rules, hardblank)
        let overlap = min(smush, result.len)

        # Merge overlapping characters safely (avoid negative slice ranges)
        if overlap > 0:
          let startPos = result.len - overlap
          var merged = ""
          for j in 0..<overlap:
            if startPos + j < result.len and j < chLine.len:
              let sm = canSmushHorizontal(result[startPos + j], chLine[j], rules, hardblank)
              merged.add(if sm.can: sm.result else: chLine[j])

          let leftSlice = if startPos > 0: result.substr(0, startPos) else: ""
          let rightTail = if overlap < chLine.len: chLine.substr(overlap, chLine.len - overlap) else: ""
          result = leftSlice & merged & rightTail
        else:
          result.add(chLine)
  
  else:
    discard

proc renderText*(font: FIGfont, text: string, layout: LayoutMode = FullWidth): seq[string] =
  var chars: seq[FIGcharacter] = @[]
  
  for ch in text:
    let code = ord(ch)
    if font.chars.hasKey(code):
      chars.add(font.chars[code])
    elif font.chars.hasKey(32):  # fallback to space
      chars.add(font.chars[32])
  
  if chars.len == 0:
    return @[]
  
  # Respect the caller's requested layout. Do not override `FullWidth` with the
  # font's default—caller asked for FullWidth (no smushing/fitting).
  let actualLayout = layout
  
  result = newSeq[string](font.height)
  for i in 0..<font.height:
    result[i] = renderLine(chars, i, actualLayout, font.horizontalSmushRules, font.hardblank)

# --- figlet_fonts ---
# NIMINI BINDINGS:
# Pattern 1 (Auto-exposed): isFontLoaded, clearCache
# Pattern 3 (Auto-exposed): listAvailableFonts (seq return)
# Manual wrappers: loadFont, parseFontFromString, render (use FIGfont custom type)

when defined(js) or defined(emscripten):
  # Web builds: fonts would need async loading
  type InternalCallback* = proc(content: string, error: string)
  
  proc loadFontAsync*(name: string, callback: InternalCallback) =
    # TODO: Implement async font loading via JavaScript
    callback("", "Font loading not yet implemented for web builds")
  
else:
  proc getFontPath*(name: string): string =
    result = "docs/figlets/" & name & ".flf"
    if not fileExists(result):
      result = "figlets/" & name & ".flf"

proc listAvailableFonts*(): seq[string] {.autoExpose: "figlet".} =
  when defined(js) or defined(emscripten):
    # Common figlet fonts available
    result = @["standard", "small", "big", "banner", "block", "bubble", 
               "digital", "ivrit", "lean", "mini", "script", "shadow", 
               "slant", "speed", "starwars", "stop", "straight"]
  else:
    for fontDir in ["docs/figlets", "figlets"]:
      if dirExists(fontDir):
        for file in walkFiles(fontDir / "*.flf"):
          result.add(file.splitFile.name)
        break

# --- public API ---
export LayoutMode, PrintDirection, FIGfont, FIGletError, listAvailableFonts

when defined(js) or defined(emscripten):
  export InternalCallback, loadFontAsync
else:
  export getFontPath

var fontCache = initTable[string, FIGfont]()

proc loadFont*(name: string): FIGfont =
  ## Load a figlet font by name (native only, returns cached if available)
  when not defined(js) and not defined(emscripten):
    let path = getFontPath(name)
    if fontCache.hasKey(path):
      return fontCache[path]
    result = loadFIGfont(path)
    fontCache[path] = result
  else:
    if fontCache.hasKey(name):
      return fontCache[name]
    raise newException(FIGletError, "Font not loaded: " & name & ". Use loadFontAsync first.")

proc parseFontFromString*(name: string, content: string): FIGfont =
  ## Parse a font from string content (for async-loaded fonts)
  if fontCache.hasKey(name):
    return fontCache[name]
  
  var stream = newStringStream(content)
  stream.setPosition(0)  # Ensure we're at the beginning
  defer: stream.close()
  
  result = loadFIGfont(stream)
  fontCache[name] = result

proc isFontLoaded*(name: string): bool {.autoExpose: "figlet".} =
  ## Check if a font is already loaded in cache
  when defined(js) or defined(emscripten):
    fontCache.hasKey(name)
  else:
    fontCache.hasKey(getFontPath(name)) or fontCache.hasKey(name)

proc render*(font: FIGfont, text: string, layout: LayoutMode = FullWidth): seq[string] =
  ## Render text with a loaded font
  renderText(font, text, layout)

proc clearCache*() {.autoExpose: "figlet".} =
  ## Clear the font cache
  fontCache.clear()
