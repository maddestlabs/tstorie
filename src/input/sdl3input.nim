## SDL3 Input Backend for tStorie
##
## This module implements the unified input system for SDL3, converting
## SDL events to the standard InputEvent format used across all backends.

import types
export types

import ../../backends/sdl3/sdl3_bindings

type
  SDL3InputHandler* = object
    canvas*: pointer  # pointer to SDLCanvas to avoid circular dependency
    cellWidth*: int
    cellHeight*: int

proc newSDL3InputHandler*(canvas: pointer, cellWidth, cellHeight: int): SDL3InputHandler =
  ## Create a new SDL3 input handler
  result = SDL3InputHandler(
    canvas: canvas,
    cellWidth: cellWidth,
    cellHeight: cellHeight
  )

# Helper to extract scancode from SDL_Event
proc getEventScancode(event: ptr SDL_Event): int =
  ## Extract keyboard scancode from SDL_Event at offset 24
  ## SDL_Event layout:
  ## - type: uint32 (0-3)
  ## - reserved: uint32 (4-7)
  ## - timestamp: uint64 (8-15)
  ## - windowID: uint32 (16-19)
  ## - scancode: uint32 (24-27) for keyboard events
  if event.type_field == SDL_EVENT_KEY_DOWN or event.type_field == SDL_EVENT_KEY_UP:
    let paddingPtr = cast[ptr array[128, uint8]](event)
    let scancodePtr = cast[ptr uint32](addr paddingPtr[24])
    return scancodePtr[].int
  return 0

# Helper to extract mouse button
proc getEventMouseButton(event: ptr SDL_Event): int =
  ## Extract mouse button from SDL event at offset 24
  let buttonPtr = cast[ptr uint8](cast[uint](event) + 24)
  result = buttonPtr[].int

# Helper to extract mouse position
proc getEventMousePos(event: ptr SDL_Event): tuple[x, y: int] =
  ## Extract mouse position: x at offset 28, y at offset 32 (both cfloat)
  let xPtr = cast[ptr cfloat](cast[uint](event) + 28)
  let yPtr = cast[ptr cfloat](cast[uint](event) + 32)
  result.x = xPtr[].int
  result.y = yPtr[].int

# Helper to extract mouse wheel
proc getEventMouseWheel(event: ptr SDL_Event): cfloat =
  ## Extract mouse wheel Y direction from SDL event at offset 28
  let yPtr = cast[ptr cfloat](cast[uint](event) + 28)
  result = yPtr[]

