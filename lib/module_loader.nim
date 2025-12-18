## Module Loader - Runtime loading of Nim modules from gists or local files
##
## Allows users to import .nim files at runtime using require()
## Supports both GitHub gists and local file paths
##
## Usage:
##   let canvas = requireModule("gist:abc123/canvas.nim", state)
##   let utils = requireModule("lib/utils.nim", state)

import std/[tables, strutils, os]
import ../nimini

when not defined(emscripten):
  import std/httpclient

type
  ModuleCache* = ref object
    modules*: Table[string, ref Env]  # moduleRef -> compiled runtime
    sourceCode*: Table[string, string]   # moduleRef -> source code
    
var globalModuleCache* = ModuleCache(
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
