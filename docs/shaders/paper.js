// Paper Texture Shader
// Adds subtle paper grain/noise for realistic paper effect

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
            uniform vec2 resolution;
            uniform float paperNoise;
            uniform float noiseIntensity;
            uniform float noiseMix;
            varying vec2 vUv;

            // Hash function for noise
            float hash(vec2 p) {
                vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yxz + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

            void main() {
                vec2 uv = vUv;
                vec4 color = texture2D(contentTexture, uv);
                
                // Generate and apply paper texture noise
                if (paperNoise > 0.0) {
                    vec2 screenPos = uv * resolution;
                    float noise = hash(screenPos) * noiseIntensity;
                    vec3 noiseColor = vec3(1.0) * noise;
                    color.rgb = mix(color.rgb, noiseColor, noiseMix * paperNoise);
                }
                
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            paperNoise: 1.0,         // Paper texture on/off (0.0-1.0)
            noiseIntensity: 0.08,    // How strong the noise pattern is
            noiseMix: 0.4            // How much noise blends with color
        }
    };
}