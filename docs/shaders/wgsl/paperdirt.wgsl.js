// Paper + Dirt Stain Shader
// Extends the paper texture with procedural dirt / stain noise

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
    resolution: vec2f,
    paperNoise: f32,
    noiseIntensity: f32,
    noiseMix: f32,
    dirtAmount: f32,
    dirtScale: f32,
    dirtContrast: f32,
    dirtColor: vec3f,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

vec3f mod289(x: vec3f) { return x - floor(x * (1.0 / 289.0)) * 289.0; }

vec4f mod289(x: vec4f) { return x - floor(x * (1.0 / 289.0)) * 289.0; }

vec4f permute(x: vec4f) { return mod289(((x * 34.0) + 1.0) * x); }

vec4f taylorInvSqrt(r: vec4f) {
                return 1.79284291400159 - 0.85373472095314 * r;
            }

f32 snoise(v: vec3f) {
                const var C: vec2f = vec2f(1.0/6.0, 1.0/3.0);
                const var D: vec4f = vec4f(0.0, 0.5, 1.0, 2.0);

                var i: vec3f  = floor(v + dot(v, C.yyy));
                var x0: vec3f = v - i + dot(i, C.xxx);

                var g: vec3f = step(x0.yzx, x0.xyz);
                var l: vec3f = 1.0 - g;
                var i1: vec3f = min(g.xyz, l.zxy);
                var i2: vec3f = max(g.xyz, l.zxy);

                var x1: vec3f = x0 - i1 + C.xxx;
                var x2: vec3f = x0 - i2 + C.yyy;
                var x3: vec3f = x0 - D.yyy;

                i = mod289(i);
                var p: vec4f = permute(permute(permute(
                         i.z + vec4f(0.0, i1.z, i2.z, 1.0))
                         + i.y + vec4f(0.0, i1.y, i2.y, 1.0))
                         + i.x + vec4f(0.0, i1.x, i2.x, 1.0));

                var n_: f32 = 0.142857142857;
                var ns: vec3f = n_ * D.wyz - D.xzx;

                var j: vec4f = p - 49.0 * floor(p * ns.z * ns.z);

                var x_: vec4f = floor(j * ns.z);
                var y_: vec4f = floor(j - 7.0 * x_);

                var x: vec4f = x_ * ns.x + ns.yyyy;
                var y: vec4f = y_ * ns.x + ns.yyyy;
                var h: vec4f = 1.0 - abs(x) - abs(y);

                var b0: vec4f = vec4f(x.xy, y.xy);
                var b1: vec4f = vec4f(x.zw, y.zw);

                var s0: vec4f = floor(b0)*2.0 + 1.0;
                var s1: vec4f = floor(b1)*2.0 + 1.0;
                var sh: vec4f = -step(h, vec4f(0.0));

                var a0: vec4f = b0.xzyw + s0.xzyw*sh.xxyy;
                var a1: vec4f = b1.xzyw + s1.xzyw*sh.zzww;

                var p0: vec3f = vec3f(a0.xy, h.x);
                var p1: vec3f = vec3f(a0.zw, h.y);
                var p2: vec3f = vec3f(a1.xy, h.z);
                var p3: vec3f = vec3f(a1.zw, h.w);

                var norm: vec4f = taylorInvSqrt(vec4f(
                    dot(p0,p0), dot(p1,p1),
                    dot(p2,p2), dot(p3,p3)
                ));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;

                var m: vec4f = max(
                    0.6 - vec4f(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2),
                        dot(x3,x3)
                    ),
                    0.0
                );
                m = m * m;

                return 42.0 * dot(m*m, vec4f(
                    dot(p0,x0),
                    dot(p1,x1),
                    dot(p2,x2),
                    dot(p3,x3)
                ));
            }

f32 hash(p: vec2f) {
                var p3: vec3f = fract(vec3f(p.x, p.y, p.x) * vec3f(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yxz + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var baseColor: vec4f = textureSample(contentTexture, contentTextureSampler, uv);

                // --------------------------------------------------------
                // Paper grain
                // --------------------------------------------------------
                var color: vec3f = baseColor.rgb;
                if (uniforms.paperNoise > 0.0) {
                    var screenPos: vec2f = uv * uniforms.resolution;
                    var grain: f32 = hash(screenPos) * uniforms.noiseIntensity;
                    color = mix(color, vec3f(1.0) * grain, uniforms.noiseMix * uniforms.paperNoise);
                }
`,
        uniforms: {
            // Paper
            paperNoise: 0.22,
            noiseIntensity: 0.28,
            noiseMix: 0.74,

            // Dirt
            dirtAmount: 0.32,
            dirtScale: 1.1,
            dirtContrast: 0.92,
            dirtColor: [0.25, 0.18, 0.12] // warm dirt / sepia
        }
    };
}
