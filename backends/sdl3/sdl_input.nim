## SDL3 Keyboard Input Mapping
## Maps SDL scancodes to key names and provides key state tracking

import sdl3_bindings
import tables

type
  KeyCode* = enum
    KeyUnknown = 0
    KeyEscape, KeyReturn, KeySpace, KeyBackspace, KeyTab
    KeyUp, KeyDown, KeyLeft, KeyRight
    KeyHome, KeyEnd, KeyPageUp, KeyPageDown
    KeyInsert, KeyDelete
    KeyA, KeyB, KeyC, KeyD, KeyE, KeyF, KeyG, KeyH
    KeyI, KeyJ, KeyK, KeyL, KeyM, KeyN, KeyO, KeyP
    KeyQ, KeyR, KeyS, KeyT, KeyU, KeyV, KeyW, KeyX
    KeyY, KeyZ
    Key0, Key1, Key2, Key3, Key4, Key5, Key6, Key7, Key8, Key9
    KeyF1, KeyF2, KeyF3, KeyF4, KeyF5, KeyF6
    KeyF7, KeyF8, KeyF9, KeyF10, KeyF11, KeyF12
    KeyLeftShift, KeyRightShift
    KeyLeftCtrl, KeyRightCtrl
    KeyLeftAlt, KeyRightAlt

# SDL scancode to KeyCode mapping table
var scancodeMap: Table[int, KeyCode]

proc initKeycodeMap*() =
  ## Initialize scancode to keycode mapping
  scancodeMap = initTable[int, KeyCode]()
  
  # Special keys
  scancodeMap[SDL_SCANCODE_ESCAPE] = KeyEscape
  scancodeMap[SDL_SCANCODE_RETURN] = KeyReturn
  scancodeMap[SDL_SCANCODE_SPACE] = KeySpace
  scancodeMap[SDL_SCANCODE_BACKSPACE] = KeyBackspace
  scancodeMap[SDL_SCANCODE_TAB] = KeyTab
  
  # Arrow keys
  scancodeMap[SDL_SCANCODE_UP] = KeyUp
  scancodeMap[SDL_SCANCODE_DOWN] = KeyDown
  scancodeMap[SDL_SCANCODE_LEFT] = KeyLeft
  scancodeMap[SDL_SCANCODE_RIGHT] = KeyRight
  
  # Letter keys (A-Z)
  scancodeMap[4] = KeyA   # SDL_SCANCODE_A = 4
  scancodeMap[5] = KeyB
  scancodeMap[6] = KeyC
  scancodeMap[7] = KeyD
  scancodeMap[8] = KeyE
  scancodeMap[9] = KeyF
  scancodeMap[10] = KeyG
  scancodeMap[11] = KeyH
  scancodeMap[12] = KeyI
  scancodeMap[13] = KeyJ
  scancodeMap[14] = KeyK
  scancodeMap[15] = KeyL
  scancodeMap[16] = KeyM
  scancodeMap[17] = KeyN
  scancodeMap[18] = KeyO
  scancodeMap[19] = KeyP
  scancodeMap[20] = KeyQ
  scancodeMap[21] = KeyR
  scancodeMap[22] = KeyS
  scancodeMap[23] = KeyT
  scancodeMap[24] = KeyU
  scancodeMap[25] = KeyV
  scancodeMap[26] = KeyW
  scancodeMap[27] = KeyX
  scancodeMap[28] = KeyY
  scancodeMap[29] = KeyZ
  
  # Number keys (0-9)
  scancodeMap[30] = Key1  # SDL_SCANCODE_1 = 30
  scancodeMap[31] = Key2
  scancodeMap[32] = Key3
  scancodeMap[33] = Key4
  scancodeMap[34] = Key5
  scancodeMap[35] = Key6
  scancodeMap[36] = Key7
  scancodeMap[37] = Key8
  scancodeMap[38] = Key9
  scancodeMap[39] = Key0
  
  # Function keys (F1-F12)
  scancodeMap[58] = KeyF1  # SDL_SCANCODE_F1 = 58
  scancodeMap[59] = KeyF2
  scancodeMap[60] = KeyF3
  scancodeMap[61] = KeyF4
  scancodeMap[62] = KeyF5
  scancodeMap[63] = KeyF6
  scancodeMap[64] = KeyF7
  scancodeMap[65] = KeyF8
  scancodeMap[66] = KeyF9
  scancodeMap[67] = KeyF10
  scancodeMap[68] = KeyF11
  scancodeMap[69] = KeyF12
  
  # Navigation keys
  scancodeMap[74] = KeyHome     # SDL_SCANCODE_HOME
  scancodeMap[77] = KeyEnd      # SDL_SCANCODE_END
  scancodeMap[75] = KeyPageUp   # SDL_SCANCODE_PAGEUP
  scancodeMap[78] = KeyPageDown # SDL_SCANCODE_PAGEDOWN
  scancodeMap[73] = KeyInsert   # SDL_SCANCODE_INSERT
  scancodeMap[76] = KeyDelete   # SDL_SCANCODE_DELETE

proc scancodeToKeyCode*(scancode: int): KeyCode =
  ## Convert SDL scancode to KeyCode
  if scancodeMap.len == 0:
    initKeycodeMap()
  
  if scancodeMap.hasKey(scancode):
    return scancodeMap[scancode]
  else:
    return KeyUnknown

proc keyCodeToString*(key: KeyCode): string =
  ## Convert KeyCode to human-readable string
  case key
  of KeyEscape: "Escape"
  of KeyReturn: "Return"
  of KeySpace: "Space"
  of KeyBackspace: "Backspace"
  of KeyTab: "Tab"
  of KeyUp: "Up"
  of KeyDown: "Down"
  of KeyLeft: "Left"
  of KeyRight: "Right"
  of KeyHome: "Home"
  of KeyEnd: "End"
  of KeyPageUp: "PageUp"
  of KeyPageDown: "PageDown"
  of KeyInsert: "Insert"
  of KeyDelete: "Delete"
  of KeyA..KeyZ: $key  # Letter keys
  of Key0..Key9: $key  # Number keys
  of KeyF1..KeyF12: $key  # Function keys
  of KeyLeftShift: "LeftShift"
  of KeyRightShift: "RightShift"
  of KeyLeftCtrl: "LeftCtrl"
  of KeyRightCtrl: "RightCtrl"
  of KeyLeftAlt: "LeftAlt"
  of KeyRightAlt: "RightAlt"
  else: "Unknown"

# Helper to extract scancode from SDL_Event
proc getEventScancode*(event: ptr SDL_Event): int =
  ## Extract keyboard scancode from SDL_Event
  ## Note: This accesses the keyboard event structure within the union
  ## We need to read bytes 16-19 (after type and timestamp)
  
  # SDL_Event layout:
  # - type: uint32 (0-3)
  # - timestamp: uint64 (4-11)
  # - padding/window: uint32 (12-15)
  # - scancode: uint32 (16-19) for keyboard events
  
  if event.type_field == SDL_EVENT_KEY_DOWN or event.type_field == SDL_EVENT_KEY_UP:
    # Cast to access scancode field
    # In SDL3, keyboard events have scancode at a specific offset
    let paddingPtr = cast[ptr array[128, uint8]](event)
    let scancodePtr = cast[ptr uint32](addr paddingPtr[16])
    return scancodePtr[].int
  
  return 0
