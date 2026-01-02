import strutils, times, parseopt, os, tables, math, random, sequtils, strtabs, algorithm
import macros
import nimini
import src/params
import src/types  # Core runtime types
import src/charwidth  # Character display width utilities
import src/layers  # Layer system and buffer operations
import src/appstate  # Application state management
import lib/storie_types
import lib/audio_gen
import lib/storie_md          # Markdown parser (includes gEmbeddedFigletFonts)
import lib/section_manager    # Section navigation and management (includes nimini bindings)
import lib/layout             # Text layout utilities
import lib/figlet             # FIGlet font rendering (for parsing and rendering)
import lib/nimini_bridge      # Nimini API registration and bindings
import lib/tui_bindings       # TUI widget nimini bindings
import lib/ascii_art_bindings # ASCII art nimini bindings
import lib/dungeon_bindings   # Dungeon generator nimini bindings

when not defined(emscripten):
  import src/platform/terminal
  import std/httpclient
  import src/export_command  # Export command support

# These modules work directly with tstorie's core types (Layer, TermBuffer, Style, etc.)
# so they must be included to share the same namespace
include lib/events            # Event handling system
include lib/animation         # Animation helpers and easing
include lib/canvas            # Canvas navigation system
include lib/audio             # Audio system
include lib/tui               # TUI widget system (defines INPUT_* constants)
include lib/tui_editor

const version = "0.1.0"

# ================================================================
# INPUT CONSTANTS - Defined in lib/tui.nim
# ================================================================

const
  ModShift* = 0'u8
  ModAlt* = 1'u8
  ModCtrl* = 2'u8
  ModSuper* = 3'u8

# ================================================================
# INPUT EVENT TYPES (imported from src/types)
# ================================================================
# Types now defined in src/types.nim:
# - InputAction, MouseButton, InputEventKind, InputEvent
# - Color, Style, and color helpers
# - TerminalInputParser and related types

# ================================================================
# TERMINAL INPUT PARSER IMPLEMENTATION
# ================================================================

# ================================================================
# INPUT PARSING
# ================================================================

# newTerminalInputParser is now in src/types.nim

proc csiArg(a: int64): int = int(a and CSI_ARG_MASK)
proc csiArgHasMore(a: int64): bool = (a and CSI_ARG_FLAG_MORE) != 0
proc csiArgIsMissing(a: int64): bool = (a and CSI_ARG_MASK) == CSI_ARG_MISSING

proc csiArgOr(a: int64, def: int): int =
  if csiArgIsMissing(a): def else: csiArg(a)

proc csiArg(vt: TerminalInputParser, i: int, i1: int, default: int = 0): int =
  var index = 0
  var k = 0
  while index < vt.csi.argi and k < i:
    if vt.csi.args[index].csiArgHasMore():
      inc index
      continue
    inc index
    inc k

  if index + i1 < vt.csi.argi:
    let a = vt.csi.args[index + i1]
    if a.csiArgIsMissing():
      return default
    return csiArg(a)
  return default

proc csiArg(vt: TerminalInputParser, i: int, default: int = 0): int =
  return vt.csiArg(i, 0, default)

proc isIntermed(c: char): bool =
  return c.int >= 0x20 and c.int <= 0x2f

proc handleCsi(vt: var TerminalInputParser, command: char): seq[InputEvent] =
  result = @[]
  let leader = if vt.csi.leaderlen > 0: vt.csi.leader[0] else: '\0'
  let args = vt.csi.args
  let argcount = vt.csi.argi

  proc parseModsAndAction(vt: TerminalInputParser): (set[uint8], InputAction) =
    result = ({}, Press)
    let mods = vt.csiArg(1) - 1
    if mods >= 0:
      if (mods and 0x1) != 0:
        result[0].incl ModShift
      if (mods and 0x2) != 0:
        result[0].incl ModAlt
      if (mods and 0x4) != 0:
        result[0].incl ModCtrl
      if (mods and 0x8) != 0:
        result[0].incl ModSuper

    let action = vt.csiArg(1, 1, default = 1)
    case action
    of 1: result[1] = Press
    of 2: result[1] = Repeat
    of 3: result[1] = Release
    else: discard

  case command
  of 'u':
    let input = vt.csiArg(0)
    if input != 0:
      let (mods, action) = vt.parseModsAndAction()
      result.add InputEvent(kind: KeyEvent, keyCode: input, keyMods: mods, keyAction: action)

  of 'A':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_UP, keyMods: mods, keyAction: action)
  of 'B':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_DOWN, keyMods: mods, keyAction: action)
  of 'C':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_RIGHT, keyMods: mods, keyAction: action)
  of 'D':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_LEFT, keyMods: mods, keyAction: action)
  of 'F':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_END, keyMods: mods, keyAction: action)
  of 'H':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_HOME, keyMods: mods, keyAction: action)
  of 'P':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F1, keyMods: mods, keyAction: action)
  of 'Q':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F2, keyMods: mods, keyAction: action)
  of 'S':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F4, keyMods: mods, keyAction: action)
  of 'Z':
    var (mods, action) = vt.parseModsAndAction()
    mods.incl ModShift
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_TAB, keyMods: mods, keyAction: action)
  of '~':
    let (mods, action) = vt.parseModsAndAction()
    if argcount > 0:
      case args[0].int
      of 3: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_DELETE, keyMods: mods, keyAction: action)
      of 5: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_PAGE_UP, keyMods: mods, keyAction: action)
      of 6: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_PAGE_DOWN, keyMods: mods, keyAction: action)
      of 11: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F1, keyMods: mods, keyAction: action)
      of 12: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F2, keyMods: mods, keyAction: action)
      of 13: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F3, keyMods: mods, keyAction: action)
      of 14: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F4, keyMods: mods, keyAction: action)
      of 15: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F5, keyMods: mods, keyAction: action)
      of 17: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F6, keyMods: mods, keyAction: action)
      of 18: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F7, keyMods: mods, keyAction: action)
      of 19: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F8, keyMods: mods, keyAction: action)
      of 20: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F9, keyMods: mods, keyAction: action)
      of 21: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F10, keyMods: mods, keyAction: action)
      of 23: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F11, keyMods: mods, keyAction: action)
      of 24: result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F12, keyMods: mods, keyAction: action)
      else: discard

  of 'm', 'M':
    if argcount == 3:
      let codeAndMods = vt.csiArg(0)
      let buttonCode = codeAndMods and 0b11
      let mods = (codeAndMods shr 2) and 0b111
      let col = vt.csiArg(1) - 1
      let row = vt.csiArg(2) - 1
      let action = if command == 'M': Press else: Release
      let move = (codeAndMods and 0x20) != 0
      let scroll = (codeAndMods and 0x40) != 0

      let mouseButton: MouseButton = case buttonCode
      of 0: Left
      of 1: Middle
      of 2: Right
      else: Unknown

      var modifiers: set[uint8] = {}
      if (mods and 0x1) != 0:
        modifiers.incl ModShift
      if (mods and 0x2) != 0:
        modifiers.incl ModAlt
      if (mods and 0x4) != 0:
        modifiers.incl ModCtrl

      if move:
        result.add InputEvent(kind: MouseMoveEvent, moveX: col, moveY: row, moveMods: modifiers)
      elif scroll:
        let scrollBtn = if (codeAndMods and 0x1) == 0: ScrollUp else: ScrollDown
        result.add InputEvent(kind: MouseEvent, button: scrollBtn, mouseX: col, mouseY: row, mods: modifiers, action: Press)
      else:
        result.add InputEvent(kind: MouseEvent, button: mouseButton, mouseX: col, mouseY: row, mods: modifiers, action: action)
  else:
    discard

