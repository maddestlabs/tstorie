// Four Corner Gradient with Color Dodge Blend
// Subtle color overlay to brighten and add warmth to paper textures

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

            // Corner colors
            uniform vec3 topLeftColor;
            uniform vec3 topRightColor;
            uniform vec3 bottomLeftColor;
            uniform vec3 bottomRightColor;

            // Blend controls
            uniform float blendAmount;
            uniform float gradientSoftness;

            varying vec2 vUv;
            
            vec3 blendColorDodge(vec3 base, vec3 blend) {
                return min(base / (1.0 - blend + 0.001), vec3(1.0));
            }
            
            // ------------------------------------------------------------
            // Blend mode router (using mix for GPU efficiency)
            // ------------------------------------------------------------
            vec3 applyBlendMode(vec3 base, vec3 blend) {
                // 0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=SoftLight, 5=ColorDodge, 6=ColorBurn, 7=LinearDodge, 8=Add
                float m = float(5);
                vec3 result = base;
                result = mix(result, blendColorDodge(base, blend), step(abs(m - 5.0), 0.1));                
                return result;
            }

            void main() {
                vec2 uv = vUv;
                vec4 baseColor = texture2D(contentTexture, uv);

                // --------------------------------------------------------
                // Create four-corner gradient
                // --------------------------------------------------------
                
                // Apply softness curve to UV (makes gradient less linear)
                vec2 softUv = uv;
                softUv = pow(softUv, vec2(gradientSoftness));
                vec2 invSoftUv = vec2(1.0) - softUv;
                invSoftUv = pow(invSoftUv, vec2(gradientSoftness));
                
                // Bilinear interpolation between four corners
                vec3 top = mix(topLeftColor, topRightColor, softUv.x);
                vec3 bottom = mix(bottomLeftColor, bottomRightColor, softUv.x);
                vec3 gradientColor = mix(top, bottom, softUv.y);

                // --------------------------------------------------------
                // Apply selected blend mode
                // --------------------------------------------------------
                vec3 blended = applyBlendMode(baseColor.rgb, gradientColor);
                
                // Mix based on blend amount
                vec3 finalColor = mix(baseColor.rgb, blended, blendAmount);

                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Corner colors
            topLeftColor: [1.0, 0.92, 0.96],        // Red
            topRightColor: [0.6, 0.5, 0.6],      // Yellow
            bottomLeftColor: [0.6, 0.9, 0.7],     // Green
            bottomRightColor: [0.7, 0.6, 1.0],    // Blue

            // Blend controls
            blendAmount: 0.25,      // How much of the gradient to apply
            gradientSoftness: 1.2,  // Higher = softer, more circular gradient
        }
    };
}