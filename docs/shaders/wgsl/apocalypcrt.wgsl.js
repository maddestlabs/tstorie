// Apocalypse CRT Shader for tStorie
// Ported from apocalypse-crt.hlsl (MaddestLabs)

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
    grilleLvl: f32,
    grilleDensity: f32,
    scanlineLvl: f32,
    scanlines: f32,
    rgbOffset: f32,
    noiseLevel: f32,
    flicker: f32,
    hSync: f32,
    vignetteStart: f32,
    vignetteLvl: f32,
    curveStrength: f32,
    frameSize: f32,
    frameHue: f32,
    frameSat: f32,
    frameLight: f32,
    frameReflect: f32,
    frameGrain: f32,
    borderSize: f32,
    borderHue: f32,
    borderSat: f32,
    borderLight: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 random(c: vec2f) {
                return fract(sin(dot(c.xy, vec2f(12.9898,78.233))) * 43758.5453);
            }

vec3f hsl2rgb(c: vec3f) {
                var K: vec4f = vec4f(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                var p: vec3f = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }

vec3f rgbDistortion(uv: vec2f, offset: f32) {
                var color: vec3f;
                color.r = textureSample(contentTexture, contentTextureSampler, uv + vec2f(offset, 0.0)).r;
                color.g = textureSample(contentTexture, contentTextureSampler, uv).g;
                color.b = textureSample(contentTexture, contentTextureSampler, uv - vec2f(offset, 0.0)).b;
                return color;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var iTime: f32 = uniforms.time;
                var iResolution: vec2f = uniforms.resolution;
                var uv: vec2f = vUv;
                var center: vec2f = vec2f(0.5, 0.5);
                var distanceFromCenter: f32 = length(uv - center);
                var px: f32 = 1.0 / iResolution.x;
                var border: f32 = uniforms.borderSize * px;
                var frame: f32 = uniforms.frameSize * px;
                var alpha: f32 = 1.0;

                var bColor: vec3f = hsl2rgb(vec3f(uniforms.borderHue, uniforms.borderSat, uniforms.borderLight));
                // CRT Curvature (applies to all)
                uv = vUv + (vUv - center) * pow(distanceFromCenter, 5.0) * uniforms.curveStrength;

                // Frame region is at the canvas edge
                var isFrame: bool = (uv.x < frame || uv.x > (1.0 - frame) || uv.y < frame || uv.y > (1.0 - frame));
                // Border is inner padding between frame and CRT content
                var isBorder: bool = (!isFrame) && (uv.x < frame + border || uv.x > (1.0 - frame - border) || uv.y < frame + border || uv.y > (1.0 - frame - border));
                // CRT content region
                var contentUV: vec2f = (uv - vec2f(frame + border, frame + border)) / (1.0 - 2.0 * (frame + border));
                var color: vec3f;

                if (isFrame) {
                    var frameVal: f32 = 100.0;
                    var nX: f32 = frameVal / iResolution.x;
                    var nY: f32 = frameVal / iResolution.y;
                    var intensity: f32 = 0.0;
                    var distX: f32 = min(uv.x, 1.0-uv.x);
                    var distY: f32 = min(uv.y, 1.0-uv.y);
                    var minDist: f32 = min(distX, distY);
                    intensity = mix(uniforms.frameLight, 0.0, minDist / max(nX, nY) * 4.0);
                    color = hsl2rgb(vec3f(uniforms.frameHue, uniforms.frameSat, intensity));
                    color *= 1.0 - uniforms.frameGrain * random(uv);
                    // Reflection: mirror, curve, and blur
                    var f: vec2f = border * vec2f(1.0) / iResolution.xy;
                    var reflectedUV: vec2f = contentUV;
                    if (reflectedUV.x < f.x) reflectedUV.x = f.x - (reflectedUV.x - f.x);
                    else if (reflectedUV.x > 1.0 - f.x) reflectedUV.x = 1.0 - f.x - (reflectedUV.x - (1.0 - f.x));
                    if (reflectedUV.y < f.y) reflectedUV.y = f.y - (reflectedUV.y - f.y);
                    else if (reflectedUV.y > 1.0 - f.y) reflectedUV.y = 1.0 - f.y - (reflectedUV.y - (1.0 - f.y));
                    var reflCenter: vec2f = vec2f(0.5, 0.5);
                    var reflDistFromCenter: f32 = length(reflectedUV - reflCenter);
                    // Simple blur
                    var blurred: vec3f = vec3f(0.0);
                    var blur: f32 = 2.0 / iResolution.x;
                    var frameBlur: f32 = 1.0;
                    for (var x: i32 = -1; x <= 1.0; x++) {
                        for (var y: i32 = -1; y <= 1.0; y++) {
                            var blurPos: vec2f = reflectedUV + vec2f(float(x) * blur, float(y) * blur);
                            blurred += rgbDistortion(blurPos, 0.0005);
                        }
`,
        uniforms: {
            grilleLvl: 0.95,
            grilleDensity: 800.0,
            scanlineLvl: 0.8,
            scanlines: 2.0,
            rgbOffset: 0.001,
            noiseLevel: 0.025,
            flicker: 0.1,
            hSync: 0.01,
            vignetteStart: 0.25,
            vignetteLvl: 40.0,
            curveStrength: 0.95,
            frameSize: 20.0,
            frameHue: 0.025,
            frameSat: 0.0,
            frameLight: 0.01,
            frameReflect: 0.15,
            frameGrain: 0.25,
            borderSize: 2.0,
            borderHue: 0.0,
            borderSat: 0.0,
            borderLight: 0.0
        }
    };
}
