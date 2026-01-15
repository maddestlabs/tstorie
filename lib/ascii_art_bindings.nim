## Nimini bindings for ASCII Art library
## Exposes procedural ASCII art functions to nimini scripts
##
## BINDING PATTERNS:
## This module primarily uses manual wrappers due to:
## - PatternFunc: Closure type that requires runtime storage and ID-based references
## - Custom types: ModuloRule, PatternConfig, DetailPoint cannot be auto-converted
## - Proc parameters: drawBorder/drawBorderLine take callback procs
##
## Pattern 1 (Auto-exposed - 1 function):
## - setSeedIfNeeded: Uses {.autoExpose: "ascii".} in ascii_art.nim
##
## Manual wrappers (15 functions):
## - Pattern creation: moduloPattern, moduloPatternV, randomPattern, solidPattern, 
##   combinePatterns, layerPattern (all return PatternFunc)
## - Drawing: drawBorder, drawBorderLine, addDetail (take proc parameters)
## - Generators: crackedBorderPattern, simpleBorderPattern (return tuple of PatternFunc)
## - Utilities: generateCrackDetails, generateVariations (return seq of custom types)
## - Metadata: describePattern, getPatternExportMetadata (use custom types)

import ../nimini
import ../nimini/runtime
import ../nimini/type_converters
import ascii_art
import std/[tables, random, strutils]

when not declared(Style):
  import ../src/types

# Forward declaration for AppState
when not declared(AppState):
  type AppState* = ref object
    termWidth*: int
    termHeight*: int

# Global reference to draw procedure (set by registerAsciiArtBindings)
type DrawProc* = proc(layer, x, y: int, char: string, style: Style)
var gDrawProc: DrawProc
var gAppStateRef: ptr AppState = nil

# ==============================================================================
# PATTERN FUNCTION STORAGE
# ==============================================================================
# Store created pattern functions so they can be reused

var gPatternFuncs = initTable[string, PatternFunc]()
var gPatternIdCounter = 0

proc storePattern(pattern: PatternFunc): string =
  ## Store a pattern and return its ID
  gPatternIdCounter += 1
  let id = "pattern_" & $gPatternIdCounter
  gPatternFuncs[id] = pattern
  return id

proc getPattern(id: string): PatternFunc =
  ## Retrieve a stored pattern by ID
  if gPatternFuncs.hasKey(id):
    return gPatternFuncs[id]
  # Return default pattern if not found
  return solidPattern("─")

# ==============================================================================
# NIMINI BINDINGS - PATTERN CREATION
# ==============================================================================

# Note: setSeedIfNeeded is auto-exposed in ascii_art.nim, no manual wrapper needed

proc nimini_moduloPattern*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a modulo-based pattern. Args: rules (array of [modBase, modValue, char]), default (string)
  ## Returns: pattern ID (string)
  var rules: seq[ModuloRule] = @[]
  
  if args.len > 0 and args[0].kind == vkArray:
    for ruleVal in args[0].arr:
      if ruleVal.kind == vkArray and ruleVal.arr.len >= 3:
        let modBase = toInt(ruleVal.arr[0])
        let modValue = toInt(ruleVal.arr[1])
        let char = $(ruleVal.arr[2])
        rules.add((modBase, modValue, char))
  
  let default = if args.len > 1: $(args[1]) else: "─"
  let pattern = moduloPattern(rules, default)
  let id = storePattern(pattern)
  
  return valString(id)

proc nimini_moduloPatternV*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a vertical modulo-based pattern. Args: rules (array), default (string)
  ## Returns: pattern ID (string)
  var rules: seq[ModuloRule] = @[]
  
  if args.len > 0 and args[0].kind == vkArray:
    for ruleVal in args[0].arr:
      if ruleVal.kind == vkArray and ruleVal.arr.len >= 3:
        let modBase = toInt(ruleVal.arr[0])
        let modValue = toInt(ruleVal.arr[1])
        let char = $(ruleVal.arr[2])
        rules.add((modBase, modValue, char))
  
  let default = if args.len > 1: $(args[1]) else: "│"
  let pattern = moduloPatternV(rules, default)
  let id = storePattern(pattern)
  
  return valString(id)

