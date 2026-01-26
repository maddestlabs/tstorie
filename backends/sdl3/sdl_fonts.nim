## SDL3 TTF Font Management
## Handles font loading, caching, and text rendering with SDL3_ttf

when not defined(coreOnly):
  import sdl3_bindings
  import tables
  import std/options

  type
    FontCache* = ref object
      fonts*: Table[FontKey, ptr TTF_Font]
      defaultFont*: ptr TTF_Font
      defaultSize*: float
    
    FontKey = tuple
      path: string
      size: int
    
    TextureCache* = ref object
      textures*: Table[string, CachedTexture]
      maxCacheSize*: int
    
    CachedTexture = object
      texture: ptr SDL_Texture
      width, height: int
      lastUsed: int  # Frame counter for LRU

  var globalFontCache: FontCache
  var globalTextureCache: TextureCache
  var frameCounter: int = 0

  proc initFontCache*(): FontCache =
    ## Initialize font cache system
    result = FontCache()
    result.fonts = initTable[FontKey, ptr TTF_Font]()
    result.defaultSize = 16.0
    result.defaultFont = nil
    
    # Try to load a default font
    when defined(linux):
      const defaultPaths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"
      ]
    elif defined(macosx):
      const defaultPaths = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.dfont",
        "/Library/Fonts/Courier New.ttf"
      ]
    elif defined(windows):
      const defaultPaths = [
        "C:\\Windows\\Fonts\\consola.ttf",
        "C:\\Windows\\Fonts\\cour.ttf"
      ]
    else:
      const defaultPaths: seq[string] = @[]
    
    for path in defaultPaths:
      result.defaultFont = TTF_OpenFont(path.cstring, result.defaultSize.cfloat)
      if not result.defaultFont.isNil:
        # Enable light hinting for better rendering quality
        TTF_SetFontHinting(result.defaultFont, TTF_HINTING_LIGHT)
        echo "[FontCache] Loaded default font: ", path
        break
    
    if result.defaultFont.isNil:
      echo "[FontCache] Warning: No default font found"

  proc initTextureCache*(): TextureCache =
    ## Initialize texture cache for rendered text
    result = TextureCache()
    result.textures = initTable[string, CachedTexture]()
    result.maxCacheSize = 500  # Larger cache for dynamic content (counters, etc.)

  proc init*() =
    ## Initialize SDL_ttf and caches
    if not TTF_Init():
      echo "[Fonts] Failed to initialize TTF: ", SDL_GetError()
      return
    
    globalFontCache = initFontCache()
    globalTextureCache = initTextureCache()
    echo "[Fonts] SDL_ttf initialized"

  proc shutdown*() =
    ## Cleanup all fonts and textures
    if not globalFontCache.isNil:
      for font in globalFontCache.fonts.values:
        TTF_CloseFont(font)
      if not globalFontCache.defaultFont.isNil:
        TTF_CloseFont(globalFontCache.defaultFont)
      globalFontCache = nil
    
    if not globalTextureCache.isNil:
      for cached in globalTextureCache.textures.values:
        SDL_DestroyTexture(cached.texture)
      globalTextureCache = nil
    
    TTF_Quit()

  proc loadFont*(path: string, size: float = 16.0): ptr TTF_Font =
    ## Load a font with caching
    if globalFontCache.isNil:
      init()
    
    let key = (path, size.int)
    
    if globalFontCache.fonts.hasKey(key):
      return globalFontCache.fonts[key]
    
    let font = TTF_OpenFont(path.cstring, size.cfloat)
    if font.isNil:
      echo "[Fonts] Failed to load font: ", path, " - ", SDL_GetError()
      return globalFontCache.defaultFont
    
    # Enable light hinting for better rendering quality
    TTF_SetFontHinting(font, TTF_HINTING_LIGHT)
    
    globalFontCache.fonts[key] = font
    return font

  proc getDefaultFont*(): ptr TTF_Font =
    ## Get the default system font
    if globalFontCache.isNil:
      init()
    return globalFontCache.defaultFont

  proc renderTextRaw*(renderer: ptr SDL_Renderer, font: ptr TTF_Font, 
                      text: cstring, textLen: csize_t, x, y: float, 
                      color: tuple[r, g, b: uint8]): bool =
    ## Render text at position using TTF font (raw cstring with length for UTF-8)
    if font.isNil:
      return false
    
    # Render new surface (skip caching for now with raw cstrings)
    let sdlColor = SDL_Color(r: color.r, g: color.g, b: color.b, a: 255)
    let surface = TTF_RenderText_Blended(font, text, textLen, sdlColor)
    
    if surface.isNil:
      echo "[Fonts] Failed to render text surface: ", SDL_GetError()
      return false
    
    defer: SDL_DestroySurface(surface)
    
    # Create texture from surface
    let texture = SDL_CreateTextureFromSurface(renderer, surface)
    if texture.isNil:
      echo "[Fonts] Failed to create texture from surface: ", SDL_GetError()
      return false
    
    # Set linear filtering for smooth font rendering (fixes artifacts)
    discard SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_LINEAR)
    
    defer: SDL_DestroyTexture(texture)
    
    # Render texture
    var dstRect = SDL_FRect(x: x.cfloat, y: y.cfloat, 
                            w: surface.w.cfloat, h: surface.h.cfloat)
    result = SDL_RenderTexture(renderer, texture, nil, addr dstRect)
    
    frameCounter.inc

  proc renderText*(renderer: ptr SDL_Renderer, font: ptr TTF_Font, 
                   text: string, x, y: float, color: tuple[r, g, b: uint8]): bool =
    ## Render text at position using TTF font
    if font.isNil:
      return false
    
    # Create cache key
    let cacheKey = text & $color.r & $color.g & $color.b & $cast[int](font)
    
    # Check texture cache
    if globalTextureCache.textures.hasKey(cacheKey):
      var cached = globalTextureCache.textures[cacheKey]
      cached.lastUsed = frameCounter
      globalTextureCache.textures[cacheKey] = cached
      
      # Render cached texture
      var dstRect = SDL_FRect(x: x.cfloat, y: y.cfloat, 
                              w: cached.width.cfloat, h: cached.height.cfloat)
      return SDL_RenderTexture(renderer, cached.texture, nil, addr dstRect)
    
    # Render new surface
    let sdlColor = SDL_Color(r: color.r, g: color.g, b: color.b, a: 255)
    let surface = TTF_RenderText_Blended(font, text.cstring, text.len.csize_t, sdlColor)
    
    if surface.isNil:
      echo "[Fonts] Failed to render text surface: ", SDL_GetError()
      return false
    
    defer: SDL_DestroySurface(surface)
    
    # Create texture from surface
    let texture = SDL_CreateTextureFromSurface(renderer, surface)
    if texture.isNil:
      echo "[Fonts] Failed to create texture from surface: ", SDL_GetError()
      return false    
    # Set linear filtering for smooth font rendering (fixes artifacts)
    discard SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_LINEAR)    
    # Cache texture (with LRU eviction if needed)
    if globalTextureCache.textures.len >= globalTextureCache.maxCacheSize:
      # Simple eviction: remove first item (pseudo-LRU, much faster than finding oldest)
      # This is O(1) instead of O(n), trading perfect LRU for speed
      var keyToRemove = ""
      for key in globalTextureCache.textures.keys:
        keyToRemove = key
        break
      
      if keyToRemove != "":
        SDL_DestroyTexture(globalTextureCache.textures[keyToRemove].texture)
        globalTextureCache.textures.del(keyToRemove)
    
    globalTextureCache.textures[cacheKey] = CachedTexture(
      texture: texture,
      width: surface.w,
      height: surface.h,
      lastUsed: frameCounter
    )
    
    # Render texture
    var dstRect = SDL_FRect(x: x.cfloat, y: y.cfloat, 
                            w: surface.w.cfloat, h: surface.h.cfloat)
    result = SDL_RenderTexture(renderer, texture, nil, addr dstRect)
    
    frameCounter.inc

  proc measureText*(font: ptr TTF_Font, text: string): tuple[width, height: int] =
    ## Measure text dimensions (not implemented yet - requires SDL_ttf additions)
    ## For now, estimate based on character count and font size
    if font.isNil:
      return (0, 0)
    
    # Rough estimation: 8 pixels per char width, 16 pixels height
    # Real implementation would use TTF_MeasureText from SDL_ttf
    result = (text.len * 8, 16)

  proc clearCache*() =
    ## Clear texture cache (useful for freeing memory)
    if not globalTextureCache.isNil:
      for cached in globalTextureCache.textures.values:
        SDL_DestroyTexture(cached.texture)
      globalTextureCache.textures.clear()
else:
  # Core-only build: Provide stub implementations
  type
    FontCache* = ref object
    TextureCache* = ref object
  
  proc init*() = discard
  proc getDefaultFont*(): pointer = nil
  proc renderText*(renderer: pointer, font: pointer, text: string, x, y: float, color: tuple[r, g, b: uint8]): bool = false
  proc measureText*(font: pointer, text: string): tuple[width, height: int] = (text.len * 8, 16)
  proc clearCache*() = discard
