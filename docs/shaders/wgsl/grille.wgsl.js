// CRT Scanlines & Aperture Grille Shader for t|Storie
// Light approximation for retro aesthetics

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
    scanlineIntensity: f32,
    scanlineSharpness: f32,
    bloomAmount: f32,
    phosphorSharpness: f32,
    grilleBrightness: f32,
    maskStrength: f32,
    enableScanlines: f32,
    enableApertureGrille: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 gaussianWeight(x: f32, sigma: f32) {
                return exp(-(x * x) / (2.0 * sigma * sigma));
            }

vec3f apertureMask(pixelPos: vec2f) {
                // Each pixel is divided into RGB subpixels
                var subpixel: f32 = fract(pixelPos.x, 3.0);
                
                var mask: vec3f = vec3f(0.0);
                
                // Red stripe
                if (subpixel < 1.0) {
                    mask.r = 1.0;
                }
                // Green stripe
                else if (subpixel < 2.0) {
                    mask.g = 1.0;
                }
                // Blue stripe
                else {
                    mask.b = 1.0;
                }
                
                // Apply sharpness - softer edges blend the stripes
                var sharpness: f32 = phosphorSharpness;
                mask = mix(vec3f(1.0), mask, sharpness);
                
                // Normalize brightness
                mask *= grilleBrightness;
                
                return mask;
            }

f32 scanlineMask(y: f32, scanlineHeight: f32) {
                // Calculate position within current scanline (0.0 to 1.0)
                var linePos: f32 = fract(y, scanlineHeight) / scanlineHeight;
                
                // Center of scanline is at 0.5
                var distFromCenter: f32 = abs(linePos - 0.5) * 2.0;
                
                // Gaussian falloff from center of scanline
                var sigma: f32 = 0.5 / scanlineSharpness;
                var intensity: f32 = gaussianWeight(distFromCenter, sigma);
                
                // Mix between full brightness and the gap darkness
                return mix(scanlineIntensity, 1.0, intensity);
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var pixelPos: vec2f = uv * uniforms.resolution;
                
                // Sample base color
                var color: vec3f = textureSample(contentTexture, contentTextureSampler, uv).rgb;
                
                // Calculate brightness for bloom (bright areas bleed into gaps)
                var brightness: f32 = dot(color, vec3f(0.299, 0.587, 0.114));
                
                // Apply aperture grille (vertical RGB stripes)
                if (uniforms.enableApertureGrille > 0.5) {
                    var mask: vec3f = apertureMask(pixelPos);
                    
                    // Bright pixels can bleed through the mask more
                    var bleedThrough: f32 = mix(1.0, 1.5, brightness * uniforms.bloomAmount);
                    mask *= bleedThrough;
                    
                    // Apply mask with controllable strength
                    color *= mix(vec3f(1.0), mask, uniforms.maskStrength);
                }
`,
        
        uniforms: {
            scanlineIntensity: 0.3,
            scanlineSharpness: 2.0,
            bloomAmount: 0.5,
            phosphorSharpness: 0.2,
            grilleBrightness: 0.50,
            maskStrength: 0.7,
            enableScanlines: 0.0,
            enableApertureGrille: 1.0
        }
    };
}