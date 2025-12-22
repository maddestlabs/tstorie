# ================================================================
# AUDIO PLAYBACK SYSTEM
# ================================================================
# Platform-agnostic audio playback for procedurally generated sounds
# Uses miniaudio on native, Web Audio API on WASM

import audio_gen
import tables

when not defined(emscripten):
  # Native build - will use miniaudio
  # For now, this is a stub until we integrate miniaudio C bindings
  discard
else:
  # WASM build - use Web Audio API via JavaScript
  proc emAudioInit*() {.importc.}
  proc emAudioPlaySample*(data: ptr float32, length: cint, sampleRate: cint, 
                          volume: cfloat) {.importc.}
  proc emAudioStopAll*() {.importc.}

type
  AudioSystem* = ref object
    initialized: bool
    sampleRate*: int
    when not defined(emscripten):
      # Will add miniaudio device here later
      discard
    sounds*: Table[string, AudioSample]  # Named sound cache
  
  PlaybackHandle* = object
    id: int
    playing: bool

# ================================================================
# INITIALIZATION
# ================================================================

proc initAudio*(sampleRate: int = 44100): AudioSystem =
  ## Initialize the audio system
  result = new(AudioSystem)
  result.sampleRate = sampleRate
  result.sounds = initTable[string, AudioSample]()
  
  when defined(emscripten):
    emAudioInit()
    result.initialized = true
  else:
    # Native audio - for now just mark as initialized
    # TODO: Initialize miniaudio device when we add C bindings
    result.initialized = true
    echo "Audio system initialized (native stub - miniaudio pending)"

proc isReady*(sys: AudioSystem): bool =
  ## Check if audio system is ready
  return sys.initialized

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
    # Play via Web Audio API
    if sample.data.len > 0:
      emAudioPlaySample(unsafeAddr sample.data[0], cint(sample.data.len),
                       cint(sample.sampleRate), cfloat(volume))
      return PlaybackHandle(id: 0, playing: true)
  else:
    # Native playback - stub for now
    echo "Playing audio sample (", sample.data.len, " samples, ", 
         sample.sampleRate, "Hz) - native playback pending"
    # TODO: Queue sample for miniaudio playback
  
  return PlaybackHandle(id: 0, playing: false)

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
    # Native stop - stub
    discard

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
