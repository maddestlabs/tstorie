// Example TStorie Shader
// Upload this to a GitHub Gist and use: ?shader=YOUR_GIST_ID
//
// The shader system expects this file to export a getShaderConfig() function
// that returns an object with vertexShader, fragmentShader, and optional uniforms

function getShaderConfig() {
    return {
        // Vertex shader - basic passthrough with texture coordinates
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            
            void main() {
                vUv = position * 0.5 + 0.5;
                vUv.y = 1.0 - vUv.y;  // Flip vertically
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        // Fragment shader - your effect goes here
        fragmentShader: `
            precision mediump float;
            
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            
            // Custom uniforms (optional)
            uniform float scanlineIntensity;
            uniform float rgbShift;
            uniform float noiseAmount;
            
            varying vec2 vUv;
            
            // Random function for noise
            float random(vec2 co) {
                return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
            }
            
            void main() {
                vec2 uv = vUv;
                
                // RGB chromatic aberration
                float offset = rgbShift * 0.002;
                vec3 color;
                color.r = texture2D(contentTexture, uv + vec2(offset, 0.0)).r;
                color.g = texture2D(contentTexture, uv).g;
                color.b = texture2D(contentTexture, uv - vec2(offset, 0.0)).b;
                
                // Scanlines
                float scanline = sin(uv.y * resolution.y * 3.14159 / 2.0);
                color *= (scanlineIntensity + (1.0 - scanlineIntensity) * scanline);
                
                // Noise
                float noise = random(uv + time) * noiseAmount;
                color += vec3(noise);
                
                // Vignette
                vec2 pos = uv - 0.5;
                float vignette = 1.0 - dot(pos, pos) * 0.5;
                color *= vignette;
                
                // Slight flicker
                float flicker = 1.0 + sin(time * 60.0) * 0.02;
                color *= flicker;
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        // Custom uniforms with default values (optional)
        uniforms: {
            scanlineIntensity: 0.8,
            rgbShift: 1.0,
            noiseAmount: 0.05
        }
    };
}
