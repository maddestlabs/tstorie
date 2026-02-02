// Film Scratches Shader for tStorie
// Simulates realistic analog film scratches with vertical orientation and subtle variation

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
    scratchDensity: f32,
    scratchWidth: f32,
    scratchIntensity: f32,
    scratchSpeed: f32,
    verticalVariation: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 hash(n: f32) {
                return fract(sin(n) * 43758.5453);
            }

f32 hash2(p: vec2f) {
                return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453);
            }

f32 noise(p: f32) {
                var i: f32 = floor(p);
                var f: f32 = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                return mix(hash(i), hash(i + 1.0), f);
            }

f32 verticalScratches(uv: vec2f, time: f32) {
                var scratches: f32 = 0.0;
                
                // Slow time progression for scratch persistence
                var timeSeed: f32 = floor(time * scratchSpeed);
                
                // Multiple scratch layers
                for(var i: f32 = 0.0; i < 6.0; i++) {
                    // Each scratch has a unique seed
                    var scratchId: f32 = i + timeSeed * 0.3;
                    var appear: f32 = hash(scratchId * 127.3);
                    
                    // Control scratch density
                    if(appear > scratchDensity) continue;
                    
                    // Random horizontal position
                    var xPos: f32 = hash(scratchId * 234.5);
                    
                    // Subtle horizontal drift using smooth noise
                    var drift: f32 = noise(uv.y * 8.0 + scratchId) * verticalVariation;
                    var scratchX: f32 = xPos + drift;
                    
                    // Distance from scratch center
                    var dist: f32 = abs(uv.x - scratchX);
                    
                    // Random width variation per scratch
                    var widthVar: f32 = hash(scratchId * 345.6) * 0.5 + 0.5;
                    var width: f32 = scratchWidth * widthVar;
                    
                    // Create scratch with soft falloff
                    var scratch: f32 = smoothstep(width, width * 0.3, dist);
                    
                    // Random intensity per scratch
                    var brightness: f32 = hash(scratchId * 456.7) * 0.6 + 0.4;
                    scratch *= brightness;
                    
                    // Vertical opacity variation (scratches fade in/out)
                    var fadePattern: f32 = noise(uv.y * 15.0 + scratchId * 10.0);
                    fadePattern = fadePattern * 0.4 + 0.6; // 60.0-100.0% opacity
                    scratch *= fadePattern;
                    
                    // Accumulate scratches (additive)
                    scratches += scratch;
                }
                
                return min(scratches, 1.0); // Clamp to prevent over-brightening
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var baseColor: vec3f = textureSample(contentTexture, contentTextureSampler, uv).rgb;
                
                // Generate defects
                var scratchEffect: f32 = verticalScratches(uv, uniforms.time);
                
                // Apply scratches (brighten - white/light scratches)
                var finalColor: vec3f = baseColor + scratchEffect * uniforms.scratchIntensity;

                return vec4f(finalColor, 1.0);
            }
`,
        uniforms: {
            // Scratch controls
            scratchDensity: 0.05,        // Number of scratches (0.0-1.0, higher = more scratches)
            scratchWidth: 0.0005,         // Base scratch thickness (0.001-0.01)
            scratchIntensity: 0.3,       // Scratch brightness (0.0-1.0)
            scratchSpeed: 3.0,           // How often scratches change (0.1-2.0)
            verticalVariation: 0.002,    // Subtle horizontal drift (0.0-0.01, higher = more wavy)
        }
    };
}