// Rough Sketch Shader for tStorie
// Hand-drawn effect inspired by Rough.js
// Features wobbly lines, double-line effects, and organic imperfections
// No hatching - pure line work

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
            uniform float sketchRoughness;    // How rough/imperfect the lines are (0.0-1.0)
            uniform float lineWobble;         // Amount of line waviness (0.0-1.0)
            uniform float edgeThreshold;      // Edge detection sensitivity (0.1-0.3)
            uniform float doubleLine;         // Amount of double-line effect (0.0-0.5)
            uniform float lineWeight;         // Thickness of sketch lines (0.5-2.0)
            
            varying vec2 vUv;
            
            // Hash functions for randomness
            float hash(float n) {
                return fract(sin(n) * 43758.5453123);
            }
            
            float hash2(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
            }
            
            vec2 hash22(vec2 p) {
                p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
                return fract(sin(p) * 43758.5453);
            }
            
            // Noise function for organic variation
            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                vec2 u = f * f * (3.0 - 2.0 * f);
                
                float a = hash2(i + vec2(0.0, 0.0));
                float b = hash2(i + vec2(1.0, 0.0));
                float c = hash2(i + vec2(0.0, 1.0));
                float d = hash2(i + vec2(1.0, 1.0));
                
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }
            
            // Calculate luminance
            float luminance(vec3 color) {
                return dot(color, vec3(0.299, 0.587, 0.114));
            }
            
            // Wobbly edge detection (edges aren't perfectly straight)
            float detectWobblyEdges(vec2 uv) {
                vec2 texelSize = 1.0 / resolution;
                
                // Add wobble to sample positions
                float wobbleFreq = 50.0;
                vec2 wobble = vec2(
                    noise(uv * wobbleFreq) - 0.5,
                    noise(uv * wobbleFreq + vec2(100.0)) - 0.5
                ) * texelSize * lineWobble * 2.0;
                
                // Sample with wobbled positions
                float tl = luminance(texture2D(contentTexture, uv + vec2(-1.0, -1.0) * texelSize + wobble).rgb);
                float t  = luminance(texture2D(contentTexture, uv + vec2( 0.0, -1.0) * texelSize + wobble).rgb);
                float tr = luminance(texture2D(contentTexture, uv + vec2( 1.0, -1.0) * texelSize + wobble).rgb);
                float l  = luminance(texture2D(contentTexture, uv + vec2(-1.0,  0.0) * texelSize + wobble).rgb);
                float r  = luminance(texture2D(contentTexture, uv + vec2( 1.0,  0.0) * texelSize + wobble).rgb);
                float bl = luminance(texture2D(contentTexture, uv + vec2(-1.0,  1.0) * texelSize + wobble).rgb);
                float b  = luminance(texture2D(contentTexture, uv + vec2( 0.0,  1.0) * texelSize + wobble).rgb);
                float br = luminance(texture2D(contentTexture, uv + vec2( 1.0,  1.0) * texelSize + wobble).rgb);
                
                float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
                float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
                
                return length(vec2(gx, gy));
            }
            
            // Double-line effect (like redrawing lines imperfectly)
            float doubleLineEffect(vec2 uv, float edges) {
                vec2 texelSize = 1.0 / resolution;
                vec2 offset = vec2(
                    hash2(uv * 100.0) - 0.5,
                    hash2(uv * 100.0 + vec2(50.0)) - 0.5
                ) * texelSize * 2.0;
                
                float secondEdge = detectWobblyEdges(uv + offset);
                return max(edges, secondEdge * doubleLine);
            }
            
            // Paper texture with fiber-like imperfections
            float roughPaper(vec2 uv) {
                float grain = noise(uv * resolution * 0.5);
                float fibers = noise(uv * resolution * 3.0) * 0.3;
                float spots = hash2(floor(uv * resolution * 0.1)) * 0.1;
                
                return mix(0.85, 1.0, grain + fibers + spots);
            }
            
            void main() {
                vec2 uv = vUv;
                
                // Sample base color
                vec3 color = texture2D(contentTexture, uv).rgb;
                float brightness = luminance(color);
                
                // Detect wobbly edges
                float edges = detectWobblyEdges(uv);
                
                // Add double-line imperfection
                edges = doubleLineEffect(uv, edges);
                
                // Convert edge strength to line with adjustable weight
                float edgeLine = smoothstep(edgeThreshold, edgeThreshold + 0.15 * lineWeight, edges);
                
                // Add roughness to edges (gaps and irregularities)
                float edgeRoughness = noise(uv * resolution * 0.3);
                edgeLine *= mix(0.7, 1.0, edgeRoughness * sketchRoughness);
                
                // Paper texture
                float paper = roughPaper(uv);
                
                // Combine elements
                float sketch = 1.0;
                
                // Apply edge lines with variation
                sketch -= edgeLine * (0.8 + hash2(uv * 100.0) * 0.2 * sketchRoughness) * lineWeight;
                
                // Darken based on brightness (subtle shading from original image)
                sketch *= mix(0.6, 1.0, brightness);
                
                // Apply paper texture
                //sketch *= paper;
                
                sketch = clamp(sketch, 0.0, 1.0);
                
                vec3 finalColor = vec3(sketch);
                vec3 mixed = mix(color, finalColor, 0.35); 
                
                gl_FragColor = vec4(mixed, 1.0);
            }
        `,
        
        uniforms: {
            sketchRoughness: 0.6,      // Overall imperfection level (0.4-0.8)
            lineWobble: 0.4,           // How much lines wiggle (0.2-0.6)
            edgeThreshold: 0.85,       // Edge sensitivity (0.1-0.25)
            doubleLine: 0.3,           // Double-line effect strength (0.2-0.5)
            lineWeight: 0.42            // Line thickness (0.8-1.5)
        }
    };
}