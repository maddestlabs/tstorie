// Film Scratches Shader for tStorie
// Simulates realistic analog film scratches with vertical orientation and subtle variation

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
            uniform float scratchDensity;
            uniform float scratchWidth;
            uniform float scratchIntensity;
            uniform float scratchSpeed;
            uniform float verticalVariation;
            varying vec2 vUv;

            // Hash function
            float hash(float n) {
                return fract(sin(n) * 43758.5453);
            }
            
            float hash2(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            // Smooth noise for subtle variation
            float noise(float p) {
                float i = floor(p);
                float f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                return mix(hash(i), hash(i + 1.0), f);
            }

            // Generate realistic vertical scratches
            float verticalScratches(vec2 uv, float time) {
                float scratches = 0.0;
                
                // Slow time progression for scratch persistence
                float timeSeed = floor(time * scratchSpeed);
                
                // Multiple scratch layers
                for(float i = 0.0; i < 6.0; i++) {
                    // Each scratch has a unique seed
                    float scratchId = i + timeSeed * 0.3;
                    float appear = hash(scratchId * 127.3);
                    
                    // Control scratch density
                    if(appear > scratchDensity) continue;
                    
                    // Random horizontal position
                    float xPos = hash(scratchId * 234.5);
                    
                    // Subtle horizontal drift using smooth noise
                    float drift = noise(uv.y * 8.0 + scratchId) * verticalVariation;
                    float scratchX = xPos + drift;
                    
                    // Distance from scratch center
                    float dist = abs(uv.x - scratchX);
                    
                    // Random width variation per scratch
                    float widthVar = hash(scratchId * 345.6) * 0.5 + 0.5;
                    float width = scratchWidth * widthVar;
                    
                    // Create scratch with soft falloff
                    float scratch = smoothstep(width, width * 0.3, dist);
                    
                    // Random intensity per scratch
                    float brightness = hash(scratchId * 456.7) * 0.6 + 0.4;
                    scratch *= brightness;
                    
                    // Vertical opacity variation (scratches fade in/out)
                    float fadePattern = noise(uv.y * 15.0 + scratchId * 10.0);
                    fadePattern = fadePattern * 0.4 + 0.6; // 60-100% opacity
                    scratch *= fadePattern;
                    
                    // Accumulate scratches (additive)
                    scratches += scratch;
                }
                
                return min(scratches, 1.0); // Clamp to prevent over-brightening
            }

            void main() {
                vec2 uv = vUv;
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                // Generate defects
                float scratchEffect = verticalScratches(uv, time);
                
                // Apply scratches (brighten - white/light scratches)
                vec3 finalColor = baseColor + scratchEffect * scratchIntensity;

                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Scratch controls
            scratchDensity: 0.05,        // Number of scratches (0.0-1.0, higher = more scratches)
            scratchWidth: 0.0005,         // Base scratch thickness (0.001-0.01)
            scratchIntensity: 0.3,       // Scratch brightness (0.0-1.0)
            scratchSpeed: 3.0,           // How often scratches change (0.1-2.0)
            verticalVariation: 0.002,    // Subtle horizontal drift (0.0-0.01, higher = more wavy)
        }
    };
}