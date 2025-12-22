# TStorie Audio System

Procedural audio generation and playback for terminal games and interactive stories.

## Overview

TStorie's audio system is built on **procedural sound generation** - sounds are created algorithmically in real-time rather than loaded from files. This approach is:

- **Self-contained** - No external audio files needed
- **Dynamic** - Generate infinite variations
- **Lightweight** - Tiny code footprint
- **Retro-authentic** - Classic game sound aesthetic
- **Cross-platform** - Works on native and WASM builds

## Architecture

```
lib/audio_gen.nim    - Core synthesis (oscillators, envelopes, effects)
lib/audio.nim        - Playback system (Web Audio API / miniaudio)
web/audio_bridge.js  - JavaScript bridge for WASM builds
```

## Quick Start

### Basic Usage

```nim
import lib/audio
import lib/audio_gen

# Initialize audio
var audio = initAudio(44100)  # 44.1kHz sample rate

# Play built-in effects
audio.playJump()
audio.playHit()
audio.playPowerUp()

# Play a simple tone
audio.playTone(440.0, 0.5, wfSine, 0.5)  # A440 for 0.5 seconds
```

### Pre-generate Sounds

For best performance, generate sounds once and cache them:

```nim
# Generate and register
audio.registerSound("coin", generateBleep(800.0, 0.1))
audio.registerSound("explosion", generateNoiseBurst(0.3))

# Play instantly
audio.playSound("coin")
audio.playSound("explosion")
```

## Core Synthesis Functions

### generateTone()

Create a basic tone with envelope:

```nim
let tone = generateTone(
  frequency = 440.0,      # Hz
  duration = 0.5,         # seconds
  waveform = wfSine,      # sine, square, sawtooth, triangle, noise
  amplitude = 0.5,        # 0.0 to 1.0
  sampleRate = 44100,
  envelope = Envelope(
    attack: 0.01,         # fade in time
    decay: 0.05,          # decay to sustain
    sustain: 0.7,         # hold level (0.0-1.0)
    release: 0.1          # fade out time
  )
)
```

### generateFrequencySweep()

Create a pitch slide (great for jumps, lasers, etc.):

```nim
let sweep = generateFrequencySweep(
  startFreq = 200.0,      # Starting Hz
  endFreq = 800.0,        # Ending Hz
  duration = 0.3,
  waveform = wfSquare,
  amplitude = 0.5
)
```

### generateNoiseBurst()

White noise burst (explosions, hits):

```nim
let noise = generateNoiseBurst(
  duration = 0.2,
  amplitude = 0.4
)
```

## Waveform Types

```nim
type Waveform = enum
  wfSine       # Smooth, pure tone (flutes, clean beeps)
  wfSquare     # Hollow, retro (classic video games)
  wfSawtooth   # Harsh, buzzy (brass instruments, aggressive)
  wfTriangle   # Softer square (woodwinds, mellow)
  wfNoise      # White noise (wind, explosions)
  wfPulse      # Variable duty cycle (configurable width)
```

## ADSR Envelopes

Control how sounds fade in and out:

```
Amplitude
    ^
1.0 |    /\___
    |   /  |  \___
    |  /   |      \___
    | /    |          \___
0.0 |/____|______|_______\___> Time
      A    D   S      R

A = Attack   - Fade in time
D = Decay    - Drop to sustain level
S = Sustain  - Hold level (0.0-1.0)
R = Release  - Fade out time
```

Example envelopes:

```nim
# Percussive (drum, hit)
Envelope(attack: 0.001, decay: 0.05, sustain: 0.0, release: 0.05)

# Sustained (organ, pad)
Envelope(attack: 0.05, decay: 0.1, sustain: 0.8, release: 0.3)

# Plucky (plucked string)
Envelope(attack: 0.001, decay: 0.3, sustain: 0.0, release: 0.01)

# Bell-like
Envelope(attack: 0.001, decay: 0.5, sustain: 0.2, release: 0.4)
```

## Built-in Sound Effects

Convenience functions for common game sounds:

```nim
generateJump()      # Upward frequency sweep
generateLanding()   # Downward thud
generateHit()       # Short noise burst
generatePowerUp()   # Ascending musical sweep
generateLaser()     # Descending sawtooth
generateBleep()     # Short UI feedback tone
```

