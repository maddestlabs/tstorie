## SDL3 Canvas Implementation
## Pixel-based rendering buffer using SDL3

import sdl3_bindings
import sdl_fonts
import ../../src/types  # For Style type
import std/options

type
  SDLCanvas* = ref object
    window*: ptr SDL_Window
    renderer*: ptr SDL_Renderer
    width*: int
    height*: int
    bgColor*: tuple[r, g, b: uint8]
    clipRect*: Option[tuple[x, y, w, h: int]]
    offset*: tuple[x, y: int]
    font*: ptr TTF_Font  # Current font for text rendering
    useTTF*: bool        # Whether to use TTF fonts or debug text
  
  SDLColor* = tuple[r, g, b: uint8]

proc newSDLCanvas*(width, height: int, title: string = "tStorie"): SDLCanvas =
  ## Create a new SDL3 canvas with window and renderer
  result = SDLCanvas()
  result.width = width
  result.height = height
  result.clipRect = none(tuple[x, y, w, h: int])
  result.offset = (0, 0)
  result.useTTF = true
  
  # Initialize SDL
  if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS) != 0:
    echo "Failed to initialize SDL: ", SDL_GetError()
    return nil
  
  # Initialize TTF fonts
  sdl_fonts.init()
  result.font = getDefaultFont()
  if result.font.isNil:
    echo "[Canvas] Warning: No TTF font available, falling back to debug text"
    result.useTTF = false
  
  # Handle Emscripten canvas size
  when defined(emscripten):
    var canvasW, canvasH: cint
    discard emscripten_get_canvas_element_size("#canvas", addr canvasW, addr canvasH)
    result.width = canvasW.int
    result.height = canvasH.int
  
  # Create window
  result.window = SDL_CreateWindow(
    title.cstring,
    result.width.cint,
    result.height.cint,
    SDL_WINDOW_RESIZABLE
  )
  
  if result.window.isNil:
    echo "Failed to create window: ", SDL_GetError()
    SDL_Quit()
    return nil
  
  # Create renderer
  result.renderer = SDL_CreateRenderer(result.window, nil)
  
  if result.renderer.isNil:
    echo "Failed to create renderer: ", SDL_GetError()
    SDL_DestroyWindow(result.window)
    SDL_Quit()
    return nil

proc shutdown*(canvas: SDLCanvas) =
  ## Clean up SDL resources
  sdl_fonts.shutdown()
  if not canvas.renderer.isNil:
    SDL_DestroyRenderer(canvas.renderer)
  if not canvas.window.isNil:
    SDL_DestroyWindow(canvas.window)
  SDL_Quit()

# Implement RenderBuffer interface
proc write*(canvas: SDLCanvas, x, y: int, ch: string, style: Style) =
  ## Write a character at pixel coordinates
  let adjX = x + canvas.offset.x
  let adjY = y + canvas.offset.y
  
  if canvas.useTTF and not canvas.font.isNil:
    # Use TTF font rendering
    let color = (style.fg.r, style.fg.g, style.fg.b)
    discard renderText(canvas.renderer, canvas.font, ch, adjX.float, adjY.float, color)
  else:
    # Fallback to debug text
    if not SDL_RenderDebugText(canvas.renderer, adjX.cfloat, adjY.cfloat, ch.cstring):
      discard

proc writeText*(canvas: SDLCanvas, x, y: int, text: string, style: Style) =
  ## Write text at pixel coordinates
  let adjX = x + canvas.offset.x
  let adjY = y + canvas.offset.y
  
  if canvas.useTTF and not canvas.font.isNil:
    # Use TTF font rendering with caching
    let color = (style.fg.r, style.fg.g, style.fg.b)
    discard renderText(canvas.renderer, canvas.font, text, adjX.float, adjY.float, color)
  else:
    # Fallback to debug text
    if not SDL_RenderDebugText(canvas.renderer, adjX.cfloat, adjY.cfloat, text.cstring):
      discard

