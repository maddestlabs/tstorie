# TStorie entry point

import strutils, tables, random, times, algorithm
when not defined(emscripten):
  import os
  import src/platform/terminal
import nimini
import lib/storie_md
import lib/layout

# Include canvas module so it has access to TermBuffer and Style types
include lib/canvas

# Figlet font data for digital clock
const figletDigits = [
  # 0
  ["+---+", "|   |", "|   |", "|   |", "+---+"],
  # 1
  ["    |", "    |", "    |", "    |", "    |"],
  # 2
  ["+---+", "    |", "+---+", "|    ", "+---+"],
  # 3
  ["+---+", "    |", "+---+", "    |", "+---+"],
  # 4
  ["|   |", "|   |", "+---+", "    |", "    |"],
  # 5
  ["+---+", "|    ", "+---+", "    |", "+---+"],
  # 6
  ["+---+", "|    ", "+---+", "|   |", "+---+"],
  # 7
  ["+---+", "    |", "    |", "    |", "    |"],
  # 8
  ["+---+", "|   |", "+---+", "|   |", "+---+"],
  # 9
  ["+---+", "|   |", "+---+", "    |", "+---+"]
]

const figletColon = [" ", "o", " ", "o", " "]

# Helper to convert Value to int (handles both int and float values)
proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

# ================================================================
# NIMINI INTEGRATION
# ================================================================

type
  NiminiContext = ref object
    env: ref Env
  
  GlobalHandler* = object
    name*: string
    callback*: Value  # Nimini function/closure
    priority*: int    # Lower = executes first (default 0)
  
  StorieContext = ref object
    codeBlocks: seq[CodeBlock]
    niminiContext: NiminiContext
    frontMatter: FrontMatter  # Front matter from markdown
    # Pre-compiled layer references
    bgLayer: Layer
    fgLayer: Layer
    # Section management
    sections: seq[Section]       # All sections from the document
    currentSectionIndex: int     # Index of currently active section (default 0)
    multiSectionMode: bool       # If true, render all sections; if false, render only current
    scrollY: int                 # Scroll position for multi-section mode
    # Global event handlers
    globalRenderHandlers*: seq[GlobalHandler]
    globalUpdateHandlers*: seq[GlobalHandler]
    globalInputHandlers*: seq[GlobalHandler]


# ================================================================
# NIMINI WRAPPERS - Bridge storie functions to Nimini
# ================================================================

# Global references to layers (set in initStorieContext)
var gBgLayer: Layer
var gFgLayer: Layer
var gTextStyle, gBorderStyle, gInfoStyle: Style
var gAppState: AppState  # Global reference to app state for state accessors

# Forward declaration for functions that will be defined later
var storieCtx: StorieContext

# ================================================================
# SECTION MANAGEMENT FUNCTIONS
# ================================================================

proc getCurrentSection*(): Section =
  ## Get the currently active section
  if storieCtx.isNil or storieCtx.sections.len == 0:
    result = Section(id: "", title: "", level: 1, blocks: @[])
  elif storieCtx.currentSectionIndex >= 0 and storieCtx.currentSectionIndex < storieCtx.sections.len:
    result = storieCtx.sections[storieCtx.currentSectionIndex]
  else:
    result = storieCtx.sections[0]

proc getAllSections*(): seq[Section] =
  ## Get all sections in the document
  if storieCtx.isNil:
    return @[]
  return storieCtx.sections

proc getSectionById*(id: string): Section =
  ## Get a section by its ID
  if storieCtx.isNil:
    return Section(id: "", title: "", level: 1, blocks: @[])
  
  for section in storieCtx.sections:
    if section.id == id:
      return section
  
  # Not found
  return Section(id: "", title: "", level: 1, blocks: @[])

proc getSectionByIndex*(index: int): Section =
  ## Get a section by its index
  if storieCtx.isNil or index < 0 or index >= storieCtx.sections.len:
    return Section(id: "", title: "", level: 1, blocks: @[])
  return storieCtx.sections[index]

proc gotoSection*(target: int): bool =
  ## Navigate to a section by index
  if storieCtx.isNil or target < 0 or target >= storieCtx.sections.len:
    return false
  
  let oldIndex = storieCtx.currentSectionIndex
  storieCtx.currentSectionIndex = target
  
  # TODO: Execute on:exit for old section and on:enter for new section
  # This would require finding code blocks with those lifecycle hooks in each section
  
  return true

proc gotoSectionById*(id: string): bool =
  ## Navigate to a section by ID
  if storieCtx.isNil:
    return false
  
  for i, section in storieCtx.sections:
    if section.id == id:
      return gotoSection(i)
  
  return false

proc createSection*(id: string, title: string, level: int = 1): bool =
  ## Create a new section and add it to the document
  if storieCtx.isNil:
    return false
  
  let newSection = Section(
    id: id,
    title: title,
    level: level,
    blocks: @[ContentBlock(kind: HeadingBlock, level: level, title: title)]
  )
  
  storieCtx.sections.add(newSection)
  return true

proc deleteSection*(id: string): bool =
  ## Delete a section by ID
  if storieCtx.isNil:
    return false
  
  var indexToDelete = -1
  for i, section in storieCtx.sections:
    if section.id == id:
      indexToDelete = i
      break
  
  if indexToDelete >= 0:
    storieCtx.sections.delete(indexToDelete)
    # Adjust current index if needed
    if storieCtx.currentSectionIndex >= storieCtx.sections.len:
      storieCtx.currentSectionIndex = max(0, storieCtx.sections.len - 1)
    return true
  
  return false