proc parseInput*(vt: var TerminalInputParser, text: openArray[char]): seq[InputEvent] =
  result = @[]
  var mods: set[uint8] = {}

  if vt.enableEscapeTimeout and vt.endedInEsc and (epochTime() - vt.escTimer) * 1000.0 >= vt.escapeTimeout.float:
    if vt.prevEsc:
      mods.incl ModAlt
    result.add InputEvent(kind: KeyEvent, keyCode: INPUT_ESCAPE, keyMods: mods, keyAction: Press)
    vt.inEsc = false
    vt.prevEsc = false
    vt.endedInEsc = false

  if text.len > 0:
    vt.endedInEsc = false

  var i = 0

  while i < text.len:
    defer: inc i
    var c1Allowed = false
    var c = text[i]

    if vt.inEscO:
      vt.inEscO = false
      case c
      of 'P':
        result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F1, keyMods: mods, keyAction: Press)
        continue
      of 'Q':
        result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F2, keyMods: mods, keyAction: Press)
        continue
      of 'R':
        result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F3, keyMods: mods, keyAction: Press)
        continue
      of 'S':
        result.add InputEvent(kind: KeyEvent, keyCode: INPUT_F4, keyMods: mods, keyAction: Press)
        continue
      else: discard

    vt.prevEsc = vt.inEsc

    case c
    of '\x1b':
      vt.intermedLen = 0
      vt.state = Normal
      vt.inEsc = true

      if i == text.len - 1:
        vt.endedInEsc = true
        vt.escTimer = epochTime()
        continue

      vt.endedInEsc = false
      continue

    of '\x7f':
      if vt.inEsc:
        mods.incl ModAlt
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: INPUT_BACKSPACE, keyMods: mods, keyAction: Press)
      mods = {}
      continue
    of '\x08':
      if vt.inEsc:
        mods.incl ModAlt
      mods.incl ModCtrl
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: INPUT_BACKSPACE, keyMods: mods, keyAction: Press)
      mods = {}
      continue
    of '\x09':
      if vt.inEsc:
        mods.incl ModAlt
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: INPUT_TAB, keyMods: mods, keyAction: Press)
      mods = {}
      continue
    of '\x0d', '\x0a':
      if vt.inEsc:
        mods.incl ModAlt
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: INPUT_ENTER, keyMods: mods, keyAction: Press)
      mods = {}
      continue

    of '\x01'..'\x07', '\x10'..'\x1a', '\x1c'..'\x1f':
      var key = c.int
      if c.int >= 1 and c.int <= 26:
        key = (c.int - 1 + 'a'.int)
      if vt.inEsc:
        mods.incl ModAlt
      mods.incl ModCtrl
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: key, keyMods: mods, keyAction: Press)
      mods = {}
      continue

    of '\x20':
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: INPUT_SPACE, keyMods: mods, keyAction: Press)
      mods = {}
      continue

    else:
      discard

    if vt.inEsc:
      if vt.intermedLen == 0 and c.int >= 0x40 and c.int < 0x60:
        c = (c.int + 0x40).char
        c1Allowed = true
        vt.inEsc = false
      else:
        vt.state = Normal

    if vt.state == CSILeader:
      if c.int >= 0x3c and c.int <= 0x3f:
        if vt.csi.leaderlen < CSI_LEADER_MAX - 1:
          vt.csi.leader[vt.csi.leaderlen] = c
          inc(vt.csi.leaderlen)
        continue
      vt.csi.leader[vt.csi.leaderlen] = 0.char
      vt.csi.argi = 0
      vt.csi.args[0] = CSI_ARG_MISSING
      vt.state = CSIArgs

    if vt.state == CSIArgs:
      if c >= '0' and c <= '9':
        if vt.csi.args[vt.csi.argi] == CSI_ARG_MISSING:
          vt.csi.args[vt.csi.argi] = 0
        vt.csi.args[vt.csi.argi] = vt.csi.args[vt.csi.argi] * 10
        inc(vt.csi.args[vt.csi.argi], c.int - '0'.int)
        continue
      if c == ':':
        vt.csi.args[vt.csi.argi] = vt.csi.args[vt.csi.argi] or CSI_ARG_FLAG_MORE
        c = ';'
      if c == ';':
        inc(vt.csi.argi)
        vt.csi.args[vt.csi.argi] = CSI_ARG_MISSING
        continue
      inc(vt.csi.argi)
      vt.intermedlen = 0
      vt.state = CSIIntermed

    if vt.state == CSIIntermed:
      if isIntermed(c):
        if vt.intermedlen < INTERMED_MAX - 1:
          vt.intermed[vt.intermedlen] = c
          inc(vt.intermedlen)
        continue
      elif c.int >= 0x40 and c.int <= 0x7e:
        vt.intermed[vt.intermedlen] = 0.char
        for event in vt.handleCsi(c):
          result.add event
      vt.state = Normal
      continue

    case vt.state
    of Normal:
      if vt.inEsc:
        if isIntermed(c):
          if vt.intermedLen < INTERMED_MAX - 1:
            vt.intermed[vt.intermedLen] = c
            inc(vt.intermedLen)
        elif c.int >= 0x30 and c.int < 0x7f:
          mods.incl ModAlt
          vt.inEsc = false
          result.add InputEvent(kind: KeyEvent, keyCode: c.int, keyMods: mods, keyAction: Press)
          mods = {}
        continue

      if c1Allowed and c.int >= 0x80 and c.int < 0xa0:
        if c.int == 0x9b:
          vt.csi.leaderlen = 0
          vt.state = CSILeader
      else:
        var k = i
        var n = i + vt.utf8Remaining
        while k < text.len:
          let ch = text[k]
          if ch.int <= 127:
            vt.inUtf8 = false
            if ch.int < 32 or ch.int == 127:
              break
            n = k + 1
            inc k
          else:
            if (ch.int and 0b11000000) == 0b10000000:
              vt.inUtf8 = false
              n = k + 1
            elif (ch.int and 0b11100000) == 0b11000000:
              vt.inUtf8 = true
              n = k + 2
            elif (ch.int and 0b11110000) == 0b11100000:
              vt.inUtf8 = true
              n = k + 3
            elif (ch.int and 0b11111000) == 0b11110000:
              vt.inUtf8 = true
              n = k + 4
            else:
              vt.inUtf8 = false
            inc k
        if k == i:
          inc k

        vt.utf8Remaining = n - k
        if k == text.len:
          if k < n:
            vt.utf8Buffer.add text[i..<k].join("")
            break
          if vt.utf8Buffer.len > 0:
            result.add InputEvent(kind: TextEvent, text: vt.utf8Buffer & text[i..<k].join(""))
            vt.utf8Buffer.setLen(0)
          else:
            result.add InputEvent(kind: TextEvent, text: text[i..<k].join(""))
          vt.inUtf8 = false
          vt.utf8Remaining = 0
        else:
          if vt.utf8Buffer.len > 0:
            result.add InputEvent(kind: TextEvent, text: vt.utf8Buffer & text[i..<k].join(""))
            vt.utf8Buffer.setLen(0)
          else:
            result.add InputEvent(kind: TextEvent, text: text[i..<k].join(""))
          vt.inUtf8 = false
          vt.utf8Remaining = 0
        i = k - 1

    else:
      discard

