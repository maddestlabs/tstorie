// Clouds Shader for tStorie
// Procedural cloud/fog effect inspired by Chrono Trigger

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
    cloudDensity: f32,
    cloudScale: f32,
    cloudSpeed: f32,
    cloudDirection: vec2f,
    cloudSoftness: f32,
    cloudColor: vec3f,
    layerCount: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

vec2f hash(p: vec2f) {
                p = vec2f(dot(p, vec2f(127.1, 311.7)), dot(p, vec2f(269.5, 183.3)));
                return fract(sin(p) * 43758.5453);
            }

f32 noise(p: vec2f) {
                var i: vec2f = floor(p);
                var f: vec2f = fract(p);
                
                // Smooth interpolation
                var u: vec2f = f * f * (3.0 - 2.0 * f);
                
                // Four corners
                var a: f32 = dot(hash(i + vec2f(0.0, 0.0)) - 0.5, f - vec2f(0.0, 0.0));
                var b: f32 = dot(hash(i + vec2f(1.0, 0.0)) - 0.5, f - vec2f(1.0, 0.0));
                var c: f32 = dot(hash(i + vec2f(0.0, 1.0)) - 0.5, f - vec2f(0.0, 1.0));
                var d: f32 = dot(hash(i + vec2f(1.0, 1.0)) - 0.5, f - vec2f(1.0, 1.0));
                
                // Bilinear interpolation
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

f32 fbm(p: vec2f, octaves: i32) {
                var value: f32 = 0.0;
                var amplitude: f32 = 0.5;
                var frequency: f32 = 1.0;
                
                for (var i: i32 = 0.0; i < 4.0; i++) {
                    if (i >= octaves) break;
                    value += amplitude * noise(p * frequency);
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }
                
                return value;
            }

f32 cloudPattern(uv: vec2f, timeOffset: f32) {
                // Apply cloud movement
                var movement: vec2f = cloudDirection * time * cloudSpeed + vec2f(timeOffset * 10.0, 0.0);
                var cloudUv: vec2f = (uv + movement) * cloudScale;
                
                // Create billowy cloud shapes with FBM
                var clouds: f32 = fbm(cloudUv, 4.0);
                
                // Add another layer at different scale for variety
                clouds += fbm(cloudUv * 0.5 + vec2f(100.0), 3.0) * 0.5;
                
                // Normalize and apply softness
                clouds = (clouds + 1.0) * 0.5; // Map from [-1.0,1] to [0.0,1]
                clouds = smoothstep(0.5 - cloudSoftness, 0.5 + cloudSoftness, clouds);
                
                return clouds;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Sample base texture
                var baseColor: vec3f = textureSample(contentTexture, contentTextureSampler, uv).rgb;
                
                // Generate multiple cloud layers for depth
                var cloudMask: f32 = 0.0;
                var layers: i32 = int(uniforms.layerCount);
                
                for (var i: i32 = 0; i < 3.0; i++) {
                    if (i >= layers) break;
                    
                    var layerOffset: f32 = float(i) * 0.3;
                    var layerSpeed: f32 = 1.0 + float(i) * 0.2; // Parallax effect
                    var layer: f32 = cloudPattern(uv, layerOffset) * (1.0 - float(i) * 0.2);
                    cloudMask += layer;
                }
`,
        
        uniforms: {
    cloudDensity: 0.5,
    cloudScale: 0.5,
    cloudSpeed: 0.075,
    cloudDirection: [1.15, -0.3],
    cloudSoftness: 0.01,
    cloudColor: [0.7, 0.75, 0.8],
    layerCount: 2.0
        }
    };
}