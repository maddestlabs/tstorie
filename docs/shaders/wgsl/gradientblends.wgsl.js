// Four Corner Gradient with Color Dodge Blend
// Subtle color overlay to brighten and add warmth to paper textures

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
    topLeftColor: vec3f,
    topRightColor: vec3f,
    bottomLeftColor: vec3f,
    bottomRightColor: vec3f,
    blendAmount: f32,
    gradientSoftness: f32,
    blendMode: i32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

vec3f blendNormal(base: vec3f, blend: vec3f) {
                return blend;
            }

vec3f blendMultiply(base: vec3f, blend: vec3f) {
                return base * blend;
            }

vec3f blendScreen(base: vec3f, blend: vec3f) {
                return 1.0 - (1.0 - base) * (1.0 - blend);
            }

vec3f blendOverlay(base: vec3f, blend: vec3f) {
                return mix(
                    2.0 * base * blend,
                    1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
                    step(0.5, base)
                );
            }

vec3f blendSoftLight(base: vec3f, blend: vec3f) {
                return mix(
                    2.0 * base * blend + base * base * (1.0 - 2.0 * blend),
                    sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend),
                    step(0.5, blend)
                );
            }

vec3f blendColorDodge(base: vec3f, blend: vec3f) {
                return min(base / (1.0 - blend + 0.001), vec3f(1.0));
            }

vec3f blendColorBurn(base: vec3f, blend: vec3f) {
                return 1.0 - min((1.0 - base) / (blend + 0.001), vec3f(1.0));
            }

vec3f blendLinearDodge(base: vec3f, blend: vec3f) {
                return min(base + blend, vec3f(1.0));
            }

vec3f blendAdd(base: vec3f, blend: vec3f) {
                return min(base + blend, vec3f(1.0));
            }

vec3f applyBlendMode(base: vec3f, blend: vec3f, mode: i32) {
                // 0.0=Normal, 1.0=Multiply, 2.0=Screen, 3.0=Overlay, 4.0=SoftLight, 5.0=ColorDodge, 6.0=ColorBurn, 7.0=LinearDodge, 8.0=Add
                var m: f32 = float(5.0);
                
                var result: vec3f = base;
                
                // Build result by mixing each mode based on exact match
                result = mix(result, blendNormal(base, blend), step(abs(m - 0.0), 0.1));
                result = mix(result, blendMultiply(base, blend), step(abs(m - 1.0), 0.1));
                result = mix(result, blendScreen(base, blend), step(abs(m - 2.0), 0.1));
                result = mix(result, blendOverlay(base, blend), step(abs(m - 3.0), 0.1));
                result = mix(result, blendSoftLight(base, blend), step(abs(m - 4.0), 0.1));
                result = mix(result, blendColorDodge(base, blend), step(abs(m - 5.0), 0.1));
                result = mix(result, blendColorBurn(base, blend), step(abs(m - 6.0), 0.1));
                result = mix(result, blendLinearDodge(base, blend), step(abs(m - 7.0), 0.1));
                result = mix(result, blendAdd(base, blend), step(abs(m - 8.0), 0.1));
                
                return result;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var baseColor: vec4f = textureSample(contentTexture, contentTextureSampler, uv);

                // --------------------------------------------------------
                // Create four-corner gradient
                // --------------------------------------------------------
                
                // Apply softness curve to UV (makes gradient less linear)
                var softUv: vec2f = uv;
                softUv = pow(softUv, vec2f(uniforms.gradientSoftness));
                var invSoftUv: vec2f = vec2f(1.0) - softUv;
                invSoftUv = pow(invSoftUv, vec2f(uniforms.gradientSoftness));
                
                // Bilinear interpolation between four corners
                var top: vec3f = mix(uniforms.topLeftColor, uniforms.topRightColor, softUv.x);
                var bottom: vec3f = mix(uniforms.bottomLeftColor, uniforms.bottomRightColor, softUv.x);
                var gradientColor: vec3f = mix(top, bottom, softUv.y);

                // --------------------------------------------------------
                // Apply selected blend mode
                // --------------------------------------------------------
                var blended: vec3f = applyBlendMode(baseColor.rgb, gradientColor, uniforms.blendMode);
                
                // Mix based on blend amount
                var finalColor: vec3f = mix(baseColor.rgb, blended, uniforms.blendAmount);

                return vec4f(finalColor, 1.0);
            }
`,
        uniforms: {
            // Corner colors
            topLeftColor: [1.0, 0.92, 0.96],        // Red
            topRightColor: [0.6, 0.5, 0.6],      // Yellow
            bottomLeftColor: [0.4, 0.9, 0.5],     // Green
            bottomRightColor: [0.7, 0.6, 1.0],    // Blue

            // Blend controls
            blendAmount: 0.25,      // How much of the gradient to apply
            gradientSoftness: 1.2,  // Higher = softer, more circular gradient
            blendMode: 5            // 0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=SoftLight, 5=ColorDodge, 6=ColorBurn, 7=LinearDodge, 8=Add
        }
    };
}