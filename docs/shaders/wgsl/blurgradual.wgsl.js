// Gradual Blur Shader for t|Storie
// Increasing blur from center to edges (tilt-shift like effect)

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
    focusPoint: vec2f,
    focusRadius: f32,
    blurRadius: f32,
    falloffPower: f32,
    sampleCount: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Calculate distance from focus point
                var centerOffset: vec2f = uv - uniforms.focusPoint;
                var distFromCenter: f32 = length(centerOffset);
                
                // Calculate blur intensity with smooth falloff
                // 0.0 at center (uniforms.focusRadius), 1.0 at edges
                var blurAmount: f32 = smoothstep(uniforms.focusRadius, uniforms.focusRadius + 0.4, distFromCenter);
                blurAmount = pow(blurAmount, uniforms.falloffPower);
                
                // Early exit: if blur amount is very low, just sample once
                if (blurAmount < 0.05) {
                    return textureSample(contentTexture, contentTextureSampler, uv);
                    return;
                }
`,
        
        uniforms: {
            // Focus area (center of sharpness)
            focusPoint: [0.5, 0.5],      // Center of screen (0.0-1.0 range)
            focusRadius: 0.2,            // Radius of perfectly sharp area (0.0-1.0)
            
            // Blur intensity
            blurRadius: 1.5,             // Maximum blur radius in pixels at edges
            
            // Falloff control
            falloffPower: 1.5,           // How quickly blur increases (1.0 = linear, 2.0 = quadratic)
            
            // Performance control
            sampleCount: 5.0             // Number of samples: 1 (none), 5 (fast), 9 (balanced), 13 (quality)
        }
    };
}
