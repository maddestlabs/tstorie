// Cyberpunk Glow Shader for TStorie (WebGPU Optimized)
// Heavy, saturated glow effect inspired by 80s cyberpunk aesthetics
// Optimized for WebGPU with dual-pass separable blur and chromatic effects

function getShaderConfig() {
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
    glowIntensity: f32,
    glowRadius: f32,
    glowThreshold: f32,
    saturationBoost: f32,
    chromaticAberration: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

// High-quality luminance for glow extraction
fn luminance(color: vec3f) -> f32 {
    return dot(color, vec3f(0.2126, 0.7152, 0.0722));
}

// Convert RGB to HSV for saturation manipulation
fn rgb2hsv(c: vec3f) -> vec3f {
    let K = vec4f(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    let p = mix(vec4f(c.bg, K.wz), vec4f(c.gb, K.xy), step(c.b, c.g));
    let q = mix(vec4f(p.xyw, c.r), vec4f(c.r, p.yzx), step(p.x, c.r));
    let d = q.x - min(q.w, q.y);
    let e = 1.0e-10;
    return vec3f(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV back to RGB
fn hsv2rgb(c: vec3f) -> vec3f {
    let K = vec4f(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    let p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, vec3f(0.0), vec3f(1.0)), c.y);
}

// Boost color saturation for cyberpunk look
fn saturateColor(color: vec3f, boost: f32) -> vec3f {
    let hsv = rgb2hsv(color);
    let newSaturation = clamp(hsv.y * boost, 0.0, 1.0);
    return hsv2rgb(vec3f(hsv.x, newSaturation, hsv.z));
}

// Extract glow-worthy colors (bright + saturated)
fn extractGlow(color: vec3f) -> vec3f {
    let lum = luminance(color);
    let hsv = rgb2hsv(color);
    
    // Threshold based on brightness
    let brightnessFactor = smoothstep(uniforms.glowThreshold, uniforms.glowThreshold + 0.2, lum);
    
    // Boost highly saturated colors even if not super bright
    let saturationFactor = hsv.y * 0.5;
    
    // Combine factors
    let glowFactor = clamp(brightnessFactor + saturationFactor, 0.0, 1.0);
    
    // Extra boost for very bright pixels
    let intensityBoost = 1.0 + max(0.0, lum - uniforms.glowThreshold) * 3.0;
    
    return color * glowFactor * intensityBoost;
}

// Optimized separable Gaussian blur (horizontal or vertical)
fn gaussianBlur(uv: vec2f, direction: vec2f, radius: f32) -> vec3f {
    var result = vec3f(0.0);
    var totalWeight = 0.0;
    
    let texelSize = 1.0 / uniforms.resolution;
    let sigma = radius * 0.4;
    let samples = i32(min(radius * 0.6, 16.0));
    
    for (var i = -samples; i <= samples; i++) {
        let offset = f32(i) * direction * texelSize * 1.2;
        let samplePos = uv + offset;
        
        if (samplePos.x >= 0.0 && samplePos.x <= 1.0 && 
            samplePos.y >= 0.0 && samplePos.y <= 1.0) {
            
            let sampleColor = textureSample(contentTexture, contentTextureSampler, samplePos).rgb;
            let glowColor = extractGlow(sampleColor);
            
            // Gaussian weight
            let weight = exp(-(f32(i) * f32(i)) / (2.0 * sigma * sigma));
            
            result += glowColor * weight;
            totalWeight += weight;
        }
    }
    
    return result / totalWeight;
}

// Fast dual-direction blur with single-pass approximation
fn dualPassGlow(uv: vec2f) -> vec3f {
    // Horizontal blur samples
    let horizontal = gaussianBlur(uv, vec2f(1.0, 0.0), uniforms.glowRadius);
    
    // Vertical blur samples  
    let vertical = gaussianBlur(uv, vec2f(0.0, 1.0), uniforms.glowRadius);
    
    // Combine both directions
    return (horizontal + vertical) * 0.5;
}

// High-quality multi-pass glow with chromatic aberration
fn cyberpunkGlow(uv: vec2f) -> vec3f {
    var glow = vec3f(0.0);
    
    // Multi-scale glow (3 passes at different radii)
    let scale1 = dualPassGlow(uv);
    let scale2 = dualPassGlow(uv) * 0.7; // Slightly wider
    let scale3 = dualPassGlow(uv) * 0.5; // Widest spread
    
    glow = scale1 + scale2 * 0.6 + scale3 * 0.4;
    
    // Optional chromatic aberration for extra cyberpunk feel
    if (uniforms.chromaticAberration > 0.0) {
        let offset = uniforms.chromaticAberration * 0.003;
        let texelSize = 1.0 / uniforms.resolution;
        
        // Separate RGB channels slightly
        let r = gaussianBlur(uv + vec2f(offset, 0.0) * texelSize, vec2f(1.0, 0.0), uniforms.glowRadius * 0.8).r;
        let g = glow.g;
        let b = gaussianBlur(uv - vec2f(offset, 0.0) * texelSize, vec2f(1.0, 0.0), uniforms.glowRadius * 0.8).b;
        
        glow = vec3f(r, g, b);
    }
    
    return glow;
}

// Heavy glow with color enhancement
fn heavyGlow(uv: vec2f) -> vec3f {
    var glow = vec3f(0.0);
    let texelSize = 1.0 / uniforms.resolution;
    
    // Multiple octaves of glow at different scales
    let weights = array<f32, 5>(1.0, 0.8, 0.6, 0.4, 0.3);
    let scales = array<f32, 5>(1.0, 1.5, 2.2, 3.2, 4.5);
    
    for (var octave = 0; octave < 5; octave++) {
        let scale = scales[octave];
        let weight = weights[octave];
        let radius = uniforms.glowRadius * scale;
        
        // Fast 8-tap rotated grid per octave
        let angleStep = 0.78539816339; // PI/4
        let samples = 8;
        var octaveGlow = vec3f(0.0);
        
        for (var i = 0; i < samples; i++) {
            let angle = f32(i) * angleStep;
            let offset = vec2f(cos(angle), sin(angle)) * radius * texelSize * 0.8;
            let samplePos = uv + offset;
            
            // No bounds check needed - sampler uses clamp-to-edge addressing
            // This ensures uniform control flow for textureSample
            let sampleColor = textureSample(contentTexture, contentTextureSampler, samplePos).rgb;
            octaveGlow += extractGlow(sampleColor);
        }
        
        octaveGlow /= f32(samples);
        glow += octaveGlow * weight;
    }
    
    return glow / 3.5; // Normalize
}

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {
    let uv = vUv;
    
    // Sample base color
    var baseColor = textureSample(contentTexture, contentTextureSampler, uv).rgb;
    
    // Calculate heavy cyberpunk glow
    var glow = heavyGlow(uv);
    
    // Boost saturation of the glow
    if (uniforms.saturationBoost > 1.0) {
        glow = saturateColor(glow, uniforms.saturationBoost);
    }
    
    // Optional: boost saturation of base image too for full cyberpunk effect
    if (uniforms.saturationBoost > 1.5) {
        baseColor = saturateColor(baseColor, 1.0 + (uniforms.saturationBoost - 1.5) * 0.5);
    }
    
    // Combine with strong intensity
    var finalColor = baseColor + glow * uniforms.glowIntensity;
    
    // Optional chromatic aberration (no conditional sampling - always sample, mask result)
    if (uniforms.chromaticAberration > 0.0) {
        let brightnessMask = smoothstep(0.7, 1.0, luminance(finalColor));
        let offset = uniforms.chromaticAberration * 0.002;
        let texelSize = 1.0 / uniforms.resolution;
        
        let rOffset = uv + vec2f(offset, 0.0) * texelSize * brightnessMask;
        let bOffset = uv - vec2f(offset, 0.0) * texelSize * brightnessMask;
        
        // Always sample (uniform control flow), then blend based on mask
        let r = textureSample(contentTexture, contentTextureSampler, rOffset).r;
        let b = textureSample(contentTexture, contentTextureSampler, bOffset).b;
        
        // Blend chromatic aberration only where mask is active
        baseColor.r = mix(baseColor.r, r, brightnessMask);
        baseColor.b = mix(baseColor.b, b, brightnessMask);
        
        // Recalculate final color with chromatic aberration
        finalColor = baseColor + glow * uniforms.glowIntensity;
    }
    
    return vec4f(finalColor, 1.0);
}
`,
        
        uniforms: {
            glowIntensity: 1.2,         // Heavy glow (0.5-3.0)
            glowRadius: 18.0,           // Glow spread distance
            glowThreshold: 0.1,         // Lower = more things glow
            saturationBoost: 1.8,       // Cyberpunk color saturation (1.0-3.0)
            chromaticAberration: 1.5    // Color fringing effect (0.0-3.0)
        }
    };
}
