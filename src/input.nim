## Terminal Input Parsing Module
## Standalone input handling for terminal applications
## Can be used by both the tStorie runtime and exported programs

import times
import strutils  # For join
import types
when not defined(emscripten):
  import platform/terminal

# ================================================================
# CSI PARSING HELPERS
# ================================================================

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

# ================================================================
# CSI SEQUENCE HANDLING
# ================================================================

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

# ================================================================
# MAIN INPUT PARSER
# ================================================================

proc parseInput*(vt: var TerminalInputParser, text: openArray[char]): seq[InputEvent] =
  ## Parse raw terminal input bytes into structured input events
  ## Handles ANSI escape sequences, CSI codes, UTF-8, mouse events, etc.
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
# HIGH-LEVEL POLLING API
# ================================================================

proc pollInput*(parser: var TerminalInputParser): seq[InputEvent] =
  ## Convenience function that polls terminal for input and parses it
  ## Returns a sequence of input events (key presses, mouse events, etc.)
  ## This is the main function exported programs should use in their main loop
  when defined(emscripten):
    return @[]
  else:
    var buffer: array[256, char]
    let bytesRead = readInputRaw(buffer)
    if bytesRead > 0:
      return parser.parseInput(buffer.toOpenArray(0, bytesRead - 1))
    return @[]
