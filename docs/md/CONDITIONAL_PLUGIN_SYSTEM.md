# Platform-Conditional Plugin System

## Overview

tStorie can use **different implementations** for the same feature based on the build target:
- **WASM builds** → Use browser built-in APIs (Web Audio, Canvas, etc.)
- **Native builds** → Load optional plugins (miniaudio, graphics, etc.)

This keeps both builds optimal: WASM stays small, native only loads what's needed.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    tStorie Source Code                       │
│                  (Same code for all platforms)               │
│                                                               │
│  when defined(emscripten):                                   │
│    # Use browser APIs                                        │
│  else:                                                       │
│    # Load native plugins                                     │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│   WASM Build     │          │  Native Build    │
│                  │          │                  │
│ • Web Audio API  │          │ • Audio Plugin   │
│ • Canvas API     │          │ • Graphics Plugin│
│ • Compression    │          │ • Compress Plugin│
│   Streams        │          │ (all optional)   │
│                  │          │                  │
│ Size: ~2MB       │          │ Size: ~3MB +     │
│ No plugins       │          │ optional plugins │
└──────────────────┘          └──────────────────┘
```

## Audio Example

### Problem
- **WASM**: Has Web Audio API (no plugin needed)
- **Native**: Needs miniaudio library (~200KB)
- **Goal**: Same API works on both platforms

### Solution
```nim
# lib/audio_loader.nim - Platform detection

when defined(emscripten):
  # WASM: Use browser APIs
  proc initAudio*(): bool =
    js_initAudio()  # Call JavaScript
    return true
  
  proc playTone*(freq: float, dur: float) =
    js_playTone(freq, dur)

else:
  # Native: Load plugin dynamically
  proc initAudio*(): bool =
    let plugin = loadAudioPlugin()  # Load .so/.dll/.dylib
    if plugin == nil:
      return false
    return plugin.initDevice() == 1
  
  proc playTone*(freq: float, dur: float) =
    let plugin = loadAudioPlugin()
    if plugin != nil:
      plugin.playTone(freq, dur)
```

### Usage in Your Code
```nim
# Your code doesn't care about platform!
import audio_loader

proc playSound() =
  if initAudio():
    playTone(440.0, 1.0)  # Works on both platforms!
```

## Pattern: Conditional Plugin Loading

### Step 1: Detect Platform
```nim
when defined(emscripten):
  # This code only in WASM builds
  echo "Running in browser"
else:
  # This code only in native builds
  echo "Running natively"
```

### Step 2: Abstract the API
```nim
# Unified interface that works everywhere
proc doSomething*() =
  when defined(emscripten):
    # Use browser API
    js_callBrowserFunction()
  else:
    # Use plugin
    let plugin = loadPlugin()
    if plugin != nil:
      plugin.callFunction()
    else:
      echo "Plugin not available"
```

### Step 3: Graceful Degradation
```nim
proc hasFeature*(): bool =
  when defined(emscripten):
    return true  # Always available in browser
  else:
    return isPluginAvailable()

proc showUI() =
  if hasFeature():
    showFeatureButton()
  else:
    showInstallPluginHint()
```

## Real-World Examples

### Audio System
```nim
# lib/audio_loader.nim

when defined(emscripten):
  # Web Audio API (always available)
  proc playTone*(freq: float, dur: float) =
    js_playTone(freq.cfloat, dur.cfloat)

else:
  # miniaudio plugin (optional)
  proc playTone*(freq: float, dur: float) =
    if isAudioPluginAvailable():
      let plugin = loadAudioPlugin()
      plugin.playTone(freq.cfloat, dur.cfloat)
    else:
      echo "♪ Beep! (install audio plugin for sound)"

# Usage:
playTone(440.0, 1.0)  # Works on both!
```

### Compression System
```nim
# lib/compression_loader.nim

when defined(emscripten):
  # Compression Streams API (browser)
  proc compress*(data: string): string =
    return js_compress(data)

else:
  # zlib plugin (optional)
  proc compress*(data: string): string =
    if isCompressionPluginAvailable():
      return compressionPlugin.compress(data)
    else:
      return data  # Fallback: uncompressed

# Usage:
let compressed = compress(myData)  # Adapts to platform!
```

### Graphics System
```nim
# lib/graphics_loader.nim

when defined(emscripten):
  # WebGL (browser)
  proc drawTriangle*(x, y: float) =
    js_drawTriangle(x, y)

