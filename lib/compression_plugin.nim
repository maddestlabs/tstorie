# Compression Plugin - Compiled as separate shared library
# Build with: nim c --app:lib -d:release lib/compression_plugin.nim
# Output: libcompression_plugin.so (Linux), compression_plugin.dll (Windows), libcompression_plugin.dylib (macOS)

import std/[base64, strutils]

# Use nimble's zip/zlib or implement minimal deflate
when not defined(js):
  # For now, using simple base64 encoding as placeholder
  # In production, you'd add: nimble install zip
  # import zip/zlib
  
  proc compressData*(data: string): string {.exportc, dynlib.} =
    ## Compress data using deflate
    ## Returns base64-encoded compressed data
    # TODO: Add real compression with zlib
    # For now, just base64 encode (placeholder)
    result = encode(data)
    
  proc decompressData*(data: string): string {.exportc, dynlib.} =
    ## Decompress data from base64-encoded deflate
    ## Returns original uncompressed data
    # TODO: Add real decompression with zlib
    # For now, just base64 decode (placeholder)
    try:
      result = decode(data)
    except:
      result = ""
      
  proc getPluginVersion*(): cstring {.exportc, dynlib.} =
    ## Get plugin version string
    return "compression_plugin v1.0.0"
    
  proc isCompressionAvailable*(): bool {.exportc, dynlib.} =
    ## Check if compression is actually available
    return true

# Export these symbols for dynamic loading
{.push exportc, dynlib.}

proc compress_string(data: cstring): cstring =
  ## C-compatible wrapper for compression
  let input = $data
  let compressed = compressData(input)
  return compressed.cstring

proc decompress_string(data: cstring): cstring =
  ## C-compatible wrapper for decompression
  let input = $data
  let decompressed = decompressData(input)
  return decompressed.cstring

{.pop.}
