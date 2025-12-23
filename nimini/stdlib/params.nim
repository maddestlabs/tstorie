## Nimini Standard Library - Parameters
## Provides access to command-line arguments and URL parameters

import ../runtime
import std/[tables, strutils]

# Store params as global variables in the nimini runtime environment
# This ensures they're accessible from nimini scripts

# Temporary storage for params set before runtime is initialized
var gPendingParams = initTable[string, string]()

proc hasVarSafe(env: ref Env; name: string): bool =
  ## Check if a variable exists in the environment without throwing
  var e = env
  while e != nil:
    if name in e.vars:
      return true
    e = e.parent
  return false

proc setParam*(name: string, value: string) =
  ## Set a parameter value as a global variable in the runtime
  ## Called by host application
  if not runtimeEnv.isNil:
    defineVar(runtimeEnv, "_param_" & name, valString(value))
    defineVar(runtimeEnv, "_debug_setparam", valString("direct:" & name & "=" & value))
  else:
    # Runtime not initialized yet, store for later
    gPendingParams[name] = value

proc getPendingCount*(): int =
  ## Debug: Get count of pending params
  return gPendingParams.len

proc flushPendingParams*() =
  ## Move pending params to runtime environment after it's initialized
  ## Note: Does not clear pending params, so they can be re-flushed if needed
  when defined(emscripten):
    if gPendingParams.len > 0 and not runtimeEnv.isNil:
      # Store count in a global var that we can check
      for name, value in gPendingParams:
        defineVar(runtimeEnv, "_param_" & name, valString(value))
        defineVar(runtimeEnv, "_debug_flushed", valString("yes:" & $gPendingParams.len))
    else:
      if not runtimeEnv.isNil:
        defineVar(runtimeEnv, "_debug_flushed", valString("no_params:" & $gPendingParams.len))
  else:
    if not runtimeEnv.isNil and gPendingParams.len > 0:
      for name, value in gPendingParams:
        defineVar(runtimeEnv, "_param_" & name, valString(value))

proc clearParams*() =
  ## Clear all parameters (no-op now since we use runtime env)
  discard

proc niminiGetParam*(env: ref Env; args: seq[Value]): Value =
  ## getParam(name: string): string
  ## Returns URL parameter or command-line argument value
  ## Returns empty string if not found
  if args.len < 1:
    return valString("")
  
  let name = args[0].s
  
  when defined(emscripten):
    # In WASM, call JavaScript to retrieve URL params
    {.emit: """
    extern char* jsGetUrlParam(const char* name);
    """.}
    proc jsGetUrlParam(name: cstring): cstring {.importc, nodecl.}
    let value = $jsGetUrlParam(name.cstring)
    return valString(value)
  else:
    # In native builds, check runtime environment
    let paramVar = "_param_" & name
    
    # Check if parameter exists before trying to get it
    if hasVarSafe(env, paramVar):
      let value = getVar(env, paramVar)
      if value.kind == vkString:
        return value
    
    return valString("")

proc niminiHasParam*(env: ref Env; args: seq[Value]): Value =
  ## hasParam(name: string): bool
  ## Check if parameter exists
  if args.len < 1:
    return valBool(false)
  
  let name = args[0].s
  
  when defined(emscripten):
    # In WASM, call JavaScript to check URL params
    {.emit: """
    extern char* jsGetUrlParam(const char* name);
    """.}
    proc jsGetUrlParam(name: cstring): cstring {.importc, nodecl.}
    let value = $jsGetUrlParam(name.cstring)
    return valBool(value.len > 0)
  else:
    # In native builds, check runtime environment
    let paramVar = "_param_" & name
    return valBool(hasVarSafe(env, paramVar))

proc niminiGetParamInt*(env: ref Env; args: seq[Value]): Value =
  ## getParamInt(name: string, default: int): int
  ## Returns parameter as integer, or default if not found or invalid
  if args.len < 2:
    return valInt(0)
  
  let name = args[0].s
  let defaultVal = toInt(args[1])
  
  when defined(emscripten):
    # In WASM, call JavaScript to retrieve URL params
    {.emit: """
    extern char* jsGetUrlParam(const char* name);
    """.}
    proc jsGetUrlParam(name: cstring): cstring {.importc, nodecl.}
    let value = $jsGetUrlParam(name.cstring)
    if value.len > 0:
      try:
        return valInt(parseInt(value))
      except:
        return valInt(defaultVal)
    else:
      return valInt(defaultVal)
  else:
    # In native builds, check runtime environment
    let paramVar = "_param_" & name
    
    # Check if parameter exists before trying to get it
    if hasVarSafe(env, paramVar):
      let value = getVar(env, paramVar)
      if value.kind == vkString:
        try:
          return valInt(parseInt(value.s))
        except:
          return valInt(defaultVal)
    
    return valInt(defaultVal)

proc registerParamFuncs*(env: ref Env) =
  ## Register parameter functions in nimini environment
  registerNative("getParam", niminiGetParam)
  registerNative("hasParam", niminiHasParam)
  registerNative("getParamInt", niminiGetParamInt)
