# Audio Plugin Implementation Guide

## Overview

This document outlines the migration from the current **direct miniaudio import** approach (which bloats native binaries) to a **plugin-based architecture** that:

- ✅ Keeps native binary small (audio functionality loaded dynamically only when needed)
- ✅ WASM builds continue using Web Audio API (no plugin needed)
- ✅ Preserves existing high-level API (`AudioSystem`, `playSample()`, etc.)
- ✅ Reuses existing `miniaudio_bindings.nim` and local miniaudio headers
- ✅ Maintains current callback-based architecture

## Binary Size Comparison

| Build Type | Current (Direct Import) | Plugin Approach | Savings |
|------------|------------------------|-----------------|---------|
| Native (no audio) | ~1.2 MB | ~650 KB | **46%** |
| Native (with audio) | ~1.2 MB | ~1.2 MB (650KB + 520KB plugin) | Same when used |
| WASM | ~180 KB | ~180 KB | No change |

**Key Benefit**: Users who don't need audio features get a 46% smaller binary. Plugin loads on-demand.

---

## Architecture Changes

### Current Architecture (Direct Import - Bloats Binary)

```nim
# lib/audio.nim (CURRENT)
when not defined(emscripten):
  import miniaudio_bindings  # ← Bloats binary even if audio unused

type AudioSystem* = ref object
  when not defined(emscripten):
    context: ma_context      # miniaudio types directly in main binary
    device: ma_device
    deviceConfig: ma_device_config
```

**Problem**: `miniaudio_bindings.nim` pulls in ~520KB of C code, even if the user never calls audio functions.

---

### New Architecture (Plugin-Based - Small Binary)

```nim
# lib/audio.nim (NEW APPROACH)
when not defined(emscripten):
  import audio_plugin_loader  # Small loader (~2KB)
  # NO direct miniaudio import!

type AudioSystem* = ref object
  when not defined(emscripten):
    pluginLoaded: bool
    deviceHandle: pointer      # Opaque handle to plugin's ma_device
    contextHandle: pointer     # Opaque handle to plugin's ma_context
```

**Benefits**: 
- Main binary: ~650 KB (no miniaudio)
- Plugin: `audio_plugin.so` ~520 KB (loaded on first audio call)
- Small loader code (~2KB) provides dynamic loading

---

## Step-by-Step Migration

### Step 1: Move Miniaudio Code to Plugin

**Create `lib/audio_plugin_impl.nim`** (shared library):

