// Desert Sand Shader for tStorie
// Creates a pixelated desert sand texture with organic variation

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
    sandScale: f32,
    sandDensity: f32,
    temporalSpeed: f32,
    colorVariation: f32,
    sandIntensity: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 hash2(p: vec2f) {
                var p3: vec3f = fract(vec3f(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

f32 sandTexture(uv: vec2f, time: f32) {
                var pixelPos: vec2f = uv * resolution;
                
                // Primary sand grain pattern
                var sandNoise: f32 = hash2(floor(pixelPos * sandScale));
                
                // Threshold to control sand density/coverage
                var threshold: f32 = 1.0 - sandDensity;
                var sandMask: f32 = step(threshold, sandNoise);
                
                // Slow temporal variation (sand grains shift slowly)
                var slowTime: f32 = floor(time * temporalSpeed);
                var temporalNoise: f32 = hash2(floor(pixelPos * sandScale) + vec2f(slowTime));
                
                // Combine spatial and temporal
                var sandPattern: f32 = sandMask * temporalNoise;
                
                // Add finer sand detail at different scale
                var fineScale: f32 = sandScale * 0.5;
                var fineNoise: f32 = hash2(floor(pixelPos * fineScale));
                var fineSand: f32 = step(1.0 - sandDensity * 0.8, fineNoise);
                fineSand *= hash2(floor(pixelPos * fineScale) + vec2f(slowTime));
                
                // Combine sand layers
                var sandEffect: f32 = max(sandPattern * 0.7, fineSand * 0.4);
                
                return sandEffect;
            }

f32 colorNoise(uv: vec2f, time: f32) {
                var pixelPos: vec2f = uv * resolution;
                var slowTime: f32 = floor(time * temporalSpeed * 0.3);
                
                // Low frequency color variation
                var colorShift: f32 = hash2(floor(pixelPos * 0.05) + vec2f(slowTime));
                return (colorShift - 0.5) * colorVariation;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var baseColor: vec3f = textureSample(contentTexture, contentTextureSampler, uv).rgb;
                
                // Generate sand texture
                var sand: f32 = sandTexture(uv, uniforms.time);
                var colorShift: f32 = colorNoise(uv, uniforms.time);
                
                // Desert sand color palette (warm sandy tones)
                var sandColor: vec3f = vec3f(0.9, 0.85, 0.7); // Light sand
                var darkSandColor: vec3f = vec3f(0.7, 0.6, 0.45); // Darker sand
                
                // Mix sand colors with variation
                var sandTone: vec3f = mix(darkSandColor, sandColor, sand);
                
                // Apply color variation
                sandTone += colorShift;
                
                // Blend sand texture over base content
                var finalColor: vec3f = mix(baseColor, sandTone, sand * uniforms.sandIntensity);
                
                // Subtle overall warm tint
                finalColor = mix(finalColor, finalColor * vec3f(1.0, 0.98, 0.94), 0.1);
                
                return vec4f(finalColor, 1.0);
            }
`,
        uniforms: {
            // Sand grain controls
            sandScale: 1.0,              // Sand grain size (0.1-1.0, higher = smaller grains)
            sandDensity: 0.028,           // Coverage amount (0.0-0.5, higher = more sand visible)
            temporalSpeed: 0.0,          // How fast sand shifts (0.0-2.0)
            
            // Visual appearance
            colorVariation: 0.15,        // Color diversity (0.0-0.3)
            sandIntensity: 0.2           // Overall effect strength (0.0-1.0)
        }
    };
}