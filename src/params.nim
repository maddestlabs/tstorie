## TStorie Parameters Module
## Unified parameter handling for both command-line args and URL parameters
## 
## On native builds: Parameters come from command-line args (parsed in main)
## On WASM builds: Parameters come from URL query string (parsed in JavaScript)
## 
## Both use the same storage mechanism (runtime env variables with _param_ prefix)

import ../nimini/runtime
import std/[tables, strutils]

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
  ## Called by host application (CLI parser or URL parser)
  if not runtimeEnv.isNil:
    defineVar(runtimeEnv, "_param_" & name, valString(value))
  else:
    # Runtime not initialized yet, store for later
    gPendingParams[name] = value

proc getParamDirect*(name: string): string =
  ## Get parameter value directly (used by host application)
  ## Checks pending params first, then runtime env
  if gPendingParams.hasKey(name):
    return gPendingParams[name]
  
  if not runtimeEnv.isNil:
    let paramVar = "_param_" & name
    if hasVarSafe(runtimeEnv, paramVar):
      let val = getVar(runtimeEnv, paramVar)
      if val.kind == vkString:
        return val.s
  
  return ""

proc hasParamDirect*(name: string): bool =
  ## Check if parameter exists directly (used by host application)
  if gPendingParams.hasKey(name):
    return true
  
  if not runtimeEnv.isNil:
    let paramVar = "_param_" & name
    return hasVarSafe(runtimeEnv, paramVar)
  
  return false

when defined(emscripten):
  proc emscripten_setParam_internal(namePtr: cstring, valuePtr: cstring) {.exportc.} =
    ## Internal function called from JavaScript to set a parameter
    let name = $namePtr
    let value = $valuePtr
    setParam(name, value)
  
  proc parseUrlParams*() =
    ## Parse URL query string and store as parameters
    ## This is a no-op in Nim - the actual parsing happens in JavaScript
    ## The JavaScript calls emscripten_setParam_internal for each param
    discard

proc flushPendingParams*() =
  ## Move pending params to runtime environment after it's initialized
  if not runtimeEnv.isNil and gPendingParams.len > 0:
    for name, value in gPendingParams:
      defineVar(runtimeEnv, "_param_" & name, valString(value))

proc clearParams*() =
  ## Clear all parameters
  gPendingParams.clear()

# ================================================================
# Nimini Script Functions (called from user scripts)
# ================================================================

proc nimini_getParam*(env: ref Env; args: seq[Value]): Value =
  ## getParam(name: string): string
  ## Returns URL parameter or command-line argument value
  ## Returns empty string if not found
  if args.len < 1:
    return valString("")
  
  let name = args[0].s
  let paramVar = "_param_" & name
  
  # Check runtime environment (unified for all platforms)
  if hasVarSafe(env, paramVar):
    let value = getVar(env, paramVar)
    if value.kind == vkString:
      return value
  
  return valString("")

proc nimini_hasParam*(env: ref Env; args: seq[Value]): Value =
  ## hasParam(name: string): bool
  ## Check if parameter exists
  if args.len < 1:
    return valBool(false)
  
  let name = args[0].s
  let paramVar = "_param_" & name
  
  # Check runtime environment (unified for all platforms)
  return valBool(hasVarSafe(env, paramVar))

proc nimini_getParamInt*(env: ref Env; args: seq[Value]): Value =
  ## getParamInt(name: string, default: int): int
  ## Returns parameter as integer, or default if not found or invalid
  if args.len < 2:
    return valInt(0)
  
  let name = args[0].s
  let defaultVal = toInt(args[1])
  let paramVar = "_param_" & name
  
  # Check runtime environment (unified for all platforms)
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
