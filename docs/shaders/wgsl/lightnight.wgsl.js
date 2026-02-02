// Point Light Shader for tStorie
// Simulates realistic localized lighting with distance-based falloff
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
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {
    // Sample base color once
    let baseColor = textureSample(contentTexture, contentTextureSampler, vUv).rgb;
    
    // Aspect-corrected distance calculation (inlined for efficiency)
    let aspectRatio = uniforms.resolution.x / uniforms.resolution.y;
    let delta = (vUv - uniforms.lightPosition) * vec2f(aspectRatio, 1.0);
    let dist = length(delta);
    
    // Normalize distance by radius
    let normalizedDist = dist / uniforms.lightRadius;
    
    // Physically-based inverse square law with adjustable power
    // Combined with height factor for vertical spread (inlined)
    let heightSpread = 1.0 + (uniforms.lightHeight - 1.0) * saturate(1.0 - normalizedDist);
    let attenuation = heightSpread / (1.0 + normalizedDist * normalizedDist * uniforms.falloffPower);
    
    // Smooth cutoff at radius edge - fades from 1.0 (inside) to 0.0 (outside)
    let edgeFade = 1.0 - smoothstep(0.8, 1.2, normalizedDist);
    
    // Combined lighting calculation
    let lighting = uniforms.lightColor * (uniforms.lightIntensity * attenuation * edgeFade);
    
    // Apply lighting with ambient floor (ensures nothing goes completely black)
    let finalColor = baseColor * (uniforms.ambientLevel + lighting);
    
    return vec4f(finalColor, 1.0);
}
`,
        
        uniforms: {
            lightPosition: [0.47, 0.6],           // Top-left area (UV space)
            lightColor: [1.0, 0.95, 0.85],       // Warm white (slightly yellow)
            lightIntensity: 1.2,                  // Brightness multiplier
            lightRadius: 0.96,                     // Coverage area in UV space
            falloffPower: 1.5,                    // Attenuation sharpness (2.0-5.0 realistic)
            ambientLevel: 0.15,                   // Dark ambient for dramatic spotlight
            lightHeight: 1.5                      // Simulated height (1.0-2.0)
        }
    };
}