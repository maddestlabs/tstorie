## Complete Input Handling System for tStorie
##
## This module provides comprehensive input handling for both terminal
## (via CSI/ANSI escape sequences) and future SDL3 graphical backends.
##
## Consolidated from lib/event_constants.nim and old src/input.nim
## to provide a single source of truth for all input-related functionality.
##
## Features:
## - SDL3-compatible key codes and event types
## - Terminal CSI/ANSI escape sequence parsing
## - Mouse event handling (buttons, movement, scrolling)
## - Keyboard modifiers (Shift, Ctrl, Alt, Super)
## - UTF-8 text input
##
## Design Philosophy:
## - Named constants instead of magic numbers (KEY_ESCAPE vs 27)
## - Enum-based types for type safety (MouseButton enum vs strings)
## - SDL3-compatible event structure for future graphical backend
## - Progressive enhancement: Terminal gets basic, SDL3 gets full features

import times
import strutils

when not defined(emscripten):
  import platform/terminal

# ================================================================
# KEY TYPES (SDL3-Compatible)
# ================================================================

type
  KeyCode* = distinct int
    ## Logical key (respects keyboard layout)
    ## Maps to SDL_Keycode in SDL3 backend
  
  ScanCode* = distinct int
    ## Physical key position (layout-independent)
    ## Maps to SDL_Scancode in SDL3 backend
    ## Based on USB HID Usage Tables
  
  KeyMod* = enum
    ## Keyboard modifiers
    ## Maps to SDL_Keymod in SDL3 backend
    kmNone = 0
    kmShift = 1 shl 0
    kmCtrl = 1 shl 1
    kmAlt = 1 shl 2
    kmSuper = 1 shl 3     # Windows/Command key
    kmCapsLock = 1 shl 8
    kmNumLock = 1 shl 9

# ================================================================
# MOUSE TYPES
# ================================================================

type
  MouseButton* = enum
    ## Mouse button identifiers
    ## Maps to SDL_BUTTON_* in SDL3 backend
    mbNone = 0
    mbLeft = 1
    mbMiddle = 2
    mbRight = 3
    mbX1 = 4      # Extra mouse button 1
    mbX2 = 5      # Extra mouse button 2

# ================================================================
# EVENT TYPES (SDL3-Compatible)
# ================================================================

type
  EventType* = enum
    ## Event type identifiers
    ## Maps to SDL_EventType in SDL3 backend
    etNone = 0
    etKeyDown
    etKeyUp
    etTextInput           # Separate from key events (important for IME!)
    etMouseMotion
    etMouseButtonDown
    etMouseButtonUp
    etMouseWheel
    # Future SDL3 support:
    etTouchFingerDown     # Multi-touch for mobile/tablets
    etTouchFingerUp
    etTouchFingerMotion
    etMultiGesture        # Pinch, rotate gestures

# ================================================================
# KEY CONSTANTS - Printable ASCII
# ================================================================

