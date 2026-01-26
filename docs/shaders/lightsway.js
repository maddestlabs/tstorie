// Swaying Point Light Shader for t|Storie
// Perfect for desk lamps, candles, or any point light source

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
            uniform vec2 lightPosition;      // Position in UV space (0.0-1.0)
            uniform vec3 lightColor;         // RGB color of the light
            uniform float lightIntensity;    // Brightness of the light
            uniform float lightRadius;       // How far the light reaches
            uniform float falloffPower;      // How quickly light fades (higher = sharper falloff)
            uniform float ambientLevel;      // Minimum lighting (prevents total darkness)
            uniform float lightHeight;       // Simulated height above surface (affects spread)
            uniform float swayAmount;        // How much the light sways (0.0-1.0)
            uniform float swaySpeed;         // Speed of swaying motion
            
            varying vec2 vUv;
            
            // Calculate distance with aspect ratio correction
            float getDistance(vec2 uv, vec2 lightPos) {
                vec2 aspectCorrection = vec2(resolution.x / resolution.y, 1.0);
                vec2 delta = (uv - lightPos) * aspectCorrection;
                return length(delta);
            }
            
            // Realistic inverse square falloff with artistic control
            float calculateAttenuation(float distance, float radius, float power) {
                // Normalize distance by radius
                float normalizedDist = distance / radius;
                
                // Inverse square law with adjustable power
                float attenuation = 1.0 / (1.0 + normalizedDist * normalizedDist * power);
                
                // Smooth cutoff at radius edge
                float edgeFade = smoothstep(radius * 1.2, radius * 0.8, distance);
                
                return attenuation * edgeFade;
            }
            
            // Simulate how light height affects spread
            float heightFactor(float distance, float height) {
                // Higher lights spread more evenly
                return 1.0 + (height - 1.0) * (1.0 - distance);
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Calculate swaying light position (horizontal sway)
                float swayOffset = sin(time * swaySpeed) * swayAmount;
                vec2 swayedLightPos = vec2(
                    lightPosition.x + swayOffset,
                    lightPosition.y
                );
                
                // Sample base color
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                // Calculate distance from swayed light
                float dist = getDistance(uv, swayedLightPos);
                
                // Calculate light attenuation
                float attenuation = calculateAttenuation(dist, lightRadius, falloffPower);
                
                // Apply height-based spread modification
                attenuation *= heightFactor(dist / lightRadius, lightHeight);
                
                // Calculate final lighting
                vec3 lighting = lightColor * lightIntensity * attenuation;
                
                // Apply lighting to base color
                // Ambient ensures nothing goes completely black
                vec3 finalColor = baseColor * (ambientLevel + lighting);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        
        uniforms: {
            lightPosition: [0.47, 0.6],           // Center area (UV space)
            lightColor: [1.0, 0.95, 0.85],       // Warm white (slightly yellow)
            lightIntensity: 0.45,                 // Brightness multiplier
            lightRadius: 3.0,                     // Coverage area in UV space
            falloffPower: 5.0,                    // Attenuation sharpness (2.0-5.0 realistic)
            ambientLevel: 0.85,                   // Ambient light level
            lightHeight: 1.62,                    // Simulated height (1.0-2.0)
            swayAmount: 0.6,                     // Horizontal sway range (0.0-0.2)
            swaySpeed: 0.9                        // Sway speed (0.5-2.0)
        }
    };
}