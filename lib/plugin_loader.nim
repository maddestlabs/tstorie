# Dynamic Plugin Loader for tStorie
# Loads compression plugin only when needed

import std/[dynlib, os, strutils]

type
  CompressionPlugin* = ref object
    handle: LibHandle
    compress*: proc(data: cstring): cstring {.cdecl.}
    decompress*: proc(data: cstring): cstring {.cdecl.}
    getVersion*: proc(): cstring {.cdecl.}
    isAvailable*: proc(): bool {.cdecl.}

var globalPlugin: CompressionPlugin = nil

proc getPluginPath*(): string =
  ## Get expected path to compression plugin library
  when defined(windows):
    result = "compression_plugin.dll"
  elif defined(macosx):
    result = "libcompression_plugin.dylib"
  else:
    result = "libcompression_plugin.so"
  
  # Check in multiple locations
  let locations = [
    result,  # Current directory
    "lib" / result,  # lib subdirectory
    getAppDir() / result,  # Same dir as executable
    getAppDir() / "lib" / result,  # lib next to executable
  ]
  
  for loc in locations:
    if fileExists(loc):
      return loc
  
  return result  # Return default if not found

proc isPluginAvailable*(): bool =
  ## Check if compression plugin exists
  fileExists(getPluginPath())

proc loadCompressionPlugin*(): CompressionPlugin =
  ## Load the compression plugin dynamically
  ## Returns nil if plugin not found or failed to load
  
  if globalPlugin != nil:
    return globalPlugin  # Already loaded
  
  let pluginPath = getPluginPath()
  
  if not fileExists(pluginPath):
    echo "Compression plugin not found: ", pluginPath
    return nil
  
  # Use absolute path for loading
  let absPath = if pluginPath.isAbsolute(): pluginPath else: getCurrentDir() / pluginPath
  
  let handle = loadLib(absPath)
  if handle == nil:
    echo "Failed to load compression plugin: ", pluginPath
    return nil
  
  var plugin = CompressionPlugin(handle: handle)
  
  # Load function pointers
  plugin.compress = cast[proc(data: cstring): cstring {.cdecl.}](
    symAddr(handle, "compress_string")
  )
  plugin.decompress = cast[proc(data: cstring): cstring {.cdecl.}](
    symAddr(handle, "decompress_string")
  )
  plugin.getVersion = cast[proc(): cstring {.cdecl.}](
    symAddr(handle, "getPluginVersion")
  )
  plugin.isAvailable = cast[proc(): bool {.cdecl.}](
    symAddr(handle, "isCompressionAvailable")
  )
  
  if plugin.compress == nil or plugin.decompress == nil:
    echo "Failed to load required symbols from plugin"
    unloadLib(handle)
    return nil
  
  echo "Loaded compression plugin: ", $plugin.getVersion()
  globalPlugin = plugin
  return plugin

proc unloadCompressionPlugin*() =
  ## Unload the compression plugin
  if globalPlugin != nil and globalPlugin.handle != nil:
    unloadLib(globalPlugin.handle)
    globalPlugin = nil

proc compressString*(data: string): string =
  ## Compress string using plugin
  ## Returns empty string if plugin not available
  let plugin = loadCompressionPlugin()
  if plugin == nil:
    return ""
  
  let compressed = plugin.compress(data.cstring)
  if compressed == nil:
    return ""
  
  return $compressed

proc decompressString*(data: string): string =
  ## Decompress string using plugin
  ## Returns empty string if plugin not available or decompression fails
  let plugin = loadCompressionPlugin()
  if plugin == nil:
    return ""
  
  let decompressed = plugin.decompress(data.cstring)
  if decompressed == nil:
    return ""
  
  return $decompressed

proc showPluginHelp*() =
  ## Show help message about compression plugin
  echo """
Compression Plugin Required
----------------------------
This feature requires the compression plugin, which is not currently loaded.

To build the compression plugin:
  nim c --app:lib -d:release lib/compression_plugin.nim

This will create:
  - libcompression_plugin.so (Linux)
  - compression_plugin.dll (Windows)
  - libcompression_plugin.dylib (macOS)

Place the library file in one of these locations:
  - Same directory as tstorie executable
  - ./lib/ subdirectory
  - Current working directory

Then run tstorie again with your data URL or PNG workflow.
"""

# Export for use in main tstorie binary
when isMainModule:
  # Test the plugin loader
  if isPluginAvailable():
    echo "Plugin found: ", getPluginPath()
    
    let plugin = loadCompressionPlugin()
    if plugin != nil:
      echo "Plugin loaded successfully!"
      echo "Version: ", $plugin.getVersion()
      
      # Test compression/decompression
      let original = "Hello, tStorie!"
      let compressed = compressString(original)
      let decompressed = decompressString(compressed)
      
      echo "Original: ", original
      echo "Compressed: ", compressed
      echo "Decompressed: ", decompressed
      echo "Match: ", decompressed == original
      
      unloadCompressionPlugin()
    else:
      echo "Failed to load plugin"
  else:
    echo "Plugin not available"
    showPluginHelp()
