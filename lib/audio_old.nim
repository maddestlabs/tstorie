# ================================================================
# AUDIO PLAYBACK SYSTEM (DEPRECATED)
# ================================================================
# ⚠️ DEPRECATED: This file has been replaced by the new lib/audio.nim
# 
# The old multi-module architecture has been simplified:
# OLD: audio.nim + audio_plugin_loader.nim + audio_plugin_impl.nim + web/audio_bridge.js
# NEW: Single audio.nim with embedded platform-specific code
#
# This file is kept for reference only. Use: import lib/audio
# ================================================================
# Platform-agnostic audio playback for procedurally generated sounds
# Uses Web Audio API for WASM, miniaudio for native builds
#
# This module provides TWO APIs:
# 1. Simple procedural API (legacy): playTone(), playJump(), etc.
# 2. Node-based API: Full Web Audio-style node graph (see audio_nodes.nim)
#
# NIMINI BINDINGS:
# No functions are auto-exposed. Audio system uses global state and C FFI.
# See miniaudio_bindings.nim for low-level C bindings.
# Most audio functionality is accessed through runtime-specific wrappers.

import audio_gen
import tables

# Note: audio_nodes is NOT exported by default to keep binaries small
# It imports miniaudio_bindings directly, which would bloat the binary
# If you need the node-based API, import it explicitly:
#   import lib/audio_nodes

when not defined(emscripten):
  import audio_plugin_loader  # ← Small loader instead of miniaudio_bindings
else:
  # WASM build - use Web Audio API via JavaScript bridge
  proc emAudioInit*() {.importc.}
  proc emAudioPlaySample*(data: ptr float32, length: cint, sampleRate: cint, 
                          volume: cfloat) {.importc.}
  proc emAudioStopAll*() {.importc.}

type
  AudioSystem* = ref object
    initialized: bool
    sampleRate*: int
    when not defined(emscripten):
      pluginLoaded: bool
      # Plugin maintains its own internal state
    sounds*: Table[string, AudioSample]  # Named sound cache
  
  PlaybackHandle* = object
    id: int
    playing: bool

# ================================================================
# NATIVE AUDIO (PLUGIN-BASED)
# ================================================================

when not defined(emscripten):
  proc ensurePluginLoaded(sys: AudioSystem): bool =
    ## Lazy-load plugin on first audio operation
    if not sys.pluginLoaded:
      if not loadAudioPlugin():
        echo "Warning: Audio plugin not available. Build with ./build-audio-plugin.sh"
        return false
      
      if not initAudioPlugin(sys.sampleRate, 2):  # Always use stereo for simplicity
        echo "Warning: Failed to initialize audio plugin"
        return false
      
      sys.pluginLoaded = true
      echo "Audio plugin initialized (", sys.sampleRate, " Hz, stereo)"
    
    return sys.pluginLoaded

# ================================================================
# INITIALIZATION
# ================================================================

proc initAudio*(sampleRate: int = 44100): AudioSystem =
  ## Initialize the audio system
  result = new(AudioSystem)
  result.sampleRate = sampleRate
  result.sounds = initTable[string, AudioSample]()
  
  when defined(emscripten):
    # WASM: Use Web Audio API
    emAudioInit()
    result.initialized = true
    echo "Audio system initialized with Web Audio API (", sampleRate, " Hz)"
  else:
    # Native: Plugin will be loaded on first use (lazy loading)
    result.pluginLoaded = false
    result.initialized = true  # System is "initialized", plugin loads on demand
    echo "Audio system initialized (plugin will load on first use)"

proc isReady*(sys: AudioSystem): bool =
  ## Check if audio system is ready
  return sys.initialized

proc cleanup*(sys: AudioSystem) =
  ## Clean up audio system resources
  when not defined(emscripten):
    if sys.pluginLoaded:
      cleanupAudioPlugin()
      sys.pluginLoaded = false
    sys.initialized = false

# ================================================================
# SOUND REGISTRATION
# ================================================================

proc registerSound*(sys: AudioSystem, name: string, sample: AudioSample) =
  ## Register a generated sound with a name for easy playback
  sys.sounds[name] = sample

