// Soft Grid Shader for Stone Garden
// Draws a soft-edged grid for double-width character cells
// Optimized for zen aesthetic with gentle color blending

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
            uniform vec2 cellSize;
            uniform vec3 gridColor;
            uniform float gridAlpha;
            uniform float coreThickness;
            uniform float softThickness;
            uniform float haloAlpha;
            varying vec2 vUv;

            void main() {
                vec2 uv = vUv;
                
                // Sample terminal content
                vec4 content = texture2D(contentTexture, uv);
                
                // Double-width cell size for Stone Garden characters
                vec2 doubleWidthCellSize = vec2(cellSize.x, cellSize.y);
                
                // Convert UV to pixel coordinates
                vec2 pixelCoord = uv * resolution;
                
                // Calculate position within each cell
                vec2 cellPos = mod(pixelCoord, doubleWidthCellSize);
                
                // Calculate distance to nearest grid line
                // Distance to left/top edge
                float distToLeft = cellPos.x;
                float distToTop = cellPos.y;
                
                // Distance to right/bottom edge
                float distToRight = doubleWidthCellSize.x - cellPos.x;
                float distToBottom = doubleWidthCellSize.y - cellPos.y;
                
                // Minimum distance to any grid line
                float distToVerticalLine = min(distToLeft, distToRight);
                float distToHorizontalLine = min(distToTop, distToBottom);
                
                // Calculate line intensity with soft falloff
                // Core line (sharp, dark)
                float verticalCore = 1.0 - smoothstep(0.0, coreThickness, distToVerticalLine);
                float horizontalCore = 1.0 - smoothstep(0.0, coreThickness, distToHorizontalLine);
                
                // Soft halo (gentle, lighter)
                float verticalHalo = 1.0 - smoothstep(coreThickness, coreThickness + softThickness, distToVerticalLine);
                float horizontalHalo = 1.0 - smoothstep(coreThickness, coreThickness + softThickness, distToHorizontalLine);
                
                // Combine core and halo
                float verticalLine = verticalCore + verticalHalo * haloAlpha;
                float horizontalLine = horizontalCore + horizontalHalo * haloAlpha;
                
                // Combine vertical and horizontal (max = at intersections)
                float gridIntensity = max(verticalLine, horizontalLine);
                
                // Blend grid color over terminal content
                vec3 finalColor = mix(content.rgb, gridColor, gridIntensity * gridAlpha);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Cell size (set dynamically by terminal, then doubled for double-width chars)
            cellSize: [10.0, 20.0],     // Will be updated by terminal
            
            // Grid appearance
            gridColor: [0.1, 0.1, 0.12], // Very dark, almost black with slight blue tint
            gridAlpha: 0.2,              // Overall grid opacity (0.0-1.0)
            
            // Softness control
            coreThickness: 0.7,          // Core line thickness in pixels (sharp)
            softThickness: 0.7,          // Additional soft halo thickness in pixels
            haloAlpha: 0.1               // Opacity of soft halo relative to core (0.0-1.0)
        }
    };
}
