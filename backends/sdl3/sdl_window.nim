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
  
  SDLInputEventKind* = enum
    SDLQuit
    SDLKeyDown
    SDLKeyUp
    SDLMouseMove
    SDLResize
    SDLUnknown

proc pollEvents*(canvas: SDLCanvas): seq[SDLInputEvent] =
  ## Poll all pending SDL events and convert to SDLInputEvents
  result = @[]
  var event: SDL_Event
  
  while SDL_PollEvent(addr event):
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
