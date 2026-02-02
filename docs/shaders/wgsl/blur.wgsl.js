// Simple Box Blur Shader for t|Storie
// Made for dulling sharp edges

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
                output.vUv.y = 1.0 - output.vUv.y;  // Flip vertically
                output.position = vec4f(position, 0.0, 1.0);
                return output;
}
`,
        
        fragmentShader: `@group(0) @binding(0) var contentTexture: texture_2d<f32>;
@group(0) @binding(1) var contentTextureSampler: sampler;

struct Uniforms {
    time: f32,
    resolution: vec2f,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Calculate blur radius (in pixels)
                var blurRadius: f32 = 0.75;
                var texelSize: vec2f = 1.0 / uniforms.resolution;
                
                // Simple 9.0-sample box blur
                var color: vec4f = vec4f(0.0);
                var totalWeight: f32 = 0.0;
                
                for (var x: i32 = -1; x <= 1.0; x += 1.0) {
                    for (var y: i32 = -1; y <= 1.0; y += 1.0) {
                        var offset: vec2f = vec2f(x, y) * texelSize * blurRadius;
                        color += textureSample(contentTexture, contentTextureSampler, uv + offset);
                        totalWeight += 1.0;
                    }
`,
        
        uniforms: {
            // No custom uniforms needed
        }
    };
}
