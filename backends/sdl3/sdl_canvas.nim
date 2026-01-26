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
  SDLCanvas* = ref object
    window*: ptr SDL_Window
    renderer*: ptr SDL_Renderer
    width*: int
    height*: int
    cellWidth*: int    # Width in character cells
    cellHeight*: int   # Height in character cells
    cells*: seq[Cell]  # Virtual terminal grid
    bgColor*: tuple[r, g, b: uint8]
    clipRect*: Option[tuple[x, y, w, h: int]]
    offset*: tuple[x, y: int]
    # Layer system support
    layers*: seq[Layer]           # Layer storage for compositing
    layerIndexCache*: Table[string, int]  # Cache for O(1) layer lookup
    cacheValid*: bool             # Whether cache is up-to-date
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
  
  # Calculate cell dimensions
  result.cellWidth = width div CHAR_WIDTH
  result.cellHeight = height div CHAR_HEIGHT
  
  # Initialize virtual terminal cell grid
  result.cells = newSeq[Cell](result.cellWidth * result.cellHeight)
  let defaultStyle = Style(fg: white(), bg: black(), bold: false)
  for i in 0 ..< result.cells.len:
    result.cells[i] = Cell(ch: " ", style: defaultStyle)
  
  # Initialize layer system
  result.layers = @[]
  result.layerIndexCache = initTable[string, int]()
  result.cacheValid = false
  
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
    for i in 0 ..< result.cells.len:
      result.cells[i] = Cell(ch: " ", style: defaultStyle)
  
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

proc renderCellsToPixels*(canvas: SDLCanvas) =
  ## Render the entire cell grid to pixels
  ## This is called each frame to convert terminal cells to graphics
  var nonSpaceCount = 0
  for y in 0 ..< canvas.cellHeight:
    for x in 0 ..< canvas.cellWidth:
      let idx = y * canvas.cellWidth + x
      if idx < 0 or idx >= canvas.cells.len:
        continue
      
      let cell = canvas.cells[idx]
      if cell.ch != " " and cell.ch.len > 0:
        nonSpaceCount += 1
      let pixelX = x * CHAR_WIDTH
      let pixelY = y * CHAR_HEIGHT
      
      # Draw background (only if not default black to save draw calls)
      if cell.style.bg.r != 0 or cell.style.bg.g != 0 or cell.style.bg.b != 0:
        discard SDL_SetRenderDrawColor(canvas.renderer, 
          cell.style.bg.r, cell.style.bg.g, cell.style.bg.b, 255)
        var bgRect = SDL_FRect(x: pixelX.cfloat, y: pixelY.cfloat, 
          w: CHAR_WIDTH.cfloat, h: CHAR_HEIGHT.cfloat)
        discard SDL_RenderFillRect(canvas.renderer, addr bgRect)
      
      # Draw character if not space
      if cell.ch != " " and cell.ch.len > 0:
        # Runtime check: use TTF plugin if loaded, otherwise fallback
        if not gTTFRenderFunc.isNil and not gTTFFontHandle.isNil:
          # Use TTF plugin (dynamically loaded)
          discard gTTFRenderFunc(canvas.renderer, gTTFFontHandle, cell.ch.cstring, cell.ch.len.csize_t,
                                 pixelX.cfloat, pixelY.cfloat,
                                 cell.style.fg.r, cell.style.fg.g, cell.style.fg.b)
        else:
          # Fallback to debug text (ASCII only, always available)
          discard SDL_SetRenderDrawColor(canvas.renderer,
            cell.style.fg.r, cell.style.fg.g, cell.style.fg.b, 255)
          discard SDL_RenderDebugText(canvas.renderer, pixelX.cfloat, pixelY.cfloat, cell.ch.cstring)

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
# LAYER SYSTEM (Multi-buffer compositing)
# ================================================================

proc newLayer*(canvas: SDLCanvas, id: string, z: int = 0): Layer =
  ## Create a new layer with the canvas dimensions
  result = Layer(
    id: id,
    z: z,
    visible: true,
    buffer: TermBuffer(
      width: canvas.cellWidth,
      height: canvas.cellHeight,
      cells: newSeq[Cell](canvas.cellWidth * canvas.cellHeight),
      clipX: 0,
      clipY: 0,
      clipW: canvas.cellWidth,
      clipH: canvas.cellHeight,
      offsetX: 0,
      offsetY: 0
    )
  )
  # Clear layer buffer to transparent
  let defaultStyle = Style(fg: white(), bg: black(), bold: false)
  for i in 0 ..< result.buffer.cells.len:
    result.buffer.cells[i] = Cell(ch: "", style: defaultStyle)

