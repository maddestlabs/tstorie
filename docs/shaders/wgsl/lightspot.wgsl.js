// Realistic Circular Spotlight Shader for tStorie
// Simulates a focused spot light with smooth radial falloff and dark ambient

function getShaderConfig() {
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
    lightPosition: vec2f,
    _pad5: f32,
    _pad6: f32,
    lightColor: vec3f,
    lightIntensity: f32,
    lightRadius: f32,
    falloffSoftness: f32,
    ambientLevel: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {
    let uv = vUv;
    // Aspect-corrected distance from light center
    let aspect = uniforms.resolution.x / uniforms.resolution.y;
    let delta = (uv - uniforms.lightPosition) * vec2f(aspect, 1.0);
    let dist = length(delta);
    // Smooth radial falloff: 1.0 at center, 0.0 at edge
    let edge = uniforms.lightRadius;
    let softness = uniforms.falloffSoftness * 0.5 * uniforms.lightRadius;
    let spot = 1.0 - smoothstep(edge - softness, edge + softness, dist);
    let baseColor = textureSample(contentTexture, contentTextureSampler, uv).rgb;
    // Only add light inside the spot, leave outside unchanged
    let lightAdd = uniforms.lightColor * spot * uniforms.lightIntensity;
    let finalColor = baseColor + lightAdd;
    return vec4f(finalColor, 1.0);
}
`,
        uniforms: {
            lightPosition: [0.5, 0.5],      // Center of screen
            lightColor: [1.0, 0.98, 0.92], // Slightly warm white
            lightIntensity: 1.2,           // Spotlight strength
            lightRadius: 0.35,             // Radius in UV space (0.0-1.0)
            falloffSoftness: 0.18,         // Edge softness (0.0-0.5)
            ambientLevel: 0.08             // Very dark ambient
        }
    };
}
