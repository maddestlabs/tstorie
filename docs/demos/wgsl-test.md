---
title: Simple WGSL Test
---

# WGSL Fragment Shader Test

Testing inline WGSL shader definition.

```wgsl fragment:tint
// Simple color tint shader

struct Uniforms {
  time: f32,
  _pad0: f32,
  _pad1: f32,
  _pad2: f32,
  resolution: vec2f,
  _pad3: f32,
  _pad4: f32,
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
  // Flip Y coordinate for WebGPU texture coordinates (origin at top-left)
  output.uv = vec2f(pos.x * 0.5 + 0.5, 0.5 - pos.y * 0.5);
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
# Keep trying to set uniforms until shader system is ready
# setShaderUniform will log warnings until system initializes, then succeed
if not shadersInitialized:
  setShaderUniform("tint", "tintR", 1.0)
  setShaderUniform("tint", "tintG", 0.5)  # Pink!
  setShaderUniform("tint", "tintB", 0.0)
  # Only set as initialized after a few frames to ensure it had time to apply
  if getFrameCount() > 10:
    shadersInitialized = true
    print("✓ Pink tint shader configured!")
```

```nim on:render
# Simple rendering on default layer (layer 0)
# Draw bright content so pink tint is visible
draw(0, 5, 5, "╔════════════════════════════════╗", getStyle("accent1"))
draw(0, 5, 6, "║  WGSL SHADER TEST - PINK TINT ║", getStyle("accent1"))
draw(0, 5, 7, "╠════════════════════════════════╣", getStyle("accent1"))
draw(0, 5, 8, "║                                ║", getStyle("default"))
draw(0, 5, 9, "║  Tint: R=1.0 G=0.5 B=1.0       ║", getStyle("success"))
draw(0, 5, 10, "║                                ║", getStyle("default"))
draw(0, 5, 11, "║  White text should be PINK     ║", getStyle("default"))
draw(0, 5, 12, "║  Green text should be YELLOW   ║", getStyle("success"))
draw(0, 5, 13, "║  Cyan text should be MAGENTA   ║", getStyle("info"))
draw(0, 5, 14, "║                                ║", getStyle("default"))
draw(0, 5, 15, "╚════════════════════════════════╝", getStyle("accent1"))
```