const
  # Printable ASCII characters (0x20-0x7E)
  KEY_SPACE* = KeyCode(32)
  KEY_EXCLAIM* = KeyCode(33)        # !
  KEY_QUOTEDBL* = KeyCode(34)       # "
  KEY_HASH* = KeyCode(35)           # #
  KEY_DOLLAR* = KeyCode(36)         # $
  KEY_PERCENT* = KeyCode(37)        # %
  KEY_AMPERSAND* = KeyCode(38)      # &
  KEY_QUOTE* = KeyCode(39)          # '
  KEY_LEFTPAREN* = KeyCode(40)      # (
  KEY_RIGHTPAREN* = KeyCode(41)     # )
  KEY_ASTERISK* = KeyCode(42)       # *
  KEY_PLUS* = KeyCode(43)           # +
  KEY_COMMA* = KeyCode(44)          # ,
  KEY_MINUS* = KeyCode(45)          # -
  KEY_PERIOD* = KeyCode(46)         # .
  KEY_SLASH* = KeyCode(47)          # /
  
  # Numbers (0-9)
  KEY_0* = KeyCode(48)
  KEY_1* = KeyCode(49)
  KEY_2* = KeyCode(50)
  KEY_3* = KeyCode(51)
  KEY_4* = KeyCode(52)
  KEY_5* = KeyCode(53)
  KEY_6* = KeyCode(54)
  KEY_7* = KeyCode(55)
  KEY_8* = KeyCode(56)
  KEY_9* = KeyCode(57)
  
  KEY_COLON* = KeyCode(58)          # :
  KEY_SEMICOLON* = KeyCode(59)      # ;
  KEY_LESS* = KeyCode(60)           # <
  KEY_EQUALS* = KeyCode(61)         # =
  KEY_GREATER* = KeyCode(62)        # >
  KEY_QUESTION* = KeyCode(63)       # ?
  KEY_AT* = KeyCode(64)             # @
  
  # Uppercase letters (A-Z)
  KEY_A* = KeyCode(65)
  KEY_B* = KeyCode(66)
  KEY_C* = KeyCode(67)
  KEY_D* = KeyCode(68)
  KEY_E* = KeyCode(69)
  KEY_F* = KeyCode(70)
  KEY_G* = KeyCode(71)
  KEY_H* = KeyCode(72)
  KEY_I* = KeyCode(73)
  KEY_J* = KeyCode(74)
  KEY_K* = KeyCode(75)
  KEY_L* = KeyCode(76)
  KEY_M* = KeyCode(77)
  KEY_N* = KeyCode(78)
  KEY_O* = KeyCode(79)
  KEY_P* = KeyCode(80)
  KEY_Q* = KeyCode(81)
  KEY_R* = KeyCode(82)
  KEY_S* = KeyCode(83)
  KEY_T* = KeyCode(84)
  KEY_U* = KeyCode(85)
  KEY_V* = KeyCode(86)
  KEY_W* = KeyCode(87)
  KEY_X* = KeyCode(88)
  KEY_Y* = KeyCode(89)
  KEY_Z* = KeyCode(90)
  
  KEY_LEFTBRACKET* = KeyCode(91)    # [
  KEY_BACKSLASH* = KeyCode(92)      # \
  KEY_RIGHTBRACKET* = KeyCode(93)   # ]
  KEY_CARET* = KeyCode(94)          # ^
  KEY_UNDERSCORE* = KeyCode(95)     # _
  KEY_BACKQUOTE* = KeyCode(96)      # `
  
  KEY_LEFTBRACE* = KeyCode(123)     # {
  KEY_PIPE* = KeyCode(124)          # |
  KEY_RIGHTBRACE* = KeyCode(125)    # }
  KEY_TILDE* = KeyCode(126)         # ~

# ================================================================
# KEY CONSTANTS - Control Characters
# ================================================================

const
  KEY_BACKSPACE* = KeyCode(8)
  KEY_TAB* = KeyCode(9)
  KEY_RETURN* = KeyCode(13)
  KEY_ENTER* = KEY_RETURN           # Alias
  KEY_ESCAPE* = KeyCode(27)
  KEY_ESC* = KEY_ESCAPE             # Short alias
  KEY_DELETE* = KeyCode(127)

# ================================================================
# KEY CONSTANTS - Arrow Keys & Navigation
# ================================================================
# Note: These use custom keycodes (1000+) for terminal mode
# In SDL3 mode, these will be remapped to SDL_SCANCODE_* values

const
  KEY_UP* = KeyCode(1000)
  KEY_DOWN* = KeyCode(1001)
  KEY_LEFT* = KeyCode(1002)
  KEY_RIGHT* = KeyCode(1003)
  KEY_HOME* = KeyCode(1004)
  KEY_END* = KeyCode(1005)
  KEY_PAGEUP* = KeyCode(1006)
  KEY_PAGEDOWN* = KeyCode(1007)
  KEY_INSERT* = KeyCode(1008)

# ================================================================
# KEY CONSTANTS - Function Keys
# ================================================================

const
  KEY_F1* = KeyCode(1100)
  KEY_F2* = KeyCode(1101)
  KEY_F3* = KeyCode(1102)
  KEY_F4* = KeyCode(1103)
  KEY_F5* = KeyCode(1104)
  KEY_F6* = KeyCode(1105)
  KEY_F7* = KeyCode(1106)
  KEY_F8* = KeyCode(1107)
  KEY_F9* = KeyCode(1108)
  KEY_F10* = KeyCode(1109)
  KEY_F11* = KeyCode(1110)
  KEY_F12* = KeyCode(1111)

# ================================================================
# SCANCODE CONSTANTS (Physical Key Positions)
# ================================================================
# Based on USB HID Usage Tables and SDL3 scancodes
# These represent physical key positions, independent of layout

