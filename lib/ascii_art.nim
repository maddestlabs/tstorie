## ASCII Art Primitives Library for tStorie
##
## Provides composable primitives for generating procedural ASCII art with
## seeded randomization. Supports the "Rebuild Pattern" for exporting
## prototype patterns to compiled native modules.
##
## Core Concepts:
## - PatternFunc: Function that generates a character at position (x, y)
## - Seeded randomization: Reproducible results with specific seeds
## - Composability: Combine patterns, layer effects, mix styles
## - Export-friendly: Patterns designed for easy compilation

import std/[tables, random, strutils, math, sequtils]

when not declared(Style):
  import ../src/types

# ==============================================================================
# TYPE DEFINITIONS
# ==============================================================================

type
  PatternFunc* = proc(x, y, w, h: int): string {.closure.}
    ## Function that generates an ASCII character at position (x, y)
    ## given total dimensions (w, h)
  
  ModuloRule* = tuple
    modBase: int      # Modulo base (e.g., x % 7)
    modValue: int     # Value to match (e.g., == 3)
    char: string      # Character to output
  
  PatternConfig* = object
    seed*: int                    # Random seed for reproducibility
    rules*: seq[ModuloRule]       # Pattern generation rules
    default*: string              # Default character when no rules match
    randomChance*: float          # Chance of random variation (0.0-1.0)
    randomChars*: seq[string]     # Pool of random characters

# ==============================================================================
# CHARACTER SET DEFINITIONS
# ==============================================================================

type
  # Box drawing characters organized by category
  BoxChars* = object
    solid*: seq[string]
    double*: seq[string]
    lightBreaks*: seq[string]
    heavyBreaks*: seq[string]
    branches*: seq[string]
    weathered*: seq[string]
    corners*: seq[string]

const
  BoxDrawing* = BoxChars(
    solid: @["─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼"],
    double: @["═", "║", "╔", "╗", "╚", "╝", "╠", "╣", "╦", "╩", "╬"],
    lightBreaks: @["╌", "╍", "┄", "┅", "┆", "┇", "┈", "┉", "┊", "┋", "╎", "╏"],
    heavyBreaks: @["╸", "╹", "╺", "╻", "╼", "╽", "╾", "╿"],
    branches: @["┬", "┴", "├", "┤", "┼", "╁", "╂", "╃", "╄", "╅", "╆", "╇", "╈", "╉", "╊", "╋"],
    weathered: @["╥", "╨", "╞", "╡", "╪", "╫", "╬", "┯", "┷", "┿", "╀"],
    corners: @["┌", "┐", "└", "┘", "╔", "╗", "╚", "╝", "╭", "╮", "╰", "╯"]
  )

# Border style presets
type
  BorderStyles* = object
    classic*: array[4, string]
    double*: array[4, string]
    rounded*: array[4, string]
    heavy*: array[4, string]
    weathered*: array[4, string]

const
  BorderCorners* = BorderStyles(
    classic: ["┌", "┐", "└", "┘"],
    double: ["╔", "╗", "╚", "╝"],
    rounded: ["╭", "╮", "╰", "╯"],
    heavy: ["┏", "┓", "┗", "┛"],
    weathered: ["╔", "╗", "╚", "╝"]  # Will be cracked in pattern
  )

# ==============================================================================
# PATTERN GENERATION FUNCTIONS
# ==============================================================================

proc setSeedIfNeeded*(seed: int) =
  ## Set random seed if non-zero
  if seed != 0:
    randomize(seed)

proc moduloPattern*(rules: seq[ModuloRule], default: string = "─"): PatternFunc =
  ## Create a pattern function from modulo rules
  ## Rules are checked in order; first match wins
  return proc(x, y, w, h: int): string =
    for rule in rules:
      if x mod rule.modBase == rule.modValue:
        return rule.char
    return default

proc moduloPatternV*(rules: seq[ModuloRule], default: string = "│"): PatternFunc =
  ## Vertical variant - checks y coordinate instead of x
  return proc(x, y, w, h: int): string =
    for rule in rules:
      if y mod rule.modBase == rule.modValue:
        return rule.char
    return default

