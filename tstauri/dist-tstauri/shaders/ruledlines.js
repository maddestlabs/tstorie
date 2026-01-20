// Ruled Lines Shader
// Adds notebook-style ruled lines

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
                
                // Light lines - use step to create a mask (1.0 when on line, 0.0 otherwise)
                float lightLineMask = step(lightLineSpacing, 0.001) * 0.0 + 
                                     (1.0 - step(lightLineSpacing, 0.001)) * 
                                     step(mod(yScreen, lineHeight * lightLineSpacing), 1.0);
                color.rgb = mix(color.rgb, lightLineColor, lineOpacity * lightLineMask);
                
                // Alternating line tint (every other line)
                float altLineMask = step(alternatingLineSpacing, 0.001) * 0.0 + 
                                   (1.0 - step(alternatingLineSpacing, 0.001)) * 
                                   (1.0 - step(1.0, mod(lineNumber, alternatingLineSpacing)));
                color.rgb = mix(color.rgb, alternatingTint, lineOpacity * altLineMask);
                
                // Dark lines
                float darkLineMask = step(darkLineSpacing, 0.001) * 0.0 + 
                                    (1.0 - step(darkLineSpacing, 0.001)) * 
                                    step(mod(yScreen, lineHeight * darkLineSpacing), 1.0);
                color.rgb = mix(color.rgb, darkLineColor, lineOpacity * darkLineMask);
                
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            // Cell size (set dynamically from terminal/game engine)
            cellSize: [10.0, 20.0],

            // Line opacity
            lineOpacity: 0.2,
            
            // Line spacing (relative to cellSize.y)
            lightLineSpacing: 0.2,      // Light lines every 20% of line height
            darkLineSpacing: 1.0,       // Dark lines every 100% of line height
            alternatingLineSpacing: 2.0, // Alternating tint every 2 lines
            
            // Line colors
            lightLineColor: [0.8, 0.9, 1.0],  // Light blue
            darkLineColor: [0.4, 0.5, 0.8],   // Dark blue
            alternatingTint: [0.75, 0.75, 0.75] // Slight darkening
        }
    };
}