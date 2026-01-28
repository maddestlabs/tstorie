## SDL3 Canvas Implementation
## Pixel-based rendering buffer using SDL3

import sdl3_bindings
when not defined(coreOnly):
  import sdl_fonts  # TTF fonts (excluded in core-only builds)

import ../../src/types  # For Style type, Cell, Layer
import std/[options, unicode, tables, algorithm]  # For UTF-8 rune iteration and layer system

const
  CHAR_WIDTH* = 8   # Character cell width in pixels
  CHAR_HEIGHT* = 16  # Character cell height in pixels

# Plugin function pointer types
type
  TTFRenderTextProc* = proc(renderer: ptr SDL_Renderer, fontHandle: pointer,
                            text: cstring, textLen: csize_t, x, y: cfloat, 
                            r, g, b: uint8): bool {.cdecl.}

# Global plugin state (runtime, not compile-time)
var gTTFRenderFunc*: TTFRenderTextProc = nil
var gTTFFontHandle*: pointer = nil

# Internal TTF rendering wrapper (when compiled in, not as plugin)
when not defined(coreOnly):
  proc internalTTFRender(renderer: ptr SDL_Renderer, fontHandle: pointer,
                         text: cstring, textLen: csize_t, x, y: cfloat, 
                         r, g, b: uint8): bool {.cdecl.} =
    ## Wrapper function that matches plugin signature - uses texture caching
    let font = cast[ptr TTF_Font](fontHandle)
    if font.isNil:
      return false
    let color = (r, g, b)
    # Convert cstring to string for caching
    let textStr = newString(textLen.int)
    if textLen > 0:
      copyMem(addr textStr[0], text, textLen.int)
    # Use cached renderText instead of raw for better performance
    return sdl_fonts.renderText(renderer, font, textStr, x.float, y.float, color)
  
  proc initTTFPointers(font: ptr TTF_Font) =
    ## Initialize global function pointers when TTF is compiled in
    if not font.isNil:
      gTTFFontHandle = cast[pointer](font)
      gTTFRenderFunc = internalTTFRender
      echo "[Canvas] TTF function pointers initialized"
    else:
      echo "[Canvas] ERROR: initTTFPointers called with nil font!"


type
  GlyphCache = object
    texture: ptr SDL_Texture  # Pre-rendered glyph texture with specific color
    srcRect: SDL_FRect        # Source rect in atlas (if using atlas)
    advance: int              # Character advance width
  
  GlyphKey = tuple[ch: string, r, g, b: uint8]  # Key includes character AND color
  
  SDLCanvas* = ref object
    window*: ptr SDL_Window
    renderer*: ptr SDL_Renderer
    terminalTexture*: ptr SDL_Texture  # Persistent texture (render target) for terminal content
    width*: int
    height*: int
    cellWidth*: int    # Width in character cells
    cellHeight*: int   # Height in character cells
    cells*: seq[Cell]  # Virtual terminal grid for final rendered output
    prevCells*: seq[Cell]  # Previous frame for dirty tracking (battery optimization)
    bgColor*: tuple[r, g, b: uint8]
    clipRect*: Option[tuple[x, y, w, h: int]]
    offset*: tuple[x, y: int]
    glyphCache*: Table[GlyphKey, GlyphCache]  # (Character + Color) -> cached texture
    firstFrame*: bool  # Track if this is the first frame (needs full clear)
    # NOTE: SDL3 uses gAppState.layers (shared with terminal backend)
    # No separate layer system needed - we just render the final composited buffer
    when not defined(coreOnly):
      font*: ptr TTF_Font  # Current font for text rendering (SDL3_ttf)
    useTTF*: bool        # Whether to use TTF fonts or debug text
  
  SDLColor* = tuple[r, g, b: uint8]

