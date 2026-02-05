---
title: Simple WGSL Test
---

# WGSL Fragment Shader Test

Testing inline WGSL shader definition.

```wgsl fragment:tint
// Simple color tint shader

struct Uniforms {
  time: f32,
  resolution: vec2f,
  tintR: f32,
  tintG: f32,
  tintB: f32,
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
  var color = textureSample(inputTexture, inputSampler, input.uv);
  let tint = vec3f(uniforms.tintR, uniforms.tintG, uniforms.tintB);
  color = vec4f(color.rgb * tint, color.a);
  return color;
}
```

```nim on:init
var shadersInitialized = false
```

```nim on:update
if not shadersInitialized:
  setShaderUniform("tint", "tintR", 1.0)
  setShaderUniform("tint", "tintG", 0.5)
  setShaderUniform("tint", "tintB", 1.0)
  shadersInitialized = true
  print("Tint shader initialized!")
```

```nim on:render
draw(0, 2, 2, "WGSL shader test - should see pink tint", getStyle("accent1"))
```
