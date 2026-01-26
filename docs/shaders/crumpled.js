// Linen Paper Texture Shader
// Soft diagonal woven texture for premium paper stock

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

            uniform float linenStrength;
            uniform float linenScale;
            uniform float linenSoftness;

            varying vec2 vUv;

            // Hash for subtle irregularity
            float hash(vec2 p) {
                p = fract(p * vec2(127.1, 311.7));
                p += dot(p, p + 34.5);
                return fract(p.x * p.y);
            }

            // Soft diagonal thread
            float thread(vec2 uv, vec2 dir, float scale) {
                float d = dot(uv, normalize(dir)) * scale;
                float wave = sin(d * 6.28318);
                return smoothstep(-linenSoftness, linenSoftness, wave);
            }

            void main() {
                vec2 uv = vUv;
                vec4 base = texture2D(contentTexture, uv);

                // Scale to paper space
                vec2 p = uv * linenScale;

                // Subtle irregularity so it doesn't look procedural
                float jitter = hash(floor(p * 0.5)) * 0.15;

                // Two diagonal weave directions
                float weaveA = thread(p + jitter, vec2(1.0, 1.0), 1.0);
                float weaveB = thread(p - jitter, vec2(-1.0, 1.0), 1.0);

                // Combine and soften
                float weave = mix(weaveA, weaveB, 0.5);
                weave = mix(0.5, weave, linenStrength);

                // Very gentle contrast shaping
                weave = pow(weave, 1.1);

                // Apply as luminance modulation
                vec3 color = base.rgb * weave;

                gl_FragColor = vec4(color, 1.0);
            }
        `,
        uniforms: {
            linenStrength: 0.18,   // VERY subtle (key to premium look)
            linenScale: 300.0,     // Thread density
            linenSoftness: 1.5     // How thick/soft the threads are
        }
    };
}