proc updateSectionTitle*(id: string, newTitle: string): bool =
  ## Update a section's title
  if storieCtx.isNil:
    return false
  
  for section in storieCtx.sections.mitems:
    if section.id == id:
      section.title = newTitle
      # Update the heading block if it exists
      for blk in section.blocks.mitems:
        if blk.kind == HeadingBlock:
          blk.title = newTitle
          break
      return true
  
  return false

proc setMultiSectionMode*(enabled: bool) =
  ## Enable or disable multi-section rendering mode
  if not storieCtx.isNil:
    storieCtx.multiSectionMode = enabled

proc getMultiSectionMode*(): bool =
  ## Get current multi-section mode setting
  if storieCtx.isNil:
    return true
  return storieCtx.multiSectionMode

proc setScrollY*(y: int) =
  ## Set scroll position for multi-section mode
  if not storieCtx.isNil:
    storieCtx.scrollY = y

proc getScrollY*(): int =
  ## Get current scroll position
  if storieCtx.isNil:
    return 0
  return storieCtx.scrollY


# Type conversion functions
proc nimini_int(env: ref Env; args: seq[Value]): Value =
  ## Convert a value to integer
  if args.len > 0:
    case args[0].kind
    of vkInt: return args[0]
    of vkFloat: return valInt(args[0].f.int)
    of vkString: 
      try:
        return valInt(parseInt(args[0].s))
      except:
        return valInt(0)
    of vkBool: return valInt(if args[0].b: 1 else: 0)
    else: return valInt(0)
  return valInt(0)

proc nimini_float(env: ref Env; args: seq[Value]): Value =
  ## Convert a value to float
  if args.len > 0:
    case args[0].kind
    of vkFloat: return args[0]
    of vkInt: return valFloat(args[0].i.float)
    of vkString: 
      try:
        return valFloat(parseFloat(args[0].s))
      except:
        return valFloat(0.0)
    of vkBool: return valFloat(if args[0].b: 1.0 else: 0.0)
    else: return valFloat(0.0)
  return valFloat(0.0)

proc nimini_str(env: ref Env; args: seq[Value]): Value =
  ## Convert a value to string
  if args.len > 0:
    return valString($args[0])
  return valString("")

# Print function
proc print(env: ref Env; args: seq[Value]): Value {.nimini.} =
  var output = ""
  for i, arg in args:
    if i > 0: output.add(" ")
    case arg.kind
    of vkInt: output.add($arg.i)
    of vkFloat: output.add($arg.f)
    of vkString: output.add(arg.s)
    of vkBool: output.add($arg.b)
    of vkNil: output.add("nil")
    else: output.add("<value>")
  echo output
  return valNil()

# Buffer drawing functions
proc bgClear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gBgLayer.buffer.clear()
  return valNil()

proc bgClearTransparent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gBgLayer.buffer.clearTransparent()
  return valNil()

proc fgClear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gFgLayer.buffer.clear()
  return valNil()

proc fgClearTransparent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gFgLayer.buffer.clearTransparent()
  return valNil()

