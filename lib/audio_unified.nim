# Platform-Aware Audio Interface with Plugin System
# Demonstrates conditional plugin loading based on platform

import audio_loader

# Export unified API
export initAudio, playTone, stopAudio, isAudioPluginAvailable,
       getAudioBackend, showAudioHelp, hasAudioSupport

# Example: Feature detection for conditional UI elements
proc shouldShowAudioMenu*(): bool =
  ## Determine if audio menu should be shown
  ## Always true for WASM, true for native if plugin available
  when defined(emscripten):
    return true  # Web Audio always available
  else:
    return isAudioPluginAvailable()

proc getAudioStatusMessage*(): string =
  ## Get human-readable audio status
  when defined(emscripten):
    return "✓ Web Audio API (browser built-in)"
  else:
    if isAudioPluginAvailable():
      return "✓ " & getAudioBackend()
    else:
      return "⚠ Audio plugin not installed (optional)"

# Conditional feature loading example
proc tryInitializeAudio*(): bool =
  ## Try to initialize audio, but don't fail if not available
  when defined(emscripten):
    # Always available in browser
    return initAudio()
  else:
    # Optional on native
    if isAudioPluginAvailable():
      echo "Loading audio plugin..."
      return initAudio()
    else:
      echo "Audio plugin not found (audio features disabled)"
      return false

# Example integration patterns
when isMainModule:
  echo "=== Platform-Aware Audio System ==="
  echo ""
  echo "Platform: ", when defined(emscripten): "WASM" else: "Native"
  echo "Audio Status: ", getAudioStatusMessage()
  echo "Show Audio Menu: ", shouldShowAudioMenu()
  echo ""
  
  if tryInitializeAudio():
    echo "✓ Audio initialized successfully"
    playTone(440.0, 0.5)
  else:
    when not defined(emscripten):
      echo "Continuing without audio..."
      echo "(Install audio plugin for sound features)"
