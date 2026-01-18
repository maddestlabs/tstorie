## tStorie Core Runtime Types
##
## This module contains all core type definitions for the tStorie runtime.
## No dependencies on other modules - this is the foundation.
##
## Separated from main runtime to enable:
## - Clean imports in library modules
## - Selective imports in exported programs
## - Better code organization and maintainability

import tables
import ../lib/storie_types  # Import markdown types
import input  # All input types now come from the unified input module

# Note: Input types (InputEvent, InputEventKind, InputAction, etc.) and
# key constants (KEY_*, ModShift, etc.) are now in src/input.nim
# Re-export them here for backward compatibility
export input.InputEvent, input.InputEventKind, input.InputAction
export input.TerminalMouseButton
export input.ModShift, input.ModAlt, input.ModCtrl, input.ModSuper
export input.TerminalInputParser, input.newTerminalInputParser

# Type alias for simpler access to terminal mouse button enum
type MouseButton* = input.TerminalMouseButton

# ================================================================
# COLOR AND STYLE SYSTEM
# ================================================================

type
  Color* = object
    r*, g*, b*: uint8

  Style* = object
    fg*: Color
    bg*: Color
    bold*: bool
    underline*: bool
    italic*: bool
    dim*: bool

# Color constructor helpers
proc rgb*(r, g, b: uint8): Color =
  Color(r: r, g: g, b: b)

proc gray*(level: uint8): Color =
  rgb(level, level, level)

proc black*(): Color = rgb(0, 0, 0)
proc red*(): Color = rgb(255, 0, 0)
proc green*(): Color = rgb(0, 255, 0)
proc yellow*(): Color = rgb(255, 255, 0)
proc blue*(): Color = rgb(0, 0, 255)
proc magenta*(): Color = rgb(255, 0, 255)
proc cyan*(): Color = rgb(0, 255, 255)
proc white*(): Color = rgb(255, 255, 255)

proc dim*(c: Color): Color =
  ## Create a dimmed version of a color
  Color(r: c.r div 2, g: c.g div 2, b: c.b div 2)

# Global default style - can be overridden
var gGlobalDefaultStyle* = Style(
  fg: white(), 
  bg: black(), 
  bold: false, 
  underline: false, 
  italic: false, 
  dim: false
)

proc defaultStyle*(): Style =
  ## Get the global default style
  return gGlobalDefaultStyle

proc setGlobalDefaultStyle*(style: Style) =
  ## Set the global default style
  gGlobalDefaultStyle = style

# ================================================================
# COLOR UTILITIES FOR ANSI CONVERSION
# ================================================================

proc toAnsi256*(c: Color): int =
  ## Convert RGB color to closest ANSI 256 color index
  let r = int(c.r) * 5 div 255
  let g = int(c.g) * 5 div 255
  let b = int(c.b) * 5 div 255
  return 16 + 36 * r + 6 * g + b

proc toAnsi8*(c: Color): int =
  ## Convert RGB color to closest ANSI 8 color code (30-37)
  let bright = (int(c.r) + int(c.g) + int(c.b)) div 3 > 128
  var code = 30
  if c.r > 128: code += 1
  if c.g > 128: code += 2
  if c.b > 128: code += 4
  if bright and code == 30: code = 37
  return code

# ================================================================
# COLOR AND STYLE INTERPOLATION
# ================================================================
# Moved from lib/animation.nim - these work with core Color/Style types

proc lerpColor*(a, b: Color, t: float): Color =
  ## Interpolate between two colors
  ## t: 0.0 = color a, 1.0 = color b
  Color(
    r: uint8(float(a.r) + (float(b.r) - float(a.r)) * t),
    g: uint8(float(a.g) + (float(b.g) - float(a.g)) * t),
    b: uint8(float(a.b) + (float(b.b) - float(a.b)) * t)
  )

proc lerpStyle*(a, b: Style, t: float): Style =
  ## Linear interpolation between two styles
  ## Colors fade smoothly, other attributes switch at midpoint
  Style(
    fg: lerpColor(a.fg, b.fg, t),
    bg: lerpColor(a.bg, b.bg, t),
    bold: if t < 0.5: a.bold else: b.bold,
    underline: if t < 0.5: a.underline else: b.underline,
    italic: if t < 0.5: a.italic else: b.italic,
    dim: if t < 0.5: a.dim else: b.dim
  )

proc lerpRGB*(r1, g1, b1, r2, g2, b2: int, t: float): Color =
  ## Interpolate between two RGB values
  ## t: 0.0 = first color, 1.0 = second color
  let r = int(float(r1) + (float(r2) - float(r1)) * t)
  let g = int(float(g1) + (float(g2) - float(g1)) * t)
  let b = int(float(b1) + (float(b2) - float(b1)) * t)
  Color(
    r: uint8(clamp(r, 0, 255)),
    g: uint8(clamp(g, 0, 255)),
    b: uint8(clamp(b, 0, 255))
  )

# Terminal input parser types are now in src/input.nim
# Re-export for backward compatibility
export input.StringCsiState, input.ParserState
export input.INTERMED_MAX, input.CSI_ARGS_MAX, input.CSI_LEADER_MAX
export input.CSI_ARG_FLAG_MORE, input.CSI_ARG_MASK, input.CSI_ARG_MISSING

# ================================================================
# RENDERING TYPES
# ================================================================

type
  Cell* = object
    ch*: string
    style*: Style

  TermBuffer* = object
    width*, height*: int
    cells*: seq[Cell]
    clipX*, clipY*, clipW*, clipH*: int
    offsetX*, offsetY*: int

  Layer* = ref object
    id*: string
    z*: int
    visible*: bool
    buffer*: TermBuffer

# ================================================================
# APPLICATION STATE
# ================================================================

type
  AppState* = ref object
    running*: bool
    termWidth*, termHeight*: int
    currentBuffer*: TermBuffer
    previousBuffer*: TermBuffer
    frameCount*: int
    totalTime*: float
    fps*: float
    lastFpsUpdate*: float
    targetFps*: float
    colorSupport*: int
    layers*: seq[Layer]
    layerIndexCache*: Table[string, int]  ## Cache for O(1) layer name -> index lookup
    cacheValid*: bool                      ## Whether cache is up-to-date
    inputParser*: TerminalInputParser
    lastMouseX*, lastMouseY*: int
    audioSystemPtr*: pointer  ## Points to AudioSystem (to avoid import issues)
    themeBackground*: tuple[r, g, b: uint8]  ## Theme's background color for terminal
    styleSheet*: StyleSheet  ## Styles from front matter

# ================================================================
# CONTENT SOURCE TYPES
# ================================================================

type
  ContentSource* = enum
    csNone
    csGist
    csDemo
    csFile