proc fillRect*(canvas: SDLCanvas, x, y, width, height: int, ch: string, style: Style) =
  ## Fill a rectangle with color from style
  let adjX = x + canvas.offset.x
  let adjY = y + canvas.offset.y
  
  let color = style.bg  # Use background color for fill
  discard SDL_SetRenderDrawColor(canvas.renderer, color.r, color.g, color.b, 255)
  var rect = SDL_FRect(x: adjX.cfloat, y: adjY.cfloat, w: width.cfloat, h: height.cfloat)
  discard SDL_RenderFillRect(canvas.renderer, addr rect)

proc clear*(canvas: SDLCanvas, bgColor: tuple[r, g, b: uint8]) =
  ## Clear the canvas to specified background color
  discard SDL_SetRenderDrawColor(canvas.renderer, bgColor.r, bgColor.g, bgColor.b, 255)
  discard SDL_RenderClear(canvas.renderer)

proc clearTransparent*(canvas: SDLCanvas) =
  ## Clear with transparency (SDL3 doesn't really support this, use black)
  discard SDL_SetRenderDrawColor(canvas.renderer, 0, 0, 0, 0)
  discard SDL_RenderClear(canvas.renderer)

proc getCell*(canvas: SDLCanvas, x, y: int): tuple[ch: string, style: Style] =
  ## Get cell content (not really supported in SDL3, return empty)
  result = ("", Style())

proc setClip*(canvas: SDLCanvas, x, y, w, h: int) =
  ## Set clipping rectangle
  canvas.clipRect = some((x, y, w, h))
  var rect = SDL_Rect(x: x.cint, y: y.cint, w: w.cint, h: h.cint)
  discard SDL_SetRenderViewport(canvas.renderer, addr rect)

proc clearClip*(canvas: SDLCanvas) =
  ## Clear clipping rectangle
  canvas.clipRect = none(tuple[x, y, w, h: int])
  discard SDL_SetRenderViewport(canvas.renderer, nil)

proc setOffset*(canvas: SDLCanvas, x, y: int) =
  ## Set rendering offset
  canvas.offset = (x, y)

proc present*(canvas: SDLCanvas) =
  ## Present the rendered frame to the screen
  discard SDL_RenderPresent(canvas.renderer)

proc setBackgroundColor*(canvas: SDLCanvas, r, g, b: uint8) =
  ## Set the background color for clear operations
  canvas.bgColor = (r, g, b)

proc getSize*(canvas: SDLCanvas): tuple[width, height: int] =
  ## Get current canvas size
  var w, h: cint
  discard SDL_GetWindowSize(canvas.window, addr w, addr h)
  result = (w.int, h.int)

# Font management functions
proc setFont*(canvas: SDLCanvas, fontPath: string, size: float = 16.0) =
  ## Load and set a custom font
  let newFont = loadFont(fontPath, size)
  if not newFont.isNil:
    canvas.font = newFont
    canvas.useTTF = true
  else:
    echo "[Canvas] Failed to load font: ", fontPath

proc setFontSize*(canvas: SDLCanvas, size: float) =
  ## Change font size (reloads current font)
  if canvas.font.isNil:
    canvas.font = getDefaultFont()
  # Note: Font size change requires reloading - simplified for now
  canvas.useTTF = not canvas.font.isNil

proc resetFont*(canvas: SDLCanvas) =
  ## Reset to default system font
  canvas.font = getDefaultFont()
  canvas.useTTF = not canvas.font.isNil

proc measureText*(canvas: SDLCanvas, text: string): tuple[width, height: int] =
  ## Measure text dimensions with current font
  if canvas.font.isNil:
    return (0, 0)
  return sdl_fonts.measureText(canvas.font, text)

proc clearTextCache*(canvas: SDLCanvas) =
  ## Clear cached text textures
  sdl_fonts.clearCache()
