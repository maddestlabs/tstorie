#!/usr/bin/env node
/**
 * GLSL to WGSL Shader Converter for TStorie
 * 
 * Converts TStorie shader files from WebGL/GLSL to WebGPU/WGSL
 * Handles the specific shader format used in docs/shaders/*.js
 */

const fs = require('fs');
const path = require('path');

class GLSLtoWGSLConverter {
    constructor() {
        this.uniformBindings = [];
        this.bindingCounter = 0;
    }

    /**
     * Convert GLSL type to WGSL type
     */
    convertType(glslType) {
        const typeMap = {
            'float': 'f32',
            'vec2': 'vec2f',
            'vec3': 'vec3f',
            'vec4': 'vec4f',
            'mat2': 'mat2x2f',
            'mat3': 'mat3x3f',
            'mat4': 'mat4x4f',
            'int': 'i32',
            'uint': 'u32',
            'bool': 'bool',
            'sampler2D': 'texture_2d<f32>'
        };
        return typeMap[glslType] || glslType;
    }

    /**
     * Convert GLSL built-in functions to WGSL
     */
    convertFunctions(code) {
        const functionMap = [
            // Texture sampling
            [/texture2D\s*\(\s*(\w+)\s*,\s*([^)]+)\)/g, 'textureSample($1, $1Sampler, $2)'],
            
            // Math functions (most are same, but some differ)
            [/fract\s*\(/g, 'fract('],
            [/mix\s*\(/g, 'mix('],
            [/mod\s*\(/g, 'fract('],  // Note: mod(x,y) in GLSL ≈ x - y * floor(x/y), but fract for mod(x,1.0)
            
            // Type constructors - add 'f' suffix
            [/\bvec2\s*\(/g, 'vec2f('],
            [/\bvec3\s*\(/g, 'vec3f('],
            [/\bvec4\s*\(/g, 'vec4f('],
            [/\bmat2\s*\(/g, 'mat2x2f('],
            [/\bmat3\s*\(/g, 'mat3x3f('],
            [/\bmat4\s*\(/g, 'mat4x4f('],
        ];

        let result = code;
        for (const [pattern, replacement] of functionMap) {
            result = result.replace(pattern, replacement);
        }
        
        // Fix float literals properly
        // Step 1: Add .0 to integers used as floats (but not in array indices or loop counters)
        result = result.replace(/\b(\d+)\b(?!\.)(?!\])/g, '$1.0');
        
        // Step 2: Fix double decimals like 0.5.0 -> 0.5
        result = result.replace(/(\d+)\.(\d+)\.0/g, '$1.$2');
        
        // Step 3: Fix integer loop variables (restore them)
        result = result.replace(/for\s*\(\s*(?:var\s+)?(\w+)\s*(?::\s*\w+\s*)?=\s*(-?\d+)\.0\s*;/g, 'for (var $1: i32 = $2;');
        
        return result;
    }
    
    /**
     * Extract helper functions from GLSL code
     */
    extractHelperFunctions(glsl) {
        const helpers = [];
        // Match function definitions (not main)
        const functionRegex = /((?:float|vec2|vec3|vec4|int|bool|mat2|mat3|mat4)\s+(\w+)\s*\([^)]*\)\s*{(?:[^{}]|{[^{}]*})*})/g;
        
        let match;
        while ((match = functionRegex.exec(glsl)) !== null) {
            const funcName = match[2];
            if (funcName !== 'main') {
                const funcCode = match[1];
                helpers.push({ name: funcName, code: funcCode });
            }
        }
        
        return helpers;
    }
    
    /**
     * Convert a helper function from GLSL to WGSL
     */
    convertHelperFunction(glslFunc) {
        let wgsl = glslFunc;
        
        // Convert return type
        wgsl = wgsl.replace(/^(float|vec2|vec3|vec4|int|bool|mat2|mat3|mat4)/, (match) => {
            return this.convertType(match);
        });
        
        // Convert parameter types
        wgsl = wgsl.replace(/\(([^)]+)\)/, (match, params) => {
            const convertedParams = params.split(',').map(param => {
                param = param.trim();
                const parts = param.match(/(\w+)\s+(\w+)/);
                if (parts) {
                    const type = this.convertType(parts[1]);
                    const name = parts[2];
                    return `${name}: ${type}`;
                }
                return param;
            }).join(', ');
            return `(${convertedParams})`;
        });
        
        // Convert types in function body
        wgsl = this.convertFunctions(wgsl);
        
        // Convert type declarations inside function
        wgsl = wgsl.replace(/\b(float|vec2|vec3|vec4|int|bool)\s+(\w+)/g, (match, type, name) => {
            return `var ${name}: ${this.convertType(type)}`;
        });
        
        return wgsl;
    }

    /**
     * Convert vertex shader from GLSL to WGSL
     */
    convertVertexShader(glsl) {
        let wgsl = '';
        
        // Parse attributes and varyings
        const attributeRegex = /attribute\s+(\w+)\s+(\w+);/g;
        const varyingRegex = /varying\s+(\w+)\s+(\w+);/g;
        
        const attributes = [];
        const varyings = [];
        
        let match;
        while ((match = attributeRegex.exec(glsl)) !== null) {
            attributes.push({ type: match[1], name: match[2] });
        }
        
        while ((match = varyingRegex.exec(glsl)) !== null) {
            varyings.push({ type: match[1], name: match[2] });
        }
        
        // Create VertexOutput struct
        if (varyings.length > 0) {
            wgsl += 'struct VertexOutput {\n';
            wgsl += '    @builtin(position) position: vec4f,\n';
            varyings.forEach((varying, i) => {
                const wgslType = this.convertType(varying.type);
                wgsl += `    @location(${i}) ${varying.name}: ${wgslType},\n`;
            });
            wgsl += '}\n\n';
        }
        
        // Start vertex function
        wgsl += '@vertex\n';
        wgsl += 'fn vertexMain(\n';
        
        // Add attributes as parameters
        attributes.forEach((attr, i) => {
            const wgslType = this.convertType(attr.type);
            wgsl += `    @location(${i}) ${attr.name}: ${wgslType}`;
            if (i < attributes.length - 1) wgsl += ',';
            wgsl += '\n';
        });
        
        wgsl += ') -> VertexOutput {\n';
        wgsl += '    var output: VertexOutput;\n';
        
        // Extract main function body
        const mainMatch = glsl.match(/void\s+main\s*\(\s*\)\s*{([\s\S]*?)}/);
        if (mainMatch) {
            let body = mainMatch[1];
            
            // Replace varying assignments with output struct assignments
            varyings.forEach(varying => {
                body = body.replace(
                    new RegExp(`\\b${varying.name}\\b`, 'g'),
                    `output.${varying.name}`
                );
            });
            
            // Replace gl_Position with output.position
            body = body.replace(/gl_Position/g, 'output.position');
            
            // Convert functions
            body = this.convertFunctions(body);
            
            wgsl += body;
        }
        
        wgsl += '    return output;\n';
        wgsl += '}\n';
        
        return wgsl;
    }

    /**
     * Convert fragment shader from GLSL to WGSL
     */
    convertFragmentShader(glsl) {
        let wgsl = '';
        this.uniformBindings = [];
        this.bindingCounter = 0;
        
        // Extract helper functions first
        const helperFunctions = this.extractHelperFunctions(glsl);
        
        // Parse uniforms
        const uniformRegex = /uniform\s+(\w+)\s+(\w+);/g;
        const varyingRegex = /varying\s+(\w+)\s+(\w+);/g;
        
        const uniforms = [];
        const varyings = [];
        
        let match;
        while ((match = uniformRegex.exec(glsl)) !== null) {
            uniforms.push({ type: match[1], name: match[2] });
        }
        
        while ((match = varyingRegex.exec(glsl)) !== null) {
            varyings.push({ type: match[1], name: match[2] });
        }
        
        // Create uniform bindings
        const textureUniforms = uniforms.filter(u => u.type === 'sampler2D');
        const dataUniforms = uniforms.filter(u => u.type !== 'sampler2D');
        
        // Textures and samplers
        textureUniforms.forEach(texture => {
            wgsl += `@group(0) @binding(${this.bindingCounter++}) var ${texture.name}: texture_2d<f32>;\n`;
            wgsl += `@group(0) @binding(${this.bindingCounter++}) var ${texture.name}Sampler: sampler;\n`;
            this.uniformBindings.push(texture.name);
        });
        
        // Data uniforms in a struct
        if (dataUniforms.length > 0) {
            wgsl += '\nstruct Uniforms {\n';
            dataUniforms.forEach(uniform => {
                const wgslType = this.convertType(uniform.type);
                wgsl += `    ${uniform.name}: ${wgslType},\n`;
            });
            wgsl += '}\n';
            wgsl += `@group(0) @binding(${this.bindingCounter++}) var<uniform> uniforms: Uniforms;\n\n`;
        }
        
        // Add converted helper functions BEFORE the main fragment function
        if (helperFunctions.length > 0) {
            helperFunctions.forEach(helper => {
                const convertedHelper = this.convertHelperFunction(helper.code);
                wgsl += convertedHelper + '\n\n';
            });
        }
        
        // Fragment function
        wgsl += '@fragment\n';
        wgsl += 'fn fragmentMain(\n';
        
        // Add varyings as input
        if (varyings.length > 0) {
            varyings.forEach((varying, i) => {
                const wgslType = this.convertType(varying.type);
                wgsl += `    @location(${i}) ${varying.name}: ${wgslType}`;
                if (i < varyings.length - 1) wgsl += ',';
                wgsl += '\n';
            });
        }
        
        wgsl += ') -> @location(0) vec4f {\n';
        
        // Extract main function body
        const mainMatch = glsl.match(/void\s+main\s*\(\s*\)\s*{([\s\S]*?)}\s*$/m);
        if (mainMatch) {
            let body = mainMatch[1];
            
            // Replace gl_FragColor with return statement
            body = body.replace(/gl_FragColor\s*=\s*([^;]+);/g, 'return $1;');
            
            // Replace uniform references with uniforms struct
            dataUniforms.forEach(uniform => {
                const regex = new RegExp(`\\b${uniform.name}\\b`, 'g');
                body = body.replace(regex, `uniforms.${uniform.name}`);
            });
            
            // Convert variable declarations
            body = body.replace(/\b(float|vec2|vec3|vec4|int|bool)\s+(\w+)/g, (match, type, name) => {
                return `var ${name}: ${this.convertType(type)}`;
            });
            
            // Convert functions
            body = this.convertFunctions(body);
            
            wgsl += body;
        }
        
        wgsl += '}\n';
        
        return wgsl;
    }

    /**
     * Convert a complete shader file
     */
    convertShaderFile(inputPath, outputPath) {
        console.log(`Converting: ${inputPath}`);
        
        const content = fs.readFileSync(inputPath, 'utf8');
        
        // Extract shader config
        const vertexMatch = content.match(/vertexShader:\s*`([\s\S]*?)`/);
        const fragmentMatch = content.match(/fragmentShader:\s*`([\s\S]*?)`/);
        
        if (!vertexMatch || !fragmentMatch) {
            console.error(`  ✗ Could not parse shader config from ${inputPath}`);
            return false;
        }
        
        const vertexGLSL = vertexMatch[1];
        const fragmentGLSL = fragmentMatch[1];
        
        try {
            // Convert shaders
            const vertexWGSL = this.convertVertexShader(vertexGLSL);
            const fragmentWGSL = this.convertFragmentShader(fragmentGLSL);
            
            // Create new file content
            const newContent = content
                .replace(/vertexShader:\s*`[\s\S]*?`/, `vertexShader: \`${vertexWGSL}\``)
                .replace(/fragmentShader:\s*`[\s\S]*?`/, `fragmentShader: \`${fragmentWGSL}\``);
            
            // Add API version marker
            const finalContent = newContent.replace(
                /function getShaderConfig\(\)/,
                `function getShaderConfig() {\n    // WGSL shader (WebGPU) - Auto-converted from GLSL`
            );
            
            fs.writeFileSync(outputPath, finalContent);
            console.log(`  ✓ Converted successfully`);
            console.log(`    Bindings used: ${this.bindingCounter}`);
            return true;
            
        } catch (error) {
            console.error(`  ✗ Conversion failed: ${error.message}`);
            return false;
        }
    }

    /**
     * Convert all shader files in a directory
     */
    convertDirectory(inputDir, outputDir) {
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        const files = fs.readdirSync(inputDir);
        const shaderFiles = files.filter(f => f.endsWith('.js'));
        
        console.log(`Found ${shaderFiles.length} shader files\n`);
        
        let successCount = 0;
        let failCount = 0;
        
        shaderFiles.forEach(file => {
            const inputPath = path.join(inputDir, file);
            const outputPath = path.join(outputDir, file.replace('.js', '.wgsl.js'));
            
            if (this.convertShaderFile(inputPath, outputPath)) {
                successCount++;
            } else {
                failCount++;
            }
        });
        
        console.log(`\n=== Conversion Summary ===`);
        console.log(`✓ Success: ${successCount}`);
        console.log(`✗ Failed:  ${failCount}`);
        console.log(`\nNote: Manual review recommended for:
- Helper functions
- Complex math operations
- Custom texture sampling
- Integer/float type conversions`);
    }
}

// CLI usage
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length < 2) {
        console.log(`Usage: node glsl_to_wgsl.js <input-dir> <output-dir>`);
        console.log(`Example: node glsl_to_wgsl.js docs/shaders docs/shaders/wgsl`);
        process.exit(1);
    }
    
    const [inputDir, outputDir] = args;
    
    if (!fs.existsSync(inputDir)) {
        console.error(`Input directory not found: ${inputDir}`);
        process.exit(1);
    }
    
    const converter = new GLSLtoWGSLConverter();
    converter.convertDirectory(inputDir, outputDir);
}

module.exports = GLSLtoWGSLConverter;