proc unregisterSound*(sys: AudioSystem, name: string) =
  ## Remove a registered sound
  sys.sounds.del(name)

proc hasSound*(sys: AudioSystem, name: string): bool =
  ## Check if a sound is registered
  return sys.sounds.hasKey(name)

proc clearSounds*(sys: AudioSystem) =
  ## Clear all registered sounds
  sys.sounds.clear()

# ================================================================
# PLAYBACK
# ================================================================

proc playSample*(sys: AudioSystem, sample: AudioSample, volume: float = 1.0): PlaybackHandle =
  ## Play a procedurally generated audio sample
  ## Returns a handle (for future stop/control functionality)
  
  if not sys.initialized:
    echo "Warning: Audio system not initialized"
    return PlaybackHandle(id: -1, playing: false)
  
  when defined(emscripten):
    # WASM: Use Web Audio API directly
    if sample.data.len > 0:
      emAudioPlaySample(unsafeAddr sample.data[0], cint(sample.data.len),
                       cint(sample.sampleRate), cfloat(volume))
      return PlaybackHandle(id: 0, playing: true)
  else:
    # Native: Use plugin
    if not sys.ensurePluginLoaded():
      return PlaybackHandle(id: -1, playing: false)
    
    # Apply volume to the sample (create a copy to avoid modifying original)
    var adjustedSample = AudioSample(
      data: newSeq[float32](sample.data.len),
      sampleRate: sample.sampleRate,
      channels: sample.channels
    )
    
    for i in 0 ..< sample.data.len:
      adjustedSample.data[i] = sample.data[i] * float32(volume)
    
    # Convert to device sample rate if needed
    if sample.sampleRate != sys.sampleRate:
      echo "Warning: Sample rate mismatch. Sample: ", sample.sampleRate, ", Device: ", sys.sampleRate
      # Could use audio_gen.resample here
    
    # Convert mono to stereo if needed (device is stereo)
    if sample.channels == 1:
      # Duplicate mono to both channels
      var stereoData = newSeq[float32](sample.data.len * 2)
      for i in 0 ..< sample.data.len:
        stereoData[i * 2] = adjustedSample.data[i]
        stereoData[i * 2 + 1] = adjustedSample.data[i]
      adjustedSample.data = stereoData
      adjustedSample.channels = 2
    
    # Play through plugin
    if playSamplePlugin(adjustedSample, 1.0):  # volume already applied
      return PlaybackHandle(id: 0, playing: true)
    else:
      return PlaybackHandle(id: -1, playing: false)
  
  return PlaybackHandle(id: -1, playing: false)

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
# CONVENIENCE FUNCTIONS
# ================================================================

proc playTone*(sys: AudioSystem, frequency: float, duration: float, 
              waveform: Waveform = wfSine, volume: float = 0.5) =
  ## Generate and immediately play a tone
  let sample = generateTone(frequency, duration, waveform, volume, sys.sampleRate)
  discard sys.playSample(sample, 1.0)

proc playBleep*(sys: AudioSystem, frequency: float = 440.0, volume: float = 0.4) =
  ## Quick bleep sound
  let sample = generateBleep(frequency, 0.1, volume, sys.sampleRate)
  discard sys.playSample(sample, 1.0)

proc playJump*(sys: AudioSystem, volume: float = 0.4) =
  ## Play jump sound effect
  let sample = generateJump(sys.sampleRate)
  discard sys.playSample(sample, volume)

proc playLanding*(sys: AudioSystem, volume: float = 0.5) =
  ## Play landing sound effect
  let sample = generateLanding(sys.sampleRate)
  discard sys.playSample(sample, volume)

proc playHit*(sys: AudioSystem, volume: float = 0.4) =
  ## Play hit/damage sound
  let sample = generateHit(sys.sampleRate)
  discard sys.playSample(sample, volume)

proc playPowerUp*(sys: AudioSystem, volume: float = 0.4) =
  ## Play power-up sound
  let sample = generatePowerUp(sys.sampleRate)
  discard sys.playSample(sample, volume)

proc playLaser*(sys: AudioSystem, volume: float = 0.35) =
  ## Play laser sound
  let sample = generateLaser(sys.sampleRate)
  discard sys.playSample(sample, volume)
