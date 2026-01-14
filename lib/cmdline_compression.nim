# Command-line handler for data URLs and PNG workflows
# Only loads compression plugin when needed

import std/[os, strutils, parseopt]
import plugin_loader

proc handleDataUrl*(url: string): bool =
  ## Handle data URL from command line
  ## Returns true if successfully processed
  
  # Check if it's a data URL
  if not url.startsWith("decode:"):
    return false
  
  # Extract compressed data
  let compressedData = url[7..^1]  # Skip "decode:"
  
  # Check if compression plugin is available
  if not isPluginAvailable():
    echo "\nError: Compression plugin required to decode data URLs"
    echo "======================================================\n"
    showPluginHelp()
    return false
  
  # Decompress the data
  echo "Decompressing data URL..."
  let decompressed = decompressString(compressedData)
  
  if decompressed.len == 0:
    echo "Error: Failed to decompress data"
    return false
  
  echo "Successfully decompressed ", decompressed.len, " bytes"
  echo "\n--- Content ---"
  echo decompressed
  echo "--- End Content ---\n"
  
  return true

proc handlePngWorkflow*(pngPath: string): bool =
  ## Handle PNG workflow from command line
  ## Returns true if successfully processed
  
  if not fileExists(pngPath):
    echo "Error: File not found: ", pngPath
    return false
  
  if not pngPath.toLowerAscii().endsWith(".png"):
    return false  # Not a PNG file
  
  echo "PNG workflow extraction not yet implemented"
  echo "This would require:"
  echo "  1. PNG chunk parsing (can be in plugin or main binary)"
  echo "  2. Decompression plugin for workflow data"
  
  if not isPluginAvailable():
    echo "\nNote: Compression plugin would be required"
    showPluginHelp()
  
  return false

proc processCommandLine*(): bool =
  ## Process command-line arguments for compression-dependent features
  ## Returns true if a compression feature was invoked (whether successful or not)
  
  var p = initOptParser()
  var foundCompressionFeature = false
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "decode", "d":
        foundCompressionFeature = true
        if p.val.len > 0:
          discard handleDataUrl("decode:" & p.val)
        else:
          echo "Error: --decode requires a value"
      of "png-workflow", "png":
        foundCompressionFeature = true
        if p.val.len > 0:
          discard handlePngWorkflow(p.val)
        else:
          echo "Error: --png-workflow requires a file path"
      of "plugin-info":
        foundCompressionFeature = true
        if isPluginAvailable():
          echo "Compression plugin: AVAILABLE"
          echo "Location: ", getPluginPath()
          let plugin = loadCompressionPlugin()
          if plugin != nil:
            echo "Version: ", $plugin.getVersion()
            unloadCompressionPlugin()
        else:
          echo "Compression plugin: NOT AVAILABLE"
          showPluginHelp()
      else:
        discard
    of cmdArgument:
      # Check if it's a data URL
      if p.key.startsWith("decode:"):
        foundCompressionFeature = true
        discard handleDataUrl(p.key)
      # Check if it's a PNG file
      elif p.key.toLowerAscii().endsWith(".png"):
        foundCompressionFeature = true
        discard handlePngWorkflow(p.key)
  
  return foundCompressionFeature

when isMainModule:
  # Test command-line processing
  if processCommandLine():
    echo "Processed compression-dependent feature"
  else:
    echo "No compression features invoked"
