// Simple Scanlines Shader for t|Storie
// Clean, good-looking horizontal scanlines

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
            uniform float scanlineStrength;   // How dark the scanlines are (0.0-1.0)
            uniform float scanlineWidth;      // Width of scanlines (1.0-4.0)
            uniform float scanlineSpeed;      // Animation speed (0.0 = static)
            varying vec2 vUv;
            
            void main() {
                vec2 uv = vUv;
                
                // Sample base color
                vec3 color = texture2D(contentTexture, uv).rgb;
                
                // Calculate scanline pattern
                float scanline = sin((uv.y + time * scanlineSpeed) * resolution.y * 3.14159 / scanlineWidth);
                
                // Convert from -1,1 to 0,1 range and apply strength
                scanline = scanlineStrength + (1.0 - scanlineStrength) * (scanline * 0.5 + 0.5);
                
                // Apply scanlines
                color *= scanline;
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            scanlineStrength: 0.7,    // 0.0 = black lines, 1.0 = no effect
            scanlineWidth: 1.5,       // Pixels per scanline pair
            scanlineSpeed: 0.0        // 0.0 = static, 0.01 = slow scroll
        }
    };
}