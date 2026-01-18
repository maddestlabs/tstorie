// Zen Garden Sand Shader for tStorie
// Creates a subtle raked sand texture with very fine grain displacement
// Upload this to a GitHub Gist and use: ?shader=YOUR_GIST_ID
// Or use locally: ?shader=sand

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
            uniform float grainStrength;
            uniform float grainScale;
            uniform float colorVariation;
            uniform float displacementStrength;
            varying vec2 vUv;

            // High-quality noise functions
            float hash(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }
            
            float hash3(vec3 p) {
                return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
            }
            
            // 2D Perlin-like noise
            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                
                float a = hash(i);
                float b = hash(i + vec2(1.0, 0.0));
                float c = hash(i + vec2(0.0, 1.0));
                float d = hash(i + vec2(1.0, 1.0));
                
                return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
            }
            
            // 3D noise for temporal variation
            float noise3(vec3 p) {
                vec3 i = floor(p);
                vec3 f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                
                return mix(
                    mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
                        mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
                    mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
                        mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y),
                    f.z
                );
            }
            
            // Fractal Brownian Motion for layered texture
            float fbm(vec2 p, int octaves) {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                for(int i = 0; i < 8; i++) {
                    if(i >= octaves) break;
                    value += amplitude * noise(p * frequency);
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }
                
                return value;
            }

            void main() {
                vec2 uv = vUv;
                
                // === SAND GRAIN DISPLACEMENT ===
                // Multi-octave noise for natural sand texture - use fewer octaves to reduce patterns
                float noiseX = fbm(uv * resolution * grainScale, 4);
                float noiseY = fbm(uv * resolution * grainScale + vec2(1000.0, 1000.0), 4);
                
                // Create subtle displacement vector from independent noise sources
                vec2 displacement = vec2(
                    (noiseX - 0.5),
                    (noiseY - 0.5)
                ) * displacementStrength * 0.0006;
                
                // Apply displacement to sample position
                vec2 displacedUV = uv + displacement;
                
                // === SAMPLE CONTENT ===
                vec4 content = texture2D(contentTexture, displacedUV);
                
                // === SAND GRAIN TEXTURE ===
                // Base grain layers (blurry texture)
                float fineGrain = noise(uv * resolution * grainScale * 8.0);
                
                // Medium grain with slight temporal variation (very subtle)
                float mediumGrain = noise3(vec3(uv * resolution * grainScale * 2.0, time * 0.01));
                
                // Combine base grain layers
                float grain = mix(fineGrain, mediumGrain, 0.3) - 0.5;
                grain *= grainStrength * 0.15;
                
                // === EXTRA FINE GRAIN LAYER ===
                // Very high-frequency grain for sharp sand particle detail
                float extraFineGrain = hash(uv * resolution * 2.0);
                extraFineGrain += noise(uv * resolution * grainScale * 32.0) * 0.5;
                extraFineGrain = (extraFineGrain - 0.75) * grainStrength * 0.25;
                
                // === COLOR VARIATION ===
                // Subtle color shifts across the sand surface
                float colorShift = fbm(uv * resolution * 0.005, 4);
                float colorMod = (colorShift - 0.5) * colorVariation;
                
                // === COMPOSE FINAL COLOR ===
                vec3 finalColor = content.rgb;
                
                // Apply base grain (affects brightness slightly)
                finalColor += grain;
                
                // Apply extra fine grain on top
                finalColor += extraFineGrain;
                
                // Apply subtle color variation
                finalColor += colorMod * 0.05;
                
                // Very subtle warm sand tint overlay (barely perceptible)
                vec3 sandTint = vec3(1.0, 0.98, 0.94);
                finalColor = mix(finalColor, finalColor * sandTint, 0.02);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Sand grain appearance
            grainStrength: 0.25,        // Overall grain visibility (0.0-1.0, higher = more visible)
            grainScale: 0.03,            // Grain detail scale (0.05-0.3, smaller = finer grain)
            
            // Color and atmosphere
            colorVariation: 0.5,       // Subtle color shifts across sand (0.0-0.2, higher = more variation)
            
            // Displacement for terminal content
            displacementStrength: 2.0   // Content displacement amount (0.0-3.0, higher = more distortion)
        }
    };
}
