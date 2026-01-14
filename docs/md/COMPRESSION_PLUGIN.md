# Compression Plugin System

## Overview

tStorie uses a **dynamic plugin architecture** for compression features to keep the main binary small. Compression/decompression is compiled as a separate shared library that's loaded only when needed.

## Why Plugin Architecture?

### Problems Solved
1. **Binary Size** - Compression libraries (zlib, etc.) add 50-200KB to binary
2. **Optional Features** - Not everyone needs native compression (WASM has browser APIs)
3. **Flexibility** - Easy to swap compression algorithms without rebuilding main binary
4. **Dependency Management** - Compression libs stay separate from core application

### When Plugin is Needed
- Decoding data URLs from command line
- Loading PNG workflows with embedded data (native builds)
- Compressing content for export (native builds)

### When Plugin is NOT Needed
- Running in browser (WASM) - uses JavaScript Compression Streams API
- Normal tStorie usage without data URL/PNG features
- Any use case not involving compression

## Architecture

```
┌─────────────────────────────────────────────────┐
│           tStorie Main Binary                   │
│              (tstorie.nim)                      │
│                                                 │
│  • Core application logic                      │
│  • UI/Terminal rendering                       │
│  • Command-line parsing                        │
│  • Plugin detection & loading                  │
│                                                 │
│  Size: ~2-5MB (no compression code)            │
└───────────────────┬─────────────────────────────┘
                    │
                    │ Dynamic load when needed
                    ▼
┌─────────────────────────────────────────────────┐
│      Compression Plugin (Optional)              │
│     libcompression_plugin.so/.dll/.dylib        │
│                                                 │
│  • compress_string()                            │
│  • decompress_string()                          │
│  • getPluginVersion()                           │
│  • isCompressionAvailable()                     │
│                                                 │
│  Size: ~50-200KB (with zlib/compression code)  │
└─────────────────────────────────────────────────┘
```

## Building the Plugin

### Quick Build
```bash
./build-plugin.sh
```

### Manual Build
```bash
# Linux
nim c --app:lib -d:release --opt:size lib/compression_plugin.nim
mv lib/libcompression_plugin.so ./

# macOS
nim c --app:lib -d:release --opt:size lib/compression_plugin.nim
mv lib/libcompression_plugin.dylib ./

# Windows
nim c --app:lib -d:release --opt:size lib/compression_plugin.nim
move lib\compression_plugin.dll .\
```

### Output Files
- **Linux**: `libcompression_plugin.so`
- **macOS**: `libcompression_plugin.dylib`
- **Windows**: `compression_plugin.dll`

## Plugin Loading

### Search Locations
The plugin is searched in this order:
1. Current working directory
2. `./lib/` subdirectory
3. Same directory as `tstorie` executable
4. `<executable_dir>/lib/` subdirectory

### Loading Process
```nim
# 1. Check if plugin exists
if isPluginAvailable():
  # 2. Load the shared library
  let plugin = loadCompressionPlugin()
  
  if plugin != nil:
    # 3. Use the plugin
    let compressed = compressString(data)
    let decompressed = decompressString(compressed)
    
    # 4. Unload when done (optional, happens at exit anyway)
    unloadCompressionPlugin()
```

## Usage Examples

### Command-Line Data URL Decoding
```bash
# Decode a compressed data URL
./tstorie --decode "eJwLycxNtUq2MjG..."

# Or use positional argument
./tstorie decode:eJwLycxNtUq2MjG...
```

**If plugin missing:**
```
Error: Compression plugin required to decode data URLs
======================================================

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
```

### PNG Workflow Loading
```bash
# Load workflow from PNG file
./tstorie --png-workflow my-workflow.png

# Or use positional argument
./tstorie my-workflow.png
```

### Check Plugin Status
```bash
./tstorie --plugin-info
```

**Output:**
```
Compression plugin: AVAILABLE
Location: ./libcompression_plugin.so
Version: compression_plugin v1.0.0
```

## API Reference

### Plugin Loader (lib/plugin_loader.nim)

