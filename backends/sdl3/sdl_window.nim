## SDL3 Window and Input Management

import sdl3_bindings
import sdl_canvas
import sdl_input

export KeyCode, keyCodeToString  # Export input mapping types

type
  SDLInputEvent* = object
    kind*: SDLInputEventKind
    key*: KeyCode  # Mapped key code
    scancode*: int  # Raw SDL scancode
    ch*: string
    mouseX*: int    # Mouse X position
    mouseY*: int    # Mouse Y position
    mouseButton*: int  # Mouse button (1=left, 2=middle, 3=right)
  
  SDLInputEventKind* = enum
    SDLQuit
    SDLKeyDown
    SDLKeyUp
    SDLMouseClick
    SDLMouseRelease
    SDLMouseMove
    SDLResize
    SDLUnknown

proc getEventMouseButton(event: ptr SDL_Event): int =
  ## Extract mouse button from SDL event padding
  ## SDL3 MouseButtonEvent: button is uint8 at offset 24
  ## Structure: type(0) reserved(4) timestamp(8) windowID(16) which(20) button(24) down(25) clicks(26) pad(27) x(28) y(32)
  let buttonPtr = cast[ptr uint8](cast[uint](event) + 24)
  result = buttonPtr[].int

proc getEventMousePos(event: ptr SDL_Event): tuple[x, y: int] =
  ## Extract mouse position from SDL event padding  
  ## SDL3 MouseButtonEvent/MouseMotionEvent: x at offset 28, y at offset 32 (both float)
  ## Structure: ...which(20) [button fields for click events](24-27) x(28) y(32)
  let xPtr = cast[ptr cfloat](cast[uint](event) + 28)
  let yPtr = cast[ptr cfloat](cast[uint](event) + 32)
  result.x = xPtr[].int
  result.y = yPtr[].int

proc getEventMouseWheel(event: ptr SDL_Event): cfloat =
  ## Extract mouse wheel Y direction from SDL event
  ## SDL3 MouseWheelEvent: ...windowID(16) which(20) x(24) y(28) direction(32)
  ## Y > 0 = scroll up, Y < 0 = scroll down
  let yPtr = cast[ptr cfloat](cast[uint](event) + 28)
  result = yPtr[]

proc pollEvents*(canvas: SDLCanvas): seq[SDLInputEvent] =
  ## Poll all pending SDL events and convert to SDLInputEvents
  result = @[]
  var event: SDL_Event
  var eventCount = 0
  
  while SDL_PollEvent(addr event):
    eventCount.inc
    case event.type_field
    of SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
      result.add(SDLInputEvent(kind: SDLQuit))
    
    of SDL_EVENT_KEY_DOWN:
      let scancode = getEventScancode(addr event)
      let keycode = scancodeToKeyCode(scancode)
      result.add(SDLInputEvent(kind: SDLKeyDown, key: keycode, scancode: scancode))
    
    of SDL_EVENT_KEY_UP:
      let scancode = getEventScancode(addr event)
      let keycode = scancodeToKeyCode(scancode)
      result.add(SDLInputEvent(kind: SDLKeyUp, key: keycode, scancode: scancode))
    
    of SDL_EVENT_MOUSE_BUTTON_DOWN:
      let button = getEventMouseButton(addr event)
      let pos = getEventMousePos(addr event)
      result.add(SDLInputEvent(kind: SDLMouseClick, mouseButton: button, 
                               mouseX: pos.x, mouseY: pos.y))
    
    of SDL_EVENT_MOUSE_BUTTON_UP:
      let button = getEventMouseButton(addr event)
      let pos = getEventMousePos(addr event)
      result.add(SDLInputEvent(kind: SDLMouseRelease, mouseButton: button,
                               mouseX: pos.x, mouseY: pos.y))
    
    of SDL_EVENT_MOUSE_MOTION:
      let pos = getEventMousePos(addr event)
      result.add(SDLInputEvent(kind: SDLMouseMove, mouseX: pos.x, mouseY: pos.y))
    
    of SDL_EVENT_MOUSE_WHEEL:
      let wheelY = getEventMouseWheel(addr event)
      let pos = getEventMousePos(addr event)
      # Wheel Y > 0 = scroll up, Y < 0 = scroll down
      # Treat as mouse click with special button type
      let button = if wheelY > 0: 4 else: 5  # 4=ScrollUp, 5=ScrollDown
      result.add(SDLInputEvent(kind: SDLMouseClick, mouseButton: button,
                               mouseX: pos.x, mouseY: pos.y))
    
    of SDL_EVENT_WINDOW_RESIZED:
      # Update canvas size
      var w, h: cint
      discard SDL_GetWindowSize(canvas.window, addr w, addr h)
      canvas.width = w.int
      canvas.height = h.int
      result.add(SDLInputEvent(kind: SDLResize))
    
    else:
      result.add(SDLInputEvent(kind: SDLUnknown))

proc waitEvent*(canvas: SDLCanvas, timeoutMs: int = -1): SDLInputEvent =
  ## Wait for a single event (blocks until event arrives or timeout)
  var event: SDL_Event
  
  let hasEvent = if timeoutMs < 0:
    SDL_WaitEvent(addr event)
  else:
    SDL_WaitEventTimeout(addr event, timeoutMs.int32)
  
  if not hasEvent:
    return SDLInputEvent(kind: SDLUnknown)
  
  case event.type_field
  of SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
    return SDLInputEvent(kind: SDLQuit)
  of SDL_EVENT_KEY_DOWN:
    let scancode = getEventScancode(addr event)
    let keycode = scancodeToKeyCode(scancode)
    return SDLInputEvent(kind: SDLKeyDown, key: keycode, scancode: scancode)
  of SDL_EVENT_KEY_UP:
    let scancode = getEventScancode(addr event)
    let keycode = scancodeToKeyCode(scancode)
    return SDLInputEvent(kind: SDLKeyUp, key: keycode, scancode: scancode)
  of SDL_EVENT_WINDOW_RESIZED:
    var w, h: cint
    discard SDL_GetWindowSize(canvas.window, addr w, addr h)
    canvas.width = w.int
    canvas.height = h.int
    return SDLInputEvent(kind: SDLResize)
  else:
    return SDLInputEvent(kind: SDLUnknown)