# Helper to convert SDL modifiers to input system modifier set
proc sdlModsToSet(sdlMods: uint16): set[uint8] =
  ## Convert SDL_Keymod flags to modifier set
  result = {}
  if (sdlMods and SDL_KMOD_SHIFT) != 0:
    result.incl(0'u8)  # Shift
  if (sdlMods and SDL_KMOD_ALT) != 0:
    result.incl(1'u8)  # Alt
  if (sdlMods and SDL_KMOD_CTRL) != 0:
    result.incl(2'u8)  # Ctrl
  if (sdlMods and SDL_KMOD_GUI) != 0:
    result.incl(3'u8)  # Super/GUI

# Apply shift modifier to character
proc applyShiftToChar(keyCode: int, hasShift: bool): string =
  ## Convert keyCode to character string, applying shift modifier
  if hasShift:
    # Shift is pressed - return uppercase/symbols
    case keyCode
    # Letters: already uppercase in keyCode (65-90)
    of 65..90: return $char(keyCode)
    # Numbers with shift → symbols
    of 48: return ")"  # 0 → )
    of 49: return "!"  # 1 → !
    of 50: return "@"  # 2 → @
    of 51: return "#"  # 3 → #
    of 52: return "$"  # 4 → $
    of 53: return "%"  # 5 → %
    of 54: return "^"  # 6 → ^
    of 55: return "&"  # 7 → &
    of 56: return "*"  # 8 → *
    of 57: return "("  # 9 → (
    # Punctuation with shift
    of 45: return "_"  # - → _
    of 61: return "+"  # = → +
    of 91: return "{"  # [ → {
    of 93: return "}"  # ] → }
    of 92: return "|"  # \ → |
    of 59: return ":"  # ; → :
    of 39: return "\""  # ' → "
    of 96: return "~"  # ` → ~
    of 44: return "<"  # , → <
    of 46: return ">"  # . → >
    of 47: return "?"  # / → ?
    # Space and other printables
    of 32: return " "  # Space stays space
    else: return $char(keyCode)
  else:
    # No shift - return lowercase/numbers/punctuation as-is
    if keyCode >= 65 and keyCode <= 90:
      # Letters: convert to lowercase (65-90 → 97-122)
      return $char(keyCode + 32)
    elif keyCode >= 32 and keyCode <= 126:
      # Other printable chars stay as-is
      return $char(keyCode)
    else:
      return $char(keyCode)

# Scancode to KeyCode conversion (SDL scancode → unified KeyCode int)
proc scancodeToKeyCode(scancode: int): int =
  ## Convert SDL scancode to unified input system KeyCode (int)
  ## Maps to ASCII codes for printable keys, special codes (1000+) for others
  case scancode
  # Special keys
  of 41: return KEY_ESCAPE.int      # SDL_SCANCODE_ESCAPE
  of 40: return KEY_RETURN.int      # SDL_SCANCODE_RETURN
  of 44: return KEY_SPACE.int       # SDL_SCANCODE_SPACE
  of 42: return KEY_BACKSPACE.int   # SDL_SCANCODE_BACKSPACE
  of 43: return KEY_TAB.int         # SDL_SCANCODE_TAB
  
  # Arrow keys
  of 82: return KEY_UP.int          # SDL_SCANCODE_UP
  of 81: return KEY_DOWN.int        # SDL_SCANCODE_DOWN
  of 80: return KEY_LEFT.int        # SDL_SCANCODE_LEFT
  of 79: return KEY_RIGHT.int       # SDL_SCANCODE_RIGHT
  
  # Navigation
  of 74: return KEY_HOME.int        # SDL_SCANCODE_HOME
  of 77: return KEY_END.int         # SDL_SCANCODE_END
  of 75: return KEY_PAGEUP.int      # SDL_SCANCODE_PAGEUP
  of 78: return KEY_PAGEDOWN.int    # SDL_SCANCODE_PAGEDOWN
  of 73: return KEY_INSERT.int      # SDL_SCANCODE_INSERT
  of 76: return KEY_DELETE.int      # SDL_SCANCODE_DELETE
  
  # Letters (A-Z) → ASCII uppercase (65-90)
  of 4: return 65   # A
  of 5: return 66   # B
  of 6: return 67   # C
  of 7: return 68   # D
  of 8: return 69   # E
  of 9: return 70   # F
  of 10: return 71  # G
  of 11: return 72  # H
  of 12: return 73  # I
  of 13: return 74  # J
  of 14: return 75  # K
  of 15: return 76  # L
  of 16: return 77  # M
  of 17: return 78  # N
  of 18: return 79  # O
  of 19: return 80  # P
  of 20: return 81  # Q
  of 21: return 82  # R
  of 22: return 83  # S
  of 23: return 84  # T
  of 24: return 85  # U
  of 25: return 86  # V
  of 26: return 87  # W
  of 27: return 88  # X
  of 28: return 89  # Y
  of 29: return 90  # Z
  
  # Numbers (0-9) → ASCII (48-57)
  of 30: return 49  # 1
  of 31: return 50  # 2
  of 32: return 51  # 3
  of 33: return 52  # 4
  of 34: return 53  # 5
  of 35: return 54  # 6
  of 36: return 55  # 7
  of 37: return 56  # 8
  of 38: return 57  # 9
  of 39: return 48  # 0
  
  # Punctuation and symbols (scancodes for US QWERTY layout)
  of 45: return 45   # - (minus)
  of 46: return 61   # = (equals)
  of 47: return 91   # [ (left bracket)
  of 48: return 93   # ] (right bracket)
  of 49: return 92   # \ (backslash)
  of 51: return 59   # ; (semicolon)
  of 52: return 39   # ' (apostrophe)
  of 53: return 96   # ` (grave accent / backtick)
  of 54: return 44   # , (comma)
  of 55: return 46   # . (period)
  of 56: return 47   # / (forward slash)
  
  # Function keys → Special codes (1100+)
  of 58: return KEY_F1.int
  of 59: return KEY_F2.int
  of 60: return KEY_F3.int
  of 61: return KEY_F4.int
  of 62: return KEY_F5.int
  of 63: return KEY_F6.int
  of 64: return KEY_F7.int
  of 65: return KEY_F8.int
  of 66: return KEY_F9.int
  of 67: return KEY_F10.int
  of 68: return KEY_F11.int
  of 69: return KEY_F12.int
  
  else: return 0

proc pollInput*(handler: var SDL3InputHandler): seq[InputEvent] =
  ## Poll SDL3 events and convert to unified InputEvents
  result = @[]
  var event: SDL_Event
  
  while SDL_PollEvent(addr event):
    case event.type_field
    of SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
      # Window close button pressed - generate quit event as ESC key
      result.add(InputEvent(
        kind: KeyEvent,
        keyCode: 27,  # KEY_ESCAPE
        keyMods: {},
        keyAction: Press
      ))
    
    of SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
      let scancode = getEventScancode(addr event)
      let keyCode = scancodeToKeyCode(scancode)
      
      if keyCode == 0:
        # Unknown scancode - log it for debugging (only in dev builds)
        when not defined(release):
          echo "Unknown SDL scancode: ", scancode
        continue  # Skip unknown key
      
      let action = if event.type_field == SDL_EVENT_KEY_DOWN: Press else: Release
      
      # Get current modifier state
      let sdlMods = SDL_GetModState()
      let mods = sdlModsToSet(sdlMods)
      let hasShift = (sdlMods and SDL_KMOD_SHIFT) != 0
      
      # Generate appropriate event based on key type and action
      if isPrintableKey(keyCode):
        # Printable key - generate TextEvent only on Press
        if action == Press:
          let charText = applyShiftToChar(keyCode, hasShift)
          result.add(InputEvent(
            kind: TextEvent,
            text: charText,
            textMods: mods
          ))
        # For Release, generate KeyEvent (apps that need key-up detection)
        else:
          result.add(InputEvent(
            kind: KeyEvent,
            keyCode: keyCode,
            keyMods: mods,
            keyAction: action
          ))
      else:
        # Special key - generate KeyEvent for both Press and Release
        result.add(InputEvent(
          kind: KeyEvent,
          keyCode: keyCode,
          keyMods: mods,
          keyAction: action
        ))
    
    of SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
      let button = getEventMouseButton(addr event)
      let pos = getEventMousePos(addr event)
      # Convert pixel coordinates to cell coordinates (8x16 character cells)
      let cellX = pos.x div 8
      let cellY = pos.y div 16
      
      # Map SDL button to TerminalMouseButton
      let btn = case button
        of 1: Left
        of 2: Middle
        of 3: Right
        else: Unknown
      
      let action = if event.type_field == SDL_EVENT_MOUSE_BUTTON_DOWN: Press else: Release
      
      # Get current modifier state for mouse events too
      let sdlMods = SDL_GetModState()
      let mods = sdlModsToSet(sdlMods)
      
      result.add(InputEvent(
        kind: MouseEvent,
        button: btn,
        mouseX: cellX,
        mouseY: cellY,
        mods: mods,
        action: action
      ))
    
    of SDL_EVENT_MOUSE_MOTION:
      let pos = getEventMousePos(addr event)
      let cellX = pos.x div 8
      let cellY = pos.y div 16
      
      # Get modifiers for mouse move too
      let sdlMods = SDL_GetModState()
      let mods = sdlModsToSet(sdlMods)
      
      result.add(InputEvent(
        kind: MouseMoveEvent,
        moveX: cellX,
        moveY: cellY,
        moveMods: mods
      ))
    
    of SDL_EVENT_MOUSE_WHEEL:
      let wheelY = getEventMouseWheel(addr event)
      let pos = getEventMousePos(addr event)
      let cellX = pos.x div 8
      let cellY = pos.y div 16
      
      # Get modifiers for wheel events
      let sdlMods = SDL_GetModState()
      let mods = sdlModsToSet(sdlMods)
      
      # Wheel events as mouse button press
      let btn = if wheelY > 0: ScrollUp else: ScrollDown
      
      result.add(InputEvent(
        kind: MouseEvent,
        button: btn,
        mouseX: cellX,
        mouseY: cellY,
        mods: mods,
        action: Press
      ))
    
    of SDL_EVENT_WINDOW_RESIZED:
      # Use stored dimensions
      result.add(InputEvent(
        kind: ResizeEvent,
        newWidth: handler.cellWidth,
        newHeight: handler.cellHeight
      ))
    
    else:
      discard  # Ignore other event types
  
  # Apply normalization to ensure consistent behavior
  result = normalizeEvents(result)
