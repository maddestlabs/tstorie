// Film Scratches Shader for tStorie
// Simulates realistic analog film scratches using Bezier curves

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
    scratchInterval: f32,
    scratchLifetime: f32,
    minAlpha: f32,
    maxAlpha: f32,
    minLength: f32,
    maxLength: f32,
    straightness: f32,
    noisiness: f32,
    minWidth: f32,
    maxWidth: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

vec2f bezier(t: f32, p0: vec2f, p1: vec2f, p2: vec2f, p3: vec2f) {
                var it: f32 = 1.0 - t;
                return it * it * it * p0 + 3.0 * it * it * t * p1 + 3.0 * it * t * t * p2 + t * t * t * p3;
            }

f32 rand(co: vec2f) {
                return fract(sin(dot(co.xy, vec2f(12.9898, 78.233))) * 43758.5453);
            }

f32 line(p1: vec2f, p2: vec2f, p: vec2f, noise: f32) {
                var v: vec2f = p2 - p1;
                var w: vec2f = p - p1;
                var c1: f32 = dot(w, v);
                if (c1 <= 0.0) return length(w) + noise * rand(p1 + p2) - 0.5 * noise;
                var c2: f32 = dot(v, v);
                if (c2 <= c1) return length(p - p2) + noise * rand(p1 + p2) - 0.5 * noise;
                var b: f32 = c1 / c2;
                var baseDistance: f32 = length(p - (p1 + b * v));
                return baseDistance + noise * rand(p + p1 + p2) - 0.5 * noise;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var baseColor: vec3f = textureSample(contentTexture, contentTextureSampler, uv).rgb;
                
                var lifeInterval: f32 = uniforms.scratchInterval * uniforms.scratchLifetime;
                var currentTimeInInterval: f32 = fract(uniforms.time, uniforms.scratchInterval);
                var isLineVisible: bool = currentTimeInInterval <= lifeInterval;
                
                if (!isLineVisible) {
                    return vec4f(baseColor, 1.0);
                    return;
                }
`,
        uniforms: {
            // Scratch timing
            scratchInterval: 1.5,        // How often new scratches appear (0.1-4.0, higher = less frequent)
            scratchLifetime: 0.1,        // How long scratches persist (0.1-1.0, fraction of interval)
            
            // Scratch appearance
            minAlpha: 0.4,               // Minimum scratch opacity (0.0-1.0)
            maxAlpha: 0.8,               // Maximum scratch opacity (0.0-1.0)
            minLength: 0.005,            // Minimum scratch length (0.0-1.0)
            maxLength: 0.5,              // Maximum scratch length (0.0-3.0)
            straightness: 0.8,           // Probability of straight scratches (0.0-1.0, higher = straighter)
            noisiness: 0.001,            // Edge roughness (0.0-0.015, higher = rougher)
            minWidth: 0.0,               // Minimum scratch width (0.0-0.005)
            maxWidth: 0.0002              // Maximum scratch width (0.0-0.015)
        }
    };
}