proc nimini_solidPattern*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a solid pattern (single character). Args: char (string)
  ## Returns: pattern ID (string)
  let char = if args.len > 0: $(args[0]) else: "─"
  let pattern = solidPattern(char)
  let id = storePattern(pattern)
  return valString(id)

proc nimini_crackedBorderPattern*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create the cracked/weathered border pattern. Args: seed (int)
  ## Returns: table with keys "top", "bottom", "left", "right" (pattern IDs)
  let seed = if args.len > 0: toInt(args[0]) else: 42
  let patterns = crackedBorderPattern(seed)
  
  # Store each pattern and return IDs
  let topId = storePattern(patterns.top)
  let bottomId = storePattern(patterns.bottom)
  let leftId = storePattern(patterns.left)
  let rightId = storePattern(patterns.right)
  
  # Return as table
  var table = initTable[string, Value]()
  table["top"] = valString(topId)
  table["bottom"] = valString(bottomId)
  table["left"] = valString(leftId)
  table["right"] = valString(rightId)
  
  return valMap(table)

proc nimini_simpleBorderPattern*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a simple solid border pattern. No args.
  ## Returns: table with keys "top", "bottom", "left", "right" (pattern IDs)
  let patterns = simpleBorderPattern()
  
  let topId = storePattern(patterns.top)
  let bottomId = storePattern(patterns.bottom)
  let leftId = storePattern(patterns.left)
  let rightId = storePattern(patterns.right)
  
  var table = initTable[string, Value]()
  table["top"] = valString(topId)
  table["bottom"] = valString(bottomId)
  table["left"] = valString(leftId)
  table["right"] = valString(rightId)
  
  return valMap(table)

# ==============================================================================
# NIMINI BINDINGS - BORDER DRAWING
# ==============================================================================

proc nimini_drawBorder*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw a border with custom patterns. 
  ## Args: layer (int), x (int), y (int), width (int), height (int),
  ##       topPattern (patternId), bottomPattern (patternId), 
  ##       leftPattern (patternId), rightPattern (patternId),
  ##       corners (array of 4 strings), style (style)
  if args.len < 11 or gDrawProc.isNil:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let width = toInt(args[3])
  let height = toInt(args[4])
  
  let topPattern = getPattern($(args[5]))
  let bottomPattern = getPattern($(args[6]))
  let leftPattern = getPattern($(args[7]))
  let rightPattern = getPattern($(args[8]))
  
  var corners: array[4, string]
  if args[9].kind == vkArray and args[9].arr.len >= 4:
    for i in 0..3:
      corners[i] = $(args[9].arr[i])
  else:
    corners = ["┌", "┐", "└", "┘"]
  
  let style = valueToStyle(args[10])
  
  drawBorder(layer, x, y, width, height, topPattern, bottomPattern,
             leftPattern, rightPattern, corners, style, gDrawProc)
  
  return valNil()

proc nimini_drawBorderFull*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw a border that fills the terminal.
  ## Args: layer (int), topPattern (id), bottomPattern (id), 
  ##       leftPattern (id), rightPattern (id), corners (array), style (style)
  ## Uses global termWidth and termHeight
  if args.len < 7 or gDrawProc.isNil:
    return valNil()
  
  # Get terminal dimensions from global app state
  # Note: gAppStateRef is set by registerAsciiArtBindings
  let termWidth = if not gAppStateRef.isNil: gAppStateRef.termWidth else: 80
  let termHeight = if not gAppStateRef.isNil: gAppStateRef.termHeight else: 24
  
  let layer = toInt(args[0])
  let topPattern = getPattern($(args[1]))
  let bottomPattern = getPattern($(args[2]))
  let leftPattern = getPattern($(args[3]))
  let rightPattern = getPattern($(args[4]))
  
  var corners: array[4, string]
  if args[5].kind == vkArray and args[5].arr.len >= 4:
    for i in 0..3:
      corners[i] = $(args[5].arr[i])
  else:
    corners = ["┌", "┐", "└", "┘"]
  
  let style = valueToStyle(args[6])
  
  drawBorder(layer, 0, 0, termWidth, termHeight, topPattern, bottomPattern,
             leftPattern, rightPattern, corners, style, gDrawProc)
  
  return valNil()

