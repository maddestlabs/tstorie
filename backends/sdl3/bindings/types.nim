## SDL3 Core Types

import build_config

type
  # Opaque types (incomplete structs - SDL3 manages the memory)
  SDL_Window* {.importc, header: "SDL3/SDL.h", incompletestruct.} = object
  SDL_Renderer* {.importc, header: "SDL3/SDL.h", incompletestruct.} = object
  SDL_Texture* {.importc, header: "SDL3/SDL.h", incompletestruct.} = object
  SDL_Surface* {.importc, header: "SDL3/SDL_surface.h".} = object
    flags*: uint32
    format*: pointer
    w*, h*: cint
    pitch*: cint
    pixels*: pointer
    refcount*: cint
    reserved*: pointer
  
  # Geometric types
  SDL_FRect* {.importc, header: "SDL3/SDL_rect.h".} = object
    x*, y*, w*, h*: cfloat
  
  SDL_Rect* {.importc, header: "SDL3/SDL_rect.h".} = object
    x*, y*, w*, h*: cint
  
  # Color
  SDL_Color* {.importc, header: "SDL3/SDL_pixels.h".} = object
    r*, g*, b*, a*: uint8