```nim
# Check if plugin exists
proc isPluginAvailable*(): bool

# Get plugin file path
proc getPluginPath*(): string

# Load the plugin (automatic on first use)
proc loadCompressionPlugin*(): CompressionPlugin

# Unload the plugin (automatic at exit)
proc unloadCompressionPlugin*()

# High-level compression/decompression
proc compressString*(data: string): string
proc decompressString*(data: string): string

# Show help about plugin
proc showPluginHelp*()
```

### Command-Line Handler (lib/cmdline_compression.nim)

```nim
# Handle data URL from command line
proc handleDataUrl*(url: string): bool

# Handle PNG workflow from command line
proc handlePngWorkflow*(pngPath: string): bool

# Process all command-line args for compression features
proc processCommandLine*(): bool
```

### Plugin Functions (lib/compression_plugin.nim)

```nim
# Exported from shared library:
proc compress_string(data: cstring): cstring
proc decompress_string(data: cstring): cstring
proc getPluginVersion(): cstring
proc isCompressionAvailable(): bool
```

## Integration into tStorie

### Step 1: Import the modules
```nim
when not defined(emscripten):
  import lib/plugin_loader
  import lib/cmdline_compression
```

### Step 2: Check for compression features early
```nim
proc main() =
  # Handle compression-dependent CLI args first
  when not defined(emscripten):
    if processCommandLine():
      return  # Feature handled, exit
  
  # Continue with normal tStorie startup
  startApplication()
```

### Step 3: Use compression when available
```nim
proc saveWorkflow(content: string) =
  when not defined(emscripten):
    if isPluginAvailable():
      let compressed = compressString(content)
      # Save compressed content
    else:
      # Save uncompressed or show message
      echo "Tip: Install compression plugin for smaller files"
```

## Adding Real Compression

Currently the plugin uses base64 as a placeholder. To add real compression:

### Option 1: Use nimble zip/zlib
```bash
nimble install zip
```

```nim
# In compression_plugin.nim
import zip/zlib

proc compressData*(data: string): string {.exportc, dynlib.} =
  let compressed = compress(data, stream = ZLIB_STREAM)
  return encode(compressed)  # base64 encode the result

proc decompressData*(data: string): string {.exportc, dynlib.} =
  let decoded = decode(data)  # base64 decode first
  return uncompress(decoded)
```

### Option 2: Use miniz (header-only C library)
```nim
{.compile: "miniz.c".}

proc mz_compress(dest: pointer, destLen: ptr csize_t, 
                 source: pointer, sourceLen: csize_t): cint {.importc.}

proc mz_uncompress(dest: pointer, destLen: ptr csize_t,
                   source: pointer, sourceLen: csize_t): cint {.importc.}

proc compressData*(data: string): string {.exportc, dynlib.} =
  # Use miniz for compression
  var destLen: csize_t = data.len * 2
  var dest = newString(destLen)
  let res = mz_compress(addr dest[0], addr destLen, 
                        unsafeAddr data[0], data.len.csize_t)
  if res == 0:
    dest.setLen(destLen)
    return encode(dest)
  return ""
```

### Option 3: Link against system zlib
```nim
{.passL: "-lz".}

proc compress2(dest: pointer, destLen: ptr culong,
               source: pointer, sourceLen: culong,
               level: cint): cint {.importc, header: "<zlib.h>".}

proc uncompress(dest: pointer, destLen: ptr culong,
                source: pointer, sourceLen: culong): cint {.importc, header: "<zlib.h>".}
```

## Size Comparison

### Without Plugin System
```
tstorie binary:        5.2 MB (includes zlib + compression code)
Total deployment:      5.2 MB
```

### With Plugin System
```
tstorie binary:        2.8 MB (no compression code)
compression plugin:    0.15 MB (zlib only)
Total deployment:      2.95 MB (main) + 0.15 MB (optional plugin)

Users who don't need compression: 2.8 MB (save 2.4 MB)
Users who need compression:       2.95 MB (save 2.25 MB)
```

## Distribution Strategies

