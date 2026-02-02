// Border Shader for t|Storie
// Adds a solid color border around content

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
    borderSize: f32,
    _pad5: f32,
    _pad6: f32,
    _pad7: f32,
    backgroundColor: vec3f,
    _pad8: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Calculate border in pixel space
                var px: f32 = 1.0 / uniforms.resolution.x;
                var border: f32 = uniforms.borderSize * px;
                
                // Check if we're in the border region
                var isBorder: bool = (uv.x < border || uv.x > (1.0 - border) || 
                                uv.y < border || uv.y > (1.0 - border));
                
                // Calculate content UV (area inside border)
                var contentUV: vec2f = (uv - vec2f(border, border)) / (1.0 - 2.0 * border);
                
                // Always sample the content texture (required for uniform control flow)
                var sampledColor: vec3f = textureSample(contentTexture, contentTextureSampler, contentUV).rgb;
                
                // Blend between border color and content
                var color: vec3f = select(sampledColor, uniforms.backgroundColor, isBorder);
                
                return vec4f(color, 1.0);
            }
`,
        
        uniforms: {
            borderSize: 20.0,                    // Border thickness in pixels
            backgroundColor: [0.0, 0.0, 0.0]     // Border color (RGB, black by default)
        }
    };
}