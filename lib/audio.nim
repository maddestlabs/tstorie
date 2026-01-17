# ================================================================
# TSTORIE UNIFIED AUDIO SYSTEM
# ================================================================
# Single source of truth for all audio functionality
# - WASM builds: Embedded WebAudio API (via {.emit.})
# - Native builds: Direct miniaudio integration
# 
# This replaces the old multi-module architecture:
# ✓ Consolidates: audio.nim, audio_plugin_loader.nim, audio_plugin_impl.nim
# ✓ Embeds: web/audio_bridge.js directly into WASM build
# ✗ Removes: audio_nodes.nim (incomplete, unused)

import audio_gen
export audio_gen  # Re-export for convenience

# ================================================================
# PLATFORM-SPECIFIC IMPLEMENTATIONS
# ================================================================

when defined(emscripten):
  # ================================================================
  # WASM: WEBAUDIO API (EXTERNAL JS BRIDGE)
  # ================================================================
  # Using web/audio_bridge.js for JavaScript WebAudio implementation
  
  # Import JavaScript functions from audio_bridge.js
  proc emAudioInit() {.importc.}
  proc emAudioPlaySample(data: ptr float32, len: cint, sampleRate: cint, 
                         volume: cfloat) {.importc.}
  proc emAudioStopAll() {.importc.}

else:
  # ================================================================
  # NATIVE: MINIAUDIO (DIRECT INTEGRATION)
  # ================================================================
  
  import os
  
  # Minimal miniaudio bindings (only what we need)
  when defined(windows):
    {.passL: "-lwinmm -lole32".}
  elif defined(macosx):
    {.passL: "-framework CoreAudio -framework AudioToolbox".}
  elif defined(linux):
    {.passL: "-lpthread -lm -ldl".}
  
  {.passC: "-I" & currentSourcePath.parentDir().}
  
  # Only compile helper once - use guard to prevent duplicate compilation
  when not defined(tStorieMiniaudioHelperCompiled):
    {.define: tStorieMiniaudioHelperCompiled.}
    {.compile: "miniaudio_helper.c".}
  
  type
    ma_result = cint
    ma_uint32 = uint32
    ma_bool32 = uint32
    
    ma_device_type {.size: sizeof(cint).} = enum
      ma_device_type_playback = 1
    
    ma_format {.size: sizeof(cint).} = enum
      ma_format_f32 = 5
    
    ma_context {.importc: "ma_context", header: "miniaudio.h", incompleteStruct.} = object
    ma_device {.importc: "ma_device", header: "miniaudio.h", incompleteStruct.} = object
    ma_device_config {.importc: "ma_device_config", header: "miniaudio.h", bycopy.} = object
    
    ma_device_data_proc = proc(pDevice: ptr ma_device, pOutput: pointer,
                               pInput: pointer, frameCount: ma_uint32) {.cdecl.}
  
  const MA_SUCCESS = 0
  
  proc ma_context_init(backends: pointer, backendCount: ma_uint32,
                      config: pointer, ctx: ptr ma_context): ma_result 
    {.importc, header: "miniaudio.h".}
  
  proc ma_context_uninit(ctx: ptr ma_context) 
    {.importc, header: "miniaudio.h".}
  
  proc ma_device_config_init(deviceType: ma_device_type): ma_device_config 
    {.importc, header: "miniaudio.h".}
  
  proc ma_device_init(ctx: ptr ma_context, config: ptr ma_device_config,
                     device: ptr ma_device): ma_result 
    {.importc, header: "miniaudio.h".}
  
  proc ma_device_uninit(device: ptr ma_device) 
    {.importc, header: "miniaudio.h".}
  
  proc ma_device_start(device: ptr ma_device): ma_result 
    {.importc, header: "miniaudio.h".}
  
  proc ma_device_stop(device: ptr ma_device): ma_result 
    {.importc, header: "miniaudio.h".}
  
  # Helper functions from miniaudio_helper.c
  proc ma_device_config_set_callback(config: ptr ma_device_config, 
                                     callback: ma_device_data_proc,
                                     userData: pointer) 
    {.importc, header: "miniaudio.h".}
  
  proc ma_device_config_set_playback_format(config: ptr ma_device_config,
                                           format: ma_format,
                                           channels: ma_uint32,
                                           sampleRate: ma_uint32) 
    {.importc, header: "miniaudio.h".}
  
  # Global audio state
  var
    nativeContext: ma_context
    nativeDevice: ma_device
    nativeInitialized = false
    nativeSampleQueue: seq[AudioSample]
    nativeQueuePos: int = 0
    nativeCurrentSampleRate: int = 44100
  
  # Thread synchronization for audio queue
  import std/locks
  var nativeQueueLock: Lock
  
  proc initQueueLock() =
    initLock(nativeQueueLock)
  
  proc deinitQueueLock() =
    deinitLock(nativeQueueLock)

  # Miniaudio callback - called when device needs audio data
  proc nativeAudioCallback(pDevice: ptr ma_device, pOutput: pointer,
                          pInput: pointer, frameCount: ma_uint32) {.cdecl.} =
    acquire(nativeQueueLock)
    defer: release(nativeQueueLock)
    
    if nativeSampleQueue.len == 0:
      # No audio playing - output silence
      let outputBuf = cast[ptr UncheckedArray[float32]](pOutput)
      for i in 0 ..< int(frameCount) * 2:  # Stereo
        outputBuf[i] = 0.0
      return
    
    let outputBuf = cast[ptr UncheckedArray[float32]](pOutput)
    var outIdx = 0
    
    for i in 0 ..< int(frameCount):
      if nativeSampleQueue.len > 0:
        let sample = nativeSampleQueue[0]
        
        if nativeQueuePos < sample.data.len:
          let value = sample.data[nativeQueuePos]
          # Stereo output - duplicate mono
          outputBuf[outIdx] = value
          outputBuf[outIdx + 1] = value
          nativeQueuePos += 1
        else:
          # Sample finished, remove from queue
          nativeSampleQueue.delete(0)
          nativeQueuePos = 0
          outputBuf[outIdx] = 0.0
          outputBuf[outIdx + 1] = 0.0
      else:
        outputBuf[outIdx] = 0.0
        outputBuf[outIdx + 1] = 0.0
      
      outIdx += 2

