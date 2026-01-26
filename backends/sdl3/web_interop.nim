## SDL3 Web Interop - Minimal JS bridge for web-specific features
## 
## This module provides ONLY the web-specific functionality that SDL3 doesn't handle:
## - URL parameter parsing
## - Gist content loading
## - Console logging
##
## Everything else (rendering, input, events) is handled by SDL3 directly.

import std/strutils

when not defined(emscripten):
  {.error: "web_interop.nim requires -d:emscripten".}

# Forward declarations for Emscripten functions
proc emscripten_run_script*(script: cstring) {.importc, header: "<emscripten.h>".}
proc emscripten_run_script_string*(script: cstring): cstring {.importc, header: "<emscripten.h>".}

proc consoleLog*(msg: cstring) =
  ## Log message to browser console using Emscripten
  var script = "console.log('[tStorie] " & $msg & "');"
  emscripten_run_script(script.cstring)

proc getUrlParam*(key: cstring): cstring =
  ## Get a URL parameter value by key
  var script = "(new URLSearchParams(window.location.search)).get('" & $key & "') || '';"
  result = emscripten_run_script_string(script.cstring)

proc hasUrlParam*(key: cstring): bool =
  ## Check if a URL parameter exists
  var script = "(new URLSearchParams(window.location.search)).has('" & $key & "') ? '1' : '0';"
  var res = emscripten_run_script_string(script.cstring)
  result = ($res) == "1"

proc parseUrlParams*(): seq[(string, string)] =
  ## Parse all URL parameters from the browser location
  ## Returns a sequence of (key, value) tuples
  result = @[]
  
  # Get number of params
  let countScript = "(new URLSearchParams(window.location.search)).toString().split('&').filter(x => x).length.toString();"
  let countStr = $emscripten_run_script_string(countScript.cstring)
  var count = 0
  try:
    count = parseInt(countStr)
  except:
    return result
  
  if count == 0:
    return result
  
  # Get param keys
  let keysScript = "Array.from(new URLSearchParams(window.location.search).keys()).join('|');"
  let keysStr = $emscripten_run_script_string(keysScript.cstring)
  
  if keysStr.len > 0:
    for key in keysStr.split('|'):
      if key.len > 0:
        let val = $getUrlParam(key.cstring)
        result.add((key, val))

proc loadGistContent*(gistId: string): string =
  ## Load gist content from GitHub (simplified version)
  ## In a real implementation, this would use XMLHttpRequest
  ## For now, returns empty string (gist loading not critical for initial testing)
  consoleLog(("[Web] Gist loading not yet implemented: " & gistId).cstring)
  result = ""

when isMainModule:
  # Test the web interop functions
  consoleLog("Web interop module loaded".cstring)
  
  let params = parseUrlParams()
  consoleLog(("Found " & $params.len & " URL parameters").cstring)
  
  for (key, val) in params:
    consoleLog(("  " & key & " = " & val).cstring)