proc newSDLCanvas*(width, height: int, title: string = "tStorie"): SDLCanvas =
  ## Create a new SDL3 canvas with window and renderer
  result = SDLCanvas()
  result.width = width
  result.height = height
  result.clipRect = none(tuple[x, y, w, h: int])
  result.offset = (0, 0)
  result.glyphCache = initTable[GlyphKey, GlyphCache]()
  result.firstFrame = true  # First frame needs full clear
  
  # Calculate cell dimensions
  result.cellWidth = width div CHAR_WIDTH
  result.cellHeight = height div CHAR_HEIGHT
  
  # Initialize virtual terminal cell grid
  result.cells = newSeq[Cell](result.cellWidth * result.cellHeight)
  result.prevCells = newSeq[Cell](result.cellWidth * result.cellHeight)
  let defaultStyle = Style(fg: white(), bg: black(), bold: false)
  for i in 0 ..< result.cells.len:
    result.cells[i] = Cell(ch: " ", style: defaultStyle)
    result.prevCells[i] = Cell(ch: " ", style: defaultStyle)
  
  # NOTE: SDL3 uses gAppState.layers (shared with terminal backend)
  # No layer initialization needed here
  
  # Set hints BEFORE SDL_Init (required for Emscripten)
  when defined(emscripten):
    # Tell SDL3 to register event listeners on our canvas element
    discard SDL_SetHint("SDL_EMSCRIPTEN_KEYBOARD_ELEMENT", "canvas")
    discard SDL_SetHint("SDL_EMSCRIPTEN_ASYNCIFY", "0")
  
  # Initialize SDL (works on both native and Emscripten)
  if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS) < 0:
    echo "Failed to initialize SDL: ", SDL_GetError()
    return nil
  
  # Initialize TTF fonts (works on all platforms with pre-built SDL3_ttf)
  when not defined(coreOnly):
    sdl_fonts.init()
    when defined(emscripten):
      # Emscripten: Load preloaded font from /fonts/ (3270 has excellent Unicode/Kanji support)
      result.font = TTF_OpenFont("/fonts/3270-Regular.ttf", 16.0)
      if result.font.isNil:
        echo "[Canvas] Warning: Failed to load /fonts/3270-Regular.ttf, falling back to debug text"
        result.useTTF = false
      else:
        # Enable light hinting for better text quality
        TTF_SetFontHinting(result.font, TTF_HINTING_LIGHT)
        echo "[Canvas] TTF font loaded successfully: 3270-Regular.ttf"
        result.useTTF = true
        initTTFPointers(result.font)  # Initialize function pointers
    else:
      # Desktop: Try to load TTF fonts from system
      result.font = getDefaultFont()
      if result.font.isNil:
        echo "[Canvas] Warning: No TTF font available, falling back to debug text"
        result.useTTF = false
      else:
        result.useTTF = true
        initTTFPointers(result.font)  # Initialize function pointers
  else:
    # Core-only build: Always use debug text
    result.useTTF = false
    echo "[Canvas] Core-only build: Using debug text rendering (ASCII only)"
  
  # Handle Emscripten canvas size
  when defined(emscripten):
    var canvasW, canvasH: cint
    discard emscripten_get_canvas_element_size("#canvas", addr canvasW, addr canvasH)
    result.width = canvasW.int
    result.height = canvasH.int
    
    # Recalculate cell dimensions based on actual canvas size
    result.cellWidth = result.width div CHAR_WIDTH
    result.cellHeight = result.height div CHAR_HEIGHT
    
    # Resize the cell grid to match new dimensions
    result.cells = newSeq[Cell](result.cellWidth * result.cellHeight)
    result.prevCells = newSeq[Cell](result.cellWidth * result.cellHeight)
    for i in 0 ..< result.cells.len:
      result.cells[i] = Cell(ch: " ", style: defaultStyle)
      result.prevCells[i] = Cell(ch: " ", style: defaultStyle)
  
  # Create window
  when defined(emscripten):
    # For Emscripten 2D rendering, use no special flags (0)
    # SDL will automatically use the canvas element
    result.window = SDL_CreateWindow(
      title.cstring,
      result.width.cint,
      result.height.cint,
      0'u64
    )
  else:
    result.window = SDL_CreateWindow(
      title.cstring,
      result.width.cint,
      result.height.cint,
      SDL_WINDOW_RESIZABLE
    )
  
  if result.window.isNil:
    echo "Failed to create window: ", SDL_GetError()
    when not defined(emscripten):
      SDL_Quit()
    return nil
  
  # Create renderer
  when defined(emscripten):
    # For Emscripten with OpenGL window, create renderer without a name  
    result.renderer = SDL_CreateRenderer(result.window, nil)
  else:
    result.renderer = SDL_CreateRenderer(result.window, nil)
  
  if result.renderer.isNil:
    echo "Failed to create renderer: ", SDL_GetError()
    SDL_DestroyWindow(result.window)
    when not defined(emscripten):
      SDL_Quit()
    return nil
  
  # Enable text input for proper keyboard handling (SDL3)
  discard SDL_StartTextInput(result.window)
  
  # Create persistent terminal texture (render target for dirty cell updates)
  result.terminalTexture = SDL_CreateTexture(
    result.renderer,
    SDL_PIXELFORMAT_RGBA8888.uint32,
    SDL_TEXTUREACCESS_TARGET.cint,  # KEY: allows rendering to this texture
    result.width.cint,
    result.height.cint
  )
  
  if result.terminalTexture.isNil:
    echo "Failed to create terminal texture: ", SDL_GetError()
    SDL_DestroyRenderer(result.renderer)
    SDL_DestroyWindow(result.window)
    when not defined(emscripten):
      SDL_Quit()
    return nil
  
  # Initialize terminal texture to black
  discard SDL_SetRenderTarget(result.renderer, result.terminalTexture)
  discard SDL_SetRenderDrawColor(result.renderer, 0, 0, 0, 255)
  discard SDL_RenderClear(result.renderer)
  discard SDL_SetRenderTarget(result.renderer, nil)
  
  echo "[Canvas] Created persistent terminal texture: ", result.width, "x", result.height
  
  # Don't use logical presentation on web - it causes additional scaling artifacts
  # On web, the canvas size should match the display size 1:1 for crisp text
  when not defined(emscripten):
    # Set logical size to match our terminal dimensions for consistent rendering
    # This makes the renderer scale automatically to window size
    discard SDL_SetRenderLogicalPresentation(
      result.renderer,
      result.width.cint,
      result.height.cint,
      SDL_LOGICAL_PRESENTATION_LETTERBOX
    )