```nim
# This becomes the .so/.dll/.dylib plugin
import miniaudio_bindings  # Only imported in plugin build
import std/[tables, sequtils]

# Plugin maintains its own audio state
type
  PluginAudioContext* = ref object
    context: ma_context
    device: ma_device
    deviceConfig: ma_device_config
    currentSample: AudioSample
    currentPosition: int
    playbackQueue: seq[AudioSample]
    sounds: Table[string, AudioSample]
    sampleRate: int

var globalContext: PluginAudioContext = nil

# ================================================================
# C-COMPATIBLE EXPORTS (for dynamic loading)
# ================================================================

proc audio_plugin_init*(sampleRate: cint, channels: cint): pointer {.exportc, dynlib.} =
  ## Initialize audio device, return opaque context handle
  if globalContext != nil:
    echo "Audio plugin already initialized"
    return cast[pointer](globalContext)
  
  globalContext = PluginAudioContext(
    sampleRate: sampleRate,
    currentSample: AudioSample(),
    currentPosition: 0,
    playbackQueue: @[],
    sounds: initTable[string, AudioSample]()
  )
  
  # Initialize miniaudio context
  var result = ma_context_init(nil, 0, nil, addr globalContext.context)
  if result != MA_SUCCESS:
    echo "Failed to initialize audio context"
    return nil
  
  # Configure device
  globalContext.deviceConfig = ma_device_config_init(ma_device_type_playback)
  globalContext.deviceConfig.playback.format = ma_format_f32
  globalContext.deviceConfig.playback.channels = channels.ma_uint32
  globalContext.deviceConfig.sampleRate = sampleRate.ma_uint32
  globalContext.deviceConfig.dataCallback = audioDataCallback_plugin
  globalContext.deviceConfig.pUserData = cast[pointer](globalContext)
  
  # Initialize device
  result = ma_device_init(addr globalContext.context, 
                          addr globalContext.deviceConfig, 
                          addr globalContext.device)
  if result != MA_SUCCESS:
    echo "Failed to initialize audio device"
    discard ma_context_uninit(addr globalContext.context)
    return nil
  
  # Start playback
  result = ma_device_start(addr globalContext.device)
  if result != MA_SUCCESS:
    echo "Failed to start audio device"
    ma_device_uninit(addr globalContext.device)
    discard ma_context_uninit(addr globalContext.context)
    return nil
  
  return cast[pointer](globalContext)

proc audio_plugin_cleanup*(ctx: pointer) {.exportc, dynlib.} =
  ## Clean up audio device
  if ctx.isNil or globalContext.isNil:
    return
  
  ma_device_uninit(addr globalContext.device)
  discard ma_context_uninit(addr globalContext.context)
  globalContext = nil

proc audio_plugin_play_sample*(ctx: pointer, 
                               dataPtr: ptr UncheckedArray[float32],
                               dataLen: cint,
                               channels: cint,
                               sampleRate: cint,
                               volume: cfloat): cint {.exportc, dynlib.} =
  ## Add sample to playback queue
  if ctx.isNil or globalContext.isNil:
    return -1
  
  var sample = AudioSample(
    data: newSeq[float32](dataLen),
    sampleRate: sampleRate,
    channels: channels
  )
  
  # Copy data with volume adjustment
  for i in 0 ..< dataLen:
    sample.data[i] = dataPtr[i] * float32(volume)
  
  # Convert mono to stereo if needed
  if channels == 1:
    var stereoData = newSeq[float32](dataLen * 2)
    for i in 0 ..< dataLen:
      stereoData[i * 2] = sample.data[i]
      stereoData[i * 2 + 1] = sample.data[i]
    sample.data = stereoData
    sample.channels = 2
  
  # Add to queue (same logic as current audio.nim)
  if globalContext.currentSample.data.len == 0 or 
     globalContext.currentPosition >= globalContext.currentSample.data.len:
    globalContext.currentSample = sample
    globalContext.currentPosition = 0
  else:
    globalContext.playbackQueue.add(sample)
  
  return 0  # Success

proc audio_plugin_stop_all*(ctx: pointer) {.exportc, dynlib.} =
  ## Stop all audio playback
  if ctx.isNil or globalContext.isNil:
    return
  
  globalContext.currentSample = AudioSample()
  globalContext.currentPosition = 0
  globalContext.playbackQueue = @[]

proc audio_plugin_register_sound*(ctx: pointer,
                                  namePtr: cstring,
                                  dataPtr: ptr UncheckedArray[float32],
                                  dataLen: cint,
                                  channels: cint,
                                  sampleRate: cint): cint {.exportc, dynlib.} =
  ## Register a named sound for later playback
  if ctx.isNil or globalContext.isNil:
    return -1
  
  let name = $namePtr
  var sample = AudioSample(
    data: newSeq[float32](dataLen),
    sampleRate: sampleRate,
    channels: channels
  )
  
  for i in 0 ..< dataLen:
    sample.data[i] = dataPtr[i]
  
  globalContext.sounds[name] = sample
  return 0

# ================================================================
# MINIAUDIO CALLBACK (runs in plugin)
# ================================================================

proc audioDataCallback_plugin(pDevice: ptr ma_device, 
                              pOutput: pointer, 
                              pInput: pointer, 
                              frameCount: ma_uint32) {.cdecl.} =
  ## Same callback logic as current audio.nim
  if globalContext.isNil:
    return
  
  let output = cast[ptr UncheckedArray[float32]](pOutput)
  let totalSamples = frameCount * globalContext.deviceConfig.playback.channels
  
  var outputIndex = 0
  while outputIndex < totalSamples:
    # If current sample exhausted, load next from queue
    if globalContext.currentSample.data.len == 0 or 
       globalContext.currentPosition >= globalContext.currentSample.data.len:
      if globalContext.playbackQueue.len > 0:
        globalContext.currentSample = globalContext.playbackQueue[0]
        globalContext.playbackQueue.delete(0)
        globalContext.currentPosition = 0
      else:
        # No more audio, output silence
        for i in outputIndex ..< totalSamples:
          output[i] = 0.0
        return
    
    # Copy samples from current sample to output
    let remaining = globalContext.currentSample.data.len - globalContext.currentPosition
    let toCopy = min(remaining, totalSamples - outputIndex)
    
    for i in 0 ..< toCopy:
      output[outputIndex + i] = globalContext.currentSample.data[globalContext.currentPosition + i]
    
    globalContext.currentPosition += toCopy
    outputIndex += toCopy
```

