// Ruled Lines Shader
// Adds notebook-style ruled lines with configurable blend modes

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
            uniform float lightLineBlend;
            uniform float darkLineBlend;
            uniform float alternatingBlend;
            uniform int lightLineBlendMode;
            uniform int darkLineBlendMode;
            uniform int alternatingBlendMode;
            varying vec2 vUv;

            // Blend mode functions
            vec3 blendNormal(vec3 base, vec3 blend, float opacity) {
                return mix(base, blend, opacity);
            }

            vec3 blendMultiply(vec3 base, vec3 blend, float opacity) {
                return mix(base, base * blend, opacity);
            }

            vec3 blendScreen(vec3 base, vec3 blend, float opacity) {
                vec3 result = vec3(1.0) - (vec3(1.0) - base) * (vec3(1.0) - blend);
                return mix(base, result, opacity);
            }

            vec3 blendOverlay(vec3 base, vec3 blend, float opacity) {
                vec3 result;
                result.r = base.r < 0.5 ? 2.0 * base.r * blend.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
                result.g = base.g < 0.5 ? 2.0 * base.g * blend.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
                result.b = base.b < 0.5 ? 2.0 * base.b * blend.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
                return mix(base, result, opacity);
            }

            vec3 applyBlendMode(vec3 base, vec3 blend, float opacity, int mode) {
                if (mode == 0) return blendNormal(base, blend, opacity);
                if (mode == 1) return blendMultiply(base, blend, opacity);
                if (mode == 2) return blendScreen(base, blend, opacity);
                if (mode == 3) return blendOverlay(base, blend, opacity);
                return base;
            }

            void main() {
                vec2 uv = vUv;
                vec4 color = texture2D(contentTexture, uv);
                
                // Use cellSize height to determine line spacing
                float lineHeight = cellSize.y;
                
                // Calculate screen position for pixel-perfect lines
                vec2 screenPos = uv * resolution;
                float yScreen = screenPos.y;
                
                // Calculate base line number
                float lineNumber = floor(yScreen / lineHeight);
                
                // Light lines (every LINE_HEIGHT * lightLineSpacing pixels)
                if (lightLineSpacing > 0.0 && mod(yScreen, lineHeight * lightLineSpacing) < 1.0) {
                    color.rgb = applyBlendMode(color.rgb, lightLineColor, lightLineBlend, lightLineBlendMode);
                }
                
                // Alternating line tint (every other line)
                if (alternatingLineSpacing > 0.0 && mod(lineNumber, alternatingLineSpacing) < 1.0) {
                    color.rgb = applyBlendMode(color.rgb, alternatingTint, alternatingBlend, alternatingBlendMode);
                }
                
                // Dark lines (every LINE_HEIGHT * darkLineSpacing pixels)
                if (darkLineSpacing > 0.0 && mod(yScreen, lineHeight * darkLineSpacing) < 1.0) {
                    color.rgb = applyBlendMode(color.rgb, darkLineColor, darkLineBlend, darkLineBlendMode);
                }
                
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        `,
        uniforms: {
            // Cell size (set dynamically from terminal/game engine)
            cellSize: [10.0, 20.0],
            
            // Line spacing (relative to cellSize.y)
            lightLineSpacing: 0.2,      // Light lines every 20% of line height
            darkLineSpacing: 1.0,       // Dark lines every 100% of line height
            alternatingLineSpacing: 2.0, // Alternating tint every 2 lines
            
            // Line colors
            lightLineColor: [0.8, 0.9, 1.0],  // Light blue
            darkLineColor: [0.4, 0.5, 0.8],   // Dark blue
            alternatingTint: [0.37, 0.37, 0.37], // Slight darkening
            
            // Blend amounts (0.0-1.0)
            lightLineBlend: 0.1,
            darkLineBlend: 0.1,
            alternatingBlend: 0.1,
            
            // Blend modes (0=Normal, 1=Multiply, 2=Screen, 3=Overlay)
            lightLineBlendMode: 2,
            darkLineBlendMode: 2,
            alternatingBlendMode: 2
        }
    };
}