# ================================================================
# INTERNAL TYPES (not exposed to plugins)
# ================================================================

# ================================================================
# RENDERING TYPES (imported from src/types)
# ================================================================
# Types now defined in src/types.nim:
# - Cell, TermBuffer, Layer, AppState

when not defined(emscripten):
  var globalRunning {.global.} = true
  var globalTerminalState: TerminalState

# ================================================================
# MODULE LOADING TYPES (partially from src/types)
# ================================================================
# ContentSource defined in src/types.nim
# ModuleCache needs to be defined here because it depends on nimini's ref Env

type
  ModuleCacheImpl* = ref object
    modules*: Table[string, ref Env]  # moduleRef -> compiled runtime
    sourceCode*: Table[string, string]   # moduleRef -> source code
    
var globalModuleCache* = ModuleCacheImpl(
  modules: initTable[string, ref Env](),
  sourceCode: initTable[string, string]()
)

proc fetchGistFile*(gistId: string, filename: string): string =
  ## Fetch a file from a GitHub gist
  ## Format: gistId is the raw gist ID, filename is the file within the gist
  when defined(emscripten):
    # In WASM, this will be populated by JavaScript via emLoadGistCode
    # Return empty string to signal that async fetch is needed
    return ""
  else:
    let client = newHttpClient()
    # Use raw githubusercontent URL for direct file access
    let url = "https://gist.githubusercontent.com/raw/" & gistId & "/" & filename
    try:
      return client.getContent(url)
    except:
      raise newException(IOError, "Failed to fetch gist: " & gistId & "/" & filename)

proc parseGistReference*(moduleRef: string): tuple[gistId: string, filename: string, isGist: bool] =
  ## Parse a module reference into its components
  ## Formats:
  ##   "gist:abc123/canvas.nim" -> (abc123, canvas.nim, true)
  ##   "lib/utils.nim" -> ("", lib/utils.nim, false)
  if moduleRef.startsWith("gist:"):
    let parts = moduleRef[5..^1].split('/', maxsplit=1)
    if parts.len != 2:
      raise newException(ValueError, "Invalid gist format. Use: gist:ID/file.nim")
    return (parts[0], parts[1], true)
  else:
    return ("", moduleRef, false)

# ================================================================
# CONTENT SOURCE TYPES (imported from src/types)
# ================================================================
# Types now defined in src/types.nim:
# - ContentSource enum

proc parseContentReference*(contentRef: string): tuple[source: ContentSource, id: string] =
  ## Parse a content reference into its source type and identifier
  ## Formats:
  ##   "gist:abc123" -> (csGist, "abc123")
  ##   "demo:clock" -> (csDemo, "clock")
  ##   "file:path/to/file.md" -> (csFile, "path/to/file.md")
  ##   "https://gist.github.com/user/abc123" -> (csGist, "abc123")
  ##   "abc123" (if looks like gist ID) -> (csGist, "abc123")
  ##   "clock.md" (default) -> (csDemo, "clock")
  
  if contentRef.len == 0:
    return (csNone, "")
  
  # Check for explicit prefix
  if contentRef.startsWith("gist:"):
    return (csGist, contentRef[5..^1])
  elif contentRef.startsWith("demo:"):
    return (csDemo, contentRef[5..^1])
  elif contentRef.startsWith("file:"):
    return (csFile, contentRef[5..^1])
  
  # Check for full GitHub gist URL
  if "gist.github.com/" in contentRef:
    let parts = contentRef.split('/')
    for i, part in parts:
      if part == "gist.github.com" and i + 2 < parts.len:
        # Could be gist.github.com/user/id or gist.github.com/id
        let potentialId = parts[i + 2]
        if potentialId.len > 0:
          return (csGist, potentialId)
  
  # Check if it looks like a gist ID (32 hex chars)
  if contentRef.len == 32:
    var isHex = true
    for c in contentRef:
      if c notin {'0'..'9', 'a'..'f', 'A'..'F'}:
        isHex = false
        break
    if isHex:
      return (csGist, contentRef)
  
  # Check if it's a file path
  if fileExists(contentRef):
    return (csFile, contentRef)
  
  # Default to demo
  return (csDemo, contentRef)

proc loadContentFromSource*(contentRef: string): string =
  ## Load markdown content from various sources
  let (source, id) = parseContentReference(contentRef)
  
  case source
  of csGist:
    # Fetch gist and find first .md file
    when not defined(emscripten):
      let client = newHttpClient()
      let apiUrl = "https://api.github.com/gists/" & id
      try:
        let jsonStr = client.getContent(apiUrl)
        # Simple JSON parsing - look for first .md file
        # Format: "filename.md":{"content":"..."}
        let mdStart = jsonStr.find(".md")
        if mdStart < 0:
          raise newException(IOError, "No .md file found in gist " & id)
        
        # Find the content field
        let contentStart = jsonStr.find("\"content\":", mdStart)
        if contentStart < 0:
          raise newException(IOError, "Could not parse gist content")
        
        # Extract content (simplified - doesn't handle all edge cases)
        let valueStart = jsonStr.find("\"", contentStart + 10) + 1
        var valueEnd = valueStart
        var escaped = false
        while valueEnd < jsonStr.len:
          let c = jsonStr[valueEnd]
          if escaped:
            escaped = false
          elif c == '\\':
            escaped = true
          elif c == '"':
            break
          inc valueEnd
        
        let content = jsonStr[valueStart..<valueEnd]
        # Unescape basic sequences
        return content.multiReplace([("\\n", "\n"), ("\\t", "\t"), ("\\\"", "\""), ("\\\\", "\\")])
      except:
        raise newException(IOError, "Failed to fetch gist: " & id)
    else:
      raise newException(IOError, "Gist loading not supported in WASM CLI mode")
  
  of csDemo:
    # Load from demos/ directory
    var demoPath = id
    if not demoPath.endsWith(".md"):
      demoPath.add(".md")
    
    # Try multiple paths
    let paths = [
      "demos/" & demoPath,
      "docs/demos/" & demoPath,
      "../demos/" & demoPath,
      demoPath
    ]
    
    for path in paths:
      if fileExists(path):
        return readFile(path)
    
    raise newException(IOError, "Demo not found: " & demoPath)
  
  of csFile:
    if not fileExists(id):
      raise newException(IOError, "File not found: " & id)
    return readFile(id)
  
  of csNone:
    return ""

