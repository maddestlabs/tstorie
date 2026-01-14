# Audio Plugin - Unified API for Native (miniaudio) and WASM (Web Audio)
# Build with: nim c --app:lib -d:release lib/audio_plugin.nim
# Output: libaudio_plugin.so (Linux), audio_plugin.dll (Windows), libaudio_plugin.dylib (macOS)

when not defined(js):
  # Native builds only - WASM doesn't need this plugin
  
  # For now, using stubs. In production, you'd link miniaudio
  # {.compile: "miniaudio_helper.c".}
  # or: nimble install miniaudio
  
  type
    AudioDevice* = object
      initialized: bool
      sampleRate: int
      channels: int
    
    AudioBuffer* = object
      data: seq[float32]
      frames: int
  
  # Stub implementations - replace with real miniaudio calls
  proc initAudioDevice*(): AudioDevice {.exportc, dynlib.} =
    echo "[Audio Plugin] Initializing audio device..."
    result.initialized = true
    result.sampleRate = 48000
    result.channels = 2
    echo "[Audio Plugin] Audio device initialized (48kHz, stereo)"
  
  proc closeAudioDevice*(device: var AudioDevice) {.exportc, dynlib.} =
    echo "[Audio Plugin] Closing audio device..."
    device.initialized = false
  
  proc playTone*(frequency: float32, duration: float32, volume: float32) {.exportc, dynlib.} =
    echo "[Audio Plugin] Playing tone: ", frequency, "Hz for ", duration, "s at ", volume, " volume"
    # In real implementation:
    # Generate sine wave at frequency
    # Queue audio buffer to miniaudio device
  
  proc playSample*(samples: ptr float32, frameCount: int) {.exportc, dynlib.} =
    echo "[Audio Plugin] Playing ", frameCount, " frames"
    # In real implementation:
    # Queue samples to miniaudio device
  
  proc stopAudio*() {.exportc, dynlib.} =
    echo "[Audio Plugin] Stopping audio"
    # In real implementation:
    # Stop miniaudio playback
  
  proc getPluginVersion*(): cstring {.exportc, dynlib.} =
    return "audio_plugin v1.0.0 (miniaudio backend)"
  
  proc isAudioAvailable*(): bool {.exportc, dynlib.} =
    return true

# Export C-compatible wrappers
{.push exportc, dynlib.}

proc audio_init_device(): cint =
  let device = initAudioDevice()
  return if device.initialized: 1 else: 0

proc audio_close_device() =
  var device: AudioDevice  # In real impl, this would be stored globally
  closeAudioDevice(device)

proc audio_play_tone(frequency: cfloat, duration: cfloat, volume: cfloat) =
  playTone(frequency, duration, volume)

proc audio_stop() =
  stopAudio()

{.pop.}