# ==============================================================================
# NIMINI BINDINGS - ASCII ART CONTENT RENDERING
# ==============================================================================

proc nimini_drawAscii*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw ASCII art from a code block. Args: layer (int), x (int), y (int), artName (string), [style (Style)]
  ## Convenience function that loads and draws ASCII art in one call
  ## artName supports colon syntax: "ascii:logo" or just "logo" (assumes "ascii:" prefix)
  if args.len < 4:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  let artName = $(args[3])
  
  # Build the block type identifier
  let blockType = if artName.contains(":"): artName else: "ascii:" & artName
  
  # Get the getContent function from the environment
  let getContentFunc = env.getVar("getContent")
  if getContentFunc.kind != vkFunction or not getContentFunc.fnVal.isNative:
    return valNil()
  
  # Call getContent to get the ASCII art lines
  var getContentArgs = @[valString(blockType)]
  let artLines = getContentFunc.fnVal.native(env, getContentArgs)
  
  if artLines.kind != vkArray or artLines.arr.len == 0:
    return valNil()
  
  # Get the draw function from the environment
  let drawFunc = env.getVar("draw")
  if drawFunc.kind != vkFunction or not drawFunc.fnVal.isNative:
    return valNil()
  
  # Get style if provided
  let hasStyle = args.len >= 5
  let style = if hasStyle: args[4] else: valNil()
  
  # Draw each line
  var currentY = y
  for lineVal in artLines.arr:
    let line = $(lineVal)
    if hasStyle:
      # Draw with style
      var drawArgs = @[valInt(layer), valInt(x), valInt(currentY), valString(line), style]
      discard drawFunc.fnVal.native(env, drawArgs)
    else:
      # Draw without style
      var drawArgs = @[valInt(layer), valInt(x), valInt(currentY), valString(line)]
      discard drawFunc.fnVal.native(env, drawArgs)
    currentY += 1
  
  return valNil()

# ==============================================================================
# NIMINI BINDINGS - CRACK DETAILS
# ==============================================================================

proc nimini_generateCracks*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate crack details. Args: seed (int), width (int), height (int), density (float, optional)
  ## Returns: array of detail points (internal format)
  if args.len < 3:
    return valArray(@[])
  
  let seed = toInt(args[0])
  let width = toInt(args[1])
  let height = toInt(args[2])
  let density = if args.len > 3: toFloat(args[3]) else: 0.05
  
  let cracks = generateCrackDetails(seed, width, height, density)
  
  # Convert to nimini array format (store as pointer for now)
  # In real implementation, would serialize properly
  var crackValues: seq[Value] = @[]
  for crack in cracks:
    # Store as string representation for simplicity
    let crackStr = $crack.x & "," & $crack.y & "," & crack.chars.join(";")
    crackValues.add(valString(crackStr))
  
  return valArray(crackValues)

proc nimini_addDetail*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Add a single crack detail. Args: layer (int), x (int), y (int), chars (array), style (style)
  if args.len < 5 or gDrawProc.isNil:
    return valNil()
  
  let layer = toInt(args[0])
  let x = toInt(args[1])
  let y = toInt(args[2])
  
  var chars: seq[string] = @[]
  if args[3].kind == vkArray:
    for charVal in args[3].arr:
      chars.add($(charVal))
  
  let style = valueToStyle(args[4])
  
  # Create offsets (vertical stack by default)
  var offsets: seq[tuple[x, y: int]] = @[]
  for i in 0..<chars.len:
    offsets.add((0, i))
  
  let detail = DetailPoint(x: x, y: y, chars: chars, offsets: offsets)
  addDetail(layer, detail, style, gDrawProc)
  
  return valNil()

# ==============================================================================
# NIMINI BINDINGS - CHARACTER SETS
# ==============================================================================

