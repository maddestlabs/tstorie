// Pencil Sketch Shader for tStorie
// Creates realistic hand-drawn pencil sketch effect
// Uses edge detection, hatching patterns, and paper texture simulation

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
            precision highp float;
            
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            uniform float sketchIntensity;    // How strong the sketch lines are
            uniform float hatchDensity;       // Density of hatching lines
            uniform float edgeThreshold;      // Sensitivity to edges
            uniform float paperRoughness;     // Paper texture grain
            uniform float lineWeight;         // Thickness of sketch lines
            
            varying vec2 vUv;
            
            // Random function for paper texture
            float random(vec2 st) {
                return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
            }
            
            // Noise function for organic texture
            float noise(vec2 st) {
                vec2 i = floor(st);
                vec2 f = fract(st);
                
                float a = random(i);
                float b = random(i + vec2(1.0, 0.0));
                float c = random(i + vec2(0.0, 1.0));
                float d = random(i + vec2(1.0, 1.0));
                
                vec2 u = f * f * (3.0 - 2.0 * f);
                
                return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
            }
            
            // Calculate luminance
            float luminance(vec3 color) {
                return dot(color, vec3(0.299, 0.587, 0.114));
            }
            
            // Sobel edge detection
            float detectEdges(vec2 uv) {
                vec2 texelSize = 1.0 / resolution;
                
                // Sample 3x3 neighborhood
                float tl = luminance(texture2D(contentTexture, uv + vec2(-1.0, -1.0) * texelSize).rgb);
                float t  = luminance(texture2D(contentTexture, uv + vec2( 0.0, -1.0) * texelSize).rgb);
                float tr = luminance(texture2D(contentTexture, uv + vec2( 1.0, -1.0) * texelSize).rgb);
                float l  = luminance(texture2D(contentTexture, uv + vec2(-1.0,  0.0) * texelSize).rgb);
                float r  = luminance(texture2D(contentTexture, uv + vec2( 1.0,  0.0) * texelSize).rgb);
                float bl = luminance(texture2D(contentTexture, uv + vec2(-1.0,  1.0) * texelSize).rgb);
                float b  = luminance(texture2D(contentTexture, uv + vec2( 0.0,  1.0) * texelSize).rgb);
                float br = luminance(texture2D(contentTexture, uv + vec2( 1.0,  1.0) * texelSize).rgb);
                
                // Sobel operators
                float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
                float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
                
                return length(vec2(gx, gy));
            }
            
            // Generate hatching pattern based on brightness
            float hatchPattern(vec2 uv, float brightness, float density) {
                vec2 hatchCoord = uv * resolution * density;
                
                float hatch = 0.0;
                
                // Primary diagonal hatching (darker areas)
                if (brightness < 0.7) {
                    float diag1 = fract((hatchCoord.x + hatchCoord.y) * 0.5);
                    hatch += smoothstep(0.45, 0.55, diag1) * (0.7 - brightness);
                }
                
                // Cross-hatching (very dark areas)
                if (brightness < 0.4) {
                    float diag2 = fract((hatchCoord.x - hatchCoord.y) * 0.5);
                    hatch += smoothstep(0.45, 0.55, diag2) * (0.4 - brightness) * 0.8;
                }
                
                // Fine hatching (medium-dark areas)
                if (brightness < 0.55) {
                    float horizontal = fract(hatchCoord.y);
                    hatch += smoothstep(0.48, 0.52, horizontal) * (0.55 - brightness) * 0.5;
                }
                
                return hatch;
            }
            
            // Paper texture simulation
            float paperTexture(vec2 uv, float roughness) {
                float grain = noise(uv * resolution * 0.5);
                float fineGrain = noise(uv * resolution * 2.0) * 0.5;
                
                return mix(1.0, grain + fineGrain * 0.5, roughness);
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample base color and convert to grayscale
                vec3 color = texture2D(contentTexture, uv).rgb;
                float brightness = luminance(color);
                
                // Detect edges
                float edges = detectEdges(uv);
                float edgeLine = smoothstep(edgeThreshold, edgeThreshold + 0.1, edges);
                
                // Generate hatching based on brightness
                float hatching = hatchPattern(uv, brightness, hatchDensity);
                
                // Add paper texture
                float paper = paperTexture(uv, paperRoughness);
                
                // Combine elements
                // Start with bright paper
                float sketch = 1.0;
                
                // Apply edge lines (dark pencil strokes)
                sketch -= edgeLine * sketchIntensity * lineWeight;
                
                // Apply hatching for shading
                sketch -= hatching * sketchIntensity * 0.6;
                
                // Darken based on original brightness
                sketch *= mix(0.3, 1.0, brightness);
                
                // Apply paper texture
                sketch *= paper;
                
                // Clamp to valid range
                sketch = clamp(sketch, 0.0, 1.0);
                
                // Output as grayscale (pencil drawings are monochrome)
                vec3 finalColor = vec3(sketch);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        
        uniforms: {
            sketchIntensity: 0.2,      // Overall strength of sketch effect (0.5-1.0)
            hatchDensity: 0.5,       // Spacing of hatch lines (0.01-0.03)
            edgeThreshold: 0.15,       // Edge detection sensitivity (0.1-0.3)
            paperRoughness: 0.15,      // Paper grain visibility (0.0-0.3)
            lineWeight: 1.2            // Thickness of pencil strokes (0.8-1.5)
        }
    };
}