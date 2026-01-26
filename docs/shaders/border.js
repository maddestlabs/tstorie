// Border Shader for t|Storie
// Adds a solid color border around content

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
            uniform float borderSize;
            uniform vec3 backgroundColor;
            varying vec2 vUv;
            
            void main() {
                vec2 uv = vUv;
                
                // Calculate border in pixel space
                float px = 1.0 / resolution.x;
                float border = borderSize * px;
                
                // Check if we're in the border region
                bool isBorder = (uv.x < border || uv.x > (1.0 - border) || 
                                uv.y < border || uv.y > (1.0 - border));
                
                vec3 color;
                
                if (isBorder) {
                    // Draw border color
                    color = backgroundColor;
                } else {
                    // Calculate content UV (area inside border)
                    vec2 contentUV = (uv - vec2(border, border)) / (1.0 - 2.0 * border);
                    
                    // Sample the content texture
                    color = texture2D(contentTexture, contentUV).rgb;
                }
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            borderSize: 20.0,                    // Border thickness in pixels
            backgroundColor: [0.0, 0.0, 0.0]     // Border color (RGB, black by default)
        }
    };
}