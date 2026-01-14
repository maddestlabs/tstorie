# Unified Audio API - Works on both Native (plugin) and WASM (Web Audio)
# Platform detection and conditional loading

import std/[dynlib, os]

when defined(emscripten):
  # ===== WASM/Emscripten: Use Web Audio API =====
  
  proc js_initAudio(): cstring {.importc: "tStorie_initAudio".}
  proc js_playTone(freq: cfloat, duration: cfloat, volume: cfloat) {.importc: "tStorie_playTone".}
  proc js_stopAudio() {.importc: "tStorie_stopAudio".}
  
  proc initAudio*(): bool =
    ## Initialize audio (uses Web Audio API in browser)
    let result = js_initAudio()
    echo "Audio initialized: Web Audio API"
    return true
  
  proc playTone*(frequency: float, duration: float, volume: float = 1.0) =
    ## Play a tone (uses Web Audio oscillator)
    js_playTone(frequency.cfloat, duration.cfloat, volume.cfloat)
  
  proc stopAudio*() =
    ## Stop audio playback
    js_stopAudio()
  
  proc isAudioPluginAvailable*(): bool =
    ## Web Audio is always available in browser
    return true
  
  proc getAudioBackend*(): string =
    return "Web Audio API (browser built-in)"

else:
  # ===== Native: Use miniaudio plugin =====
  
  type
    AudioPlugin* = ref object
      handle: LibHandle
      initDevice*: proc(): cint {.cdecl.}
      closeDevice*: proc() {.cdecl.}
      playTone*: proc(freq: cfloat, dur: cfloat, vol: cfloat) {.cdecl.}
      stopAudio*: proc() {.cdecl.}
      getVersion*: proc(): cstring {.cdecl.}
      isAvailable*: proc(): bool {.cdecl.}
  
  var globalAudioPlugin: AudioPlugin = nil
  
  proc getAudioPluginPath*(): string =
    ## Get expected path to audio plugin library
    when defined(windows):
      result = "audio_plugin.dll"
    elif defined(macosx):
      result = "libaudio_plugin.dylib"
    else:
      result = "libaudio_plugin.so"
    
    # Check in multiple locations
    let locations = [
      result,
      "lib" / result,
      getAppDir() / result,
      getAppDir() / "lib" / result,
    ]
    
    for loc in locations:
      if fileExists(loc):
        return loc
    
    return result
  
  proc isAudioPluginAvailable*(): bool =
    ## Check if audio plugin exists
    fileExists(getAudioPluginPath())
  
  proc loadAudioPlugin*(): AudioPlugin =
    ## Load the audio plugin dynamically
    if globalAudioPlugin != nil:
      return globalAudioPlugin
    
    let pluginPath = getAudioPluginPath()
    
    if not fileExists(pluginPath):
      echo "Audio plugin not found: ", pluginPath
      return nil
    
    # Use absolute path for loading
    let absPath = if pluginPath.isAbsolute(): pluginPath else: getCurrentDir() / pluginPath
    
    let handle = loadLib(absPath)
    if handle == nil:
      echo "Failed to load audio plugin: ", absPath
      return nil
    
    var plugin = AudioPlugin(handle: handle)
    
    # Load function pointers
    plugin.initDevice = cast[proc(): cint {.cdecl.}](
      symAddr(handle, "audio_init_device")
    )
    plugin.playTone = cast[proc(freq: cfloat, dur: cfloat, vol: cfloat) {.cdecl.}](
      symAddr(handle, "audio_play_tone")
    )
    plugin.stopAudio = cast[proc() {.cdecl.}](
      symAddr(handle, "audio_stop")
    )
    plugin.getVersion = cast[proc(): cstring {.cdecl.}](
      symAddr(handle, "getPluginVersion")
    )
    plugin.isAvailable = cast[proc(): bool {.cdecl.}](
      symAddr(handle, "isAudioAvailable")
    )
    
    if plugin.initDevice == nil or plugin.playTone == nil:
      echo "Failed to load required symbols from audio plugin"
      unloadLib(handle)
      return nil
    
    echo "Loaded audio plugin: ", $plugin.getVersion()
    globalAudioPlugin = plugin
    return plugin
  
  proc unloadAudioPlugin*() =
    if globalAudioPlugin != nil and globalAudioPlugin.handle != nil:
      unloadLib(globalAudioPlugin.handle)
      globalAudioPlugin = nil
  
  proc initAudio*(): bool =
    ## Initialize audio (loads miniaudio plugin on native)
    let plugin = loadAudioPlugin()
    if plugin == nil:
      return false
    
    let result = plugin.initDevice()
    return result == 1
  
  proc playTone*(frequency: float, duration: float, volume: float = 1.0) =
    ## Play a tone using audio plugin
    let plugin = loadAudioPlugin()
    if plugin == nil:
      echo "Audio plugin not available"
      return
    
    plugin.playTone(frequency.cfloat, duration.cfloat, volume.cfloat)
  
  proc stopAudio*() =
    ## Stop audio playback
    let plugin = globalAudioPlugin
    if plugin != nil:
      plugin.stopAudio()
  
  proc getAudioBackend*(): string =
    if isAudioPluginAvailable():
      return "miniaudio (native plugin)"
    else:
      return "No audio plugin available"

# ===== Unified API (works on both platforms) =====

proc showAudioHelp*() =
  ## Show help about audio support
  when defined(emscripten):
    echo """
Audio Support: Web Audio API
-----------------------------
Audio is built into your browser - no plugin needed!
"""
  else:
    echo """
Audio Support: miniaudio Plugin
--------------------------------
This feature requires the audio plugin for native audio playback.

To build the audio plugin:
  nim c --app:lib -d:release lib/audio_plugin.nim

This will create:
  - libaudio_plugin.so (Linux)
  - audio_plugin.dll (Windows)  
  - libaudio_plugin.dylib (macOS)

Place the library file in one of these locations:
  - Same directory as tstorie executable
  - ./lib/ subdirectory
  - Current working directory

For Web Audio support, use the WASM build instead.
"""

# Testing
when isMainModule:
  echo "Platform: ", when defined(emscripten): "WASM" else: "Native"
  echo "Audio backend: ", getAudioBackend()
  
  if isAudioPluginAvailable():
    echo "\nInitializing audio..."
    if initAudio():
      echo "Playing test tone..."
      playTone(440.0, 1.0, 0.5)  # A4 for 1 second
      stopAudio()
    else:
      echo "Failed to initialize audio"
  else:
    when not defined(emscripten):
      echo "\nAudio plugin not available"
      showAudioHelp()
