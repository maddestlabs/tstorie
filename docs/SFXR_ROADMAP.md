# Building an sfxr-Style Sound Generator

This guide shows how to build a full sfxr/bfxr-style sound effect generator using TStorie's audio foundation.

## What is sfxr?

sfxr (and its successor bfxr) is a procedural sound effect generator created by DrPetter. It became the standard tool for indie game developers to create retro-style sound effects quickly.

## Core Concept

sfxr uses a set of **parameters** that control various aspects of sound generation:

```
Base Tone → Frequency Modulation → Filtering → Envelope → Output
```

## Parameter Set

Here's what a complete sfxr implementation would include:

```nim
type
  SfxrWaveform* = enum
    sfxSquare
    sfxSawtooth
    sfxSine
    sfxNoise
  
  SfxrParams* = object
    # Waveform
    waveform*: SfxrWaveform
    
    # Frequency
    baseFrequency*: float       # Starting pitch (Hz)
    frequencyLimit*: float      # Minimum frequency clamp
    frequencySlide*: float      # Pitch change speed
    frequencyDeltaSlide*: float # Acceleration of pitch change
    
    # Vibrato
    vibratoDepth*: float        # Amount of vibrato
    vibratoSpeed*: float        # Vibrato frequency
    
    # Duty Cycle (for square wave)
    squareDuty*: float          # Pulse width (0.0-1.0)
    dutySweep*: float           # Change in duty cycle
    
    # Arpeggio (note jumping)
    changeAmount*: float        # Frequency jump amount
    changeSpeed*: float         # Jump frequency
    
    # Envelope
    attackTime*: float          # Fade in
    sustainTime*: float         # Hold time
    decayTime*: float           # Fade out
    sustainPunch*: float        # Amplitude boost at start
    
    # Filters
    lpFilterCutoff*: float      # Low-pass filter frequency
    lpFilterCutoffSweep*: float # Filter movement
    lpFilterResonance*: float   # Filter resonance
    hpFilterCutoff*: float      # High-pass filter frequency
    hpFilterCutoffSweep*: float # Filter movement
    
    # Phaser (flanger effect)
    phaserOffset*: float        # Phase shift amount
    phaserSweep*: float         # Phase modulation
    
    # Repeat
    repeatSpeed*: float         # Time between repeats
    
    # Flanging
    flangerOffset*: float       # Stereo offset
    flangerSweep*: float        # Flanger modulation
    
    # Volume
    masterVolume*: float        # Overall volume (0.0-1.0)

# Default "bleep" preset
proc sfxrPresetBleep*(): SfxrParams =
  SfxrParams(
    waveform: sfxSquare,
    baseFrequency: 440.0,
    attackTime: 0.01,
    sustainTime: 0.1,
    decayTime: 0.05,
    masterVolume: 0.5
  )

# Jump preset
proc sfxrPresetJump*(): SfxrParams =
  SfxrParams(
    waveform: sfxSquare,
    baseFrequency: 200.0,
    frequencySlide: 1.5,
    attackTime: 0.001,
    sustainTime: 0.15,
    decayTime: 0.05,
    masterVolume: 0.4
  )

# Explosion preset
proc sfxrPresetExplosion*(): SfxrParams =
  SfxrParams(
    waveform: sfxNoise,
    attackTime: 0.001,
    sustainTime: 0.3,
    decayTime: 0.5,
    frequencySlide: -0.5,
    masterVolume: 0.6
  )

# Laser preset
proc sfxrPresetLaser*(): SfxrParams =
  SfxrParams(
    waveform: sfxSawtooth,
    baseFrequency: 800.0,
    frequencySlide: -0.8,
    attackTime: 0.001,
    sustainTime: 0.1,
    decayTime: 0.05,
    masterVolume: 0.35
  )
```

## Implementation Strategy

### Phase 1: Basic Generator (Now Possible)

Using existing `audio_gen.nim` functions:

```nim
import lib/audio_gen

proc generateFromSfxr*(params: SfxrParams, sampleRate: int = 44100): AudioSample =
  ## Generate audio from sfxr parameters
  
  # Map sfxr waveform to our Waveform type
  let wf = case params.waveform
    of sfxSquare: wfSquare
    of sfxSawtooth: wfSawtooth
    of sfxSine: wfSine
    of sfxNoise: wfNoise
  
  # Calculate duration from envelope
  let duration = params.attackTime + params.sustainTime + params.decayTime
  
  # Build envelope
  let envelope = Envelope(
    attack: params.attackTime,
    decay: params.decayTime,
    sustain: 0.7,  # Simplified
    release: params.decayTime
  )
  
  # Simple version: frequency sweep
  if params.frequencySlide != 0.0:
    let endFreq = params.baseFrequency * (1.0 + params.frequencySlide)
    return generateFrequencySweep(
      params.baseFrequency,
      endFreq,
      duration,
      wf,
      params.masterVolume,
      sampleRate,
      envelope
    )
  else:
    return generateTone(
      params.baseFrequency,
      duration,
      wf,
      params.masterVolume,
      sampleRate,
      envelope
    )
```

### Phase 2: Advanced Features (Future)

