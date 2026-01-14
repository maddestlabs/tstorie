# ================================================================
# AUDIO PLUGIN LOADER
# ================================================================
# Dynamic loader for audio plugin shared library
# This allows the main binary to stay small (~650KB) and only load
# the audio plugin (~520KB) when audio features are actually used

import std/[dynlib, os, strutils]
import audio_gen  # For AudioSample type

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
    getVersion: proc(): cstring {.cdecl.}
    isInitialized: proc(ctx: pointer): cint {.cdecl.}

var globalPlugin: AudioPluginHandle = nil

# ================================================================
# PLUGIN DISCOVERY
# ================================================================

proc findAudioPlugin*(): string =
  ## Search for audio plugin in common locations
  const pluginNames = when defined(windows):
    ["audio_plugin.dll", "lib/audio_plugin.dll", "./audio_plugin.dll"]
  elif defined(macos) or defined(macosx):
    ["libaudio_plugin.dylib", "lib/libaudio_plugin.dylib", "./libaudio_plugin.dylib"]
  else:
    ["libaudio_plugin.so", "lib/libaudio_plugin.so", "./libaudio_plugin.so"]
  
  for name in pluginNames:
    let path = if name.isAbsolute: name else: getCurrentDir() / name
    if fileExists(path):
      return path
  
  return ""

# ================================================================
# PLUGIN LOADING
# ================================================================

proc loadAudioPlugin*(path: string = ""): bool =
  ## Load the audio plugin dynamically
  if not globalPlugin.isNil:
    return true  # Already loaded
  
  let pluginPath = if path.len > 0: path else: findAudioPlugin()
  
  if pluginPath.len == 0 or not fileExists(pluginPath):
    echo "[Audio] Plugin not found. Build with: ./build-audio-plugin.sh"
    return false
  
  let lib = loadLib(pluginPath)
  if lib.isNil:
    echo "[Audio] Failed to load plugin from: ", pluginPath
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
  globalPlugin.getVersion = cast[type(globalPlugin.getVersion)](
    symAddr(lib, "audio_plugin_get_version"))
  globalPlugin.isInitialized = cast[type(globalPlugin.isInitialized)](
    symAddr(lib, "audio_plugin_is_initialized"))
  
  if globalPlugin.init.isNil or globalPlugin.playSample.isNil:
    echo "[Audio] Plugin missing required symbols"
    unloadLib(lib)
    globalPlugin = nil
    return false
  
  if not globalPlugin.getVersion.isNil:
    echo "[Audio] Plugin loaded: ", globalPlugin.getVersion(), " from ", pluginPath
  else:
    echo "[Audio] Plugin loaded from: ", pluginPath
  
  return true

# ================================================================
# PLUGIN INITIALIZATION
# ================================================================

proc initAudioPlugin*(sampleRate: int, channels: int): bool =
  ## Initialize the audio plugin
  if globalPlugin.isNil:
    if not loadAudioPlugin():
      return false
  
  globalPlugin.contextPtr = globalPlugin.init(sampleRate.cint, channels.cint)
  return not globalPlugin.contextPtr.isNil

proc isPluginInitialized*(): bool =
  ## Check if plugin is initialized
  if globalPlugin.isNil or globalPlugin.contextPtr.isNil:
    return false
  
  if not globalPlugin.isInitialized.isNil:
    return globalPlugin.isInitialized(globalPlugin.contextPtr) != 0
  
  return true

# ================================================================
# PLUGIN OPERATIONS
# ================================================================

proc playSamplePlugin*(sample: AudioSample, volume: float): bool =
  ## Play audio sample through plugin
  if globalPlugin.isNil or globalPlugin.contextPtr.isNil:
    return false
  
  if sample.data.len == 0:
    return false
  
  let dataPtr = cast[ptr UncheckedArray[float32]](unsafeAddr sample.data[0])
  let result = globalPlugin.playSample(
    globalPlugin.contextPtr,
    dataPtr,
    sample.data.len.cint,
    sample.channels.cint,
    sample.sampleRate.cint,
    volume.cfloat
  )
  
  return result == 0

proc stopAllPlugin*() =
  ## Stop all audio through plugin
  if not globalPlugin.isNil and not globalPlugin.contextPtr.isNil:
    globalPlugin.stopAll(globalPlugin.contextPtr)

proc registerSoundPlugin*(name: string, sample: AudioSample): bool =
  ## Register a sound in the plugin
  if globalPlugin.isNil or globalPlugin.contextPtr.isNil:
    return false
  
  if sample.data.len == 0:
    return false
  
  let dataPtr = cast[ptr UncheckedArray[float32]](unsafeAddr sample.data[0])
  let result = globalPlugin.registerSound(
    globalPlugin.contextPtr,
    name.cstring,
    dataPtr,
    sample.data.len.cint,
    sample.channels.cint,
    sample.sampleRate.cint
  )
  
  return result == 0

proc cleanupAudioPlugin*() =
  ## Clean up and unload plugin
  if not globalPlugin.isNil:
    if not globalPlugin.contextPtr.isNil and not globalPlugin.cleanup.isNil:
      globalPlugin.cleanup(globalPlugin.contextPtr)
      globalPlugin.contextPtr = nil
    
    unloadLib(globalPlugin.lib)
    globalPlugin = nil

# ================================================================
# UTILITY FUNCTIONS
# ================================================================

proc isPluginAvailable*(): bool =
  ## Check if audio plugin is available (file exists)
  return findAudioPlugin().len > 0

proc isPluginLoaded*(): bool =
  ## Check if plugin is currently loaded
  return not globalPlugin.isNil

proc getPluginPath*(): string =
  ## Get the path to the audio plugin (if found)
  return findAudioPlugin()
