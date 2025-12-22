// Apocalypse CRT Shader for TStorie
// Upload this to a GitHub Gist and use: ?shader=YOUR_GIST_ID
// Based on MaddestLabs CRT shader

function getShaderConfig() {
    return {
        vertexShader: `
            attribute vec2 position;
            varying vec2 vUv;
            
            void main() {
                vUv = position * 0.5 + 0.5;
                vUv.y = 1.0 - vUv.y;  // Flip vertically
                gl_Position = vec4(position, 0.0, 1.0);
            }
        `,
        
        fragmentShader: `
            precision mediump float;
            
            uniform sampler2D contentTexture;
            uniform float time;
            uniform vec2 resolution;
            
            // CRT Parameters
            uniform float grilleLvl;
            uniform float grilleDensity;
            uniform float scanlineLvl;
            uniform float scanlines;
            uniform float rgbOffset;
            uniform float noiseLevel;
            uniform float flicker;
            uniform float hSync;
            uniform float vignetteStart;
            uniform float vignetteLvl;
            uniform float curveStrength;
            
            varying vec2 vUv;
            
            float random(vec2 co) {
                return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
            }
            
            vec3 rgbDistortion(vec2 uv, float offset) {
                vec3 color;
                color.r = texture2D(contentTexture, uv + vec2(offset, 0.0)).r;
                color.g = texture2D(contentTexture, uv).g;
                color.b = texture2D(contentTexture, uv - vec2(offset, 0.0)).b;
                return color;
            }
            
            void main() {
                vec2 uv = vUv;
                vec2 center = vec2(0.5, 0.5);
                
                // CRT Curvature
                float distanceFromCenter = length(uv - center);
                uv += (uv - center) * pow(distanceFromCenter, 5.0) * curveStrength;
                
                // Check bounds
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
                    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                    return;
                }
                
                // Horizontal sync wave effect
                float cyclePosition = fract(time / 2.0);
                float waveStrength = 0.0;
                
                if (cyclePosition < 0.15) {
                    float normalizedTime = cyclePosition / 0.15;
                    waveStrength = sin(normalizedTime * 3.14159) * hSync * 0.1;
                }
                
                float hWave = sin(uv.y * 10.0 + time * 5.0) * waveStrength;
                uv.x += hWave;
                
                // RGB chromatic aberration
                vec3 color = rgbDistortion(uv, rgbOffset);
                
                // Aperture Grille
                if (grilleLvl > 0.0) {
                    float grillePattern = sin(uv.x * grilleDensity * 3.14159);
                    grillePattern = grilleLvl + (1.0 - grilleLvl) * grillePattern;
                    color *= (0.5 + 0.5 * grillePattern);
                }
                
                // Scanlines
                if (scanlineLvl > 0.05) {
                    float scanlinePattern = sin(uv.y * resolution.y * 3.14159 / scanlines);
                    color *= (scanlineLvl + (1.0 - scanlineLvl) * scanlinePattern);
                }
                
                // Noise
                if (noiseLevel > 0.0) {
                    float noise = random(uv + time);
                    color += vec3(noise * noiseLevel * 0.5);
                }
                
                // Flicker
                if (flicker > 0.0) {
                    float f = 1.0 + 0.25 * sin(time * 60.0) * flicker;
                    color *= f;
                }
                
                // Vignette
                vec2 vigUv = uv;
                vigUv *= (1.0 - vigUv.yx);
                color *= pow(vigUv.x * vigUv.y * vignetteLvl, vignetteStart);
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            grilleLvl: 0.95,
            grilleDensity: 800.0,
            scanlineLvl: 0.8,
            scanlines: 2.0,
            rgbOffset: 0.001,
            noiseLevel: 0.1,
            flicker: 0.15,
            hSync: 0.01,
            vignetteStart: 0.25,
            vignetteLvl: 20.0,
            curveStrength: 0.95
        }
    };
}
