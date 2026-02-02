// Rough Sketch Shader for tStorie
// Features wobbly lines, double-line effects, and organic imperfections

function getShaderConfig() {
    // WGSL shader (WebGPU) - Auto-converted from GLSL {
    return {
        vertexShader: `struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) vUv: vec2f,
}

@vertex
fn vertexMain(
    @location(0) position: vec2f
) -> VertexOutput {
    var output: VertexOutput;

                output.vUv = position * 0.5 + 0.5;
                output.vUv.y = 1.0 - output.vUv.y;
                output.position = vec4f(position, 0.0, 1.0);
                return output;
}
`,
        
        fragmentShader: `@group(0) @binding(0) var contentTexture: texture_2d<f32>;
@group(0) @binding(1) var contentTextureSampler: sampler;

struct Uniforms {
    time: f32,
    resolution: vec2f,
    sketchRoughness: f32,
    lineWobble: f32,
    edgeThreshold: f32,
    doubleLine: f32,
    lineWeight: f32,
}
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

f32 hash(n: f32) {
                return fract(sin(n) * 43758.5453123);
            }

f32 hash2(p: vec2f) {
                return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453123);
            }

vec2f hash22(p: vec2f) {
                p = vec2f(dot(p, vec2f(127.1, 311.7)), dot(p, vec2f(269.5, 183.3)));
                return fract(sin(p) * 43758.5453);
            }

f32 noise(p: vec2f) {
                var i: vec2f = floor(p);
                var f: vec2f = fract(p);
                var u: vec2f = f * f * (3.0 - 2.0 * f);
                
                var a: f32 = hash2(i + vec2f(0.0, 0.0));
                var b: f32 = hash2(i + vec2f(1.0, 0.0));
                var c: f32 = hash2(i + vec2f(0.0, 1.0));
                var d: f32 = hash2(i + vec2f(1.0, 1.0));
                
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

f32 luminance(color: vec3f) {
                return dot(color, vec3f(0.299, 0.587, 0.114));
            }

f32 detectWobblyEdges(uv: vec2f) {
                var texelSize: vec2f = 1.0 / resolution;
                
                // Add wobble to sample positions
                var wobbleFreq: f32 = 50.0;
                var wobble: vec2f = vec2f(
                    noise(uv * wobbleFreq) - 0.5,
                    noise(uv * wobbleFreq + vec2f(100.0)) - 0.5
                ) * texelSize * lineWobble * 2.0;
                
                // Sample with wobbled positions
                var tl: f32 = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f(-1.0, -1.0) * texelSize + wobble).rgb);
                var t: f32  = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f( 0.0, -1.0) * texelSize + wobble).rgb);
                var tr: f32 = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f( 1.0, -1.0) * texelSize + wobble).rgb);
                var l: f32  = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f(-1.0,  0.0) * texelSize + wobble).rgb);
                var r: f32  = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f( 1.0,  0.0) * texelSize + wobble).rgb);
                var bl: f32 = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f(-1.0,  1.0) * texelSize + wobble).rgb);
                var b: f32  = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f( 0.0,  1.0) * texelSize + wobble).rgb);
                var br: f32 = luminance(textureSample(contentTexture, contentTextureSampler, uv + vec2f( 1.0,  1.0) * texelSize + wobble).rgb);
                
                var gx: f32 = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
                var gy: f32 = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
                
                return length(vec2f(gx, gy));
            }

f32 doubleLineEffect(uv: vec2f, edges: f32) {
                var texelSize: vec2f = 1.0 / resolution;
                var offset: vec2f = vec2f(
                    hash2(uv * 100.0) - 0.5,
                    hash2(uv * 100.0 + vec2f(50.0)) - 0.5
                ) * texelSize * 2.0;
                
                var secondEdge: f32 = detectWobblyEdges(uv + offset);
                return max(edges, secondEdge * doubleLine);
            }

f32 roughPaper(uv: vec2f) {
                var grain: f32 = noise(uv * resolution * 0.5);
                var fibers: f32 = noise(uv * resolution * 3.0) * 0.3;
                var spots: f32 = hash2(floor(uv * resolution * 0.1)) * 0.1;
                
                return mix(0.85, 1.0, grain + fibers + spots);
            }

@fragment
fn fragmentMain(
    @location(0) vUv: vec2f
) -> @location(0) vec4f {

                var uv: vec2f = vUv;
                
                // Sample base color
                var color: vec3f = textureSample(contentTexture, contentTextureSampler, uv).rgb;
                var brightness: f32 = luminance(color);
                
                // Detect wobbly edges
                var edges: f32 = detectWobblyEdges(uv);
                
                // Add double-line imperfection
                edges = doubleLineEffect(uv, edges);
                
                // Convert edge strength to line with adjustable weight
                var edgeLine: f32 = smoothstep(uniforms.edgeThreshold, uniforms.edgeThreshold + 0.15 * uniforms.lineWeight, edges);
                
                // Add roughness to edges (gaps and irregularities)
                var edgeRoughness: f32 = noise(uv * uniforms.resolution * 0.3);
                edgeLine *= mix(0.7, 1.0, edgeRoughness * uniforms.sketchRoughness);
                
                // Paper texture
                var paper: f32 = roughPaper(uv);
                
                // Combine elements
                var sketch: f32 = 1.0;
                
                // Apply edge lines with variation
                sketch -= edgeLine * (0.8 + hash2(uv * 100.0) * 0.2 * uniforms.sketchRoughness) * uniforms.lineWeight;
                
                // Darken based on brightness (subtle shading from original image)
                sketch *= mix(0.6, 1.0, brightness);
                
                // Apply paper texture
                //sketch *= paper;
                
                sketch = clamp(sketch, 0.0, 1.0);
                
                var finalColor: vec3f = vec3f(sketch);
                var mixed: vec3f = mix(color, finalColor, 0.35); 
                
                return vec4f(mixed, 1.0);
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