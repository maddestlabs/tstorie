// Movie Film Grain Shader for tStorie
// Simulates realistic analog film grain with temporal variation

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
    grainIntensity: f32,
    grainAdaptive: f32,
    temporalSpeed: f32,
    fineGrainFreq: f32,
    mediumGrainFreq: f32,
    coarseGrainFreq: f32,
    chromaticStrength: f32,
    vignetteStrength: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 hash(p: vec2f) {
                var p3: vec3f = fract(vec3f(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

f32 noise(p: vec2f) {
                var i: vec2f = floor(p);
                var f: vec2f = fract(p);
                
                // Smoother interpolation (quintic)
                var u: vec2f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
                
                var a: f32 = hash(i);
                var b: f32 = hash(i + vec2f(1.0, 0.0));
                var c: f32 = hash(i + vec2f(0.0, 1.0));
                var d: f32 = hash(i + vec2f(1.0, 1.0));
                
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

f32 filmGrain(uv: vec2f, time: f32) {
                var grain: f32 = 0.0;
                
                // Fine grain (base layer)
                grain += noise(uv * fineGrainFreq + time * 5.0) * 0.5;
                
                // Medium grain (adds texture)
                grain += noise(uv * mediumGrainFreq + time * 3.0) * 0.3;
                
                // Coarse grain (analog film characteristic)
                grain += noise(uv * coarseGrainFreq + time * 1.5) * 0.2;
                
                return grain;
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                var pixelCoord: vec2f = uv * uniforms.resolution;
                
                // Sample the content texture
                var color: vec4f = textureSample(contentTexture, contentTextureSampler, uv);
                
                // Generate grain with temporal variation
                var t: f32 = uniforms.time * uniforms.temporalSpeed;
                
                // Separate grain channels for chromatic aberration effect
                var grainR: f32 = filmGrain(pixelCoord + vec2f(0.0, 0.0), t);
                var grainG: f32 = filmGrain(pixelCoord + vec2f(7.3, 13.1), t + 0.33);
                var grainB: f32 = filmGrain(pixelCoord + vec2f(15.7, 3.9), t + 0.67);
                
                // Luminance grain (affects all channels equally)
                var grainL: f32 = filmGrain(pixelCoord + vec2f(23.4, 31.2), t);
                
                // Scale grain based on image luminance (darker = more visible grain)
                var luminance: f32 = dot(color.rgb, vec3f(0.299, 0.587, 0.114));
                var adaptiveGrain: f32 = uniforms.grainIntensity + (1.0 - luminance) * uniforms.grainAdaptive;
                
                // Apply chromatic and luminance grain
                var grain: vec3f = vec3f(grainR, grainG, grainB) - 0.5;
                grain = grain * adaptiveGrain * uniforms.chromaticStrength;
                
                // Add luminance grain
                grain += (grainL - 0.5) * adaptiveGrain;
                
                // Composite grain with original color
                var finalColor: vec3f = color.rgb + grain;
                
                // Optional: Add subtle vignette to enhance film look
                var vignetteUV: vec2f = uv * 2.0 - 1.0;
                var vignette: f32 = 1.0 - dot(vignetteUV, vignetteUV) * uniforms.vignetteStrength;
                finalColor *= vignette;
                
                return vec4f(finalColor, color.a);
            }
`,
        uniforms: {
            // Grain intensity
            grainIntensity: 0.07,        // Base grain intensity (0.0-0.1, higher = more visible grain)
            grainAdaptive: 0.02,         // Additional grain in dark areas (0.0-0.1, higher = more visible in shadows)
            
            // Temporal animation
            temporalSpeed: 0.5,          // Animation speed (0.0-2.0, higher = faster grain movement)
            
            // Grain frequencies
            fineGrainFreq: 800.0,        // Fine grain scale (200.0-1200.0, higher = smaller grain)
            mediumGrainFreq: 400.0,      // Medium grain scale (100.0-600.0, higher = smaller grain)
            coarseGrainFreq: 150.0,      // Coarse grain scale (50.0-300.0, higher = smaller grain)
            
            // Color and atmosphere
            chromaticStrength: 0.7,      // Color separation strength (0.0-1.0, higher = more chromatic aberration)
            vignetteStrength: 0.35       // Edge darkening (0.0-0.5, higher = darker edges)
        }
    };
}