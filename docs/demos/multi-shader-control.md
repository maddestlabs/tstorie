---
title: Multi-Shader Control Demo
shaders: paper;crt
targetFPS: 60
---

# Multi-Shader Interactive Control

Control multiple shaders and their parameters!

This demo shows how to control a shader chain using both paper and crt shaders.

---

Controls:

Paper Shader
- 1-5 : Preset intensities (0.2, 0.4, 0.6, 0.8, 1.0)
- Q/W : Decrease/increase paper noise
- A/S : Decrease/increase noise intensity

CRT Shader  
- E/R : Decrease/increase curve strength
- D/F : Decrease/increase frame size
- C : Toggle CRT on/off

General
- Space : Show all values
- 0 : Reset all to defaults
- P : Toggle pulse animation

---

```nim on:init
# Paper shader state
var paperNoise = 0.3
var noiseIntensity = 0.5
var noiseMix = 0.5

# CRT shader state (if available)
var crtEnabled = true
var curveStrength = 0.15
var frameSize = 40.0

# Animation
var isPulsing = false
var pulseTime = 0.0

print("Multi-Shader Control Demo")
print("Use number keys 1-5 for quick presets")
print("Use QWAS for paper shader control")
print("Use ERDF for CRT shader control")

# Initialize shaders
applyPaperSettings()
applyCRTSettings()
```

```nim on:update
if isPulsing then
  pulseTime = pulseTime + getDeltaTime()
  
  # Pulse both shaders
  let pulse = (sin(pulseTime * 2.0) + 1.0) / 2.0
  setShaderUniform("paper", "noiseMix", pulse * 0.8)
  
  # Pulse CRT curve too
  let crtPulse = 0.1 + pulse * 0.1
  setShaderUniform("crt", "curveStrength", crtPulse)
```

```nim on:input
let key = getKey()

# Presets (1-5)
if key == "1" then
  paperNoise = 0.2
  applyPaperSettings()
  print("Preset 1: Subtle")
elif key == "2" then
  paperNoise = 0.4
  applyPaperSettings()
  print("Preset 2: Light")
elif key == "3" then
  paperNoise = 0.6
  applyPaperSettings()
  print("Preset 3: Medium")
elif key == "4" then
  paperNoise = 0.8
  applyPaperSettings()
  print("Preset 4: Heavy")
elif key == "5" then
  paperNoise = 1.0
  applyPaperSettings()
  print("Preset 5: Maximum")

# Paper controls
elif key == "q" or key == "Q" then
  paperNoise = max(0.0, paperNoise - 0.05)
  applyPaperSettings()
  print("Paper noise: " & str(paperNoise))
elif key == "w" or key == "W" then
  paperNoise = min(1.0, paperNoise + 0.05)
  applyPaperSettings()
  print("Paper noise: " & str(paperNoise))
elif key == "a" or key == "A" then
  noiseIntensity = max(0.0, noiseIntensity - 0.05)
  applyPaperSettings()
  print("Noise intensity: " & str(noiseIntensity))
elif key == "s" or key == "S" then
  noiseIntensity = min(2.0, noiseIntensity + 0.05)
  applyPaperSettings()
  print("Noise intensity: " & str(noiseIntensity))

# CRT controls
elif key == "e" or key == "E" then
  curveStrength = max(0.0, curveStrength - 0.01)
  applyCRTSettings()
  print("CRT curve: " & str(curveStrength))
elif key == "r" or key == "R" then
  curveStrength = min(0.5, curveStrength + 0.01)
  applyCRTSettings()
  print("CRT curve: " & str(curveStrength))
elif key == "d" or key == "D" then
  frameSize = max(0.0, frameSize - 5.0)
  applyCRTSettings()
  print("Frame size: " & str(frameSize))
elif key == "f" or key == "F" then
  frameSize = min(100.0, frameSize + 5.0)
  applyCRTSettings()
  print("Frame size: " & str(frameSize))
elif key == "c" or key == "C" then
  crtEnabled = not crtEnabled
  if crtEnabled then
    applyCRTSettings()
    print("CRT shader ON")
  else
    setShaderUniform("crt", "curveStrength", 0.0)
    setShaderUniform("crt", "frameSize", 0.0)
    print("CRT shader OFF")

# Pulse animation
elif key == "p" or key == "P" then
  isPulsing = not isPulsing
  pulseTime = 0.0
  if not isPulsing then
    applyPaperSettings()
    applyCRTSettings()
  print("Pulse: " & (if isPulsing then "ON" else "OFF"))

# Reset
elif key == "0" then
  paperNoise = 0.3
  noiseIntensity = 0.5
  noiseMix = 0.5
  curveStrength = 0.15
  frameSize = 40.0
  crtEnabled = true
  isPulsing = false
  applyPaperSettings()
  applyCRTSettings()
  print("Reset to defaults")

# Show values
elif key == " " then
  print("====================")
  print("PAPER SHADER:")
  print("  paperNoise: " & str(paperNoise))
  print("  noiseIntensity: " & str(noiseIntensity))
  print("  noiseMix: " & str(noiseMix))
  print("")
  print("CRT SHADER:")
  print("  curveStrength: " & str(curveStrength))
  print("  frameSize: " & str(frameSize))
  print("  enabled: " & (if crtEnabled then "YES" else "NO"))
  print("")
  print("ANIMATION:")
  print("  pulsing: " & (if isPulsing then "YES" else "NO"))
  print("====================")
```

