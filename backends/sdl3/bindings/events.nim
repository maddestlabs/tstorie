## SDL3 Events - Event handling and input

import build_config
import types
export types

const sdlHeader = "SDL3/SDL.h"

# Event types
const
  SDL_EVENT_QUIT* = 0x100'u32
  SDL_EVENT_KEY_DOWN* = 0x300'u32
  SDL_EVENT_KEY_UP* = 0x301'u32
  SDL_EVENT_MOUSE_MOTION* = 0x400'u32
  SDL_EVENT_MOUSE_BUTTON_DOWN* = 0x401'u32
  SDL_EVENT_MOUSE_BUTTON_UP* = 0x402'u32
  SDL_EVENT_MOUSE_WHEEL* = 0x403'u32
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

# Keyboard modifiers (SDL_Keymod)
const
  SDL_KMOD_NONE* = 0x0000'u16
  SDL_KMOD_LSHIFT* = 0x0001'u16
  SDL_KMOD_RSHIFT* = 0x0002'u16
  SDL_KMOD_SHIFT* = 0x0003'u16  # LSHIFT | RSHIFT
  SDL_KMOD_LCTRL* = 0x0040'u16
  SDL_KMOD_RCTRL* = 0x0080'u16
  SDL_KMOD_CTRL* = 0x00C0'u16   # LCTRL | RCTRL
  SDL_KMOD_LALT* = 0x0100'u16
  SDL_KMOD_RALT* = 0x0200'u16
  SDL_KMOD_ALT* = 0x0300'u16    # LALT | RALT
  SDL_KMOD_LGUI* = 0x0400'u16   # Windows/Command key
  SDL_KMOD_RGUI* = 0x0800'u16
  SDL_KMOD_GUI* = 0x0C00'u16    # LGUI | RGUI

type
  SDL_Event* {.importc, header: sdlHeader.} = object
    type_field* {.importc: "type".}: uint32
    timestamp*: uint64
    # Union of different event types - we'll access fields based on type
    padding*: array[128, uint8]  # Ensure enough space for all event types

# Event functions
proc SDL_PollEvent*(event: ptr SDL_Event): bool {.importc, header: sdlHeader.}
proc SDL_WaitEvent*(event: ptr SDL_Event): bool {.importc, header: sdlHeader.}
proc SDL_WaitEventTimeout*(event: ptr SDL_Event, timeoutMS: int32): bool {.importc, header: "SDL3/SDL_events.h".}
proc SDL_GetModState*(): uint16 {.importc, header: sdlHeader.}