proc shutdown*(canvas: SDLCanvas) =
  ## Clean up SDL resources
  # Destroy cached glyph textures
  for ch, glyph in canvas.glyphCache.pairs:
    if not glyph.texture.isNil:
      SDL_DestroyTexture(glyph.texture)
  canvas.glyphCache.clear()
  
  when not defined(emscripten):
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
  
  # Runtime check: use TTF plugin if loaded, otherwise fallback to debug
  if not gTTFRenderFunc.isNil and not gTTFFontHandle.isNil:
    # Use TTF plugin (dynamically loaded)
    discard gTTFRenderFunc(canvas.renderer, gTTFFontHandle, ch.cstring, ch.len.csize_t,
                           adjX.cfloat, adjY.cfloat,
                           style.fg.r, style.fg.g, style.fg.b)
  else:
    # Fallback to debug text (ASCII only, always available)
    if not SDL_RenderDebugText(canvas.renderer, adjX.cfloat, adjY.cfloat, ch.cstring):
      discard

proc writeText*(canvas: SDLCanvas, x, y: int, text: string, style: Style) =
  ## Write text at pixel coordinates
  let adjX = x + canvas.offset.x
  let adjY = y + canvas.offset.y
  
  # Runtime check: use TTF plugin if loaded, otherwise fallback to debug
  if not gTTFRenderFunc.isNil and not gTTFFontHandle.isNil:
    # Use TTF plugin (dynamically loaded)
    discard gTTFRenderFunc(canvas.renderer, gTTFFontHandle, text.cstring, text.len.csize_t,
                           adjX.cfloat, adjY.cfloat,
                           style.fg.r, style.fg.g, style.fg.b)
  else:
    # Fallback to debug text (ASCII only, always available)
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
  ## Note: We don't call SDL_RenderClear() - pixels persist and cells overwrite their areas
  discard  # No-op: layers handle clearing, pixels persist on renderer

proc clearTransparent*(canvas: SDLCanvas) =
  ## Clear with transparency (SDL3 doesn't really support this, use black)
  ## Note: We don't call SDL_RenderClear() - pixels persist and cells overwrite their areas
  discard  # No-op: layers handle clearing, pixels persist on renderer

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
  ## Load and set a custom font (desktop only)
  when not defined(emscripten):
    let newFont = loadFont(fontPath, size)
    if not newFont.isNil:
      canvas.font = newFont
      canvas.useTTF = true
    else:
      echo "[Canvas] Failed to load font: ", fontPath

proc setFontSize*(canvas: SDLCanvas, size: float) =
  ## Change font size (reloads current font) - desktop only
  when not defined(emscripten):
    if canvas.font.isNil:
      canvas.font = getDefaultFont()
    # Note: Font size change requires reloading - simplified for now
    canvas.useTTF = not canvas.font.isNil

proc resetFont*(canvas: SDLCanvas) =
  ## Reset to default system font (desktop only)
  when not defined(emscripten):
    canvas.font = getDefaultFont()
    canvas.useTTF = not canvas.font.isNil

# ================================================================
# CELL-BASED RENDERING (Terminal Emulation)
# ================================================================