proc randomPattern*(chars: seq[string], chance: float = 0.1, default: string = "─"): PatternFunc =
  ## Create a pattern with random character substitutions
  return proc(x, y, w, h: int): string =
    if rand(1.0) < chance:
      return chars[rand(chars.len - 1)]
    return default

proc solidPattern*(char: string): PatternFunc =
  ## Simple pattern that returns the same character everywhere
  return proc(x, y, w, h: int): string =
    return char

proc combinePatterns*(patterns: seq[PatternFunc]): PatternFunc =
  ## Combine multiple patterns with priority order
  ## First pattern to return non-empty string wins
  return proc(x, y, w, h: int): string =
    for pattern in patterns:
      let char = pattern(x, y, w, h)
      if char != "":
        return char
    return " "

proc layerPattern*(base, overlay: PatternFunc, overlayChance: float = 0.3): PatternFunc =
  ## Layer an overlay pattern on top of a base with probability
  return proc(x, y, w, h: int): string =
    if rand(1.0) < overlayChance:
      let char = overlay(x, y, w, h)
      if char != "":
        return char
    return base(x, y, w, h)

# ==============================================================================
# BORDER DRAWING PRIMITIVES
# ==============================================================================

proc drawBorderLine*(
  layer: int,
  x1, y1, x2, y2: int,
  pattern: PatternFunc,
  style: Style,
  drawProc: proc(layer, x, y: int, char: string, style: Style)
) =
  ## Draw a line of a border using a pattern function
  ## Works for horizontal or vertical lines
  if y1 == y2:
    # Horizontal line
    let w = abs(x2 - x1) + 1
    let h = 1
    let startX = min(x1, x2)
    for x in 0..<w:
      let char = pattern(x, 0, w, h)
      drawProc(layer, startX + x, y1, char, style)
  else:
    # Vertical line
    let w = 1
    let h = abs(y2 - y1) + 1
    let startY = min(y1, y2)
    for y in 0..<h:
      let char = pattern(0, y, w, h)
      drawProc(layer, x1, startY + y, char, style)

proc drawBorder*(
  layer: int,
  x, y, width, height: int,
  topPattern, bottomPattern, leftPattern, rightPattern: PatternFunc,
  corners: array[4, string],
  style: Style,
  drawProc: proc(layer, x, y: int, char: string, style: Style)
) =
  ## Draw a complete border with custom patterns for each edge
  ## corners = [topLeft, topRight, bottomLeft, bottomRight]
  
  # Top edge
  for px in 1..<(width - 1):
    let char = topPattern(px, 0, width, height)
    drawProc(layer, x + px, y, char, style)
  
  # Bottom edge
  for px in 1..<(width - 1):
    let char = bottomPattern(px, height - 1, width, height)
    drawProc(layer, x + px, y + height - 1, char, style)
  
  # Left edge
  for py in 1..<(height - 1):
    let char = leftPattern(0, py, width, height)
    drawProc(layer, x, y + py, char, style)
  
  # Right edge
  for py in 1..<(height - 1):
    let char = rightPattern(width - 1, py, width, height)
    drawProc(layer, x + width - 1, y + py, char, style)
  
  # Corners
  drawProc(layer, x, y, corners[0], style)
  drawProc(layer, x + width - 1, y, corners[1], style)
  drawProc(layer, x, y + height - 1, corners[2], style)
  drawProc(layer, x + width - 1, y + height - 1, corners[3], style)

# ==============================================================================
# DETAIL DECORATION SYSTEM
# ==============================================================================

type
  DetailPoint* = object
    x*, y*: int                    # Base position
    chars*: seq[string]            # Characters to draw
    offsets*: seq[tuple[x, y: int]]  # Relative positions for each char

proc addDetail*(
  layer: int,
  detail: DetailPoint,
  style: Style,
  drawProc: proc(layer, x, y: int, char: string, style: Style)
) =
  ## Add a detail decoration at a specific point
  for i, char in detail.chars:
    if i < detail.offsets.len:
      let (dx, dy) = detail.offsets[i]
      drawProc(layer, detail.x + dx, detail.y + dy, char, style)

