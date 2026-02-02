import strutils, times, parseopt, os, tables, math, random, sequtils, strtabs, algorithm
import macros
import nimini
import nimini/auto_pointer  # For initPlugins()
import src/params
import src/types  # Core runtime types
import src/charwidth  # Character display width utilities

# ================================================================
# BACKEND SELECTION (Multi-Backend Architecture Phase 2)
# ================================================================
# Choose rendering backend at compile time:
#   Default (no flags):     Terminal backend (character-cell, ANSI)
#   -d:sdl3Backend:         SDL3 backend (pixel-based, TTF fonts) [Future Phase 3]
#
# This allows tStorie to support:
#   - Terminal (lightweight, fast, text-focused)
#   - SDL3 (rich graphics, smooth animations, multimedia)
#
# The same high-level code (canvas, animations, etc.) works with both!

when defined(sdl3Backend):
  # SDL3 backend - pixel-based rendering (Phase 3)
  import backends/sdl3/sdl_canvas
  import backends/sdl3/sdl_window
  export sdl_canvas, sdl_window
  type RenderBackend* = SDLCanvas
  
  # Emscripten support for main loop
  when defined(emscripten):
    {.emit: """/*INCLUDESECTION*/
    #include <emscripten/emscripten.h>
    """.}
  
  static:
    echo "[Build] Using SDL3 backend (pixel-based, TTF fonts)"
else:
  # Terminal backend - character-cell rendering (Default)
  import backends/terminal/termbuffer
  
  static:
    echo "[Build] Using Terminal backend (character-cell, ANSI)"
  type RenderBackend* = TermBuffer
  # Backend coordinate unit: 1.0 = 1 character cell

# Import layer system (uses RenderBackend internally)
import src/layers  # Layer system and buffer operations
import src/appstate  # Application state management
import lib/storie_types
# Audio system is now imported through nimini_bridge (which exports audio)
import lib/storie_md          # Markdown parser (includes gEmbeddedFigletFonts)
import lib/section_manager    # Section navigation and management (includes nimini bindings)
import lib/figlet             # FIGlet font rendering (for parsing and rendering)
import lib/figlet_bindings    # FIGlet nimini bindings
import lib/nimini_bridge      # Nimini API registration and bindings (includes gDroppedFile* globals)
import lib/ascii_art_bindings # ASCII art nimini bindings
import lib/ansi_art_bindings  # ANSI art nimini bindings
import lib/dungeon_gen        # Dungeon generator (auto-registers via pragmas)
import lib/particles_bindings # Particle system nimini bindings
import lib/primitives         # Procedural primitives (auto-registers via pragmas)
import lib/noise_composer     # Composable noise API with WebGPU support
import lib/graph              # Graph/node system (auto-registers via pragmas)
import lib/wgsl_bindings      # WGSL GPU shader bindings for compute shaders
# import lib/graph_compiler     # Graph compiler (utility, not runtime plugin)
import lib/animation          # Animation helpers and easing (now pure math, can be imported)
import lib/canvas             # Canvas navigation system (now proper module!)
import lib/canvased           # Canvas editor - visual node graph editor
import lib/layerfx            # Layer effects plugin (parallax, depth cueing, etc.)
import src/timing             # High-precision timing and timers
include lib/audio             # Audio system
# Explicitly initialize plugin modules to ensure registration happens
initDungeonGenModule()
initPrimitivesModule()
initGraphModule()

when not defined(emscripten):
  import src/platform/terminal
  when not defined(noGistLoading):
    import std/httpclient
  import src/export_command  # Export command support

const version = "0.1.0"

# ================================================================
# ARCHITECTURE OVERVIEW
# ================================================================
#
# tStorie is organized into modules:
#
# /src/ - Core engine modules (imported)
#   - types.nim: Core type definitions
#   - layers.nim: Layer and buffer operations
#   - appstate.nim: Application state management
#   - input.nim: Input parsing and event handling
#   - params.nim: URL/CLI parameter management
#   - runtime_api.nim: Runtime API and lifecycle (INCLUDED)
#   - platform/: Platform-specific code (terminal, etc.)
#
# /lib/ - Feature modules (imported or included)
#   - storie_types.nim: Markdown document types
#   - storie_md.nim: Markdown parser
#   - section_manager.nim: Section navigation
#   - canvas.nim: Canvas presentation system (INCLUDED)
#   - animation.nim: Animation and easing (INCLUDED)
#   - audio.nim: Audio generation (INCLUDED)
#   - figlet.nim: FIGlet font rendering
#   - tui_helpers.nim: TUI widgets and helpers
#
# Note: runtime_api.nim (formerly index.nim) is INCLUDED to share
# namespace and provide lifecycle callbacks. Most other modules are
# imported for proper encapsulation.
#
# ================================================================

# ================================================================
# INPUT EVENT TYPES (imported from src/types)
# ================================================================
# Types now defined in src/types.nim:
# - InputAction, MouseButton, InputEventKind, InputEvent
# - Color, Style, and color helpers
# - TerminalInputParser and related types

# ================================================================
# TERMINAL INPUT PARSER IMPLEMENTATION
# ================================================================

# ================================================================
# INPUT PARSING - Now in src/input.nim
# ================================================================

import src/input

# ================================================================
# INTERNAL TYPES (not exposed to plugins)
# ================================================================

# ================================================================
# RENDERING TYPES (imported from src/types)
# ================================================================
# Types now defined in src/types.nim:
# - Cell, TermBuffer, Layer, AppState

when not defined(emscripten):
  var globalRunning {.global.} = true
  var globalTerminalState: TerminalState

# ================================================================
# MODULE LOADING TYPES (partially from src/types)
# ================================================================
# ContentSource defined in src/types.nim
# ModuleCache needs to be defined here because it depends on nimini's ref Env

type
  ModuleCacheImpl* = ref object
    modules*: Table[string, ref Env]  # moduleRef -> compiled runtime
    sourceCode*: Table[string, string]   # moduleRef -> source code
    
var globalModuleCache* = ModuleCacheImpl(
  modules: initTable[string, ref Env](),
  sourceCode: initTable[string, string]()
)

proc fetchGistFile*(gistId: string, filename: string): string =
  ## Fetch a file from a GitHub gist
  ## Format: gistId is the raw gist ID, filename is the file within the gist
  when defined(emscripten):
    # In WASM, this will be populated by JavaScript via emLoadGistCode
    # Return empty string to signal that async fetch is needed
    return ""
  elif defined(noGistLoading):
    raise newException(IOError, "Gist loading disabled (compiled with -d:noGistLoading)")
  else:
    let client = newHttpClient()
    # Use raw githubusercontent URL for direct file access
    let url = "https://gist.githubusercontent.com/raw/" & gistId & "/" & filename
    try:
      return client.getContent(url)
    except:
      raise newException(IOError, "Failed to fetch gist: " & gistId & "/" & filename)

proc parseGistReference*(moduleRef: string): tuple[gistId: string, filename: string, isGist: bool] =
  ## Parse a module reference into its components
  ## Formats:
  ##   "gist:abc123/canvas.nim" -> (abc123, canvas.nim, true)
  ##   "lib/utils.nim" -> ("", lib/utils.nim, false)
  if moduleRef.startsWith("gist:"):
    let parts = moduleRef[5..^1].split('/', maxsplit=1)
    if parts.len != 2:
      raise newException(ValueError, "Invalid gist format. Use: gist:ID/file.nim")
    return (parts[0], parts[1], true)
  else:
    return ("", moduleRef, false)

# ================================================================
# CONTENT SOURCE TYPES (imported from src/types)
# ================================================================
# Types now defined in src/types.nim:
# - ContentSource enum

