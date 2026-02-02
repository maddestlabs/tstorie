// Ruled Lines Shader
// Adds notebook-style ruled lines that adapt to light or dark themes

function getShaderConfig() {
    // WGSL shader (WebGPU) - Auto-converted from GLSL {
    return {
        vertexShader: `struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) vUv: vec2f,
}

@vertex
fn vertexMain(
    @location(0) position: vec2f
) -> VertexOutput {
    var output: VertexOutput;

                output.vUv = position * 0.5 + 0.5;
                output.vUv.y = 1.0 - output.vUv.y;
                output.position = vec4f(position, 0.0, 1.0);
                return output;
}
`,
        fragmentShader: `@group(0) @binding(0) var contentTexture: texture_2d<f32>;
@group(0) @binding(1) var contentTextureSampler: sampler;

struct Uniforms {
    resolution: vec2f,
    cellSize: vec2f,
    lightLineSpacing: f32,
    darkLineSpacing: f32,
    alternatingLineSpacing: f32,
    lightLineColor: vec3f,
    darkLineColor: vec3f,
    alternatingTint: vec3f,
    lineOpacity: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 lineMask(screenCoord: f32, cell: f32, spacing: f32) {
                return step(spacing, 0.001) * 0.0 +
                    (1.0 - step(spacing, 0.001)) *
                    step(fract(screenCoord, cell * spacing), 1.0);
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var color: vec4f = textureSample(contentTexture, contentTextureSampler, vUv);

                var screenPos: vec2f = vUv * uniforms.resolution;

                var xScreen: f32 = screenPos.x;
                var yScreen: f32 = screenPos.y;

                // Line indices
                var row: f32 = floor(yScreen / uniforms.cellSize.y);
                var col: f32 = floor(xScreen / uniforms.cellSize.x);

                /* ---------------- Light grid lines ---------------- */

                var lightH: f32 = lineMask(yScreen, uniforms.cellSize.y, uniforms.lightLineSpacing);
                var lightV: f32 = lineMask(xScreen, uniforms.cellSize.x, uniforms.lightLineSpacing);
                var lightMask: f32 = max(lightH, lightV);

                var lightBlend: vec3f = mix(vec3f(1.0), uniforms.lightLineColor, uniforms.lineOpacity);
                color.rgb *= mix(vec3f(1.0), lightBlend, lightMask);

                /* ---------------- Alternating tint ---------------- */

                var altRow: f32 = step(uniforms.alternatingLineSpacing, 0.001) * 0.0 +
                            (1.0 - step(uniforms.alternatingLineSpacing, 0.001)) *
                            (1.0 - step(1.0, fract(row, uniforms.alternatingLineSpacing)));

                var altCol: f32 = step(uniforms.alternatingLineSpacing, 0.001) * 0.0 +
                            (1.0 - step(uniforms.alternatingLineSpacing, 0.001)) *
                            (1.0 - step(1.0, fract(col, uniforms.alternatingLineSpacing)));

                var altMask: f32 = max(altRow, altCol);

                // Invert so MOST cells remain light
                var invertedAltMask: f32 = 1.0 - altMask;

                color.rgb *= mix(vec3f(1.0), uniforms.alternatingTint, invertedAltMask);


                /* ---------------- Dark grid lines ---------------- */

                var darkH: f32 = lineMask(yScreen, uniforms.cellSize.y, uniforms.darkLineSpacing);
                var darkV: f32 = lineMask(xScreen, uniforms.cellSize.x, uniforms.darkLineSpacing);
                var darkMask: f32 = max(darkH, darkV);

                var darkBlend: vec3f = mix(vec3f(1.0), uniforms.darkLineColor, uniforms.lineOpacity);
                color.rgb *= mix(vec3f(1.0), darkBlend, darkMask);

                return vec4f(color.rgb, 1.0);
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