/**
 * WGSL Shader Runtime for tstorie
 * 
 * Provides runtime GPU compute shader execution via WebGPU.
 * Called from nimini scripts via wgsl_bindings.nim.
 * 
 * Architecture:
 * - Shaders compiled on-demand from WGSL strings
 * - Uniform buffers updated per-frame
 * - Compute shaders execute asynchronously
 * - Results copied back to JavaScript arrays
 * 
 * Future: Native support via SDL3 GPU + SDL_shadercross
 */

// Shader cache: name → {pipeline, bindGroup, buffers}
const shaderCache = new Map();

// Uniform storage: name → {uniformData}
const shaderUniforms = new Map();

/**
 * Update shader uniform values (called from nimini)
 * @param {string} name - Shader name
 * @param {object} uniforms - Uniform values {fieldName: value, ...}
 */
window.updateShaderUniforms = function(name, uniforms) {
    shaderUniforms.set(name, uniforms);
};

/**
 * Run a compute shader (called from nimini)
 * @param {string} code - WGSL shader source code
 * @param {Array<number>} inputData - Input array
 * @param {Array<number>} outputData - Output array (will be filled)
 * @param {Array<number>} workgroupSize - [x, y, z] workgroup dimensions
 * @returns {Promise<boolean>} - True on success
 */
window.runComputeShader = async function(code, inputData, outputData, workgroupSize = [64, 1, 1]) {
    console.log('[WGSL Runtime] runComputeShader called:');
    console.log('  Code length:', code.length);
    console.log('  Input length:', inputData.length);
    console.log('  Output length:', outputData.length);
    console.log('  Workgroup size:', workgroupSize);
    
    if (!window.webgpuDevice || !window.webgpuDevice.device) {
        console.warn('[WGSL Runtime] WebGPU not initialized');
        return false;
    }
    
    const device = window.webgpuDevice.device;
    console.log('[WGSL Runtime] Using device:', device);
    
    try {
        // Create shader module
        console.log('[WGSL Runtime] Creating shader module...');
        const shaderModule = device.createShaderModule({
            code: code,
            label: 'Compute Shader'
        });
        console.log('[WGSL Runtime] Shader module created');
        
        // Create buffers
        const inputBuffer = device.createBuffer({
            size: inputData.length * 4,  // float32
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true
        });
        new Float32Array(inputBuffer.getMappedRange()).set(inputData);
        inputBuffer.unmap();
        
        const outputBuffer = device.createBuffer({
            size: outputData.length * 4,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC
        });
        
        const stagingBuffer = device.createBuffer({
            size: outputData.length * 4,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        });
        
        // Create pipeline
        const pipeline = device.createComputePipeline({
            layout: 'auto',
            compute: {
                module: shaderModule,
                entryPoint: 'main'
            }
        });
        
        // Create bind group
        const bindGroup = device.createBindGroup({
            layout: pipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: { buffer: inputBuffer } },
                { binding: 1, resource: { buffer: outputBuffer } }
            ]
        });
        
        // Execute
        const commandEncoder = device.createCommandEncoder();
        const passEncoder = commandEncoder.beginComputePass();
        passEncoder.setPipeline(pipeline);
        passEncoder.setBindGroup(0, bindGroup);
        
        const workgroupCount = Math.ceil(outputData.length / workgroupSize[0]);
        passEncoder.dispatchWorkgroups(workgroupCount, workgroupSize[1], workgroupSize[2]);
        passEncoder.end();
        
        // Copy results to staging buffer
        commandEncoder.copyBufferToBuffer(outputBuffer, 0, stagingBuffer, 0, outputData.length * 4);
        
        device.queue.submit([commandEncoder.finish()]);
        
        // Read back results
        await stagingBuffer.mapAsync(GPUMapMode.READ);
        const results = new Float32Array(stagingBuffer.getMappedRange());
        
        // Copy to output array
        for (let i = 0; i < outputData.length; i++) {
            outputData[i] = results[i];
        }
        
        stagingBuffer.unmap();
        
        console.log('[WGSL Runtime] Compute shader executed successfully, result[0]:', outputData[0]);
        
        // Cleanup
        inputBuffer.destroy();
        outputBuffer.destroy();
        stagingBuffer.destroy();
        
        return outputData;  // Return the array for promise resolution
        
    } catch (error) {
        console.error('[WGSL Runtime] Compute shader execution failed:', error);
        return false;
    }
};

/**
 * Check if WebGPU compute shaders are supported
 * @returns {boolean}
 */
window.webgpuComputeSupported = function() {
    return window.webgpuDevice && window.webgpuDevice.device !== null;
};

console.log('[WGSL Runtime] Loaded - GPU compute shader support enabled');