proc rebuildLayerCache*(canvas: SDLCanvas) =
  ## Rebuild the layer name -> index cache
  canvas.layerIndexCache.clear()
  for i, layer in canvas.layers:
    canvas.layerIndexCache[layer.id] = i
  canvas.cacheValid = true

proc invalidateLayerCache*(canvas: SDLCanvas) =
  ## Mark the layer cache as invalid (will be rebuilt on next access)
  canvas.cacheValid = false

proc resolveLayerIndex*(canvas: SDLCanvas, layerId: string): int =
  ## Resolve a layer name to its index in the layers array
  ## Returns -1 if layer not found
  ## Special case: "default" or "" returns 0 (the default layer)
  if layerId == "default" or layerId == "":
    if canvas.layers.len > 0:
      return 0
    else:
      return -1
  
  # Rebuild cache if invalid
  if not canvas.cacheValid:
    canvas.rebuildLayerCache()
  
  # Look up in cache
  if canvas.layerIndexCache.hasKey(layerId):
    return canvas.layerIndexCache[layerId]
  else:
    return -1

proc addLayer*(canvas: SDLCanvas, id: string, z: int): Layer =
  ## Add a new layer to the canvas
  let layer = canvas.newLayer(id, z)
  canvas.layers.add(layer)
  canvas.invalidateLayerCache()
  echo "[SDL3] Added layer '", id, "' (z=", z, ") - total layers: ", canvas.layers.len
  return layer

proc getLayer*(canvas: SDLCanvas, id: string): Layer =
  ## Get a layer by ID
  for layer in canvas.layers:
    if layer.id == id:
      return layer
  return nil

proc removeLayer*(canvas: SDLCanvas, id: string) =
  ## Remove a layer by ID
  var i = 0
  while i < canvas.layers.len:
    if canvas.layers[i].id == id:
      canvas.layers.delete(i)
      canvas.invalidateLayerCache()
    else:
      i += 1

proc resizeLayers*(canvas: SDLCanvas, newWidth, newHeight: int) =
  ## Resize all layer buffers to match new canvas size
  for layer in canvas.layers:
    layer.buffer.width = newWidth
    layer.buffer.height = newHeight
    layer.buffer.cells = newSeq[Cell](newWidth * newHeight)
    let defaultStyle = Style(fg: white(), bg: black(), bold: false)
    for i in 0 ..< layer.buffer.cells.len:
      layer.buffer.cells[i] = Cell(ch: "", style: defaultStyle)

proc compositeBufferOnto(dest: var seq[Cell], destWidth: int, src: var TermBuffer) =
  ## Composite one buffer onto a destination cell array
  ## Empty cells and pure-black backgrounds are treated as transparent
  var nonEmptyCount = 0
  let w = min(destWidth, src.width)
  let h = min(dest.len div destWidth, src.height)
  for y in 0 ..< h:
    let dr = y * destWidth
    let sr = y * src.width
    for x in 0 ..< w:
      let s = src.cells[sr + x]
      # Composite if there's a character OR if there's a non-black background
      if s.ch.len > 0 or (s.style.bg.r != 0 or s.style.bg.g != 0 or s.style.bg.b != 0):
        if s.ch.len > 0 and s.ch != " ":
          nonEmptyCount += 1
        dest[dr + x] = s

proc compositeLayers*(canvas: SDLCanvas) =
  ## Composite all visible layers to the canvas cells[] in z-order
  if canvas.layers.len == 0:
    return
  
  # Clear canvas cells to background
  let bgStyle = Style(fg: white(), bg: Color(r: canvas.bgColor.r, g: canvas.bgColor.g, b: canvas.bgColor.b), bold: false)
  for i in 0 ..< canvas.cells.len:
    canvas.cells[i] = Cell(ch: " ", style: bgStyle)
  
  # Sort layers by z-index (stable sort maintains insertion order for equal z values)
  canvas.layers.sort(proc(a, b: Layer): int =
    cmp(a.z, b.z)
  )
  canvas.invalidateLayerCache()  # Cache is stale after reordering
  
  # Composite each visible layer
  for layer in canvas.layers:
    if layer.visible:
      compositeBufferOnto(canvas.cells, canvas.cellWidth, layer.buffer)

proc getLayerCount*(canvas: SDLCanvas): int =
  ## Get the number of layers
  return canvas.layers.len