Implement filters and effects:

```nim
proc applyLowPassFilter*(sample: var AudioSample, cutoff: float, resonance: float) =
  ## Apply a simple low-pass filter
  # Implement using biquad filter coefficients
  discard

proc applyHighPassFilter*(sample: var AudioSample, cutoff: float) =
  ## Apply high-pass filter
  discard

proc applyVibrato*(sample: var AudioSample, depth: float, speed: float) =
  ## Add vibrato (pitch modulation)
  # Modulate oscillator frequency over time
  discard

proc applyArpeggio*(sample: var AudioSample, changeAmount: float, changeSpeed: float) =
  ## Add note jumping
  discard

proc applyPhaser*(sample: var AudioSample, offset: float, sweep: float) =
  ## Add phaser effect
  discard
```

### Phase 3: Randomization (sfxr's Killer Feature)

```nim
import random

proc randomizeSfxr*(category: SfxrCategory): SfxrParams =
  ## Generate random parameters for a sound category
  
  case category
  of Pickup:
    result = SfxrParams(
      waveform: sample([sfxSquare, sfxSine]),
      baseFrequency: rand(400.0..800.0),
      frequencySlide: rand(0.2..0.8),
      attackTime: rand(0.001..0.01),
      sustainTime: rand(0.05..0.15),
      decayTime: rand(0.02..0.08),
      masterVolume: rand(0.3..0.5)
    )
  
  of Explosion:
    result = SfxrParams(
      waveform: sfxNoise,
      baseFrequency: rand(50.0..200.0),
      frequencySlide: rand(-0.8.. -0.3),
      attackTime: 0.001,
      sustainTime: rand(0.2..0.4),
      decayTime: rand(0.3..0.6),
      masterVolume: rand(0.4..0.7)
    )
  
  of Jump:
    result = SfxrParams(
      waveform: sfxSquare,
      baseFrequency: rand(200.0..400.0),
      frequencySlide: rand(0.5..1.5),
      attackTime: 0.001,
      sustainTime: rand(0.1..0.2),
      decayTime: rand(0.05..0.1),
      masterVolume: rand(0.3..0.5)
    )
  
  # ... more categories
```

## Full File Structure

```
lib/
  audio_gen.nim       # Core synthesis (✅ done)
  audio.nim           # Playback system (✅ done)
  sfxr.nim            # sfxr generator (⏳ future)
  sfxr_presets.nim    # Preset library (⏳ future)
  sfxr_random.nim     # Randomization (⏳ future)
  audio_filters.nim   # DSP filters (⏳ future)
  audio_effects.nim   # Effects (reverb, delay, etc.) (⏳ future)
```

## Interactive Generator Example

```nim
# In a TStorie .md file

## sfxr_generator

```nim
import lib/sfxr

var params = sfxrPresetBleep()
var previewSound: AudioSample
var audio = initAudio()

proc regeneratePreview() =
  previewSound = generateFromSfxr(params)
  audio.registerSound("preview", previewSound)

regeneratePreview()

proc onRender(ctx: var StorieContext, w, h: int, dt: float) =
  clearLayer("main")
  
  writeText("main", 2, 2, "sfxr Sound Generator", getStyle("title"))
  
  var y = 5
  writeText("main", 2, y, "Wave: " & $params.waveform, defaultStyle())
  y += 1
  writeText("main", 2, y, "Freq: " & $params.baseFrequency & " Hz", defaultStyle())
  y += 1
  writeText("main", 2, y, "Slide: " & $params.frequencySlide, defaultStyle())
  
  y += 2
  writeText("main", 2, y, "[Space] Play   [R] Randomize   [1-4] Presets", defaultStyle())

proc onKeyPress(ctx: var StorieContext, key: int) =
  case char(key)
  of ' ':
    audio.playSound("preview")
  of 'r', 'R':
    params = randomizeSfxr(Pickup)
    regeneratePreview()
  of '1':
    params = sfxrPresetJump()
    regeneratePreview()
  of '2':
    params = sfxrPresetExplosion()
    regeneratePreview()
  # ... more keys
  else:
    discard
```
```

## Benefits of Building on TStorie's Foundation

1. **Core synthesis done** - Oscillators, envelopes, basic effects ready
2. **Platform support** - WASM works now, native ready
3. **Integration** - Already wired into TStorie's event system
4. **Extensible** - Easy to add filters, effects, etc.
5. **Nim's strengths** - Type safety, performance, compile-time checks

## Resources

- **sfxr**: https://sfxr.me/
- **bfxr**: https://www.bfxr.net/
- **sfxr.js**: https://github.com/chr15m/jsfxr (JS implementation)
- **DSP Guide**: https://www.dspguide.com/ (for filters)

## Next Steps

If you want to implement this:

1. Start with `lib/sfxr.nim` and the parameter types
2. Implement `generateFromSfxr()` with basic features
3. Add presets for common sound types
4. Implement randomization per category
5. Add filters (low-pass, high-pass)
6. Add effects (vibrato, arpeggio, phaser)
7. Create interactive generator UI in TStorie

The foundation is solid - you can now build a full-featured procedural sound effect generator!
