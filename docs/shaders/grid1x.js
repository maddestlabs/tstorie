// Ruled Lines Shader
// Adds notebook-style ruled lines that adapt to light or dark themes

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

            float lineMask(float screenCoord, float cell, float spacing) {
                return step(spacing, 0.001) * 0.0 +
                    (1.0 - step(spacing, 0.001)) *
                    step(mod(screenCoord, cell * spacing), 1.0);
            }

            void main() {
                vec4 color = texture2D(contentTexture, vUv);

                vec2 screenPos = vUv * resolution;

                float xScreen = screenPos.x;
                float yScreen = screenPos.y;

                // Line indices
                float row = floor(yScreen / cellSize.y);
                float col = floor(xScreen / cellSize.x);

                /* ---------------- Light grid lines ---------------- */

                float lightH = lineMask(yScreen, cellSize.y, lightLineSpacing);
                float lightV = lineMask(xScreen, cellSize.x, lightLineSpacing);
                float lightMask = max(lightH, lightV);

                vec3 lightBlend = mix(vec3(1.0), lightLineColor, lineOpacity);
                color.rgb *= mix(vec3(1.0), lightBlend, lightMask);

                /* ---------------- Alternating tint ---------------- */

                float altRow = step(alternatingLineSpacing, 0.001) * 0.0 +
                            (1.0 - step(alternatingLineSpacing, 0.001)) *
                            (1.0 - step(1.0, mod(row, alternatingLineSpacing)));

                float altCol = step(alternatingLineSpacing, 0.001) * 0.0 +
                            (1.0 - step(alternatingLineSpacing, 0.001)) *
                            (1.0 - step(1.0, mod(col, alternatingLineSpacing)));

                float altMask = max(altRow, altCol);

                // Invert so MOST cells remain light
                float invertedAltMask = 1.0 - altMask;

                color.rgb *= mix(vec3(1.0), alternatingTint, invertedAltMask);


                /* ---------------- Dark grid lines ---------------- */

                float darkH = lineMask(yScreen, cellSize.y, darkLineSpacing);
                float darkV = lineMask(xScreen, cellSize.x, darkLineSpacing);
                float darkMask = max(darkH, darkV);

                vec3 darkBlend = mix(vec3(1.0), darkLineColor, lineOpacity);
                color.rgb *= mix(vec3(1.0), darkBlend, darkMask);

                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            // Cell size (set dynamically from terminal/game engine)
            cellSize: [10.0, 20.0],

            // Line opacity
            lineOpacity: 0.45,
            
            // Line spacing (relative to cellSize.y)
            lightLineSpacing: 0.2,      // Light lines every 20% of line height
            darkLineSpacing: 1.0,       // Dark lines every 100% of line height
            alternatingLineSpacing: 2.0, // Alternating tint every 2 lines
            
            // Line colors (for multiply blend - values < 1.0 darken)
            lightLineColor: [0.92, 0.94, 0.96],  // Subtle gray-blue
            darkLineColor: [0.7, 0.75, 0.8],     // Medium gray-blue
            alternatingTint: [0.99, 0.99, 0.99]  // Very subtle darkening
        }
    };
}