proc parseContentReference*(contentRef: string): tuple[source: ContentSource, id: string] =
  ## Parse a content reference into its source type and identifier
  ## Formats:
  ##   "gist:abc123" -> (csGist, "abc123")
  ##   "demo:clock" -> (csDemo, "clock")
  ##   "file:path/to/file.md" -> (csFile, "path/to/file.md")
  ##   "https://gist.github.com/user/abc123" -> (csGist, "abc123")
  ##   "abc123" (if looks like gist ID) -> (csGist, "abc123")
  ##   "clock.md" (default) -> (csDemo, "clock")
  
  if contentRef.len == 0:
    return (csNone, "")
  
  # Check for explicit prefix
  if contentRef.startsWith("gist:"):
    return (csGist, contentRef[5..^1])
  elif contentRef.startsWith("demo:"):
    return (csDemo, contentRef[5..^1])
  elif contentRef.startsWith("file:"):
    return (csFile, contentRef[5..^1])
  
  # Check for full GitHub gist URL
  if "gist.github.com/" in contentRef:
    let parts = contentRef.split('/')
    for i, part in parts:
      if part == "gist.github.com" and i + 2 < parts.len:
        # Could be gist.github.com/user/id or gist.github.com/id
        let potentialId = parts[i + 2]
        if potentialId.len > 0:
          return (csGist, potentialId)
  
  # Check if it looks like a gist ID (32 hex chars)
  if contentRef.len == 32:
    var isHex = true
    for c in contentRef:
      if c notin {'0'..'9', 'a'..'f', 'A'..'F'}:
        isHex = false
        break
    if isHex:
      return (csGist, contentRef)
  
  # Check if it's a file path
  if fileExists(contentRef):
    return (csFile, contentRef)
  
  # Default to demo
  return (csDemo, contentRef)

proc loadContentFromSource*(contentRef: string): string =
  ## Load markdown content from various sources
  let (source, id) = parseContentReference(contentRef)
  
  case source
  of csGist:
    # Fetch gist and find first .md file
    when defined(emscripten):
      raise newException(IOError, "Gist loading not supported in WASM CLI mode")
    elif defined(noGistLoading):
      raise newException(IOError, "Gist loading disabled (compiled with -d:noGistLoading)")
    else:
      let client = newHttpClient()
      let apiUrl = "https://api.github.com/gists/" & id
      try:
        let jsonStr = client.getContent(apiUrl)
        # Simple JSON parsing - look for first .md file
        # Format: "filename.md":{"content":"..."}
        let mdStart = jsonStr.find(".md")
        if mdStart < 0:
          raise newException(IOError, "No .md file found in gist " & id)
        
        # Find the content field
        let contentStart = jsonStr.find("\"content\":", mdStart)
        if contentStart < 0:
          raise newException(IOError, "Could not parse gist content")
        
        # Extract content (simplified - doesn't handle all edge cases)
        let valueStart = jsonStr.find("\"", contentStart + 10) + 1
        var valueEnd = valueStart
        var escaped = false
        while valueEnd < jsonStr.len:
          let c = jsonStr[valueEnd]
          if escaped:
            escaped = false
          elif c == '\\':
            escaped = true
          elif c == '"':
            break
          inc valueEnd
        
        let content = jsonStr[valueStart..<valueEnd]
        # Unescape basic sequences
        return content.multiReplace([("\\n", "\n"), ("\\t", "\t"), ("\\\"", "\""), ("\\\\", "\\")])
      except:
        raise newException(IOError, "Failed to fetch gist: " & id)
  
  of csDemo:
    # Load from demos/ directory
    var demoPath = id
    if not demoPath.endsWith(".md"):
      demoPath.add(".md")
    
    # Try multiple paths
    let paths = [
      "demos/" & demoPath,
      "docs/demos/" & demoPath,
      "../demos/" & demoPath,
      demoPath
    ]
    
    for path in paths:
      if fileExists(path):
        return readFile(path)
    
    raise newException(IOError, "Demo not found: " & demoPath)
  
  of csFile:
    if not fileExists(id):
      raise newException(IOError, "File not found: " & id)
    return readFile(id)
  
  of csNone:
    return ""

proc requireModule*(moduleRef: string, env: ref Env = nil): ref Env =
  ## Load and compile a .nim module from a gist or local file
  ## Returns a ref Env with the module's exported functions and variables
  ## 
  ## Format examples:
  ##   requireModule("gist:abc123def456/canvas.nim")
  ##   requireModule("lib/utils.nim")
  
  # Check cache first
  if globalModuleCache.modules.hasKey(moduleRef):
    return globalModuleCache.modules[moduleRef]
  
  var sourceCode: string
  let (gistId, filename, isGist) = parseGistReference(moduleRef)
  
  if isGist:
    # Fetch from gist
    sourceCode = fetchGistFile(gistId, filename)
    
    when defined(emscripten):
      # In WASM, empty string means we need JS to fetch it
      if sourceCode == "":
        # Check if code was loaded by JS
        if globalModuleCache.sourceCode.hasKey(moduleRef):
          sourceCode = globalModuleCache.sourceCode[moduleRef]
        else:
          # Signal that async fetch is needed
          raise newException(IOError, "Module not yet loaded: " & moduleRef)
  else:
    # Load from local file
    if not fileExists(filename):
      raise newException(IOError, "Module file not found: " & filename)
    sourceCode = readFile(filename)
  
  # Compile using nimini
  try:
    let program = compileSource(sourceCode)
    
    # Create runtime environment for this module
    var moduleEnv = newEnv()
    
    # If a parent environment was provided, link it
    if env != nil:
      moduleEnv.parent = env
    
    # Execute the module to populate its exports
    execProgram(program, moduleEnv)
    
    # Cache the compiled module
    globalModuleCache.modules[moduleRef] = moduleEnv
    globalModuleCache.sourceCode[moduleRef] = sourceCode
    
    return moduleEnv
    
  except Exception as e:
    raise newException(ValueError, "Failed to compile module " & moduleRef & ": " & e.msg)

proc loadGistCode*(moduleRef: string, code: string) =
  ## Called by JavaScript in WASM builds after fetching gist content
  ## Stores the code for later compilation
  globalModuleCache.sourceCode[moduleRef] = code

proc clearModuleCache*() =
  ## Clear all cached modules (useful for development/testing)
  globalModuleCache.modules.clear()
  globalModuleCache.sourceCode.clear()

proc listCachedModules*(): seq[string] =
  ## Get list of all cached module references
  result = @[]
  for key in globalModuleCache.modules.keys:
    result.add(key)

# ================================================================
# NIMINI BRIDGE - Module loading and runtime
# ================================================================

# Buffer operations and layer management now imported from src/layers
# API registration and helper templates now in lib/nimini_bridge.nim

# ================================================================
# RUNTIME API INTEGRATION - Types and Globals
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
    styleSheet: StyleSheet    # Style configurations from front matter
    themeBackground: tuple[r, g, b: uint8]  # Theme's background color for terminal
    minWidth: int  # Minimum required terminal width (0 = no requirement)
    minHeight: int  # Minimum required terminal height (0 = no requirement)
    # Pre-compiled layer references
    bgLayer: Layer
    fgLayer: Layer
    # Section management
    sectionMgr: SectionManager   # Section manager handles all section state
    # Embedded content (figlet fonts, data files, ANSI art, etc.)
    embeddedContent*: seq[EmbeddedContent]  # For getContent() access
    # Global event handlers
    globalRenderHandlers*: seq[GlobalHandler]
    globalUpdateHandlers*: seq[GlobalHandler]
    globalInputHandlers*: seq[GlobalHandler]

# Global references to layers (set in initStorieContext)
var gDefaultLayer: Layer  # Single default layer (layer 0)
var gTextStyle, gBorderStyle, gInfoStyle: Style
var gAppState: AppState  # Global reference to app state for state accessors

# Forward declaration for storieCtx (used by tui_helpers)
var storieCtx: StorieContext

# Import TUI helpers (proper module now, not included)
import lib/tui_helpers

# Import TUI bindings after the helpers
import lib/tui_helpers_bindings

# Import TUI terminal backend (auto-rendering with caching)
import lib/tui_terminal
import lib/tui_terminal_bindings

# Import TUI module (production retained mode UI system)
import lib/tui
import lib/tui_bindings

# Import text editor module and bindings
import lib/text_editor
import lib/text_editor_bindings

# Random number generator - consistent across WASM and native
var globalRng: Rand

proc initGlobalRng*() =
  ## Initialize the global random number generator with a seed
  when defined(emscripten):
    # For WASM, use a fixed seed or timestamp if available
    globalRng = initRand(123456)
  else:
    # For native, use system entropy
    globalRng = initRand()

# Global cache for loaded figlet fonts
var gFigletFonts = initTable[string, FIGfont]()

# Note: registerTstorieApis is now defined in lib/nimini_bridge.nim
# The bridge module handles all API registrations for nimini-interpreted code

