// Gradual Blur Shader for Stone Garden
// Applies increasing blur from center to edges (tilt-shift effect)
// Optimized: reduces samples near center, increases at edges

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
            uniform vec2 focusPoint;
            uniform float focusRadius;
            uniform float blurRadius;
            uniform float falloffPower;
            uniform float sampleCount;
            
            varying vec2 vUv;
            
            void main() {
                vec2 uv = vUv;
                
                // Calculate distance from focus point
                vec2 centerOffset = uv - focusPoint;
                float distFromCenter = length(centerOffset);
                
                // Calculate blur intensity with smooth falloff
                // 0.0 at center (focusRadius), 1.0 at edges
                float blurAmount = smoothstep(focusRadius, focusRadius + 0.4, distFromCenter);
                blurAmount = pow(blurAmount, falloffPower);
                
                // Early exit: if blur amount is very low, just sample once
                if (blurAmount < 0.05) {
                    gl_FragColor = texture2D(contentTexture, uv);
                    return;
                }
                
                // Calculate actual blur radius for this pixel
                float pixelBlurRadius = blurRadius * blurAmount;
                vec2 texelSize = 1.0 / resolution;
                vec4 color = vec4(0.0);
                float totalWeight = 0.0;
                
                // Sample patterns based on sampleCount uniform
                if (sampleCount == 1.0) {
                    // Single sample (no blur)
                    color = texture2D(contentTexture, uv);
                    totalWeight = 1.0;
                    
                } else if (sampleCount == 5.0) {
                    // 5 samples: center + 4 cardinal directions (cross pattern)
                    color += texture2D(contentTexture, uv);
                    totalWeight += 1.0;
                    
                    for (float i = 0.0; i < 4.0; i += 1.0) {
                        float angle = i * 1.5708; // 90 degrees
                        vec2 offset = vec2(cos(angle), sin(angle)) * texelSize * pixelBlurRadius;
                        color += texture2D(contentTexture, uv + offset);
                        totalWeight += 1.0;
                    }
                    
                } else if (sampleCount == 9.0) {
                    // 9 samples: 3x3 box pattern
                    for (float x = -1.0; x <= 1.0; x += 1.0) {
                        for (float y = -1.0; y <= 1.0; y += 1.0) {
                            vec2 offset = vec2(x, y) * texelSize * pixelBlurRadius;
                            color += texture2D(contentTexture, uv + offset);
                            totalWeight += 1.0;
                        }
                    }
                    
                } else if (sampleCount == 13.0) {
                    // 13 samples: center + two rings (cross + diagonals)
                    color += texture2D(contentTexture, uv);
                    totalWeight += 1.0;
                    
                    // Inner ring (8 samples)
                    for (float i = 0.0; i < 8.0; i += 1.0) {
                        float angle = i * 0.785398; // 45 degrees
                        vec2 offset = vec2(cos(angle), sin(angle)) * texelSize * pixelBlurRadius;
                        color += texture2D(contentTexture, uv + offset);
                        totalWeight += 1.0;
                    }
                    
                    // Outer ring (4 samples at corners)
                    for (float i = 0.0; i < 4.0; i += 1.0) {
                        float angle = i * 1.5708 + 0.785398; // 45° offset
                        vec2 offset = vec2(cos(angle), sin(angle)) * texelSize * pixelBlurRadius * 1.414;
                        color += texture2D(contentTexture, uv + offset);
                        totalWeight += 1.0;
                    }
                    
                } else {
                    // Default: 9 samples (box pattern)
                    for (float x = -1.0; x <= 1.0; x += 1.0) {
                        for (float y = -1.0; y <= 1.0; y += 1.0) {
                            vec2 offset = vec2(x, y) * texelSize * pixelBlurRadius;
                            color += texture2D(contentTexture, uv + offset);
                            totalWeight += 1.0;
                        }
                    }
                }
                
                color /= totalWeight;
                
                gl_FragColor = color;
            }
        `,
        
        uniforms: {
            // Focus area (center of sharpness)
            focusPoint: [0.5, 0.5],      // Center of screen (0.0-1.0 range)
            focusRadius: 0.2,            // Radius of perfectly sharp area (0.0-1.0)
            
            // Blur intensity
            blurRadius: 1.5,             // Maximum blur radius in pixels at edges
            
            // Falloff control
            falloffPower: 1.5,           // How quickly blur increases (1.0 = linear, 2.0 = quadratic)
            
            // Performance control
            sampleCount: 5.0             // Number of samples: 1 (none), 5 (fast), 9 (balanced), 13 (quality)
        }
    };
}
