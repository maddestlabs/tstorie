// Bloom Shader for tStorie
// Extracted from apocalypse-crt.hlsl bloom implementation (MaddestLabs)
// High-performance Gaussian bloom effect

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
            uniform float bloomLevel;
            uniform float bloomScale;
            
            varying vec2 vUv;
            
            #define M_PI 3.14159265
            #define BLOOM_SAMPLES 4
            
            // Gaussian 2D function for bloom effect
            float Gaussian2D(float x, float y, float sigma) {
                return 1.0 / (sigma * sqrt(2.0 * M_PI)) * exp(-0.5 * (x * x + y * y) / (sigma * sigma));
            }
            
            // Blur function for Bloom effect
            vec3 Blur(vec2 tex_coord, float sigma) {
                vec2 dimensions = resolution;
                float texelWidth = 1.0 / dimensions.x;
                float texelHeight = 1.0 / dimensions.y;
                
                vec3 color = vec3(0.0, 0.0, 0.0);
                float totalWeight = 0.0;
                float halfSamples = float(BLOOM_SAMPLES) / 2.0;
                
                for (int x = 0; x < BLOOM_SAMPLES; x++) {
                    float fx = float(x);
                    vec2 samplePos = vec2(0.0, 0.0);
                    samplePos.x = tex_coord.x + (fx - halfSamples) * texelWidth;
                    
                    for (int y = 0; y < BLOOM_SAMPLES; y++) {
                        float fy = float(y);
                        samplePos.y = tex_coord.y + (fy - halfSamples) * texelHeight;
                        
                        // Check if the sample position is within the valid range
                        if (samplePos.x >= 0.0 && samplePos.x <= 1.0 && 
                            samplePos.y >= 0.0 && samplePos.y <= 1.0) {
                            
                            float weight = Gaussian2D(fx - halfSamples, fy - halfSamples, sigma);
                            totalWeight += weight;
                            
                            color += texture2D(contentTexture, samplePos).rgb * weight;
                        }
                    }
                }
                
                // Prevent division by zero if all samples were outside the valid range
                if (totalWeight > 0.0) {
                    return color / totalWeight;
                } else {
                    return vec3(0.0, 0.0, 0.0);
                }
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample the base color from input texture
                vec3 color = texture2D(contentTexture, uv).rgb;
                
                // Calculate bloom
                float scaledGaussianSigma = 3.0 * bloomScale;
                vec3 bloom = Blur(uv, scaledGaussianSigma);
                
                // Add bloom to base color
                color += bloom * bloomLevel;
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            bloomLevel: 0.8,   // Intensity of bloom effect (0.0 = none, 1.0 = strong)
            bloomScale: 1.5    // Size/spread of bloom (higher = wider glow)
        }
    };
}
