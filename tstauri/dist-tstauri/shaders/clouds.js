// Clouds Shader for tStorie
// Procedural cloud/fog effect inspired by classic JRPGs like Chrono Trigger
// Smooth, billowy clouds with controllable density and movement

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
            uniform float cloudDensity;      // How thick/opaque the clouds are (0.0-1.0)
            uniform float cloudScale;        // Size of cloud formations (0.5-3.0)
            uniform float cloudSpeed;        // How fast clouds move (0.0-2.0)
            uniform vec2 cloudDirection;     // Direction vector for cloud movement
            uniform float cloudSoftness;     // Edge softness of clouds (0.0-1.0)
            uniform vec3 cloudColor;         // Color tint for clouds
            uniform float layerCount;        // Number of cloud layers for depth (1.0-3.0)
            
            varying vec2 vUv;
            
            // Hash function for noise generation
            vec2 hash(vec2 p) {
                p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
                return fract(sin(p) * 43758.5453);
            }
            
            // Smooth noise function (simplified Perlin-like noise)
            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                
                // Smooth interpolation
                vec2 u = f * f * (3.0 - 2.0 * f);
                
                // Four corners
                float a = dot(hash(i + vec2(0.0, 0.0)) - 0.5, f - vec2(0.0, 0.0));
                float b = dot(hash(i + vec2(1.0, 0.0)) - 0.5, f - vec2(1.0, 0.0));
                float c = dot(hash(i + vec2(0.0, 1.0)) - 0.5, f - vec2(0.0, 1.0));
                float d = dot(hash(i + vec2(1.0, 1.0)) - 0.5, f - vec2(1.0, 1.0));
                
                // Bilinear interpolation
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }
            
            // Fractal Brownian Motion (FBM) for more organic cloud shapes
            float fbm(vec2 p, int octaves) {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                for (int i = 0; i < 4; i++) {
                    if (i >= octaves) break;
                    value += amplitude * noise(p * frequency);
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }
                
                return value;
            }
            
            // Generate cloud pattern
            float cloudPattern(vec2 uv, float timeOffset) {
                // Apply cloud movement
                vec2 movement = cloudDirection * time * cloudSpeed + vec2(timeOffset * 10.0, 0.0);
                vec2 cloudUv = (uv + movement) * cloudScale;
                
                // Create billowy cloud shapes with FBM
                float clouds = fbm(cloudUv, 4);
                
                // Add another layer at different scale for variety
                clouds += fbm(cloudUv * 0.5 + vec2(100.0), 3) * 0.5;
                
                // Normalize and apply softness
                clouds = (clouds + 1.0) * 0.5; // Map from [-1,1] to [0,1]
                clouds = smoothstep(0.5 - cloudSoftness, 0.5 + cloudSoftness, clouds);
                
                return clouds;
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample base texture
                vec3 baseColor = texture2D(contentTexture, uv).rgb;
                
                // Generate multiple cloud layers for depth
                float cloudMask = 0.0;
                int layers = int(layerCount);
                
                for (int i = 0; i < 3; i++) {
                    if (i >= layers) break;
                    
                    float layerOffset = float(i) * 0.3;
                    float layerSpeed = 1.0 + float(i) * 0.2; // Parallax effect
                    float layer = cloudPattern(uv, layerOffset) * (1.0 - float(i) * 0.2);
                    cloudMask += layer;
                }
                
                // Normalize based on layer count
                cloudMask /= layerCount;
                cloudMask = clamp(cloudMask, 0.0, 1.0);
                
                // Apply cloud density
                cloudMask *= cloudDensity;
                
                // Blend clouds over the base texture
                vec3 finalColor = mix(baseColor, cloudColor, cloudMask);
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        
        uniforms: {
    cloudDensity: 0.5,
    cloudScale: 0.5,
    cloudSpeed: 0.075,
    cloudDirection: [1.15, -0.3],
    cloudSoftness: 0.01,
    cloudColor: [0.7, 0.75, 0.8],
    layerCount: 2.0
        }
    };
}