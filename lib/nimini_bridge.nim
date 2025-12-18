## Nimini Bridge - Expose tstorie APIs to interpreted Nim modules
##
## This module provides the glue between tstorie's native functionality
## and nimini's interpreted environment, allowing loaded modules to:
## - Draw to layers
## - Handle input events
## - Access application state
## - Create/manage UI elements

import std/[tables, strutils]
import ../nimini

# Forward declare types to avoid circular dependency
# These will be provided at runtime from tstorie
type
  AppStateObj = object  # Placeholder - actual type from tstorie
  
# We store the global state ref here to avoid circular imports
var globalAppStateRef: pointer = nil

proc setGlobalAppState*(state: pointer) =
  ## Called by tstorie to set the app state reference
  globalAppStateRef = state

proc registerTstorieApis*(env: ref Env, state: pointer) =
  ## Register all tstorie API functions in the nimini environment
  ## This makes them available to interpreted modules
  ## state is a pointer to AppState to avoid circular dependency
  
  # Store state for later use
  setGlobalAppState(state)
  
  # ============================================================================
  # Drawing APIs
  # ============================================================================
  
  # Note: These will call back into tstorie via proc pointers
  # For now, provide placeholder implementations
  env.vars["write"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## write(x: int, y: int, text: string)
    if args.len < 3:
      raise newException(ValueError, "write() requires at least 3 arguments: x, y, text")
    
    echo "write(", args[0].i, ", ", args[1].i, ", ", args[2].s, ")"
    return valNil()
  
  env.vars["writeText"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## writeText(x: int, y: int, text: string)
    if args.len < 3:
      raise newException(ValueError, "writeText() requires at least 3 arguments")
    
    echo "writeText(", args[0].i, ", ", args[1].i, ", ", args[2].s, ")"
    return valNil()
  
  env.vars["fillRect"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## fillRect(x: int, y: int, w: int, h: int, ch: string)
    if args.len < 5:
      raise newException(ValueError, "fillRect() requires at least 5 arguments")
    
    echo "fillRect(", args[0].i, ", ", args[1].i, ", ", args[2].i, ", ", args[3].i, ", ", args[4].s, ")"
    return valNil()
  
  # ============================================================================
  # Layer Management
  # ============================================================================
  
  env.vars["createLayer"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## createLayer(id: string, z: int)
    if args.len < 2:
      raise newException(ValueError, "createLayer() requires 2 arguments: id, z")
    
    echo "createLayer(", args[0].s, ", ", args[1].i, ")"
    return valNil()
  
  env.vars["getLayer"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getLayer(id: string) -> map with layer info
    if args.len < 1:
      raise newException(ValueError, "getLayer() requires 1 argument: id")
    
    # Return nil for now - will be implemented with real tstorie integration
    return valNil()
  
  env.vars["removeLayer"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## removeLayer(id: string)
    if args.len < 1:
      raise newException(ValueError, "removeLayer() requires 1 argument: id")
    
    echo "removeLayer(", args[0].s, ")"
    return valNil()
  
  # ============================================================================
  # Color Utilities
  # ============================================================================
  
  env.vars["rgb"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## rgb(r: int, g: int, b: int) -> color map
    if args.len < 3:
      raise newException(ValueError, "rgb() requires 3 arguments: r, g, b")
    
    let colorMap = valMap()
    colorMap.map["r"] = valInt(args[0].i)
    colorMap.map["g"] = valInt(args[1].i)
    colorMap.map["b"] = valInt(args[2].i)
    return colorMap
  
  proc makeColorMap(r, g, b: int): Value =
    let m = valMap()
    m.map["r"] = valInt(r)
    m.map["g"] = valInt(g)
    m.map["b"] = valInt(b)
    return m
  
  env.vars["black"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 0, 0)
  
  env.vars["white"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(255, 255, 255)
  
  env.vars["red"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(255, 0, 0)
  
  env.vars["green"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 255, 0)
  
  env.vars["blue"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    return makeColorMap(0, 0, 255)
  
  # ============================================================================
  # Input Handling
  # ============================================================================
  
  env.vars["getInput"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getInput() -> array of input events
    # Return empty array for now
    return valArray()
  
  # ============================================================================
  # State Access
  # ============================================================================
  
  env.vars["getWidth"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getWidth() -> int
    return valInt(80)  # Default size
  
  env.vars["getHeight"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getHeight() -> int
    return valInt(24)  # Default size
  
  env.vars["getDeltaTime"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## getDeltaTime() -> float
    return valFloat(0.016)  # ~60 FPS
  
  # ============================================================================
  # Utility Functions
  # ============================================================================
  
  env.vars["echo"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## echo(...) - print to console/stdout
    var output = ""
    for i, arg in args:
      if i > 0: output.add(" ")
      output.add($arg)
    echo output
    return valNil()
  
  env.vars["len"] = valNativeFunc proc(e: ref Env, args: seq[Value]): Value =
    ## len(array or string) -> int
    if args.len < 1:
      raise newException(ValueError, "len() requires 1 argument")
    
    case args[0].kind
    of vkArray:
      return valInt(args[0].arr.len)
    of vkString:
      return valInt(args[0].s.len)
    else:
      raise newException(ValueError, "len() requires array or string")
