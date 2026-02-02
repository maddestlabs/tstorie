# WebGPU Shader System Documentation

## Overview

TStorie's WebGPU shader system provides real-time post-processing effects for terminal content. Shaders are written in WGSL (WebGPU Shading Language) and can be chained together for complex effects.

**Key Files:**
- `docs/webgpu_shader_system.js` - Core shader compilation and uniform management with WGSL-aware packing
- `docs/shaders/wgsl/*.wgsl.js` - Individual shader implementations (36+ shaders available)
- `docs/index-webgpu.html` - Entry point with shader parameter parsing
- `web/font_metrics_bridge.js` - Bridge for loading shaders from frontmatter

## Loading Shaders

### Via URL Parameter

Load shaders by adding `?shader=` to the URL with `+` separating shader names:

```
http://localhost:8000/docs/index-webgpu.html?content=demo&shader=paper+ruledlines
http://localhost:8000/docs/index-webgpu.html?content=demo&shader=invert+crt+bloom
```

### Via Frontmatter

In your markdown file, specify shaders in the YAML frontmatter:

```yaml
---
title: "My Demo"
theme: "coffee"
shaders: "paper+ruledlines"
fontsize: 16
---
```

The system automatically:
1. Detects WebGPU support and prefers WGSL shaders (`shaders/wgsl/*.wgsl.js`)
2. Falls back to GLSL shaders (`shaders/*.js`) if WGSL version not found
3. Loads from local files first, then tries GitHub Gist if not found locally
4. Initializes the shader pipeline after the terminal is ready

**Note:** Frontmatter shaders are only applied if no URL `?shader=` parameter is present (URL takes precedence).

## Shader Chaining

Shaders can be chained together for complex effects. Each shader receives the output of the previous shader as input.

### Via URL

Chain shaders with `+` separator:
```
http://localhost:8000/docs/index-webgpu.html?content=demo&shader=paper+ruledlines+lightvignette
http://localhost:8000/docs/index-webgpu.html?shader=invert+crt+scanlines
```

### Via Frontmatter

```yaml
---
shaders: "paper+filmgrain+crt"
---
```

### Recommended Combinations

**Paper Document:**
```
paper+ruledlines+lightvignette
```

**Vintage Terminal:**
```
crt+scanlines+filmgrain
```

**Cyberpunk:**
```
cyberpunkglow+gridpro+scanlines
```

**Old Film:**
```
filmgrain+filmlines+filmhairs+soften
```

**Dramatic Spotlight:**
```
paper+lightson
```

## Shader Structure

Each shader is a JavaScript file exporting a `getShaderConfig()` function:

```javascript
function getShaderConfig() {
    return {
        vertexShader: `/* WGSL vertex shader */`,
        fragmentShader: `/* WGSL fragment shader */`,
        uniforms: {
            // Custom uniform values
        }
    };
}
```

## Uniform Buffer Layout (CRITICAL)

### WGSL-aware packing (recommended)

As of January 2026, the WebGPU shader system uses a **WGSL-aware uniform packer**.

Instead of “pushing floats” in JavaScript, it:
1. Locates the `@group(0) @binding(2) var<uniform> … : SomeStruct;` declaration.
2. Parses `struct SomeStruct { ... }`.
3. Computes WGSL-uniform byte offsets (including tricky cases like `vec3f` + `f32`).
4. Writes each field at the correct byte offset.

**What this fixes:** the classic failure mode where a shader compiles but renders “nothing” because the JS packer’s padding rules don’t match WGSL struct layout.

**Special field names (auto-populated):**
- `time` (`f32`) — seconds since shader system start
- `resolution` (`vec2f`) — terminal canvas pixel size
- `cellSize` (`vec2f`) — pulled from `window.terminal.charWidth/charHeight` when available; otherwise uses the shader’s default

All other struct fields are filled from the shader’s `uniforms` object by **matching field name**.

### Legacy packing (fallback)

If the WGSL-aware parser can’t understand a uniform struct, the system falls back to the old packing strategy:
- Writes `time` + padding, then `resolution` + padding
- Appends custom uniforms in JS insertion order
- Pads `vec2` to 4 floats, pads `vec3` to 4 floats

