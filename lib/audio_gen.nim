# ================================================================
# PROCEDURAL AUDIO GENERATION
# ================================================================
# Foundation for generating sound effects procedurally
# Similar to sfxr/bfxr but as a flexible building block

import math, random

type
  Waveform* = enum
    wfSine
    wfSquare
    wfSawtooth
    wfTriangle
    wfNoise
    wfPulse
  
  Envelope* = object
    attack*: float   # seconds
    decay*: float    # seconds
    sustain*: float  # 0.0 to 1.0
    release*: float  # seconds
  
  AudioSample* = object
    data*: seq[float32]  # PCM data, -1.0 to 1.0
    sampleRate*: int     # typically 44100 or 48000
    channels*: int       # 1 for mono, 2 for stereo
  
  OscillatorState* = object
    phase: float
    
  NoiseState* = object
    last: float

# ================================================================
# CORE OSCILLATORS
# ================================================================

const PI2 = 2.0 * PI

proc generateSine*(freq: float, sampleRate: int): float =
  ## Generate a single sine wave sample (used internally)
  sin(freq * PI2)

proc oscillatorStep*(state: var OscillatorState, waveform: Waveform, 
                     frequency: float, sampleRate: float, 
                     pulseWidth: float = 0.5): float =
  ## Generate one sample from an oscillator
  ## pulseWidth only used for wfPulse (0.0 to 1.0, default 0.5 = square)
  
  let phaseIncrement = frequency / sampleRate
  
  result = case waveform
  of wfSine:
    sin(state.phase * PI2)
  
  of wfSquare:
    if state.phase < 0.5: 1.0 else: -1.0
  
  of wfSawtooth:
    2.0 * state.phase - 1.0
  
  of wfTriangle:
    if state.phase < 0.5:
      4.0 * state.phase - 1.0
    else:
      3.0 - 4.0 * state.phase
  
  of wfPulse:
    if state.phase < pulseWidth: 1.0 else: -1.0
  
  of wfNoise:
    # White noise - generate new random value each sample
    rand(-1.0..1.0)
  
  # Advance phase
  state.phase += phaseIncrement
  if state.phase >= 1.0:
    state.phase -= 1.0

proc applyEnvelope*(sample: float, envelope: Envelope, time: float, 
                   duration: float): float =
  ## Apply ADSR envelope to a sample
  ## time: current time in the sound
  ## duration: total duration of the sound
  
  let attackTime = envelope.attack
  let decayTime = envelope.decay
  let releaseStart = duration - envelope.release
  
  var amplitude = 1.0
  
  if time < attackTime:
    # Attack phase: fade in
    amplitude = time / attackTime
  
  elif time < attackTime + decayTime:
    # Decay phase: fade to sustain level
    let decayProgress = (time - attackTime) / decayTime
    amplitude = 1.0 - (1.0 - envelope.sustain) * decayProgress
  
  elif time < releaseStart:
    # Sustain phase: hold at sustain level
    amplitude = envelope.sustain
  
  else:
    # Release phase: fade out
    let releaseProgress = (time - releaseStart) / envelope.release
    amplitude = envelope.sustain * (1.0 - releaseProgress)
  
  return sample * amplitude

# ================================================================
# HIGH-LEVEL SOUND GENERATION
# ================================================================

proc generateTone*(frequency: float, duration: float, waveform: Waveform = wfSine,
                  amplitude: float = 0.5, sampleRate: int = 44100,
                  envelope: Envelope = Envelope(attack: 0.01, decay: 0.05, 
                                               sustain: 0.7, release: 0.1),
                  pulseWidth: float = 0.5): AudioSample =
  ## Generate a simple tone with envelope
  result.sampleRate = sampleRate
  result.channels = 1
  
  let numSamples = int(duration * float(sampleRate))
  result.data = newSeq[float32](numSamples)
  
  var osc = OscillatorState()
  
  for i in 0 ..< numSamples:
    let time = float(i) / float(sampleRate)
    var sample = oscillatorStep(osc, waveform, frequency, float(sampleRate), pulseWidth)
    sample = applyEnvelope(sample, envelope, time, duration)
    result.data[i] = float32(sample * amplitude)

proc generateFrequencySweep*(startFreq: float, endFreq: float, duration: float,
                            waveform: Waveform = wfSquare, amplitude: float = 0.5,
                            sampleRate: int = 44100,
                            envelope: Envelope = Envelope(attack: 0.001, decay: 0.05,
                                                         sustain: 0.8, release: 0.1)): AudioSample =
  ## Generate a frequency sweep (slide) - great for jump/laser sounds
  result.sampleRate = sampleRate
  result.channels = 1
  
  let numSamples = int(duration * float(sampleRate))
  result.data = newSeq[float32](numSamples)
  
  var osc = OscillatorState()
  
  for i in 0 ..< numSamples:
    let time = float(i) / float(sampleRate)
    let progress = time / duration
    
    # Linear frequency interpolation
    let currentFreq = startFreq + (endFreq - startFreq) * progress
    
    var sample = oscillatorStep(osc, waveform, currentFreq, float(sampleRate))
    sample = applyEnvelope(sample, envelope, time, duration)
    result.data[i] = float32(sample * amplitude)

