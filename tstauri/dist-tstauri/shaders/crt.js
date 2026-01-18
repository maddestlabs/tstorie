// Apocalypse CRT Shader for tStorie
// Ported from apocalypse-crt.hlsl (MaddestLabs)

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
            uniform float frameSize;
            uniform float frameHue;
            uniform float frameSat;
            uniform float frameLight;
            uniform float frameReflect;
            uniform float frameGrain;
            uniform float borderSize;
            uniform float borderHue;
            uniform float borderSat;
            uniform float borderLight;
            varying vec2 vUv;

            float random(vec2 c) {
                return fract(sin(dot(c.xy, vec2(12.9898,78.233))) * 43758.5453);
            }

            vec3 hsl2rgb(vec3 c) {
                vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }

            vec3 rgbDistortion(vec2 uv, float offset) {
                vec3 color;
                color.r = texture2D(contentTexture, uv + vec2(offset, 0.0)).r;
                color.g = texture2D(contentTexture, uv).g;
                color.b = texture2D(contentTexture, uv - vec2(offset, 0.0)).b;
                return color;
            }

            void main() {
                float iTime = time;
                vec2 iResolution = resolution;
                vec2 uv = vUv;
                vec2 center = vec2(0.5, 0.5);
                float distanceFromCenter = length(uv - center);
                float px = 1.0 / iResolution.x;
                float border = borderSize * px;
                float frame = frameSize * px;
                float alpha = 1.0;

                vec3 bColor = hsl2rgb(vec3(borderHue, borderSat, borderLight));
                // CRT Curvature (applies to all)
                uv = vUv + (vUv - center) * pow(distanceFromCenter, 5.0) * curveStrength;

                // Frame region is at the canvas edge
                bool isFrame = (uv.x < frame || uv.x > (1.0 - frame) || uv.y < frame || uv.y > (1.0 - frame));
                // Border is inner padding between frame and CRT content
                bool isBorder = (!isFrame) && (uv.x < frame + border || uv.x > (1.0 - frame - border) || uv.y < frame + border || uv.y > (1.0 - frame - border));
                // CRT content region
                vec2 contentUV = (uv - vec2(frame + border, frame + border)) / (1.0 - 2.0 * (frame + border));
                vec3 color;

                if (isFrame) {
                    float frameVal = 100.0;
                    float nX = frameVal / iResolution.x;
                    float nY = frameVal / iResolution.y;
                    float intensity = 0.0;
                    float distX = min(uv.x, 1.0-uv.x);
                    float distY = min(uv.y, 1.0-uv.y);
                    float minDist = min(distX, distY);
                    intensity = mix(frameLight, 0.0, minDist / max(nX, nY) * 4.0);
                    color = hsl2rgb(vec3(frameHue, frameSat, intensity));
                    color *= 1.0 - frameGrain * random(uv);
                    // Reflection: mirror, curve, and blur
                    vec2 f = border * vec2(1.0) / iResolution.xy;
                    vec2 reflectedUV = contentUV;
                    if (reflectedUV.x < f.x) reflectedUV.x = f.x - (reflectedUV.x - f.x);
                    else if (reflectedUV.x > 1.0 - f.x) reflectedUV.x = 1.0 - f.x - (reflectedUV.x - (1.0 - f.x));
                    if (reflectedUV.y < f.y) reflectedUV.y = f.y - (reflectedUV.y - f.y);
                    else if (reflectedUV.y > 1.0 - f.y) reflectedUV.y = 1.0 - f.y - (reflectedUV.y - (1.0 - f.y));
                    vec2 reflCenter = vec2(0.5, 0.5);
                    float reflDistFromCenter = length(reflectedUV - reflCenter);
                    // Simple blur
                    vec3 blurred = vec3(0.0);
                    float blur = 2.0 / iResolution.x;
                    float frameBlur = 1.0;
                    for (int x = -1; x <= 1; x++) {
                        for (int y = -1; y <= 1; y++) {
                            vec2 blurPos = reflectedUV + vec2(float(x) * blur, float(y) * blur);
                            blurred += rgbDistortion(blurPos, 0.0005);
                        }
                    }
                    blurred /= 9.0;
                    color += blurred * frameReflect * 0.5;
                    // Light source
                    float lightX = 0.5 + sin(iTime * 1.75) * 0.35;
                    vec2 lightPos = vec2(lightX, 0.2);
                    float lightDist = length(uv - lightPos);
                    float lightFalloff = pow(clamp(1.0 - (lightDist / 1.5), 0.0, 1.0), 0.85);
                    color *= mix(0.25, 2.5, lightFalloff);
                } else if (isBorder) {
                    color = bColor;
                } else {
                    // Horizontal sync wave effect
                    float cyclePeriod = 2.0;
                    float randomOffset = fract(sin(floor(iTime / cyclePeriod) * 12345.67) * 43758.5453);
                    float actualCyclePeriod = cyclePeriod + randomOffset;
                    float cyclePosition = fract(iTime / actualCyclePeriod);
                    float waveDuration = 0.15;
                    float waveStrength = 0.0;
                    if (cyclePosition < waveDuration) {
                        float normalizedTime = cyclePosition / waveDuration;
                        waveStrength = sin(normalizedTime * 3.14159) * hSync * 0.1;
                    }
                    float hWave = sin(contentUV.y * 10.0 + iTime * 5.0) * waveStrength;
                    contentUV.x += hWave;
                    if (contentUV.x < 0.0 || contentUV.x > 1.0 || contentUV.y < 0.0 || contentUV.y > 1.0) {
                        color = bColor;
                    } else {
                        color = rgbDistortion(contentUV, rgbOffset);
                        if (grilleLvl > 0.0) {
                            float grillePattern = sin(contentUV.x * grilleDensity * 3.14159);
                            grillePattern = grilleLvl + (1.0 - grilleLvl) * grillePattern;
                            color *= (0.5 + 0.5 * grillePattern);
                        }
                        if (scanlineLvl > 0.05) {
                            float scanlinePattern = sin(contentUV.y * iResolution.y * 3.14159 / scanlines);
                            color *= (scanlineLvl + (1.0 - scanlineLvl) * scanlinePattern);
                        }
                        if (noiseLevel > 0.0) {
                            float noise = random(contentUV + iTime);
                            color += vec3(noise * noiseLevel * 0.5);
                        }
                        if (flicker > 0.0) {
                            float f = 1.0 + 0.25 * sin(iTime * 60.0) * flicker;
                            color *= f;
                        }
                    }
                    // Vignette (applies to CRT content only)
                    contentUV *= (1.0 - contentUV.yx);
                    color *= pow(contentUV.x * contentUV.y * vignetteLvl, vignetteStart);
                }

                gl_FragColor = vec4(color, alpha);
            }
        `,
        uniforms: {
            grilleLvl: 0.95,
            grilleDensity: 800.0,
            scanlineLvl: 0.8,
            scanlines: 2.0,
            rgbOffset: 0.001,
            noiseLevel: 0.025,
            flicker: 0.1,
            hSync: 0.01,
            vignetteStart: 0.25,
            vignetteLvl: 40.0,
            curveStrength: 0.95,
            frameSize: 20.0,
            frameHue: 0.025,
            frameSat: 0.0,
            frameLight: 0.01,
            frameReflect: 0.15,
            frameGrain: 0.25,
            borderSize: 2.0,
            borderHue: 0.0,
            borderSat: 0.0,
            borderLight: 0.0
        }
    };
}