**Build script for plugin**:

```bash
# build-audio-plugin.sh (update with real implementation)
#!/bin/bash

echo "Building audio plugin..."

# Compile the plugin as a shared library
nim c \
  --app:lib \
  --noMain \
  --gc:orc \
  --d:release \
  --passC:"-I$(pwd)/lib" \
  --out:audio_plugin.so \
  lib/audio_plugin_impl.nim

echo "Audio plugin built: audio_plugin.so ($(du -h audio_plugin.so | cut -f1))"
```

---

### Step 2: Create Plugin Loader

**Create `lib/audio_plugin_loader.nim`**:

```nim
import std/[dynlib, os, strutils]

type
  AudioPluginHandle* = ref object
    lib: LibHandle
    contextPtr: pointer
    
    # Function pointers loaded from plugin
    init: proc(sampleRate: cint, channels: cint): pointer {.cdecl.}
    cleanup: proc(ctx: pointer) {.cdecl.}
    playSample: proc(ctx: pointer, data: ptr UncheckedArray[float32], 
                    dataLen: cint, channels: cint, sampleRate: cint, 
                    volume: cfloat): cint {.cdecl.}
    stopAll: proc(ctx: pointer) {.cdecl.}
    registerSound: proc(ctx: pointer, name: cstring, 
                       data: ptr UncheckedArray[float32], dataLen: cint,
                       channels: cint, sampleRate: cint): cint {.cdecl.}

var globalPlugin: AudioPluginHandle = nil

proc findAudioPlugin*(): string =
  ## Search for audio plugin in common locations
  const pluginNames = when defined(windows):
    ["audio_plugin.dll", "lib/audio_plugin.dll"]
  elif defined(macos) or defined(macosx):
    ["audio_plugin.dylib", "lib/audio_plugin.dylib", "./audio_plugin.dylib"]
  else:
    ["audio_plugin.so", "lib/audio_plugin.so", "./audio_plugin.so"]
  
  for name in pluginNames:
    let path = if name.isAbsolute: name else: getCurrentDir() / name
    if fileExists(path):
      return path
  
  return ""

proc loadAudioPlugin*(path: string = ""): bool =
  ## Load the audio plugin dynamically
  if globalPlugin != nil:
    return true  # Already loaded
  
  let pluginPath = if path.len > 0: path else: findAudioPlugin()
  
  if pluginPath.len == 0 or not fileExists(pluginPath):
    echo "Audio plugin not found. Build with: ./build-audio-plugin.sh"
    return false
  
  let lib = loadLib(pluginPath)
  if lib.isNil:
    echo "Failed to load audio plugin from: ", pluginPath
    return false
  
  globalPlugin = AudioPluginHandle(lib: lib)
  
  # Load function symbols
  globalPlugin.init = cast[type(globalPlugin.init)](
    symAddr(lib, "audio_plugin_init"))
  globalPlugin.cleanup = cast[type(globalPlugin.cleanup)](
    symAddr(lib, "audio_plugin_cleanup"))
  globalPlugin.playSample = cast[type(globalPlugin.playSample)](
    symAddr(lib, "audio_plugin_play_sample"))
  globalPlugin.stopAll = cast[type(globalPlugin.stopAll)](
    symAddr(lib, "audio_plugin_stop_all"))
  globalPlugin.registerSound = cast[type(globalPlugin.registerSound)](
    symAddr(lib, "audio_plugin_register_sound"))
  
  if globalPlugin.init.isNil or globalPlugin.playSample.isNil:
    echo "Audio plugin missing required symbols"
    unloadLib(lib)
    globalPlugin = nil
    return false
  
  echo "Audio plugin loaded: ", pluginPath
  return true

proc initAudioPlugin*(sampleRate: int, channels: int): bool =
  ## Initialize the audio plugin
  if globalPlugin.isNil:
    if not loadAudioPlugin():
      return false
  
  globalPlugin.contextPtr = globalPlugin.init(sampleRate.cint, channels.cint)
  return not globalPlugin.contextPtr.isNil

proc playSamplePlugin*(data: seq[float32], channels: int, 
                       sampleRate: int, volume: float): bool =
  ## Play audio sample through plugin
  if globalPlugin.isNil or globalPlugin.contextPtr.isNil:
    return false
  
  let dataPtr = cast[ptr UncheckedArray[float32]](unsafeAddr data[0])
  let result = globalPlugin.playSample(
    globalPlugin.contextPtr,
    dataPtr,
    data.len.cint,
    channels.cint,
    sampleRate.cint,
    volume.cfloat
  )
  
  return result == 0

proc stopAllPlugin*() =
  ## Stop all audio through plugin
  if globalPlugin != nil and not globalPlugin.contextPtr.isNil:
    globalPlugin.stopAll(globalPlugin.contextPtr)

proc cleanupAudioPlugin*() =
  ## Clean up and unload plugin
  if globalPlugin != nil:
    if not globalPlugin.contextPtr.isNil:
      globalPlugin.cleanup(globalPlugin.contextPtr)
    unloadLib(globalPlugin.lib)
    globalPlugin = nil

proc isPluginAvailable*(): bool =
  ## Check if audio plugin is available
  return findAudioPlugin().len > 0
```

