// Film Scratches Shader for tStorie
// Simulates realistic analog film scratches using Bezier curves

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
            uniform float scratchInterval;
            uniform float scratchLifetime;
            uniform float minAlpha;
            uniform float maxAlpha;
            uniform float minLength;
            uniform float maxLength;
            uniform float straightness;
            uniform float noisiness;
            uniform float minWidth;
            uniform float maxWidth;
            varying vec2 vUv;

            // Bezier curve function
            vec2 bezier(float t, vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
                float it = 1.0 - t;
                return it * it * it * p0 + 3.0 * it * it * t * p1 + 3.0 * it * t * t * p2 + t * t * t * p3;
            }

            // Random function
            float rand(vec2 co) {
                return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
            }

            // Distance to line segment with noise
            float line(vec2 p1, vec2 p2, vec2 p, float noise) {
                vec2 v = p2 - p1;
                vec2 w = p - p1;
                float c1 = dot(w, v);
                if (c1 <= 0.0) return length(w) + noise * rand(p1 + p2) - 0.5 * noise;
                float c2 = dot(v, v);
                if (c2 <= c1) return length(p - p2) + noise * rand(p1 + p2) - 0.5 * noise;
                float b = c1 / c2;
                float baseDistance = length(p - (p1 + b * v));
                return baseDistance + noise * rand(p + p1 + p2) - 0.5 * noise;
            }

            void main() {
                vec2 uv = vUv;
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                float lifeInterval = scratchInterval * scratchLifetime;
                float currentTimeInInterval = mod(time, scratchInterval);
                bool isLineVisible = currentTimeInInterval <= lifeInterval;
                
                if (!isLineVisible) {
                    gl_FragColor = vec4(baseColor, 1.0);
                    return;
                }
                
                float intervalIndex = floor(time / scratchInterval);
                float t = intervalIndex * scratchInterval * 0.1;
                
                // Random alpha for this scratch
                float rawAlpha = fract(sin(intervalIndex * 12.9898) * 43758.5453);
                float lineAlpha = minAlpha + (maxAlpha - minAlpha) * rawAlpha;
                
                // Random length for this scratch
                float lengthFactor = mix(minLength, maxLength, rand(vec2(t, 2.5)));
                
                // Start point and direction
                vec2 p0 = vec2(rand(vec2(t, 0.3)), rand(vec2(t, 1.3)));
                vec2 direction = normalize(vec2(rand(vec2(t, 0.7)), rand(vec2(t, 1.7))) - p0);
                vec2 p3 = p0 + direction * lengthFactor;
                
                // Control points for bezier curve
                bool makeStraight = rand(vec2(t, 2.0)) < straightness;
                if (maxLength - minLength < 0.1) { makeStraight = true; }
                
                vec2 p1, p2;
                if (makeStraight) {
                    p1 = mix(p0, p3, 0.33);
                    p2 = mix(p0, p3, 0.66);
                } else {
                    p1 = vec2(rand(vec2(t, 0.4)), rand(vec2(t, 1.4)));
                    p2 = vec2(rand(vec2(t, 0.6)), rand(vec2(t, 1.6)));
                }
                
                // Find minimum distance to bezier curve
                float minDist = 1.0;
                const int segments = 20;
                for (int i = 0; i < segments; i++) {
                    float t1 = float(i) / float(segments);
                    float t2 = float(i + 1) / float(segments);
                    vec2 point1 = bezier(t1, p0, p1, p2, p3);
                    vec2 point2 = bezier(t2, p0, p1, p2, p3);
                    minDist = min(minDist, line(point1, point2, uv, noisiness));
                }
                
                // Random width for this scratch
                float rawWidth = fract(sin(intervalIndex * 78.233) * 43758.5453);
                float lineWidth = minWidth + (maxWidth - minWidth) * rawWidth;
                
                if (minDist < lineWidth) {
                    // Create scratch color with noise
                    float c = fract(sin(dot(uv * resolution, vec2(12.9898, 78.233))) * 43758.5453);
                    vec3 lineColor = vec3(c + 0.25);
                    vec3 blendedColor = mix(baseColor, lineColor, lineAlpha);
                    gl_FragColor = vec4(blendedColor, 1.0);
                } else {
                    gl_FragColor = vec4(baseColor, 1.0);
                }
            }
        `,
        uniforms: {
            // Scratch timing
            scratchInterval: 1.5,        // How often new scratches appear (0.1-4.0, higher = less frequent)
            scratchLifetime: 0.1,        // How long scratches persist (0.1-1.0, fraction of interval)
            
            // Scratch appearance
            minAlpha: 0.4,               // Minimum scratch opacity (0.0-1.0)
            maxAlpha: 0.8,               // Maximum scratch opacity (0.0-1.0)
            minLength: 0.005,            // Minimum scratch length (0.0-1.0)
            maxLength: 0.5,              // Maximum scratch length (0.0-3.0)
            straightness: 0.8,           // Probability of straight scratches (0.0-1.0, higher = straighter)
            noisiness: 0.001,            // Edge roughness (0.0-0.015, higher = rougher)
            minWidth: 0.0,               // Minimum scratch width (0.0-0.005)
            maxWidth: 0.0002              // Maximum scratch width (0.0-0.015)
        }
    };
}