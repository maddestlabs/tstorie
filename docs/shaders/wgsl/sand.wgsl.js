// Zen Garden Sand Shader for tStorie
// Creates a subtle raked sand texture with very fine grain displacement

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
    grainStrength: f32,
    grainScale: f32,
    colorVariation: f32,
    displacementStrength: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 hash(p: vec2f) {
                return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453);
            }

f32 hash3(p: vec3f) {
                return fract(sin(dot(p, vec3f(127.1, 311.7, 74.7))) * 43758.5453);
            }

f32 noise(p: vec2f) {
                var i: vec2f = floor(p);
                var f: vec2f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                
                var a: f32 = hash(i);
                var b: f32 = hash(i + vec2f(1.0, 0.0));
                var c: f32 = hash(i + vec2f(0.0, 1.0));
                var d: f32 = hash(i + vec2f(1.0, 1.0));
                
                return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
            }

f32 noise3(p: vec3f) {
                var i: vec3f = floor(p);
                var f: vec3f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                
                return mix(
                    mix(mix(hash3(i), hash3(i + vec3f(1.0,0.0,0.0)), f.x),
                        mix(hash3(i + vec3f(0.0,1.0,0.0)), hash3(i + vec3f(1.0,1.0,0.0)), f.x), f.y),
                    mix(mix(hash3(i + vec3f(0.0,0.0,1.0)), hash3(i + vec3f(1.0,0.0,1.0)), f.x),
                        mix(hash3(i + vec3f(0.0,1.0,1.0)), hash3(i + vec3f(1.0,1.0,1.0)), f.x), f.y),
                    f.z
                );
            }

f32 fbm(p: vec2f, octaves: i32) {
                var value: f32 = 0.0;
                var amplitude: f32 = 0.5;
                var frequency: f32 = 1.0;
                
                for(var i: i32 = 0.0; i < 8.0; i++) {
                    if(i >= octaves) break;
                    value += amplitude * noise(p * frequency);
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }
                
                return value;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var screenPos: vec2f = uv * uniforms.resolution;
                
                // === SUBTLE DISPLACEMENT ===
                // Use low-frequency fbm for gentle organic displacement
                var displaceX: f32 = fbm(uv * uniforms.resolution * uniforms.grainScale * 0.3, 3.0);
                var displaceY: f32 = fbm(uv * uniforms.resolution * uniforms.grainScale * 0.3 + vec2f(100.0, 100.0), 3.0);
                
                var displacement: vec2f = vec2f(
                    (displaceX - 0.5),
                    (displaceY - 0.5)
                ) * uniforms.displacementStrength * 0.0004;
                
                var displacedUV: vec2f = uv + displacement;
                
                // === SAMPLE CONTENT ===
                var content: vec4f = textureSample(contentTexture, contentTextureSampler, displacedUV);
                
                // === PAPER-LIKE GRAIN TEXTURE ===
                // Similar to notebook.js paper noise approach
                var paperGrain: f32 = hash(screenPos * uniforms.grainScale * 2.0);
                
                // Add multi-scale noise for depth
                var mediumNoise: f32 = noise(screenPos * uniforms.grainScale * 0.5);
                var fineNoise: f32 = noise(screenPos * uniforms.grainScale * 4.0);
                
                // Combine layers for natural texture
                var grain: f32 = paperGrain * 0.5 + mediumNoise * 0.3 + fineNoise * 0.2;
                grain = (grain - 0.5) * uniforms.grainStrength;
                
                // === COLOR VARIATION ===
                // Subtle organic color shifts
                var colorShift: f32 = fbm(screenPos * 0.002, 3.0);
                var colorMod: f32 = (colorShift - 0.5) * uniforms.colorVariation;
                
                // === COMPOSE FINAL COLOR ===
                var finalColor: vec3f = content.rgb;
                
                // Apply grain texture
                finalColor += grain;
                
                // Apply subtle color variation
                finalColor += colorMod;
                
                // Very subtle warm sand tint overlay (barely perceptible)
                var sandTint: vec3f = vec3f(1.0, 0.98, 0.94);
                finalColor = mix(finalColor, finalColor * sandTint, 0.02);
                
                return vec4f(finalColor, 1.0);
            }
`,
        uniforms: {
            // Sand grain appearance
            grainStrength: 0.15,        // Overall grain visibility (0.0-1.0, higher = more visible)
            grainScale: 0.02,            // Grain detail scale (0.05-0.3, smaller = finer grain)
            
            // Color and atmosphere
            colorVariation: 0.15,       // Subtle color shifts across sand (0.0-0.2, higher = more variation)
            
            // Displacement for terminal content
            displacementStrength: 2.0   // Content displacement amount (0.0-3.0, higher = more distortion)
        }
    };
}
