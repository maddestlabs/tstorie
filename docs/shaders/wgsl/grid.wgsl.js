// Soft Grid Shader for Stone Garden
// Draws a soft-edged grid for double-width character cells
// Optimized for zen aesthetic with gentle color blending

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
    time: f32,
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
    resolution: vec2f,
    _pad3: f32,
    _pad4: f32,
    cellSize: vec2f,
    _pad5: f32,
    _pad6: f32,
    gridColor: vec3f,
    _padColor: f32,
    gridAlpha: f32,
    coreThickness: f32,
    softThickness: f32,
    haloAlpha: f32,
    _pad7: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

fn isNanF32(x: f32) -> bool {
    // NaN is the only float where (x != x) is true.
    return x != x;
}

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Sample terminal content
                var content: vec4f = textureSample(contentTexture, contentTextureSampler, uv);
                
                // Use cellSize directly (already scaled by DPR from terminal)
                // Guard against NaNs/zeros (can happen early in init, or if JS writes NaN)
                var cellSize: vec2f = uniforms.cellSize;
                if (isNanF32(cellSize.x) || isNanF32(cellSize.y) || cellSize.x < 1.0 || cellSize.y < 1.0) {
                    cellSize = vec2f(10.0, 20.0);
                }
                
                // Convert UV to pixel coordinates
                // Prefer uniforms.resolution, but fall back to the input texture size if needed
                var resolution: vec2f = uniforms.resolution;
                if (isNanF32(resolution.x) || isNanF32(resolution.y) || resolution.x < 1.0 || resolution.y < 1.0) {
                    let dims: vec2u = textureDimensions(contentTexture);
                    resolution = vec2f(f32(dims.x), f32(dims.y));
                }
                var pixelCoord: vec2f = uv * resolution;
                
                // Compute cell-local coordinates robustly
                // cellFrac: 0..1 position inside the cell
                let cellFrac: vec2f = fract(pixelCoord / cellSize);
                // Distance in pixels to the nearest vertical/horizontal cell border
                var distToVerticalLine: f32 = min(cellFrac.x, 1.0 - cellFrac.x) * cellSize.x;
                var distToHorizontalLine: f32 = min(cellFrac.y, 1.0 - cellFrac.y) * cellSize.y;
                
                // Calculate line intensity with soft falloff
                // Core line (sharp, dark)
                var verticalCore: f32 = 1.0 - smoothstep(0.0, uniforms.coreThickness, distToVerticalLine);
                var horizontalCore: f32 = 1.0 - smoothstep(0.0, uniforms.coreThickness, distToHorizontalLine);
                
                // Soft halo (gentle, lighter)
                var verticalHalo: f32 = 1.0 - smoothstep(uniforms.coreThickness, uniforms.coreThickness + uniforms.softThickness, distToVerticalLine);
                var horizontalHalo: f32 = 1.0 - smoothstep(uniforms.coreThickness, uniforms.coreThickness + uniforms.softThickness, distToHorizontalLine);
                
                // Combine core and halo
                var verticalLine: f32 = verticalCore + verticalHalo * uniforms.haloAlpha;
                var horizontalLine: f32 = horizontalCore + horizontalHalo * uniforms.haloAlpha;
                
                // Combine vertical and horizontal (max = at intersections)
                var gridIntensity: f32 = max(verticalLine, horizontalLine);
                
                // Blend grid color over terminal content
                var finalColor: vec3f = mix(content.rgb, uniforms.gridColor, gridIntensity * uniforms.gridAlpha);
                
                return vec4f(finalColor, 1.0);
            }
`,
        uniforms: {
            // Cell size (set dynamically by terminal, then doubled for double-width chars)
            cellSize: [10.0, 20.0],     // Will be updated by terminal
            
            // Grid appearance - TESTING: much more visible
            gridColor: [0.0, 0.5, 1.0],  // Bright blue for testing
            gridAlpha: 0.8,              // Overall grid opacity (0.0-1.0) - increased
            
            // Softness control
            coreThickness: 2.0,          // Core line thickness in pixels (sharp) - increased
            softThickness: 2.0,          // Additional soft halo thickness in pixels - increased
            haloAlpha: 0.5               // Opacity of soft halo relative to core (0.0-1.0) - increased
        }
    };
}
