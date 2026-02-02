// Swaying Point Light Shader for t|Storie
// Perfect for desk lamps, candles, or any point light source

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
    lightPosition: vec2f,
    _pad5: f32,
    _pad6: f32,
    lightColor: vec3f,
    lightIntensity: f32,
    lightRadius: f32,
    falloffPower: f32,
    ambientLevel: f32,
    lightHeight: f32,
    swayAmount: f32,
    swaySpeed: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {
    let uv = vUv;
    // Calculate swaying light position (horizontal sway)
    let swayOffset = sin(uniforms.time * uniforms.swaySpeed) * uniforms.swayAmount;
    let swayedLightPos = vec2f(uniforms.lightPosition.x + swayOffset, uniforms.lightPosition.y);
    // Aspect-corrected distance calculation
    let aspectRatio = uniforms.resolution.x / uniforms.resolution.y;
    let delta = (uv - swayedLightPos) * vec2f(aspectRatio, 1.0);
    let dist = length(delta);
    // Normalize distance by radius
    let normalizedDist = dist / uniforms.lightRadius;
    // Physically-based inverse square law with adjustable power
    let heightSpread = 1.0 + (uniforms.lightHeight - 1.0) * saturate(1.0 - normalizedDist);
    let attenuation = heightSpread / (1.0 + normalizedDist * normalizedDist * uniforms.falloffPower);
    // Smooth cutoff at radius edge
    let edgeFade = 1.0 - smoothstep(0.8, 1.2, normalizedDist);
    // Combined lighting calculation
    let lighting = uniforms.lightColor * (uniforms.lightIntensity * attenuation * edgeFade);
    // Sample base color
    let baseColor = textureSample(contentTexture, contentTextureSampler, uv).rgb;
    // Apply lighting with ambient floor
    let finalColor = baseColor * (uniforms.ambientLevel + lighting);
    return vec4f(finalColor, 1.0);
}
`,
        
        uniforms: {
            lightPosition: [0.47, 0.6],           // Center area (UV space)
            lightColor: [1.0, 0.95, 0.85],       // Warm white (slightly yellow)
            lightIntensity: 0.45,                 // Brightness multiplier
            lightRadius: 3.0,                     // Coverage area in UV space
            falloffPower: 5.0,                    // Attenuation sharpness (2.0-5.0 realistic)
            ambientLevel: 0.85,                   // Ambient light level
            lightHeight: 1.62,                    // Simulated height (1.0-2.0)
            swayAmount: 0.6,                     // Horizontal sway range (0.0-0.2)
            swaySpeed: 0.9                        // Sway speed (0.5-2.0)
        }
    };
}