proc requireModule*(moduleRef: string, env: ref Env = nil): ref Env =
  ## Load and compile a .nim module from a gist or local file
  ## Returns a ref Env with the module's exported functions and variables
  ## 
  ## Format examples:
  ##   requireModule("gist:abc123def456/canvas.nim")
  ##   requireModule("lib/utils.nim")
  
  # Check cache first
  if globalModuleCache.modules.hasKey(moduleRef):
    return globalModuleCache.modules[moduleRef]
  
  var sourceCode: string
  let (gistId, filename, isGist) = parseGistReference(moduleRef)
  
  if isGist:
    # Fetch from gist
    sourceCode = fetchGistFile(gistId, filename)
    
    when defined(emscripten):
      # In WASM, empty string means we need JS to fetch it
      if sourceCode == "":
        # Check if code was loaded by JS
        if globalModuleCache.sourceCode.hasKey(moduleRef):
          sourceCode = globalModuleCache.sourceCode[moduleRef]
        else:
          # Signal that async fetch is needed
          raise newException(IOError, "Module not yet loaded: " & moduleRef)
  else:
    # Load from local file
    if not fileExists(filename):
      raise newException(IOError, "Module file not found: " & filename)
    sourceCode = readFile(filename)
  
  # Compile using nimini
  try:
    let program = compileSource(sourceCode)
    
    # Create runtime environment for this module
    var moduleEnv = newEnv()
    
    # If a parent environment was provided, link it
    if env != nil:
      moduleEnv.parent = env
    
    # Execute the module to populate its exports
    execProgram(program, moduleEnv)
    
    # Cache the compiled module
    globalModuleCache.modules[moduleRef] = moduleEnv
    globalModuleCache.sourceCode[moduleRef] = sourceCode
    
    return moduleEnv
    
  except Exception as e:
    raise newException(ValueError, "Failed to compile module " & moduleRef & ": " & e.msg)

proc loadGistCode*(moduleRef: string, code: string) =
  ## Called by JavaScript in WASM builds after fetching gist content
  ## Stores the code for later compilation
  globalModuleCache.sourceCode[moduleRef] = code

proc clearModuleCache*() =
  ## Clear all cached modules (useful for development/testing)
  globalModuleCache.modules.clear()
  globalModuleCache.sourceCode.clear()

proc listCachedModules*(): seq[string] =
  ## Get list of all cached module references
  result = @[]
  for key in globalModuleCache.modules.keys:
    result.add(key)

# ================================================================
# NIMINI BRIDGE - Module loading and runtime
# ================================================================

# Buffer operations and layer management now imported from src/layers
# API registration and helper templates now in lib/nimini_bridge.nim

# ================================================================
# INDEX.NIM INTEGRATION - Types and Globals
# ================================================================

type
  NiminiContext = ref object
    env: ref Env
  
  GlobalHandler* = object
    name*: string
    callback*: Value  # Nimini function/closure
    priority*: int    # Lower = executes first (default 0)
  
  StorieContext = ref object
    codeBlocks: seq[CodeBlock]
    niminiContext: NiminiContext
    frontMatter: FrontMatter  # Front matter from markdown
    styleSheet: StyleSheet    # Style configurations from front matter
    themeBackground: tuple[r, g, b: uint8]  # Theme's background color for terminal
    minWidth: int  # Minimum required terminal width (0 = no requirement)
    minHeight: int  # Minimum required terminal height (0 = no requirement)
    # Pre-compiled layer references
    bgLayer: Layer
    fgLayer: Layer
    # Section management
    sectionMgr: SectionManager   # Section manager handles all section state
    # Global event handlers
    globalRenderHandlers*: seq[GlobalHandler]
    globalUpdateHandlers*: seq[GlobalHandler]
    globalInputHandlers*: seq[GlobalHandler]

# Global references to layers (set in initStorieContext)
var gDefaultLayer: Layer  # Single default layer (layer 0)
var gTextStyle, gBorderStyle, gInfoStyle: Style
var gAppState: AppState  # Global reference to app state for state accessors

# Global TUI widget manager and widget registry
var gWidgetManager: WidgetManager
var gWidgetRegistry = initTable[string, Widget]()
var gLastClickedWidget: string = ""  # Track last clicked widget for polling

# Forward declaration for functions that will be defined later
var storieCtx: StorieContext

# Random number generator - consistent across WASM and native
var globalRng: Rand

proc initGlobalRng*() =
  ## Initialize the global random number generator with a seed
  when defined(emscripten):
    # For WASM, use a fixed seed or timestamp if available
    globalRng = initRand(123456)
  else:
    # For native, use system entropy
    globalRng = initRand()

# Global cache for loaded figlet fonts
var gFigletFonts = initTable[string, FIGfont]()

# Note: registerTstorieApis is now defined in lib/nimini_bridge.nim
# The bridge module handles all API registrations for nimini-interpreted code

var globalRuntimeEnv*: ref Env = nil

proc initGlobalRuntime*(state: AppState) =
  ## Initialize the global nimini runtime environment with tstorie APIs
  if globalRuntimeEnv == nil:
    globalRuntimeEnv = newEnv()
    registerTstorieApis(globalRuntimeEnv, state)

proc require*(moduleRef: string, state: AppState): ref Env =
  ## Load a Nim module at runtime from a gist or local file
  ## Usage: let canvas = require("gist:abc123/canvas.nim", state)
  ##        let utils = require("lib/utils.nim", state)
  
  if globalRuntimeEnv == nil:
    initGlobalRuntime(state)
  
  try:
    return requireModule(moduleRef, globalRuntimeEnv)
  except Exception:
    let e = getCurrentException()
    echo "Error loading module '", moduleRef, "': ", e.msg
    raise e

# ================================================================
# COLOR UTILITIES - Now in src/types.nim
# ================================================================
# toAnsi256 and toAnsi8 functions moved to src/types.nim

# ================================================================
# TERMINAL SETUP
# ================================================================

proc detectColorSupport(): int =
  when defined(emscripten):
    return 16777216
  else:
    let colorterm = getEnv("COLORTERM")
    if colorterm in ["truecolor", "24bit"]:
      return 16777216
    let term = getEnv("TERM")
    if "256color" in term:
      return 256
    if term in ["xterm", "screen", "linux"]:
      return 8
    return 0

proc getInputEvent*(state: AppState): seq[InputEvent] =
  when defined(emscripten):
    return @[]
  else:
    var buffer: array[256, char]
    let bytesRead = readInputRaw(buffer)
    if bytesRead > 0:
      return state.inputParser.parseInput(buffer.toOpenArray(0, bytesRead - 1))
    return @[]

# ================================================================
# BUFFER AND LAYER OPERATIONS - Now imported from src/layers
# ================================================================
# Buffer operations (newTermBuffer, write, fillRect, clear, etc.)
# Layer management (addLayer, getLayer, removeLayer, resizeLayers, compositeLayers)
# Display rendering (display, compositeBufferOnto)
# All these functions are now in src/layers.nim

# ================================================================
# FPS CONTROL - Now in src/appstate.nim
# ================================================================
# setTargetFps, updateFpsCounter, getFps, getFrameCount, getTotalTime moved to src/appstate

