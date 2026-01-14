## Common Type Converters for Nimini Bindings
##
## Provides shared conversion functions for common tstorie types like Style, Color, etc.
## This eliminates duplication across binding files and enables auto-bindings for complex types.

import runtime
import ../src/types
import std/[strutils, tables]

# Export runtime types that modules might need
export runtime.Value, runtime.ValueKind, runtime.valInt, runtime.valFloat,
       runtime.valString, runtime.valBool, runtime.valNil, runtime.valArray, runtime.valMap

# ==============================================================================
# BASIC TYPE HELPERS (already in auto_bindings, but useful standalone too)
# ==============================================================================

proc valueToInt*(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

proc valueToFloat*(v: Value): float =
  case v.kind
  of vkFloat: return v.f
  of vkInt: return float(v.i)
  else: return 0.0

proc valueToString*(v: Value): string =
  if v.kind == vkString:
    return v.s
  return ""

proc valueToBool*(v: Value): bool =
  case v.kind
  of vkBool: return v.b
  of vkInt: return v.i != 0
  else: return false

# ==============================================================================
# STYLE CONVERTERS
# ==============================================================================

proc valueToStyle*(v: Value): Style =
  ## Convert nimini Value to Style
  ## Handles both hex strings (#RRGGBB) and RGB maps ({r, g, b})
  if v.kind == vkMap:
    var style = Style()
    
    # Foreground color
    if v.map.hasKey("fg"):
      let fgVal = v.map["fg"]
      if fgVal.kind == vkString:
        # Parse hex color string
        let hexStr = fgVal.s
        if hexStr.len >= 7 and hexStr[0] == '#':
          let r = parseHexInt(hexStr[1..2])
          let g = parseHexInt(hexStr[3..4])
          let b = parseHexInt(hexStr[5..6])
          style.fg = Color(r: uint8(r), g: uint8(g), b: uint8(b))
      elif fgVal.kind == vkMap:
        # Parse RGB map (from getStyle())
        if fgVal.map.hasKey("r") and fgVal.map.hasKey("g") and fgVal.map.hasKey("b"):
          style.fg = Color(
            r: uint8(valueToInt(fgVal.map["r"])),
            g: uint8(valueToInt(fgVal.map["g"])),
            b: uint8(valueToInt(fgVal.map["b"]))
          )
    
    # Background color
    if v.map.hasKey("bg"):
      let bgVal = v.map["bg"]
      if bgVal.kind == vkString:
        let hexStr = bgVal.s
        if hexStr.len >= 7 and hexStr[0] == '#':
          let r = parseHexInt(hexStr[1..2])
          let g = parseHexInt(hexStr[3..4])
          let b = parseHexInt(hexStr[5..6])
          style.bg = Color(r: uint8(r), g: uint8(g), b: uint8(b))
      elif bgVal.kind == vkMap:
        # Parse RGB map (from getStyle())
        if bgVal.map.hasKey("r") and bgVal.map.hasKey("g") and bgVal.map.hasKey("b"):
          style.bg = Color(
            r: uint8(valueToInt(bgVal.map["r"])),
            g: uint8(valueToInt(bgVal.map["g"])),
            b: uint8(valueToInt(bgVal.map["b"]))
          )
    
    # Style attributes
    if v.map.hasKey("bold"):
      style.bold = valueToBool(v.map["bold"])
    if v.map.hasKey("italic"):
      style.italic = valueToBool(v.map["italic"])
    if v.map.hasKey("underline"):
      style.underline = valueToBool(v.map["underline"])
    if v.map.hasKey("dim"):
      style.dim = valueToBool(v.map["dim"])
    
    return style
  
  # Fallback to default white on black
  return Style(
    fg: Color(r: 255'u8, g: 255'u8, b: 255'u8),
    bg: Color(r: 0'u8, g: 0'u8, b: 0'u8),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

proc styleToValue*(s: Style): Value =
  ## Convert Style to nimini Value (as map)
  var m = initTable[string, Value]()
  
  # Foreground as RGB map
  var fg = initTable[string, Value]()
  fg["r"] = valInt(int(s.fg.r))
  fg["g"] = valInt(int(s.fg.g))
  fg["b"] = valInt(int(s.fg.b))
  m["fg"] = valMap(fg)
  
  # Background as RGB map
  var bg = initTable[string, Value]()
  bg["r"] = valInt(int(s.bg.r))
  bg["g"] = valInt(int(s.bg.g))
  bg["b"] = valInt(int(s.bg.b))
  m["bg"] = valMap(bg)
  
  # Style attributes
  m["bold"] = valBool(s.bold)
  m["italic"] = valBool(s.italic)
  m["underline"] = valBool(s.underline)
  m["dim"] = valBool(s.dim)
  
  return valMap(m)

# ==============================================================================
# COLOR CONVERTERS
# ==============================================================================

proc valueToColor*(v: Value): Color =
  ## Convert nimini Value to Color
  ## Handles hex strings (#RRGGBB) and RGB maps ({r, g, b})
  if v.kind == vkString:
    # Parse hex color string
    let hexStr = v.s
    if hexStr.len >= 7 and hexStr[0] == '#':
      let r = parseHexInt(hexStr[1..2])
      let g = parseHexInt(hexStr[3..4])
      let b = parseHexInt(hexStr[5..6])
      return Color(r: uint8(r), g: uint8(g), b: uint8(b))
  elif v.kind == vkMap:
    # Parse RGB map
    if v.map.hasKey("r") and v.map.hasKey("g") and v.map.hasKey("b"):
      return Color(
        r: uint8(valueToInt(v.map["r"])),
        g: uint8(valueToInt(v.map["g"])),
        b: uint8(valueToInt(v.map["b"]))
      )
  
  # Fallback to white
  return Color(r: 255'u8, g: 255'u8, b: 255'u8)

proc colorToValue*(c: Color): Value =
  ## Convert Color to nimini Value (as RGB map)
  var m = initTable[string, Value]()
  m["r"] = valInt(int(c.r))
  m["g"] = valInt(int(c.g))
  m["b"] = valInt(int(c.b))
  return valMap(m)

# ==============================================================================
# SEQUENCE CONVERTERS
# ==============================================================================

proc valueToSeqInt*(v: Value): seq[int] =
  ## Convert nimini array to seq[int]
  result = @[]
  if v.kind == vkArray:
    for item in v.arr:
      result.add(valueToInt(item))

proc seqIntToValue*(s: seq[int]): Value =
  ## Convert seq[int] to nimini array
  var arr: seq[Value] = @[]
  for item in s:
    arr.add(valInt(item))
  return valArray(arr)

proc valueToSeqString*(v: Value): seq[string] =
  ## Convert nimini array to seq[string]
  result = @[]
  if v.kind == vkArray:
    for item in v.arr:
      result.add(valueToString(item))

proc seqStringToValue*(s: seq[string]): Value =
  ## Convert seq[string] to nimini array
  var arr: seq[Value] = @[]
  for item in s:
    arr.add(valString(item))
  return valArray(arr)

proc valueToSeqFloat*(v: Value): seq[float] =
  ## Convert nimini array to seq[float]
  result = @[]
  if v.kind == vkArray:
    for item in v.arr:
      result.add(valueToFloat(item))

proc seqFloatToValue*(s: seq[float]): Value =
  ## Convert seq[float] to nimini array
  var arr: seq[Value] = @[]
  for item in s:
    arr.add(valFloat(item))
  return valArray(arr)

# ==============================================================================
# TUPLE CONVERTERS
# ==============================================================================

proc tupleXYToValue*(t: tuple[x, y: int]): Value =
  ## Convert tuple[x, y: int] to nimini map
  var m = initTable[string, Value]()
  m["x"] = valInt(t.x)
  m["y"] = valInt(t.y)
  return valMap(m)

proc valueToTupleXY*(v: Value): tuple[x, y: int] =
  ## Convert nimini map to tuple[x, y: int]
  result = (x: 0, y: 0)
  if v.kind == vkMap:
    if v.map.hasKey("x"):
      result.x = valueToInt(v.map["x"])
    if v.map.hasKey("y"):
      result.y = valueToInt(v.map["y"])

proc seqTupleXYToValue*(s: seq[tuple[x, y: int]]): Value =
  ## Convert seq[tuple[x, y: int]] to nimini array of maps
  var arr: seq[Value] = @[]
  for item in s:
    arr.add(tupleXYToValue(item))
  return valArray(arr)

proc valueToSeqTupleXY*(v: Value): seq[tuple[x, y: int]] =
  ## Convert nimini array of maps to seq[tuple[x, y: int]]
  result = @[]
  if v.kind == vkArray:
    for item in v.arr:
      result.add(valueToTupleXY(item))

# ==============================================================================
# TUPLE (WIDTH/HEIGHT) CONVERTERS
# ==============================================================================

proc tupleWidthHeightToValue*(t: tuple[width, height: int]): Value =
  ## Convert tuple[width, height: int] to nimini map
  var m = initTable[string, Value]()
  m["width"] = valInt(t.width)
  m["height"] = valInt(t.height)
  return valMap(m)

proc valueToTupleWidthHeight*(v: Value): tuple[width, height: int] =
  ## Convert nimini map to tuple[width, height: int]
  result = (width: 0, height: 0)
  if v.kind == vkMap:
    if v.map.hasKey("width"):
      result.width = valueToInt(v.map["width"])
    if v.map.hasKey("height"):
      result.height = valueToInt(v.map["height"])