const
  # Special keys
  SC_ESCAPE* = ScanCode(41)
  SC_RETURN* = ScanCode(40)
  SC_BACKSPACE* = ScanCode(42)
  SC_TAB* = ScanCode(43)
  SC_SPACE* = ScanCode(44)
  SC_DELETE* = ScanCode(76)
  
  # Arrow keys (USB HID standard positions)
  SC_RIGHT* = ScanCode(79)
  SC_LEFT* = ScanCode(80)
  SC_DOWN* = ScanCode(81)
  SC_UP* = ScanCode(82)
  
  SC_HOME* = ScanCode(74)
  SC_END* = ScanCode(77)
  SC_PAGEUP* = ScanCode(75)
  SC_PAGEDOWN* = ScanCode(78)
  SC_INSERT* = ScanCode(73)
  
  # Function keys
  SC_F1* = ScanCode(58)
  SC_F2* = ScanCode(59)
  SC_F3* = ScanCode(60)
  SC_F4* = ScanCode(61)
  SC_F5* = ScanCode(62)
  SC_F6* = ScanCode(63)
  SC_F7* = ScanCode(64)
  SC_F8* = ScanCode(65)
  SC_F9* = ScanCode(66)
  SC_F10* = ScanCode(67)
  SC_F11* = ScanCode(68)
  SC_F12* = ScanCode(69)
  
  # Letters (physical QWERTY positions)
  SC_A* = ScanCode(4)
  SC_B* = ScanCode(5)
  SC_C* = ScanCode(6)
  SC_D* = ScanCode(7)
  SC_E* = ScanCode(8)
  SC_F* = ScanCode(9)
  SC_G* = ScanCode(10)
  SC_H* = ScanCode(11)
  SC_I* = ScanCode(12)
  SC_J* = ScanCode(13)
  SC_K* = ScanCode(14)
  SC_L* = ScanCode(15)
  SC_M* = ScanCode(16)
  SC_N* = ScanCode(17)
  SC_O* = ScanCode(18)
  SC_P* = ScanCode(19)
  SC_Q* = ScanCode(20)
  SC_R* = ScanCode(21)
  SC_S* = ScanCode(22)
  SC_T* = ScanCode(23)
  SC_U* = ScanCode(24)
  SC_V* = ScanCode(25)
  SC_W* = ScanCode(26)
  SC_X* = ScanCode(27)
  SC_Y* = ScanCode(28)
  SC_Z* = ScanCode(29)
  
  # Numbers (top row)
  SC_1* = ScanCode(30)
  SC_2* = ScanCode(31)
  SC_3* = ScanCode(32)
  SC_4* = ScanCode(33)
  SC_5* = ScanCode(34)
  SC_6* = ScanCode(35)
  SC_7* = ScanCode(36)
  SC_8* = ScanCode(37)
  SC_9* = ScanCode(38)
  SC_0* = ScanCode(39)

# ================================================================
# CONVERSION HELPERS
# ================================================================

proc `==`*(a, b: KeyCode): bool {.borrow.}
proc `==`*(a, b: ScanCode): bool {.borrow.}
proc `$`*(k: KeyCode): string = "KeyCode(" & $k.int & ")"
proc `$`*(s: ScanCode): string = "ScanCode(" & $s.int & ")"

# Note: Use .int directly on KeyCode/ScanCode values instead of explicit converter
# Example: myKeyCode.int returns the integer value



# ================================================================
# KEY NAME HELPERS
# ================================================================

proc keyCodeToName*(key: KeyCode): string =
  ## Convert KeyCode to human-readable name
  ## Useful for debugging and UI display
  case key.int
  # Control characters
  of 8: "Backspace"
  of 9: "Tab"
  of 13: "Enter"
  of 27: "Escape"
  of 127: "Delete"
  # Arrow keys
  of 1000: "Up"
  of 1001: "Down"
  of 1002: "Left"
  of 1003: "Right"
  of 1004: "Home"
  of 1005: "End"
  of 1006: "PageUp"
  of 1007: "PageDown"
  of 1008: "Insert"
  # Function keys
  of 1100..1111: "F" & $(key.int - 1099)
  # Printable characters
  of 32..126: $chr(key.int)
  else: "Unknown(" & $key.int & ")"

