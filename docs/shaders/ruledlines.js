// Ruled Lines Shader for t|Storie
// Notebook-style ruled lines for real paper effect

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
            uniform vec2 cellSize;
            uniform float lightLineSpacing;
            uniform float darkLineSpacing;
            uniform float alternatingLineSpacing;
            uniform vec3 lightLineColor;
            uniform vec3 darkLineColor;
            uniform vec3 alternatingTint;
            uniform float lineOpacity;
            varying vec2 vUv;

            void main() {
                vec2 uv = vUv;
                vec4 color = texture2D(contentTexture, uv);
                
                // Calculate screen position for pixel-perfect lines
                vec2 screenPos = uv * resolution;
                float yScreen = screenPos.y;
                float lineHeight = cellSize.y;
                
                // Calculate base line number
                float lineNumber = floor(yScreen / lineHeight);
                
                // Light lines - use multiply blend mode
                float lightLineMask = step(lightLineSpacing, 0.001) * 0.0 + 
                                     (1.0 - step(lightLineSpacing, 0.001)) * 
                                     step(mod(yScreen, lineHeight * lightLineSpacing), 1.0);
                vec3 lightBlend = mix(vec3(1.0), lightLineColor, lineOpacity);
                color.rgb *= mix(vec3(1.0), lightBlend, lightLineMask);
                
                // Alternating line tint - also using multiply
                float altLineMask = step(alternatingLineSpacing, 0.001) * 0.0 + 
                                   (1.0 - step(alternatingLineSpacing, 0.001)) * 
                                   (1.0 - step(1.0, mod(lineNumber, alternatingLineSpacing)));
                vec3 altBlend = mix(vec3(1.0), alternatingTint, 1.0);
                color.rgb *= mix(vec3(1.0), altBlend, altLineMask);
                
                // Dark lines - multiply blend
                float darkLineMask = step(darkLineSpacing, 0.001) * 0.0 + 
                                    (1.0 - step(darkLineSpacing, 0.001)) * 
                                    step(mod(yScreen, lineHeight * darkLineSpacing), 1.0);
                vec3 darkBlend = mix(vec3(1.0), darkLineColor, lineOpacity);
                color.rgb *= mix(vec3(1.0), darkBlend, darkLineMask);
                
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            // Cell size (set dynamically from terminal/game engine)
            cellSize: [10.0, 20.0],

            // Line opacity
            lineOpacity: 0.6,
            
            // Line spacing (relative to cellSize.y)
            lightLineSpacing: 0.2,      // Light lines every 20% of line height
            darkLineSpacing: 1.0,       // Dark lines every 100% of line height
            alternatingLineSpacing: 2.0, // Alternating tint every 2 lines
            
            // Line colors (for multiply blend - values < 1.0 darken)
            lightLineColor: [0.92, 0.94, 0.96],  // Subtle gray-blue
            darkLineColor: [0.7, 0.75, 0.8],     // Medium gray-blue
            alternatingTint: [0.96, 0.96, 0.96]  // Very subtle darkening
        }
    };
}