# ================================================================
# USER CALLBACKS
# ================================================================

# Global markdown file path (can be set via CLI or from user files)
var gMarkdownFile*: string = "index.md"
var gWaitingForGist*: bool = false
var gShowingDimensionWarning*: bool = false  # Flag to skip layer compositing

# ================================================================
# HELPER FUNCTIONS FOR INDEX.NIM (used by both native and WASM)
# ================================================================

# Helper to convert Value to int (handles both int and float values)
proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  of vkString:
    try:
      return parseInt(v.s)
    except:
      return 0
  of vkBool: return if v.b: 1 else: 0
  else: return 0

# Helper to convert Value to bool
proc valueToBool(v: Value): bool =
  case v.kind
  of vkBool: return v.b
  of vkInt: return v.i != 0
  of vkFloat: return v.f != 0.0
  else: return false

# ================================================================
# PLATFORM-SPECIFIC INCLUDES
# ================================================================

when not defined(emscripten):
  var onInit*: proc(state: AppState) = nil
  var onUpdate*: proc(state: AppState, dt: float) = nil
  var onRender*: proc(state: AppState) = nil
  var onShutdown*: proc(state: AppState) = nil
  var onInput*: proc(state: AppState, event: InputEvent): bool = nil
  
  # Directly include index.nim
  include "index"
  
  proc callOnSetup(state: AppState) =
    if not onInit.isNil:
      onInit(state)
  
  proc callOnFrame(state: AppState, dt: float) =
    if not onUpdate.isNil:
      onUpdate(state, dt)
  
  proc callOnDraw(state: AppState) =
    if not onRender.isNil:
      onRender(state)
  
  proc callOnShutdown(state: AppState) =
    if not onShutdown.isNil:
      onShutdown(state)
  
  proc callOnInput(state: AppState, event: InputEvent): bool =
    if not onInput.isNil:
      return onInput(state, event)
    return false

# ================================================================
# WEB EXPORTS
# ================================================================