If a shader relies on fallback packing, you may need explicit `_padN` fields and careful ordering.

### The `vec3 + f32` pitfall

WGSL uniform layout allows a `f32` to sit “inside” the same 16-byte slot as a preceding `vec3f` (because `vec3f` is 12 bytes).
The old JS packer incorrectly padded every `vec3` to 16 bytes, shifting subsequent fields.

With the WGSL-aware packer, you can write natural WGSL like:
```wgsl
gridColor: vec3f,
gridAlpha: f32,
```
and it will pack correctly.

## WGSL Syntax Requirements

### 1. Uniform Control Flow for `textureSample`

**Problem:** WGSL requires `textureSample` to be called in uniform control flow.

**Wrong:**
```wgsl
if (dist < radius) {
    let color = textureSample(tex, samp, uv);  // ERROR: non-uniform control flow
    return vec4f(color, 1.0);
} else {
    return vec4f(1.0, 0.0, 0.0, 1.0);
}
```

**Correct:**
```wgsl
let color = textureSample(tex, samp, uv);  // Always sample first
let red = vec3f(1.0, 0.0, 0.0);
let inside = dist < radius;
let outColor = select(red, color.rgb, inside);  // Use select()
return vec4f(outColor, 1.0);
```

### 2. Function Declarations

All functions must use `fn` keyword:

```wgsl
fn myFunction(x: f32) -> f32 {
    return x * 2.0;
}
```

### 3. Variable Declarations

Use `let` for constants, `var` for mutable variables:

```wgsl
let constant = 1.0;  // Immutable
var mutable = 0.0;   // Mutable
mutable = 2.0;       // OK
```

## Lighting Shaders: The Correct Approach

### The Problem

After extensive testing, we discovered that **additive and ambient-based lighting approaches fail** for both light and dark themes:

- **Additive only:** `baseColor + spotlight` - Darkens everything if ambient is low
- **Ambient multiply:** `baseColor * (ambient + spotlight)` - With high ambient (0.85), just brightens uniformly; with low ambient (0.15), darkens everything

### The Solution: Multiplicative Lighting

**Key Insight:** Use pure multiplicative lighting where the lighting term represents the final brightness multiplier:

```wgsl
let lighting = uniforms.ambient + spot * uniforms.intensity;
let finalColor = baseColor.rgb * lighting;
```

**Why This Works:**
- `ambient` (e.g., 0.08) darkens outside the spotlight
- `spot` (0.0 to 1.0) controls where light is applied
- `intensity` (e.g., 1.2) controls spotlight brightness
- Inside spotlight: `lighting = 0.08 + 1.0 * 1.2 = 1.28` → brightens
- Outside spotlight: `lighting = 0.08 + 0.0 * 1.2 = 0.08` → darkens

### Working Spotlight Example

See `docs/shaders/wgsl/lightson.wgsl.js` for the complete implementation.

**Key Components:**

1. **Aspect-corrected distance** (prevents ellipses):
```wgsl
let aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
let delta = (uv - uniforms.lightPos) * vec2f(aspect, 1.0);
let dist = length(delta);
```

2. **Smooth radial falloff**:
```wgsl
let spot = 1.0 - smoothstep(uniforms.radius, uniforms.radius + uniforms.softness, dist);
```

3. **Multiplicative lighting**:
```wgsl
let lighting = uniforms.ambient + spot * uniforms.intensity;
let finalColor = baseColor.rgb * lighting;
```

**Typical Uniform Values:**
```javascript
uniforms: {
    lightPos: [0.5, 0.5],   // Center of screen (UV space)
    radius: 0.35,           // Spotlight radius in UV space
    softness: 0.15,         // Edge softness
    intensity: 1.2,         // Brightness inside spotlight (>1.0 brightens)
    ambient: 0.08           // Darkness outside spotlight (0.0-0.2 for dramatic)
}
```

## Common Shader Patterns

### Aspect-Corrected Circular Effects

Prevent ellipses by correcting for aspect ratio:

```wgsl
let aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
let center = vec2f(0.5, 0.5);
let delta = (uv - center) * vec2f(aspect, 1.0);
let dist = length(delta);
```