## Advanced Techniques

### Mixing Sounds

Combine multiple sounds:

```nim
let drum = generateNoiseBurst(0.1)
let bass = generateTone(60.0, 0.1, wfSine)
let mixed = mixSamples(drum, bass, volume = 1.0)
```

### Concatenating

Create sequences:

```nim
let beep1 = generateBleep(440.0)
let beep2 = generateBleep(880.0)
let sequence = concatenateSamples(beep1, beep2)
```

### Volume Control

Adjust volume after generation:

```nim
var sound = generateTone(440.0, 0.5)
sound.applySampleVolume(0.5)  # Reduce to 50%
```

### Resampling

Change sample rate:

```nim
let sound48k = sound44k.resample(48000)
```

## Musical Notes

Common frequencies for musical tones:

```nim
const
  NOTE_C4 = 261.63
  NOTE_D4 = 293.66
  NOTE_E4 = 329.63
  NOTE_F4 = 349.23
  NOTE_G4 = 392.00
  NOTE_A4 = 440.00
  NOTE_B4 = 493.88
  NOTE_C5 = 523.25

# Play middle C
audio.playTone(NOTE_C4, 0.5)
```

## Sound Design Patterns

### Jump Sound
```nim
generateFrequencySweep(200.0, 600.0, 0.2, wfSquare)
```

### Coin/Pickup
```nim
generateBleep(800.0, 0.1, 0.4)
```

### Explosion
```nim
let env = Envelope(attack: 0.001, decay: 0.2, sustain: 0.0, release: 0.1)
generateNoiseBurst(0.3, 0.5, env)
```

### Laser Shot
```nim
generateFrequencySweep(800.0, 200.0, 0.15, wfSawtooth)
```

### Menu Selection
```nim
generateTone(600.0, 0.05, wfSquare, 0.3)
```

### Power Down
```nim
generateFrequencySweep(400.0, 100.0, 0.5, wfSine)
```

## Platform Support

### WASM (Web)
- Uses Web Audio API via JavaScript bridge
- Zero latency playback
- Works in all modern browsers
- Requires user interaction to start (browser policy)

### Native (Future)
- Will use miniaudio C library
- Cross-platform (Linux, Windows, macOS)
- Low-latency hardware audio

## Performance Tips

1. **Pre-generate** - Create sounds at init, not during gameplay
2. **Cache smartly** - Register frequently-used sounds by name
3. **Reasonable lengths** - Keep sounds under 1-2 seconds
4. **Limit simultaneous** - Don't play too many sounds at once
5. **Use lower sample rates** - 22050Hz is fine for retro sounds

## Building an sfxr-Style Generator

The foundation is in place to build an sfxr clone. Key parameters:

```nim
type SfxrParams = object
  waveform: Waveform
  baseFreq: float
  freqSlide: float        # Pitch change over time
  freqDeltaSlide: float   # Acceleration of pitch change
  squareDuty: float       # Pulse width for square wave
  dutySweep: float        # Duty cycle change
  vibratoDepth: float     # Vibrato amount
  vibratoSpeed: float     # Vibrato frequency
  attack: float           # Envelope attack
  sustain: float          # Envelope sustain
  decay: float            # Envelope decay
  # ... more parameters
```

This can be implemented as `lib/sfxr.nim` using the existing `audio_gen` primitives.

## API Reference

See:
- `lib/audio_gen.nim` - Full synthesis API
- `lib/audio.nim` - Playback system API
- `examples/audio_demo.md` - Interactive examples

## Future Enhancements

Planned features:

- [ ] Filters (low-pass, high-pass, band-pass)
- [ ] Effects (reverb, delay, distortion)
- [ ] Complete sfxr parameter set
- [ ] Sound randomization/mutation
- [ ] Native miniaudio integration
- [ ] Multi-track mixing
- [ ] Real-time parameter modulation
- [ ] Save/load sound definitions

## Credits

Inspired by:
- **sfxr** by DrPetter
- **bfxr** by increpare
- **miniaudio** by mackron
- Classic 8-bit/16-bit game audio