# ================================================================
# UNIFIED AUDIO SYSTEM TYPE
# ================================================================

type
  AudioSystem* = ref object
    initialized: bool
    sampleRate*: int

# ================================================================
# INITIALIZATION & CLEANUP
# ================================================================

proc initAudio*(sampleRate: int = 44100): AudioSystem =
  ## Initialize the audio system
  result = AudioSystem(
    initialized: false,
    sampleRate: sampleRate
  )
  
  when defined(emscripten):
    emAudioInit()
    result.initialized = true
    echo "TStorie Audio: WebAudio initialized (", sampleRate, " Hz)"
  
  else:
    # Initialize miniaudio
    if nativeInitialized:
      result.initialized = true
      return
    
    # Initialize queue lock
    initQueueLock()
    
    var contextResult = ma_context_init(nil, 0, nil, addr nativeContext)
    if contextResult != MA_SUCCESS:
      echo "TStorie Audio: Failed to init context"
      return
    
    var deviceConfig = ma_device_config_init(ma_device_type_playback)
    
    # Configure device
    ma_device_config_set_playback_format(addr deviceConfig, ma_format_f32, 2, ma_uint32(sampleRate))
    ma_device_config_set_callback(addr deviceConfig, nativeAudioCallback, nil)
    
    var deviceResult = ma_device_init(addr nativeContext, addr deviceConfig, addr nativeDevice)
    if deviceResult != MA_SUCCESS:
      echo "TStorie Audio: Failed to init device"
      ma_context_uninit(addr nativeContext)
      return
    
    if ma_device_start(addr nativeDevice) != MA_SUCCESS:
      echo "TStorie Audio: Failed to start device"
      ma_device_uninit(addr nativeDevice)
      ma_context_uninit(addr nativeContext)
      return
    
    nativeInitialized = true
    nativeCurrentSampleRate = sampleRate
    nativeSampleQueue = @[]
    nativeQueuePos = 0
    
    result.initialized = true
    echo "TStorie Audio: miniaudio initialized (", sampleRate, " Hz)"

