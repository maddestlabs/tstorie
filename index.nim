# TStorie entry point

import strutils, tables, random, times
when not defined(emscripten):
  import os
import nimini
import lib/drawing
import lib/storie_md

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

# ================================================================
# NIMINI WRAPPERS - Bridge storie functions to Nimini
# ================================================================

# Global references to layers (set in initStorieContext)
var gBgLayer: Layer
var gFgLayer: Layer
var gTextStyle, gBorderStyle, gInfoStyle: Style
var gAppState: AppState  # Global reference to app state for state accessors

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
  gBgLayer.bgClear()
  return valNil()

proc bgClearTransparent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gBgLayer.bgClearTransparent()
  return valNil()

proc fgClear(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gFgLayer.fgClear()
  return valNil()

proc fgClearTransparent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  gFgLayer.fgClearTransparent()
  return valNil()

proc bgWrite(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let ch = args[2].s
    let style = if args.len >= 4: gTextStyle else: gTextStyle  # TODO: support style arg
    gBgLayer.bgWrite(x, y, ch, style)
  return valNil()

proc fgWrite(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let ch = args[2].s
    let style = if args.len >= 4: gTextStyle else: gTextStyle
    gFgLayer.fgWrite(x, y, ch, style)
  return valNil()

proc bgWriteText(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let text = args[2].s
    gBgLayer.bgWriteText(x, y, text, gTextStyle)
  return valNil()

proc fgWriteText(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 3:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let text = args[2].s
    gFgLayer.fgWriteText(x, y, text, gTextStyle)
  return valNil()

proc bgFillRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 5:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let w = valueToInt(args[2])
    let h = valueToInt(args[3])
    let ch = args[4].s
    gBgLayer.bgFillRect(x, y, w, h, ch, gTextStyle)
  return valNil()

proc fgFillRect(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len >= 5:
    let x = valueToInt(args[0])
    let y = valueToInt(args[1])
    let w = valueToInt(args[2])
    let h = valueToInt(args[3])
    let ch = args[4].s
    gFgLayer.fgFillRect(x, y, w, h, ch, gTextStyle)
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
    gFgLayer.drawFigletDigit(digit, x, y, gTextStyle)
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
    bgClear, bgClearTransparent, bgWrite, bgWriteText, bgFillRect,
    fgClear, fgClearTransparent, fgWrite, fgWriteText, fgFillRect,
    randInt, randFloat,
    getYear, getMonth, getDay, getHour, getMinute, getSecond,
    drawFigletDigit,
    getTermWidth, getTermHeight, getTargetFps, setTargetFps,
    getFps, getFrameCount, getTotalTime
  )
  
  let ctx = NiminiContext(env: runtimeEnv)
  
  return ctx

proc executeCodeBlock(context: NiminiContext, codeBlock: CodeBlock, state: AppState): bool =
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

type
  StorieContext = ref object
    codeBlocks: seq[CodeBlock]
    niminiContext: NiminiContext
    frontMatter: FrontMatter  # Front matter from markdown
    # Pre-compiled layer references
    bgLayer: Layer
    fgLayer: Layer
    
var storieCtx: StorieContext
var gWaitingForGist: bool = false  # Global flag set before context initialization

proc loadAndParseMarkdown(): MarkdownDocument =
  ## Load index.md and parse it for code blocks and front matter
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
    let mdPath = "index.md"
    
    if not fileExists(mdPath):
      echo "Warning: index.md not found, using default behavior"
      return MarkdownDocument()
    
    try:
      let content = readFile(mdPath)
      return parseMarkdownDocument(content)
    except:
      echo "Error reading index.md: ", getCurrentExceptionMsg()
      return MarkdownDocument()

# ================================================================
# INITIALIZE CONTEXT AND LAYERS
# ================================================================

proc initStorieContext(state: AppState) =
  ## Initialize the Storie context, parse Markdown, and set up layers
  if storieCtx.isNil:
    storieCtx = StorieContext()
  
  # Load and parse markdown document (with front matter)
  let doc = loadAndParseMarkdown()
  storieCtx.codeBlocks = doc.codeBlocks
  storieCtx.frontMatter = doc.frontMatter
  
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
    echo "Loaded ", storieCtx.codeBlocks.len, " code blocks from index.md"
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
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "init":
      if not executeCodeBlock(storieCtx.niminiContext, codeBlock, state):
        when defined(emscripten):
          if lastError.len == 0:
            lastError = "init block failed"

# ================================================================
# CALLBACK IMPLEMENTATIONS
# ================================================================

onInit = proc(state: AppState) =
  initStorieContext(state)

onUpdate = proc(state: AppState, dt: float) =
  if storieCtx.isNil:
    return
  
  # Execute update code blocks
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
    let msg = "No index.md found or parsing failed"
    let x = (state.termWidth - msg.len) div 2
    let y = state.termHeight div 2
    var fallbackStyle = defaultStyle()
    fallbackStyle.fg = cyan()
    state.currentBuffer.writeText(x, y, msg, fallbackStyle)
    return
  
  # Check if we have any render blocks
  var hasRenderBlocks = false
  var renderBlockCount = 0
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      hasRenderBlocks = true
      renderBlockCount += 1
  
  if not hasRenderBlocks:
    when defined(emscripten):
      lastRenderExecutedCount = 0
      if lastError.len == 0:
        lastError = "No on:render blocks"
    # Fallback if no render blocks found
    state.currentBuffer.clear()
    let msg = "No render blocks found in index.md"
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
  
  # Execute render code blocks
  var executedCount = 0
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
      if success:
        executedCount += 1
  
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
  
  # Default quit behavior (Q or ESC)
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == ord('q') or event.keyCode == ord('Q') or event.keyCode == INPUT_ESCAPE:
      state.running = false
      return true
  
  # Execute input code blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "input":
      if executeCodeBlock(storieCtx.niminiContext, codeBlock, state):
        return true
  
  return false

onShutdown = proc(state: AppState) =
  if storieCtx.isNil:
    return
  
  # Execute shutdown code blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "shutdown":
      discard executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