proc nimini_getBoxChars*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get a box character set by name. Args: category (string)
  ## Returns: array of characters
  let category = if args.len > 0: $(args[0]) else: "solid"
  
  var chars: seq[string]
  case category
  of "solid": chars = BoxDrawing.solid
  of "double": chars = BoxDrawing.double
  of "lightBreaks": chars = BoxDrawing.lightBreaks
  of "heavyBreaks": chars = BoxDrawing.heavyBreaks
  of "branches": chars = BoxDrawing.branches
  of "weathered": chars = BoxDrawing.weathered
  of "corners": chars = BoxDrawing.corners
  else: chars = BoxDrawing.solid
  
  var values: seq[Value] = @[]
  for ch in chars:
    values.add(valString(ch))
  
  return valArray(values)

proc nimini_getBorderCorners*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get border corner characters by style. Args: style (string)
  ## Returns: array of 4 corner characters [TL, TR, BL, BR]
  let style = if args.len > 0: $(args[0]) else: "classic"
  
  var corners: array[4, string]
  case style
  of "classic": corners = BorderCorners.classic
  of "double": corners = BorderCorners.double
  of "rounded": corners = BorderCorners.rounded
  of "heavy": corners = BorderCorners.heavy
  of "weathered": corners = BorderCorners.weathered
  else: corners = BorderCorners.classic
  
  var values: seq[Value] = @[]
  for corner in corners:
    values.add(valString(corner))
  
  return valArray(values)

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerAsciiArtBindings*(drawProc: DrawProc, appState: ptr AppState = nil) =
  ## Register all ASCII art bindings with nimini runtime
  ## Call this during initialization
  gDrawProc = drawProc
  gAppStateRef = appState
  
  # Pattern 1: Auto-exposed functions
  register_setSeedIfNeeded()
  
  # Manual wrappers: Pattern creation (return PatternFunc closures)
  registerNative("moduloPattern", nimini_moduloPattern,
    storieLibs = @["ascii_art"],
    description = "Create horizontal modulo-based pattern from rules")
  
  registerNative("moduloPatternV", nimini_moduloPatternV,
    storieLibs = @["ascii_art"],
    description = "Create vertical modulo-based pattern from rules")
  
  registerNative("solidPattern", nimini_solidPattern,
    storieLibs = @["ascii_art"],
    description = "Create solid single-character pattern")
  
  registerNative("crackedBorderPattern", nimini_crackedBorderPattern,
    storieLibs = @["ascii_art"],
    description = "Create weathered/cracked border pattern (returns table of patterns)")
  
  registerNative("simpleBorderPattern", nimini_simpleBorderPattern,
    storieLibs = @["ascii_art"],
    description = "Create simple solid border pattern (returns table of patterns)")
  
  # Manual wrappers: Drawing functions (take proc parameters)
  registerNative("drawBorder", nimini_drawBorder,
    storieLibs = @["ascii_art"],
    description = "Draw a border with custom patterns at specified position")
  
  registerNative("drawBorderFull", nimini_drawBorderFull,
    storieLibs = @["ascii_art"],
    description = "Draw a border that fills the entire terminal")
  
  # Manual wrappers: Generators (return custom types)
  registerNative("generateCracks", nimini_generateCracks,
    imports = @["random"],
    storieLibs = @["ascii_art"],
    description = "Generate random crack details for weathered effects")
  
  registerNative("addDetail", nimini_addDetail,
    storieLibs = @["ascii_art"],
    description = "Add a decorative detail at specified position")
  
  # Manual wrappers: Utilities (custom types)
  registerNative("getBoxChars", nimini_getBoxChars,
    storieLibs = @["ascii_art"],
    description = "Get box drawing characters by category")
  
  registerNative("getBorderCorners", nimini_getBorderCorners,
    storieLibs = @["ascii_art"],
    description = "Get corner characters for border style")
  
  # Register ASCII art content rendering
  registerNative("drawAscii", nimini_drawAscii,
    storieLibs = @["ascii_art"],
    description = "Draw ASCII art from a code block")

export registerAsciiArtBindings, DrawProc