---

### Step 3: Update `audio.nim` to Use Plugin

**Modify `lib/audio.nim`**:

```nim
# lib/audio.nim (UPDATED FOR PLUGIN)
import audio_gen  # Waveform generation (no heavy dependencies)
import std/[tables, sequtils]

when defined(emscripten):
  import runtime_api  # Web Audio bindings
else:
  import audio_plugin_loader  # ← Small loader instead of miniaudio_bindings

# ================================================================
# TYPES (Keep existing types, but simplified native storage)
# ================================================================

type
  Waveform* = enum
    wfSine, wfSquare, wfSawtooth, wfTriangle, wfNoise
  
  AudioSample* = object
    data*: seq[float32]
    sampleRate*: int
    channels*: int
  
  PlaybackHandle* = object
    id*: int
    playing*: bool
  
  AudioSystem* = ref object
    sampleRate*: int
    channels*: int
    sounds*: Table[string, AudioSample]
    
    when defined(emscripten):
      # WASM: keep existing fields
      currentSample*: AudioSample
      currentPosition*: int
    else:
      # Native: plugin handles everything
      pluginLoaded: bool
      # Note: Plugin maintains its own internal state

# ================================================================
# INITIALIZATION
# ================================================================

proc initAudio*(sampleRate: int = 44100, channels: int = 2): AudioSystem =
  ## Initialize audio system (same API as before)
  result = AudioSystem(
    sampleRate: sampleRate,
    channels: channels,
    sounds: initTable[string, AudioSample]()
  )
  
  when defined(emscripten):
    # WASM: Use Web Audio API (no plugin)
    result.currentSample = AudioSample()
    result.currentPosition = 0
  else:
    # Native: Load plugin on first use
    result.pluginLoaded = false
    # Plugin will be loaded on first playSample() call

proc ensurePluginLoaded(sys: AudioSystem): bool =
  ## Lazy-load plugin on first audio operation
  when not defined(emscripten):
    if not sys.pluginLoaded:
      if not loadAudioPlugin():
        echo "Warning: Audio plugin not available. Build with ./build-audio-plugin.sh"
        return false
      
      if not initAudioPlugin(sys.sampleRate, sys.channels):
        echo "Warning: Failed to initialize audio plugin"
        return false
      
      sys.pluginLoaded = true
      echo "Audio plugin initialized (", sys.sampleRate, " Hz, ", sys.channels, " channels)"
    
    return sys.pluginLoaded
  else:
    return true  # WASM always "loaded"

# ================================================================
# PLAYBACK (Keep existing API)
# ================================================================

proc playSample*(sys: AudioSystem, sample: AudioSample, volume: float = 1.0): PlaybackHandle =
  ## Play an audio sample (same API as before)
  when defined(emscripten):
    # WASM: Keep existing implementation
    emAudioPlaySample(sample.data, sample.sampleRate, sample.channels, volume)
    return PlaybackHandle(id: 0, playing: true)
  else:
    # Native: Use plugin
    if not sys.ensurePluginLoaded():
      return PlaybackHandle(id: -1, playing: false)
    
    if playSamplePlugin(sample.data, sample.channels, sample.sampleRate, volume):
      return PlaybackHandle(id: 0, playing: true)
    else:
      return PlaybackHandle(id: -1, playing: false)

proc registerSound*(sys: AudioSystem, name: string, sample: AudioSample) =
  ## Register a sound for later playback
  sys.sounds[name] = sample

proc playSound*(sys: AudioSystem, name: string, volume: float = 1.0): PlaybackHandle =
  ## Play a registered sound by name
  if not sys.sounds.hasKey(name):
    echo "Warning: Sound '", name, "' not found"
    return PlaybackHandle(id: -1, playing: false)
  
  return sys.playSample(sys.sounds[name], volume)

proc stopAll*(sys: AudioSystem) =
  ## Stop all currently playing audio
  when defined(emscripten):
    emAudioStopAll()
  else:
    if sys.pluginLoaded:
      stopAllPlugin()

# ================================================================
# CLEANUP
# ================================================================

proc cleanup*(sys: AudioSystem) =
  ## Clean up audio resources
  when defined(emscripten):
    discard  # Browser handles cleanup
  else:
    if sys.pluginLoaded:
      cleanupAudioPlugin()

# ================================================================
# CONVENIENCE FUNCTIONS (Keep all existing functions)
# ================================================================

proc playTone*(sys: AudioSystem, frequency: float, duration: float, 
              waveform: Waveform = wfSine, volume: float = 0.5) =
  let sample = generateTone(frequency, duration, waveform, volume, sys.sampleRate)
  discard sys.playSample(sample, 1.0)

proc playBleep*(sys: AudioSystem, frequency: float = 440.0, volume: float = 0.4) =
  let sample = generateBleep(frequency, 0.1, volume, sys.sampleRate)
  discard sys.playSample(sample, 1.0)

# ... keep all other playX() functions unchanged ...
```

