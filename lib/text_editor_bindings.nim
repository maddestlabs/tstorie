## Nimini bindings for Text Editor
##
## Exposes text editor functions to nimini scripts for building
## rich text editing experiences.
##
## BINDING PATTERN:
## This module uses the REGISTRY PATTERN - no auto-exposed functions.
##
## Why no auto-expose?
## - EditorState is a ref object with complex state (buffer, cursor, selection, undo stack)
## - Native functions: take EditorState ref as parameter
## - Nimini API: takes string ID as first parameter, does registry lookup
## - These are fundamentally different signatures (string → lookup vs direct ref)
##
## Benefits of registry pattern:
## - Avoids passing ref objects through nimini Value system
## - Scripts use simple string IDs: "editor_1", "editor_2"
## - Multiple editors can coexist with different IDs
## - Complex state management stays in native code
##
## All ~30 functions use manual wrappers with this pattern:
##   proc nimini_editorXxx(env, args): Value =
##     let editorId = valueToString(args[0])  # Get editor ID
##     gEditorStates[editorId].nativeMethod()  # Lookup + call

import ../nimini
import ../nimini/runtime
import ../nimini/type_converters
import text_editor
import std/[tables, strutils]

when not declared(Style):
  import ../src/types

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

proc valueToBool(v: Value): bool =
  case v.kind
  of vkBool: return v.b
  of vkInt: return v.i != 0
  else: return false

proc valueToString(v: Value): string =
  if v.kind == vkString:
    return v.s
  return ""

proc valueToStringSeq(v: Value): seq[string] =
  if v.kind == vkArray:
    result = @[]
    for item in v.arr:
      result.add(valueToString(item))
  else:
    result = @[""]

# ==============================================================================
# EDITOR STATE STORAGE
# ==============================================================================

# Store editor states so they can be referenced by ID in scripts
var gEditorStates = initTable[string, EditorState]()
var gEditorIdCounter = 0

proc storeEditorState(state: EditorState): string =
  ## Store an editor state and return its ID
  gEditorIdCounter += 1
  let id = "editor_" & $gEditorIdCounter
  gEditorStates[id] = state
  return id

proc getEditorState(id: string): EditorState =
  ## Retrieve a stored editor state by ID
  if gEditorStates.hasKey(id):
    return gEditorStates[id]
  return nil

# ==============================================================================
# EDITOR CREATION
# ==============================================================================

proc nimini_newEditor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new editor. Args: content (string or array of strings)
  ## Returns: editor ID (string)
  var state: EditorState
  
  if args.len > 0:
    if args[0].kind == vkString:
      # Single string - create from text
      state = newEditorState(valueToString(args[0]))
    elif args[0].kind == vkArray:
      # Array of strings - create from lines
      state = newEditorState(valueToStringSeq(args[0]))
    else:
      # Empty editor
      state = newEditorState("")
  else:
    # No args - empty editor
    state = newEditorState("")
  
  return valString(storeEditorState(state))

# ==============================================================================
# EDITOR CONTENT ACCESS
# ==============================================================================

proc nimini_editorGetText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get entire editor content as string. Args: editorId
  if args.len < 1:
    return valString("")
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if state.isNil:
    return valString("")
  
  return valString(state.buffer.getText())

proc nimini_editorGetLines*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get all lines as array. Args: editorId
  if args.len < 1:
    return valArray(@[])
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if state.isNil:
    return valArray(@[])
  
  let lines = state.buffer.getLines()
  var arr: seq[Value] = @[]
  for line in lines:
    arr.add(valString(line))
  
  return valArray(arr)

proc nimini_editorGetLine*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get a specific line. Args: editorId, lineIndex
  if args.len < 2:
    return valString("")
  
  let editorId = valueToString(args[0])
  let lineIdx = valueToInt(args[1])
  let state = getEditorState(editorId)
  if state.isNil:
    return valString("")
  
  return valString(state.buffer.getLine(lineIdx))

