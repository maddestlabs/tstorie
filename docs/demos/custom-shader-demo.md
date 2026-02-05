---
title: Custom WGSL Shader Demo
---

# Custom WGSL Fragment Shader

This demo shows how to define custom WGSL shaders inline and control them with code!

Press **[Space]** to toggle animation  
Press **[+/-]** to adjust wave intensity  
Press **[C]** to cycle through color modes

---

```wgsl fragment:waves
// Custom wave distortion shader with color effects

struct Uniforms {
  time: f32,
  resolution: vec2f,
  waveIntensity: f32,
  colorMode: f32,
};

@group(0) @binding(2) var<uniform> uniforms: Uniforms;
@group(0) @binding(0) var inputTexture: texture_2d<f32>;
@group(0) @binding(1) var inputSampler: sampler;

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
};

@vertex
fn vertexMain(@location(0) pos: vec2f) -> VertexOutput {
  var output: VertexOutput;
  output.position = vec4f(pos, 0.0, 1.0);
  output.uv = pos * 0.5 + 0.5;
  return output;
}

@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
  // Wave distortion
  let wave = sin(input.uv.y * 20.0 + uniforms.time * 2.0) * uniforms.waveIntensity;
  let distortedUV = vec2f(input.uv.x + wave * 0.05, input.uv.y);
  
  // Sample texture
  var color = textureSample(inputTexture, inputSampler, distortedUV);
  
  // Color effects based on mode
  if (uniforms.colorMode < 0.5) {
    // Mode 0: Rainbow tint
    let tint = vec3f(
      sin(uniforms.time + input.uv.x * 3.0) * 0.5 + 0.5,
      sin(uniforms.time + input.uv.y * 3.0 + 2.0) * 0.5 + 0.5,
      sin(uniforms.time + (input.uv.x + input.uv.y) * 3.0 + 4.0) * 0.5 + 0.5
    );
    color = vec4f(color.rgb * (0.7 + tint * 0.3), color.a);
  } else if (uniforms.colorMode < 1.5) {
    // Mode 1: Grayscale with edge highlight
    let gray = dot(color.rgb, vec3f(0.299, 0.587, 0.114));
    let edge = abs(wave) * 2.0;
    color = vec4f(vec3f(gray) + vec3f(edge * 0.3), color.a);
  } else {
    // Mode 2: Inverted colors
    color = vec4f(1.0 - color.rgb, color.a);
  }
  
  return color;
}
```

```nim on:init
var waveIntensity = 0.5
var colorMode = 0.0
var isAnimating = true
var time = 0.0
var shadersInitialized = false
```

```nim on:update
# Initialize shader uniforms once shaders are loaded
if not shadersInitialized:
  setShaderUniform("waves", "waveIntensity", waveIntensity)
  setShaderUniform("waves", "colorMode", colorMode)
  shadersInitialized = true

# Update time if animating
if isAnimating:
  time = time + getDeltaTime()
  setShaderUniform("waves", "time", time)
```

```nim on:input
if event.type == "text":
  let key = event.text
  
  if key == " ":
    isAnimating = not isAnimating
    if isAnimating:
      print("Animation: ON")
    else:
      print("Animation: OFF")
  
  elif key == "+":
    waveIntensity = min(1.0, waveIntensity + 0.1)
    setShaderUniform("waves", "waveIntensity", waveIntensity)
    print("Wave intensity: " & str(waveIntensity))
  
  elif key == "-":
    waveIntensity = max(0.0, waveIntensity - 0.1)
    setShaderUniform("waves", "waveIntensity", waveIntensity)
    print("Wave intensity: " & str(waveIntensity))
  
  elif key == "c" or key == "C":
    colorMode = colorMode + 1.0
    if colorMode > 2.5:
      colorMode = 0.0
    setShaderUniform("waves", "colorMode", colorMode)
    
    if colorMode < 0.5:
      print("Color mode: Rainbow")
    elif colorMode < 1.5:
      print("Color mode: Grayscale")
    else:
      print("Color mode: Inverted")
```

```nim on:render
# Display current settings
drawText(2, 2, "Wave Intensity: " & str(waveIntensity), "#00ff00")
drawText(2, 3, "Animation: " & (if isAnimating: "ON" else: "OFF"), "#00ff00")

let modeText = if colorMode < 0.5: "Rainbow"
               elif colorMode < 1.5: "Grayscale"
               else: "Inverted"
drawText(2, 4, "Color Mode: " & modeText, "#00ff00")
```

---

## How It Works

1. **WGSL Code Block**: Define shaders with ` ```wgsl fragment:name`
2. **Uniforms**: Declare them in a `struct Uniforms` with `@binding(2)`
3. **Control**: Use `setShaderUniform()` to update values in real-time
4. **No Recompilation**: Changes happen instantly via GPU buffer updates!

The shader system:
- Automatically detects fragment shaders from code blocks
- Injects them into the render pipeline
- Makes their uniforms accessible via `setShaderUniform()`

This works for both **fragment shaders** (like this) and **compute shaders** (for parallel computation).
