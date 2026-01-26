// Combined Paper + Dirt Stain + Linen Texture Shader
// Premium paper texture with grain, dirt stains, and woven linen pattern

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
            uniform vec2 resolution;

            // Paper grain controls
            uniform float paperNoise;
            uniform float noiseIntensity;
            uniform float noiseMix;

            // Dirt stain controls
            uniform float dirtAmount;
            uniform float dirtScale;
            uniform float dirtContrast;
            uniform vec3 dirtColor;

            // Linen texture controls
            uniform float linenStrength;
            uniform float linenScale;
            uniform float linenSoftness;

            varying vec2 vUv;

            // ------------------------------------------------------------
            // Simplex noise for dirt stains
            // ------------------------------------------------------------

            vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
            vec4 taylorInvSqrt(vec4 r) {
                return 1.79284291400159 - 0.85373472095314 * r;
            }

            float snoise(vec3 v) {
                const vec2 C = vec2(1.0/6.0, 1.0/3.0);
                const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

                vec3 i  = floor(v + dot(v, C.yyy));
                vec3 x0 = v - i + dot(i, C.xxx);

                vec3 g = step(x0.yzx, x0.xyz);
                vec3 l = 1.0 - g;
                vec3 i1 = min(g.xyz, l.zxy);
                vec3 i2 = max(g.xyz, l.zxy);

                vec3 x1 = x0 - i1 + C.xxx;
                vec3 x2 = x0 - i2 + C.yyy;
                vec3 x3 = x0 - D.yyy;

                i = mod289(i);
                vec4 p = permute(permute(permute(
                         i.z + vec4(0.0, i1.z, i2.z, 1.0))
                         + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                         + i.x + vec4(0.0, i1.x, i2.x, 1.0));

                float n_ = 0.142857142857;
                vec3 ns = n_ * D.wyz - D.xzx;

                vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

                vec4 x_ = floor(j * ns.z);
                vec4 y_ = floor(j - 7.0 * x_);

                vec4 x = x_ * ns.x + ns.yyyy;
                vec4 y = y_ * ns.x + ns.yyyy;
                vec4 h = 1.0 - abs(x) - abs(y);

                vec4 b0 = vec4(x.xy, y.xy);
                vec4 b1 = vec4(x.zw, y.zw);

                vec4 s0 = floor(b0)*2.0 + 1.0;
                vec4 s1 = floor(b1)*2.0 + 1.0;
                vec4 sh = -step(h, vec4(0.0));

                vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
                vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

                vec3 p0 = vec3(a0.xy, h.x);
                vec3 p1 = vec3(a0.zw, h.y);
                vec3 p2 = vec3(a1.xy, h.z);
                vec3 p3 = vec3(a1.zw, h.w);

                vec4 norm = taylorInvSqrt(vec4(
                    dot(p0,p0), dot(p1,p1),
                    dot(p2,p2), dot(p3,p3)
                ));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;

                vec4 m = max(
                    0.6 - vec4(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2),
                        dot(x3,x3)
                    ),
                    0.0
                );
                m = m * m;

                return 42.0 * dot(m*m, vec4(
                    dot(p0,x0),
                    dot(p1,x1),
                    dot(p2,x2),
                    dot(p3,x3)
                ));
            }

            // ------------------------------------------------------------
            // Hash noise for paper grain and linen irregularity
            // ------------------------------------------------------------

            float hash(vec2 p) {
                vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yxz + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }

            // ------------------------------------------------------------
            // Linen thread pattern
            // ------------------------------------------------------------

            float thread(vec2 uv, vec2 dir, float scale) {
                float d = dot(uv, normalize(dir)) * scale;
                float wave = sin(d * 6.28318);
                return smoothstep(-linenSoftness, linenSoftness, wave);
            }

            void main() {
                vec2 uv = vUv;
                vec4 baseColor = texture2D(contentTexture, uv);

                // --------------------------------------------------------
                // 1. Start with base content
                // --------------------------------------------------------
                vec3 color = baseColor.rgb;

                // --------------------------------------------------------
                // 2. Apply paper grain
                // --------------------------------------------------------
                if (paperNoise > 0.0) {
                    vec2 screenPos = uv * resolution;
                    float grain = hash(screenPos) * noiseIntensity;
                    color = mix(color, vec3(1.0) * grain, noiseMix * paperNoise);
                }

                // --------------------------------------------------------
                // 3. Apply dirt stains
                // --------------------------------------------------------
                vec2 p = (uv - 0.5) * dirtScale;

                float dirt = 0.0;
                dirt += snoise(vec3(p * 1.5, 1.0)) * 0.6;
                dirt += snoise(vec3(p * 3.0, 2.0)) * 0.3;
                dirt += snoise(vec3(p * 6.0, 3.0)) * 0.1;

                dirt = dirt * 0.5 + 0.5;
                dirt = pow(dirt, dirtContrast);

                float mask = smoothstep(0.45, 0.75, dirt) * dirtAmount;
                color = mix(color, dirtColor, mask);

                // --------------------------------------------------------
                // 4. Apply linen weave texture
                // --------------------------------------------------------
                vec2 linenP = uv * linenScale;
                
                // Subtle irregularity for natural look
                float jitter = hash(floor(linenP * 0.5)) * 0.15;

                // Two diagonal weave directions
                float weaveA = thread(linenP + jitter, vec2(1.0, 1.0), 1.0);
                float weaveB = thread(linenP - jitter, vec2(-1.0, 1.0), 1.0);

                // Combine and soften
                float weave = mix(weaveA, weaveB, 0.5);
                weave = mix(0.5, weave, linenStrength);

                // Gentle contrast shaping
                weave = pow(weave, 1.1);

                // Apply as luminance modulation
                color = color * weave;

                gl_FragColor = vec4(color, 1.0);
            }
        `,
        uniforms: {
            // Paper grain
            paperNoise: 0.4,
            noiseIntensity: 0.18,
            noiseMix: 0.64,

            // Dirt stains
            dirtAmount: 0.15,
            dirtScale: 0.97,
            dirtContrast: 0.96,
            dirtColor: [0.95, 0.98, 0.92], // warm dirt / sepia

            // Linen texture
            linenStrength: 0.18,   // Very subtle for premium look
            linenScale: 300.0,     // Thread density
            linenSoftness: 3.5     // Thread thickness/softness
        }
    };
}