### Smooth Radial Falloff

Use `smoothstep` for soft edges:

```wgsl
let spot = 1.0 - smoothstep(innerRadius, outerRadius, dist);
```

### Circular Mask/Vignette

```wgsl
let center = vec2f(0.5, 0.5);
let aspect = uniforms.resolution.x / uniforms.resolution.y;
let delta = (uv - center) * vec2f(aspect, 1.0);
let dist = length(delta);
let mask = 1.0 - smoothstep(innerRadius, outerRadius, dist);
```

### Color Modulation

```wgsl
let baseColor = textureSample(contentTexture, contentTextureSampler, uv).rgb;
let modulation = someEffect();  // 0.0 to 1.0
let finalColor = mix(baseColor, targetColor, modulation);
```

### Time-based Animation

```wgsl
let phase = sin(uniforms.time * speed) * amplitude;
let animatedValue = baseValue + phase;
```

## Creating New Light-Based Shaders

### 1. Swaying Light

Add time-based position offset:
```wgsl
let swayOffset = sin(uniforms.time * uniforms.swaySpeed) * uniforms.swayAmount;
let lightPos = vec2f(uniforms.lightPos.x + swayOffset, uniforms.lightPos.y);
```

### 2. Flickering Light

Modulate intensity with noise or random values:
```wgsl
let flicker = sin(uniforms.time * 17.3) * 0.5 + 0.5;
let dynamicIntensity = uniforms.intensity * (0.8 + flicker * 0.2);
```

### 3. Multiple Light Sources

Calculate lighting contribution from each source and sum:
```wgsl
let light1 = calculateSpotlight(uv, uniforms.light1Pos, uniforms.light1Radius);
let light2 = calculateSpotlight(uv, uniforms.light2Pos, uniforms.light2Radius);
let totalLighting = uniforms.ambient + light1 + light2;
let finalColor = baseColor.rgb * min(totalLighting, 2.0);  // Clamp to prevent over-brightening
```

### 4. Colored Lights

Apply color tint within lighting calculation:
```wgsl
let spotlight = spot * uniforms.intensity;
let lightColor = uniforms.lightColor;  // vec3f
let lighting = uniforms.ambient + spotlight;
let coloredLighting = vec3f(
    uniforms.ambient + spotlight * lightColor.r,
    uniforms.ambient + spotlight * lightColor.g,
    uniforms.ambient + spotlight * lightColor.b
);
let finalColor = baseColor.rgb * coloredLighting;
```

## Performance Optimization

### 1. Inline Helper Functions

Instead of:
```wgsl
fn getDistance(uv: vec2f, pos: vec2f) -> f32 { ... }
let dist = getDistance(uv, lightPos);
```

Do:
```wgsl
let delta = (uv - lightPos) * vec2f(aspect, 1.0);
let dist = length(delta);
```

### 2. Minimize Texture Samples

Sample once, reuse the result:
```wgsl
let baseColor = textureSample(contentTexture, contentTextureSampler, uv).rgb;
// Use baseColor multiple times
```

### 3. Precompute Constants

```wgsl
let softEdge = uniforms.radius + uniforms.softness;
let spot = 1.0 - smoothstep(uniforms.radius, softEdge, dist);
```

## Debugging Shaders

### 1. Visualize Intermediate Values

Return intermediate calculations as colors:
```wgsl
// Debug distance field
return vec4f(dist, dist, dist, 1.0);

// Debug spotlight mask
return vec4f(spot, spot, spot, 1.0);

// Debug UVs
return vec4f(uv.x, uv.y, 0.0, 1.0);

// Debug uniforms (e.g., cellSize)
return vec4f(uniforms.cellSize.x / 100.0, uniforms.cellSize.y / 100.0, 0.0, 1.0);
```

### 2. Console Logging

#### One-time uniform layout dump (recommended)

Add URL params to print the **computed WGSL uniform layout** as a `console.table` (once per shader per page load):

- Dump layouts for all shaders:
    - `index-webgpu.html?...&debugUniformLayouts=1`
- Dump layout for a single shader only:
    - `index-webgpu.html?...&debugUniformLayouts=1&debugUniformShader=grid`