proc bgWrite(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let ch = args[2].s
    let style = if args.len >= 4: gTextStyle else: gTextStyle  # TODO: support style arg
    gBgLayer.buffer.write(x, y, ch, style)
  return valNil()

proc fgWrite(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let ch = args[2].s
    let style = if args.len >= 4: gTextStyle else: gTextStyle
    gFgLayer.buffer.write(x, y, ch, style)
  return valNil()

proc bgWriteText(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let text = args[2].s
    gBgLayer.buffer.writeText(x, y, text, gTextStyle)
  return valNil()

proc fgWriteText(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let text = args[2].s
    gFgLayer.buffer.writeText(x, y, text, gTextStyle)
  return valNil()

proc bgFillRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 5:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let w = valueToInt(args[2])
    let h = valueToInt(args[3])
    let ch = args[4].s
    gBgLayer.buffer.fillRect(x, y, w, h, ch, gTextStyle)
  return valNil()

proc fgFillRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 5:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let w = valueToInt(args[2])
    let h = valueToInt(args[3])
    let ch = args[4].s
    gFgLayer.buffer.fillRect(x, y, w, h, ch, gTextStyle)
  return valNil()

# Random number functions
proc randInt(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate random integer: randInt(max) returns 0..max-1, randInt(min, max) returns min..max-1
  if args.len == 0:
    return valInt(0)
  elif args.len == 1:
    let max = valueToInt(args[0])
    return valInt(rand(max - 1))
  else:
    let min = valueToInt(args[0])
    let max = valueToInt(args[1])
    return valInt(rand(max - min - 1) + min)

proc randFloat(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate random float: randFloat() returns 0.0..1.0, randFloat(max) returns 0.0..max
  if args.len == 0:
    return valFloat(rand(1.0))
  else:
    let max = case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 1.0
    return valFloat(rand(max))

# Time functions - work across platforms including WASM
proc getYear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current year (e.g., 2025)
  let now = now()
  return valInt(now.year)

proc getMonth(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current month (1-12)
  let now = now()
  return valInt(now.month.int)

proc getDay(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current day of month (1-31)
  let now = now()
  return valInt(now.monthday)

proc getHour(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current hour (0-23)
  let now = now()
  return valInt(now.hour)

proc getMinute(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current minute (0-59)
  let now = now()
  return valInt(now.minute)

proc getSecond(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current second (0-59)
  let now = now()
  return valInt(now.second)

proc drawFigletDigit(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Draw a figlet digit at x, y position. Args: digit(0-9 or 10 for colon), x, y
  if args.len >= 3:
    let digit = valueToInt(args[0])
    let x = valueToInt(args[1])
    let y = valueToInt(args[2])
    
    if digit >= 0 and digit <= 9:
      for line in 0..4:
        gFgLayer.buffer.writeText(x, y + line, figletDigits[digit][line], gTextStyle)
    elif digit == 10:  # Colon
      for line in 0..4:
        gFgLayer.buffer.writeText(x, y + line, figletColon[line], gTextStyle)
  
  return valNil()

# ================================================================
# STATE ACCESSORS - Expose AppState to user scripts
# ================================================================

proc getTermWidth(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current terminal width
  return valInt(gAppState.termWidth)

proc getTermHeight(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current terminal height
  return valInt(gAppState.termHeight)

proc getTargetFps(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the target FPS
  return valFloat(gAppState.targetFps)

proc setTargetFps(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set the target FPS. Args: fps (number)
  if args.len > 0:
    let fps = case args[0].kind
      of vkFloat: args[0].f
      of vkInt: args[0].i.float
      else: 60.0
    gAppState.setTargetFps(fps)
  return valNil()

proc getFps(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the current actual FPS
  return valFloat(gAppState.fps)

proc getFrameCount(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the total frame count
  return valInt(gAppState.frameCount)

proc getTotalTime(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the total elapsed time in seconds
  return valFloat(gAppState.totalTime)

# ================================================================
# SECTION MANAGEMENT WRAPPERS
# ================================================================

proc nimini_getCurrentSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the currently active section as a table
  let section = getCurrentSection()
  var table = initTable[string, Value]()
  table["id"] = valString(section.id)
  table["title"] = valString(section.title)
  table["level"] = valInt(section.level)
  table["blockCount"] = valInt(section.blocks.len)
  table["index"] = valInt(storieCtx.currentSectionIndex)
  
  # Add metadata as a nested table
  var metadataTable = initTable[string, Value]()
  for key, val in section.metadata:
    metadataTable[key] = valString(val)
  table["metadata"] = valMap(metadataTable)
  
  return valMap(table)

proc nimini_getAllSections(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get all sections as an array of tables
  let sections = getAllSections()
  var arr: seq[Value] = @[]
  for i, section in sections:
    var table = initTable[string, Value]()
    table["id"] = valString(section.id)
    table["title"] = valString(section.title)
    table["level"] = valInt(section.level)
    table["blockCount"] = valInt(section.blocks.len)
    table["index"] = valInt(i)
    
    # Add metadata as a nested table
    var metadataTable = initTable[string, Value]()
    for key, val in section.metadata:
      metadataTable[key] = valString(val)
    table["metadata"] = valMap(metadataTable)
    
    arr.add(valMap(table))
  return valArray(arr)

proc nimini_getSectionById(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get a section by ID. Args: id (string)
  if args.len == 0:
    return valNil()
  let id = args[0].s
  let section = getSectionById(id)
  if section.id.len == 0:
    return valNil()
  
  # Find index
  var sectionIndex = 0
  for i, s in getAllSections():
    if s.id == id:
      sectionIndex = i
      break
  
  var table = initTable[string, Value]()
  table["id"] = valString(section.id)
  table["title"] = valString(section.title)
  table["level"] = valInt(section.level)
  table["blockCount"] = valInt(section.blocks.len)
  table["index"] = valInt(sectionIndex)
  
  # Add metadata as a nested table
  var metadataTable = initTable[string, Value]()
  for key, val in section.metadata:
    metadataTable[key] = valString(val)
  table["metadata"] = valMap(metadataTable)
  
  return valMap(table)

proc nimini_gotoSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Navigate to a section. Args: target (int index or string ID)
  if args.len == 0:
    return valBool(false)
  
  let success = case args[0].kind
    of vkInt:
      gotoSection(args[0].i)
    of vkString:
      gotoSectionById(args[0].s)
    else:
      false
  
  return valBool(success)

proc nimini_createSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new section. Args: id (string), title (string), level (int, default 1)
  if args.len < 2:
    return valBool(false)
  
  let id = args[0].s
  let title = args[1].s
  let level = if args.len > 2: valueToInt(args[2]) else: 1
  
  return valBool(createSection(id, title, level))

proc nimini_deleteSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Delete a section by ID. Args: id (string)
  if args.len == 0:
    return valBool(false)
  
  let id = args[0].s
  return valBool(deleteSection(id))

proc nimini_updateSectionTitle(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update a section's title. Args: id (string), newTitle (string)
  if args.len < 2:
    return valBool(false)
  
  let id = args[0].s
  let newTitle = args[1].s
  return valBool(updateSectionTitle(id, newTitle))

proc nimini_setMultiSectionMode(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Enable or disable multi-section rendering. Args: enabled (bool)
  if args.len > 0:
    let enabled = args[0].b
    setMultiSectionMode(enabled)
  return valNil()

proc nimini_getMultiSectionMode(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current multi-section mode setting
  return valBool(getMultiSectionMode())

proc nimini_setScrollY(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set scroll position. Args: y (int)
  if args.len > 0:
    setScrollY(valueToInt(args[0]))
  return valNil()

proc nimini_getScrollY(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current scroll position
  return valInt(getScrollY())

proc nimini_getSectionCount(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get total number of sections
  return valInt(getAllSections().len)

proc nimini_getCurrentSectionIndex(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the index of the current section
  if storieCtx.isNil:
    return valInt(0)
  return valInt(storieCtx.currentSectionIndex)


# ================================================================
# GLOBAL EVENT HANDLER MANAGEMENT
# ================================================================

proc registerGlobalRender*(name: string, callback: Value, priority: int = 0): bool =
  ## Register a global render handler
  if storieCtx.isNil:
    return false
  
  # Check if handler with this name already exists
  for i, handler in storieCtx.globalRenderHandlers:
    if handler.name == name:
      # Update existing handler
      storieCtx.globalRenderHandlers[i] = GlobalHandler(name: name, callback: callback, priority: priority)
      return true
  
  # Add new handler and sort by priority
  storieCtx.globalRenderHandlers.add(GlobalHandler(name: name, callback: callback, priority: priority))
  storieCtx.globalRenderHandlers.sort(proc(a, b: GlobalHandler): int = cmp(a.priority, b.priority))
  return true

proc registerGlobalUpdate*(name: string, callback: Value, priority: int = 0): bool =
  ## Register a global update handler
  if storieCtx.isNil:
    return false
  
  for i, handler in storieCtx.globalUpdateHandlers:
    if handler.name == name:
      storieCtx.globalUpdateHandlers[i] = GlobalHandler(name: name, callback: callback, priority: priority)
      return true
  
  storieCtx.globalUpdateHandlers.add(GlobalHandler(name: name, callback: callback, priority: priority))
  storieCtx.globalUpdateHandlers.sort(proc(a, b: GlobalHandler): int = cmp(a.priority, b.priority))
  return true

proc registerGlobalInput*(name: string, callback: Value, priority: int = 0): bool =
  ## Register a global input handler
  if storieCtx.isNil:
    return false
  
  for i, handler in storieCtx.globalInputHandlers:
    if handler.name == name:
      storieCtx.globalInputHandlers[i] = GlobalHandler(name: name, callback: callback, priority: priority)
      return true
  
  storieCtx.globalInputHandlers.add(GlobalHandler(name: name, callback: callback, priority: priority))
  storieCtx.globalInputHandlers.sort(proc(a, b: GlobalHandler): int = cmp(a.priority, b.priority))
  return true

proc unregisterGlobalHandler*(name: string): bool =
  ## Unregister a global handler by name (searches all handler types)
  if storieCtx.isNil:
    return false
  
  var found = false
  
  # Remove from render handlers
  for i in countdown(storieCtx.globalRenderHandlers.len - 1, 0):
    if storieCtx.globalRenderHandlers[i].name == name:
      storieCtx.globalRenderHandlers.delete(i)
      found = true
  
  # Remove from update handlers
  for i in countdown(storieCtx.globalUpdateHandlers.len - 1, 0):
    if storieCtx.globalUpdateHandlers[i].name == name:
      storieCtx.globalUpdateHandlers.delete(i)
      found = true
  
  # Remove from input handlers
  for i in countdown(storieCtx.globalInputHandlers.len - 1, 0):
    if storieCtx.globalInputHandlers[i].name == name:
      storieCtx.globalInputHandlers.delete(i)
      found = true
  
  return found

proc clearGlobalHandlers*() =
  ## Clear all global handlers
  if not storieCtx.isNil:
    storieCtx.globalRenderHandlers = @[]
    storieCtx.globalUpdateHandlers = @[]
    storieCtx.globalInputHandlers = @[]

# Nimini wrapper functions
proc nimini_registerGlobalRender(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Register a global render handler. Args: name (string), callback (function), [priority (int)]
  if args.len < 2:
    return valBool(false)
  let name = args[0].s
  let callback = args[1]
  let priority = if args.len >= 3 and args[2].kind == vkInt: args[2].i else: 0
  return valBool(registerGlobalRender(name, callback, priority))

proc nimini_registerGlobalUpdate(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Register a global update handler. Args: name (string), callback (function), [priority (int)]
  if args.len < 2:
    return valBool(false)
  let name = args[0].s
  let callback = args[1]
  let priority = if args.len >= 3 and args[2].kind == vkInt: args[2].i else: 0
  return valBool(registerGlobalUpdate(name, callback, priority))

proc nimini_registerGlobalInput(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Register a global input handler. Args: name (string), callback (function), [priority (int)]
  if args.len < 2:
    return valBool(false)
  let name = args[0].s
  let callback = args[1]
  let priority = if args.len >= 3 and args[2].kind == vkInt: args[2].i else: 0
  return valBool(registerGlobalInput(name, callback, priority))

proc nimini_unregisterGlobalHandler(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Unregister a global handler by name. Args: name (string)
  if args.len == 0:
    return valBool(false)
  return valBool(unregisterGlobalHandler(args[0].s))

proc nimini_clearGlobalHandlers(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Clear all global handlers
  clearGlobalHandlers()
  return valNil()

# ================================================================
# MOUSE HANDLING
# ================================================================

proc nimini_enableMouse(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Enable mouse input reporting
  when not defined(emscripten):
    enableMouseReporting()
  return valNil()

proc nimini_disableMouse(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Disable mouse input reporting
  when not defined(emscripten):
    disableMouseReporting()
  return valNil()

# ================================================================
# CANVAS SYSTEM WRAPPERS
# ================================================================

proc nimini_initCanvas(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Initialize canvas system with all sections. Args: currentIdx (int, optional, default 0)
  let currentIdx = if args.len > 0: valueToInt(args[0]) else: 0
  let sections = getAllSections()
  initCanvas(sections, currentIdx)
  return valBool(true)

proc nimini_hideSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Hide a section by reference. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  hideSection(args[0].s)
  return valNil()

proc nimini_removeSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Remove a section from display. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  removeSection(args[0].s)
  return valNil()

proc nimini_restoreSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Restore a removed section. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  restoreSection(args[0].s)
  return valNil()

proc nimini_isVisited(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if a section has been visited. Args: sectionRef (string)
  if args.len == 0:
    return valBool(false)
  return valBool(isVisited(args[0].s))

proc nimini_markVisited(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Manually mark a section as visited. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  markVisited(args[0].s)
  return valNil()

proc nimini_canvasRender(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render the canvas system. No args needed (uses global buffers)
  # Get the current buffer and dimensions from global state
  # Canvas should render to the foreground layer buffer
  if not gAppState.isNil and not gFgLayer.isNil:
    canvasRender(gFgLayer.buffer, gAppState.termWidth, gAppState.termHeight)
  return valNil()

proc nimini_canvasUpdate(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update canvas animations. Args: deltaTime (float)
  let deltaTime = if args.len > 0:
    (if args[0].kind == vkFloat: args[0].f else: float(args[0].i))
  else:
    0.016 # Default ~60fps
  canvasUpdate(deltaTime)
  return valNil()

proc nimini_canvasHandleKey(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle keyboard input for canvas. Args: keyCode (int), mods (int, optional)
  ## Returns: bool (true if handled)
  if args.len == 0:
    return valBool(false)
  let keyCode = valueToInt(args[0])
  let mods = if args.len > 1: valueToInt(args[1]) else: 0
  # Convert int to set[uint8] - simplified for common cases
  var modSet: set[uint8] = {}
  if (mods and 1) != 0: modSet.incl(0'u8)  # Shift
  if (mods and 2) != 0: modSet.incl(1'u8)  # Ctrl
  if (mods and 4) != 0: modSet.incl(2'u8)  # Alt
  return valBool(canvasHandleKey(keyCode, modSet))

proc nimini_canvasHandleMouse(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse input for canvas. Args: x (int), y (int), button (int), isDown (bool)
  ## Returns: bool (true if handled)
  if args.len < 4:
    return valBool(false)
  let x = valueToInt(args[0])
  let y = valueToInt(args[1])
  let button = valueToInt(args[2])
  let isDown = if args[3].kind == vkBool: args[3].b else: (valueToInt(args[3]) != 0)
  return valBool(canvasHandleMouse(x, y, button, isDown))

proc encodeInputEvent(event: InputEvent): Value =
  ## Convert InputEvent to a Nimini Value table
  var table = initTable[string, Value]()
  
  case event.kind
  of KeyEvent:
    table["type"] = valString("key")
    table["keyCode"] = valInt(event.keyCode)
    table["action"] = valString(case event.keyAction
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat")
    
    # Encode modifiers
    var mods: seq[string] = @[]
    if ModShift in event.keyMods: mods.add("shift")
    if ModAlt in event.keyMods: mods.add("alt")
    if ModCtrl in event.keyMods: mods.add("ctrl")
    if ModSuper in event.keyMods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
  of TextEvent:
    table["type"] = valString("text")
    table["text"] = valString(event.text)
  
  of MouseEvent:
    table["type"] = valString("mouse")
    table["x"] = valInt(event.mouseX)
    table["y"] = valInt(event.mouseY)
    table["button"] = valString(case event.button
      of Left: "left"
      of Right: "right"
      of Middle: "middle"
      of ScrollUp: "scroll_up"
      of ScrollDown: "scroll_down"
      of Unknown: "unknown")
    table["action"] = valString(case event.action
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat")
    
    # Encode modifiers
    var mods: seq[string] = @[]
    if ModShift in event.mods: mods.add("shift")
    if ModAlt in event.mods: mods.add("alt")
    if ModCtrl in event.mods: mods.add("ctrl")
    if ModSuper in event.mods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
  of MouseMoveEvent:
    table["type"] = valString("mouse_move")
    table["x"] = valInt(event.moveX)
    table["y"] = valInt(event.moveY)
    
    # Encode modifiers
    var mods: seq[string] = @[]
    if ModShift in event.moveMods: mods.add("shift")
    if ModAlt in event.moveMods: mods.add("alt")
    if ModCtrl in event.moveMods: mods.add("ctrl")
    if ModSuper in event.moveMods: mods.add("super")
    
    var modsArray: seq[Value] = @[]
    for m in mods:
      modsArray.add(valString(m))
    table["mods"] = valArray(modsArray)
  
  of ResizeEvent:
    table["type"] = valString("resize")
    table["width"] = valInt(event.newWidth)
    table["height"] = valInt(event.newHeight)
  
  return valMap(table)

# ================================================================
# LAYOUT MODULE WRAPPERS
# ================================================================

proc bgWriteTextBox(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Write text in a box with alignment and wrapping on background layer
  ## Args: x, y, width, height, text, hAlign, vAlign, wrapMode, style
  if args.len >= 5:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let width = valueToInt(args[2])
    let height = valueToInt(args[3])
    let text = args[4].s
    
    # Default alignment and wrap mode
    var hAlign = AlignLeft
    var vAlign = AlignTop
    var wrapMode = WrapWord
    
    # Parse optional hAlign parameter (arg 5)
    if args.len >= 6:
      case args[5].s
      of "AlignLeft": hAlign = AlignLeft
      of "AlignCenter": hAlign = AlignCenter
      of "AlignRight": hAlign = AlignRight
      of "AlignJustify": hAlign = AlignJustify
      else: discard
    
    # Parse optional vAlign parameter (arg 6)
    if args.len >= 7:
      case args[6].s
      of "AlignTop": vAlign = AlignTop
      of "AlignMiddle": vAlign = AlignMiddle
      of "AlignBottom": vAlign = AlignBottom
      else: discard
    
    # Parse optional wrapMode parameter (arg 7)
    if args.len >= 8:
      case args[7].s
      of "WrapNone": wrapMode = WrapNone
      of "WrapWord": wrapMode = WrapWord
      of "WrapChar": wrapMode = WrapChar
      of "WrapEllipsis": wrapMode = WrapEllipsis
      of "WrapJustify": wrapMode = WrapJustify
      else: discard
    
    discard writeTextBox(gBgLayer.buffer, x, y, width, height, text, 
                         hAlign, vAlign, wrapMode, gTextStyle)
  return valNil()

proc fgWriteTextBox(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Write text in a box with alignment and wrapping on foreground layer
  ## Args: x, y, width, height, text, hAlign, vAlign, wrapMode, style
  if args.len >= 5:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let width = valueToInt(args[2])
    let height = valueToInt(args[3])
    let text = args[4].s
    
    # Default alignment and wrap mode
    var hAlign = AlignLeft
    var vAlign = AlignTop
    var wrapMode = WrapWord
    
    # Parse optional hAlign parameter (arg 5)
    if args.len >= 6:
      case args[5].s
      of "AlignLeft": hAlign = AlignLeft
      of "AlignCenter": hAlign = AlignCenter
      of "AlignRight": hAlign = AlignRight
      of "AlignJustify": hAlign = AlignJustify
      else: discard
    
    # Parse optional vAlign parameter (arg 6)
    if args.len >= 7:
      case args[6].s
      of "AlignTop": vAlign = AlignTop
      of "AlignMiddle": vAlign = AlignMiddle
      of "AlignBottom": vAlign = AlignBottom
      else: discard
    
    # Parse optional wrapMode parameter (arg 7)
    if args.len >= 8:
      case args[7].s
      of "WrapNone": wrapMode = WrapNone
      of "WrapWord": wrapMode = WrapWord
      of "WrapChar": wrapMode = WrapChar
      of "WrapEllipsis": wrapMode = WrapEllipsis
      of "WrapJustify": wrapMode = WrapJustify
      else: discard
    
    discard writeTextBox(gFgLayer.buffer, x, y, width, height, text, 
                         hAlign, vAlign, wrapMode, gTextStyle)
  return valNil()

proc createNiminiContext(state: AppState): NiminiContext =
  ## Create a Nimini interpreter context with exposed APIs
  initRuntime()
  initStdlib()  # Register standard library functions (add, len, etc.)
  
  # Register type conversion functions with custom names
  registerNative("int", nimini_int)
  registerNative("float", nimini_float)
  registerNative("str", nimini_str)
  
  # Auto-register all {.nimini.} pragma functions
  exportNiminiProcs(
    print,
    bgClear, bgClearTransparent, bgWrite, bgWriteText, bgFillRect, bgWriteTextBox,
    fgClear, fgClearTransparent, fgWrite, fgWriteText, fgFillRect, fgWriteTextBox,
    randInt, randFloat,
    getYear, getMonth, getDay, getHour, getMinute, getSecond,
    drawFigletDigit,
    getTermWidth, getTermHeight, getTargetFps, setTargetFps,
    getFps, getFrameCount, getTotalTime,
    nimini_getCurrentSection, nimini_getAllSections, nimini_getSectionById,
    nimini_gotoSection, nimini_createSection, nimini_deleteSection,
    nimini_updateSectionTitle, nimini_setMultiSectionMode, nimini_getMultiSectionMode,
    nimini_setScrollY, nimini_getScrollY, nimini_getSectionCount, nimini_getCurrentSectionIndex,
    nimini_registerGlobalRender, nimini_registerGlobalUpdate, nimini_registerGlobalInput,
    nimini_unregisterGlobalHandler, nimini_clearGlobalHandlers,
    nimini_enableMouse, nimini_disableMouse,
    nimini_initCanvas, nimini_hideSection, nimini_removeSection, nimini_restoreSection,
    nimini_isVisited, nimini_markVisited, nimini_canvasRender, nimini_canvasUpdate,
    nimini_canvasHandleKey, nimini_canvasHandleMouse
  )
  
  let ctx = NiminiContext(env: runtimeEnv)
  
  return ctx

proc executeCodeBlock(context: NiminiContext, codeBlock: CodeBlock, state: AppState, event: InputEvent = InputEvent()): bool =
  ## Execute a code block using Nimini
  ## 
  ## Scoping rules:
  ## - 'init' blocks execute in global scope (all vars become global)
  ## - Other blocks execute in child scope:
  ##   - 'var x = 5' creates local variable
  ##   - 'x = 5' updates parent scope if exists, else creates local
  ##   - Reading variables walks up scope chain automatically
  if codeBlock.code.strip().len == 0:
    return true
  
  try:
    # Build a wrapper that includes state access
    # We expose common variables directly in the script context
    var scriptCode = ""
    
    # Add state field accessors as local variables
    scriptCode.add("var termWidth = " & $state.termWidth & "\n")
    scriptCode.add("var termHeight = " & $state.termHeight & "\n")
    scriptCode.add("var fps = " & formatFloat(state.fps, ffDecimal, 2) & "\n")
    scriptCode.add("var frameCount = " & $state.frameCount & "\n")
    
    # For input blocks, we'll inject the event variable later
    if codeBlock.lifecycle == "input":
      # Add a placeholder - the actual event will be set in the environment
      scriptCode.add("# event variable will be provided by runtime\n")
    
    scriptCode.add("\n")
    
    # Add user code
    scriptCode.add(codeBlock.code)
    
    let tokens = tokenizeDsl(scriptCode)
    let program = parseDsl(tokens)
    
    # Choose execution environment based on lifecycle
    # 'init' blocks run in global scope to define persistent state
    # Other blocks run in child scope for local variables
    let execEnv = if codeBlock.lifecycle == "init":
      context.env  # Global scope
    else:
      newEnv(context.env)  # Child scope with parent link
    
    # For input blocks, expose the event object
    if codeBlock.lifecycle == "input":
      let eventValue = encodeInputEvent(event)
      defineVar(execEnv, "event", eventValue)
    
    execProgram(program, execEnv)
    
    return true
  except Exception as e:
    when not defined(emscripten):
      echo "Error in ", codeBlock.lifecycle, " block: ", e.msg
    # In WASM, we can't echo, so we'll just fail silently but return false
    when defined(emscripten):
      lastError = "Error in on:" & codeBlock.lifecycle & " - " & e.msg
    return false

# ================================================================
# LIFECYCLE MANAGEMENT
# ================================================================

var gWaitingForGist: bool = false  # Global flag set before context initialization
var gMarkdownFile: string = "index.md"  # Global markdown file path (can be set via CLI)

proc loadAndParseMarkdown(): MarkdownDocument =
  ## Load markdown file and parse it for code blocks and front matter
  when defined(emscripten):
    # Check if we're waiting for gist content
    if gWaitingForGist:
      # Return empty document - gist content will be loaded via JavaScript
      return MarkdownDocument()
    
    # In WASM, embed the markdown at compile time
    # Use staticRead with the markdown content
    const mdContent = staticRead("index.md")
    const mdLines = mdContent.splitLines()
    const mdLineCount = mdLines.len
    
    # Debug: detailed parsing info
    when defined(emscripten):
      lastError = "MD:" & $mdContent.len & "ch," & $mdLineCount & "ln"
      
    let doc = parseMarkdownDocument(mdContent)
    
    when defined(emscripten):
      if doc.codeBlocks.len == 0:
        lastError = lastError & "|0blocks"
        # Show first few lines of markdown to debug
        var preview = ""
        for i in 0 ..< min(3, mdLineCount):
          if i > 0: preview.add(";")
          let line = mdLines[i]
          preview.add(if line.len > 20: line[0..19] else: line)
        lastError = lastError & "|" & preview
      else:
        lastError = "" # Success!
    return doc
  else:
    # In native builds, read from filesystem
    let mdPath = gMarkdownFile
    
    if not fileExists(mdPath):
      echo "Warning: ", mdPath, " not found, using default behavior"
      return MarkdownDocument()
    
    try:
      let content = readFile(mdPath)
      return parseMarkdownDocument(content)
    except:
      echo "Error reading ", mdPath, ": ", getCurrentExceptionMsg()
      return MarkdownDocument()

# ================================================================
# INITIALIZE CONTEXT AND LAYERS
# ================================================================

proc initStorieContext(state: AppState) =
  ## Initialize the Storie context, parse Markdown, and set up layers
  if storieCtx.isNil:
    storieCtx = StorieContext()
  
  # Load and parse markdown document (with front matter and sections)
  let doc = loadAndParseMarkdown()
  storieCtx.codeBlocks = doc.codeBlocks
  storieCtx.frontMatter = doc.frontMatter
  storieCtx.sections = doc.sections
  storieCtx.currentSectionIndex = 0
  storieCtx.multiSectionMode = true  # Default to multi-section mode (render all)
  storieCtx.scrollY = 0
  
  when defined(emscripten):
    if storieCtx.codeBlocks.len == 0 and lastError.len == 0 and not gWaitingForGist:
      lastError = "No code blocks parsed"
  
  # Apply front matter settings to state
  if storieCtx.frontMatter.hasKey("targetFPS"):
    try:
      let fps = parseFloat(storieCtx.frontMatter["targetFPS"])
      state.setTargetFps(fps)
      when not defined(emscripten):
        echo "Set target FPS from front matter: ", fps
    except:
      when not defined(emscripten):
        echo "Warning: Invalid targetFPS value in front matter"
  
  # Create default layers that code blocks can use
  storieCtx.bgLayer = state.addLayer("background", 0)
  storieCtx.fgLayer = state.addLayer("foreground", 10)
  
  # Initialize styles
  var textStyle = defaultStyle()
  textStyle.fg = cyan()
  textStyle.bold = true

  var borderStyle = defaultStyle()
  borderStyle.fg = green()

  var infoStyle = defaultStyle()
  infoStyle.fg = yellow()
  
  # Set global references for Nimini wrappers
  gBgLayer = storieCtx.bgLayer
  gFgLayer = storieCtx.fgLayer
  gTextStyle = textStyle
  gBorderStyle = borderStyle
  gInfoStyle = infoStyle
  gAppState = state  # Store state reference for accessors
  
  when not defined(emscripten):
    echo "Loaded ", storieCtx.codeBlocks.len, " code blocks from ", gMarkdownFile
    if storieCtx.frontMatter.len > 0:
      echo "Front matter keys: ", toSeq(storieCtx.frontMatter.keys).join(", ")
  
  storieCtx.niminiContext = createNiminiContext(state)
  
  # Expose front matter to user scripts as global variables
  for key, value in storieCtx.frontMatter.pairs:
    # Try to parse as number first, otherwise store as string
    try:
      let numVal = parseFloat(value)
      if '.' in value:
        setGlobal(key, valFloat(numVal))
      else:
        setGlobal(key, valInt(numVal.int))
    except:
      # Not a number, store as string
      setGlobal(key, valString(value))
  
  # Execute init code blocks
  when not defined(emscripten):
    echo "Found ", storieCtx.codeBlocks.len, " code blocks total"
    var initCount = 0
    for cb in storieCtx.codeBlocks:
      if cb.lifecycle == "init":
        initCount += 1
    echo "Found ", initCount, " init blocks"
  
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "init":
      when not defined(emscripten):
        echo "Executing init block..."
      let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
      when not defined(emscripten):
        echo "Init block execution result: ", success
      if not success:
        when defined(emscripten):
          if lastError.len == 0:
            lastError = "init block failed"
        when not defined(emscripten):
          echo "WARNING: Init block failed to execute"

# ================================================================
# CALLBACK IMPLEMENTATIONS
# ================================================================

onInit = proc(state: AppState) =
  initStorieContext(state)

onUpdate = proc(state: AppState, dt: float) =
  if storieCtx.isNil:
    return
  
  # 1. Execute global update handlers first (modules like canvas)
  for handler in storieCtx.globalUpdateHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        discard handler.callback.fnVal.native(env, @[valFloat(dt)])
    except Exception as e:
      when not defined(emscripten):
        echo "Error in global update handler '", handler.name, "': ", e.msg
  
  # 2. Execute section-specific on:update blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "update":
      discard executeCodeBlock(storieCtx.niminiContext, codeBlock, state)

onRender = proc(state: AppState) =
  if storieCtx.isNil:
    when defined(emscripten):
      lastRenderExecutedCount = 0
      # Write error directly to currentBuffer so it's visible
      var errStyle = defaultStyle()
      errStyle.fg = red()
      errStyle.bold = true
      state.currentBuffer.writeText(5, 5, "ERROR: storieCtx is nil!", errStyle)
    # Fallback rendering if no context
    let msg = "No " & gMarkdownFile & " found or parsing failed"
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackStyle = defaultStyle()
    fallbackStyle.fg = cyan()
    state.currentBuffer.writeText(x, y, msg, fallbackStyle)
    return
  
  # 1. Execute global render handlers first (modules like canvas)
  for handler in storieCtx.globalRenderHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        discard handler.callback.fnVal.native(env, @[])
    except Exception as e:
      when not defined(emscripten):
        echo "Error in global render handler '", handler.name, "': ", e.msg
  
  # Check if we have any render blocks
  var hasRenderBlocks = false
  var renderBlockCount = 0
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      hasRenderBlocks = true
      renderBlockCount += 1
  
  if not hasRenderBlocks and storieCtx.globalRenderHandlers.len == 0:
    when defined(emscripten):
      lastRenderExecutedCount = 0
      if lastError.len == 0:
        lastError = "No on:render blocks"
    # Fallback if no render blocks found
    state.currentBuffer.clear()
    let msg = "No render blocks found in " & gMarkdownFile
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackInfoStyle = defaultStyle()
    fallbackInfoStyle.fg = yellow()
    state.currentBuffer.writeText(x, y, msg, fallbackInfoStyle)
    
    # Show what blocks we DO have
    when defined(emscripten):
      var debugStyle = defaultStyle()
      debugStyle.fg = cyan()
      var debugY = y + 2
      for codeBlock in storieCtx.codeBlocks:
        let info = "Found: on:" & codeBlock.lifecycle
        state.currentBuffer.writeText(x, debugY, info, debugStyle)
        debugY += 1
    return
  
  # 2. Execute section-specific on:render code blocks
  var executedCount = 0
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
      if success:
        executedCount += 1
  
  # Debug: Show number of registered handlers (AFTER render blocks to avoid being cleared)
  when not defined(emscripten):
    var debugStyle = defaultStyle()
    debugStyle.fg = yellow()
    debugStyle.bold = true
    let handlerInfo = "Handlers: R=" & $storieCtx.globalRenderHandlers.len & 
                      " U=" & $storieCtx.globalUpdateHandlers.len & 
                      " I=" & $storieCtx.globalInputHandlers.len
    storieCtx.fgLayer.buffer.writeText(2, 0, handlerInfo, debugStyle)
  
  # Debug: Show execution status in WASM
  # Write to foreground layer so user code renders, then we overlay debug on layers
  when defined(emscripten):
    var debugStyle = defaultStyle()
    debugStyle.fg = green()
    debugStyle.bold = true
    storieCtx.fgLayer.buffer.writeText(2, 2, "Blocks: " & $storieCtx.codeBlocks.len & " Render: " & $renderBlockCount & " Exec: " & $executedCount, debugStyle)

    # Publish executedCount to WASM HUD
    lastRenderExecutedCount = executedCount
    
    if executedCount == 0 and renderBlockCount > 0:
      var errorStyle = defaultStyle()
      errorStyle.fg = red()
      errorStyle.bold = true
      storieCtx.fgLayer.buffer.writeText(2, 3, "Render execution FAILED!", errorStyle)
      # Also show last error if available
      if lastError.len > 0:
        storieCtx.fgLayer.buffer.writeText(2, 4, "Error: " & lastError, errorStyle)
    
    # Also show frame count to verify rendering is happening
    var fpsStyle = defaultStyle()
    fpsStyle.fg = yellow()
    storieCtx.fgLayer.buffer.writeText(2, 0, "Frame: " & $state.frameCount, fpsStyle)

onInput = proc(state: AppState, event: InputEvent): bool =
  if storieCtx.isNil:
    return false
  
  # 1. Execute global input handlers first (allow modules to intercept)
  for handler in storieCtx.globalInputHandlers:
    try:
      if handler.callback.kind == vkFunction and handler.callback.fnVal.isNative:
        let env = storieCtx.niminiContext.env
        # Encode input event as a Nimini Value
        let eventValue = encodeInputEvent(event)
        let result = handler.callback.fnVal.native(env, @[eventValue])
        # If handler returns true, it consumed the event
        if result.kind == vkBool and result.b:
          return true
    except Exception as e:
      when not defined(emscripten):
        echo "Error in global input handler '", handler.name, "': ", e.msg
  
  # Default quit behavior (Q or ESC)
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == ord('q') or event.keyCode == ord('Q') or event.keyCode == INPUT_ESCAPE:
      state.running = false
      return true
  
  # Handle canvas input if canvas is initialized
  if not canvasState.isNil and event.kind == KeyEvent and event.keyAction == Press:
    if canvasHandleKey(event.keyCode, {}):
      return true
  
  # 2. Execute section-specific on:input blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "input":
      if executeCodeBlock(storieCtx.niminiContext, codeBlock, state, event):
        return true
  
  return false

onShutdown = proc(state: AppState) =
  if storieCtx.isNil:
    return
  
  # Execute shutdown code blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "shutdown":
      discard executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
