# Audio Modules

Procedural audio generation and playback for TStorie.

## Quick Start

```nim
import lib/audio

# Initialize audio system
var audio = initAudio()

# Play built-in sound effects
audio.playJump()
audio.playHit()
audio.playLaser()

# Or generate custom sounds
audio.playTone(440.0, 0.5, wfSine)
```

## Modules

- **`audio_gen.nim`** - Core synthesis engine (oscillators, envelopes, effects)
- **`audio.nim`** - Playback system (Web Audio / miniaudio wrapper)

## Documentation

See [`docs/AUDIO_SYSTEM.md`](../docs/AUDIO_SYSTEM.md) for complete documentation.

## Examples

See [`examples/audio_demo.md`](../examples/audio_demo.md) for interactive demo.

## Platform Support

- ✅ **WASM/Web** - Full support via Web Audio API
- ⏳ **Native** - Stub ready for miniaudio integration

## Features

- 5 waveform types (sine, square, sawtooth, triangle, noise)
- ADSR envelope system
- Frequency sweeps
- Built-in game sound effects
- Sample mixing and manipulation
- Sound caching/registry
- Zero external dependencies
