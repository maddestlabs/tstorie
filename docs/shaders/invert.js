// Simple Invert Shader for Testing
// Upload this to a GitHub Gist and use: ?shader=YOUR_GIST_ID

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
                
                // Sample the terminal texture
                vec4 color = texture2D(contentTexture, uv);
                
                // Invert the colors
                color.rgb = vec3(1.0) - color.rgb;
                
                gl_FragColor = color;
            }
        `,
        
        uniforms: {}
    };
}
