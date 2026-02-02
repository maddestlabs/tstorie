// Movie Film Grain Shader (Optimized) for tStorie
// Performance-optimized grain with reduced noise calls

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
    grainIntensity: f32,
    grainAdaptive: f32,
    temporalSpeed: f32,
    grainFreq: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 hash(p: vec2f) {
                var p3: vec3f = fract(vec3f(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

f32 noise(p: vec2f) {
                var i: vec2f = floor(p);
                var f: vec2f = fract(p);
                
                // Smoother interpolation (quintic)
                var u: vec2f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
                
                var a: f32 = hash(i);
                var b: f32 = hash(i + vec2f(1.0, 0.0));
                var c: f32 = hash(i + vec2f(0.0, 1.0));
                var d: f32 = hash(i + vec2f(1.0, 1.0));
                
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

f32 filmGrain(uv: vec2f, time: f32) {
                var grain: f32 = 0.0;
                
                // Fine grain (base layer)
                grain += noise(uv * grainFreq + time * 5.0) * 0.6;
                
                // Medium grain (adds texture)
                grain += noise(uv * grainFreq * 0.5 + time * 3.0) * 0.4;
                
                return grain;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var pixelCoord: vec2f = uv * uniforms.resolution;
                
                // Sample the content texture
                var color: vec4f = textureSample(contentTexture, contentTextureSampler, uv);
                
                // Generate grain with temporal variation
                var t: f32 = uniforms.time * uniforms.temporalSpeed;
                
                // Single grain value (no chromatic separation)
                var grainValue: f32 = filmGrain(pixelCoord, t);
                
                // Scale grain based on image luminance (darker = more visible grain)
                var luminance: f32 = dot(color.rgb, vec3f(0.299, 0.587, 0.114));
                var adaptiveGrain: f32 = uniforms.grainIntensity + (1.0 - luminance) * uniforms.grainAdaptive;
                
                // Apply grain to all channels equally
                var grain: f32 = (grainValue - 0.5) * adaptiveGrain;
                
                // Composite grain with original color
                var finalColor: vec3f = color.rgb + grain;
                
                return vec4f(finalColor, color.a);
            }
`,
        uniforms: {
            // Grain intensity
            grainIntensity: 0.06,        // Base grain intensity (0.0-0.1, higher = more visible grain)
            grainAdaptive: 0.3,         // Additional grain in dark areas (0.0-0.1, higher = more visible in shadows)
            
            // Temporal animation
            temporalSpeed: 0.5,          // Animation speed (0.0-2.0, higher = faster grain movement)
            
            // Grain frequency (simplified to single control)
            grainFreq: 600.0,            // Grain scale (200.0-1000.0, higher = smaller grain)
        }
    };
}