This is implemented in `docs/webgpu_shader_system.js` and is the fastest way to confirm whether a shader is reading the uniforms you think it is.

### 3. Browser DevTools

- **Console**: Check for WebGPU compilation errors and warnings
- **Performance tab**: Profile shader performance
- **about:gpu** (Chrome): Verify WebGPU is enabled and feature support

### 4. Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| Entire screen one color | Wrong select() arguments | Swap true/false cases |
| Elliptical circle | Missing aspect correction | Multiply delta by `vec2f(aspect, 1.0)` |
| Compilation error | Missing struct padding | Add `_padN` fields to align vec2/vec3 |
| Non-uniform control flow | textureSample in if-block | Always sample, use select() |
| Uniform lighting (no falloff) | Wrong lighting formula | Use multiplicative: `baseColor * lighting` |
| Shader compiles but no effect | Uniform layout mismatch | Enable `debugUniformLayouts=1` and verify offsets/types |
| Shader loads but doesn't render | JavaScript syntax error in shader file | Check browser console for eval errors |
| Frontmatter shaders ignored | URL `?shader=` parameter present | Remove URL param or use URL param for overrides |
| WGSL compilation fails | GLSL syntax in WGSL shader | Convert texture2D→textureSample, varying→@location, etc. |

## Browser Compatibility

### Supported Browsers

| Browser | Version | Notes |
|---------|---------|-------|
| Chrome/Edge | 113+ | Full WebGPU support (recommended) |
| Safari | 18+ | Requires macOS Sonoma 14.3+ |
| Firefox | Nightly | Enable `dom.webgpu.enabled` flag |

### Feature Detection

The system automatically detects WebGPU support:
- **WebGPU available**: Uses `shaders/wgsl/*.wgsl.js` (high performance)
- **WebGPU unavailable**: Falls back to `shaders/*.js` (WebGL, compatibility mode)

Check support in console:
```javascript
console.log('WebGPU supported:', navigator.gpu !== undefined);
```

## Shader Chaining

Test multiple shaders with `?shader=shader1+shader2+shader3`:
```
http://localhost:8000/docs/index-webgpu.html?shader=invert+paper+lightson
```

Each shader receives the output of the previous shader as its input texture.

## Working Shader Examples

### Paper & Texture Effects
- **paper.wgsl.js** - Subtle paper grain/noise for realistic paper texture
- **paperdirt.wgsl.js** - Paper texture with dirt/aging spots
- **crumpled.wgsl.js** - Crumpled paper texture with distortion
- **sand.wgsl.js** - Sandy/grainy texture effect
- **twill.wgsl.js** - Fabric/twill weave pattern
- **sketched.wgsl.js** - Hand-drawn sketch effect
- **specks.wgsl.js** - Random speckle/dust particles

### Grid & Line Effects
- **grid.wgsl.js** - Soft-edged grid for double-width character cells (zen aesthetic)
- **grid1x.wgsl.js** - Single-width character grid
- **grid2x.wgsl.js** - Double-width character grid
- **ruledlines.wgsl.js** - Notebook-style ruled lines for paper effect
- **grille.wgsl.js** - CRT-style shadow mask grille pattern
- **scanlines.wgsl.js** - Horizontal scanline effect

### CRT & Retro Effects
- **crt.wgsl.js** - Curved CRT screen with decorative frame
- **apocalypcrt.wgsl.js** - Post-apocalyptic distressed CRT effect
- **scanlines.wgsl.js** - Classic CRT scanlines
- **grille.wgsl.js** - CRT shadow mask

### Film & Vintage Effects
- **filmgrain.wgsl.js** - Film grain noise
- **filmgrainpro.wgsl.js** - Advanced film grain with more controls
- **filmlines.wgsl.js** - Vertical film scratch lines
- **filmhairs.wgsl.js** - Film damage artifacts (hairs, scratches)

### Lighting Effects
- **lightson.wgsl.js** - Circular spotlight with multiplicative lighting (recommended)
- **lightspot.wgsl.js** - Alternative spotlight implementation
- **lightvignette.wgsl.js** - Vignette/edge darkening effect
- **lightnight.wgsl.js** - Night vision/low-light effect
- **lightsway.wgsl.js** - Swaying/animated light effect

