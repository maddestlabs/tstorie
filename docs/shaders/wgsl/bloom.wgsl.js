// Bloom Shader for tStorie
// Subtle Gaussian bloom with focus on performance

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
    bloomIntensity: f32,
    bloomRadius: f32,
    bloomThreshold: f32,
    bloomSoftness: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

// Calculate luminance from RGB
fn luminance(color: vec3f) -> f32 {
    return dot(color, vec3f(0.299, 0.587, 0.114));
}

// Extract bright areas above threshold with soft falloff
fn extractBrightness(color: vec3f, threshold: f32, softness: f32) -> vec3f {
    let lum = luminance(color);
    let edge0 = threshold - softness;
    let edge1 = threshold + softness;
    let contribution = smoothstep(edge0, edge1, lum);
    return color * contribution;
}

// 2D Gaussian blur in a single pass (radial sampling)
fn gaussianBlur2D(uv: vec2f, radius: f32) -> vec3f {
    let pixelSize = 1.0 / uniforms.resolution;
    
    // Gaussian weights for radial samples
    let weights = array<f32, 5>(0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
    
    var result = textureSample(contentTexture, contentTextureSampler, uv).rgb * weights[0];
    
    // Sample in both X and Y directions simultaneously
    for (var i: i32 = 1; i < 5; i++) {
        let offset = f32(i) * radius;
        let w = weights[i];
        
        // Horizontal samples
        result += textureSample(contentTexture, contentTextureSampler, uv + vec2f(offset, 0.0) * pixelSize).rgb * w;
        result += textureSample(contentTexture, contentTextureSampler, uv - vec2f(offset, 0.0) * pixelSize).rgb * w;
        
        // Vertical samples
        result += textureSample(contentTexture, contentTextureSampler, uv + vec2f(0.0, offset) * pixelSize).rgb * w;
        result += textureSample(contentTexture, contentTextureSampler, uv - vec2f(0.0, offset) * pixelSize).rgb * w;
        
        // Diagonal samples for more uniform blur
        result += textureSample(contentTexture, contentTextureSampler, uv + vec2f(offset, offset) * pixelSize).rgb * (w * 0.7071);
        result += textureSample(contentTexture, contentTextureSampler, uv - vec2f(offset, offset) * pixelSize).rgb * (w * 0.7071);
        result += textureSample(contentTexture, contentTextureSampler, uv + vec2f(-offset, offset) * pixelSize).rgb * (w * 0.7071);
        result += textureSample(contentTexture, contentTextureSampler, uv - vec2f(-offset, offset) * pixelSize).rgb * (w * 0.7071);
    }
    
    // Normalize by total weight
    return result / 3.5;
}

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {
    let uv = vUv;
    
    // Sample base color
    let baseColor = textureSample(contentTexture, contentTextureSampler, uv).rgb;
    
    // Extract bright areas
    let brightColor = extractBrightness(baseColor, uniforms.bloomThreshold, uniforms.bloomSoftness);
    
    // Apply 2D Gaussian blur
    let bloom = gaussianBlur2D(uv, uniforms.bloomRadius);
    
    // Combine base with bloom
    let finalColor = baseColor + bloom * uniforms.bloomIntensity;
    
    return vec4f(finalColor, 1.0);
}
`,
        
        uniforms: {
            bloomIntensity: 0.4,      // Bloom strength (0.0-1.0+)
            bloomRadius: 3.0,         // Blur radius in pixels
            bloomThreshold: 0.6,      // Brightness threshold (0.0-1.0)
            bloomSoftness: 0.2        // Threshold softness
        }
    };
}