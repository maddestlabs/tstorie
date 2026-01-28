## Nimini bindings for FIGlet Font Rendering
## Exposes FIGlet font functions to nimini scripts
##
## BINDING PATTERNS:
## Pattern 1 (Auto-exposed - 2 functions):
## - isFontLoaded: Simple string param, bool return
## - clearCache: No params, no return
##
## Pattern 3 (Auto-exposed - 1 function):
## - listAvailableFonts: No params, seq[string] return
##
## Manual wrappers (3 functions):
## - figletLoadFont: Complex logic with font cache management
## - figletRender: Returns FIGfont custom type
## - drawFigletText: Takes layer/style parameters and drawing logic

import ../nimini
import ../nimini/runtime
import ../nimini/type_converters
import ../nimini/lang/nim_extensions
import figlet
import tables
import storie_types  # For StyleConfig and StorieContext

when not declared(Style):
  import ../src/types

when not declared(TermBuffer):
  import ../src/types
  
# Import layers module for writeText function
import ../src/layers

# SDL3 backend support
when defined(sdl3Backend):
  import ../backends/sdl3/sdl_canvas
  var gSDL3Canvas*: SDLCanvas = nil

# Global references set during registration
var gFigletFontsRef*: ptr Table[string, FIGfont] = nil
var gEmbeddedFigletFontsRef*: ptr Table[string, string] = nil

# Forward declarations for types defined in tstorie.nim
when not declared(Layer):
  type Layer* = ref object
when not declared(AppState):
  type AppState* = ref object
when not declared(StorieContext):
  type StorieContext* = ref object

# Global references to layer system
var gDefaultLayerRef*: ptr Layer = nil
var gAppStateRef*: ptr AppState = nil
var gStorieCtxRef*: ptr StorieContext = nil
import ../src/binding_utils  # For valueToStyle, toInt, toBool, toFloat

# ==============================================================================
# NIMINI BINDINGS - FIGLET FUNCTIONS
# ==============================================================================

proc figletLoadFont*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Load a figlet font embedded in the markdown. Args: fontName (string)
  ## Returns: bool (true if loaded successfully)
  if args.len < 1:
    return valBool(false)
  
  let fontName = $(args[0])
  
  # Check if font caches are initialized
  if gFigletFontsRef.isNil or gEmbeddedFigletFontsRef.isNil:
    return valBool(false)
  
  # Check if already loaded
  if gFigletFontsRef[].hasKey(fontName):
    return valBool(true)
  
  # Check if font is embedded in markdown
  if not gEmbeddedFigletFontsRef[].hasKey(fontName):
    return valBool(false)
  
  # Parse the embedded font
  try:
    let font = parseFontFromString(fontName, gEmbeddedFigletFontsRef[][fontName])
    gFigletFontsRef[][fontName] = font
    return valBool(true)
  except:
    # Suppress figlet loading errors to avoid noisy output during demos
    discard
    return valBool(false)

# Note: isFontLoaded is auto-exposed in figlet.nim
# Note: listAvailableFonts is auto-exposed in figlet.nim
# Note: clearCache is auto-exposed in figlet.nim

proc figletRender*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render text with a loaded figlet font. Args: fontName (string), text (string), [layoutMode (int)]
  ## Returns: array of strings (lines)
  if args.len < 2:
    return valArray(@[])
  
  if gFigletFontsRef.isNil:
    return valArray(@[])
  
  let fontName = $(args[0])
  if not gFigletFontsRef[].hasKey(fontName):
    echo "[figletRender] Font not loaded: ", fontName
    return valArray(@[])
  
  let text = $(args[1])
  let layout = if args.len >= 3: 
    case toInt(args[2])
    of 1: HorizontalFitting
    of 2: HorizontalSmushing
    else: FullWidth
  else: FullWidth
  
  let lines = render(gFigletFontsRef[][fontName], text, layout)
  
  var result: seq[Value] = @[]
  for line in lines:
    result.add(valString(line))
  return valArray(result)

# Note: listAvailableFonts is auto-exposed in figlet.nim and lists available .flf files
# The following provides embedded fonts from markdown (different from file system fonts)

proc figletListEmbeddedFonts*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get list of embedded figlet fonts from markdown
  var result: seq[Value] = @[]
  
  if gEmbeddedFigletFontsRef.isNil:
    return valArray(result)
  
  try:
    for fontName in gEmbeddedFigletFontsRef[].keys:
      result.add(valString(fontName))
  except:
    discard
  return valArray(result)

