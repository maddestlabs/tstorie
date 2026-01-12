// Bloom Shader for tStorie (Improved)
// Smooth Gaussian bloom with controllable halo spread
// No more "copies" or box blur artifacts

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
            uniform float bloomIntensity;
            uniform float bloomRadius;
            uniform float bloomSpread;
            uniform float bloomThreshold;
            uniform float bloomSoftness;
            
            varying vec2 vUv;
            
            #define BLOOM_TAPS 16
            #define NUM_RINGS 5
            
            // Calculate perceived brightness (luminance)
            float luminance(vec3 color) {
                return dot(color, vec3(0.299, 0.587, 0.114));
            }
            
            // Soft threshold function
            float softThreshold(float value, float threshold, float softness) {
                float edge0 = threshold - softness;
                float edge1 = threshold + softness;
                return smoothstep(edge0, edge1, value);
            }
            
            // Extract bright areas above threshold
            vec3 extractBrightness(vec3 color, float threshold, float softness) {
                float lum = luminance(color);
                float contribution = softThreshold(lum, threshold, softness);
                
                float brightnessFactor = max(0.0, lum - threshold);
                contribution *= (1.0 + brightnessFactor * 2.0);
                
                return color * contribution;
            }
            
            // Gaussian function
            float gaussian(float x, float sigma) {
                return exp(-(x * x) / (2.0 * sigma * sigma));
            }
            
            // High-quality radial Gaussian bloom
            vec3 radialGaussianBloom(vec2 uv, float radius, float spread) {
                vec3 bloom = vec3(0.0);
                float totalWeight = 0.0;
                
                vec2 texelSize = 1.0 / resolution;
                float sigma = radius * 0.4;
                
                // Multiple rings with Gaussian distribution
                float angleStep = 6.28318530718 / float(BLOOM_TAPS); // 2*PI
                
                for (int ring = 1; ring <= NUM_RINGS; ring++) {
                    float ringDist = (float(ring) / float(NUM_RINGS)) * radius * spread;
                    float ringWeight = gaussian(float(ring - 1), sigma / spread);
                    
                    for (int tap = 0; tap < BLOOM_TAPS; tap++) {
                        float angle = float(tap) * angleStep;
                        vec2 offset = vec2(cos(angle), sin(angle)) * ringDist * texelSize;
                        vec2 samplePos = uv + offset;
                        
                        if (samplePos.x >= 0.0 && samplePos.x <= 1.0 && 
                            samplePos.y >= 0.0 && samplePos.y <= 1.0) {
                            
                            vec3 sampleColor = texture2D(contentTexture, samplePos).rgb;
                            vec3 brightColor = extractBrightness(sampleColor, bloomThreshold, bloomSoftness);
                            
                            bloom += brightColor * ringWeight;
                            totalWeight += ringWeight;
                        }
                    }
                }
                
                return totalWeight > 0.0 ? bloom / totalWeight : vec3(0.0);
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample the base color
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                // Calculate smooth radial Gaussian bloom
                vec3 bloom = radialGaussianBloom(uv, bloomRadius, bloomSpread);
                
                // Combine base color with bloom
                vec3 finalColor = baseColor + bloom * bloomIntensity;
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        
        uniforms: {
            bloomIntensity: 0.15,      // How strong the bloom effect is
            bloomRadius: 22.0,         // Maximum reach of the bloom halo
            bloomSpread: 1.0,          // Distance between sample rings (0.5-2.0)
            bloomThreshold: 0.15,      // Brightness threshold
            bloomSoftness: 1.5         // Smoothness of threshold falloff
        }
    };
}