proc nimini_editorLineCount*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get number of lines. Args: editorId
  if args.len < 1:
    return valInt(0)
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if state.isNil:
    return valInt(0)
  
  return valInt(state.buffer.lineCount)

proc nimini_editorIsModified*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if editor has been modified. Args: editorId
  if args.len < 1:
    return valBool(false)
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if state.isNil:
    return valBool(false)
  
  return valBool(state.buffer.modified)

# ==============================================================================
# CURSOR OPERATIONS
# ==============================================================================

proc nimini_editorGetCursor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get cursor position. Args: editorId
  ## Returns: map with 'line' and 'col' keys
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if state.isNil:
    return valNil()
  
  var map = initTable[string, Value]()
  map["line"] = valInt(state.cursor.line)
  map["col"] = valInt(state.cursor.col)
  return valMap(map)

proc nimini_editorSetCursor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set cursor position. Args: editorId, line, col
  if args.len < 3:
    return valNil()
  
  let editorId = valueToString(args[0])
  let line = valueToInt(args[1])
  let col = valueToInt(args[2])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursor(line, col)
  
  return valNil()

proc nimini_editorGetScroll*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get scroll position. Args: editorId
  ## Returns: map with 'scrollX' and 'scrollY' keys
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if state.isNil:
    return valNil()
  
  var map = initTable[string, Value]()
  map["scrollX"] = valInt(state.scrollX)
  map["scrollY"] = valInt(state.scrollY)
  return valMap(map)

# ==============================================================================
# TEXT EDITING
# ==============================================================================

proc nimini_editorInsertText*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Insert text at cursor. Args: editorId, text
  if args.len < 2:
    return valNil()
  
  let editorId = valueToString(args[0])
  let text = valueToString(args[1])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.insertTextAtCursor(text)
  
  return valNil()

proc nimini_editorInsertChar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Insert character at cursor. Args: editorId, char
  if args.len < 2:
    return valNil()
  
  let editorId = valueToString(args[0])
  let text = valueToString(args[1])
  let state = getEditorState(editorId)
  if not state.isNil and text.len > 0:
    state.insertCharAtCursor(text[0])
  
  return valNil()

proc nimini_editorBackspace*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Backspace at cursor. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.backspaceAtCursor()
  
  return valNil()

proc nimini_editorDelete*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Delete at cursor. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.deleteAtCursor()
  
  return valNil()

proc nimini_editorInsertNewline*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Insert newline at cursor. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.insertNewlineAtCursor()
  
  return valNil()

proc nimini_editorInsertTab*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Insert tab at cursor. Args: editorId, useSoftTabs (optional, default true)
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let useSoftTabs = if args.len > 1: valueToBool(args[1]) else: true
  let state = getEditorState(editorId)
  if not state.isNil:
    state.insertTabAtCursor(useSoftTabs)
  
  return valNil()

# ==============================================================================
# CURSOR MOVEMENT
# ==============================================================================

proc nimini_editorMoveCursor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor by delta. Args: editorId, deltaLine, deltaCol
  if args.len < 3:
    return valNil()
  
  let editorId = valueToString(args[0])
  let deltaLine = valueToInt(args[1])
  let deltaCol = valueToInt(args[2])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorRelative(deltaLine, deltaCol)
  
  return valNil()

proc nimini_editorMoveUp*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor up. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorUp()
  
  return valNil()

proc nimini_editorMoveDown*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor down. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorDown()
  
  return valNil()

proc nimini_editorMoveLeft*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor left. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorLeft()
  
  return valNil()

proc nimini_editorMoveRight*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor right. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorRight()
  
  return valNil()

proc nimini_editorMoveHome*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor to line start. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorToLineStart()
  
  return valNil()

proc nimini_editorMoveEnd*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor to line end. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorToLineEnd()
  
  return valNil()

proc nimini_editorMoveBufferStart*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor to buffer start. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorToBufferStart()
  
  return valNil()

