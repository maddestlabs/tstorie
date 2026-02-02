// R3Draw Edge Detection Shader
// Ported from Shadertoy - creates sketch/cartoon effect

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
    edgeLevel: f32,
    edgeInvert: f32,
    sourceMix: f32,
    sourceLight: f32,
    sourceEmboss: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

vec3f hsl2rgb(c: vec3f) {
                var K: vec4f = vec4f(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                var p: vec3f = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }

vec4f convolveMatrix(uv: vec2f, kernel: f32, kernelDivisor: f32) {
                var sum: vec4f = vec4f(0.0);
                var texelSize: vec2f = 1.0 / resolution;
                
                // Offsets for 3x3 kernel
                var offsets: vec2f[9];
                offsets[0] = vec2f(-1.0, 1.0) * texelSize;
                offsets[1] = vec2f(0.0, 1.0) * texelSize;
                offsets[2] = vec2f(1.0, 1.0) * texelSize;
                offsets[3] = vec2f(-1.0, 0.0) * texelSize;
                offsets[4] = vec2f(0.0, 0.0) * texelSize;
                offsets[5] = vec2f(1.0, 0.0) * texelSize;
                offsets[6] = vec2f(-1.0, -1.0) * texelSize;
                offsets[7] = vec2f(0.0, -1.0) * texelSize;
                offsets[8] = vec2f(1.0, -1.0) * texelSize;
                
                // Apply convolution
                for (var i: i32 = 0.0; i < 9.0; i++) {
                    var texel: vec4f = textureSample(contentTexture, contentTextureSampler, uv + offsets[i]);
                    sum += texel * kernel[i];
                }
                
                return sum / kernelDivisor;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Sample original color
                var color: vec4f = textureSample(contentTexture, contentTextureSampler, uv);
                var c: vec3f = color.rgb;
                
                // Posterize/emboss effect
                var l: f32 = dot(c, vec3f(0.3, 0.59, 0.11));
                
                // Manual derivative approximation instead of fwidth
                var texelSize: vec2f = 1.0 / uniforms.resolution;
                var lx: f32 = dot(textureSample(contentTexture, contentTextureSampler, uv + vec2f(texelSize.x, 0.0)).rgb, vec3f(0.3, 0.59, 0.11));
                var ly: f32 = dot(textureSample(contentTexture, contentTextureSampler, uv + vec2f(0.0, texelSize.y)).rgb, vec3f(0.3, 0.59, 0.11));
                var derivative: f32 = abs(lx - l) + abs(ly - l);
                
                var f: f32 = 1.0 - uniforms.sourceEmboss * derivative;
                c *= uniforms.sourceLight * vec3f(clamp(f, 0.0, 1.0));
                
                // Edge detection kernel (Laplacian)
                var kernel: f32[9];
                kernel[0] = 1.0;  kernel[1] = 1.0;  kernel[2] = 1.0;
                kernel[3] = 1.0;  kernel[4] = -8.0; kernel[5] = 1.0;
                kernel[6] = 1.0;  kernel[7] = 1.0;  kernel[8] = 1.0;
                
                var convolved: vec4f = convolveMatrix(uv, kernel, uniforms.edgeLevel);
                var luminance: f32 = dot(convolved.rgb, vec3f(0.299, 0.587, 0.114));
                
                // Invert option
                var inverted: f32 = mix(1.0 - luminance, luminance, uniforms.edgeInvert);
                
                // Mix edge detection with original color
                var mixed: vec3f = mix(vec3f(inverted), c, uniforms.sourceMix);
                
                return vec4f(mixed, color.a);
            }
`,
        
        uniforms: {
            edgeLevel: 0.25,          // Edge detection sensitivity (0.1-1.0)
            edgeInvert: 0.0,          // 0.0 = dark lines, 1.0 = light lines
            sourceMix: 0.75,           // 0.0 = pure edges, 1.0 = original image
            sourceLight: 1.5,         // Brightness multiplier (0.5-3.0)
            sourceEmboss: 8.0,        // Posterize/emboss strength (0.0-20.0)
        }
    };
}