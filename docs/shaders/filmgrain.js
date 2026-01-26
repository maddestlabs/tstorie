// Movie Film Grain Shader (Optimized) for tStorie
// Performance-optimized grain with reduced noise calls

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
            uniform float grainIntensity;
            uniform float grainAdaptive;
            uniform float temporalSpeed;
            uniform float grainFreq;
            varying vec2 vUv;

            // High-quality hash function for grain generation
            float hash(vec2 p) {
                vec3 p3 = fract(vec3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

            // Improved noise with better temporal characteristics
            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                
                // Smoother interpolation (quintic)
                vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
                
                float a = hash(i);
                float b = hash(i + vec2(1.0, 0.0));
                float c = hash(i + vec2(0.0, 1.0));
                float d = hash(i + vec2(1.0, 1.0));
                
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

            // Simplified two-octave grain (removed coarse layer)
            float filmGrain(vec2 uv, float time) {
                float grain = 0.0;
                
                // Fine grain (base layer)
                grain += noise(uv * grainFreq + time * 5.0) * 0.6;
                
                // Medium grain (adds texture)
                grain += noise(uv * grainFreq * 0.5 + time * 3.0) * 0.4;
                
                return grain;
            }

            void main() {
                vec2 uv = vUv;
                vec2 pixelCoord = uv * resolution;
                
                // Sample the content texture
                vec4 color = texture2D(contentTexture, uv);
                
                // Generate grain with temporal variation
                float t = time * temporalSpeed;
                
                // Single grain value (no chromatic separation)
                float grainValue = filmGrain(pixelCoord, t);
                
                // Scale grain based on image luminance (darker = more visible grain)
                float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
                float adaptiveGrain = grainIntensity + (1.0 - luminance) * grainAdaptive;
                
                // Apply grain to all channels equally
                float grain = (grainValue - 0.5) * adaptiveGrain;
                
                // Composite grain with original color
                vec3 finalColor = color.rgb + grain;
                
                gl_FragColor = vec4(finalColor, color.a);
            }
        `,
        uniforms: {
            // Grain intensity
            grainIntensity: 0.06,        // Base grain intensity (0.0-0.1, higher = more visible grain)
            grainAdaptive: 0.3,         // Additional grain in dark areas (0.0-0.1, higher = more visible in shadows)
            
            // Temporal animation
            temporalSpeed: 0.5,          // Animation speed (0.0-2.0, higher = faster grain movement)
            
            // Grain frequency (simplified to single control)
            grainFreq: 600.0,            // Grain scale (200.0-1000.0, higher = smaller grain)
        }
    };
}