# TStorie Shader Examples

This directory contains example WebGL shaders that can be loaded at runtime via URL parameters.

## Quick Start

1. Upload one of the shader files to a GitHub Gist
2. Use the gist ID in the URL: `?shader=YOUR_GIST_ID`
3. Combine with other parameters as needed

## Example Shaders

### apocalypcrt.js
Advanced CRT shader based on Apocalypse CRT with:
- CRT curvature/barrel distortion
- Aperture grille effect
- Horizontal sync glitches
- Scanlines
- RGB chromatic aberration
- Noise
- Flicker
- Vignette

**Parameters:**
- `grilleLvl`: 0.95
- `grilleDensity`: 800.0
- `scanlineLvl`: 0.8
- `scanlines`: 2.0
- `rgbOffset`: 0.001
- `noiseLevel`: 0.1
- `flicker`: 0.15
- `hSync`: 0.01
- `vignetteStart`: 0.25
- `vignetteLvl`: 20.0
- `curveStrength`: 0.95

## Creating Your Own Shader

1. Copy one of the example files
2. Modify the GLSL code in `fragmentShader`
3. Add/remove uniforms as needed
4. Upload to a GitHub Gist
5. Test with `?shader=GIST_ID`

## Shader Structure

```javascript
function getShaderConfig() {
    return {
        vertexShader: `...`,    // Vertex shader GLSL
        fragmentShader: `...`,  // Fragment shader GLSL
        uniforms: {             // Custom parameters
            paramName: value
        }
    };
}
```

## Built-in Uniforms

Your shader automatically receives:

- `sampler2D contentTexture` - The terminal canvas
- `float time` - Time in seconds since start
- `vec2 resolution` - Canvas dimensions in pixels

## Usage Examples

```bash
# Load with CRT shader
?shader=abc123def456

# Combine with story and custom font
?gist=story123&shader=shader456&font=Fira+Code

# All parameters together
?gist=mystory&shader=mycrt&font=https://fonts.googleapis.com/css2?family=VT323
```

## Testing Locally

You can test shaders locally by modifying the HTML to load the shader file directly:

```javascript
// In index.html, replace gist fetch with:
shaderCode = await fetch('example_shader.js').then(r => r.text());
shaderReady = true;
if (moduleReady) initShaderSystem();
```

## See Also

- [SHADER_SYSTEM.md](../docs/SHADER_SYSTEM.md) - Full shader system documentation
- [index_shader.html](index_shader.html) - Interactive shader editor (original CRT shader)
