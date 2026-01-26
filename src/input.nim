## Unified Input System for tStorie
##
## This module provides a single, consistent API for input handling across
## all backends (terminal, WASM, SDL3).
##
## Usage:
##   import input
##   
##   var parser = newInputParser()
##   
##   while running:
##     let events = parser.pollInput()
##     for event in events:
##       # Handle event
##
## The backend is automatically selected based on compile flags.

# Export shared types
import input/types
export types

# Select backend based on compile flags
when defined(emscripten) and defined(sdl3Backend):
  # SDL3 + Emscripten (web build with SDL3)
  import input/sdl3input
  export sdl3input
  
  type InputParser* = SDL3InputHandler
  
  # Forward declaration for SDLCanvas (actual type defined in backends/sdl3/sdl_canvas.nim)
  proc newInputParser*(canvas: pointer, cellWidth, cellHeight: int): InputParser =
    ## Create a new input parser (SDL3 backend)
    ## canvas is a pointer to avoid circular dependency
    result = newSDL3InputHandler(canvas, cellWidth, cellHeight)

elif defined(emscripten):
  # Pure WASM backend (legacy web build)
  import input/wasminput
  export wasminput
  
  type InputParser* = WasmInputHandler
  
  proc newInputParser*(): InputParser =
    ## Create a new input parser (WASM backend)
    result = newWasmInputHandler()
    
else:
  # Native terminal backend
  import input/terminput
  export terminput
  
  type InputParser* = TerminalInputParser
  
  proc newInputParser*(): InputParser =
    ## Create a new input parser (Terminal backend)
    result = newTerminalInputParser()
