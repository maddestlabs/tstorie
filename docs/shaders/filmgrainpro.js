// Movie Film Grain Shader for tStorie
// Simulates realistic analog film grain with temporal variation

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
            uniform float fineGrainFreq;
            uniform float mediumGrainFreq;
            uniform float coarseGrainFreq;
            uniform float chromaticStrength;
            uniform float vignetteStrength;
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

            // Layered noise for more complex grain structure
            float filmGrain(vec2 uv, float time) {
                float grain = 0.0;
                
                // Fine grain (base layer)
                grain += noise(uv * fineGrainFreq + time * 5.0) * 0.5;
                
                // Medium grain (adds texture)
                grain += noise(uv * mediumGrainFreq + time * 3.0) * 0.3;
                
                // Coarse grain (analog film characteristic)
                grain += noise(uv * coarseGrainFreq + time * 1.5) * 0.2;
                
                return grain;
            }

            void main() {
                vec2 uv = vUv;
                vec2 pixelCoord = uv * resolution;
                
                // Sample the content texture
                vec4 color = texture2D(contentTexture, uv);
                
                // Generate grain with temporal variation
                float t = time * temporalSpeed;
                
                // Separate grain channels for chromatic aberration effect
                float grainR = filmGrain(pixelCoord + vec2(0.0, 0.0), t);
                float grainG = filmGrain(pixelCoord + vec2(7.3, 13.1), t + 0.33);
                float grainB = filmGrain(pixelCoord + vec2(15.7, 3.9), t + 0.67);
                
                // Luminance grain (affects all channels equally)
                float grainL = filmGrain(pixelCoord + vec2(23.4, 31.2), t);
                
                // Scale grain based on image luminance (darker = more visible grain)
                float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
                float adaptiveGrain = grainIntensity + (1.0 - luminance) * grainAdaptive;
                
                // Apply chromatic and luminance grain
                vec3 grain = vec3(grainR, grainG, grainB) - 0.5;
                grain = grain * adaptiveGrain * chromaticStrength;
                
                // Add luminance grain
                grain += (grainL - 0.5) * adaptiveGrain;
                
                // Composite grain with original color
                vec3 finalColor = color.rgb + grain;
                
                // Optional: Add subtle vignette to enhance film look
                vec2 vignetteUV = uv * 2.0 - 1.0;
                float vignette = 1.0 - dot(vignetteUV, vignetteUV) * vignetteStrength;
                finalColor *= vignette;
                
                gl_FragColor = vec4(finalColor, color.a);
            }
        `,
        uniforms: {
            // Grain intensity
            grainIntensity: 0.07,        // Base grain intensity (0.0-0.1, higher = more visible grain)
            grainAdaptive: 0.02,         // Additional grain in dark areas (0.0-0.1, higher = more visible in shadows)
            
            // Temporal animation
            temporalSpeed: 0.5,          // Animation speed (0.0-2.0, higher = faster grain movement)
            
            // Grain frequencies
            fineGrainFreq: 800.0,        // Fine grain scale (200.0-1200.0, higher = smaller grain)
            mediumGrainFreq: 400.0,      // Medium grain scale (100.0-600.0, higher = smaller grain)
            coarseGrainFreq: 150.0,      // Coarse grain scale (50.0-300.0, higher = smaller grain)
            
            // Color and atmosphere
            chromaticStrength: 0.7,      // Color separation strength (0.0-1.0, higher = more chromatic aberration)
            vignetteStrength: 0.35       // Edge darkening (0.0-0.5, higher = darker edges)
        }
    };
}