### Blur & Glow Effects
- **blur.wgsl.js** - Simple box blur
- **blurgradual.wgsl.js** - Gradual blur with distance falloff
- **soften.wgsl.js** - Soft focus/gentle blur
- **bloom.wgsl.js** - Radial Gaussian blur with brightness extraction
- **cyberpunkglow.wgsl.js** - Neon glow/cyberpunk style

### Gradient & Color Effects
- **gradientviolet.wgsl.js** - Violet/purple gradient overlay
- **gradientblends.wgsl.js** - Smooth color gradient blending
- **invert.wgsl.js** - Simple color inversion
- **clouds.wgsl.js** - Cloud-like procedural patterns

### Edge & Outline Effects
- **border.wgsl.js** - Solid color border (uses select() for uniform control flow)
- **outline.wgsl.js** - Edge detection/outline effect

### Pixel & Noise Effects
- **pixelnoise.wgsl.js** - Pixelated noise patterns

## Future Improvements

1. **Two-pass separable blur** - For true Gaussian bloom (requires render-to-texture)
2. **Light animation presets** - Flickering candle, swinging lamp, etc.
3. **Shadow casting** - Raymarched shadows from light sources
4. **Dynamic light count** - Uniform array of light positions/properties
5. **Compute shader integration** - GPU-accelerated effects (noise generation, blur passes)
6. **Shader hot-reload** - Edit shaders and see changes without page reload
7. **Shader parameter UI** - Real-time uniform tweaking in the browser

## Creating Your Own Shaders

### Basic Template

```javascript
// My Custom Shader
// Description of what it does

function getShaderConfig() {
    return {
        vertexShader: `struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) vUv: vec2f,
}

@vertex
fn vertexMain(
    @location(0) position: vec2f
) -> VertexOutput {
    var output: VertexOutput;
    output.vUv = position * 0.5 + 0.5;
    output.vUv.y = 1.0 - output.vUv.y;
    output.position = vec4f(position, 0.0, 1.0);
    return output;
}`,
        
        fragmentShader: `@group(0) @binding(0) var contentTexture: texture_2d<f32>;
@group(0) @binding(1) var contentTextureSampler: sampler;

struct Uniforms {
    time: f32,
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
    resolution: vec2f,
    _pad3: f32,
    _pad4: f32,
    cellSize: vec2f,
    _pad5: f32,
    _pad6: f32,
    // Add your custom uniforms here
    myParam: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {
    // Sample the input texture
    let color = textureSample(contentTexture, contentTextureSampler, vUv);
    
    // Apply your effect
    let finalColor = color.rgb; // Modify this
    
    return vec4f(finalColor, 1.0);
}`,
        
        uniforms: {
            // Default values for custom uniforms
            myParam: 1.0,
        }
    };
}
```

### Testing Your Shader

1. Save your shader as `docs/shaders/wgsl/myshader.wgsl.js`
2. Test via URL: `http://localhost:8000/docs/index-webgpu.html?shader=myshader`
3. Chain with others: `?shader=paper+myshader+lightvignette`
4. Debug uniforms: `?shader=myshader&debugUniformLayouts=1`

### Shader Conversion from GLSL

If you have an existing GLSL shader, convert it to WGSL:

| GLSL | WGSL |
|------|------|
| `varying vec2 vUv;` | `@location(0) vUv: vec2f` |
| `uniform sampler2D tex;` | `@group(0) @binding(0) var tex: texture_2d<f32>;` |
| `texture2D(tex, uv)` | `textureSample(tex, sampler, uv)` |
| `vec2`, `vec3`, `vec4` | `vec2f`, `vec3f`, `vec4f` |
| `void main()` | `fn fragmentMain() -> @location(0) vec4f` |
| `gl_FragColor = ...` | `return vec4f(...)` |

## References

- [WGSL Specification](https://www.w3.org/TR/WGSL/)
- [WebGPU Fundamentals](https://webgpufundamentals.org/)
- [WGSL Uniform Control Flow](https://gpuweb.github.io/gpuweb/wgsl/#uniformity)
