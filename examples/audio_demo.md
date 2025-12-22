---
title: "The Depths of Khel-Daran"
author: "Maddest Labs"
targetFPS: 60
---

# Procedural Audio Demo

Test procedural sound generation in TStorie!

Press keys to trigger sounds:
- **J** - Jump sound
- **L** - Landing sound  
- **H** - Hit/damage sound
- **P** - Power-up sound
- **Space** - Laser sound
- **1-5** - Musical notes

```nim on:init
# Audio system is automatically initialized by TStorie
# Track what's playing for visual feedback
var lastSound = "none"
var soundTimer = 0.0
var frameTime = 1.0 / 60.0  # Approximate frame time
```

```nim on:render
bgClear()

# Title
bgWriteText(2, 2, "TStorie Procedural Audio Demo")
bgWriteText(2, 3, "================================")

# Instructions
var y = 5
bgWriteText(2, y, "Press keys to play sounds:")
y = y + 2
bgWriteText(4, y, "[J] Jump sound")
y = y + 1
bgWriteText(4, y, "[L] Landing sound")
y = y + 1
bgWriteText(4, y, "[H] Hit/damage sound")
y = y + 1
bgWriteText(4, y, "[P] Power-up sound")
y = y + 1
bgWriteText(4, y, "[Space] Laser sound")
y = y + 2
bgWriteText(4, y, "[1-5] Musical notes (C-G)")

# Show what just played
if soundTimer > 0.0:
  soundTimer = soundTimer - frameTime
  bgWriteText(2, 20, "Playing: " & lastSound)

# Info
bgWriteText(2, 23, "Audio ready - press keys to play sounds!")
```

```nim on:input
# Handle keyboard events through the input lifecycle
if event.type == "text":
  # Handle text input (alphanumeric keys)
  var ch = event.text
  
  if ch == "j" or ch == "J":
    audioPlayJump()
    lastSound = "Jump"
    soundTimer = 1.0
  
  elif ch == "l" or ch == "L":
    audioPlayLanding()
    lastSound = "Landing"
    soundTimer = 1.0
  
  elif ch == "h" or ch == "H":
    audioPlayHit()
    lastSound = "Hit"
    soundTimer = 1.0
  
  elif ch == "p" or ch == "P":
    audioPlayPowerUp()
    lastSound = "Power-Up"
    soundTimer = 1.0
  
  elif ch == "1":
    audioPlayBleep(261.63)  # C note
    lastSound = "Note: C"
    soundTimer = 1.0
  
  elif ch == "2":
    audioPlayBleep(293.66)  # D note
    lastSound = "Note: D"
    soundTimer = 1.0
  
  elif ch == "3":
    audioPlayBleep(329.63)  # E note
    lastSound = "Note: E"
    soundTimer = 1.0
  
  elif ch == "4":
    audioPlayBleep(349.23)  # F note
    lastSound = "Note: F"
    soundTimer = 1.0
  
  elif ch == "5":
    audioPlayBleep(392.00)  # G note
    lastSound = "Note: G"
    soundTimer = 1.0
  
  return false

elif event.type == "key":
  # Handle special keys
  if event.keyCode == 32 and event.action == "press":
    # Space key
    audioPlayLaser()
    lastSound = "Laser"
    soundTimer = 1.0
  
  return false

return false
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
