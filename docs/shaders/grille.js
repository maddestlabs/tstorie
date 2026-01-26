// CRT Scanlines & Aperture Grille Shader for t|Storie
// Light approximation for retro aesthetics

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
            uniform float scanlineIntensity;
            uniform float scanlineSharpness;
            uniform float bloomAmount;
            uniform float phosphorSharpness;
            uniform float grilleBrightness;
            uniform float maskStrength;
            uniform float enableScanlines;
            uniform float enableApertureGrille;
            varying vec2 vUv;
            
            // Gaussian-like falloff for scanline glow
            float gaussianWeight(float x, float sigma) {
                return exp(-(x * x) / (2.0 * sigma * sigma));
            }
            
            // Aperture grille: vertical RGB stripes (Sony Trinitron style)
            vec3 apertureMask(vec2 pixelPos) {
                // Each pixel is divided into RGB subpixels
                float subpixel = mod(pixelPos.x, 3.0);
                
                vec3 mask = vec3(0.0);
                
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
                float sharpness = phosphorSharpness;
                mask = mix(vec3(1.0), mask, sharpness);
                
                // Normalize brightness
                mask *= grilleBrightness;
                
                return mask;
            }
            
            // Scanline with proper gaussian falloff
            float scanlineMask(float y, float scanlineHeight) {
                // Calculate position within current scanline (0.0 to 1.0)
                float linePos = mod(y, scanlineHeight) / scanlineHeight;
                
                // Center of scanline is at 0.5
                float distFromCenter = abs(linePos - 0.5) * 2.0;
                
                // Gaussian falloff from center of scanline
                float sigma = 0.5 / scanlineSharpness;
                float intensity = gaussianWeight(distFromCenter, sigma);
                
                // Mix between full brightness and the gap darkness
                return mix(scanlineIntensity, 1.0, intensity);
            }
            
            void main() {
                vec2 uv = vUv;
                vec2 pixelPos = uv * resolution;
                
                // Sample base color
                vec3 color = texture2D(contentTexture, uv).rgb;
                
                // Calculate brightness for bloom (bright areas bleed into gaps)
                float brightness = dot(color, vec3(0.299, 0.587, 0.114));
                
                // Apply aperture grille (vertical RGB stripes)
                if (enableApertureGrille > 0.5) {
                    vec3 mask = apertureMask(pixelPos);
                    
                    // Bright pixels can bleed through the mask more
                    float bleedThrough = mix(1.0, 1.5, brightness * bloomAmount);
                    mask *= bleedThrough;
                    
                    // Apply mask with controllable strength
                    color *= mix(vec3(1.0), mask, maskStrength);
                }
                
                // Apply scanlines (horizontal gaps between scan lines)
                if (enableScanlines > 0.5) {
                    // Scanline height depends on vertical resolution
                    float scanlineHeight = 2.0;
                    
                    float scanline = scanlineMask(pixelPos.y, scanlineHeight);
                    
                    // Bright areas reduce the visibility of scanline gaps (bloom)
                    float bloomFactor = mix(1.0, 0.3, brightness * bloomAmount);
                    scanline = mix(scanline, 1.0, bloomFactor);
                    
                    color *= scanline;
                }
                
                gl_FragColor = vec4(color, 1.0);
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