// Crumpled Paper Shader for t|Storie
// Creates convincing paper texture with noise and creases

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
                output.vUv.y = 1.0 - output.vUv.y;  // Flip vertically
                output.position = vec4f(position, 0.0, 1.0);
                return output;
}
`,
        
        fragmentShader: `@group(0) @binding(0) var contentTexture: texture_2d<f32>;
@group(0) @binding(1) var contentTextureSampler: sampler;

struct Uniforms {
    time: f32,
    resolution: vec2f,
    noiseScale: f32,
    noiseBrightness: f32,
    noiseSeed: vec2f,
    noiseFrequency: vec2f,
    creaseSharpness: f32,
    creaseDarkness: f32,
    textureDistortion: f32,
    paperTint: vec3f,
    paperBlend: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 cheapNoise(uv: vec2f, scale: f32, seed: vec2f, uvScale: vec2f) {
                var noise: f32 = 0.0;
                noise += (cos(uv.x * uvScale.x + seed.x) + 1.0) * scale;
                noise += (cos(uv.y * uvScale.y + seed.y) + 1.0) * scale * 1.5;
                
                // Center dampening - paper is flatter in middle
                var centerRadius: f32 = length((uv - 0.5) * 2.0);
                noise *= centerRadius;
                
                return noise;
            }

f32 creaseLine(uv: vec2f, lineData: vec4f) {
                // lineData: (slope, intercept, strength, sign)
                // Line formula: y = slope * x + intercept
                var lineDist: f32 = uv.x * lineData.x + lineData.y - uv.y;
                return lineDist;
            }

f32 random(st: vec2f) {
                return fract(sin(dot(st.xy, vec2f(12.9898, 78.233))) * 43758.5453123);
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Apply cheap noise for background paper texture
                var paperNoise: f32 = cheapNoise(uv, uniforms.noiseScale, uniforms.noiseSeed, uniforms.noiseFrequency);
                
                // Define 4.0 main crease lines (slope, intercept, strength, sign)
                var crease1: vec4f = vec4f(-0.4, 0.2, 3.2, 1.0);
                var crease2: vec4f = vec4f(0.7, -0.5, 0.7, 1.0);
                var crease3: vec4f = vec4f(-1.0, 1.2, 0.9, -1.0);
                var crease4: vec4f = vec4f(1.4, 0.6, 1.2, -1.0);
                
                // Add 2.0 shorter, random crease lines (about 1.0/4.0 length, less dominant)
                // Using pseudo-random values based on seed for consistency
                var r1: f32 = random(uniforms.noiseSeed);
                var r2: f32 = random(uniforms.noiseSeed + vec2f(1.0, 0.0));
                var r3: f32 = random(uniforms.noiseSeed + vec2f(0.0, 1.0));
                var r4: f32 = random(uniforms.noiseSeed + vec2f(1.0, 1.0));
                
                // Shorter creases with random positioning
                var crease5: vec4f = vec4f(
                    mix(-0.5, 0.5, r1),           // Random slope
                    mix(0.3, 0.7, r2),            // Random intercept
                    0.5,                           // Lower strength (1.0/4.0 of main)
                    sign(r3 - 0.5)                 // Random sign
                );
                var crease6: vec4f = vec4f(
                    mix(-0.6, 0.6, r4),
                    mix(0.2, 0.8, r1),
                    0.4,
                    sign(r2 - 0.5)
                );
                
                // Calculate distance to each crease line
                var dist1: f32 = creaseLine(uv, crease1);
                var dist2: f32 = creaseLine(uv, crease2);
                var dist3: f32 = creaseLine(uv, crease3);
                var dist4: f32 = creaseLine(uv, crease4);
                var dist5: f32 = creaseLine(uv, crease5);
                var dist6: f32 = creaseLine(uv, crease6);
                
                // Create distortion field from noise and creases
                var distortion: vec2f = vec2f(0.0);
                
                // Add noise-based distortion
                distortion.x += paperNoise * 0.5;
                distortion.y += cheapNoise(uv + vec2f(0.5), uniforms.noiseScale, uniforms.noiseSeed + vec2f(3.7, 1.2), uniforms.noiseFrequency) * 0.5;
                
                // Add crease-based distortion (perpendicular to crease lines)
                distortion += vec2f(-crease1.x, 1.0) * (1.0 - clamp(abs(dist1) * 20.0, 0.0, 1.0)) * 0.3;
                distortion += vec2f(-crease2.x, 1.0) * (1.0 - clamp(abs(dist2) * 20.0, 0.0, 1.0)) * 0.2;
                distortion += vec2f(-crease3.x, 1.0) * (1.0 - clamp(abs(dist3) * 20.0, 0.0, 1.0)) * 0.25;
                distortion += vec2f(-crease4.x, 1.0) * (1.0 - clamp(abs(dist4) * 20.0, 0.0, 1.0)) * 0.3;
                
                // Smaller distortion from shorter creases
                distortion += vec2f(-crease5.x, 1.0) * (1.0 - clamp(abs(dist5) * 30.0, 0.0, 1.0)) * 0.1;
                distortion += vec2f(-crease6.x, 1.0) * (1.0 - clamp(abs(dist6) * 30.0, 0.0, 1.0)) * 0.08;
                
                // Apply texture distortion (scaled by blend amount)
                var distortedUv: vec2f = uv + distortion * uniforms.textureDistortion * uniforms.paperBlend;
                
                // Sample the terminal texture ONCE with distorted coordinates
                var color: vec4f = textureSample(contentTexture, contentTextureSampler, distortedUv);
                
                // Add subtle brightness variation from noise (scaled by blend)
                color.rgb += (paperNoise + uniforms.noiseBrightness) * uniforms.paperBlend;
                
                // Create darkening along creases
                var creaseDarkening: f32 = 0.0;
                creaseDarkening += clamp(abs(dist1) * uniforms.creaseSharpness, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist2) * uniforms.creaseSharpness, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist3) * uniforms.creaseSharpness, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist4) * uniforms.creaseSharpness, 0.0, 1.0);
                
                // Shorter creases are less dominant in darkening
                creaseDarkening += clamp(abs(dist5) * uniforms.creaseSharpness * 0.6, 0.0, 1.0);
                creaseDarkening += clamp(abs(dist6) * uniforms.creaseSharpness * 0.5, 0.0, 1.0);
                
                creaseDarkening /= 6.0;  // Average the six distances
                
                // Apply darkening along creases (interpolate between no darkening and full darkening)
                var creaseFactor: f32 = mix(1.0, creaseDarkening * uniforms.creaseDarkness + (1.0 - uniforms.creaseDarkness), uniforms.paperBlend);
                color.rgb *= creaseFactor;
                
                // Add slight paper color tint (interpolate between white and tint)
                color.rgb *= mix(vec3f(1.0), uniforms.paperTint, uniforms.paperBlend);
                
                return color;
            }
`,
        
        uniforms: {
            // Noise parameters
            noiseScale: 0.35,
            noiseBrightness: -0.6,
            noiseSeed: [1.5, 2.3],
            noiseFrequency: [8.0, 10.0],
            
            // Crease parameters
            creaseSharpness: 50.0,
            creaseDarkness: 0.64,
            
            // Distortion parameter
            textureDistortion: 0.01,
            
            // Paper tint
            paperTint: [0.75, 0.75, 0.75],
            
            // Blend control
            paperBlend: 0.27  // 0.0 = no effect, 1.0 = full paper effect
        }
    };
}