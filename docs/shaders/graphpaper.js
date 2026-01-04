// Graph Paper Shader for tStorie
// Draws a simple grid aligned to terminal character cells
// Upload this to a GitHub Gist and use: ?shader=YOUR_GIST_ID
// Or use locally: ?shader=graphpaper

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
            uniform vec2 cellSize;
            uniform vec2 cellSizeAdjust;
            uniform vec3 gridColor;
            uniform float gridAlpha;
            uniform float gridThickness;
            uniform float paperStrength;
            uniform float paperGrain;
            varying vec2 vUv;

            // Random function for noise
            float rand(vec2 n) {
                return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
            }
            
            float rand_single(float n) {
                return fract(sin(n * 43758.5453));
            }
            
            // Worley noise for paper crumpling effect
            vec3 worley(vec2 n, float s) {
                vec3 ret = vec3(s * 10.0);
                
                // Look in 9 cells (current cell plus 8 surrounding)
                for(int x = -1; x < 2; x++) {
                    for(int y = -1; y < 2; y++) {
                        vec2 offset = vec2(float(x), float(y));
                        vec2 cellIndex = floor(n / s) + offset;
                        
                        // Random point in this cell
                        vec2 worleyPoint = vec2(
                            rand(cellIndex),
                            rand(cellIndex + vec2(0.1, 0.1))
                        );
                        
                        // Convert to distance from n
                        worleyPoint += offset - fract(n / s);
                        float d = length(worleyPoint) * s;
                        
                        if(d < ret.z) {
                            ret = vec3(worleyPoint, d);
                        }
                    }
                }
                return ret;
            }

            void main() {
                vec2 uv = vUv;
                
                // Generate paper crumpling effect and lighting
                vec2 paperDisplacement = vec2(0.0);
                float paperShading = 1.0;
                
                if (paperStrength > 0.0 || paperGrain > 0.0) {
                    // Multi-octave worley noise for natural paper texture
                    float wsize = 0.8;
                    const int iterationCount = 4;
                    vec2 normal = vec2(0.0);
                    float influenceFactor = 1.0;
                    
                    for(int i = 0; i < iterationCount; i++) {
                        vec3 w = worley(uv * 2.0, wsize);
                        normal += influenceFactor * w.xy;
                        wsize *= 0.5;
                        influenceFactor *= 0.6;
                    }
                    
                    // Convert normal to subtle displacement
                    paperDisplacement = normal * paperStrength * 0.001;
                    
                    // Create subtle lighting from the normal (paper bumps catch light)
                    vec3 lightDir = normalize(vec3(0.5, -0.3, 1.0));
                    vec3 paperNormal = normalize(vec3(normal * 0.5, 1.0));
                    float diffuse = max(dot(paperNormal, lightDir), 0.0);
                    paperShading = mix(0.92, 1.08, diffuse);
                }
                
                // Fine grain texture with dithering
                float grain = 0.0;
                if (paperGrain > 0.0) {
                    // High-frequency per-pixel noise for paper grain
                    float pixelNoise = rand(uv * resolution * 0.5);
                    
                    // Add temporal variation for film grain effect (very subtle)
                    float timeNoise = rand(vec2(time * 0.1, uv.x + uv.y));
                    pixelNoise = mix(pixelNoise, timeNoise, 0.1);
                    
                    // Modulate grain intensity by paper shading (more visible in crumpled areas)
                    float grainIntensity = paperGrain * (0.5 + abs(paperShading - 1.0) * 2.0);
                    
                    // Create dithered noise pattern
                    grain = (pixelNoise - 0.5) * grainIntensity * 0.4;
                }
                
                // Apply paper displacement to UV
                vec2 distortedUV = uv + paperDisplacement;
                
                // Sample the terminal content with displacement
                vec4 content = texture2D(contentTexture, distortedUV);
                
                // Apply fine-tuning adjustment to cell size
                vec2 adjustedCellSize = cellSize + cellSizeAdjust;
                
                // Convert UV to pixel coordinates (use distorted UV for grid too)
                vec2 pixelCoord = distortedUV * resolution;
                
                // Calculate position within each cell
                vec2 cellPos = mod(pixelCoord, adjustedCellSize);
                
                // Determine if we're on a grid line (left or top edge of cell)
                float onGridLine = 0.0;
                if (cellPos.x < gridThickness || cellPos.y < gridThickness) {
                    onGridLine = 1.0;
                }
                
                // Blend grid lines over the terminal content
                vec3 finalColor = mix(content.rgb, gridColor, onGridLine * gridAlpha);
                
                // Apply paper shading and grain
                finalColor = finalColor * paperShading + grain;
                
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `,
        uniforms: {
            // These will be set dynamically based on terminal cell size
            cellSize: [10.0, 20.0],  // Default values (will be updated)
            
            // Fine-tuning adjustments (add/subtract pixels from cellSize)
            // Adjust these to align grid perfectly with terminal cells
            // Positive values = larger cells, Negative = smaller cells
            cellSizeAdjust: [0, 0],  // [widthAdjust, heightAdjust]
            
            // Grid appearance
            gridColor: [0.3, 0.5, 0.95],  // Blue-ish grid lines
            gridAlpha: 0.2,              // Grid line opacity (0.0-1.0)
            gridThickness: 1.0,          // Grid line thickness in pixels
            
            // Paper texture effect
            paperStrength: 1.0,          // Crumpling distortion (0.0 = off, 1.0-5.0 = subtle to strong)
            paperGrain: 0.18             // Fine grain visibility (0.0 = off, 0.05-0.15 = realistic)
        }
    };
}
