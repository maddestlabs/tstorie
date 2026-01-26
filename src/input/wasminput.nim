## WASM Input Backend for tStorie
##
## Minimal shim for WASM builds - actual event handling is done by JavaScript.
## This module provides the same API as terminput.nim for consistency.

import types
export types

# WASM input events come through JavaScript callbacks into runtime_api.nim
# This module exists for API consistency but doesn't implement parsing

type
  WasmInputHandler* = object
    ## Placeholder type for WASM input handling
    discard

proc newWasmInputHandler*(): WasmInputHandler =
  ## Create a new WASM input handler
  result = WasmInputHandler()

proc pollInput*(handler: var WasmInputHandler): seq[InputEvent] =
  ## WASM polling is handled by JavaScript event callbacks
  ## This function always returns empty in WASM builds
  return @[]