proc cleanup*(sys: AudioSystem) =
  ## Clean up audio resources
  if not sys.initialized:
    return
  
  when not defined(emscripten):
    if nativeInitialized:
      discard ma_device_stop(addr nativeDevice)
      ma_device_uninit(addr nativeDevice)
      ma_context_uninit(addr nativeContext)
      deinitQueueLock()
      nativeInitialized = false
      nativeSampleQueue = @[]
  
  sys.initialized = false

proc isReady*(sys: AudioSystem): bool =
  ## Check if audio system is ready
  return sys.initialized

# ================================================================
# PLAYBACK
# ================================================================

proc playSample*(sys: AudioSystem, sample: AudioSample, volume: float = 1.0) =
  ## Play a procedurally generated audio sample
  if not sys.initialized:
    echo "TStorie Audio: Not initialized"
    return
  
  if sample.data.len == 0:
    return
  
  when defined(emscripten):
    emAudioPlaySample(
      unsafeAddr sample.data[0],
      cint(sample.data.len),
      cint(sample.sampleRate),
      cfloat(volume)
    )
  
  else:
    # Add to native playback queue (thread-safe)
    var adjustedSample = sample
    
    # Apply volume
    if volume != 1.0:
      adjustedSample.data = newSeq[float32](sample.data.len)
      for i in 0 ..< sample.data.len:
        adjustedSample.data[i] = sample.data[i] * float32(volume)
    
    acquire(nativeQueueLock)
    nativeSampleQueue.add(adjustedSample)
    release(nativeQueueLock)

proc stopAll*(sys: AudioSystem) =
  ## Stop all currently playing audio
  if not sys.initialized:
    return
  
  when defined(emscripten):
    emAudioStopAll()
  else:
    acquire(nativeQueueLock)
    nativeSampleQueue = @[]
    nativeQueuePos = 0
    release(nativeQueueLock)

# ================================================================
# CONVENIENCE FUNCTIONS (PROCEDURAL API)
# ================================================================

proc playTone*(sys: AudioSystem, frequency: float, duration: float, 
              waveform: Waveform = wfSine, volume: float = 0.5) =
  ## Generate and play a tone
  let sample = generateTone(frequency, duration, waveform, volume, sys.sampleRate)
  sys.playSample(sample, 1.0)

proc playBleep*(sys: AudioSystem, frequency: float = 440.0, volume: float = 0.4) =
  ## Quick bleep sound
  let sample = generateBleep(frequency, 0.1, volume, sys.sampleRate)
  sys.playSample(sample, 1.0)

proc playJump*(sys: AudioSystem, volume: float = 0.4) =
  ## Play jump sound effect
  let sample = generateJump(sys.sampleRate)
  sys.playSample(sample, volume)

proc playLanding*(sys: AudioSystem, volume: float = 0.5) =
  ## Play landing sound effect
  let sample = generateLanding(sys.sampleRate)
  sys.playSample(sample, volume)

proc playHit*(sys: AudioSystem, volume: float = 0.4) =
  ## Play hit/damage sound
  let sample = generateHit(sys.sampleRate)
  sys.playSample(sample, volume)

proc playPowerUp*(sys: AudioSystem, volume: float = 0.4) =
  ## Play power-up sound
  let sample = generatePowerUp(sys.sampleRate)
  sys.playSample(sample, volume)

proc playLaser*(sys: AudioSystem, volume: float = 0.35) =
  ## Play laser sound
  let sample = generateLaser(sys.sampleRate)
  sys.playSample(sample, volume)
