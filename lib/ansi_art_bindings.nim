## Nimini bindings for ANSI Art Parser
## Exposes ANSI parsing and rendering functions to nimini scripts

import ../nimini
import ../nimini/runtime
import ansi_parser
import std/[tables, strutils]

when not declared(Style):
  import ../src/types

when not declared(TermBuffer):
  import ../src/layers

when defined(emscripten):
  proc emConsoleLog(msg: cstring) {.importc: "emConsoleLog".}

# Global cache for parsed ANSI buffers to avoid re-parsing
var gAnsiBuffers = initTable[string, TermBuffer]()

# Global reference to draw procedure (set by registerAnsiArtBindings)
type DrawProc* = proc(layer, x, y: int, char: string, style: Style)
var gDrawProc: DrawProc

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

proc valueToString(v: Value): string =
  if v.kind == vkString:
    return v.s
  return ""

# ==============================================================================
# NIMINI BINDINGS - ANSI ART RENDERING
# ==============================================================================

proc nimini_drawAnsi*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw ANSI art from a code block. Args: layer (int), x (int), y (int), artName (string), [skipConversion (bool)]
  ## Convenience function that loads, parses, and draws ANSI art in one call
  ## artName supports colon syntax: "ansi:logo" or just "logo" (assumes "ansi:" prefix)
  ## skipConversion: if true, assumes content already has proper escape sequences (for .ans files)
  if args.len < 4:
    when defined(emscripten):
      emConsoleLog("[drawAnsi] Not enough args".cstring)
    else:
      echo "[drawAnsi] Not enough args"
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let artName = valueToString(args[3])
  let skipConversion = if args.len > 4 and args[4].kind == vkBool: args[4].b else: false
  
  # Build the block type identifier
  let blockType = if artName.contains(":"): artName else: "ansi:" & artName
  
  # Check if we've already parsed this ANSI art
  if not gAnsiBuffers.hasKey(blockType):
    
    # Need to parse it - get the content
    let getContentFunc = env.getVar("getContent")
    if getContentFunc.kind != vkFunction or not getContentFunc.fnVal.isNative:
      return valNil()
    
    # Call getContent to get the ANSI art as array of lines
    var getContentArgs = @[valString(blockType)]
    let artLines = getContentFunc.fnVal.native(env, getContentArgs)
    
    if artLines.kind != vkArray or artLines.arr.len == 0:
      return valNil()
    
    if artLines.kind != vkArray or artLines.arr.len == 0:
      return valNil()
    
    # Join lines back into single string with newlines
    var ansiContent = ""
    for i, lineVal in artLines.arr:
      ansiContent.add(valueToString(lineVal))
      if i < artLines.arr.len - 1:
        ansiContent.add("\n")
    
    # Fix markdown ANSI: replace literal "[" with "\x1b[" for ANSI sequences
    # Skip this conversion if the content already has proper escape sequences (e.g., .ans files)
    if not skipConversion:
      var fixedContent = ""
      for ch in ansiContent:
        if ch == '[':
          fixedContent.add('\x1b')
          fixedContent.add('[')
        else:
          fixedContent.add(ch)
      ansiContent = fixedContent
    
    # Parse the ANSI content into a buffer
    let buffer = parseAnsiToBuffer(ansiContent)
    gAnsiBuffers[blockType] = buffer
  
  # Get the cached buffer
  let buffer = gAnsiBuffers[blockType]
  
  # Draw the buffer using the global draw proc
  if gDrawProc.isNil:
    return valNil()
  
  for bufY in 0 ..< buffer.height:
    for bufX in 0 ..< buffer.width:
      let idx = bufY * buffer.width + bufX
      let cell = buffer.cells[idx]
      
      # Skip empty cells
      if cell.ch.len > 0 and cell.ch[0] != ' ':
        gDrawProc(layer, x + bufX, y + bufY, cell.ch, cell.style)
  
  return valNil()

proc nimini_parseAnsi*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Parse ANSI text into a buffer. Args: ansiText (string), [maxWidth (int)]
  ## Returns: buffer ID (string) that can be used with drawAnsiBuffer
  if args.len < 1:
    return valNil()
  
  let ansiText = valueToString(args[0])
  let maxWidth = if args.len > 1: valueToInt(args[1]) else: 120
  
  # Parse the ANSI content
  let buffer = parseAnsiToBuffer(ansiText, maxWidth)
  
  # Generate a unique ID for this buffer
  let bufferId = "ansi_parsed_" & $gAnsiBuffers.len
  gAnsiBuffers[bufferId] = buffer
  
  return valString(bufferId)

proc nimini_drawAnsiBuffer*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw a previously parsed ANSI buffer. Args: layer (int), x (int), y (int), bufferId (string)
  if args.len < 4:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let bufferId = valueToString(args[3])
  
  if not gAnsiBuffers.hasKey(bufferId):
    return valNil()
  
  let buffer = gAnsiBuffers[bufferId]
  
  # Draw the buffer
  if gDrawProc.isNil:
    return valNil()
  
  for bufY in 0 ..< buffer.height:
    for bufX in 0 ..< buffer.width:
      let idx = bufY * buffer.width + bufX
      let cell = buffer.cells[idx]
      
      # Draw all cells including spaces (to preserve backgrounds)
      if cell.ch.len > 0:
        gDrawProc(layer, x + bufX, y + bufY, cell.ch, cell.style)
  
  return valNil()

proc nimini_stripAnsi*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Remove ANSI escape sequences from text. Args: text (string)
  ## Returns: plain text (string)
  if args.len < 1:
    return valString("")
  
  let text = valueToString(args[0])
  let stripped = stripAnsi(text)
  return valString(stripped)

proc nimini_getAnsiDimensions*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get dimensions of ANSI text. Args: text (string)
  ## Returns: object with width and height properties
  if args.len < 1:
    return valNil()
  
  let text = valueToString(args[0])
  let (width, height) = getAnsiTextDimensions(text)
  
  # Return as a map
  var obj = initTable[string, Value]()
  obj["width"] = valInt(width)
  obj["height"] = valInt(height)
  return valMap(obj)

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerAnsiArtBindings*(env: ref Env, drawProc: DrawProc) =
  ## Register all ANSI art bindings with a nimini environment
  ## Must be called before using any ANSI art functions
  gDrawProc = drawProc
  
  # Core ANSI functions
  env.setVar("drawAnsi", valNativeFunc(nimini_drawAnsi))
  env.setVar("parseAnsi", valNativeFunc(nimini_parseAnsi))
  env.setVar("drawAnsiBuffer", valNativeFunc(nimini_drawAnsiBuffer))
  env.setVar("stripAnsi", valNativeFunc(nimini_stripAnsi))
  env.setVar("getAnsiDimensions", valNativeFunc(nimini_getAnsiDimensions))

proc clearAnsiBufferCache* =
  ## Clear the ANSI buffer cache (useful when reloading content)
  gAnsiBuffers.clear()