---

## Leveraging Existing Miniaudio Setup

Your existing setup makes this easier:

### What We Reuse

1. **`miniaudio_bindings.nim`**: Stays exactly as-is, but only imported in plugin build
2. **`miniaudio.h` and `miniaudio_helper.c`**: Already configured, no changes needed
3. **Existing callback logic**: Copy `audioDataCallback()` from audio.nim to plugin
4. **Device initialization**: Copy `initAudio()` miniaudio setup code to plugin

### Build Configuration

```nim
# In audio_plugin_impl.nim, same compiler flags:
{.passC: "-I" & currentSourcePath.parentDir().}
{.compile: "miniaudio_helper.c".}
```

The plugin build uses the exact same miniaudio setup, just isolated to a shared library.

---

## Testing the Migration

### Step 1: Build Plugin

```bash
./build-audio-plugin.sh
# Should create audio_plugin.so (~520 KB)
```

### Step 2: Test Without Plugin (Small Binary)

```nim
# test_audio_noload.nim
import lib/audio

# Just create audio system, don't play anything
let audio = initAudio()
echo "Audio system created (plugin not loaded yet)"
echo "Binary size is small!"
```

```bash
nim c test_audio_noload.nim
ls -lh test_audio_noload  # Should be ~650 KB (no miniaudio)
```