proc generateCrackDetails*(
  seed: int,
  width, height: int,
  density: float = 0.05,
  crackChars: seq[string] = @["┯", "┷", "╽", "╿"]
): seq[DetailPoint] =
  ## Generate random crack details for weathered borders
  setSeedIfNeeded(seed)
  result = @[]
  
  let numCracks = int(float(width + height) * density)
  for i in 0..<numCracks:
    let x = rand(2..(width - 3))
    let y = rand(1..(height - 2))
    
    # Pick 1-2 characters for the crack
    let numChars = rand(1..2)
    var chars: seq[string] = @[]
    var offsets: seq[tuple[x, y: int]] = @[]
    
    for j in 0..<numChars:
      chars.add(crackChars[rand(crackChars.len - 1)])
      offsets.add((0, j))
    
    result.add(DetailPoint(
      x: x,
      y: y,
      chars: chars,
      offsets: offsets
    ))

# ==============================================================================
# PRESET PATTERN GENERATORS
# ==============================================================================

proc crackedBorderPattern*(seed: int): tuple[top, bottom, left, right: PatternFunc] =
  ## Generate the "cracked/weathered" border pattern from depths.md
  ## This is the pattern that inspired the system!
  setSeedIfNeeded(seed)
  
  result.top = moduloPattern(@[
    (7, 3, "╌"),
    (11, 5, "┬"),
    (13, 2, "╥"),
    (17, 8, "┴")
  ], "─")
  
  result.bottom = moduloPattern(@[
    (8, 2, "╌"),
    (12, 7, "┴"),
    (15, 4, "╨"),
    (19, 11, "┬")
  ], "─")
  
  result.left = moduloPatternV(@[
    (6, 2, "╎"),
    (9, 4, "├"),
    (13, 7, "╞"),
    (16, 10, "┤")
  ], "│")
  
  result.right = moduloPatternV(@[
    (7, 3, "╎"),
    (10, 5, "┤"),
    (14, 8, "╡"),
    (17, 11, "├")
  ], "│")

proc simpleBorderPattern*(): tuple[top, bottom, left, right: PatternFunc] =
  ## Simple solid border pattern
  result.top = solidPattern("─")
  result.bottom = solidPattern("─")
  result.left = solidPattern("│")
  result.right = solidPattern("│")

# ==============================================================================
# PATTERN VARIATION & EXPLORATION
# ==============================================================================

type
  PatternVariation* = object
    seed*: int
    preview*: string  # Small sample of the pattern
    description*: string

proc generateVariations*(
  patternGen: proc(seed: int): tuple[top, bottom, left, right: PatternFunc],
  count: int = 10,
  previewWidth: int = 20
): seq[PatternVariation] =
  ## Generate multiple variations of a pattern with different seeds
  ## Returns seeds and preview strings for browsing
  result = @[]
  
  for i in 0..<count:
    let seed = rand(1..999999)
    let patterns = patternGen(seed)
    
    # Generate preview of top border
    var preview = ""
    for x in 0..<previewWidth:
      preview &= patterns.top(x, 0, previewWidth, 1)
    
    result.add(PatternVariation(
      seed: seed,
      preview: preview,
      description: "Variant " & $i & " (seed: " & $seed & ")"
    ))

proc describePattern*(config: PatternConfig): string =
  ## Generate a description of a pattern configuration
  result = "Pattern(seed=" & $config.seed
  if config.rules.len > 0:
    result &= ", rules=" & $config.rules.len
  if config.randomChance > 0:
    result &= ", random=" & $(config.randomChance * 100) & "%"
  result &= ")"

# ==============================================================================
# EXPORT METADATA
# ==============================================================================

proc getPatternExportMetadata*(): tuple[
  name: string,
  description: string,
  version: string
] =
  ## Metadata for pattern export system
  result.name = "ASCII Art Pattern Library"
  result.description = "Procedural ASCII art generation with seeded randomization"
  result.version = "1.0.0"


