## SDL3 Events - Event handling and input

import build_config
import types
export types

# Event types
const
  SDL_EVENT_QUIT* = 0x100'u32
  SDL_EVENT_KEY_DOWN* = 0x300'u32
  SDL_EVENT_KEY_UP* = 0x301'u32
  SDL_EVENT_MOUSE_MOTION* = 0x400'u32
  SDL_EVENT_MOUSE_BUTTON_DOWN* = 0x401'u32
  SDL_EVENT_MOUSE_BUTTON_UP* = 0x402'u32
  SDL_EVENT_WINDOW_RESIZED* = 0x202'u32
  SDL_EVENT_WINDOW_CLOSE_REQUESTED* = 0x203'u32

# Keyboard scancodes (SDL3 uses scancodes, not keycodes)
const
  SDL_SCANCODE_ESCAPE* = 41
  SDL_SCANCODE_RETURN* = 40
  SDL_SCANCODE_SPACE* = 44
  SDL_SCANCODE_BACKSPACE* = 42
  SDL_SCANCODE_TAB* = 43
  SDL_SCANCODE_UP* = 82
  SDL_SCANCODE_DOWN* = 81
  SDL_SCANCODE_LEFT* = 80
  SDL_SCANCODE_RIGHT* = 79

type
  SDL_Event* {.importc, header: "SDL3/SDL_events.h".} = object
    type_field* {.importc: "type".}: uint32
    timestamp*: uint64
    # Union of different event types - we'll access fields based on type
    padding*: array[128, uint8]  # Ensure enough space for all event types

# Event functions
proc SDL_PollEvent*(event: ptr SDL_Event): bool {.importc, header: "SDL3/SDL_events.h".}
proc SDL_WaitEvent*(event: ptr SDL_Event): bool {.importc, header: "SDL3/SDL_events.h".}
proc SDL_WaitEventTimeout*(event: ptr SDL_Event, timeoutMS: int32): bool {.importc, header: "SDL3/SDL_events.h".}