proc nimini_editorMoveBufferEnd*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Move cursor to buffer end. Args: editorId
  if args.len < 1:
    return valNil()
  
  let editorId = valueToString(args[0])
  let state = getEditorState(editorId)
  if not state.isNil:
    state.moveCursorToBufferEnd()
  
  return valNil()

# ==============================================================================
# RENDERING
# ==============================================================================

proc nimini_drawEditor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw the editor. Args: layer, x, y, w, h, editorId, showLineNumbers (optional), 
  ## hasSelection, selStartLine, selStartCol, selEndLine, selEndCol (all optional for selection)
  if args.len < 6:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let editorId = valueToString(args[5])
  
  let state = getEditorState(editorId)
  if state.isNil:
    return valNil()
  
  # Parse optional selection parameters (args 7-11)
  if args.len >= 12:
    let hasSelection = valueToBool(args[7])
    if hasSelection:
      state.selection.active = true
      state.selection.start.line = valueToInt(args[8])
      state.selection.start.col = valueToInt(args[9])
      state.selection.`end`.line = valueToInt(args[10])
      state.selection.`end`.col = valueToInt(args[11])
    else:
      state.selection.active = false
  else:
    state.selection.active = false
  
  # Create config
  let showLineNumbers = if args.len > 6: valueToBool(args[6]) else: true
  let config = EditorConfig(
    showLineNumbers: showLineNumbers,
    lineNumberWidth: 5,
    showScrollbar: true,
    highlightCurrentLine: false,
    wrapLines: false,
    useSoftTabs: true
  )
  
  # Update scroll to keep cursor visible
  state.updateEditorScroll(h, w)
  
  # Draw the editor
  drawEditor(layer, x, y, w, h, state, config)
  
  return valNil()

proc nimini_drawMinimap*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw minimap. Args: layer, x, y, w, h, editorId, viewportHeight
  if args.len < 7:
    return valNil()
  
  let layer = valueToInt(args[0])
  let x = valueToInt(args[1])
  let y = valueToInt(args[2])
  let w = valueToInt(args[3])
  let h = valueToInt(args[4])
  let editorId = valueToString(args[5])
  let viewportHeight = valueToInt(args[6])
  
  let state = getEditorState(editorId)
  if state.isNil:
    return valNil()
  
  drawMinimap(layer, x, y, w, h, state.buffer, state.scrollY, viewportHeight)
  
  return valNil()

# ==============================================================================
# INPUT HANDLING
# ==============================================================================

proc nimini_editorHandleKey*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle key press. Args: editorId, keyCode, key, mods (array)
  ## Returns: true if handled
  if args.len < 4:
    return valBool(false)
  
  let editorId = valueToString(args[0])
  let keyCode = valueToInt(args[1])
  let key = valueToString(args[2])
  
  # Parse mods array
  var mods: seq[string] = @[]
  if args[3].kind == vkArray:
    for modVal in args[3].arr:
      mods.add(valueToString(modVal))
  
  let state = getEditorState(editorId)
  if state.isNil:
    return valBool(false)
  
  let handled = state.handleEditorKeyPress(keyCode, key, mods)
  
  # Update scroll after key press
  if handled:
    state.updateEditorScroll(25, 80)  # Default viewport dimensions
  
  return valBool(handled)

proc nimini_editorHandleClick*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse click. Args: editorId, mouseX, mouseY, editorX, editorY, editorW, editorH, showLineNumbers
  ## Returns: true if handled
  if args.len < 8:
    return valBool(false)
  
  let editorId = valueToString(args[0])
  let mouseX = valueToInt(args[1])
  let mouseY = valueToInt(args[2])
  let editorX = valueToInt(args[3])
  let editorY = valueToInt(args[4])
  let editorW = valueToInt(args[5])
  let editorH = valueToInt(args[6])
  let showLineNumbers = valueToBool(args[7])
  
  let state = getEditorState(editorId)
  if state.isNil:
    return valBool(false)
  
  let config = EditorConfig(
    showLineNumbers: showLineNumbers,
    lineNumberWidth: 5,
    showScrollbar: true,
    highlightCurrentLine: false,
    wrapLines: false,
    useSoftTabs: true
  )
  
  let handled = state.handleEditorMouseClick(mouseX, mouseY, editorX, editorY, 
                                            editorW, editorH, config)
  
  return valBool(handled)

