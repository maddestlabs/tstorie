# ================================================================
# AUDIO PLAYBACK SYSTEM
# ================================================================
# Platform-agnostic audio playback for procedurally generated sounds
# Uses Web Audio API for WASM, miniaudio for native builds
#
# This module provides TWO APIs:
# 1. Simple procedural API (legacy): playTone(), playJump(), etc.
# 2. Node-based API: Full Web Audio-style node graph (see audio_nodes.nim)

import audio_gen
import tables

# Export the node-based API
import audio_nodes
export audio_nodes

when not defined(emscripten):
  import miniaudio_bindings
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
      context: ma_context
      device: ma_device
      deviceConfig: ma_device_config
      playbackQueue: seq[AudioSample]  # Simple queue for mixing
      currentSample: AudioSample
      currentPosition: int
    sounds*: Table[string, AudioSample]  # Named sound cache
  
  PlaybackHandle* = object
    id: int
    playing: bool

# ================================================================
# NATIVE AUDIO (MINIAUDIO)
# ================================================================

when not defined(emscripten):
  proc audioDataCallback(pDevice: ptr ma_device, pOutput: pointer, 
                        pInput: pointer, frameCount: ma_uint32) {.cdecl.} =
    ## Callback that miniaudio calls to fill audio buffer
    ## This is called from the audio thread
    
    # Get our AudioSystem from the device's user data
    let sys = cast[AudioSystem](ma_device_get_user_data(pDevice))
    
    # Cast output to float32 array
    let output = cast[ptr UncheckedArray[float32]](pOutput)
    
    # Fill with silence by default
    for i in 0 ..< int(frameCount):
      output[i] = 0.0'f32
    
    # If we have a current sample, mix it in
    if sys.currentSample.data.len > 0 and sys.currentPosition < sys.currentSample.data.len:
      let samplesToWrite = min(int(frameCount), sys.currentSample.data.len - sys.currentPosition)
      
      for i in 0 ..< samplesToWrite:
        output[i] = sys.currentSample.data[sys.currentPosition + i]
      
      sys.currentPosition += samplesToWrite
      
      # If we've finished this sample, move to next in queue
      if sys.currentPosition >= sys.currentSample.data.len:
        if sys.playbackQueue.len > 0:
          sys.currentSample = sys.playbackQueue[0]
          sys.playbackQueue.delete(0)
          sys.currentPosition = 0
        else:
          sys.currentSample = AudioSample()
          sys.currentPosition = 0

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
    # Native: Use miniaudio
    result.playbackQueue = @[]
    result.currentSample = AudioSample()
    result.currentPosition = 0
    
    # Initialize miniaudio context (backend)
    var contextResult = ma_context_init(nil, 0, nil, addr result.context)
    if contextResult != MA_SUCCESS:
      echo "Warning: Failed to initialize miniaudio context: ", contextResult
      return result
    
    # Configure the device for playback
    result.deviceConfig = ma_device_config_init(ma_device_type_playback)
    
    # Set callback and user data using helper function
    ma_device_config_set_callback(addr result.deviceConfig, audioDataCallback, cast[pointer](result))
    
    # Set playback format using helper function  
    ma_device_config_set_playback_format(addr result.deviceConfig, ma_format_f32, 2, ma_uint32(sampleRate))
    
    # Performance optimizations for low latency
    ma_device_config_set_performance_profile(addr result.deviceConfig, ma_performance_profile_low_latency)
    ma_device_config_set_no_pre_silenced_output_buffer(addr result.deviceConfig, 1)  # Skip silence init
    ma_device_config_set_no_clip(addr result.deviceConfig, 1)  # We control our output, no clipping needed
    ma_device_config_set_period_size(addr result.deviceConfig, 512)  # ~11.6ms at 44100Hz
    
    # Initialize the device
    var deviceResult = ma_device_init(addr result.context, addr result.deviceConfig, addr result.device)
    if deviceResult != MA_SUCCESS:
      echo "Warning: Failed to initialize miniaudio device: ", deviceResult
      ma_context_uninit(addr result.context)
      return result
    
    # Start the device
    var startResult = ma_device_start(addr result.device)
    if startResult != MA_SUCCESS:
      echo "Warning: Failed to start miniaudio device: ", startResult
      ma_device_uninit(addr result.device)
      ma_context_uninit(addr result.context)
      return result
    
    result.initialized = true
    echo "Audio system initialized with miniaudio (", sampleRate, " Hz)"

proc isReady*(sys: AudioSystem): bool =
  ## Check if audio system is ready
  return sys.initialized

proc cleanup*(sys: AudioSystem) =
  ## Clean up audio system resources
  when not defined(emscripten):
    if sys.initialized:
      discard ma_device_stop(addr sys.device)
      ma_device_uninit(addr sys.device)
      ma_context_uninit(addr sys.context)
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
    # Native: Use miniaudio with callback
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
    
    # Add to playback queue
    if sys.currentSample.data.len == 0 or sys.currentPosition >= sys.currentSample.data.len:
      sys.currentSample = adjustedSample
      sys.currentPosition = 0
    else:
      sys.playbackQueue.add(adjustedSample)
    
    return PlaybackHandle(id: 0, playing: true)
  
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
    sys.currentSample = AudioSample()
    sys.currentPosition = 0
    sys.playbackQueue = @[]

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
