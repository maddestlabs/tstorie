// Moving Vertical Line Shader for Stone Garden
// Creates a soft vertical line that moves down and loops perfectly
// Designed to be placed before the grid shader in the chain

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
            uniform vec3 lineColor;
            uniform float lineAlpha;
            uniform float lineWidth;
            uniform float speed;
            uniform float loopDuration;
            varying vec2 vUv;

            void main() {
                vec2 uv = vUv;
                
                // Sample terminal content
                vec4 content = texture2D(contentTexture, uv);
                
                // Calculate the vertical position of the line (0.0 to 1.0)
                // Using mod to create perfect loop
                float linePosition = mod(time * speed, loopDuration) / loopDuration;
                
                // Calculate distance from current pixel to the line
                float distanceToLine = abs(uv.y - linePosition);
                
                // Create soft edge with smoothstep
                float lineIntensity = 1.0 - smoothstep(0.0, lineWidth, distanceToLine);
                
                // Blend line color over terminal content
                vec3 finalColor = mix(content.rgb, lineColor, lineIntensity * lineAlpha);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // Line appearance
            lineColor: [0.9, 0.9, 0.95],  // Very light, almost white with slight blue tint
            lineAlpha: 0.05,               // Line opacity (0.0-1.0)
            lineWidth: 0.002,              // Line softness/width (in UV space, 0.0-1.0)
            
            // Animation
            speed: 0.3,                    // Movement speed (higher = faster)
            loopDuration: 10.0             // Duration for one complete loop in seconds
        }
    };
}