proc nimini_editorHandleMinimapClick*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle minimap click for scrolling. Args: editorId, mouseX, mouseY, editorX, editorY, editorW, editorH, showLineNumbers
  ## Returns: true if handled
  if args.len < 8:
    return valBool(false)
  
  let editorId = valueToString(args[0])
  let mouseX = valueToInt(args[1])
  let mouseY = valueToInt(args[2])
  let editorX = valueToInt(args[3])
  let editorY = valueToInt(args[4])
  let editorW = valueToInt(args[5])
  let editorH = valueToInt(args[6])
  let showLineNumbers = valueToBool(args[7])
  
  let state = getEditorState(editorId)
  if state.isNil:
    return valBool(false)
  
  let config = EditorConfig(
    showLineNumbers: showLineNumbers,
    lineNumberWidth: 5,
    showScrollbar: true,
    highlightCurrentLine: false,
    wrapLines: false,
    useSoftTabs: true
  )
  
  let handled = state.handleMinimapClick(mouseX, mouseY, editorX, editorY, 
                                        editorW, editorH, config)
  
  return valBool(handled)

# ==============================================================================
# REGISTRATION
# ==============================================================================

proc registerTextEditorBindings*(env: ref Env) =
  ## Register all text editor bindings with nimini environment
  
  # Editor creation
  registerNative("newEditor", nimini_newEditor)
  
  # Content access
  registerNative("editorGetText", nimini_editorGetText)
  registerNative("editorGetLines", nimini_editorGetLines)
  registerNative("editorGetLine", nimini_editorGetLine)
  registerNative("editorLineCount", nimini_editorLineCount)
  registerNative("editorIsModified", nimini_editorIsModified)
  
  # Cursor operations
  registerNative("editorGetCursor", nimini_editorGetCursor)
  registerNative("editorSetCursor", nimini_editorSetCursor)
  registerNative("editorGetScroll", nimini_editorGetScroll)
  
  # Text editing
  registerNative("editorInsertText", nimini_editorInsertText)
  registerNative("editorInsertChar", nimini_editorInsertChar)
  registerNative("editorBackspace", nimini_editorBackspace)
  registerNative("editorDelete", nimini_editorDelete)
  registerNative("editorInsertNewline", nimini_editorInsertNewline)
  registerNative("editorInsertTab", nimini_editorInsertTab)
  
  # Cursor movement
  registerNative("editorMoveCursor", nimini_editorMoveCursor)
  registerNative("editorMoveUp", nimini_editorMoveUp)
  registerNative("editorMoveDown", nimini_editorMoveDown)
  registerNative("editorMoveLeft", nimini_editorMoveLeft)
  registerNative("editorMoveRight", nimini_editorMoveRight)
  registerNative("editorMoveHome", nimini_editorMoveHome)
  registerNative("editorMoveEnd", nimini_editorMoveEnd)
  registerNative("editorMoveBufferStart", nimini_editorMoveBufferStart)
  registerNative("editorMoveBufferEnd", nimini_editorMoveBufferEnd)
  
  # Rendering
  registerNative("drawEditor", nimini_drawEditor)
  registerNative("drawMinimap", nimini_drawMinimap)
  
  # Input handling
  registerNative("editorHandleKey", nimini_editorHandleKey)
  registerNative("editorHandleClick", nimini_editorHandleClick)
  registerNative("editorHandleMinimapClick", nimini_editorHandleMinimapClick)
