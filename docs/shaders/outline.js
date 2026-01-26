// R3Draw Edge Detection Shader
// Ported from Shadertoy - creates sketch/cartoon effect

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
            uniform float edgeLevel;          // Edge detection sensitivity
            uniform float edgeInvert;         // 0.0 = black lines, 1.0 = white lines
            uniform float sourceMix;          // Blend original color back in
            uniform float sourceLight;        // Brightness multiplier
            uniform float sourceEmboss;       // Emboss/posterize strength
            varying vec2 vUv;
            
            // HSL to RGB conversion
            vec3 hsl2rgb(vec3 c) {
                vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }
            
            // RGB to HSL conversion
            vec3 rgb2hsl(vec3 c) {
                float maxVal = max(max(c.r, c.g), c.b);
                float minVal = min(min(c.r, c.g), c.b);
                float h, s, l = (maxVal + minVal) / 2.0;
                
                if (maxVal == minVal) {
                    h = s = 0.0;
                } else {
                    float d = maxVal - minVal;
                    s = l > 0.5 ? d / (2.0 - maxVal - minVal) : d / (maxVal + minVal);
                    
                    if (maxVal == c.r) {
                        h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
                    } else if (maxVal == c.g) {
                        h = (c.b - c.r) / d + 2.0;
                    } else {
                        h = (c.r - c.g) / d + 4.0;
                    }
                    h /= 6.0;
                }
                
                return vec3(h, s, l);
            }
            
            // Convolution matrix for edge detection
            vec4 convolveMatrix(vec2 uv, float kernel[9], float kernelDivisor) {
                vec4 sum = vec4(0.0);
                vec2 texelSize = 1.0 / resolution;
                
                // Offsets for 3x3 kernel
                vec2 offsets[9];
                offsets[0] = vec2(-1.0, 1.0) * texelSize;
                offsets[1] = vec2(0.0, 1.0) * texelSize;
                offsets[2] = vec2(1.0, 1.0) * texelSize;
                offsets[3] = vec2(-1.0, 0.0) * texelSize;
                offsets[4] = vec2(0.0, 0.0) * texelSize;
                offsets[5] = vec2(1.0, 0.0) * texelSize;
                offsets[6] = vec2(-1.0, -1.0) * texelSize;
                offsets[7] = vec2(0.0, -1.0) * texelSize;
                offsets[8] = vec2(1.0, -1.0) * texelSize;
                
                // Apply convolution
                for (int i = 0; i < 9; i++) {
                    vec4 texel = texture2D(contentTexture, uv + offsets[i]);
                    sum += texel * kernel[i];
                }
                
                return sum / kernelDivisor;
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample original color
                vec4 color = texture2D(contentTexture, uv);
                vec3 c = color.rgb;
                
                // Posterize/emboss effect
                float l = dot(c, vec3(0.3, 0.59, 0.11));
                
                // Manual derivative approximation instead of fwidth
                vec2 texelSize = 1.0 / resolution;
                float lx = dot(texture2D(contentTexture, uv + vec2(texelSize.x, 0.0)).rgb, vec3(0.3, 0.59, 0.11));
                float ly = dot(texture2D(contentTexture, uv + vec2(0.0, texelSize.y)).rgb, vec3(0.3, 0.59, 0.11));
                float derivative = abs(lx - l) + abs(ly - l);
                
                float f = 1.0 - sourceEmboss * derivative;
                c *= sourceLight * vec3(clamp(f, 0.0, 1.0));
                
                // Edge detection kernel (Laplacian)
                float kernel[9];
                kernel[0] = 1.0;  kernel[1] = 1.0;  kernel[2] = 1.0;
                kernel[3] = 1.0;  kernel[4] = -8.0; kernel[5] = 1.0;
                kernel[6] = 1.0;  kernel[7] = 1.0;  kernel[8] = 1.0;
                
                vec4 convolved = convolveMatrix(uv, kernel, edgeLevel);
                float luminance = dot(convolved.rgb, vec3(0.299, 0.587, 0.114));
                
                // Invert option
                float inverted = mix(1.0 - luminance, luminance, edgeInvert);
                
                // Mix edge detection with original color
                vec3 mixed = mix(vec3(inverted), c, sourceMix);
                
                gl_FragColor = vec4(mixed, color.a);
            }
        `,
        
        uniforms: {
            edgeLevel: 0.25,          // Edge detection sensitivity (0.1-1.0)
            edgeInvert: 0.0,          // 0.0 = dark lines, 1.0 = light lines
            sourceMix: 0.75,           // 0.0 = pure edges, 1.0 = original image
            sourceLight: 1.5,         // Brightness multiplier (0.5-3.0)
            sourceEmboss: 8.0,        // Posterize/emboss strength (0.0-20.0)
        }
    };
}