---
title: "TStorie Audio Node Demo"
author: "Maddest Labs"
targetFPS: 60
---

# Web Audio Node Graph Demo

Test TStorie's procedural audio system!

Press keys to create sounds:
- **1-8** - Play musical scale (C major)
- **Q** - Quick beep (440Hz)
- **W** - Laser sweep  
- **E** - Sawtooth tone
- **Space** - Jump sound effect

```nim on:init
# Track what sound is playing for display
var lastSound = "none"
var soundTimer = 0.0
var frameTime = 1.0 / 60.0
```

```nim on:render
clear()

# Title
draw(0, 2, 2, "TStorie Procedural Audio Demo")
draw(0, 2, 3, "==============================")
draw(0, 2, 4, "(Pure code-generated sounds)")

# Instructions
var y = 6
draw(0, 2, y, "Procedural audio system:")
y = y + 2
draw(0, 4, y, "[1-8] Musical scale (sine waves)")
y = y + 1
draw(0, 4, y, "[Q] Quick beep (440Hz)")
y = y + 1
draw(0, 4, y, "[W] Laser effect")
y = y + 1
draw(0, 4, y, "[E] Sawtooth tone")
y = y + 1
draw(0, 4, y, "[Space] Jump sound")

# Show what just played
y = y + 3
if soundTimer > 0.0:
  soundTimer = soundTimer - frameTime
  draw(0, 2, y, "Playing: " & lastSound)
else:
  draw(0, 2, y, "Press keys to create sounds...")

# Info
y = y + 2
draw(0, 2, y, "How it works:")
draw(0, 4, y + 1, "Sounds generated in real-time from code")
draw(0, 2, y + 3, "No audio files needed!")
```

```nim on:input
if event.type == "text":
  var ch = event.text
  
  # Musical scale (C major) - using simple tones
  if ch == "1":
    audioPlayTone(261.63, 0.3, "sine", 0.3)  # C4
    lastSound = "C4 (261.63 Hz)"
    soundTimer = 1.0
  elif ch == "2":
    audioPlayTone(293.66, 0.3, "sine", 0.3)  # D4
    lastSound = "D4 (293.66 Hz)"
    soundTimer = 1.0
  elif ch == "3":
    audioPlayTone(329.63, 0.3, "sine", 0.3)  # E4
    lastSound = "E4 (329.63 Hz)"
    soundTimer = 1.0
  elif ch == "4":
    audioPlayTone(349.23, 0.3, "sine", 0.3)  # F4
    lastSound = "F4 (349.23 Hz)"
    soundTimer = 1.0
  elif ch == "5":
    audioPlayTone(392.00, 0.3, "sine", 0.3)  # G4
    lastSound = "G4 (392.00 Hz)"
    soundTimer = 1.0
  elif ch == "6":
    audioPlayTone(440.00, 0.3, "sine", 0.3)  # A4
    lastSound = "A4 (440.00 Hz)"
    soundTimer = 1.0
  elif ch == "7":
    audioPlayTone(493.88, 0.3, "sine", 0.3)  # B4
    lastSound = "B4 (493.88 Hz)"
    soundTimer = 1.0
  elif ch == "8":
    audioPlayTone(523.25, 0.3, "sine", 0.3)  # C5
    lastSound = "C5 (523.25 Hz)"
    soundTimer = 1.0
  
  # Quick beep
  elif ch == "q" or ch == "Q":
    audioPlayBleep(440.0, 0.3)
    lastSound = "Quick beep"
    soundTimer = 1.0
  
  # Sweep effects - different waveforms
  elif ch == "w" or ch == "W":
    audioPlayLaser(0.4)
    lastSound = "Laser sweep up"
    soundTimer = 1.0
  
  elif ch == "e" or ch == "E":
    audioPlayTone(800.0, 0.3, "sawtooth", 0.4)
    lastSound = "Sawtooth tone"
    soundTimer = 1.0

elif event.type == "keydown" and event.key == "Space":
  # Play a game sound effect
  audioPlayJump(0.4)
  lastSound = "Jump sound"
  soundTimer = 1.0
```

---

## Features Demonstrated

This example shows:

1. **Built-in Audio Functions** - Ready-to-use sound effects
2. **Game Sound Effects** - Jump, landing, hit, power-up, laser
3. **Musical Tones** - Generate specific frequencies (notes)
4. **Instant Playback** - No latency, sounds play immediately
5. **Simple API** - Just call the function, no setup needed

## Under the Hood

The audio system uses:

- **Pure Nim synthesis** - No external dependencies
- **Multiple waveforms** - Sine, square, sawtooth, triangle, noise
- **ADSR envelopes** - Professional sound shaping
- **Frequency sweeps** - For dynamic effects like jumps
- **Web Audio API** - Native browser support (WASM)
- **Procedural generation** - Sounds created in code, not files

## Available Audio Functions

TStorie provides these audio functions in markdown files:

- `audioPlayJump(volume)` - Jump sound effect
- `audioPlayLanding(volume)` - Landing sound effect  
- `audioPlayHit(volume)` - Hit/damage sound effect
- `audioPlayPowerUp(volume)` - Power-up sound effect
- `audioPlayLaser(volume)` - Laser sound effect
- `audioPlayBleep(frequency, volume)` - Simple beep tone
- `audioPlayTone(frequency, duration, waveform, volume)` - Custom tone
  - Waveforms: "sine", "square", "sawtooth", "triangle", "noise"

All volume parameters are optional and default to sensible values (0.35-0.5).

## Next Steps

Once you've tested the basics, you can:

1. Use `audioPlayTone()` for custom sound effects with different waveforms
2. Experiment with frequencies and durations to create unique sounds
3. Build interactive games with audio feedback
4. Create music sequencers using the tone functions
