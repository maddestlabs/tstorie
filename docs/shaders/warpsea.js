// Water Distortion Shader for tStorie
// Creates realistic water ripple effects with caustic highlights

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
            uniform float distortionStrength;
            uniform float causticIntensity;
            uniform float causticScale;
            uniform float waterSpeed;
            uniform float waveDensity;
            varying vec2 vUv;

            #define TAU 6.28318530718

            // Optimized water caustics without loops
            vec3 waterCaustics(vec2 uv, float time) {
                vec2 p = mod(uv * TAU * waveDensity, TAU) - 250.0;
                vec2 i = p;
                
                float t = time * waterSpeed;
                float c = 0.0;
                float inten = 0.005;
                
                // Unrolled loop - 3 iterations for performance
                // Iteration 1
                float t1 = t * (1.0 - (3.5 / 1.0));
                i = p + vec2(cos(t1 - i.x) + sin(t1 + i.y), sin(t1 - i.y) + cos(t1 + i.x));
                c += 1.0 / length(vec2(p.x / (sin(i.x + t1) / inten), p.y / (cos(i.y + t1) / inten)));
                
                // Iteration 2
                float t2 = t * (1.0 - (3.5 / 2.0));
                i = p + vec2(cos(t2 - i.x) + sin(t2 + i.y), sin(t2 - i.y) + cos(t2 + i.x));
                c += 1.0 / length(vec2(p.x / (sin(i.x + t2) / inten), p.y / (cos(i.y + t2) / inten)));
                
                // Iteration 3
                float t3 = t * (1.0 - (3.5 / 3.0));
                i = p + vec2(cos(t3 - i.x) + sin(t3 + i.y), sin(t3 - i.y) + cos(t3 + i.x));
                c += 1.0 / length(vec2(p.x / (sin(i.x + t3) / inten), p.y / (cos(i.y + t3) / inten)));
                
                // Normalize and enhance
                c /= 3.0;
                c = 1.17 - pow(c, 1.4);
                
                // Create water-colored caustics
                vec3 colour = vec3(pow(abs(c), 8.0));
                colour = clamp(colour + vec3(0.0, 0.35, 0.5), 0.0, 1.0);
                
                return colour;
            }

            // Generate water distortion offset
            vec2 waterDistortion(vec2 uv, float time) {
                float t = time * waterSpeed * 0.5;
                
                // Multiple wave layers for realistic movement
                vec2 wave1 = vec2(
                    sin(uv.y * 10.0 + t) * cos(uv.x * 8.0 + t * 0.7),
                    cos(uv.x * 12.0 + t * 0.8) * sin(uv.y * 9.0 + t * 0.6)
                );
                
                vec2 wave2 = vec2(
                    cos(uv.y * 7.0 - t * 1.2) * sin(uv.x * 11.0 - t * 0.9),
                    sin(uv.x * 8.0 - t * 1.1) * cos(uv.y * 6.0 - t * 0.7)
                );
                
                return (wave1 + wave2 * 0.5) * distortionStrength * 0.01;
            }

            void main() {
                vec2 uv = vUv;
                
                // Apply water distortion to texture coordinates
                vec2 distortion = waterDistortion(uv, time);
                vec2 distortedUV = uv + distortion;
                
                // Sample distorted texture
                vec3 baseColor = texture2D(contentTexture, distortedUV).rgb;
                
                // Generate caustic pattern
                vec3 caustics = waterCaustics(uv * causticScale, time);
                
                // Blend caustics with base color using multiply blend
                // This darkens the base and adds bright caustic highlights
                vec3 finalColor = mix(
                    baseColor,
                    baseColor * (1.0 + caustics * causticIntensity),
                    0.6
                );
                
                // Add subtle blue-green water tint
                finalColor = mix(finalColor, finalColor * vec3(0.9, 1.0, 1.05), 0.15);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Distortion controls
            distortionStrength: 1.0,     // Wave distortion amount (0.0-5.0, higher = more wavy)
            
            // Caustic controls
            causticIntensity: 1.0,       // Brightness of water highlights (0.0-2.0)
            causticScale: 0.85,           // Caustic pattern size (0.5-3.0, higher = smaller patterns)
            
            // Animation controls
            waterSpeed: 0.01,             // Overall animation speed (0.1-2.0)
            waveDensity: 0.5             // Wave pattern density (0.5-2.0)
        }
    };
}