else:
  # OpenGL plugin (optional)
  proc drawTriangle*(x, y: float) =
    if isGraphicsPluginAvailable():
      graphicsPlugin.drawTriangle(x, y)
    else:
      # Fallback: ASCII art
      echo "  /\\"
      echo " /  \\"
      echo "/____\\"

# Usage:
drawTriangle(100, 100)  # Right backend automatically!
```

## Integration Example: tstorie.nim

```nim
# Main tStorie initialization

import audio_loader
import compression_loader
import graphics_loader

proc initializeFeatures() =
  echo "Initializing tStorie..."
  echo "Platform: ", when defined(emscripten): "WASM" else: "Native"
  
  # Audio
  when defined(emscripten):
    echo "Audio: Web Audio API (built-in)"
    discard initAudio()  # Always succeeds
  else:
    if isAudioPluginAvailable():
      echo "Audio: Loading plugin..."
      if initAudio():
        echo "✓ Audio plugin loaded"
    else:
      echo "Audio: Not available (plugin not installed)"
  
  # Compression
  when defined(emscripten):
    echo "Compression: Compression Streams API (built-in)"
  else:
    if isCompressionPluginAvailable():
      echo "✓ Compression plugin available"
    else:
      echo "Compression: Not available (plugin not installed)"
  
  # Graphics
  when defined(emscripten):
    echo "Graphics: WebGL (built-in)"
  else:
    if isGraphicsPluginAvailable():
      echo "✓ Graphics plugin available"
    else:
      echo "Graphics: Using terminal rendering"

proc main() =
  initializeFeatures()
  
  # Rest of tStorie...
  startTerminal()
  runEventLoop()
```

## Build Commands

### WASM Build
```bash
./build-web.sh

# Output: ~2MB
# - No audio plugin needed (Web Audio API)
# - No compression plugin (Compression Streams)
# - No graphics plugin (WebGL/Canvas)
# All features work via browser APIs!
```

### Native Build (Minimal)
```bash
nim c -d:release tstorie.nim

# Output: ~3MB
# - No plugins included
# - Optional features disabled
# - Still fully functional
```

### Native Build (Full Features)
```bash
# Build with all plugins
./build-plugin.sh          # compression plugin
./build-audio-plugin.sh    # audio plugin
./build-graphics-plugin.sh # graphics plugin

nim c -d:release tstorie.nim

# Output: ~3MB + 200KB plugins
# - All features available
# - Plugins loaded on-demand
# - User can delete unused plugins
```

## Plugin Discovery Pattern

```nim
proc discoverPlugins*(): seq[string] =
  ## Find all available plugins
  result = @[]
  
  when not defined(emscripten):
    if isAudioPluginAvailable():
      result.add("audio")
    
    if isCompressionPluginAvailable():
      result.add("compression")
    
    if isGraphicsPluginAvailable():
      result.add("graphics")

proc showPluginStatus*() =
  echo "Available plugins:"
  let plugins = discoverPlugins()
  
  if plugins.len == 0:
    echo "  (none - using built-in features only)"
  else:
    for p in plugins:
      echo "  ✓ ", p

proc downloadMissingPlugins*() =
  ## Offer to download missing plugins
  let available = discoverPlugins()
  let all = @["audio", "compression", "graphics"]
  
  for plugin in all:
    if plugin notin available:
      echo "Install ", plugin, " plugin? (y/n)"
      # Download or show build instructions
```

## Conditional UI Example

```nim
proc buildAudioMenu*(): Menu =
  result = newMenu("Audio")
  
  when defined(emscripten):
    # Always show full menu in browser
    result.addItem("Play Sound", playSound)
    result.addItem("Settings", showAudioSettings)
  else:
    # Native: conditional based on plugin
    if isAudioPluginAvailable():
      result.addItem("Play Sound", playSound)
      result.addItem("Settings", showAudioSettings)
    else:
      result.addItem("Install Audio Plugin...", showAudioHelp)

proc buildExportMenu*(): Menu =
  result = newMenu("Export")
  
  result.addItem("Copy Text", copyToClipboard)
  
  when defined(emscripten):
    # Browser has compression built-in
    result.addItem("Share URL", exportAsUrl)
    result.addItem("Export PNG", exportAsPng)
  else:
    # Native: show only if plugin available
    if isCompressionPluginAvailable():
      result.addItem("Share URL", exportAsUrl)
      result.addItem("Export PNG", exportAsPng)
    else:
      result.addItem("Export (Install Plugin)...", showCompressionHelp)
