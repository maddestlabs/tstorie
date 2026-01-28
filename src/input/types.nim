## Shared Input Types for tStorie
##
## This module contains all the type definitions and constants used across
## different input backends (terminal, WASM, SDL3).
##
## These types provide a unified interface while remaining compatible with SDL3.

import times

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
# UNIFIED INPUT EVENT TYPES
# ================================================================

# Modifier key constants (used in event parsing)
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
    ## Unified input event structure used across all backends
    ## After normalization, printable characters ONLY appear in TextEvent
    case kind*: InputEventKind
    of KeyEvent:
      keyCode*: int
      keyMods*: set[uint8]
      keyAction*: InputAction
    of TextEvent:
      text*: string
      textMods*: set[uint8]
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
# EVENT NORMALIZATION
# ================================================================

proc isPrintableKey*(keyCode: int): bool =
  ## Check if a keyCode represents a printable character (32-126)
  ## These should be TextEvents, not KeyEvents
  return keyCode >= 32 and keyCode <= 126

proc normalizeEvents*(events: seq[InputEvent]): seq[InputEvent] =
  ## Normalize events to ensure consistent behavior across backends
  ## 
  ## Rules:
  ## 1. Printable characters (32-126) should ONLY appear as TextEvents
  ## 2. Special keys (arrows, function keys, etc.) appear as KeyEvents
  ## 3. If both KeyEvent and TextEvent exist for same character, keep only TextEvent
  ## 4. Preserve modifiers when converting KeyEvent to TextEvent
  result = @[]
  
  var i = 0
  while i < events.len:
    let evt = events[i]
    
    case evt.kind
    of KeyEvent:
      # Check if this is a printable key that will have a TextEvent
      if isPrintableKey(evt.keyCode) and evt.keyAction == Press:
        # Look ahead or behind for matching TextEvent
        var hasTextEvent = false
        
        # Check ahead (WASM backend: KeyEvent -> TextEvent)
        if i + 1 < events.len and events[i + 1].kind == TextEvent:
          hasTextEvent = true
        
        # Check behind (SDL3 backend: TextEvent -> KeyEvent)
        if i > 0 and events[i - 1].kind == TextEvent:
          hasTextEvent = true
        
        # Skip this KeyEvent if TextEvent exists
        if not hasTextEvent:
          # No TextEvent found, convert KeyEvent to TextEvent for consistency
          # Preserve modifiers from KeyEvent (only for Press events)
          result.add InputEvent(
            kind: TextEvent,
            text: $chr(evt.keyCode),
            textMods: evt.keyMods
          )
      else:
        # Non-printable key OR Release event - keep as KeyEvent
        result.add evt
        
    else:
      # MouseEvent, TextEvent, etc. - keep as-is
      result.add evt
    
    inc i