var globalRuntimeEnv*: ref Env = nil

proc initGlobalRuntime*(state: AppState) =
  ## Initialize the global nimini runtime environment with tstorie APIs
  if globalRuntimeEnv == nil:
    globalRuntimeEnv = newEnv()
    registerTstorieApis(globalRuntimeEnv, state)
    initPlugins()  # Register all {.nimini.} pragma functions

proc require*(moduleRef: string, state: AppState): ref Env =
  ## Load a Nim module at runtime from a gist or local file
  ## Usage: let canvas = require("gist:abc123/canvas.nim", state)
  ##        let utils = require("lib/utils.nim", state)
  
  if globalRuntimeEnv == nil:
    initGlobalRuntime(state)
  
  try:
    return requireModule(moduleRef, globalRuntimeEnv)
  except Exception:
    let e = getCurrentException()
    echo "Error loading module '", moduleRef, "': ", e.msg
    raise e

# ================================================================
# COLOR UTILITIES - Now in src/types.nim
# ================================================================
# toAnsi256 and toAnsi8 functions moved to src/types.nim

# ================================================================
# TERMINAL SETUP
# ================================================================

proc detectColorSupport(): int =
  when defined(emscripten):
    return 16777216
  else:
    let colorterm = getEnv("COLORTERM")
    if colorterm in ["truecolor", "24bit"]:
      return 16777216
    let term = getEnv("TERM")
    if "256color" in term:
      return 256
    if term in ["xterm", "screen", "linux"]:
      return 8
    return 0

proc getInputEvent*(state: AppState): seq[InputEvent] =
  ## Wrapper for pollInput that uses the app state's input parser
  return pollInput(state.inputParser)

# ================================================================
# BUFFER AND LAYER OPERATIONS - Now imported from src/layers
# ================================================================
# Buffer operations (newTermBuffer, write, fillRect, clear, etc.)
# Layer management (addLayer, getLayer, removeLayer, resizeLayers, compositeLayers)
# Display rendering (display, compositeBufferOnto)
# All these functions are now in src/layers.nim

# ================================================================
# FPS CONTROL - Now in src/appstate.nim
# ================================================================
# setTargetFps, updateFpsCounter, getFps, getFrameCount, getTotalTime moved to src/appstate

# ================================================================
# USER CALLBACKS
# ================================================================

# Global markdown file path (can be set via CLI or from user files)
var gMarkdownFile*: string = "index.md"
var gWaitingForGist*: bool = false
var gShowingDimensionWarning*: bool = false  # Flag to skip layer compositing

# Dropped file tracking (for drop target functionality) - now in nimini_bridge.nim
# var gDroppedFileName*: string = ""
# var gDroppedFileData*: string = ""
# var gDroppedFileSize*: int = 0

# ================================================================
# HELPER FUNCTIONS FOR RUNTIME API (used by both native and WASM)
# ================================================================
# Note: toInt, toBool, toFloat are available from nimini/runtime

# ================================================================
# PLATFORM-SPECIFIC INCLUDES
# ================================================================

when not defined(emscripten):
  var onInit*: proc(state: AppState) = nil
  var onUpdate*: proc(state: AppState, dt: float) = nil
  var onRender*: proc(state: AppState) = nil
  var onShutdown*: proc(state: AppState) = nil
  var onInput*: proc(state: AppState, event: InputEvent): bool = nil
  
  # Include runtime API from src/
  include src/runtime_api
  
  proc callOnSetup(state: AppState) =
    if not onInit.isNil:
      onInit(state)
  
  proc callOnFrame(state: AppState, dt: float) =
    if not onUpdate.isNil:
      onUpdate(state, dt)
  
  proc callOnDraw(state: AppState) =
    if not onRender.isNil:
      onRender(state)
  
  proc callOnShutdown(state: AppState) =
    if not onShutdown.isNil:
      onShutdown(state)
  
  proc callOnInput(state: AppState, event: InputEvent): bool =
    if not onInput.isNil:
      return onInput(state, event)
    return false

# ================================================================
# WEB EXPORTS
# ================================================================

