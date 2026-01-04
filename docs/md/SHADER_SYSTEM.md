# TStorie Shader System

The TStorie web runtime supports loading WebGL shaders from GitHub Gists to apply post-processing effects to the terminal canvas.

## Usage

Add the `shader` URL parameter to load a shader from a gist:

```
index.html?shader=YOUR_GIST_ID
```

Combine with other parameters:

```
index.html?gist=STORY_GIST_ID&shader=SHADER_GIST_ID&font=Fira+Code
```

## Shader Format

Create a JavaScript file that exports a `getShaderConfig()` function returning:

```javascript
function getShaderConfig() {
    return {
        vertexShader: "...",    // GLSL vertex shader source
        fragmentShader: "...",  // GLSL fragment shader source
        uniforms: {             // Optional custom uniforms
            paramName: value
        }
    };
}
```

## Built-in Uniforms

Your shader automatically receives these uniforms:

- `uniform sampler2D contentTexture` - The terminal canvas texture
- `uniform float time` - Time in seconds since shader start
- `uniform vec2 resolution` - Canvas resolution in pixels

## Cell-Aware Uniforms

For shaders that need to align with terminal character cells (like grid effects), use the special `cellSize` uniform:

```javascript
uniforms: {
    cellSize: [10.0, 20.0]  // Will be automatically updated with actual cell dimensions
}
```

The system will automatically replace this with the terminal's actual character cell dimensions (including device pixel ratio scaling). This allows effects to perfectly align with the text grid.

**Example use cases:**
- Grid overlays that match character cells
- Cell-based effects (per-character bloom, etc.)
- Alignment guides for ASCII art
- Graph paper backgrounds

See the `graphpaper.js` shader for a complete example.

## Vertex Shader

The vertex shader should output texture coordinates:

```glsl
attribute vec2 position;
varying vec2 vUv;

void main() {
    vUv = position * 0.5 + 0.5;  // Convert from [-1,1] to [0,1]
    gl_Position = vec4(position, 0.0, 1.0);
}
```

## Fragment Shader

The fragment shader receives the terminal canvas and applies effects:

```glsl
precision mediump float;

uniform sampler2D contentTexture;
uniform float time;
uniform vec2 resolution;

varying vec2 vUv;

void main() {
    vec2 uv = vUv;
    
    // Sample the terminal canvas
    vec3 color = texture2D(contentTexture, uv).rgb;
    
    // Apply your effects here
    
    gl_FragColor = vec4(color, 1.0);
}
```

## Examples

### Basic CRT Effect

```javascript
function getShaderConfig() {
    return {
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            void main() {
                vUv = position * 0.5 + 0.5;
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        fragmentShader: `
            precision mediump float;
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            uniform float scanlineIntensity;
            varying vec2 vUv;
            
            void main() {
                vec3 color = texture2D(contentTexture, vUv).rgb;
                
                // Add scanlines
                float scanline = sin(vUv.y * resolution.y * 3.14159 / 2.0);
                color *= (scanlineIntensity + (1.0 - scanlineIntensity) * scanline);
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            scanlineIntensity: 0.8
        }
    };
}
```

### RGB Shift

```javascript
fragmentShader: `
    precision mediump float;
    uniform sampler2D contentTexture;
    uniform float rgbShift;
    varying vec2 vUv;
    
    void main() {
        float offset = rgbShift * 0.002;
        vec3 color;
        color.r = texture2D(contentTexture, vUv + vec2(offset, 0.0)).r;
        color.g = texture2D(contentTexture, vUv).g;
        color.b = texture2D(contentTexture, vUv - vec2(offset, 0.0)).b;
        
        gl_FragColor = vec4(color, 1.0);
    }
`,
uniforms: {
    rgbShift: 1.0
}
```

### CRT Curvature

```javascript
fragmentShader: `
    precision mediump float;
    uniform sampler2D contentTexture;
    uniform float curveStrength;
    varying vec2 vUv;
    
    void main() {
        vec2 uv = vUv;
        vec2 center = vec2(0.5, 0.5);
        
        // Apply barrel distortion
        float dist = length(uv - center);
        uv += (uv - center) * pow(dist, 5.0) * curveStrength;
        
        // Check if UV is out of bounds
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
        
        vec3 color = texture2D(contentTexture, uv).rgb;
        gl_FragColor = vec4(color, 1.0);
    }
`,
uniforms: {
    curveStrength: 0.95
}
```

## How It Works

1. The shader system creates an offscreen canvas for terminal rendering
2. WebGL renders the terminal canvas as a texture
3. The shader is applied to a fullscreen quad
4. The result is displayed on the visible canvas

## Example Shaders

See the `web/` directory for complete examples:

- `example_shader.js` - Basic CRT effect with scanlines, RGB shift, and noise
- `crt_shader.js` - Full CRT shader based on Apocalypse CRT

## Creating a Gist

1. Create a new file with `.js` extension
2. Paste your shader code
3. Create a public gist on GitHub
4. Use the gist ID in the URL: `?shader=YOUR_GIST_ID`

## Troubleshooting

- **Black screen**: Check browser console for shader compilation errors
- **"Shader must export getShaderConfig()"**: Make sure the function is defined at global scope
- **"No .js file found"**: The gist must contain a `.js` file
- **Shader not loading**: Check Network tab for failed gist API request

## Performance

Shaders run at the refresh rate of your display (typically 60 FPS). Complex shaders may impact performance on lower-end devices. Test on your target hardware.

## Advanced: Multiple Passes

For multi-pass effects, you'll need to modify the shader system. The current implementation supports single-pass effects only.
