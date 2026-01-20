// Swaying Light Shader
// Creates a moving light effect across the screen

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
            uniform float lightIntensity;
            uniform float lightRadius;
            uniform float lightFalloff;
            uniform float ambientLight;
            uniform float lightSpeed;
            uniform float lightRange;
            uniform vec2 lightPosition;
            uniform vec3 lightColor;
            varying vec2 vUv;

            void main() {
                vec2 uv = vUv;
                vec4 color = texture2D(contentTexture, uv);
                
                // Calculate moving light position
                float lightX = lightPosition.x + sin(time * lightSpeed) * lightRange;
                float lightY = lightPosition.y;
                vec2 lightPos = vec2(lightX, lightY);
                
                // Calculate light effect with smooth falloff
                vec2 lightVector = uv - lightPos;
                float distanceToLight = length(lightVector);
                float lightFalloffCalc = pow(
                    clamp(1.0 - (distanceToLight / lightRadius), 0.0, 1.0), 
                    lightFalloff
                );
                
                // Create smooth transition from light to ambient
                float lightFactor = mix(ambientLight, 1.0 + lightIntensity, lightFalloffCalc);
                
                // Apply light color and factor
                color.rgb *= lightColor * lightFactor;
                
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            lightIntensity: 0.5,       // Overall light intensity
            lightRadius: 3.5,          // Size of the light effect
            lightFalloff: 2.3,         // How quickly light fades (higher = sharper)
            ambientLight: 0.35,        // Minimum brightness in darker areas
            lightSpeed: 1.0,           // Speed of light movement (radians/sec)
            lightRange: 0.5,           // How far the light moves left/right (0.0-1.0)
            lightPosition: [0.5, 0.3], // Base position of light [x, y] in UV space
            lightColor: [1.0, 0.98, 0.95] // Slightly warm light color
        }
    };
}