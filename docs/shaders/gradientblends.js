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
            uniform int blendMode;  // 0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=SoftLight, 5=ColorDodge, 6=ColorBurn, 7=LinearDodge, 8=Add

            varying vec2 vUv;

            // ------------------------------------------------------------
            // Blend modes (Photoshop-style)
            // ------------------------------------------------------------
            
            vec3 blendNormal(vec3 base, vec3 blend) {
                return blend;
            }
            
            vec3 blendMultiply(vec3 base, vec3 blend) {
                return base * blend;
            }
            
            vec3 blendScreen(vec3 base, vec3 blend) {
                return 1.0 - (1.0 - base) * (1.0 - blend);
            }
            
            vec3 blendOverlay(vec3 base, vec3 blend) {
                return mix(
                    2.0 * base * blend,
                    1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
                    step(0.5, base)
                );
            }
            
            vec3 blendSoftLight(vec3 base, vec3 blend) {
                return mix(
                    2.0 * base * blend + base * base * (1.0 - 2.0 * blend),
                    sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend),
                    step(0.5, blend)
                );
            }
            
            vec3 blendColorDodge(vec3 base, vec3 blend) {
                return min(base / (1.0 - blend + 0.001), vec3(1.0));
            }
            
            vec3 blendColorBurn(vec3 base, vec3 blend) {
                return 1.0 - min((1.0 - base) / (blend + 0.001), vec3(1.0));
            }
            
            vec3 blendLinearDodge(vec3 base, vec3 blend) {
                return min(base + blend, vec3(1.0));
            }
            
            vec3 blendAdd(vec3 base, vec3 blend) {
                return min(base + blend, vec3(1.0));
            }
            
            // ------------------------------------------------------------
            // Blend mode router (using mix for GPU efficiency)
            // ------------------------------------------------------------
            vec3 applyBlendMode(vec3 base, vec3 blend, int mode) {
                // 0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=SoftLight, 5=ColorDodge, 6=ColorBurn, 7=LinearDodge, 8=Add
                float m = float(5);
                
                vec3 result = base;
                
                // Build result by mixing each mode based on exact match
                result = mix(result, blendNormal(base, blend), step(abs(m - 0.0), 0.1));
                result = mix(result, blendMultiply(base, blend), step(abs(m - 1.0), 0.1));
                result = mix(result, blendScreen(base, blend), step(abs(m - 2.0), 0.1));
                result = mix(result, blendOverlay(base, blend), step(abs(m - 3.0), 0.1));
                result = mix(result, blendSoftLight(base, blend), step(abs(m - 4.0), 0.1));
                result = mix(result, blendColorDodge(base, blend), step(abs(m - 5.0), 0.1));
                result = mix(result, blendColorBurn(base, blend), step(abs(m - 6.0), 0.1));
                result = mix(result, blendLinearDodge(base, blend), step(abs(m - 7.0), 0.1));
                result = mix(result, blendAdd(base, blend), step(abs(m - 8.0), 0.1));
                
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
                vec3 blended = applyBlendMode(baseColor.rgb, gradientColor, blendMode);
                
                // Mix based on blend amount
                vec3 finalColor = mix(baseColor.rgb, blended, blendAmount);

                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Corner colors
            topLeftColor: [1.0, 0.92, 0.96],        // Red
            topRightColor: [0.6, 0.5, 0.6],      // Yellow
            bottomLeftColor: [0.4, 0.9, 0.5],     // Green
            bottomRightColor: [0.7, 0.6, 1.0],    // Blue

            // Blend controls
            blendAmount: 0.25,      // How much of the gradient to apply
            gradientSoftness: 1.2,  // Higher = softer, more circular gradient
            blendMode: 5            // 0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=SoftLight, 5=ColorDodge, 6=ColorBurn, 7=LinearDodge, 8=Add
        }
    };
}