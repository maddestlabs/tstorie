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
    resolution: vec2f,
    cellSize: vec2f,
    gridColor: vec3f,
    gridAlpha: f32,
    coreThickness: f32,
    softThickness: f32,
    haloAlpha: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Sample terminal content
                var content: vec4f = textureSample(contentTexture, contentTextureSampler, uv);
                
                // Double-width cell size for Stone Garden characters
                var doubleWidthCellSize: vec2f = vec2f(uniforms.cellSize.x * 2.0, uniforms.cellSize.y);
                
                // Convert UV to pixel coordinates
                var pixelCoord: vec2f = uv * uniforms.resolution;
                
                // Calculate position within each cell
                var cellPos: vec2f = fract(pixelCoord, doubleWidthCellSize);
                
                // Calculate distance to nearest grid line
                // Distance to left/top edge
                var distToLeft: f32 = cellPos.x;
                var distToTop: f32 = cellPos.y;
                
                // Distance to right/bottom edge
                var distToRight: f32 = doubleWidthCellSize.x - cellPos.x;
                var distToBottom: f32 = doubleWidthCellSize.y - cellPos.y;
                
                // Minimum distance to any grid line
                var distToVerticalLine: f32 = min(distToLeft, distToRight);
                var distToHorizontalLine: f32 = min(distToTop, distToBottom);
                
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
            
            // Grid appearance
            gridColor: [0.1, 0.1, 0.12], // Very dark, almost black with slight blue tint
            gridAlpha: 0.1,              // Overall grid opacity (0.0-1.0)
            
            // Softness control
            coreThickness: 0.7,          // Core line thickness in pixels (sharp)
            softThickness: 0.5,          // Additional soft halo thickness in pixels
            haloAlpha: 0.3               // Opacity of soft halo relative to core (0.0-1.0)
        }
    };
}
