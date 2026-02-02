// Cyberpunk Glow Shader for TStorie (WebGL version)
// Heavy, saturated glow effect inspired by 80s cyberpunk aesthetics
// WebGL-compatible version (GLSL)

function getShaderConfig() {
    return {
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            
            void main() {
                vUv = position * 0.5 + 0.5;
                vUv.y = 1.0 - vUv.y;
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        fragmentShader: `
            precision highp float;
            
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            
            // Shader parameters
            uniform float glowIntensity;
            uniform float glowRadius;
            uniform float glowThreshold;
            uniform float saturationBoost;
            uniform float chromaticAberration;
            
            varying vec2 vUv;
            
            // High-quality luminance for glow extraction
            float luminance(vec3 color) {
                return dot(color, vec3(0.2126, 0.7152, 0.0722));
            }
            
            // Convert RGB to HSV for saturation manipulation
            vec3 rgb2hsv(vec3 c) {
                vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
                vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }
            
            // Convert HSV back to RGB
            vec3 hsv2rgb(vec3 c) {
                vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }
            
            // Boost color saturation for cyberpunk look
            vec3 saturateColor(vec3 color, float boost) {
                vec3 hsv = rgb2hsv(color);
                float newSaturation = clamp(hsv.y * boost, 0.0, 1.0);
                return hsv2rgb(vec3(hsv.x, newSaturation, hsv.z));
            }
            
            // Extract glow-worthy colors (bright + saturated)
            vec3 extractGlow(vec3 color) {
                float lum = luminance(color);
                vec3 hsv = rgb2hsv(color);
                
                // Threshold based on brightness
                float brightnessFactor = smoothstep(glowThreshold, glowThreshold + 0.2, lum);
                
                // Boost highly saturated colors even if not super bright
                float saturationFactor = hsv.y * 0.5;
                
                // Combine factors
                float glowFactor = clamp(brightnessFactor + saturationFactor, 0.0, 1.0);
                
                // Extra boost for very bright pixels
                float intensityBoost = 1.0 + max(0.0, lum - glowThreshold) * 3.0;
                
                return color * glowFactor * intensityBoost;
            }
            
            // Heavy glow with color enhancement
            vec3 heavyGlow(vec2 uv) {
                vec3 glow = vec3(0.0);
                vec2 texelSize = 1.0 / resolution;
                
                // Multiple octaves of glow at different scales
                float weights[5];
                weights[0] = 1.0;
                weights[1] = 0.8;
                weights[2] = 0.6;
                weights[3] = 0.4;
                weights[4] = 0.3;
                
                float scales[5];
                scales[0] = 1.0;
                scales[1] = 1.5;
                scales[2] = 2.2;
                scales[3] = 3.2;
                scales[4] = 4.5;
                
                for (int octave = 0; octave < 5; octave++) {
                    float scale = scales[octave];
                    float weight = weights[octave];
                    float radius = glowRadius * scale;
                    
                    // Fast 8-tap rotated grid per octave
                    float angleStep = 0.78539816339; // PI/4
                    int samples = 8;
                    vec3 octaveGlow = vec3(0.0);
                    
                    for (int i = 0; i < samples; i++) {
                        float angle = float(i) * angleStep;
                        vec2 offset = vec2(cos(angle), sin(angle)) * radius * texelSize * 0.8;
                        vec2 samplePos = uv + offset;
                        
                        if (samplePos.x >= 0.0 && samplePos.x <= 1.0 && 
                            samplePos.y >= 0.0 && samplePos.y <= 1.0) {
                            
                            vec3 sampleColor = texture2D(contentTexture, samplePos).rgb;
                            octaveGlow += extractGlow(sampleColor);
                        }
                    }
                    
                    octaveGlow /= float(samples);
                    glow += octaveGlow * weight;
                }
                
                return glow / 3.5; // Normalize
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample base color
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                // Calculate heavy cyberpunk glow
                vec3 glow = heavyGlow(uv);
                
                // Boost saturation of the glow
                if (saturationBoost > 1.0) {
                    glow = saturateColor(glow, saturationBoost);
                }
                
                // Optional: boost saturation of base image too for full cyberpunk effect
                if (saturationBoost > 1.5) {
                    baseColor = saturateColor(baseColor, 1.0 + (saturationBoost - 1.5) * 0.5);
                }
                
                // Combine with strong intensity
                vec3 finalColor = baseColor + glow * glowIntensity;
                
                // Optional subtle chromatic fringe on very bright areas
                if (chromaticAberration > 0.0) {
                    float brightnessMask = smoothstep(0.7, 1.0, luminance(finalColor));
                    if (brightnessMask > 0.0) {
                        float offset = chromaticAberration * 0.002;
                        vec2 texelSize = 1.0 / resolution;
                        
                        vec2 rOffset = uv + vec2(offset, 0.0) * texelSize * brightnessMask;
                        vec2 bOffset = uv - vec2(offset, 0.0) * texelSize * brightnessMask;
                        
                        float r = texture2D(contentTexture, rOffset).r;
                        float b = texture2D(contentTexture, bOffset).b;
                        
                        baseColor = vec3(r, baseColor.g, b);
                    }
                }
                
                gl_FragColor = vec4(finalColor, 1.0);
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
