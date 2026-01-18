// Simple Box Blur Shader
// Can be chained with other effects: ?shader=blur+crt or ?shader=invert+blur

function getShaderConfig() {
    return {
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            
            void main() {
                vUv = position * 0.5 + 0.5;
                vUv.y = 1.0 - vUv.y;  // Flip vertically
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        fragmentShader: `
            precision mediump float;
            
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            
            varying vec2 vUv;
            
            void main() {
                vec2 uv = vUv;
                
                // Calculate blur radius (in pixels)
                float blurRadius = 0.75;
                vec2 texelSize = 1.0 / resolution;
                
                // Simple 9-sample box blur
                vec4 color = vec4(0.0);
                float totalWeight = 0.0;
                
                for (float x = -1.0; x <= 1.0; x += 1.0) {
                    for (float y = -1.0; y <= 1.0; y += 1.0) {
                        vec2 offset = vec2(x, y) * texelSize * blurRadius;
                        color += texture2D(contentTexture, uv + offset);
                        totalWeight += 1.0;
                    }
                }
                
                color /= totalWeight;
                
                gl_FragColor = color;
            }
        `,
        
        uniforms: {
            // No custom uniforms needed
        }
    };
}
