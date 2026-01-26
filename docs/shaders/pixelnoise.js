// Desert Sand Shader for tStorie
// Creates a pixelated desert sand texture with organic variation

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
            uniform float sandScale;
            uniform float sandDensity;
            uniform float temporalSpeed;
            uniform float colorVariation;
            uniform float sandIntensity;
            varying vec2 vUv;

            // Improved hash function (eliminates diagonal artifacts)
            float hash2(vec2 p) {
                vec3 p3 = fract(vec3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

            // Noise-based sand texture
            float sandTexture(vec2 uv, float time) {
                vec2 pixelPos = uv * resolution;
                
                // Primary sand grain pattern
                float sandNoise = hash2(floor(pixelPos * sandScale));
                
                // Threshold to control sand density/coverage
                float threshold = 1.0 - sandDensity;
                float sandMask = step(threshold, sandNoise);
                
                // Slow temporal variation (sand grains shift slowly)
                float slowTime = floor(time * temporalSpeed);
                float temporalNoise = hash2(floor(pixelPos * sandScale) + vec2(slowTime));
                
                // Combine spatial and temporal
                float sandPattern = sandMask * temporalNoise;
                
                // Add finer sand detail at different scale
                float fineScale = sandScale * 0.5;
                float fineNoise = hash2(floor(pixelPos * fineScale));
                float fineSand = step(1.0 - sandDensity * 0.8, fineNoise);
                fineSand *= hash2(floor(pixelPos * fineScale) + vec2(slowTime));
                
                // Combine sand layers
                float sandEffect = max(sandPattern * 0.7, fineSand * 0.4);
                
                return sandEffect;
            }

            // Add subtle color variation
            float colorNoise(vec2 uv, float time) {
                vec2 pixelPos = uv * resolution;
                float slowTime = floor(time * temporalSpeed * 0.3);
                
                // Low frequency color variation
                float colorShift = hash2(floor(pixelPos * 0.05) + vec2(slowTime));
                return (colorShift - 0.5) * colorVariation;
            }

            void main() {
                vec2 uv = vUv;
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                // Generate sand texture
                float sand = sandTexture(uv, time);
                float colorShift = colorNoise(uv, time);
                
                // Desert sand color palette (warm sandy tones)
                vec3 sandColor = vec3(0.9, 0.85, 0.7); // Light sand
                vec3 darkSandColor = vec3(0.7, 0.6, 0.45); // Darker sand
                
                // Mix sand colors with variation
                vec3 sandTone = mix(darkSandColor, sandColor, sand);
                
                // Apply color variation
                sandTone += colorShift;
                
                // Blend sand texture over base content
                vec3 finalColor = mix(baseColor, sandTone, sand * sandIntensity);
                
                // Subtle overall warm tint
                finalColor = mix(finalColor, finalColor * vec3(1.0, 0.98, 0.94), 0.1);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Sand grain controls
            sandScale: 0.3,              // Sand grain size (0.1-1.0, higher = smaller grains)
            sandDensity: 0.08,           // Coverage amount (0.0-0.5, higher = more sand visible)
            temporalSpeed: 0.5,          // How fast sand shifts (0.0-2.0)
            
            // Visual appearance
            colorVariation: 0.15,        // Color diversity (0.0-0.3)
            sandIntensity: 0.6           // Overall effect strength (0.0-1.0)
        }
    };
}