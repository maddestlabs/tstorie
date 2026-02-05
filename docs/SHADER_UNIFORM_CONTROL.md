# Shader Uniform Control API

**New in TStorie**: Control WebGPU/WebGL shader uniforms dynamically from your nimini code!

## Overview

The shader uniform control API lets you modify shader parameters in real-time without recompiling shaders. This enables:

- **Interactive effects** - Respond to keyboard, mouse, or game state
- **Animated parameters** - Smoothly transition between visual effects
- **Data visualization** - Drive shader parameters from your application data
- **Performance optimization** - Uniforms are extremely cheap to update

## API Functions

### `setShaderUniform(shaderName, uniformName, value)`

Set a shader uniform value.

**Parameters:**
- `shaderName` (string) - Name of the shader (e.g., "paper", "crt", "custom")
- `uniformName` (string) - Name of the uniform variable
- `value` (number or array) - New value for the uniform
  - Single number: `0.5`, `1.0`, `42`
  - Vec2: `[x, y]`
  - Vec3: `[r, g, b]`
  - Vec4: `[x, y, z, w]`

**Examples:**
```nim
# Single float uniform
setShaderUniform("paper", "paperNoise", 0.5)

# Vec2 uniform
setShaderUniform("custom", "offset", [10.0, 20.0])

# Vec3 color uniform
setShaderUniform("custom", "tintColor", [1.0, 0.5, 0.2])

# Vec4 uniform
setShaderUniform("custom", "params", [1.0, 2.0, 3.0, 4.0])
```

### `getShaderUniform(shaderName, uniformName)`

Get the current value of a shader uniform (returns `nil` in current implementation - track values in your own variables for now).

**Parameters:**
- `shaderName` (string) - Name of the shader
- `uniformName` (string) - Name of the uniform variable

**Example:**
```nim
let intensity = getShaderUniform("paper", "paperNoise")
```

### `listShaderUniforms(shaderName)`

Print all available uniforms for a shader to the console.

**Parameters:**
- `shaderName` (string) - Name of the shader

**Example:**
```nim
listShaderUniforms("paper")
# Console output: [Shader] Uniforms for paper: {paperNoise: 0.2, noiseIntensity: 0.5, noiseMix: 0.5}
```

## Built-in Shader Uniforms

### Paper Shader
- `paperNoise` (float, 0.0-1.0) - Overall effect intensity
- `noiseIntensity` (float, 0.0-2.0) - Strength of noise pattern
- `noiseMix` (float, 0.0-1.0) - How much noise blends with color

### CRT Shader
- `curveStrength` (float, 0.0-0.5) - Screen curvature amount
- `frameSize` (float, 0.0-100.0) - Border/bezel size in pixels

### Other Shaders
See individual shader files in `/docs/shaders/` and `/docs/shaders/wgsl/` for available uniforms.

## Usage Patterns

### 1. Keyboard Control

```nim
on:input
if key == "+" then
  intensity = min(1.0, intensity + 0.05)
  setShaderUniform("paper", "paperNoise", intensity)
elif key == "-" then
  intensity = max(0.0, intensity - 0.05)
  setShaderUniform("paper", "paperNoise", intensity)
```

### 2. Animated Parameters

```nim
on:update
let t = getTime()
let pulse = (sin(t * 2.0) + 1.0) / 2.0  # 0.0 to 1.0
setShaderUniform("paper", "noiseMix", pulse * 0.5)
```

### 3. Data-Driven Effects

```nim
on:update
# Visualize data with shader intensity
let health = player.health / player.maxHealth
setShaderUniform("paper", "paperNoise", 1.0 - health)  # More paper as health decreases
```

### 4. Smooth Transitions

```nim
var targetIntensity = 0.5
var currentIntensity = 0.2

on:update
# Smoothly interpolate toward target
let speed = 5.0 * getDeltaTime()
currentIntensity = currentIntensity + (targetIntensity - currentIntensity) * speed
setShaderUniform("paper", "paperNoise", currentIntensity)

on:input
if key == "1" then targetIntensity = 0.2
elif key == "2" then targetIntensity = 0.5
elif key == "3" then targetIntensity = 0.8
```

### 5. Multiple Shader Control

```nim
# Control a shader chain
on:init
setShaderUniform("paper", "paperNoise", 0.3)
setShaderUniform("crt", "curveStrength", 0.15)
setShaderUniform("crt", "frameSize", 40.0)

on:input
if key == "p" then
  # Toggle paper effect
  paperEnabled = not paperEnabled
  setShaderUniform("paper", "paperNoise", if paperEnabled then 0.3 else 0.0)
```

## Performance

Uniform updates are **extremely cheap**:
- No shader recompilation
- Only updates a small GPU buffer
- Can update dozens of uniforms per frame with no impact
- Much faster than changing shader programs

## Custom Shaders

When you define your own shaders in `wgsl` blocks, make sure to:

1. **Include uniform struct:**
```wgsl
struct Uniforms {
    time: f32,
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
    myParam: f32,
    color: vec3f,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;
```

2. **Declare defaults in JavaScript config:**
```javascript
uniforms: {
    myParam: 1.0,
    color: [1.0, 0.5, 0.2]
}
```

3. **Control from nimini:**
```nim
setShaderUniform("myShader", "myParam", 0.8)
setShaderUniform("myShader", "color", [0.5, 1.0, 0.3])
```

## Demos

See these interactive demos:
- [shader-control-demo.md](demos/shader-control-demo.md) - Single shader control
- [multi-shader-control.md](demos/multi-shader-control.md) - Shader chain control

## Technical Details

### How It Works

1. Shaders are compiled once with uniform buffers
2. JavaScript reads `shader.uniforms` object every frame
3. Values are packed into Float32Array and uploaded to GPU
4. `setShaderUniform()` modifies the `shader.uniforms` object
5. Next frame picks up the new values automatically

### Uniform Packing

WebGPU requires vec4 alignment (16-byte):
- `float` - Single value (padded to 16 bytes)
- `vec2` - Two values (padded to 16 bytes)
- `vec3` - Three values (padded to 16 bytes)
- `vec4` - Four values (exactly 16 bytes)

The system handles this automatically.

### Browser Support

- ✅ WebGPU: Modern Chrome, Edge (2023+)
- ✅ WebGL: All modern browsers
- ✅ Works with both backends automatically

## Future Enhancements

Planned improvements:
- [ ] `getShaderUniform()` return actual values
- [ ] Type validation for uniform values
- [ ] Uniform value constraints (min/max)
- [ ] Preset system for common configurations
- [ ] Animation curves for smooth transitions
- [ ] Bind uniform to variables for auto-sync

## See Also

- [WGSL Shader Integration](../WGSL_SHADER_INTEGRATION.md)
- [Shader System](md/SHADER_SYSTEM.md)
- [WebGPU Integration](../WEBGPU.md)