proc writeCell*(canvas: SDLCanvas, x, y: int, ch: string, style: Style) =
  ## Write a character to the virtual cell grid
  if x < 0 or x >= canvas.cellWidth or y < 0 or y >= canvas.cellHeight:
    return
  let idx = y * canvas.cellWidth + x
  if idx >= 0 and idx < canvas.cells.len:
    canvas.cells[idx] = Cell(ch: ch, style: style)

proc writeCellText*(canvas: SDLCanvas, x, y: int, text: string, style: Style) =
  ## Write text to the virtual cell grid (UTF-8 aware)
  var currentX = x
  var i = 0
  while i < text.len:
    if currentX >= canvas.cellWidth:
      break
    # Extract one UTF-8 character (rune)
    let runeLen = graphemeLen(text, i)
    let ch = text.substr(i, i + runeLen - 1)
    canvas.writeCell(currentX, y, ch, style)
    i += runeLen
    currentX += 1

proc clearCells*(canvas: SDLCanvas, bg: Color) =
  ## Clear the entire cell grid to a background color
  let clearStyle = Style(fg: white(), bg: bg, bold: false)
  for i in 0 ..< canvas.cells.len:
    canvas.cells[i] = Cell(ch: " ", style: clearStyle)

proc fillCellRect*(canvas: SDLCanvas, x, y, w, h: int, ch: string, style: Style) =
  ## Fill a rectangular region of cells with a character
  for cy in y ..< min(y + h, canvas.cellHeight):
    for cx in x ..< min(x + w, canvas.cellWidth):
      canvas.writeCell(cx, cy, ch, style)

proc getOrCreateGlyph(canvas: SDLCanvas, ch: string, fgColor: tuple[r, g, b: uint8]): ptr SDL_Texture =
  ## Get cached glyph texture or create new one (terminal emulator approach)
  ## Caches each character + color combination for maximum performance
  
  let key: GlyphKey = (ch, fgColor.r, fgColor.g, fgColor.b)
  
  # Check cache first
  if canvas.glyphCache.hasKey(key):
    return canvas.glyphCache[key].texture
  
  # Render new glyph
  var glyphTexture: ptr SDL_Texture = nil
  
  when not defined(coreOnly):
    if not canvas.font.isNil:
      # Render glyph with actual foreground color
      var color = sdl3_bindings.SDL_Color(r: fgColor.r, g: fgColor.g, b: fgColor.b, a: 255)
      let surface = TTF_RenderText_Blended(canvas.font, ch.cstring, ch.len.csize_t, color)
      if not surface.isNil:
        # Get dimensions before destroying surface
        let w = surface.w
        let h = surface.h
        
        glyphTexture = SDL_CreateTextureFromSurface(canvas.renderer, surface)
        SDL_DestroySurface(surface)
        
        # Cache it (SDL3 textures have alpha blending by default)
        if not glyphTexture.isNil:
          canvas.glyphCache[key] = GlyphCache(
            texture: glyphTexture,
            srcRect: SDL_FRect(x: 0, y: 0, w: w.cfloat, h: h.cfloat),
            advance: w.int
          )
  
  return glyphTexture

