## SDL3_ttf - TrueType font rendering

import build_config
import types
export types

when not defined(coreOnly):
  const ttfHeader = "SDL3_ttf/SDL_ttf.h"  # SDL3_ttf for all platforms

  type
    TTF_Font* {.importc, header: ttfHeader, incompletestruct.} = object

  # TTF initialization
  proc TTF_Init*(): bool {.importc, header: ttfHeader.}
  proc TTF_Quit*() {.importc, header: ttfHeader.}
else:
  # Core-only build: Provide stub types
  type
    TTF_Font* = object

when not defined(coreOnly):
  # Font management
  proc TTF_OpenFont*(file: cstring, ptsize: cfloat): ptr TTF_Font {.importc, header: ttfHeader.}
  proc TTF_CloseFont*(font: ptr TTF_Font) {.importc, header: ttfHeader.}
  
  # Font rendering hints
  const
    TTF_HINTING_NORMAL* = 0
    TTF_HINTING_LIGHT* = 1
    TTF_HINTING_MONO* = 2
    TTF_HINTING_NONE* = 3
    TTF_HINTING_LIGHT_SUBPIXEL* = 4
  
  proc TTF_SetFontHinting*(font: ptr TTF_Font, hinting: cint) {.importc, header: ttfHeader.}
  proc TTF_GetFontHinting*(font: ptr TTF_Font): cint {.importc, header: ttfHeader.}

  # Text rendering (creates SDL_Surface that can be converted to texture)
  proc TTF_RenderText_Solid*(font: ptr TTF_Font, text: cstring, length: csize_t, fg: SDL_Color): ptr SDL_Surface {.importc, header: ttfHeader.}
  proc TTF_RenderText_Blended*(font: ptr TTF_Font, text: cstring, length: csize_t, fg: SDL_Color): ptr SDL_Surface {.importc, header: ttfHeader.}
  proc TTF_RenderGlyph_Solid*(font: ptr TTF_Font, ch: uint32, fg: SDL_Color): ptr SDL_Surface {.importc, header: ttfHeader.}
