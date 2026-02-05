---
title: Interactive Shader Control Demo
shaders: "paper"
---

# Interactive Shader Control

Control shader parameters in real-time with code!

Press keys to modify the shader uniforms:

- [+] [-] : Increase/decrease paper texture intensity
- [ [ ] ] : Adjust noise intensity  
- [{] [}] : Change noise mix level
- [R] : Reset to defaults
- [P] : Pulse effect (animated)
- [O] : Turn shader off
- [Space] : Print current values

---

The paper shader has three uniforms:
- paperNoise - Overall effect intensity (0.0 to 1.0)
- noiseIntensity - Strength of the noise pattern
- noiseMix - How much noise blends with color

These can be controlled dynamically using setShaderUniform().

```nim on:init
# Track current values
var paperNoise = 0.2
var noiseIntensity = 0.5
var noiseMix = 0.5
var isPulsing = false
var pulseTime = 0.0
var shadersInitialized = false

```

```nim on:update
# Initialize shader once it's loaded
if not shadersInitialized:
  setShaderUniform("paper", "paperNoise", paperNoise)
  setShaderUniform("paper", "noiseIntensity", noiseIntensity)
  setShaderUniform("paper", "noiseMix", noiseMix)
  shadersInitialized = true
  print("Shader controls initialized")

# Handle pulse animation
if isPulsing:
  pulseTime = pulseTime + getDeltaTime()
  let pulse = (sin(pulseTime * 3.0) + 1.0) / 2.0  # 0.0 to 1.0
  setShaderUniform("paper", "noiseMix", pulse)
```

```nim on:input
let step = 0.05
if event.type == "text":
  var key = event.text
  if key == "+":
    paperNoise = min(1.0, paperNoise + step)
    setShaderUniform("paper", "paperNoise", paperNoise)
    print("Paper noise: " & str(paperNoise))
    
  elif key == "-":
    paperNoise = max(0.0, paperNoise - step)
    setShaderUniform("paper", "paperNoise", paperNoise)
    print("Paper noise: " & str(paperNoise))
    
  elif key == "[":
    noiseIntensity = max(0.0, noiseIntensity - step)
    setShaderUniform("paper", "noiseIntensity", noiseIntensity)
    print("Noise intensity: " & str(noiseIntensity))
    
  elif key == "]":
    noiseIntensity = min(2.0, noiseIntensity + step)
    setShaderUniform("paper", "noiseIntensity", noiseIntensity)
    print("Noise intensity: " & str(noiseIntensity))
    
  elif key == "{":
    noiseMix = max(0.0, noiseMix - step)
    setShaderUniform("paper", "noiseMix", noiseMix)
    print("Noise mix: " & str(noiseMix))
    
  elif key == "}":
    noiseMix = min(1.0, noiseMix + step)
    setShaderUniform("paper", "noiseMix", noiseMix)
    print("Noise mix: " & str(noiseMix))
    
  elif key == "r" or key == "R":
    # Reset to defaults
    paperNoise = 0.2
    noiseIntensity = 0.5
    noiseMix = 0.5
    isPulsing = false
    setShaderUniform("paper", "paperNoise", paperNoise)
    setShaderUniform("paper", "noiseIntensity", noiseIntensity)
    setShaderUniform("paper", "noiseMix", noiseMix)
    print("Reset to defaults")
    
  elif key == "p" or key == "P":
    # Toggle pulse effect
    isPulsing = not isPulsing
    if isPulsing:
      print("Pulse effect ON")
      pulseTime = 0.0
    else:
      # Restore static value
      setShaderUniform("paper", "noiseMix", noiseMix)
      print("Pulse effect OFF")
    
  elif key == "o" or key == "O":
    # Turn shader off
    setShaderUniform("paper", "paperNoise", 0.0)
    print("Shader disabled")
    
  elif key == " ":
    # Print current values
    print("==============================")
    print("Current Shader Values:")
    print("  paperNoise: " & str(paperNoise))
    print("  noiseIntensity: " & str(noiseIntensity))
    print("  noiseMix: " & str(noiseMix))
    print("  Pulsing: ")
    print("==============================")
```

```nim on:render
# Draw a gradient to show the shader effect
#draw(0, x, y, '█', getStyle("default"))

# Draw title
let title = "SHADER CONTROL DEMO"
let titleX = (termWidth - len(title)) div 2
draw(0, titleX, 2, title, getStyle("default"))

# Draw current values
let statusY = 4
draw(0, 2, statusY, "paperNoise: " & str(paperNoise), getStyle("default"))
draw(0, 2, statusY + 1, "noiseIntensity: " & str(noiseIntensity), getStyle("default"))
draw(0, 2, statusY + 2, "noiseMix: " & str(noiseMix), getStyle("default"))
draw(0, 2, statusY + 3, "Pulsing: " & "OFF", getStyle("default"))

# Draw instructions at bottom
draw(0, 2, termHeight - 2, "Press +/- to adjust | Space: Print values", getStyle("default"))
```

---

Try it now! Press keys to see the shader change in real-time!