proc eventTypeToString*(et: EventType): string =
  ## Convert EventType to string for debugging
  case et
  of etNone: "None"
  of etKeyDown: "KeyDown"
  of etKeyUp: "KeyUp"
  of etTextInput: "TextInput"
  of etMouseMotion: "MouseMotion"
  of etMouseButtonDown: "MouseButtonDown"
  of etMouseButtonUp: "MouseButtonUp"
  of etMouseWheel: "MouseWheel"
  of etTouchFingerDown: "TouchFingerDown"
  of etTouchFingerUp: "TouchFingerUp"
  of etTouchFingerMotion: "TouchFingerMotion"
  of etMultiGesture: "MultiGesture"

# ================================================================
# TERMINAL INPUT EVENT TYPES
# ================================================================
# These types bridge between raw terminal input and the SDL3-compatible
# event system above. They're used internally for terminal parsing.

# Modifier key constants (used in terminal parsing)
const
  ModShift* = 0'u8
  ModAlt* = 1'u8
  ModCtrl* = 2'u8
  ModSuper* = 3'u8

type
  InputAction* = enum
    Press
    Release
    Repeat

  # Terminal-specific MouseButton enum
  # Includes ScrollUp/ScrollDown because terminal scroll events come as mouse buttons
  # Distinct from SDL3 MouseButton which has separate wheel events
  TerminalMouseButton* = enum
    Left
    Middle
    Right
    Unknown
    ScrollUp
    ScrollDown

  InputEventKind* = enum
    KeyEvent
    TextEvent
    MouseEvent
    MouseMoveEvent
    ResizeEvent

  InputEvent* = object
    case kind*: InputEventKind
    of KeyEvent:
      keyCode*: int
      keyMods*: set[uint8]
      keyAction*: InputAction
    of TextEvent:
      text*: string
    of MouseEvent:
      button*: TerminalMouseButton
      mouseX*: int
      mouseY*: int
      mods*: set[uint8]
      action*: InputAction
    of MouseMoveEvent:
      moveX*: int
      moveY*: int
      moveMods*: set[uint8]
    of ResizeEvent:
      newWidth*: int
      newHeight*: int

# ================================================================
# TERMINAL INPUT PARSER TYPES
# ================================================================

const
  INTERMED_MAX* = 16
  CSI_ARGS_MAX* = 16
  CSI_LEADER_MAX* = 16
  CSI_ARG_FLAG_MORE* = 0x80000000'i64
  CSI_ARG_MASK* = 0x7FFFFFFF'i64
  CSI_ARG_MISSING* = 0x7FFFFFFF'i64

type
  StringCsiState* = object
    leaderlen*: int
    leader*: array[CSI_LEADER_MAX, char]
    argi*: int
    args*: array[CSI_ARGS_MAX, int64]

  ParserState* = enum
    Normal
    CSILeader
    CSIArgs
    CSIIntermed

  TerminalInputParser* = object
    prevEsc*: bool
    inEsc*: bool
    inEscO*: bool
    inUtf8*: bool
    utf8Remaining*: int
    utf8Buffer*: string
    state*: ParserState
    csi*: StringCsiState
    intermedlen*: int
    intermed*: array[INTERMED_MAX, char]
    mouseCol*: int
    mouseRow*: int
    width*: int
    height*: int
    escTimer*: float
    endedInEsc*: bool
    enableEscapeTimeout*: bool
    escapeTimeout*: int
    mouseTrackingDisabled*: bool
    mouseTrackingReenableTime*: float

# ================================================================
# INPUT PARSER INITIALIZATION
# ================================================================