```

## Feature Detection API

```nim
type
  PlatformFeatures* = object
    audio*: bool
    compression*: bool
    graphics*: bool
    networking*: bool

proc detectFeatures*(): PlatformFeatures =
  ## Detect available features on current platform
  result = PlatformFeatures()
  
  when defined(emscripten):
    # Browser: everything available
    result.audio = true
    result.compression = true
    result.graphics = true
    result.networking = true
  else:
    # Native: check plugins
    result.audio = isAudioPluginAvailable()
    result.compression = isCompressionPluginAvailable()
    result.graphics = isGraphicsPluginAvailable()
    result.networking = true  # Always available

proc showCapabilities*() =
  let features = detectFeatures()
  
  echo "Platform Capabilities:"
  echo "  Audio:       ", if features.audio: "✓" else: "✗"
  echo "  Compression: ", if features.compression: "✓" else: "✗"
  echo "  Graphics:    ", if features.graphics: "✓" else: "✗"
  echo "  Networking:  ", if features.networking: "✓" else: "✗"
```

## Benefits

### For WASM Builds
- ✅ **Smaller**: No plugin system code
- ✅ **Simpler**: Direct browser API calls
- ✅ **Faster**: No dynamic loading overhead
- ✅ **No dependencies**: Everything in browser

### For Native Builds
- ✅ **Flexible**: Users choose what to install
- ✅ **Smaller base**: Minimal binary without plugins
- ✅ **Optional features**: Audio/graphics/etc not required
- ✅ **Easy updates**: Update plugins independently

### For Development
- ✅ **Same code**: One codebase for both platforms
- ✅ **Clear separation**: Platform code isolated
- ✅ **Easy testing**: Test with/without plugins
- ✅ **Gradual migration**: Add plugins over time

## Plugin Build Scripts

### Build All Plugins
```bash
#!/bin/bash
# build-all-plugins.sh

echo "Building plugins for native builds..."

# Compression plugin
nim c --app:lib -d:release lib/compression_plugin.nim
mv lib/libcompression_plugin.so ./

# Audio plugin
nim c --app:lib -d:release lib/audio_plugin.nim
mv lib/libaudio_plugin.so ./

# Graphics plugin (example)
# nim c --app:lib -d:release lib/graphics_plugin.nim
# mv lib/libgraphics_plugin.so ./

echo "✓ All plugins built"
ls -lh *.so
```

### Selective Build
```bash
# User can build just what they need
./build-plugin.sh compression  # Just compression
./build-plugin.sh audio        # Just audio
./build-plugin.sh all          # Everything
```

## Distribution Strategies

### Strategy 1: Separate Downloads
```
tstorie-wasm-v1.0.tar.gz (2 MB)
  └─ tstorie.wasm + tstorie.js

tstorie-native-v1.0-linux-x64.tar.gz (3 MB)
  └─ tstorie

tstorie-plugins-v1.0-linux-x64.tar.gz (300 KB)
  ├─ libcompression_plugin.so (57 KB)
  ├─ libaudio_plugin.so (150 KB)
  └─ libgraphics_plugin.so (100 KB)
```

### Strategy 2: Bundles
```
tstorie-minimal-v1.0.tar.gz (3 MB)
  └─ tstorie (no plugins)

tstorie-standard-v1.0.tar.gz (3.2 MB)
  ├─ tstorie
  ├─ libcompression_plugin.so
  └─ libaudio_plugin.so

tstorie-full-v1.0.tar.gz (3.3 MB)
  ├─ tstorie
  └─ plugins/
      ├─ compression
      ├─ audio
      └─ graphics
```

### Strategy 3: Installer
```bash
./install-tstorie.sh

# Interactive:
#   Install compression plugin? [Y/n]
#   Install audio plugin? [Y/n]
#   Install graphics plugin? [n]
```

## Summary

The conditional plugin system allows:

✅ **WASM**: Uses browser APIs (Web Audio, etc.) - no plugins needed
✅ **Native**: Loads optional plugins (miniaudio, etc.) - only if available
✅ **Same API**: One codebase works on both platforms
✅ **Graceful degradation**: Works without plugins, better with them
✅ **User choice**: Install only needed plugins
✅ **Minimal size**: Base binary stays small

This is exactly what modern applications do (VSCode extensions, browser plugins, etc.)!
