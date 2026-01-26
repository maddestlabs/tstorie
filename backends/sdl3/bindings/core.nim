## SDL3 Core - Initialization, window management, timing

import build_config
import types
export types

# For Emscripten, use the main SDL.h header
when defined(emscripten):
  const sdlHeader = "SDL3/SDL.h"
else:
  const sdlHeader = "SDL3/SDL.h"

# Initialization flags
const
  SDL_INIT_VIDEO* = 0x00000020'u32
  SDL_INIT_EVENTS* = 0x00004000'u32
  
  # Window flags
  SDL_WINDOW_RESIZABLE* = 0x00000020'u64
  SDL_WINDOW_FULLSCREEN* = 0x00000001'u64
  SDL_WINDOW_OPENGL* = 0x00000002'u64

# Core initialization
proc SDL_Init*(flags: uint32): cint {.importc, header: sdlHeader.}
proc SDL_InitSubSystem*(flags: uint32): cint {.importc, header: sdlHeader.}
proc SDL_Quit*() {.importc, header: sdlHeader.}
proc SDL_SetHint*(name: cstring, value: cstring): bool {.importc, header: sdlHeader.}

# Window management
proc SDL_CreateWindow*(title: cstring, w, h: cint, flags: uint64): ptr SDL_Window {.importc, header: sdlHeader.}
proc SDL_DestroyWindow*(window: ptr SDL_Window) {.importc, header: sdlHeader.}
proc SDL_GetWindowSize*(window: ptr SDL_Window, w, h: ptr cint): bool {.importc, header: sdlHeader.}
proc SDL_SetWindowSize*(window: ptr SDL_Window, w, h: cint): bool {.importc, header: sdlHeader.}

# Error handling
proc SDL_GetError*(): cstring {.importc, header: sdlHeader.}

# Timing
proc SDL_Delay*(ms: uint32) {.importc, header: "SDL3/SDL_timer.h".}

# Emscripten canvas support
when defined(emscripten):
  proc emscripten_get_canvas_element_size*(target: cstring, width, height: ptr cint): cint {.importc, header: "emscripten/html5.h".}
