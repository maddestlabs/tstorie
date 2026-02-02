// CRT Frame Shader for t|Storie
// Curved CRT screen with decorative frame

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
    curveStrength: f32,
    frameSize: f32,
    frameHue: f32,
    frameSat: f32,
    frameLight: f32,
    frameReflect: f32,
    frameGrain: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 random(c: vec2f) {
                return fract(sin(dot(c.xy, vec2f(12.9898, 78.233))) * 43758.5453);
            }

vec3f hsl2rgb(c: vec3f) {
                var K: vec4f = vec4f(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                var p: vec3f = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
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
                var frame: f32 = uniforms.frameSize * px;
                
                // Apply CRT curvature to UV coordinates
                uv = vUv + (vUv - center) * pow(distanceFromCenter, 5.0) * uniforms.curveStrength;
                
                // Determine if we're in the frame region
                var isFrame: bool = (uv.x < frame || uv.x > (1.0 - frame) || 
                               uv.y < frame || uv.y > (1.0 - frame));
                
                // Calculate content UV (everything inside the frame)
                var contentUV: vec2f = (uv - vec2f(frame, frame)) / (1.0 - 2.0 * frame);
                
                var color: vec3f;
                
                if (isFrame) {
                    // Frame rendering with gradient and grain
                    var frameVal: f32 = 100.0;
                    var nX: f32 = frameVal / iResolution.x;
                    var nY: f32 = frameVal / iResolution.y;
                    var intensity: f32 = 0.0;
                    var distX: f32 = min(uv.x, 1.0 - uv.x);
                    var distY: f32 = min(uv.y, 1.0 - uv.y);
                    var minDist: f32 = min(distX, distY);
                    intensity = mix(uniforms.frameLight, 0.0, minDist / max(nX, nY) * 4.0);
                    color = hsl2rgb(vec3f(uniforms.frameHue, uniforms.frameSat, intensity));
                    color *= 1.0 - uniforms.frameGrain * random(uv);
                    
                    // Reflection effect on frame - mirror and blur the content
                    var reflectedUV: vec2f = contentUV;
                    if (reflectedUV.x < 0.0) reflectedUV.x = -reflectedUV.x;
                    else if (reflectedUV.x > 1.0) reflectedUV.x = 2.0 - reflectedUV.x;
                    if (reflectedUV.y < 0.0) reflectedUV.y = -reflectedUV.y;
                    else if (reflectedUV.y > 1.0) reflectedUV.y = 2.0 - reflectedUV.y;
                    
                    // Simple blur for reflection
                    var blurred: vec3f = vec3f(0.0);
                    var blur: f32 = 2.0 / iResolution.x;
                    for (var x: i32 = -1; x <= 1.0; x++) {
                        for (var y: i32 = -1; y <= 1.0; y++) {
                            var blurPos: vec2f = reflectedUV + vec2f(float(x) * blur, float(y) * blur);
                            blurred += textureSample(contentTexture, contentTextureSampler, blurPos).rgb;
                        }
`,
        
        uniforms: {
            curveStrength: 0.95,      // CRT screen curvature (0.0 = flat, 1.0 = curved)
            frameSize: 20.0,          // Outer frame thickness in pixels
            frameHue: 0.025,          // Frame color hue (0.0-1.0)
            frameSat: 0.0,            // Frame color saturation (0.0-1.0)
            frameLight: 0.01,         // Frame base brightness (0.0-1.0)
            frameReflect: 0.35,       // Screen reflection on frame (0.0-1.0)
            frameGrain: 0.25          // Frame texture grain (0.0-1.0)
        }
    };
}