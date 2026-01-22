## SDL3 Render - 2D rendering and drawing

import build_config
import types
export types

# Renderer creation
proc SDL_CreateRenderer*(window: ptr SDL_Window, name: cstring): ptr SDL_Renderer {.importc, header: "SDL3/SDL_render.h".}
proc SDL_DestroyRenderer*(renderer: ptr SDL_Renderer) {.importc, header: "SDL3/SDL_render.h".}

# Drawing state
proc SDL_SetRenderDrawColor*(renderer: ptr SDL_Renderer, r, g, b, a: uint8): bool {.importc, header: "SDL3/SDL_render.h".}
proc SDL_SetRenderViewport*(renderer: ptr SDL_Renderer, rect: ptr SDL_Rect): bool {.importc, header: "SDL3/SDL_render.h".}

# Drawing operations
proc SDL_RenderClear*(renderer: ptr SDL_Renderer): bool {.importc, header: "SDL3/SDL_render.h".}
proc SDL_RenderFillRect*(renderer: ptr SDL_Renderer, rect: ptr SDL_FRect): bool {.importc, header: "SDL3/SDL_render.h".}
proc SDL_RenderLine*(renderer: ptr SDL_Renderer, x1, y1, x2, y2: cfloat): bool {.importc, header: "SDL3/SDL_render.h".}
proc SDL_RenderPoint*(renderer: ptr SDL_Renderer, x, y: cfloat): bool {.importc, header: "SDL3/SDL_render.h".}
proc SDL_RenderPresent*(renderer: ptr SDL_Renderer): bool {.importc, header: "SDL3/SDL_render.h".}

# Texture management
proc SDL_CreateTextureFromSurface*(renderer: ptr SDL_Renderer, surface: ptr SDL_Surface): ptr SDL_Texture {.importc, header: "SDL3/SDL_render.h".}
proc SDL_DestroyTexture*(texture: ptr SDL_Texture) {.importc, header: "SDL3/SDL_render.h".}
proc SDL_RenderTexture*(renderer: ptr SDL_Renderer, texture: ptr SDL_Texture, srcrect: ptr SDL_FRect, dstrect: ptr SDL_FRect): bool {.importc, header: "SDL3/SDL_render.h".}

# Surface management
proc SDL_DestroySurface*(surface: ptr SDL_Surface) {.importc, header: "SDL3/SDL_surface.h".}

# Debug text rendering (built into SDL3, no TTF needed)
proc SDL_RenderDebugText*(renderer: ptr SDL_Renderer, x, y: cfloat, text: cstring): bool {.importc, header: "SDL3/SDL_render.h".}