proc newTerminalInputParser*(): TerminalInputParser =
  ## Create a new terminal input parser with default values
  result.state = Normal
  result.csi.args[0] = CSI_ARG_MISSING
  result.enableEscapeTimeout = true
  result.escapeTimeout = 300
  result.escTimer = 0.0  # Will be set when first used
  result.mouseTrackingDisabled = false
  result.mouseTrackingReenableTime = 0.0

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
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_UP.int, keyMods: mods, keyAction: action)
  of 'B':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_DOWN.int, keyMods: mods, keyAction: action)
  of 'C':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_RIGHT.int, keyMods: mods, keyAction: action)
  of 'D':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_LEFT.int, keyMods: mods, keyAction: action)
  of 'F':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_END.int, keyMods: mods, keyAction: action)
  of 'H':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_HOME.int, keyMods: mods, keyAction: action)
  of 'P':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_F1.int, keyMods: mods, keyAction: action)
  of 'Q':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_F2.int, keyMods: mods, keyAction: action)
  of 'S':
    let (mods, action) = vt.parseModsAndAction()
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_F4.int, keyMods: mods, keyAction: action)
  of 'Z':
    var (mods, action) = vt.parseModsAndAction()
    mods.incl ModShift
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_TAB.int, keyMods: mods, keyAction: action)
  of '~':
    let (mods, action) = vt.parseModsAndAction()
    if argcount > 0:
      case args[0].int
      of 3: result.add InputEvent(kind: KeyEvent, keyCode: KEY_DELETE.int, keyMods: mods, keyAction: action)
      of 5: result.add InputEvent(kind: KeyEvent, keyCode: KEY_PAGEUP.int, keyMods: mods, keyAction: action)
      of 6: result.add InputEvent(kind: KeyEvent, keyCode: KEY_PAGEDOWN.int, keyMods: mods, keyAction: action)
      of 11: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F1.int, keyMods: mods, keyAction: action)
      of 12: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F2.int, keyMods: mods, keyAction: action)
      of 13: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F3.int, keyMods: mods, keyAction: action)
      of 14: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F4.int, keyMods: mods, keyAction: action)
      of 15: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F5.int, keyMods: mods, keyAction: action)
      of 17: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F6.int, keyMods: mods, keyAction: action)
      of 18: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F7.int, keyMods: mods, keyAction: action)
      of 19: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F8.int, keyMods: mods, keyAction: action)
      of 20: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F9.int, keyMods: mods, keyAction: action)
      of 21: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F10.int, keyMods: mods, keyAction: action)
      of 23: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F11.int, keyMods: mods, keyAction: action)
      of 24: result.add InputEvent(kind: KeyEvent, keyCode: KEY_F12.int, keyMods: mods, keyAction: action)
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

      let mouseButton: TerminalMouseButton = case buttonCode
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

      # Detect Ctrl-Mousewheel and temporarily disable mouse tracking
      if scroll and (mods and 0x4) != 0:
        when not defined(emscripten):
          # Disable mouse tracking for 1 second to let terminal handle font resizing
          disableMouseReporting()
          vt.mouseTrackingDisabled = true
          vt.mouseTrackingReenableTime = epochTime() + 1.0
        # Don't generate event - let it pass through to terminal
        return result

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
    result.add InputEvent(kind: KeyEvent, keyCode: KEY_ESCAPE.int, keyMods: mods, keyAction: Press)
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
        result.add InputEvent(kind: KeyEvent, keyCode: KEY_F1.int, keyMods: mods, keyAction: Press)
        continue
      of 'Q':
        result.add InputEvent(kind: KeyEvent, keyCode: KEY_F2.int, keyMods: mods, keyAction: Press)
        continue
      of 'R':
        result.add InputEvent(kind: KeyEvent, keyCode: KEY_F3.int, keyMods: mods, keyAction: Press)
        continue
      of 'S':
        result.add InputEvent(kind: KeyEvent, keyCode: KEY_F4.int, keyMods: mods, keyAction: Press)
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
      result.add InputEvent(kind: KeyEvent, keyCode: KEY_BACKSPACE.int, keyMods: mods, keyAction: Press)
      mods = {}
      continue
    of '\x08':
      if vt.inEsc:
        mods.incl ModAlt
      mods.incl ModCtrl
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: KEY_BACKSPACE.int, keyMods: mods, keyAction: Press)
      mods = {}
      continue
    of '\x09':
      if vt.inEsc:
        mods.incl ModAlt
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: KEY_TAB.int, keyMods: mods, keyAction: Press)
      mods = {}
      continue
    of '\x0d', '\x0a':
      if vt.inEsc:
        mods.incl ModAlt
      vt.inEsc = false
      result.add InputEvent(kind: KeyEvent, keyCode: KEY_ENTER.int, keyMods: mods, keyAction: Press)
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
      result.add InputEvent(kind: KeyEvent, keyCode: KEY_SPACE.int, keyMods: mods, keyAction: Press)
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

proc checkMouseTrackingReenabled*(parser: var TerminalInputParser) =
  ## Check if mouse tracking should be re-enabled after Ctrl-Mousewheel timeout
  ## Call this once per frame in your main loop
  when not defined(emscripten):
    if parser.mouseTrackingDisabled:
      let currentTime = epochTime()
      if currentTime >= parser.mouseTrackingReenableTime:
        enableMouseReporting()
        parser.mouseTrackingDisabled = false

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