proc generateNoiseBurst*(duration: float, amplitude: float = 0.3,
                        sampleRate: int = 44100,
                        envelope: Envelope = Envelope(attack: 0.001, decay: 0.05,
                                                     sustain: 0.0, release: 0.05)): AudioSample =
  ## Generate a noise burst - great for explosions/hits
  result.sampleRate = sampleRate
  result.channels = 1
  
  let numSamples = int(duration * float(sampleRate))
  result.data = newSeq[float32](numSamples)
  
  var osc = OscillatorState()
  
  for i in 0 ..< numSamples:
    let time = float(i) / float(sampleRate)
    var sample = oscillatorStep(osc, wfNoise, 0, float(sampleRate))
    sample = applyEnvelope(sample, envelope, time, duration)
    result.data[i] = float32(sample * amplitude)

proc generateBleep*(frequency: float = 440.0, duration: float = 0.1,
                   amplitude: float = 0.4, sampleRate: int = 44100): AudioSample =
  ## Generate a simple short bleep - UI feedback, pickups
  let env = Envelope(attack: 0.001, decay: 0.02, sustain: 0.5, release: 0.05)
  return generateTone(frequency, duration, wfSquare, amplitude, sampleRate, env)

proc generateJump*(sampleRate: int = 44100): AudioSample =
  ## Generate a jump sound effect
  generateFrequencySweep(200.0, 600.0, 0.2, wfSquare, 0.4, sampleRate)

proc generateLanding*(sampleRate: int = 44100): AudioSample =
  ## Generate a landing/thud sound
  generateFrequencySweep(300.0, 80.0, 0.15, wfSquare, 0.5, sampleRate)

proc generateHit*(sampleRate: int = 44100): AudioSample =
  ## Generate a hit/damage sound
  let env = Envelope(attack: 0.001, decay: 0.1, sustain: 0.0, release: 0.05)
  generateNoiseBurst(0.12, 0.4, sampleRate, env)

proc generatePowerUp*(sampleRate: int = 44100): AudioSample =
  ## Generate a power-up/collect sound
  generateFrequencySweep(200.0, 800.0, 0.3, wfSine, 0.4, sampleRate)

proc generateLaser*(sampleRate: int = 44100): AudioSample =
  ## Generate a laser/shoot sound
  let env = Envelope(attack: 0.001, decay: 0.05, sustain: 0.3, release: 0.05)
  generateFrequencySweep(800.0, 200.0, 0.15, wfSawtooth, 0.35, sampleRate, env)

# ================================================================
# SAMPLE MANIPULATION
# ================================================================

proc mixSamples*(samples: varargs[AudioSample], volume: float = 1.0): AudioSample =
  ## Mix multiple audio samples together
  if samples.len == 0:
    return AudioSample(sampleRate: 44100, channels: 1, data: @[])
  
  result.sampleRate = samples[0].sampleRate
  result.channels = samples[0].channels
  
  # Find longest sample
  var maxLen = 0
  for s in samples:
    if s.data.len > maxLen:
      maxLen = s.data.len
  
  result.data = newSeq[float32](maxLen)
  
  # Mix samples
  for i in 0 ..< maxLen:
    var mixed = 0.0'f32
    for s in samples:
      if i < s.data.len:
        mixed += s.data[i]
    result.data[i] = mixed * float32(volume / float(samples.len))

proc applySampleVolume*(sample: var AudioSample, volume: float) =
  ## Apply volume to a sample (in-place)
  for i in 0 ..< sample.data.len:
    sample.data[i] *= float32(volume)

proc concatenateSamples*(samples: varargs[AudioSample]): AudioSample =
  ## Concatenate multiple samples into one
  if samples.len == 0:
    return AudioSample(sampleRate: 44100, channels: 1, data: @[])
  
  result.sampleRate = samples[0].sampleRate
  result.channels = samples[0].channels
  result.data = @[]
  
  for s in samples:
    result.data.add(s.data)

# ================================================================
# UTILITY
# ================================================================

proc getDuration*(sample: AudioSample): float =
  ## Get the duration of a sample in seconds
  if sample.sampleRate == 0:
    return 0.0
  return float(sample.data.len) / float(sample.sampleRate)

proc resample*(sample: AudioSample, newSampleRate: int): AudioSample =
  ## Resample audio to a different sample rate (simple linear interpolation)
  result.sampleRate = newSampleRate
  result.channels = sample.channels
  
  let ratio = float(sample.sampleRate) / float(newSampleRate)
  let newLen = int(float(sample.data.len) / ratio)
  result.data = newSeq[float32](newLen)
  
  for i in 0 ..< newLen:
    let srcPos = float(i) * ratio
    let srcIdx = int(srcPos)
    let frac = srcPos - float(srcIdx)
    
    if srcIdx + 1 < sample.data.len:
      # Linear interpolation
      result.data[i] = sample.data[srcIdx] * float32(1.0 - frac) + 
                       sample.data[srcIdx + 1] * float32(frac)
    else:
      result.data[i] = sample.data[srcIdx]
