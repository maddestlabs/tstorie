# ================================================================
# AUDIO PLUGIN IMPLEMENTATION
# ================================================================
# Shared library that provides miniaudio-based audio playback
# This isolates the ~520KB miniaudio dependency from the main binary
# Load dynamically only when audio is needed

import miniaudio_bindings
import audio_gen
import std/[tables, sequtils]

# ================================================================
# PLUGIN STATE
# ================================================================

type
  PluginAudioContext = ref object
    context: ma_context
    device: ma_device
    deviceConfig: ma_device_config
    currentSample: AudioSample
    currentPosition: int
    playbackQueue: seq[AudioSample]
    sounds: Table[string, AudioSample]
    sampleRate: int
    channels: int
    initialized: bool

var globalContext: PluginAudioContext = nil

# ================================================================
# MINIAUDIO CALLBACK (runs in plugin)
# ================================================================

proc audioDataCallback_plugin(pDevice: ptr ma_device, pOutput: pointer, 
                              pInput: pointer, frameCount: ma_uint32) {.cdecl.} =
  ## Callback that miniaudio calls to fill audio buffer
  ## This is called from the audio thread
  
  if globalContext.isNil or not globalContext.initialized:
    return
  
  # Cast output to float32 array
  let output = cast[ptr UncheckedArray[float32]](pOutput)
  let totalSamples = int(frameCount) * globalContext.channels
  
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
          output[i] = 0.0'f32
        return
    
    # Copy samples from current sample to output
    let remaining = globalContext.currentSample.data.len - globalContext.currentPosition
    let toCopy = min(remaining, totalSamples - outputIndex)
    
    for i in 0 ..< toCopy:
      output[outputIndex + i] = globalContext.currentSample.data[globalContext.currentPosition + i]
    
    globalContext.currentPosition += toCopy
    outputIndex += toCopy

# ================================================================
# C-COMPATIBLE EXPORTS (for dynamic loading)
# ================================================================

proc audio_plugin_init*(sampleRate: cint, channels: cint): pointer {.exportc, dynlib.} =
  ## Initialize audio device, return opaque context handle
  if not globalContext.isNil and globalContext.initialized:
    echo "[Audio Plugin] Already initialized"
    return cast[pointer](globalContext)
  
  globalContext = PluginAudioContext(
    sampleRate: int(sampleRate),
    channels: int(channels),
    currentSample: AudioSample(),
    currentPosition: 0,
    playbackQueue: @[],
    sounds: initTable[string, AudioSample](),
    initialized: false
  )
  
  # Initialize miniaudio context
  var initResult = ma_context_init(nil, 0, nil, addr globalContext.context)
  if initResult != MA_SUCCESS:
    echo "[Audio Plugin] Failed to initialize audio context: ", initResult
    return nil
  
  # Configure device
  globalContext.deviceConfig = ma_device_config_init(ma_device_type_playback)
  
  # Set callback and user data using helper function
  ma_device_config_set_callback(addr globalContext.deviceConfig, 
                               audioDataCallback_plugin, 
                               cast[pointer](globalContext))
  
  # Set playback format using helper function  
  ma_device_config_set_playback_format(addr globalContext.deviceConfig, 
                                      ma_format_f32, 
                                      ma_uint32(channels), 
                                      ma_uint32(sampleRate))
  
  # Performance optimizations for low latency
  ma_device_config_set_performance_profile(addr globalContext.deviceConfig, 
                                          ma_performance_profile_low_latency)
  ma_device_config_set_no_pre_silenced_output_buffer(addr globalContext.deviceConfig, 1)
  ma_device_config_set_no_clip(addr globalContext.deviceConfig, 1)
  ma_device_config_set_period_size(addr globalContext.deviceConfig, 512)
  
  # Initialize device
  initResult = ma_device_init(addr globalContext.context, 
                          addr globalContext.deviceConfig, 
                          addr globalContext.device)
  if initResult != MA_SUCCESS:
    echo "[Audio Plugin] Failed to initialize audio device: ", initResult
    ma_context_uninit(addr globalContext.context)
    return nil
  
  # Start device
  initResult = ma_device_start(addr globalContext.device)
  if initResult != MA_SUCCESS:
    echo "[Audio Plugin] Failed to start audio device: ", initResult
    ma_device_uninit(addr globalContext.device)
    ma_context_uninit(addr globalContext.context)
    return nil
  
  globalContext.initialized = true
  echo "[Audio Plugin] Initialized (", sampleRate, " Hz, ", channels, " channels)"
  
  return cast[pointer](globalContext)

proc audio_plugin_cleanup*(ctx: pointer) {.exportc, dynlib.} =
  ## Clean up audio device
  if ctx.isNil or globalContext.isNil:
    return
  
  if globalContext.initialized:
    discard ma_device_stop(addr globalContext.device)
    ma_device_uninit(addr globalContext.device)
    ma_context_uninit(addr globalContext.context)
    globalContext.initialized = false
    echo "[Audio Plugin] Cleaned up"
  
  globalContext = nil

proc audio_plugin_play_sample*(ctx: pointer, 
                               dataPtr: ptr UncheckedArray[float32],
                               dataLen: cint,
                               channels: cint,
                               sampleRate: cint,
                               volume: cfloat): cint {.exportc, dynlib.} =
  ## Add sample to playback queue
  if ctx.isNil or globalContext.isNil or not globalContext.initialized:
    return -1
  
  var sample = AudioSample(
    data: newSeq[float32](dataLen),
    sampleRate: int(sampleRate),
    channels: int(channels)
  )
  
  # Copy data with volume adjustment
  for i in 0 ..< int(dataLen):
    sample.data[i] = dataPtr[i] * float32(volume)
  
  # Convert mono to stereo if needed (device is stereo)
  if channels == 1 and globalContext.channels == 2:
    var stereoData = newSeq[float32](int(dataLen) * 2)
    for i in 0 ..< int(dataLen):
      stereoData[i * 2] = sample.data[i]
      stereoData[i * 2 + 1] = sample.data[i]
    sample.data = stereoData
    sample.channels = 2
  
  # Add to queue
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
    sampleRate: int(sampleRate),
    channels: int(channels)
  )
  
  for i in 0 ..< int(dataLen):
    sample.data[i] = dataPtr[i]
  
  globalContext.sounds[name] = sample
  return 0

proc audio_plugin_get_version*(): cstring {.exportc, dynlib.} =
  ## Get plugin version string
  return "audio_plugin v1.0.0 (miniaudio)"

proc audio_plugin_is_initialized*(ctx: pointer): cint {.exportc, dynlib.} =
  ## Check if plugin is initialized
  if ctx.isNil or globalContext.isNil:
    return 0
  return if globalContext.initialized: 1 else: 0
