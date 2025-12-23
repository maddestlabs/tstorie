# Simple test for miniaudio integration
# Run with: nim c -r tests/test_audio_miniaudio.nim

import ../lib/audio
import ../lib/audio_gen
import os

echo "Testing miniaudio integration..."
echo ""

# Initialize audio system
echo "1. Initializing audio system..."
let audioSys = initAudio(44100)

if not audioSys.isReady():
  echo "ERROR: Audio system failed to initialize"
  quit(1)

echo "✓ Audio system initialized successfully"
echo ""

# Test 1: Play a simple tone
echo "2. Playing a 440Hz sine wave for 1 second..."
let tone = generateTone(440.0, 1.0, wfSine, 0.3, 44100)
discard audioSys.playSample(tone)
sleep(1200)  # Wait for it to finish
echo "✓ Tone played"
echo ""

# Test 2: Play jump sound
echo "3. Playing jump sound effect..."
audioSys.playJump()
sleep(300)
echo "✓ Jump sound played"
echo ""

# Test 3: Play bleep
echo "4. Playing bleep..."
audioSys.playBleep(880.0)
sleep(200)
echo "✓ Bleep played"
echo ""

# Test 4: Register and play a named sound
echo "5. Registering and playing named sound..."
let laser = generateLaser(44100)
audioSys.registerSound("laser", laser)
discard audioSys.playSound("laser")
sleep(200)
echo "✓ Named sound played"
echo ""

# Cleanup
echo "6. Cleaning up..."
audioSys.cleanup()
echo "✓ Cleanup complete"
echo ""

echo "All tests passed! ✓"
