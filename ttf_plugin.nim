# TTF Plugin for TStorie
# This is compiled as a separate SIDE_MODULE that gets loaded dynamically
# when unicode or complex text is detected in the content.

import backends/sdl3/bindings/ttf
import backends/sdl3/bindings/core
import backends/sdl3/bindings/render
import backends/sdl3/bindings/types

# Forward declare SDL_SetTextureScaleMode for linear filtering
proc SDL_SetTextureScaleMode(texture: ptr SDL_Texture, scaleMode: cint): bool {.importc, header: "SDL3/SDL_render.h".}

# Global font handle for the plugin
var gPluginFont: ptr TTF_Font = nil
var gPluginInitialized = false

proc initPlugin*(): bool {.exportc: "ttfInitPlugin", dynlib.} =
  ## Initialize the TTF plugin
  ## This is called automatically when the plugin loads
  echo "[TTF Plugin] Initializing..."
  
  if gPluginInitialized:
    echo "[TTF Plugin] Already initialized"
    return true
  
  # Initialize SDL_ttf
  if not TTF_Init():
    echo "[TTF Plugin] Failed to initialize SDL_ttf"
    return false
  
  # Load the font
  const fontPath = "/fonts/3270-Regular.ttf"
  const fontSize = 14.cfloat
  
  gPluginFont = TTF_OpenFont(fontPath.cstring, fontSize)
  if gPluginFont.isNil:
    echo "[TTF Plugin] Failed to load font from: ", fontPath
    return false
  
  echo "[TTF Plugin] Font loaded successfully: ", fontPath
  gPluginInitialized = true
  return true

proc getFontHandle*(): pointer {.exportc: "ttfGetFontHandle", dynlib.} =
  ## Get the font handle from the plugin
  ## Called by the main module to hook up rendering
  return cast[pointer](gPluginFont)

proc renderText*(renderer: ptr SDL_Renderer, fontHandle: pointer, 
                 text: cstring, x: cfloat, y: cfloat,
                 r: uint8, g: uint8, b: uint8): bool {.exportc: "ttfRenderText", dynlib.} =
  ## Render text using TTF
  ## This is the main render function called from the core module
  ## Returns true on success, false on failure
  
  if fontHandle.isNil or text.isNil:
    return false
  
  let font = cast[ptr TTF_Font](fontHandle)
  
  # Create color
  var color: SDL_Color
  color.r = r
  color.g = g
  color.b = b
  color.a = 255
  
  # Calculate text length
  let textLen = csize_t(len($text))
  
  # Render text to surface
  let surface = TTF_RenderText_Blended(font, text, textLen, color)
  if surface.isNil:
    return false
  
  # Get surface dimensions
  let w = surface.w.cfloat
  let h = surface.h.cfloat
  
  # Create texture from surface
  let texture = SDL_CreateTextureFromSurface(renderer, surface)
  SDL_DestroySurface(surface)
  
  if texture.isNil:
    return false
  
  # Set linear filtering for smooth font rendering (fixes artifacts)
  discard SDL_SetTextureScaleMode(texture, 1)  # 1 = SDL_SCALEMODE_LINEAR
  
  # Set up destination rect
  var dstRect: SDL_FRect
  dstRect.x = x
  dstRect.y = y
  dstRect.w = w
  dstRect.h = h
  
  # Render texture
  let success = SDL_RenderTexture(renderer, texture, nil, addr dstRect)
  SDL_DestroyTexture(texture)
  
  return success

# Auto-initialize when plugin loads
when isMainModule:
  discard initPlugin()

