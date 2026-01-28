// Crumpled Paper Shader for t|Storie
// Creates convincing paper texture with noise and creases

function getShaderConfig() {
    return {
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            
            void main() {
                vUv = position * 0.5 + 0.5;
                vUv.y = 1.0 - vUv.y;  // Flip vertically
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        fragmentShader: `
            precision mediump float;
            
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            
            // Configurable parameters
            uniform float noiseScale;
            uniform float noiseBrightness;
            uniform vec2 noiseSeed;
            uniform vec2 noiseFrequency;
            uniform float creaseSharpness;
            uniform float creaseDarkness;
            uniform float textureDistortion;
            uniform vec3 paperTint;
            uniform float paperBlend;  // 0.0 = original, 1.0 = full paper effect
            
            varying vec2 vUv;
            
            // Cheap noise function using cosines (from tutorial)
            float cheapNoise(vec2 uv, float scale, vec2 seed, vec2 uvScale) {
                float noise = 0.0;
                noise += (cos(uv.x * uvScale.x + seed.x) + 1.0) * scale;
                noise += (cos(uv.y * uvScale.y + seed.y) + 1.0) * scale * 1.5;
                
                // Center dampening - paper is flatter in middle
                float centerRadius = length((uv - 0.5) * 2.0);
                noise *= centerRadius;
                
                return noise;
            }
            
            // Single crease calculation
            float creaseLine(vec2 uv, vec4 lineData) {
                // lineData: (slope, intercept, strength, sign)
                // Line formula: y = slope * x + intercept
                float lineDist = uv.x * lineData.x + lineData.y - uv.y;
                return lineDist;
            }
            
            // Generate pseudo-random value from UV
            float random(vec2 st) {
                return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Apply cheap noise for background paper texture
                float paperNoise = cheapNoise(uv, noiseScale, noiseSeed, noiseFrequency);
                
                // Define 4 main crease lines (slope, intercept, strength, sign)
                vec4 crease1 = vec4(-0.4, 0.2, 3.2, 1.0);
                vec4 crease2 = vec4(0.7, -0.5, 0.7, 1.0);
                vec4 crease3 = vec4(-1.0, 1.2, 0.9, -1.0);
                vec4 crease4 = vec4(1.4, 0.6, 1.2, -1.0);
                
                // Add 2 shorter, random crease lines (about 1/4 length, less dominant)
                // Using pseudo-random values based on seed for consistency
                float r1 = random(noiseSeed);
                float r2 = random(noiseSeed + vec2(1.0, 0.0));
                float r3 = random(noiseSeed + vec2(0.0, 1.0));
                float r4 = random(noiseSeed + vec2(1.0, 1.0));
                
                // Shorter creases with random positioning
                vec4 crease5 = vec4(
                    mix(-0.5, 0.5, r1),           // Random slope
                    mix(0.3, 0.7, r2),            // Random intercept
                    0.5,                           // Lower strength (1/4 of main)
                    sign(r3 - 0.5)                 // Random sign
                );
                vec4 crease6 = vec4(
                    mix(-0.6, 0.6, r4),
                    mix(0.2, 0.8, r1),
                    0.4,
                    sign(r2 - 0.5)
                );
                
                // Calculate distance to each crease line
                float dist1 = creaseLine(uv, crease1);
                float dist2 = creaseLine(uv, crease2);
                float dist3 = creaseLine(uv, crease3);
                float dist4 = creaseLine(uv, crease4);
                float dist5 = creaseLine(uv, crease5);
                float dist6 = creaseLine(uv, crease6);
                
                // Create distortion field from noise and creases
                vec2 distortion = vec2(0.0);
                
                // Add noise-based distortion
                distortion.x += paperNoise * 0.5;
                distortion.y += cheapNoise(uv + vec2(0.5), noiseScale, noiseSeed + vec2(3.7, 1.2), noiseFrequency) * 0.5;
                
                // Add crease-based distortion (perpendicular to crease lines)
                distortion += vec2(-crease1.x, 1.0) * (1.0 - clamp(abs(dist1) * 20.0, 0.0, 1.0)) * 0.3;
                distortion += vec2(-crease2.x, 1.0) * (1.0 - clamp(abs(dist2) * 20.0, 0.0, 1.0)) * 0.2;
                distortion += vec2(-crease3.x, 1.0) * (1.0 - clamp(abs(dist3) * 20.0, 0.0, 1.0)) * 0.25;
                distortion += vec2(-crease4.x, 1.0) * (1.0 - clamp(abs(dist4) * 20.0, 0.0, 1.0)) * 0.3;
                
                // Smaller distortion from shorter creases
                distortion += vec2(-crease5.x, 1.0) * (1.0 - clamp(abs(dist5) * 30.0, 0.0, 1.0)) * 0.1;
                distortion += vec2(-crease6.x, 1.0) * (1.0 - clamp(abs(dist6) * 30.0, 0.0, 1.0)) * 0.08;
                
                // Apply texture distortion (scaled by blend amount)
                vec2 distortedUv = uv + distortion * textureDistortion * paperBlend;
                
                // Sample the terminal texture ONCE with distorted coordinates
                vec4 color = texture2D(contentTexture, distortedUv);
                
                // Add subtle brightness variation from noise (scaled by blend)
                color.rgb += (paperNoise + noiseBrightness) * paperBlend;
                
                // Create darkening along creases
                float creaseDarkening = 0.0;
                creaseDarkening += clamp(abs(dist1) * creaseSharpness, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist2) * creaseSharpness, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist3) * creaseSharpness, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist4) * creaseSharpness, 0.0, 1.0);
                
                // Shorter creases are less dominant in darkening
                creaseDarkening += clamp(abs(dist5) * creaseSharpness * 0.6, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist6) * creaseSharpness * 0.5, 0.0, 1.0);
                
                creaseDarkening /= 6.0;  // Average the six distances
                
                // Apply darkening along creases (interpolate between no darkening and full darkening)
                float creaseFactor = mix(1.0, creaseDarkening * creaseDarkness + (1.0 - creaseDarkness), paperBlend);
                color.rgb *= creaseFactor;
                
                // Add slight paper color tint (interpolate between white and tint)
                color.rgb *= mix(vec3(1.0), paperTint, paperBlend);
                
                gl_FragColor = color;
            }
        `,
        
        uniforms: {
            // Noise parameters
            noiseScale: 0.35,
            noiseBrightness: -0.6,
            noiseSeed: [1.5, 2.3],
            noiseFrequency: [8.0, 10.0],
            
            // Crease parameters
            creaseSharpness: 50.0,
            creaseDarkness: 0.64,
            
            // Distortion parameter
            textureDistortion: 0.01,
            
            // Paper tint
            paperTint: [0.75, 0.75, 0.75],
            
            // Blend control
            paperBlend: 0.27  // 0.0 = no effect, 1.0 = full paper effect
        }
    };
}