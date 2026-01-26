// CRT Frame Shader for t|Storie
// Curved CRT screen with decorative frame

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
            uniform float curveStrength;
            uniform float frameSize;
            uniform float frameHue;
            uniform float frameSat;
            uniform float frameLight;
            uniform float frameReflect;
            uniform float frameGrain;
            varying vec2 vUv;
            
            float random(vec2 c) {
                return fract(sin(dot(c.xy, vec2(12.9898, 78.233))) * 43758.5453);
            }
            
            vec3 hsl2rgb(vec3 c) {
                vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }
            
            void main() {
                float iTime = time;
                vec2 iResolution = resolution;
                vec2 uv = vUv;
                vec2 center = vec2(0.5, 0.5);
                float distanceFromCenter = length(uv - center);
                float px = 1.0 / iResolution.x;
                float frame = frameSize * px;
                
                // Apply CRT curvature to UV coordinates
                uv = vUv + (vUv - center) * pow(distanceFromCenter, 5.0) * curveStrength;
                
                // Determine if we're in the frame region
                bool isFrame = (uv.x < frame || uv.x > (1.0 - frame) || 
                               uv.y < frame || uv.y > (1.0 - frame));
                
                // Calculate content UV (everything inside the frame)
                vec2 contentUV = (uv - vec2(frame, frame)) / (1.0 - 2.0 * frame);
                
                vec3 color;
                
                if (isFrame) {
                    // Frame rendering with gradient and grain
                    float frameVal = 100.0;
                    float nX = frameVal / iResolution.x;
                    float nY = frameVal / iResolution.y;
                    float intensity = 0.0;
                    float distX = min(uv.x, 1.0 - uv.x);
                    float distY = min(uv.y, 1.0 - uv.y);
                    float minDist = min(distX, distY);
                    intensity = mix(frameLight, 0.0, minDist / max(nX, nY) * 4.0);
                    color = hsl2rgb(vec3(frameHue, frameSat, intensity));
                    color *= 1.0 - frameGrain * random(uv);
                    
                    // Reflection effect on frame - mirror and blur the content
                    vec2 reflectedUV = contentUV;
                    if (reflectedUV.x < 0.0) reflectedUV.x = -reflectedUV.x;
                    else if (reflectedUV.x > 1.0) reflectedUV.x = 2.0 - reflectedUV.x;
                    if (reflectedUV.y < 0.0) reflectedUV.y = -reflectedUV.y;
                    else if (reflectedUV.y > 1.0) reflectedUV.y = 2.0 - reflectedUV.y;
                    
                    // Simple blur for reflection
                    vec3 blurred = vec3(0.0);
                    float blur = 2.0 / iResolution.x;
                    for (int x = -1; x <= 1; x++) {
                        for (int y = -1; y <= 1; y++) {
                            vec2 blurPos = reflectedUV + vec2(float(x) * blur, float(y) * blur);
                            blurred += texture2D(contentTexture, blurPos).rgb;
                        }
                    }
                    blurred /= 9.0;
                    color += blurred * frameReflect * 0.5;
                    
                    // Animated light source on frame
                    float lightX = 0.5 + sin(iTime * 1.75) * 0.35;
                    vec2 lightPos = vec2(lightX, 0.2);
                    float lightDist = length(uv - lightPos);
                    float lightFalloff = pow(clamp(1.0 - (lightDist / 1.5), 0.0, 1.0), 0.85);
                    color *= mix(0.25, 2.5, lightFalloff);
                    
                } else {
                    // CRT content area - apply curvature and sample texture
                    if (contentUV.x < 0.0 || contentUV.x > 1.0 || 
                        contentUV.y < 0.0 || contentUV.y > 1.0) {
                        // Out of bounds shows black
                        color = vec3(0.0);
                    } else {
                        // Sample the content texture with curved UVs
                        color = texture2D(contentTexture, contentUV).rgb;
                    }
                }
                
                gl_FragColor = vec4(color, 1.0);
            }
        `,
        
        uniforms: {
            curveStrength: 0.95,      // CRT screen curvature (0.0 = flat, 1.0 = curved)
            frameSize: 20.0,          // Outer frame thickness in pixels
            frameHue: 0.025,          // Frame color hue (0.0-1.0)
            frameSat: 0.0,            // Frame color saturation (0.0-1.0)
            frameLight: 0.01,         // Frame base brightness (0.0-1.0)
            frameReflect: 0.35,       // Screen reflection on frame (0.0-1.0)
            frameGrain: 0.25          // Frame texture grain (0.0-1.0)
        }
    };
}