// Vignette Shader for t|Storie
// Soft vignette that's evenly distributed toward edges

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
            uniform float vignetteStart;
            uniform float vignetteLvl;
            varying vec2 vUv;
            
            void main() {
                vec2 uv = vUv;
                
                // Sample base color
                vec3 color = texture2D(contentTexture, uv).rgb;
                
                // Vignette using edge multiplication
                vec2 vignetteUV = uv * (vec2(1.0) - vec2(uv.y, uv.x));
                float vignette = pow(vignetteUV.x * vignetteUV.y * vignetteLvl, vignetteStart);
                
                color *= vignette;
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            vignetteStart: 0.25,  // Controls the power curve (lower = softer falloff)
            vignetteLvl: 40.0     // Controls intensity (higher = stronger effect)
        }
    };
}