proc drawFigletText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw figlet text using direct layer access
  ## Args: layer (int/string), x, y, fontName, text, [layoutMode, style, vertical, letterSpacing]
  if args.len < 5:
    return valNil()
  
  if gFigletFontsRef.isNil:
    return valNil()
  
  # Use unified layer system (gAppState.layers for both terminal and SDL3)
  if gDefaultLayerRef.isNil or gAppStateRef.isNil:
    return valNil()
  
  # Resolve layer from first argument
  var layer: Layer = nil
  if args[0].kind == vkInt:
    let idx = args[0].i
    if idx >= 0 and idx < gAppStateRef[].layers.len:
      layer = gAppStateRef[].layers[idx]
    elif idx == 0:
      layer = gDefaultLayerRef[]
  elif args[0].kind == vkString:
    let layerId = args[0].s
    layer = getLayer(gAppStateRef[], layerId)
    if layer.isNil and (layerId == "default" or layerId == ""):
      layer = gDefaultLayerRef[]
  
  if layer.isNil:
    return valNil()
  
  let x = toInt(args[1])
  let y = toInt(args[2])
  let fontName = $(args[3])
  let text = $(args[4])
  let layout = if args.len >= 6: 
    case toInt(args[5])
    of 1: HorizontalFitting
    of 2: HorizontalSmushing
    else: FullWidth
  else: FullWidth
  
  # Get style (default: defaultStyle() which respects theme)
  let style = if args.len >= 7 and args[6].kind == vkMap:
    valueToStyle(args[6])
  else:
    defaultStyle()
  
  # Get vertical direction flag (default: false/0 for horizontal)
  let vertical = if args.len >= 8: toInt(args[7]) != 0 else: false
  
  # Get letter spacing (default: 0)
  let letterSpacing = if args.len >= 9: toInt(args[8]) else: 0
  
  # Check if font is loaded
  if not gFigletFontsRef[].hasKey(fontName):
    echo "[drawFigletText] Font not loaded: ", fontName
    return valNil()
  
  # Render the text
  let lines = render(gFigletFontsRef[][fontName], text, layout)
  if lines.len == 0:
    return valNil()
  
  if vertical:
    # Vertical: print each character going downward from y coordinate
    var currentY = y
    for ch in text:
      # Render single character
      let charLines = render(gFigletFontsRef[][fontName], $ch, layout)
      var lineY = currentY
      for line in charLines:
        when defined(sdl3Backend):
          layer.buffer.writeText(x, lineY, line, style)
        else:
          layer[].buffer.writeText(x, lineY, line, style)
        lineY += 1
      # Move down for next character (plus letter spacing)
      currentY = lineY + letterSpacing
  else:
    # Horizontal: normal left-to-right, top-to-bottom with letter spacing
    if letterSpacing > 0:
      # Apply letter spacing by rendering character by character
      var currentX = x
      for ch in text:
        let charLines = render(gFigletFontsRef[][fontName], $ch, layout)
        if charLines.len > 0:
          var lineY = y
          # Find the actual width of this character
          var charWidth = 0
          for line in charLines:
            if line.len > charWidth:
              charWidth = line.len
          
          # Draw each line of the character
          for line in charLines:
            when defined(sdl3Backend):
              layer.buffer.writeText(currentX, lineY, line, style)
            else:
              layer[].buffer.writeText(currentX, lineY, line, style)
            lineY += 1
          
          # Move to next character position (width + spacing)
          currentX += charWidth + letterSpacing
    else:
      # No letter spacing - draw normally
      var currentY = y
      for line in lines:
        when defined(sdl3Backend):
          layer.buffer.writeText(x, currentY, line, style)
        else:
          layer[].buffer.writeText(x, currentY, line, style)
        currentY += 1
  
  return valNil()

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerFigletBindings*(fontsTable: ptr Table[string, FIGfont], 
                             embeddedFontsTable: ptr Table[string, string],
                             defaultLayer: ptr Layer,
                             appState: ptr AppState) =
  ## Register figlet bindings with references to global state
  ## This should be called from createNiminiContext in runtime_api.nim
  gFigletFontsRef = fontsTable
  gEmbeddedFigletFontsRef = embeddedFontsTable
  gDefaultLayerRef = defaultLayer
  gAppStateRef = appState
  
  # Pattern 1 & 3: Auto-exposed functions
  register_listAvailableFonts()
  register_isFontLoaded()
  register_clearCache()
  
  # Manual wrappers: Complex font loading and rendering
  registerNative("figletLoadFont", figletLoadFont, 
    storieLibs = @["figlet"], 
    description = "Load a FIGlet font by name")
  registerNative("figletListEmbeddedFonts", figletListEmbeddedFonts,
    storieLibs = @["figlet"],
    description = "List FIGlet fonts embedded in markdown")
  registerNative("figletRender", figletRender,
    storieLibs = @["figlet"],
    description = "Render text using a loaded FIGlet font")
  registerNative("drawFigletText", drawFigletText,
    storieLibs = @["figlet"],
    description = "Draw FIGlet text to a layer")
