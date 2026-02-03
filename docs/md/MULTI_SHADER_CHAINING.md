# Multi-Shader Chaining

tStorie now supports chaining multiple shaders together for complex visual effects! Use the `+` operator in the shader URL parameter to combine effects.

## Basic Usage

```bash
# Single shader (works as before)
?shaders=invert

# Chain multiple shaders
?shaders=invert+crt

# Three or more shaders
?shaders=blur+invert+crt
```

## How It Works

Multi-shader chaining uses **framebuffer-based multi-pass rendering**:

1. Terminal renders to offscreen canvas
2. Shader 1 processes terminal → outputs to Framebuffer 1
3. Shader 2 processes Framebuffer 1 → outputs to Framebuffer 2
4. Shader N processes Framebuffer N-1 → outputs to screen

Each shader sees the output of the previous shader, creating a compositing pipeline.

## Order Matters!

Shader order affects the final result:

```bash
# These produce different results:
?shaders=invert+crt     # Inverts colors, THEN applies CRT effect
?shaders=crt+invert     # Applies CRT effect, THEN inverts colors

?shaders=blur+graphpaper   # Blurs terminal, then overlays graph paper
?shaders=graphpaper+blur   # Overlays graph paper, then blurs everything
```

## Available Shaders

Current shaders in `docs/shaders/`:

- **invert** - Inverts all colors
- **crt** - Classic CRT monitor effect with scanlines
- **crtbloom** - CRT with bloom/glow effect
- **graphpaper** - Realistic graph paper overlay
- **notebook** - Notebook paper style
- **blur** - Simple box blur (NEW!)

## Example Combinations

### Subtle Effects
```bash
?shaders=blur+crt
# Softens text before applying CRT for smoother scanlines
```

### Dramatic Effects
```bash
?shaders=invert+crtbloom
# Inverted colors with glowing CRT bloom
```

### Paper Textures
```bash
?shaders=graphpaper+blur
# Graph paper with slightly softened lines
```

### Testing Variations
```bash
?shaders=blur+blur+blur
# Triple blur for extreme softness
```

## Performance

- **Single shader**: ~60 FPS (baseline)
- **2-3 shaders**: Still 60 FPS on modern hardware
- **4+ shaders**: May impact performance on slower devices

Each shader pass adds:
- One framebuffer allocation
- One fullscreen quad draw call
- Texture upload/download overhead

The system automatically resizes framebuffers when the window changes size.

## Creating Chain-Friendly Shaders

When creating shaders for chaining:

1. **Always read from `contentTexture`** - this contains the previous shader's output
2. **Preserve alpha channel** - unless you specifically want to modify transparency
3. **Keep uniforms simple** - avoid name conflicts with other shaders
4. **Test in chains** - try your shader both first and last in a chain

Example shader template:

```javascript
function getShaderConfig() {
    return {
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            
            void main() {
                vUv = position * 0.5 + 0.5;
                vUv.y = 1.0 - vUv.y;
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        fragmentShader: `
            precision mediump float;
            
            uniform sampler2D contentTexture;  // Previous shader output
            uniform float time;                 // Animation time
            uniform vec2 resolution;            // Screen resolution
            
            varying vec2 vUv;
            
            void main() {
                // Sample input
                vec4 color = texture2D(contentTexture, vUv);
                
                // Apply your effect
                // ... modify color ...
                
                gl_FragColor = color;
            }
        `,
        
        uniforms: {
            // Your custom uniforms here
        }
    };
}
```

## Technical Details

### Framebuffer Management

- System creates (N-1) framebuffers for N shaders
- Last shader renders directly to screen
- Framebuffers automatically resize with window
- All framebuffers use RGBA format with LINEAR filtering

### Shader Compilation

- Shaders loaded in parallel for faster startup
- Each shader compiled into separate WebGL program
- Isolated eval scopes prevent variable conflicts
- Detailed error messages show which shader failed

### Render Loop

```javascript
// Pseudocode for multi-pass rendering
for each shader in chain:
    bind_framebuffer(shader.index)  // null for last shader
    use_program(shader.program)
    bind_texture(previous_output)
    set_uniforms(time, resolution, ...)
    draw_fullscreen_quad()
```

## Backward Compatibility

Single shader URLs continue to work exactly as before:

```bash
# These are equivalent:
?shaders=crt
?shaders=crt+          # Trailing + ignored
```

## Limitations

1. **Mobile devices** - Limit to 2-3 shaders for performance
2. **WebGL 1.0** - Uses WebGL 1.0 for maximum compatibility
3. **Memory** - Each framebuffer uses screen_width × screen_height × 4 bytes
4. **Uniform conflicts** - Shaders with same custom uniform names may conflict

## Future Enhancements

Potential additions:

- Shader parameters: `?shaders=blur(radius:5)+crt` (also accepts `?shader=` for back-compat)
- Shader library browser
- Visual shader chain editor
- Per-shader enable/disable toggle
- Shader hot-reloading for development

## Examples in the Wild

Try these URLs:

```bash
# Classic terminal look with slight blur
index.html?demo=welcome&shader=blur+crt

# Inverted colors on graph paper
index.html?demo=welcome&shader=graphpaper+invert

# Maximum retro
index.html?demo=particles&shader=blur+crtbloom

# Soft notebook aesthetic
index.html?demo=mandala&shader=notebook+blur
```

## Debugging

Open browser console to see shader chain info:

- Shader loading progress
- Compilation status
- Framebuffer creation
- Real-time rendering pipeline

Console messages show the shader chain as: `shader1 → shader2 → shader3`

---

**Have fun experimenting with shader combinations!** The possibilities are endless when you can chain simple effects into complex visuals.