proc renderCellsToPixels*(canvas: SDLCanvas) =
  ## TRUE dirty tracking using persistent texture render target
  ## Only render changed cells to persistent texture, then blit to back buffer
  ## This is how modern terminal emulators (Ghostty/Kitty) optimize rendering
  
  # Step 1: Render ONLY dirty cells to persistent terminal texture
  # Switch render target to our persistent texture
  discard SDL_SetRenderTarget(canvas.renderer, canvas.terminalTexture)
  
  for y in 0 ..< canvas.cellHeight:
    for x in 0 ..< canvas.cellWidth:
      let idx = y * canvas.cellWidth + x
      if idx < 0 or idx >= canvas.cells.len:
        continue
      
      let cell = canvas.cells[idx]
      let prevCell = canvas.prevCells[idx]
      
      # Check if cell changed (TRUE dirty tracking)
      let cellChanged = cell.ch != prevCell.ch or
         cell.style.fg.r != prevCell.style.fg.r or
         cell.style.fg.g != prevCell.style.fg.g or
         cell.style.fg.b != prevCell.style.fg.b or
         cell.style.bg.r != prevCell.style.bg.r or
         cell.style.bg.g != prevCell.style.bg.g or
         cell.style.bg.b != prevCell.style.bg.b
      
      # Skip unchanged cells - texture persists between frames!
      if not cellChanged and not canvas.firstFrame:
        continue
      
      # Calculate pixel coordinates for this cell
      let pixelX = x * CHAR_WIDTH
      let pixelY = y * CHAR_HEIGHT
      
      # Render this dirty cell to the persistent texture
      # Draw background (overwrite previous pixels at this location)
      discard SDL_SetRenderDrawColor(canvas.renderer, 
        cell.style.bg.r, cell.style.bg.g, cell.style.bg.b, 255)
      var bgRect = SDL_FRect(x: pixelX.cfloat, y: pixelY.cfloat, 
        w: CHAR_WIDTH.cfloat, h: CHAR_HEIGHT.cfloat)
      discard SDL_RenderFillRect(canvas.renderer, addr bgRect)
      
      # Draw character if not space
      if cell.ch != " " and cell.ch.len > 0:
        # Use glyph atlas cache (like terminal emulators)
        when not defined(coreOnly):
          if canvas.useTTF:
            let glyphTexture = canvas.getOrCreateGlyph(cell.ch, (cell.style.fg.r, cell.style.fg.g, cell.style.fg.b))
            if not glyphTexture.isNil:
              # Get glyph dimensions from cache
              let key: GlyphKey = (cell.ch, cell.style.fg.r, cell.style.fg.g, cell.style.fg.b)
              if canvas.glyphCache.hasKey(key):
                let glyph = canvas.glyphCache[key]
                
                # Render glyph texture (single SDL_RenderTexture call per cell)
                var srcRect = glyph.srcRect
                var dstRect = SDL_FRect(x: pixelX.cfloat, y: pixelY.cfloat, w: srcRect.w, h: srcRect.h)
                discard SDL_RenderTexture(canvas.renderer, glyphTexture, addr srcRect, addr dstRect)
            else:
              # Fallback to debug text
              discard SDL_SetRenderDrawColor(canvas.renderer,
                cell.style.fg.r, cell.style.fg.g, cell.style.fg.b, 255)
              discard SDL_RenderDebugText(canvas.renderer, pixelX.cfloat, pixelY.cfloat, cell.ch.cstring)
          else:
            # No TTF: use debug text
            discard SDL_SetRenderDrawColor(canvas.renderer,
              cell.style.fg.r, cell.style.fg.g, cell.style.fg.b, 255)
            discard SDL_RenderDebugText(canvas.renderer, pixelX.cfloat, pixelY.cfloat, cell.ch.cstring)
        else:
          # Core-only build: use debug text
          discard SDL_SetRenderDrawColor(canvas.renderer,
            cell.style.fg.r, cell.style.fg.g, cell.style.fg.b, 255)
          discard SDL_RenderDebugText(canvas.renderer, pixelX.cfloat, pixelY.cfloat, cell.ch.cstring)
  
  # Step 2: Switch back to default render target (back buffer)
  discard SDL_SetRenderTarget(canvas.renderer, nil)
  
  # Step 3: Clear back buffer and blit entire persistent texture
  discard SDL_SetRenderDrawColor(canvas.renderer, 0, 0, 0, 255)
  discard SDL_RenderClear(canvas.renderer)
  discard SDL_RenderTexture(canvas.renderer, canvas.terminalTexture, nil, nil)
  
  # Update previous frame buffer for next dirty comparison
  for i in 0 ..< canvas.cells.len:
    canvas.prevCells[i] = canvas.cells[i]
  
  # Mark first frame as complete
  if canvas.firstFrame:
    canvas.firstFrame = false

proc measureText*(canvas: SDLCanvas, text: string): tuple[width, height: int] =
  ## Measure text dimensions with current font
  when not defined(coreOnly):
    if canvas.font.isNil:
      # Return approximate size based on debug text
      return (text.len * 8, 12)
    return sdl_fonts.measureText(canvas.font, text)
  else:
    # Core-only: Return approximate size
    return (text.len * 8, 12)

proc clearTextCache*(canvas: SDLCanvas) =
  ## Clear cached text textures (desktop only)
  when not defined(emscripten):
    sdl_fonts.clearCache()

# ================================================================
# BUFFER RENDERING (SDL3 just renders the final composited buffer)
# ================================================================

proc renderBuffer*(canvas: SDLCanvas, buffer: TermBuffer) =
  ## Copy a composited TermBuffer to the SDL3 cells[] array for rendering
  ## This is the bridge between terminal backend's layer system and SDL3 rendering
  let w = min(canvas.cellWidth, buffer.width)
  let h = min(canvas.cellHeight, buffer.height)
  
  for y in 0 ..< h:
    for x in 0 ..< w:
      let srcIdx = y * buffer.width + x
      let dstIdx = y * canvas.cellWidth + x
      if srcIdx < buffer.cells.len and dstIdx < canvas.cells.len:
        canvas.cells[dstIdx] = buffer.cells[srcIdx]