```nim on:render
# Create a colorful gradient to showcase the shaders
for y in 0..<termHeight do
  for x in 0..<termWidth do
    # Rainbow gradient
    let hue = (float(x) / float(termWidth) + float(y) / float(termHeight) * 0.5) * 360.0
    let brightness = 0.7 + 0.3 * sin(float(x + y) * 0.3)
    
    # Convert HSV to RGB (simplified)
    let h = int(hue / 60.0) mod 6
    let c = brightness
    
    var r, g, b = 0
    if h == 0 then
      r = int(c * 255)
      g = int(c * 128)
      b = 0
    elif h == 1 then
      r = int(c * 128)
      g = int(c * 255)
      b = 0
    elif h == 2 then
      r = 0
      g = int(c * 255)
      b = int(c * 128)
    elif h == 3 then
      r = 0
      g = int(c * 128)
      b = int(c * 255)
    elif h == 4 then
      r = int(c * 128)
      g = 0
      b = int(c * 255)
    else
      r = int(c * 255)
      g = 0
      b = int(c * 128)
    end
    
    let color = rgb(r, g, b)
    drawChar(x, y, '▓', color)
  end
end

# Draw title
let title = "MULTI-SHADER CONTROL"
let titleX = (termWidth - len(title)) div 2
drawText(titleX, 1, title, 0xFFFFFF, bold=true)

# Draw controls hint
drawText(2, termHeight - 2, "1-5:Presets QWAS:Paper ERDF:CRT C:Toggle P:Pulse Space:Info", 0xFFFF00)

# Draw current status
let status = "Paper:" & str(int(paperNoise * 100)) & "% CRT:" & 
             (if crtEnabled then "ON" else "OFF") & 
             (if isPulsing then " [PULSING]" else "")
drawText(termWidth - len(status) - 2, 1, status, 0x00FF00)
```

```nim
# Helper functions
proc applyPaperSettings() =
  setShaderUniform("paper", "paperNoise", paperNoise)
  setShaderUniform("paper", "noiseIntensity", noiseIntensity)
  setShaderUniform("paper", "noiseMix", noiseMix)
end

proc applyCRTSettings() =
  setShaderUniform("crt", "curveStrength", curveStrength)
  setShaderUniform("crt", "frameSize", frameSize)
end
```

---

What This Demonstrates:

1. Multiple Shaders - Control parameters in a shader chain
2. Real-time Updates - All changes happen immediately
3. Coordinated Animation - Pulse effect affects both shaders
4. Presets - Quick-switch between configurations
5. Enable/Disable - Turn effects on/off dynamically

Performance Note:
Uniform updates are extremely cheap - they only update a small GPU buffer. 
You can update dozens of uniforms per frame with no performance impact!

---

Try it now! The combination of paper texture + CRT warping creates a nice retro effect!
