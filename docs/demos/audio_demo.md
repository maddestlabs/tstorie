---
title: "TStorie Audio Node Demo"
author: "Maddest Labs"
targetFPS: 60
---

# Web Audio Node Graph Demo

Test the Web Audio-inspired node system!

Press keys to create sounds:
- **1-8** - Play notes with oscillators
- **Q** - Quick beep (440Hz)
- **W** - Sweep up  
- **E** - Sweep down
- **Space** - Play procedural sample

```nim on:init
# Create an AudioContext (like Web Audio API)
var audioCtx = newAudioContext()
var lastSound = "none"
var soundTimer = 0.0
var frameTime = 1.0 / 60.0

# Get the destination (speakers)
var destination = audioCtx.destination()

# Helper: Play a tone using oscillator nodes
proc playNodeTone(freq: float, duration: float) =
  # Create oscillator -> gain -> destination
  var osc = audioCtx.createOscillator()
  var gain = audioCtx.createGain()
  
  osc.setFrequency(freq)
  osc.setType(Sine)
  gain.setGain(0.3)
  
  osc.connect(gain)
  gain.connect(destination)
  
  osc.start(0.0)
  # Note: In real Web Audio, we'd schedule stop() after duration
  # For now, this creates a continuous tone until we add scheduling

# Helper: Play a procedural sample using buffer source
proc playSampleNode(data: seq[float32]) =
  var source = audioCtx.createBufferSource()
  var gain = audioCtx.createGain()
  
  source.setBuffer(data, 44100)
  gain.setGain(0.4)
  
  source.connect(gain)
  gain.connect(destination)
  
  source.startBuffer(0.0)
```

```nim on:render
bgClear()

# Title
bgWriteText(2, 2, "TStorie Audio Node Graph Demo")
bgWriteText(2, 3, "================================")
bgWriteText(2, 4, "(Web Audio API-inspired)")

# Instructions
var y = 6
bgWriteText(2, y, "Node-based audio system:")
y = y + 2
bgWriteText(4, y, "[1-8] Musical scale (oscillators)")
y = y + 1
bgWriteText(4, y, "[Q] Quick beep (440Hz)")
y = y + 1
bgWriteText(4, y, "[W] Frequency sweep up")
y = y + 1
bgWriteText(4, y, "[E] Frequency sweep down")
y = y + 1
bgWriteText(4, y, "[Space] Procedural sample")

# Show what just played
y = y + 3
if soundTimer > 0.0:
  soundTimer = soundTimer - frameTime
  bgWriteText(2, y, "Playing: " & lastSound)
else:
  bgWriteText(2, y, "Press keys to create sounds...")

# Info
y = y + 2
bgWriteText(2, y, "Architecture:")
bgWriteText(4, y + 1, "Oscillator/Source -> Gain -> Destination")
bgWriteText(2, y + 3, "Each sound creates a new node graph!")
```

```nim on:input
if event.type == "text":
  var ch = event.text
  
  # Musical scale (C major)
  if ch == "1":
    playNodeTone(261.63, 0.3)  # C4
    lastSound = "C4 (261.63 Hz)"
    soundTimer = 1.0
  elif ch == "2":
    playNodeTone(293.66, 0.3)  # D4
    lastSound = "D4 (293.66 Hz)"
    soundTimer = 1.0
  elif ch == "3":
    playNodeTone(329.63, 0.3)  # E4
    lastSound = "E4 (329.63 Hz)"
    soundTimer = 1.0
  elif ch == "4":
    playNodeTone(349.23, 0.3)  # F4
    lastSound = "F4 (349.23 Hz)"
    soundTimer = 1.0
  elif ch == "5":
    playNodeTone(392.00, 0.3)  # G4
    lastSound = "G4 (392.00 Hz)"
    soundTimer = 1.0
  elif ch == "6":
    playNodeTone(440.00, 0.3)  # A4
    lastSound = "A4 (440.00 Hz)"
    soundTimer = 1.0
  elif ch == "7":
    playNodeTone(493.88, 0.3)  # B4
    lastSound = "B4 (493.88 Hz)"
    soundTimer = 1.0
  elif ch == "8":
    playNodeTone(523.25, 0.3)  # C5
    lastSound = "C5 (523.25 Hz)"
    soundTimer = 1.0
  
  # Quick beep
  elif ch == "q" or ch == "Q":
    playNodeTone(440.0, 0.1)
    lastSound = "Quick beep"
    soundTimer = 1.0
  
  # Sweep effects using procedural generation
  elif ch == "w" or ch == "W":
    var sample = generateFrequencySweep(200.0, 800.0, 0.3, 0.3, 44100)
    playSampleNode(sample.data)
    lastSound = "Sweep up (200-800 Hz)"
    soundTimer = 1.0
  
  elif ch == "e" or ch == "E":
    var sample = generateFrequencySweep(800.0, 200.0, 0.3, 0.3, 44100)
    playSampleNode(sample.data)
    lastSound = "Sweep down (800-200 Hz)"
    soundTimer = 1.0

elif event.type == "keydown" and event.key == "Space":
  # Generate a complex procedural sound
  var sample = generateJump(44100)
  playSampleNode(sample.data)
  lastSound = "Jump (procedural)"
  soundTimer = 1.0
```
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
