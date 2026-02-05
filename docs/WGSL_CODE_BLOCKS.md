# WGSL Shader Code Blocks

TStorie supports inline WGSL (WebGPU Shading Language) shaders that can be defined directly in your markdown and controlled via nimini code.

## Fragment Shaders

Fragment shaders process the terminal display for visual effects.

### Basic Syntax

````markdown
```wgsl fragment:shaderName
// Your WGSL code here
```
````

### Required Structure

```wgsl
// 1. Uniforms struct (optional)
struct Uniforms {
  time: f32,
  customParam: f32,
};

// 2. Bindings
@group(0) @binding(2) var<uniform> uniforms: Uniforms;
@group(0) @binding(0) var inputTexture: texture_2d<f32>;
@group(0) @binding(1) var inputSampler: sampler;

// 3. Vertex shader (or use default)
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

// 4. Fragment shader
@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
  var color = textureSample(inputTexture, inputSampler, input.uv);
  // Your effect here
  return color;
}
```

### Automatic Uniforms

The system automatically provides these uniforms:

- `time: f32` - Elapsed time in seconds
- `resolution: vec2f` - Screen resolution (width, height)

You can add your own custom uniforms and control them with `setShaderUniform()`.

### Controlling Shaders

```nim
# Set uniform values
setShaderUniform("myShader", "intensity", 0.8)
setShaderUniform("myShader", "color", [1.0, 0.5, 0.2])

# Get current value (returns value or nil)
let value = getShaderUniform("myShader", "intensity")

# List all uniforms
listShaderUniforms("myShader")
```

## Complete Example

````markdown
---
title: My Shader Demo
---

```wgsl fragment:ripple
struct Uniforms {
  time: f32,
  resolution: vec2f,
  waveSpeed: f32,
  waveIntensity: f32,
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
  let center = vec2f(0.5, 0.5);
  let dist = distance(input.uv, center);
  let wave = sin(dist * 20.0 - uniforms.time * uniforms.waveSpeed) * uniforms.waveIntensity;
  
  let distortedUV = input.uv + wave * 0.02;
  return textureSample(inputTexture, inputSampler, distortedUV);
}
```

```nim on:init
var speed = 2.0
var intensity = 0.5
var shadersInitialized = false
```

```nim on:update
if not shadersInitialized:
  setShaderUniform("ripple", "waveSpeed", speed)
  setShaderUniform("ripple", "waveIntensity", intensity)
  shadersInitialized = true
```

```nim on:input
if event.type == "text":
  if event.text == "+":
    intensity = min(1.0, intensity + 0.1)
    setShaderUniform("ripple", "waveIntensity", intensity)
```
````

## Compute Shaders (Future)

Compute shaders for parallel computation will be supported in the future:

```wgsl compute:myCompute
@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3u) {
  // Parallel computation
}
```

## Built-in Shaders

TStorie includes these built-in shaders (controlled the same way):

- `paper` - Paper texture effect
- `invert` - Color inversion
- `crt` - CRT monitor simulation
- `scanlines` - Horizontal scanlines
- `vignette` - Edge darkening

## Tips

1. **Initialize in on:update**: Shaders load asynchronously, so set uniforms in `on:update` with a flag
2. **Test incrementally**: Start with simple effects and build complexity
3. **Watch the console**: Shader compilation errors appear in browser console
4. **Vector uniforms**: Use arrays for vec2/vec3/vec4: `[x, y, z, w]`
5. **Performance**: Keep fragment shaders efficient - they run per pixel!

## Architecture

- WGSL shaders are parsed at markdown load time
- Fragment shaders are injected into the WebGPU render pipeline
- Uniforms are updated via GPU buffer writes (no recompilation)
- Changes are applied in real-time on the next frame

## See Also

- [SHADER_UNIFORM_CONTROL.md](SHADER_UNIFORM_CONTROL.md) - Uniform API reference
- [demos/shader-control-demo.md](demos/shader-control-demo.md) - Built-in shader demo
- [demos/custom-shader-demo.md](demos/custom-shader-demo.md) - Custom WGSL demo
- [demos/wgsl-test.md](demos/wgsl-test.md) - Simple test
