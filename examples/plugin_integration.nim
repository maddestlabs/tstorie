# Example integration into tstorie.nim
# Shows how to add plugin-based compression support

import std/[os, strutils]
when not defined(emscripten):
  import lib/plugin_loader
  import lib/cmdline_compression

# Add to your main() or command-line processing section:

proc handleCompressionFeatures(): bool =
  ## Handle any compression-dependent command-line features
  ## Returns true if a feature was handled (exits after)
  when not defined(emscripten):
    return processCommandLine()
  else:
    return false

# In your main entry point:
proc main() =
  # Check for compression-dependent features FIRST
  # before starting the full application
  when not defined(emscripten):
    if handleCompressionFeatures():
      # Feature was handled, exit
      return
  
  # Continue with normal tStorie initialization...
  echo "Starting tStorie..."
  # ... rest of your code

# Example usage patterns:

# 1. Decode a data URL from command line
proc exampleDecodeUrl() =
  # User runs: ./tstorie --decode "eJwLycxNtUq..."
  # Or: ./tstorie decode:eJwLycxNtUq...
  when not defined(emscripten):
    if not isPluginAvailable():
      echo "Compression plugin not found"
      showPluginHelp()
      return
    
    let compressed = "eJwLycxNtUq..."
    let decompressed = decompressString(compressed)
    if decompressed.len > 0:
      echo "Content: ", decompressed

# 2. Load PNG workflow from command line
proc exampleLoadPng() =
  # User runs: ./tstorie --png-workflow my-workflow.png
  # Or: ./tstorie my-workflow.png
  when not defined(emscripten):
    if not isPluginAvailable():
      echo "Compression plugin required for PNG workflows"
      showPluginHelp()
      return
    
    # Load PNG, extract tEXt chunk, decompress...

# 3. Check plugin status
proc examplePluginInfo() =
  # User runs: ./tstorie --plugin-info
  when not defined(emscripten):
    if isPluginAvailable():
      echo "Plugin location: ", getPluginPath()
      let plugin = loadCompressionPlugin()
      if plugin != nil:
        echo "Plugin version: ", $plugin.getVersion()
        unloadCompressionPlugin()
    else:
      showPluginHelp()

# 4. Optional: Compress/decompress in runtime if plugin available
proc optionalCompression(data: string): string =
  ## Try to compress data, fallback to uncompressed
  when not defined(emscripten):
    if isPluginAvailable():
      let compressed = compressString(data)
      if compressed.len > 0:
        return compressed
  # Fallback: return uncompressed
  return data

# Key advantages of this approach:
# 
# 1. Main binary size stays small (no compression code)
# 2. Compression is optional (plugin not required)
# 3. Easy to update plugin independently
# 4. Clear error messages if plugin missing
# 5. Plugin can use any compression library without affecting main binary
# 6. Works with native builds, not needed for WASM (browser has compression)

when isMainModule:
  main()