when defined(emscripten):
  var globalState: AppState
  var lastRenderExecutedCount*: int = -1
  var lastError*: string = ""
  var globalMinWidth*: int = 0  # Minimum required width (0 = no requirement)
  var globalMinHeight*: int = 0  # Minimum required height (0 = no requirement)
  
  # SDL3 backend globals (when using SDL3 with emscripten)
  when defined(sdl3Backend):
    var globalCanvas: SDLCanvas
    import src/input/sdl3input
    var globalInputHandler: SDL3InputHandler
  
  # Store URL params locally until runtime is initialized
  var wasmPendingParams: seq[(string, string)] = @[]
  var gEmSetUrlParamCalls: int = 0
  var gFlushWasmParamsCalls: int = 0
  
  # For WASM builds, include runtime API from src/
  var onInit*: proc(state: AppState) = nil
  var onUpdate*: proc(state: AppState, dt: float) = nil
  var onRender*: proc(state: AppState) = nil
  var onShutdown*: proc(state: AppState) = nil
  var onInput*: proc(state: AppState, event: InputEvent): bool = nil
  
  # Include runtime API from src/
  include src/runtime_api
  
  # Define callback wrapper procs that call the user-defined callbacks
  proc userInit(state: AppState) =
    if not onInit.isNil:
      onInit(state)

  proc userUpdate(state: AppState, dt: float) =
    if not onUpdate.isNil:
      onUpdate(state, dt)

  proc userRender(state: AppState) =
    if not onRender.isNil:
      onRender(state)
  
  # Direct render caller for WASM
  proc renderStorie(state: AppState) =
    if storieCtx.isNil:
      echo "[renderStorie] storieCtx is NIL"
      return
    
    # Check if we have any render blocks
    var hasRenderBlocks = false
    var renderBlockCount = 0
    for codeBlock in storieCtx.codeBlocks:
      if codeBlock.lifecycle == "render":
        hasRenderBlocks = true
        renderBlockCount += 1
    
    if not hasRenderBlocks:
      return
    
    # Execute render code blocks - they write to layers
    var executedCount = 0
    for codeBlock in storieCtx.codeBlocks:
      if codeBlock.lifecycle == "render":
        let success = executeCodeBlock(storieCtx.niminiContext, codeBlock, state)
        if success:
          executedCount += 1
    
    lastRenderExecutedCount = executedCount

  proc userInput(state: AppState, event: InputEvent): bool =
    if not onInput.isNil:
      return onInput(state, event)
    return false

  proc userShutdown(state: AppState) =
    if not onShutdown.isNil:
      onShutdown(state)
  
  # SDL3 main loop for emscripten
  when defined(sdl3Backend):
    proc sdl3MainLoop() {.cdecl, exportc: "sdl3MainLoop".} =
      # Poll and convert events using SDL3 input handler
      let inputEvents = globalInputHandler.pollInput()
      
      # Process input events and pass to handler
      for event in inputEvents:
        if event.kind == ResizeEvent:
          globalState.resizeState(event.newWidth, event.newHeight)
        else:
          # Pass event to input handler (defined in runtime_api.nim)
          let consumed = inputHandler(globalState, event)
          if not globalState.running:
            return
      
      # Update timing
      let deltaTime = 1.0 / 60.0  # Fixed for now
      globalState.updateFpsCounter(deltaTime)
      
      # Call update lifecycle
      if not onUpdate.isNil:
        onUpdate(globalState, deltaTime)
      
      # Check if storieCtx exists
      if storieCtx.isNil:
        return
      
      # Call render - this writes to gAppState.layers (unified layer system)
      renderStorie(globalState)
      
      # For SDL3: Use terminal backend's layer compositing, then render to pixels
      # 1. Composite layers using terminal backend's logic (this is the proven system)
      compositeLayers(globalState)
      
      # 2. Copy composited buffer to SDL3 canvas cells[]
      globalCanvas.renderBuffer(globalState.currentBuffer)
      
      # 3. Render cells to pixels with dirty tracking
      globalCanvas.renderCellsToPixels()
      
      # 4. Present the frame
      globalCanvas.present()
  
  proc flushWasmParams() =
    ## Flush pending WASM params to the nimini runtime
    gFlushWasmParamsCalls.inc
    
    if runtimeEnv.isNil:
      return
    
    # Store debug info about execution
    defineVar(runtimeEnv, "_emset_calls", valString($gEmSetUrlParamCalls))
    defineVar(runtimeEnv, "_flush_calls", valString($gFlushWasmParamsCalls))
    defineVar(runtimeEnv, "_flush_count", valString($wasmPendingParams.len))
    
    if wasmPendingParams.len == 0:
      defineVar(runtimeEnv, "_flush_status", valString("empty_array"))
      return
    
    for (name, value) in wasmPendingParams:
      setParam(name, value)
      # Also set a debug flag directly in runtime to confirm flushing worked
      defineVar(runtimeEnv, "_wasm_flushed_" & name, valString(value))
    
    defineVar(runtimeEnv, "_flush_status", valString("flushed_" & $wasmPendingParams.len))
  
  # JavaScript bridge functions for font and shader loading
  # JS bridge declarations for web builds (defined in font_metrics_bridge.js)
  proc emLoadFont(fontName: cstring) {.importc.}
  proc emLoadShaders(shadersStr: cstring) {.importc.}
  proc emSetFontSize(size: int) {.importc.}
  
  when defined(sdl3Backend):
    # SDL3-specific font reloading (used by progressive_font_loader.js)
    proc emReloadFontSDL3(fontPath: cstring, size: cfloat) {.exportc.} =
      ## Callback from JavaScript after progressive font loading
      ## fontPath is the virtual filesystem path (e.g., "/fonts/iosevka-full.ttf")
      try:
        let pathStr = $fontPath
        echo "[SDL3] Reloading font from: ", pathStr, " (size: ", size, ")"
        
        if not globalCanvas.isNil:
          globalCanvas.updateFont(pathStr, size)
          
          # Force full redraw with new font by clearing prevCells (breaks dirty tracking)
          globalCanvas.firstFrame = true
          for i in 0..<globalCanvas.prevCells.len:
            globalCanvas.prevCells[i].ch = ""  # Make prev different from current
          
          echo "[SDL3] Font reloaded successfully, full redraw triggered"
        else:
          echo "[SDL3] ERROR: globalCanvas is nil"
      except Exception as e:
        echo "[SDL3] ERROR reloading font: ", e.msg
    
    proc emForceRedraw() {.exportc.} =
      ## Force a complete redraw on the next frame
      ## Useful after font changes or when display needs refreshing
      try:
        if not globalCanvas.isNil:
          globalCanvas.firstFrame = true
          for i in 0..<globalCanvas.prevCells.len:
            globalCanvas.prevCells[i].ch = ""  # Invalidate all cells
          echo "[SDL3] Forced redraw requested"
        else:
          echo "[SDL3] ERROR: Cannot force redraw, globalCanvas is nil"
      except Exception as e:
        echo "[SDL3] ERROR forcing redraw: ", e.msg
  
  proc loadFontFromFrontMatter(fontName: string) =
    ## DISABLED: Dynamic font loading removed in favor of progressive loading
    ## The app now starts with iosevka-startup.ttf (33KB) and automatically upgrades
    ## to iosevka-full.ttf (1.4MB) after 2 seconds (see progressive_font_loader.js)
    discard
  
  proc setFontSizeFromFrontMatter(size: int) =
    ## Set font size from front matter
    try:
      emSetFontSize(size)
    except:
      discard  # Gracefully ignore errors
  
  proc loadShadersFromFrontMatter(shadersStr: string) =
    ## Load shader chain from front matter (semicolon or + separated)
    try:
      emLoadShaders(shadersStr.cstring)
    except:
      discard  # Gracefully ignore errors
  
  proc emInit(width, height: int) {.exportc.} =
    globalState = newAppState(width, height)
    
    # Initialize timing system FIRST
    timing.initTiming()
    
    # Initialize layer effects plugin
    initLayerFxPlugin()
    
    # URL parameters are parsed in JavaScript (parseAndStoreUrlParams in index.html)
    # and stored before this function is called
    
    # Call initStorieContext directly (callback system doesn't work in WASM)
    initStorieContext(globalState)
    
    # Flush any URL params that were set before initialization
    flushWasmParams()
    
    # Apply theme parameter if present (will be applied in initStorieContext)
  
  proc checkAndRenderDimensionWarning(): bool =
    ## Check if dimensions meet requirements and render warning if not.
    ## Returns true if dimensions are OK, false if too small.
    
    # Check if we have requirements (use storieCtx if available, otherwise globals)
    var minW, minH: int
    if not storieCtx.isNil:
      minW = storieCtx.minWidth
      minH = storieCtx.minHeight
    else:
      minW = globalMinWidth
      minH = globalMinHeight
    
    # DEBUG: Always show values in top-left corner
    var debugStyle = defaultStyle()
    debugStyle.fg = rgb(255'u8, 100'u8, 100'u8)
    debugStyle.bold = true
    let debugMsg = "Check: " & $minW & "x" & $minH & " vs " & $globalState.termWidth & "x" & $globalState.termHeight
    globalState.currentBuffer.writeCellText(1, 1, debugMsg, debugStyle)
    
    if minW <= 0 and minH <= 0:
      gShowingDimensionWarning = false
      return true  # No minimum requirements
    
    let needsWidth = minW > 0 and globalState.termWidth < minW
    let needsHeight = minH > 0 and globalState.termHeight < minH
    
    if not needsWidth and not needsHeight:
      gShowingDimensionWarning = false
      return true  # Dimensions are sufficient
    
    # Set flag to prevent layer compositing
    gShowingDimensionWarning = true
    
    # Clear screen and render centered warning message
    globalState.currentBuffer.clearCells((0'u8, 0'u8, 0'u8))
    
    # Build the message lines with current dimensions for debugging
    let reqWidth = if minW > 0: minW else: globalState.termWidth
    let reqHeight = if minH > 0: minH else: globalState.termHeight
    
    let line1 = $reqWidth & " x " & $reqHeight & " dimensions required."
    let line2 = "Current: " & $globalState.termWidth & " x " & $globalState.termHeight
    let line3 = "Resize browser window to continue."
    
    # Calculate centering
    let centerY = globalState.termHeight div 2
    
    # Render lines centered
    var warnStyle = defaultStyle()
    warnStyle.fg = yellow()
    warnStyle.bold = true
    
    let line1X = (globalState.termWidth - line1.len) div 2
    let line1Y = centerY
    if line1Y >= 0 and line1Y < globalState.termHeight:
      globalState.currentBuffer.writeCellText(line1X, line1Y, line1, warnStyle)
    
    let line2X = (globalState.termWidth - line2.len) div 2
    let line2Y = centerY + 1
    if line2Y >= 0 and line2Y < globalState.termHeight:
      globalState.currentBuffer.writeCellText(line2X, line2Y, line2, warnStyle)
    
    let line3X = (globalState.termWidth - line3.len) div 2
    let line3Y = centerY + 2
    if line3Y >= 0 and line3Y < globalState.termHeight:
      globalState.currentBuffer.writeCellText(line3X, line3Y, line3, warnStyle)
    
    return false
  
  proc emUpdate(deltaMs: float) {.exportc.} =
    var dt = deltaMs / 1000.0
    
    # Update timing system (call FIRST to get accurate deltaTime)
    timing.updateTiming()
    timing.updateTimers()
    timing.processNextFrameCallbacks()
    
    # Use real measured deltaTime from timing module
    dt = timing.getDeltaTime()
    
    # Update global state for compatibility
    globalState.totalTime = timing.getTotalTime()
    globalState.frameCount = timing.getFrameCount()
    
    if globalState.totalTime - globalState.lastFpsUpdate >= 0.5:
      # Guard against division by zero
      if dt > 0.0:
        globalState.fps = 1.0 / dt
      else:
        globalState.fps = 60.0  # Default to 60 FPS if dt is invalid
      globalState.lastFpsUpdate = globalState.totalTime
    
    # DEBUG: Write something to see if emUpdate is running
    var testStyle = defaultStyle()
    testStyle.fg = rgb(255'u8, 0'u8, 255'u8)
    testStyle.bold = true
    globalState.currentBuffer.writeCellText(1, 0, "emUpdate running!", testStyle)
    
    # Check if dimensions meet requirements and render warning if not
    if not checkAndRenderDimensionWarning():
      # Dimensions insufficient, warning already rendered
      # Skip normal rendering (no need to composite, warning is in currentBuffer)
      return
    
    # Call update directly
    if not storieCtx.isNil:
      for codeBlock in storieCtx.codeBlocks:
        if codeBlock.lifecycle == "update":
          discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState, deltaTime = dt)
    
    # Note: Don't clear buffer here - compositeLayers will do it with theme background
    
    # Clear layer buffers each frame
    if not storieCtx.isNil:
      if not storieCtx.bgLayer.isNil:
        storieCtx.bgLayer.buffer.clearCellsTransparent()
      if not storieCtx.fgLayer.isNil:
        storieCtx.fgLayer.buffer.clearCellsTransparent()
    
    # Call render - this writes to layers
    renderStorie(globalState)

    # Composite layers onto currentBuffer (this will fill with theme background first)
    # Only composite if not showing dimension warning
    if not gShowingDimensionWarning:
      compositeLayers(globalState)

    # Optional: Show minimal debug info at bottom (can be removed)
    when defined(emscripten):
      if lastError.len > 0:
        let hudY = globalState.termHeight - 1
        var errStyle = defaultStyle()
        errStyle.fg = red()
        errStyle.bold = true
        globalState.currentBuffer.writeCellText(2, hudY, "Error: " & lastError, errStyle)

      if lastError.len > 0:
        var errStyle = defaultStyle()
        errStyle.fg = rgb(255'u8, 255'u8, 0'u8)  # Bright yellow
        errStyle.bg = black()
        errStyle.bold = true
        # Show error on multiple lines if needed
        var yPos = 8
        var remaining = lastError
        while remaining.len > 0:
          let lineLen = min(globalState.termWidth - 8, remaining.len)
          globalState.currentBuffer.writeCellText(4, yPos, "ERR: " & remaining[0 ..< lineLen], errStyle)
          remaining = if remaining.len > lineLen: remaining[lineLen .. ^1] else: ""
          yPos += 1
          if yPos >= globalState.termHeight - 1: break
  
  proc emResize(width, height: int) {.exportc.} =
    globalState.termWidth = width
    globalState.termHeight = height
    globalState.currentBuffer = newTermBuffer(width, height)
    globalState.previousBuffer = newTermBuffer(width, height)
    resizeLayers(globalState, width, height)
    
    # Check dimensions and render warning if needed
    discard checkAndRenderDimensionWarning()
  
  # Thread-local storage for cell character to ensure cstring stability
  var cellCharBuffer {.threadvar.}: string
  
  proc emGetCell(x, y: int): cstring {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      cellCharBuffer = globalState.currentBuffer.cells[idx].ch
      return cstring(cellCharBuffer)
    return cstring("")
  
  proc emGetCellFgR(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.fg.r.int
    return 255
  
  proc emGetCellFgG(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.fg.g.int
    return 255
  
  proc emGetCellFgB(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.fg.b.int
    return 255
  
  proc emGetCellBgR(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.bg.r.int
    return 0
  
  proc emGetCellBgG(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.bg.g.int
    return 0
  
  proc emGetCellBgB(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return globalState.currentBuffer.cells[idx].style.bg.b.int
    return 0
  
  proc emGetCellBold(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return if globalState.currentBuffer.cells[idx].style.bold: 1 else: 0
    return 0
  
  proc emGetCellItalic(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return if globalState.currentBuffer.cells[idx].style.italic: 1 else: 0
    return 0
  
  proc emGetCellUnderline(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      return if globalState.currentBuffer.cells[idx].style.underline: 1 else: 0
    return 0
  
  proc emGetCellWidth(x, y: int): int {.exportc.} =
    if x >= 0 and x < globalState.currentBuffer.width and 
       y >= 0 and y < globalState.currentBuffer.height:
      let idx = y * globalState.currentBuffer.width + x
      let ch = globalState.currentBuffer.cells[idx].ch
      if ch.len > 0:
        return getCharDisplayWidth(ch)
    return 1
  
  proc normalizeJSKeyCode(jsKeyCode: int): int =
    ## Convert JavaScript keyCode to unified tStorie keyCode
    ## 
    ## JavaScript uses different key code values than our unified system:
    ## - JS arrows: 37-40 → Unified: 1000-1003
    ## - JS function keys: 112-123 → Unified: 1100-1111
    ## - JS navigation keys: Different values → Unified: 1004-1008
    ## 
    ## This ensures consistent behavior between terminal, SDL3, and WASM backends.
    case jsKeyCode
    of 37: return KEY_LEFT.int    # Left arrow
    of 38: return KEY_UP.int      # Up arrow
    of 39: return KEY_RIGHT.int   # Right arrow
    of 40: return KEY_DOWN.int    # Down arrow
    of 36: return KEY_HOME.int    # Home
    of 35: return KEY_END.int     # End
    of 33: return KEY_PAGEUP.int  # Page Up
    of 34: return KEY_PAGEDOWN.int # Page Down
    of 45: return KEY_INSERT.int  # Insert
    of 46: return KEY_DELETE.int  # Delete
    of 112: return KEY_F1.int     # F1
    of 113: return KEY_F2.int     # F2
    of 114: return KEY_F3.int     # F3
    of 115: return KEY_F4.int     # F4
    of 116: return KEY_F5.int     # F5
    of 117: return KEY_F6.int     # F6
    of 118: return KEY_F7.int     # F7
    of 119: return KEY_F8.int     # F8
    of 120: return KEY_F9.int     # F9
    of 121: return KEY_F10.int    # F10
    of 122: return KEY_F11.int    # F11
    of 123: return KEY_F12.int    # F12
    # Control keys that match
    of 8: return KEY_BACKSPACE.int
    of 9: return KEY_TAB.int
    of 13: return KEY_RETURN.int
    of 27: return KEY_ESCAPE.int
    # Everything else passes through (printable characters, etc.)
    else: return jsKeyCode
  
  proc emHandleKeyPress(keyCode: int, shift, alt, ctrl: int) {.exportc.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    # Normalize JavaScript keyCode to unified system
    let normalizedKeyCode = normalizeJSKeyCode(keyCode)
    
    let event = InputEvent(kind: KeyEvent, keyCode: normalizedKeyCode, keyMods: mods, keyAction: Press)
    # Call inputHandler directly
    discard inputHandler(globalState, event)
  
  proc emHandleTextInput(text: cstring) {.exportc.} =
    let event = InputEvent(kind: TextEvent, text: $text)
    # Call inputHandler directly
    discard inputHandler(globalState, event)
  
  proc emHandleMouseClick(x, y, button, shift, alt, ctrl: int) {.exportc.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    let mouseButton = case button
      of 0: Left
      of 1: Middle
      of 2: Right
      else: Unknown
    
    let event = InputEvent(kind: MouseEvent, button: mouseButton, mouseX: x, mouseY: y, mods: mods, action: Press)
    # Call inputHandler directly
    discard inputHandler(globalState, event)
  
  proc emHandleMouseRelease(x, y, button, shift, alt, ctrl: int) {.exportc.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    let mouseButton = case button
      of 0: Left
      of 1: Middle
      of 2: Right
      else: Unknown
    
    let event = InputEvent(kind: MouseEvent, button: mouseButton, mouseX: x, mouseY: y, mods: mods, action: Release)
    # Call inputHandler directly
    discard inputHandler(globalState, event)
  
  proc emHandleMouseMove(x, y: int) {.exportc.} =
    globalState.lastMouseX = x
    globalState.lastMouseY = y
    let event = InputEvent(kind: MouseMoveEvent, moveX: x, moveY: y, moveMods: {})
    # Call inputHandler directly
    discard inputHandler(globalState, event)
  
  proc emHandleMouseWheel(x, y, deltaY, shift, alt, ctrl: int) {.exportc: "emHandleMouseWheel", used.} =
    var mods: set[uint8] = {}
    if shift != 0: mods.incl ModShift
    if alt != 0: mods.incl ModAlt
    if ctrl != 0: mods.incl ModCtrl
    
    # deltaY is positive when scrolling down, negative when scrolling up
    let mouseButton = if deltaY < 0: ScrollUp else: ScrollDown
    
    let event = InputEvent(kind: MouseEvent, button: mouseButton, mouseX: x, mouseY: y, mods: mods, action: Press)
    # Call inputHandler directly
    discard inputHandler(globalState, event)
  
  proc emSetWaitingForGist() {.exportc.} =
    ## Set flag to wait for gist content instead of loading index.md
    gWaitingForGist = true
    # Ensure storieCtx exists (will be properly initialized later)
    if storieCtx.isNil:
      storieCtx = StorieContext()
  
  # URL parameters are now parsed directly in Nim via parseUrlParams()
  # No JS bridge needed for parameter access
  
  proc emLoadGistCode(moduleRef: cstring, code: cstring) {.exportc.} =
    ## Called by JavaScript after fetching a gist file
    ## Stores the code for later compilation by requireModule
    try:
      if moduleRef.isNil or code.isNil:
        lastError = "moduleRef or code is nil"
        return
      
      let modRef = $moduleRef
      let sourceCode = $code
      loadGistCode(modRef, sourceCode)
      
    except Exception:
      let e = getCurrentException()
      lastError = "Failed to load gist code: " & e.msg
  
  proc emRequireModule(moduleRef: cstring): cstring {.exportc.} =
    ## Load a module at runtime
    ## Returns "loaded" if successful, "fetch_needed" if JS needs to fetch gist
    ## Returns error message if compilation fails
    try:
      if moduleRef.isNil:
        return "error: moduleRef is nil".cstring
      
      let modRef = $moduleRef
      
      # Try to load the module
      discard require(modRef, globalState)
      return "loaded".cstring
      
    except IOError:
      let e = getCurrentException()
      # Module not yet loaded - signal JS to fetch it
      if "not yet loaded" in e.msg:
        return "fetch_needed".cstring
      else:
        return ("error: " & e.msg).cstring
    except Exception:
      let e = getCurrentException()
      return ("error: " & e.msg).cstring
  
  proc emLoadMarkdownFromJS(markdownContent: cstring) {.exportc.} =
    ## Load markdown content from JavaScript and reinitialize the storie context
    try:
      # Convert cstring to string safely
      if markdownContent.isNil:
        lastError = "markdownContent is nil"
        return
      
      let content = $markdownContent
      
      # Ensure content is valid
      if content.len == 0:
        lastError = "content is empty"
        return
      
      # Parse the markdown document (includes sections)
      let doc = parseMarkdownDocument(content)
      
      # Check if we got any blocks
      if doc.codeBlocks.len == 0:
        lastError = "no blocks parsed from " & $content.len & " bytes"
        return
      
      # Update the storie context with new code blocks and sections
      if not storieCtx.isNil and not storieCtx.niminiContext.isNil:
        gWaitingForGist = false
        
        # Flush WASM params before executing init blocks
        flushWasmParams()
        
        # Replace the code blocks and sections
        storieCtx.codeBlocks = doc.codeBlocks
        storieCtx.sectionMgr = newSectionManager(doc.sections)
        storieCtx.frontMatter = doc.frontMatter
        storieCtx.styleSheet = doc.styleSheet
        storieCtx.embeddedContent = doc.embeddedContent

        # Parse minWidth and minHeight from front matter (WASM fix)
        storieCtx.minWidth = 0
        storieCtx.minHeight = 0
        if storieCtx.frontMatter.hasKey("minWidth"):
          try:
            storieCtx.minWidth = parseInt(storieCtx.frontMatter["minWidth"])
            globalMinWidth = storieCtx.minWidth
          except:
            discard
        if storieCtx.frontMatter.hasKey("minHeight"):
          try:
            storieCtx.minHeight = parseInt(storieCtx.frontMatter["minHeight"])
            globalMinHeight = storieCtx.minHeight
          except:
            discard

        # Also update globalState styleSheet for API access
        globalState.styleSheet = doc.styleSheet
        
        # Update global default style from stylesheet
        if doc.styleSheet.hasKey("default"):
          # Use explicit "default" style if defined
          setDefaultStyleConfig(doc.styleSheet["default"])
        elif doc.styleSheet.hasKey("body"):
          # Fallback: use "body" style background/foreground for default
          setDefaultStyleConfig(doc.styleSheet["body"])
        
        # Check if theme parameter is set and override the stylesheet
        if hasParamDirect("theme"):
          let themeName = getParamDirect("theme")
          if themeName.len > 0:
            try:
              let newStyleSheet = applyThemeByName(themeName)
              storieCtx.styleSheet = newStyleSheet
              globalState.styleSheet = newStyleSheet
              # Update global default style from theme
              if newStyleSheet.hasKey("default"):
                # Use explicit "default" style if defined
                setDefaultStyleConfig(newStyleSheet["default"])
              elif newStyleSheet.hasKey("body"):
                # Fallback: use "body" style background/foreground for default
                setDefaultStyleConfig(newStyleSheet["body"])
              # Re-initialize canvas module with new stylesheet
              if globalState.layers.len > 0:
                initCanvasModule(addr globalState, addr storieCtx.sectionMgr, addr storieCtx.styleSheet)
                registerCanvasBindings(addr globalState.layers[0].buffer, addr globalState, addr storieCtx.styleSheet)
                registerCanvasEditorBindings()
                # Register layer effects bindings
                registerLayerFxBindings(storieCtx.niminiContext.env)
                # Register text editor bindings
                registerTextEditorBindings(storieCtx.niminiContext.env)
            except:
              discard
        
        # Extract theme background color from stylesheet and update globalState
        if storieCtx.styleSheet.hasKey("body"):
          storieCtx.themeBackground = storieCtx.styleSheet["body"].bg
          globalState.themeBackground = storieCtx.themeBackground
        else:
          storieCtx.themeBackground = (0'u8, 0'u8, 0'u8)
          globalState.themeBackground = (0'u8, 0'u8, 0'u8)
        
        # Expose front matter variables to Nimini environment
        exposeFrontMatterVariables()
        
        # Update browser tab title if title is defined in frontmatter
        if storieCtx.frontMatter.hasKey("title"):
          setDocumentTitle(storieCtx.frontMatter["title"])
        
        # Apply front matter settings for font, fontsize, and shaders
        when defined(emscripten):
          # Load custom font if specified (only if not overridden by URL param)
          if not hasParamDirect("font") and storieCtx.frontMatter.hasKey("font"):
            let fontName = storieCtx.frontMatter["font"]
            if fontName.len > 0:
              loadFontFromFrontMatter(fontName)
          
          # Apply font size if specified (only if not overridden by URL param)
          if not hasParamDirect("fontsize") and storieCtx.frontMatter.hasKey("fontsize"):
            try:
              let fontSize = parseInt(storieCtx.frontMatter["fontsize"])
              if fontSize > 0:
                setFontSizeFromFrontMatter(fontSize)
            except:
              discard  # Gracefully ignore invalid fontsize
          
          # Load shaders if specified (only if not overridden by URL param)
          if not hasParamDirect("shader") and storieCtx.frontMatter.hasKey("shaders"):
            let shadersStr = storieCtx.frontMatter["shaders"]
            if shadersStr.len > 0:
              loadShadersFromFrontMatter(shadersStr)
        
        # Clear all layer buffers with theme background
        for layer in globalState.layers:
          layer.buffer.clearCells(globalState.themeBackground)
        
        # Execute init blocks immediately
        for codeBlock in doc.codeBlocks:
          if codeBlock.lifecycle == "init":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
        
        # Execute render blocks immediately to show content
        for codeBlock in doc.codeBlocks:
          if codeBlock.lifecycle == "render":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
    except Exception as e:
      discard # Silently fail in WASM
  
  proc emCheckDropTarget(): int {.exportc: "emCheckDropTarget", cdecl, used.} =
    ## Check if current section has dropTarget: true in frontmatter
    ## Returns 1 if yes, 0 if no
    try:
      if storieCtx.isNil:
        return 0
      
      let section = storieCtx.sectionMgr.getCurrentSection()
      
      # Check if section has dropTarget in its metadata
      if section.metadata.hasKey("dropTarget"):
        if section.metadata["dropTarget"].toLowerAscii() in ["true", "yes", "1"]:
          return 1
      
      # Also check global frontmatter for dropTarget
      if storieCtx.frontMatter.hasKey("dropTarget"):
        if storieCtx.frontMatter["dropTarget"].toLowerAscii() in ["true", "yes", "1"]:
          return 1
      
      return 0
    except:
      return 0
  
  proc emHandleDroppedFile(filename: cstring, data: cstring, length: int) {.exportc: "emHandleDroppedFile", cdecl, used.} =
    ## Handle a dropped file - store data and trigger ondrop lifecycle
    try:
      if filename.isNil or data.isNil:
        return
      
      # Store dropped file data in globals
      gDroppedFileName = $filename
      gDroppedFileSize = length
      
      # Copy binary data safely - data is already a byte buffer
      gDroppedFileData = newString(length)
      for i in 0 ..< length:
        gDroppedFileData[i] = data[i]
      
      # Execute ondrop lifecycle hooks
      if not storieCtx.isNil and not storieCtx.niminiContext.isNil:
        for codeBlock in storieCtx.codeBlocks:
          if codeBlock.lifecycle == "ondrop":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
        
        # Also trigger render to show updated content
        for codeBlock in storieCtx.codeBlocks:
          if codeBlock.lifecycle == "render":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
    except:
      discard

proc showHelp() =
  echo "tstorie v" & version
  echo "Terminal-based interactive fiction engine"
  echo ""
  echo "Usage:"
  echo "  tstorie [OPTIONS] [FILE] [PARAMS...]"
  echo "  tstorie export [OPTIONS] <file.md>     # Export to native Nim"
  echo ""
  echo "Commands:"
  echo "  (default)             Run a tStorie markdown file"
  echo "  export                Export markdown to native Nim program"
  echo "                        Use 'tstorie export --help' for export options"
  echo ""
  echo "Arguments:"
  echo "  FILE                  Markdown file to run (default: index.md)"
  echo "  PARAMS                Custom parameters as key=value pairs"
  echo ""
  echo "Options:"
  echo "  -h, --help            Show this help message"
  echo "  -v, --version         Show version information"
  echo "  -c, --content <ref>   Load content from source (see Content Sources below)"
  echo "  --fps <num>           Set target FPS (default 60; Windows non-WT default 30)"
  echo "                        Can also use STORIE_TARGET_FPS env var"
  echo "  --<key>=<value>       Custom parameter (accessible via getParam/hasParam)"
  echo ""
  echo "Content Sources:"
  echo "  The --content option supports multiple sources:"
  echo "    gist:<ID>           - Load from GitHub Gist"
  echo "    demo:<name>         - Load from demos/ folder"
  echo "    file:<path>         - Load from file path"
  echo "    <URL>               - Full GitHub Gist URL"
  echo ""
  echo "Custom Parameters:"
  echo "  Scripts can access custom parameters using:"
  echo "    hasParam(\"name\")     - Check if parameter exists"
  echo "    getParam(\"name\")     - Get parameter as string"
  echo "    getParamInt(\"name\", default) - Get parameter as integer"
  echo ""
  echo "  Special parameters:"
  echo "    theme=<name>       - Override theme from front matter"
  echo "                         (e.g., theme=nord, theme=dracula)"
  echo ""
  echo "Examples:"
  echo "  tstorie                              # Run index.md"
  echo "  tstorie depths.md                    # Run depths.md"
  echo "  tstorie export myapp.md              # Export to native Nim"
  echo "  tstorie export myapp.md -c           # Export and compile"
  echo "  tstorie --content demo:clock         # Run clock demo"
  echo "  tstorie --content gist:abc123        # Run from GitHub Gist"
  echo "  tstorie examples/dungen.md seed=12345  # Run with seed parameter"
  echo "  tstorie examples/dungen.md --seed=12345  # Same using --option format"
  echo "  tstorie myfile.md theme=nord         # Override theme to nord"
  echo "  tstorie examples/canvas_demo.md      # Run a demo"
  echo ""
  echo "Web Usage (URL parameters):"
  echo "  https://example.com/?seed=12345      # Parameters passed via URL"
  echo "  https://example.com/?theme=dracula   # Override theme via URL"
  echo "  tstorie --fps 30 my_story.md         # Run with custom FPS"
  echo ""

proc main() =
  # Check for export subcommand first (before parsing any options)
  when not defined(emscripten):
    if paramCount() > 0 and paramStr(1) == "export":
      runExport()
      return
  
  var p = initOptParser()
  var cliFps: float = 0.0
  var mdFile: string = ""
  var contentRef: string = ""
  var customParams: seq[(string, string)] = @[]
  
  for kind, key, val in p.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h":
        showHelp()
        quit(0)
      of "version", "v":
        echo "storie version " & version
        quit(0)
      of "fps":
        if val.len == 0:
          echo "--fps requires a value (e.g., --fps 30)"
          quit(1)
        try:
          let f = parseFloat(val)
          if f <= 0:
            echo "--fps must be > 0"
            quit(1)
          cliFps = f
        except:
          echo "Invalid --fps value: " & val
          quit(1)
      of "content", "c":
        if val.len == 0:
          echo "--content requires a value (e.g., --content gist:abc123 or --content demo:clock)"
          quit(1)
        contentRef = val
      else:
        # Custom parameter (e.g., --seed=12345 or --width=100)
        if val.len > 0:
          customParams.add((key, val))
        else:
          echo "Unknown option: " & key
          echo "Use --help for usage information"
          quit(1)
    of cmdArgument:
      # First positional argument is the markdown file (unless content is specified)
      if mdFile.len == 0 and contentRef.len == 0:
        mdFile = key
      else:
        # Additional arguments as key=value pairs (e.g., seed=12345)
        let parts = key.split('=', maxsplit=1)
        if parts.len == 2:
          customParams.add((parts[0], parts[1]))
        else:
          echo "Only one markdown file can be specified"
          echo "Additional arguments should be key=value pairs (e.g., seed=12345)"
          echo "Use --help for usage information"
          quit(1)
    else: discard
  
  # Store custom parameters in nimini stdlib
  for (key, val) in customParams:
    setParam(key, val)
  
  # Load content from specified source
  if contentRef.len > 0:
    when not defined(emscripten):
      try:
        echo "Loading content from: ", contentRef
        let content = loadContentFromSource(contentRef)
        # Write to temp file
        let tmpFile = "/tmp/tstorie_content.md"
        writeFile(tmpFile, content)
        gMarkdownFile = tmpFile
        echo "Content loaded successfully"
      except Exception as e:
        echo "Error loading content: ", e.msg
        quit(1)
    else:
      echo "Content loading not supported in WASM mode"
      quit(1)
  elif mdFile.len > 0:
    gMarkdownFile = mdFile
  
  # Apply theme parameter if present (before loading markdown)
  if hasParamDirect("theme"):
    let themeName = getParamDirect("theme")
    if themeName.len > 0:
      # Will be applied when storieCtx is initialized
      discard  # Theme will be checked after markdown loads
  
  when defined(sdl3Backend):
    # SDL3 backend - pixel-based rendering
    echo "[main] Initializing SDL3 backend..."
    echo "[main] storieCtx before init: ", (if storieCtx.isNil: "NIL" else: "OK")
    
    # Create SDL canvas (global for emscripten main loop)
    when defined(emscripten):
      globalCanvas = newSDLCanvas(800, 600)
      if globalCanvas.isNil:
        echo "[main] ERROR: Failed to create SDL canvas"
        quit(1)
      echo "[main] SDL canvas created: ", globalCanvas.width, "x", globalCanvas.height
      
      # Initialize SDL3 input handler
      globalInputHandler = newSDL3InputHandler(addr globalCanvas, globalCanvas.cellWidth, globalCanvas.cellHeight)
      
      # Create application state
      var state = newAppState(globalCanvas.cellWidth, globalCanvas.cellHeight)
      state.targetFps = 60.0
      globalState = state
      gAppState = state  # Set global for runtime API functions
    else:
      let canvas = newSDLCanvas(800, 600)
      if canvas.isNil:
        echo "[main] ERROR: Failed to create SDL canvas"
        quit(1)
      echo "[main] SDL canvas created: ", canvas.width, "x", canvas.height
      
      var state = newAppState(canvas.cellWidth, canvas.cellHeight)
      state.targetFps = 60.0
      gAppState = state  # Set global for runtime API functions
    
    # Initialize plugins
    initLayerFxPlugin()
    
    # Set SDL3 canvas for runtime API functions
    when defined(emscripten):
      setSDL3Canvas(globalCanvas)
    else:
      setSDL3Canvas(canvas)
    
    # Initialize storie context (parses embedded markdown, sets up nimini, etc.)
    when defined(emscripten):
      echo "[main] Calling initStorieContext..."
      initStorieContext(globalState)
      echo "[main] storieCtx after init: ", (if storieCtx.isNil: "NIL" else: "OK")
      if not storieCtx.isNil:
        echo "[main] Number of code blocks: ", storieCtx.codeBlocks.len
    else:
      initStorieContext(state)
      echo "[main] storieCtx after init: ", (if storieCtx.isNil: "NIL" else: "OK")
    
    # Call setup lifecycle
    if not onInit.isNil:
      when defined(emscripten):
        onInit(globalState)
      else:
        onInit(state)
    
    echo "[main] Entering SDL3 main loop..."
    
    # Main loop (for native or Emscripten)
    when defined(emscripten):
      # Start the emscripten main loop (proc defined at top level)
      {.emit: """
        emscripten_set_main_loop(sdl3MainLoop, 0, 1);
      """.}
    else:
      # Native: Regular while loop
      var lastTime = epochTime()
      
      while state.running:
        let currentTime = epochTime()
        let deltaTime = currentTime - lastTime
        lastTime = currentTime
        
        # Poll events
        let events = canvas.pollEvents()
        for event in events:
          case event.kind
          of SDLQuit:
            state.running = false
            break
          of SDLResize:
            state.resizeState(canvas.cellWidth, canvas.cellHeight)
          else:
            discard
        
        if not state.running:
          break
        
        # Update FPS counter
        state.updateFpsCounter(deltaTime)
        
        # Call update lifecycle
        if not onUpdate.isNil:
          onUpdate(state, deltaTime)
        
        # Clear canvas
        canvas.clear((0'u8, 0'u8, 0'u8))
        
        # Call render
        if not onRender.isNil:
          onRender(state)
        
        # Composite layers onto canvas cells
        for layer in state.layers:
          if layer.visible:
            let buffer = layer.buffer
            for y in 0 ..< min(buffer.height, canvas.cellHeight):
              for x in 0 ..< min(buffer.width, canvas.cellWidth):
                let cell = buffer.getCell(x, y)
                canvas.writeCell(x, y, cell.ch, cell.style)
        
        # Convert cells to pixels and present
        canvas.renderCellsToPixels()
        canvas.present()
        
        # Frame timing
        if state.targetFps > 0.0:
          let frameTime = epochTime() - currentTime
          let targetFrameTime = 1.0 / state.targetFps
          let sleepTime = targetFrameTime - frameTime
          if sleepTime > 0:
            sleep(int(sleepTime * 1000))
      
      # Cleanup
      if not onShutdown.isNil:
        onShutdown(state)
      canvas.shutdown()
  
  elif not defined(emscripten):
    # Terminal backend - character-cell rendering  
    let (w, h) = getTermSize()
    var state = newAppState(w, h)
    state.colorSupport = detectColorSupport()
    
    when defined(windows):
      # If not Windows Terminal (WT_SESSION absent), lower default FPS for performance
      if getEnv("WT_SESSION").len == 0:
        state.targetFps = 30.0
    let fpsEnv = getEnv("STORIE_TARGET_FPS")
    if fpsEnv.len > 0:
      try:
        let envFps = parseFloat(fpsEnv)
        if envFps > 0:
          state.targetFps = envFps
      except:
        discard  # Ignore invalid values
    if cliFps > 0.0:
      state.targetFps = cliFps
    
    globalTerminalState = setupRawMode()
    hideCursor()
    enableMouseReporting()
    enableKeyboardProtocol()
    
    setupSignalHandlers(proc(sig: cint) {.noconv.} = globalRunning = false)
    
    # Initialize plugins before calling setup
    initLayerFxPlugin()
    
    callOnSetup(state)
    
    var lastTime = epochTime()
    
    try:
      while state.running and globalRunning:
        if not globalRunning:
          break
          
        let currentTime = epochTime()
        let deltaTime = currentTime - lastTime
        lastTime = currentTime
        
        # Process input events
        let events = getInputEvent(state)
        for event in events:
          if event.kind == ResizeEvent:
            state.resizeState(event.newWidth, event.newHeight)
            stdout.write("\e[2J\e[H")
            stdout.flushFile()
          else:
            discard callOnInput(state, event)
        
        # Check if mouse tracking should be re-enabled after Ctrl-Mousewheel
        checkMouseTrackingReenabled(state.inputParser)
        
        let (newW, newH) = getTermSize()
        if newW != state.termWidth or newH != state.termHeight:
          state.resizeState(newW, newH)
          stdout.write("\e[2J\e[H")
          stdout.flushFile()
        
        # Update FPS counter
        state.updateFpsCounter(deltaTime)
        
        callOnFrame(state, deltaTime)
        
        swap(state.currentBuffer, state.previousBuffer)
        callOnDraw(state)
        
        # Only composite layers if not showing dimension warning
        # (warning is rendered directly to currentBuffer)
        if not gShowingDimensionWarning:
          compositeLayers(state)
        
        state.currentBuffer.display(state.previousBuffer, state.colorSupport)
        
        if state.targetFps > 0.0:
          let frameTime = epochTime() - currentTime
          let targetFrameTime = 1.0 / state.targetFps
          let sleepTime = targetFrameTime - frameTime
          if sleepTime > 0:
            sleep(int(sleepTime * 1000))
        
        if not globalRunning:
          break
    finally:
      callOnShutdown(state)
      disableKeyboardProtocol()
      disableMouseReporting()
      showCursor()
      clearScreen()
      restoreTerminal(globalTerminalState)
      stdout.write("\n")
      stdout.flushFile()

when isMainModule:
  main()
# ================================================================
# EMSCRIPTEN EXPORTS (SDL3 Web)
# ================================================================

when defined(emscripten) and defined(sdl3Backend):
  import backends/sdl3/web_interop
  
  proc setMarkdownContent*(content: cstring) {.exportc.} =
    ## Load markdown content from JavaScript (matches old WASM build pattern)
    try:
      # Convert cstring to string safely
      if content.isNil:
        echo "[setMarkdownContent] ERROR: content is nil"
        return
      
      let contentStr = $content
      echo "[setMarkdownContent] Received ", contentStr.len, " bytes"
      
      # Ensure content is valid
      if contentStr.len == 0:
        echo "[setMarkdownContent] ERROR: content is empty"
        return
      
      # Parse the markdown document
      let doc = parseMarkdownDocument(contentStr)
      
      # Check if we got any blocks
      if doc.codeBlocks.len == 0:
        echo "[setMarkdownContent] WARNING: no code blocks parsed from ", contentStr.len, " bytes"
      
      # Update the storie context with new code blocks and sections
      if not storieCtx.isNil and not storieCtx.niminiContext.isNil:
        # Replace the code blocks and sections
        storieCtx.codeBlocks = doc.codeBlocks
        storieCtx.sectionMgr = newSectionManager(doc.sections)
        storieCtx.frontMatter = doc.frontMatter
        storieCtx.styleSheet = doc.styleSheet
        storieCtx.embeddedContent = doc.embeddedContent
        
        # Register WGSL shaders for nimini access
        registerWGSLShaders(doc.wgslShaders)
        
        # Also update globalState styleSheet for API access
        globalState.styleSheet = doc.styleSheet
        
        # Expose front matter variables to Nimini environment
        exposeFrontMatterVariables()
        
        # Apply front matter settings for font (SDL3-specific)
        when defined(emscripten):
          # Load custom font if specified in front matter
          if storieCtx.frontMatter.hasKey("font"):
            let fontName = storieCtx.frontMatter["font"]
            if fontName.len > 0:
              echo "[setMarkdownContent] Loading font from front matter: ", fontName
              loadFontFromFrontMatter(fontName)
        
        # Execute init blocks
        for codeBlock in storieCtx.codeBlocks:
          if codeBlock.lifecycle == "init":
            discard executeCodeBlock(storieCtx.niminiContext, codeBlock, globalState)
        
        echo "[setMarkdownContent] Content loaded successfully"
      else:
        echo "[setMarkdownContent] ERROR: storieCtx or niminiContext is nil"
    except Exception as e:
      echo "[setMarkdownContent] ERROR: ", e.msg