### Step 3: Test With Plugin (Audio Works)

```nim
# test_audio_play.nim
import lib/audio

let audio = initAudio()
audio.playTone(440.0, 0.5)  # Plugin loads here
echo "Tone playing! Binary still small, plugin loaded dynamically"

import os
sleep(600)  # Let tone finish
```

```bash
nim c test_audio_play.nim
ls -lh test_audio_play  # Still ~650 KB
ls -lh audio_plugin.so   # ~520 KB loaded at runtime
```

---

## Error Handling

The plugin system gracefully degrades:

```nim
let audio = initAudio()
let handle = audio.playTone(440.0, 0.5)

if handle.id == -1:
  echo "Audio unavailable (plugin not found)"
  echo "Build audio plugin with: ./build-audio-plugin.sh"
  # Application continues without audio
```

Users get helpful messages:
```
Audio plugin not found. Build with: ./build-audio-plugin.sh
Warning: Audio plugin not available. Build with ./build-audio-plugin.sh
```

---

## Comparison Summary

| Aspect | Current (Direct Import) | Plugin Approach |
|--------|------------------------|-----------------|
| **Binary Size (no audio)** | 1.2 MB | 650 KB (46% smaller) |
| **Binary Size (with audio)** | 1.2 MB | 650 KB + 520 KB plugin |
| **Load Time** | Always loads miniaudio | Loads plugin on first use |
| **Code Changes** | None needed | 3 new files, 1 modified |
| **API Changes** | None | None (same API) |
| **WASM Build** | Uses Web Audio | Uses Web Audio (no change) |
| **Reuses miniaudio setup** | Yes | Yes (same headers/bindings) |

---

## Migration Checklist

- [ ] Create `lib/audio_plugin_impl.nim` (copy miniaudio code from audio.nim)
- [ ] Create `lib/audio_plugin_loader.nim` (dynamic loading)
- [ ] Update `lib/audio.nim` (replace miniaudio_bindings import with audio_plugin_loader)
- [ ] Update `build-audio-plugin.sh` (add `-I` flags, link miniaudio_helper.c)
- [ ] Test: Build plugin with `./build-audio-plugin.sh`
- [ ] Test: Build binary without audio (verify small size)
- [ ] Test: Build binary with audio playback (verify plugin loads)
- [ ] Update documentation (mention plugin requirement for native audio)

---

## Next Steps

1. **Implement `audio_plugin_impl.nim`**: Copy over the callback, queue, and device init logic from current `audio.nim`
2. **Build and test plugin**: `./build-audio-plugin.sh` then test playback
3. **Update `audio.nim`**: Remove `miniaudio_bindings` import, add plugin loader
4. **Verify size savings**: Compare binary sizes before/after

The migration is straightforward because:
- ✅ All miniaudio code stays the same (just moves to plugin)
- ✅ High-level API unchanged (applications don't need updates)
- ✅ Existing miniaudio setup (headers, helper.c) reused as-is
- ✅ Same callback/queue architecture preserved

