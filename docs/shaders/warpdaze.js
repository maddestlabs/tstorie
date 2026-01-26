// Subtle Chromatic Warp Shader
// Adapted from Shadertoy "Subtle" by R3V1Z3
// Nightlight.js compatible

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
            uniform float time;

            varying vec2 vUv;

            void main() {
                float aspectRatio = resolution.x / resolution.y;

                // Start from normalized UVs
                vec2 uv = vUv;

                // Convert to -1..1 space
                uv = uv * 2.0 - 1.0;
                uv.x *= aspectRatio;

                float r = 5.0;
                float ry = r * 2.0;
                float t = time * 0.5;

                float angleY = radians(mix(-r, r, sin(t) * 0.5 + 0.5));
                float angleX = radians(mix(-ry, ry, sin(t + 1.0) * 0.5 + 0.5));

                mat3 rotY = mat3(
                    cos(angleY), 0.0, sin(angleY),
                    0.0, 1.0, 0.0,
                   -sin(angleY), 0.0, cos(angleY)
                );

                mat3 rotX = mat3(
                    1.0, 0.0, 0.0,
                    0.0, cos(angleX), -sin(angleX),
                    0.0, sin(angleX),  cos(angleX)
                );

                vec3 dir = vec3(uv, 0.0);
                dir = rotY * dir;
                dir = rotX * dir;

                uv = dir.xy;
                uv.x /= aspectRatio;
                uv = uv * 0.5 + 0.5;

                // Chromatic aberration
                float rgbAngle = time;
                float rgbRadius = 0.00075;

                vec2 offsetR = vec2(cos(rgbAngle), sin(rgbAngle)) * rgbRadius;
                vec2 offsetG = vec2(cos(rgbAngle + 2.0944), sin(rgbAngle + 2.0944)) * rgbRadius;
                vec2 offsetB = vec2(cos(rgbAngle - 2.0944), sin(rgbAngle - 2.0944)) * rgbRadius;

                float rCol = texture2D(contentTexture, uv + offsetR).r;
                float gCol = texture2D(contentTexture, uv + offsetG).g;
                float bCol = texture2D(contentTexture, uv + offsetB).b;
                float aCol = texture2D(contentTexture, uv).a;

                gl_FragColor = vec4(rCol, gCol, bCol, aCol);
            }
        `,

        uniforms: {
            // No custom tuning needed, but exposed if you want later
        }
    };
}