when defined(emscripten):
  var globalState: AppState
  var lastRenderExecutedCount*: int = -1
  var lastError*: string = ""
  var globalMinWidth*: int = 0  # Minimum required width (0 = no requirement)
  var globalMinHeight*: int = 0  # Minimum required height (0 = no requirement)
  
  # Store URL params locally until runtime is initialized
  var wasmPendingParams: seq[(string, string)] = @[]
  var gEmSetUrlParamCalls: int = 0
  var gFlushWasmParamsCalls: int = 0
  
  # For WASM builds, include index.nim directly
  var onInit*: proc(state: AppState) = nil
  var onUpdate*: proc(state: AppState, dt: float) = nil
  var onRender*: proc(state: AppState) = nil
  var onShutdown*: proc(state: AppState) = nil
  var onInput*: proc(state: AppState, event: InputEvent): bool = nil
  
  # Directly include index.nim
  include "index"
  
  # Define callback wrapper procs that call the user-defined callbacks
  proc userInit(state: AppState) =
    if not onInit.isNil:
      onInit(state)

  proc userUpdate(state: AppState, dt: float) =
    if not onUpdate.isNil:
      onUpdate(state, dt)

  proc userRender(state: AppState) =
    if not onRender.isNil:
      onRender(state)
  
  # Direct render caller for WASM
  proc renderStorie(state: AppState) =
    # Call the render logic from index.nim directly
    if storieCtx.isNil:
      return
    
    # Check if we have any render blocks
    var hasRenderBlocks = false
    var renderBlockCount = 0
    for codeBlock in storieCtx.codeBlocks:
      if codeBlock.lifecycle == "render":
        hasRenderBlocks = true
        renderBlockCount += 1
    
    if not hasRenderBlocks:
      return
    
    # Execute render code blocks - they write to layers
    var executedCount = 0
    for codeBlock in storieCtx.codeBlocks:
      if codeBlock.lifecycle == "render":
        let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
        if success:
          executedCount += 1
    
    lastRenderExecutedCount = executedCount

  proc userInput(state: AppState, event: InputEvent): bool =
    if not onInput.isNil:
      return onInput(state, event)
    return false

  proc userShutdown(state: AppState) =
    if not onShutdown.isNil:
      onShutdown(state)
  
  proc flushWasmParams() =
    ## Flush pending WASM params to the nimini runtime
    gFlushWasmParamsCalls.inc
    
    if runtimeEnv.isNil:
      return
    
    # Store debug info about execution
    defineVar(runtimeEnv, "_emset_calls", valString($gEmSetUrlParamCalls))
    defineVar(runtimeEnv, "_flush_calls", valString($gFlushWasmParamsCalls))
    defineVar(runtimeEnv, "_flush_count", valString($wasmPendingParams.len))
    
    if wasmPendingParams.len == 0:
      defineVar(runtimeEnv, "_flush_status", valString("empty_array"))
      return
    
    for (name, value) in wasmPendingParams:
      setParam(name, value)
      # Also set a debug flag directly in runtime to confirm flushing worked
      defineVar(runtimeEnv, "_wasm_flushed_" & name, valString(value))
    
    defineVar(runtimeEnv, "_flush_status", valString("flushed_" & $wasmPendingParams.len))
  
  proc emInit(width, height: int) {.exportc.} =
    globalState = newAppState(width, height)
    
    # URL parameters are parsed in JavaScript (parseAndStoreUrlParams in index.html)
    # and stored before this function is called
    
    # Call initStorieContext directly (callback system doesn't work in WASM)
    initStorieContext(globalState)
    
    # Flush any URL params that were set before initialization
    flushWasmParams()
    
    # Apply theme parameter if present (will be applied in initStorieContext)
    # Theme parameter is checked after markdown loads in index.nim
  
  proc checkAndRenderDimensionWarning(): bool =
    ## Check if dimensions meet requirements and render warning if not.
    ## Returns true if dimensions are OK, false if too small.
    
    # Check if we have requirements (use storieCtx if available, otherwise globals)
    var minW, minH: int
    if not storieCtx.isNil:
      minW = storieCtx.minWidth
      minH = storieCtx.minHeight
    else:
      minW = globalMinWidth
      minH = globalMinHeight
    
    # DEBUG: Always show values in top-left corner
    var debugStyle = defaultStyle()
    debugStyle.fg = rgb(255'u8, 100'u8, 100'u8)
    debugStyle.bold = true
    let debugMsg = "Check: " & $minW & "x" & $minH & " vs " & $globalState.termWidth & "x" & $globalState.termHeight
    globalState.currentBuffer.writeText(1, 1, debugMsg, debugStyle)
    
    if minW <= 0 and minH <= 0:
      gShowingDimensionWarning = false
      return true  # No minimum requirements
    
    let needsWidth = minW > 0 and globalState.termWidth < minW
    let needsHeight = minH > 0 and globalState.termHeight < minH
    
    if not needsWidth and not needsHeight:
      gShowingDimensionWarning = false
      return true  # Dimensions are sufficient
    
    # Set flag to prevent layer compositing
    gShowingDimensionWarning = true
    
    # Clear screen and render centered warning message
    globalState.currentBuffer.clear((0'u8, 0'u8, 0'u8))
    
    # Build the message lines with current dimensions for debugging
    let reqWidth = if minW > 0: minW else: globalState.termWidth
    let reqHeight = if minH > 0: minH else: globalState.termHeight
    
    let line1 = $reqWidth & " x " & $reqHeight & " dimensions required."
    let line2 = "Current: " & $globalState.termWidth & " x " & $globalState.termHeight
    let line3 = "Resize browser window to continue."
    
    # Calculate centering
    let centerY = globalState.termHeight div 2
    
    # Render lines centered
    var warnStyle = defaultStyle()
    warnStyle.fg = yellow()
    warnStyle.bold = true
    
    let line1X = (globalState.termWidth - line1.len) div 2
    let line1Y = centerY
    if line1Y >= 0 and line1Y < globalState.termHeight:
      globalState.currentBuffer.writeText(line1X, line1Y, line1, warnStyle)
    
    let line2X = (globalState.termWidth - line2.len) div 2
    let line2Y = centerY + 1
    if line2Y >= 0 and line2Y < globalState.termHeight:
      globalState.currentBuffer.writeText(line2X, line2Y, line2, warnStyle)
    
    let line3X = (globalState.termWidth - line3.len) div 2
    let line3Y = centerY + 2
    if line3Y >= 0 and line3Y < globalState.termHeight:
      globalState.currentBuffer.writeText(line3X, line3Y, line3, warnStyle)
    
    return false
  
  proc emUpdate(deltaMs: float) {.exportc.} =
    let dt = deltaMs / 1000.0
    globalState.totalTime += dt
    globalState.frameCount += 1
    
    if globalState.totalTime - globalState.lastFpsUpdate >= 0.5:
      globalState.fps = 1.0 / dt
      globalState.lastFpsUpdate = globalState.totalTime
    
    # DEBUG: Write something to see if emUpdate is running
    var testStyle = defaultStyle()
    testStyle.fg = rgb(255'u8, 0'u8, 255'u8)
    testStyle.bold = true
    globalState.currentBuffer.writeText(1, 0, "emUpdate running!", testStyle)
    
    # Check if dimensions meet requirements and render warning if not
    if not checkAndRenderDimensionWarning():
      # Dimensions insufficient, warning already rendered
      # Skip normal rendering (no need to composite, warning is in currentBuffer)
      return
    
    # Call update directly
    if not storieCtx.isNil:
      for codeBlock in storieCtx.codeBlocks:
        if codeBlock.lifecycle == "update":
          discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
    
    # Note: Don't clear buffer here - compositeLayers will do it with theme background
    
    # Clear layer buffers each frame
    if not storieCtx.isNil:
      if not storieCtx.bgLayer.isNil:
        storieCtx.bgLayer.buffer.clearTransparent()
      if not storieCtx.fgLayer.isNil:
        storieCtx.fgLayer.buffer.clearTransparent()
    
    # Call render - this writes to layers
    renderStorie(globalState)

    # Composite layers onto currentBuffer (this will fill with theme background first)
    # Only composite if not showing dimension warning
    if not gShowingDimensionWarning:
      compositeLayers(globalState)

    # Optional: Show minimal debug info at bottom (can be removed)
    when defined(emscripten):
      if lastError.len > 0:
        let hudY = globalState.termHeight - 1
        var errStyle = defaultStyle()
        errStyle.fg = red()
        errStyle.bold = true
        globalState.currentBuffer.writeText(2, hudY, "Error: " & lastError, errStyle)

      if lastError.len > 0:
        var errStyle = defaultStyle()
        errStyle.fg = rgb(255'u8, 255'u8, 0'u8)  # Bright yellow
        errStyle.bg = black()
        errStyle.bold = true
        # Show error on multiple lines if needed
        var yPos = 8
        var remaining = lastError
        while remaining.len > 0:
          let lineLen = min(globalState.termWidth - 8, remaining.len)
          globalState.currentBuffer.writeText(4, yPos, "ERR: " & remaining[0 ..< lineLen], errStyle)
          remaining = if remaining.len > lineLen: remaining[lineLen .. ^1] else: ""
          yPos += 1
          if yPos >= globalState.termHeight - 1: break
  
  proc emResize(width, height: int) {.exportc.} =
    globalState.termWidth = width
    globalState.termHeight = height
    globalState.currentBuffer = newTermBuffer(width, height)
    globalState.previousBuffer = newTermBuffer(width, height)
    resizeLayers(globalState, width, height)
    
    # Check dimensions and render warning if needed
    discard checkAndRenderDimensionWarning()
  
  # Thread-local storage for cell character to ensure cstring stability
  var cellCharBuffer {.threadvar.}: string
  
  proc emGetCell(x, y: int): cstring {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      cellCharBuffer = globalState.currentBuffer.cells[idx].ch
      return cstring(cellCharBuffer)
    return cstring("")
  
  proc emGetCellFgR(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.fg.r.int
    return 255
  
  proc emGetCellFgG(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.fg.g.int
    return 255
  
  proc emGetCellFgB(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.fg.b.int
    return 255
  
  proc emGetCellBgR(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.bg.r.int
    return 0
  
  proc emGetCellBgG(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.bg.g.int
    return 0
  
  proc emGetCellBgB(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.bg.b.int
    return 0
  
  proc emGetCellBold(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return if globalState.currentBuffer.cells[idx].style.bold: 1 else: 0
    return 0
  
  proc emGetCellItalic(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return if globalState.currentBuffer.cells[idx].style.italic: 1 else: 0
    return 0
  
  proc emGetCellUnderline(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return if globalState.currentBuffer.cells[idx].style.underline: 1 else: 0
    return 0
  
  proc emGetCellWidth(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      let ch = globalState.currentBuffer.cells[idx].ch
      if ch.len > 0:
        return getCharDisplayWidth(ch)
    return 1
  
  proc emHandleKeyPress(keyCode: int, shift, alt, ctrl: int) {.exportc.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    let event = InputEvent(kind: KeyEvent, keyCode: keyCode, keyMods: mods, keyAction: Press)
    # Call inputHandler directly (defined in index.nim via include)
    discard inputHandler(globalState, event)
  
  proc emHandleTextInput(text: cstring) {.exportc.} =
    let event = InputEvent(kind: TextEvent, text: $text)
    # Call inputHandler directly (defined in index.nim via include)
    discard inputHandler(globalState, event)
  
  proc emHandleMouseClick(x, y, button, shift, alt, ctrl: int) {.exportc.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    let mouseButton = case button
      of 0: Left
      of 1: Middle
      of 2: Right
      else: Unknown
    
    let event = InputEvent(kind: MouseEvent, button: mouseButton, mouseX: x, mouseY: y, mods: mods, action: Press)
    # Call inputHandler directly (defined in index.nim via include)
    discard inputHandler(globalState, event)
  
  proc emHandleMouseRelease(x, y, button, shift, alt, ctrl: int) {.exportc.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    let mouseButton = case button
      of 0: Left
      of 1: Middle
      of 2: Right
      else: Unknown
    
    let event = InputEvent(kind: MouseEvent, button: mouseButton, mouseX: x, mouseY: y, mods: mods, action: Release)
    # Call inputHandler directly (defined in index.nim via include)
    discard inputHandler(globalState, event)
  
  proc emHandleMouseMove(x, y: int) {.exportc.} =
    globalState.lastMouseX = x
    globalState.lastMouseY = y
    let event = InputEvent(kind: MouseMoveEvent, moveX: x, moveY: y, moveMods: {})
    # Call inputHandler directly (defined in index.nim via include)
    discard inputHandler(globalState, event)
  
  proc emSetWaitingForGist() {.exportc.} =
    ## Set flag to wait for gist content instead of loading index.md
    gWaitingForGist = true
    # Ensure storieCtx exists (will be properly initialized later)
    if storieCtx.isNil:
      storieCtx = StorieContext()
  
  # URL parameters are now parsed directly in Nim via parseUrlParams()
  # No JS bridge needed for parameter access
  
  proc emLoadGistCode(moduleRef: cstring, code: cstring) {.exportc.} =
    ## Called by JavaScript after fetching a gist file
    ## Stores the code for later compilation by requireModule
    try:
      if moduleRef.isNil or code.isNil:
        lastError = "moduleRef or code is nil"
        return
      
      let modRef = $moduleRef
      let sourceCode = $code
      loadGistCode(modRef, sourceCode)
      
    except Exception:
      let e = getCurrentException()
      lastError = "Failed to load gist code: " & e.msg
  
  proc emRequireModule(moduleRef: cstring): cstring {.exportc.} =
    ## Load a module at runtime
    ## Returns "loaded" if successful, "fetch_needed" if JS needs to fetch gist
    ## Returns error message if compilation fails
    try:
      if moduleRef.isNil:
        return "error: moduleRef is nil".cstring
      
      let modRef = $moduleRef
      
      # Try to load the module
      discard require(modRef, globalState)
      return "loaded".cstring
      
    except IOError:
      let e = getCurrentException()
      # Module not yet loaded - signal JS to fetch it
      if "not yet loaded" in e.msg:
        return "fetch_needed".cstring
      else:
        return ("error: " & e.msg).cstring
    except Exception:
      let e = getCurrentException()
      return ("error: " & e.msg).cstring
  
  proc emLoadMarkdownFromJS(markdownContent: cstring) {.exportc.} =
    ## Load markdown content from JavaScript and reinitialize the storie context
    try:
      # Convert cstring to string safely
      if markdownContent.isNil:
        lastError = "markdownContent is nil"
        return
      
      let content = $markdownContent
      
      # Ensure content is valid
      if content.len == 0:
        lastError = "content is empty"
        return
      
      # Parse the markdown document (includes sections)
      let doc = parseMarkdownDocument(content)
      
      # Check if we got any blocks
      if doc.codeBlocks.len == 0:
        lastError = "no blocks parsed from " & $content.len & " bytes"
        return
      
      # Update the storie context with new code blocks and sections
      if not storieCtx.isNil and not storieCtx.niminiContext.isNil:
        gWaitingForGist = false
        
        # Flush WASM params before executing init blocks
        flushWasmParams()
        
        # Replace the code blocks and sections
        storieCtx.codeBlocks = doc.codeBlocks
        storieCtx.sectionMgr = newSectionManager(doc.sections)
        storieCtx.frontMatter = doc.frontMatter
        storieCtx.styleSheet = doc.styleSheet

        # Parse minWidth and minHeight from front matter (WASM fix)
        storieCtx.minWidth = 0
        storieCtx.minHeight = 0
        if storieCtx.frontMatter.hasKey("minWidth"):
          try:
            storieCtx.minWidth = parseInt(storieCtx.frontMatter["minWidth"])
            globalMinWidth = storieCtx.minWidth
          except:
            discard
        if storieCtx.frontMatter.hasKey("minHeight"):
          try:
            storieCtx.minHeight = parseInt(storieCtx.frontMatter["minHeight"])
            globalMinHeight = storieCtx.minHeight
          except:
            discard

        # Also update globalState styleSheet for API access
        globalState.styleSheet = doc.styleSheet
        
        # Check if theme parameter is set and override the stylesheet
        if hasParamDirect("theme"):
          let themeName = getParamDirect("theme")
          if themeName.len > 0:
            try:
              let newStyleSheet = applyThemeByName(themeName)
              storieCtx.styleSheet = newStyleSheet
              globalState.styleSheet = newStyleSheet
              # Re-register canvas bindings with new stylesheet (use default layer)
              if globalState.layers.len > 0:
                registerCanvasBindings(addr globalState.layers[0].buffer, addr globalState, addr storieCtx.styleSheet)
            except:
              discard
        
        # Extract theme background color from stylesheet and update globalState
        if storieCtx.styleSheet.hasKey("body"):
          storieCtx.themeBackground = storieCtx.styleSheet["body"].bg
          globalState.themeBackground = storieCtx.themeBackground
        else:
          storieCtx.themeBackground = (0'u8, 0'u8, 0'u8)
          globalState.themeBackground = (0'u8, 0'u8, 0'u8)
        
        # Expose front matter variables to Nimini environment
        exposeFrontMatterVariables()
        
        # Update browser tab title if title is defined in frontmatter
        if storieCtx.frontMatter.hasKey("title"):
          setDocumentTitle(storieCtx.frontMatter["title"])
        
        # Clear all layer buffers with theme background
        for layer in globalState.layers:
          layer.buffer.clear(globalState.themeBackground)
        
        # Execute init blocks immediately
        for codeBlock in doc.codeBlocks:
          if codeBlock.lifecycle == "init":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
        
        # Execute render blocks immediately to show content
        for codeBlock in doc.codeBlocks:
          if codeBlock.lifecycle == "render":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
    except Exception as e:
      discard # Silently fail in WASM

proc showHelp() =
  echo "tstorie v" & version
  echo "Terminal-based interactive fiction engine"
  echo ""
  echo "Usage:"
  echo "  tstorie [OPTIONS] [FILE] [PARAMS...]"
  echo "  tstorie export [OPTIONS] <file.md>     # Export to native Nim"
  echo ""
  echo "Commands:"
  echo "  (default)             Run a tStorie markdown file"
  echo "  export                Export markdown to native Nim program"
  echo "                        Use 'tstorie export --help' for export options"
  echo ""
  echo "Arguments:"
  echo "  FILE                  Markdown file to run (default: index.md)"
  echo "  PARAMS                Custom parameters as key=value pairs"
  echo ""
  echo "Options:"
  echo "  -h, --help            Show this help message"
  echo "  -v, --version         Show version information"
  echo "  -c, --content <ref>   Load content from source (see Content Sources below)"
  echo "  --fps <num>           Set target FPS (default 60; Windows non-WT default 30)"
  echo "                        Can also use STORIE_TARGET_FPS env var"
  echo "  --<key>=<value>       Custom parameter (accessible via getParam/hasParam)"
  echo ""
  echo "Content Sources:"
  echo "  The --content option supports multiple sources:"
  echo "    gist:<ID>           - Load from GitHub Gist"
  echo "    demo:<name>         - Load from demos/ folder"
  echo "    file:<path>         - Load from file path"
  echo "    <URL>               - Full GitHub Gist URL"
  echo ""
  echo "Custom Parameters:"
  echo "  Scripts can access custom parameters using:"
  echo "    hasParam(\"name\")     - Check if parameter exists"
  echo "    getParam(\"name\")     - Get parameter as string"
  echo "    getParamInt(\"name\", default) - Get parameter as integer"
  echo ""
  echo "  Special parameters:"
  echo "    theme=<name>       - Override theme from front matter"
  echo "                         (e.g., theme=nord, theme=dracula)"
  echo ""
  echo "Examples:"
  echo "  tstorie                              # Run index.md"
  echo "  tstorie depths.md                    # Run depths.md"
  echo "  tstorie export myapp.md              # Export to native Nim"
  echo "  tstorie export myapp.md -c           # Export and compile"
  echo "  tstorie --content demo:clock         # Run clock demo"
  echo "  tstorie --content gist:abc123        # Run from GitHub Gist"
  echo "  tstorie examples/dungen.md seed=12345  # Run with seed parameter"
  echo "  tstorie examples/dungen.md --seed=12345  # Same using --option format"
  echo "  tstorie myfile.md theme=nord         # Override theme to nord"
  echo "  tstorie examples/canvas_demo.md      # Run a demo"
  echo ""
  echo "Web Usage (URL parameters):"
  echo "  https://example.com/?seed=12345      # Parameters passed via URL"
  echo "  https://example.com/?theme=dracula   # Override theme via URL"
  echo "  tstorie --fps 30 my_story.md         # Run with custom FPS"
  echo ""

proc main() =
  # Check for export subcommand first (before parsing any options)
  when not defined(emscripten):
    if paramCount() > 0 and paramStr(1) == "export":
      runExport()
      return
  
  var p = initOptParser()
  var cliFps: float = 0.0
  var mdFile: string = ""
  var contentRef: string = ""
  var customParams: seq[(string, string)] = @[]
  
  for kind, key, val in p.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h":
        showHelp()
        quit(0)
      of "version", "v":
        echo "storie version " & version
        quit(0)
      of "fps":
        if val.len == 0:
          echo "--fps requires a value (e.g., --fps 30)"
          quit(1)
        try:
          let f = parseFloat(val)
          if f <= 0:
            echo "--fps must be > 0"
            quit(1)
          cliFps = f
        except:
          echo "Invalid --fps value: " & val
          quit(1)
      of "content", "c":
        if val.len == 0:
          echo "--content requires a value (e.g., --content gist:abc123 or --content demo:clock)"
          quit(1)
        contentRef = val
      else:
        # Custom parameter (e.g., --seed=12345 or --width=100)
        if val.len > 0:
          customParams.add((key, val))
        else:
          echo "Unknown option: " & key
          echo "Use --help for usage information"
          quit(1)
    of cmdArgument:
      # First positional argument is the markdown file (unless content is specified)
      if mdFile.len == 0 and contentRef.len == 0:
        mdFile = key
      else:
        # Additional arguments as key=value pairs (e.g., seed=12345)
        let parts = key.split('=', maxsplit=1)
        if parts.len == 2:
          customParams.add((parts[0], parts[1]))
        else:
          echo "Only one markdown file can be specified"
          echo "Additional arguments should be key=value pairs (e.g., seed=12345)"
          echo "Use --help for usage information"
          quit(1)
    else: discard
  
  # Store custom parameters in nimini stdlib
  for (key, val) in customParams:
    setParam(key, val)
  
  # Load content from specified source
  if contentRef.len > 0:
    when not defined(emscripten):
      try:
        echo "Loading content from: ", contentRef
        let content = loadContentFromSource(contentRef)
        # Write to temp file
        let tmpFile = "/tmp/tstorie_content.md"
        writeFile(tmpFile, content)
        gMarkdownFile = tmpFile
        echo "Content loaded successfully"
      except Exception as e:
        echo "Error loading content: ", e.msg
        quit(1)
    else:
      echo "Content loading not supported in WASM mode"
      quit(1)
  elif mdFile.len > 0:
    gMarkdownFile = mdFile
  
  # Apply theme parameter if present (before loading markdown)
  if hasParamDirect("theme"):
    let themeName = getParamDirect("theme")
    if themeName.len > 0:
      # Will be applied when storieCtx is initialized
      discard  # Theme will be checked after markdown loads
  
  when not defined(emscripten):
    let (w, h) = getTermSize()
    var state = newAppState(w, h)
    state.colorSupport = detectColorSupport()
    
    when defined(windows):
      # If not Windows Terminal (WT_SESSION absent), lower default FPS for performance
      if getEnv("WT_SESSION").len == 0:
        state.targetFps = 30.0
    let fpsEnv = getEnv("STORIE_TARGET_FPS")
    if fpsEnv.len > 0:
      try:
        let envFps = parseFloat(fpsEnv)
        if envFps > 0:
          state.targetFps = envFps
      except:
        discard  # Ignore invalid values
    if cliFps > 0.0:
      state.targetFps = cliFps
    
    globalTerminalState = setupRawMode()
    hideCursor()
    enableMouseReporting()
    enableKeyboardProtocol()
    
    setupSignalHandlers(proc(sig: cint) {.noconv.} = globalRunning = false)
    
    callOnSetup(state)
    
    var lastTime = epochTime()
    
    try:
      while state.running and globalRunning:
        if not globalRunning:
          break
          
        let currentTime = epochTime()
        let deltaTime = currentTime - lastTime
        lastTime = currentTime
        
        # Process input events
        let events = getInputEvent(state)
        for event in events:
          if event.kind == ResizeEvent:
            state.resizeState(event.newWidth, event.newHeight)
            stdout.write("\e[2J\e[H")
            stdout.flushFile()
          else:
            discard callOnInput(state, event)
        
        let (newW, newH) = getTermSize()
        if newW != state.termWidth or newH != state.termHeight:
          state.resizeState(newW, newH)
          stdout.write("\e[2J\e[H")
          stdout.flushFile()
        
        # Update FPS counter
        state.updateFpsCounter(deltaTime)
        
        callOnFrame(state, deltaTime)
        
        swap(state.currentBuffer, state.previousBuffer)
        callOnDraw(state)
        
        # Only composite layers if not showing dimension warning
        # (warning is rendered directly to currentBuffer)
        if not gShowingDimensionWarning:
          compositeLayers(state)
        
        state.currentBuffer.display(state.previousBuffer, state.colorSupport)
        
        if state.targetFps > 0.0:
          let frameTime = epochTime() - currentTime
          let targetFrameTime = 1.0 / state.targetFps
          let sleepTime = targetFrameTime - frameTime
          if sleepTime > 0:
            sleep(int(sleepTime * 1000))
        
        if not globalRunning:
          break
    finally:
      callOnShutdown(state)
      disableKeyboardProtocol()
      disableMouseReporting()
      showCursor()
      clearScreen()
      restoreTerminal(globalTerminalState)
      stdout.write("\n")
      stdout.flushFile()

when isMainModule:
  main()