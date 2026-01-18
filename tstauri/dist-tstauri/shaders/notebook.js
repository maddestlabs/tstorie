// Notebook Paper Shader for tStorie
// Creates a realistic notebook paper effect with moving light
// Based on Windows Terminal notebook.hlsl shader

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
            uniform vec2 cellSize;
            uniform float lightLineSpacing;
            uniform float darkLineSpacing;
            uniform float lightIntensity;
            uniform float lightRadius;
            uniform float lightFalloff;
            uniform float ambientLight;
            uniform float lightSpeed;
            uniform float lightRange;
            uniform float baseBlur;
            uniform float paperNoise;
            varying vec2 vUv;

            // Hash function for noise
            float hash(vec2 p) {
                vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yxz + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

            // Sample texture with simple blur
            vec4 sampleBlurred(vec2 uv) {
                vec2 pixelSize = 1.0 / resolution;
                vec2 blurOffset = pixelSize * baseBlur;
                
                // Center sample
                vec4 color = texture2D(contentTexture, uv);
                float totalWeight = 1.0;
                
                // Horizontal samples if not at edges
                if (uv.x > blurOffset.x && uv.x < 1.0 - blurOffset.x) {
                    color += texture2D(contentTexture, uv + vec2(blurOffset.x, 0.0));
                    color += texture2D(contentTexture, uv - vec2(blurOffset.x, 0.0));
                    totalWeight += 2.0;
                }
                
                // Vertical samples if not at edges
                if (uv.y > blurOffset.y && uv.y < 1.0 - blurOffset.y) {
                    color += texture2D(contentTexture, uv + vec2(0.0, blurOffset.y));
                    color += texture2D(contentTexture, uv - vec2(0.0, blurOffset.y));
                    totalWeight += 2.0;
                }
                
                return color / totalWeight;
            }

            void main() {
                vec2 uv = vUv;
                
                // Sample with blur
                vec4 color = sampleBlurred(uv);
                
                // Use cellSize height to determine line spacing
                // LINE_HEIGHT is based on terminal character cell height
                float lineHeight = cellSize.y;
                
                // Calculate screen position for pixel-perfect lines
                vec2 screenPos = uv * resolution;
                float yScreen = screenPos.y;
                
                // Calculate base line number
                float lineNumber = floor(yScreen / lineHeight);
                
                // Light blue lines (every LINE_HEIGHT * lightLineSpacing pixels)
                if (mod(yScreen, lineHeight * lightLineSpacing) < 1.0) {
                    color.rgb = mix(color.rgb, vec3(0.8, 0.9, 1.0), 0.4);
                }
                
                // Darker tint for every other line (alternating)
                if (mod(lineNumber, 2.0) < 1.0) {
                    color.rgb *= 0.97;
                }
                
                // Dark blue lines (every LINE_HEIGHT * darkLineSpacing pixels)
                if (mod(yScreen, lineHeight * darkLineSpacing) < 1.0) {
                    color.rgb = mix(color.rgb, vec3(0.4, 0.5, 0.8), 0.25);
                }
                
                // Generate and apply paper texture noise
                if (paperNoise > 0.0) {
                    float noise = hash(screenPos) * 0.08;
                    vec3 noiseColor = vec3(1.0) * noise;
                    color.rgb = mix(color.rgb, noiseColor, 0.4 * paperNoise);
                }
                
                // Calculate moving light position
                float lightX = 0.5 + sin(time * lightSpeed) * lightRange;
                vec2 lightPos = vec2(lightX, 0.3);
                
                // Calculate light effect with smooth falloff
                vec2 lightVector = uv - lightPos;
                float distanceToLight = length(lightVector);
                float lightFalloffCalc = pow(clamp(1.0 - (distanceToLight / lightRadius), 0.0, 1.0), lightFalloff);
                
                // Create smooth transition from light to ambient
                float lightFactor = mix(ambientLight, 1.0 + lightIntensity, lightFalloffCalc);
                
                // Apply slightly warm light color
                vec3 lightColor = vec3(1.0, 0.98, 0.95);
                color.rgb *= lightColor * lightFactor;
                
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            // Cell size is set dynamically from terminal
            cellSize: [10.0, 20.0],
            
            // Line configuration (relative to LINE_HEIGHT which equals cellSize.y)
            lightLineSpacing: 0.2,    // Light lines every 20% of line height
            darkLineSpacing: 1.0,     // Dark lines every 100% of line height
            
            // Lighting parameters
            lightIntensity: 0.5,      // Overall light intensity
            lightRadius: 3.5,         // Size of the light effect
            lightFalloff: 2.3,        // How quickly light fades
            ambientLight: 0.35,       // Minimum brightness in darker areas
            lightSpeed: 1.0,          // Speed of light movement
            lightRange: 0.5,          // How far the light moves left/right
            
            // Visual effects
            baseBlur: 0.5,            // Base blur in pixels
            paperNoise: 1.0           // Paper texture intensity (0.0-1.0)
        }
    };
}