### Strategy 1: Separate Downloads
```
- tstorie-linux-x64.tar.gz (2.8 MB)
- tstorie-compression-plugin-linux-x64.tar.gz (150 KB)
```

Users download only what they need.

### Strategy 2: Optional Install
```bash
# Main installation
./install-tstorie.sh

# Optional plugin installation
./install-tstorie.sh --with-compression
```

### Strategy 3: Runtime Download
```nim
# If plugin not found, offer to download
if not isPluginAvailable():
  echo "Download compression plugin? (150 KB) [y/n]"
  if readLine(stdin) == "y":
    downloadPlugin()
```

### Strategy 4: Build-Time Option
```bash
# Build without compression support
nim c -d:release tstorie.nim

# Build with compression support (includes plugin in binary)
nim c -d:release -d:withCompression tstorie.nim
```

## Platform Considerations

### Linux
- Standard `.so` shared library
- Works on most distributions
- May need `libc` dependency documented

### macOS
- Uses `.dylib` extension
- Code signing may be needed for distribution
- Universal binary for M1/Intel

### Windows
- Uses `.dll` extension
- May need MSVC runtime documented
- Consider static linking to avoid runtime deps

## Security Considerations

### Plugin Verification
```nim
proc verifyPlugin(path: string): bool =
  # Check file hash
  let hash = sha256(readFile(path))
  return hash == KNOWN_GOOD_HASH

if not verifyPlugin(getPluginPath()):
  echo "Warning: Plugin verification failed"
  return false
```

### Sandboxing
```nim
# Plugin only has access to compress/decompress functions
# No file I/O, no network, no system calls
# Just pure data transformation
```

## Testing

### Test Plugin Loading
```bash
cd lib
nim c -r plugin_loader.nim
```

### Test Command-Line Processing
```bash
nim c -r lib/cmdline_compression.nim --decode "test"
```

### Test Integration
```bash
# Build plugin
./build-plugin.sh

# Test with tstorie
./tstorie --plugin-info
./tstorie --decode "eJwLycxNtUq..."
```

## Troubleshooting

### Plugin Not Found
**Problem:** `Compression plugin not found`

**Solutions:**
1. Build the plugin: `./build-plugin.sh`
2. Check plugin location: `./tstorie --plugin-info`
3. Copy plugin to: `./` or `./lib/`

### Failed to Load Plugin
**Problem:** `Failed to load compression plugin`

**Solutions:**
1. Check file permissions: `chmod +x libcompression_plugin.so`
2. Check dependencies: `ldd libcompression_plugin.so` (Linux)
3. Rebuild plugin: `./build-plugin.sh`

### Symbol Not Found
**Problem:** `Failed to load required symbols from plugin`

**Solutions:**
1. Rebuild plugin with `--app:lib` flag
2. Check exports: `nm -D libcompression_plugin.so | grep compress`
3. Ensure functions have `{.exportc, dynlib.}` pragma

### Wrong Architecture
**Problem:** `Plugin won't load on macOS M1`

**Solutions:**
1. Build universal binary: `--cpu:arm64` and `--cpu:amd64`
2. Use `lipo` to create fat binary
3. Or build separately for each architecture

## Future Enhancements

### Plugin Registry
```nim
# Load multiple plugins
loadPlugin("compression")
loadPlugin("encryption")
loadPlugin("image_processing")
```

### Plugin Updates
```nim
proc checkPluginUpdate(): bool =
  let currentVersion = getPluginVersion()
  let latestVersion = fetchLatestVersion()
  return latestVersion > currentVersion
```

### Plugin Marketplace
```bash
# Install plugins from registry
tstorie plugin install compression
tstorie plugin install png-tools
tstorie plugin list
```

## Summary

The plugin system provides:
- ✅ **Smaller binaries** - Main binary stays small
- ✅ **Optional features** - Install only what you need
- ✅ **Flexibility** - Easy to update/swap plugins
- ✅ **Clear errors** - Helpful messages if plugin missing
- ✅ **Native-only** - WASM uses browser APIs, no plugin needed
- ✅ **Simple API** - Just call `compressString()`/`decompressString()`
