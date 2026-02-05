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

// ================================================================
// WGSL FRAGMENT SHADER INJECTION (from markdown code blocks)
// ================================================================

/**
 * Inject a WGSL fragment shader from user markdown code blocks
 * Called via webgpu_bridge_extern.js from Nim
 * 
 * @param {string} name - Shader name
 * @param {string} vertexCode - Vertex shader WGSL (empty if included in fragment)
 * @param {string} fragmentCode - Fragment shader WGSL
 * @param {string} uniformsJson - JSON string of uniforms object
 * @returns {number} - 1 on success, 0 on failure
 */
window.tStorie_injectWGSLShader = function(name, vertexCode, fragmentCode, uniformsJson) {
  console.log('[WGSL Bridge] tStorie_injectWGSLShader called:', name);
  
  try {
    // === SAFETY LAYER 1: Circuit Breaker ===
    if (!window._shaderSafety) {
      window._shaderSafety = {
        failureCount: 0,
        maxFailures: 3,
        cooldownUntil: 0
      };
    }
    
    const now = Date.now();
    if (window._shaderSafety.failureCount >= window._shaderSafety.maxFailures) {
      if (now < window._shaderSafety.cooldownUntil) {
        console.error('[WGSL SAFETY] Circuit breaker OPEN - shader system disabled');
        return 0;
      } else {
        console.log('[WGSL SAFETY] Circuit breaker reset after cooldown');
        window._shaderSafety.failureCount = 0;
      }
    }
    
    // === SAFETY LAYER 2: Input Validation ===
    if (!name || !/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/.test(name)) {
      console.error('[WGSL SAFETY] Invalid shader name:', name);
      window._shaderSafety.failureCount++;
      return 0;
    }
    
    if (fragmentCode.length > 500000 || vertexCode.length > 500000) {
      console.error('[WGSL SAFETY] Shader code too large (max 500KB)');
      window._shaderSafety.failureCount++;
      return 0;
    }
    
    // === SAFETY LAYER 3: Parse Uniforms ===
    let uniforms = {};
    try {
      uniforms = JSON.parse(uniformsJson);
      
      const uniformNames = Object.keys(uniforms);
      if (uniformNames.length > 64) {
        console.error('[WGSL SAFETY] Too many uniforms (max 64):', uniformNames.length);
        window._shaderSafety.failureCount++;
        return 0;
      }
      
      for (const uname of uniformNames) {
        if (!/^[a-zA-Z_][a-zA-Z0-9_]{0,63}$/.test(uname)) {
          console.error('[WGSL SAFETY] Invalid uniform name:', uname);
          window._shaderSafety.failureCount++;
          return 0;
        }
      }
      
      console.log('[WGSL Bridge] Validated', uniformNames.length, 'uniforms:', uniformNames);
    } catch (e) {
      console.error('[WGSL SAFETY] Failed to parse uniforms JSON:', e);
      window._shaderSafety.failureCount++;
      return 0;
    }
    
    // === SAFETY LAYER 4: Register Shader ===
    if (!window.shaderCodes) {
      window.shaderCodes = [];
    }
    
    // Check for duplicates
    const existingIdx = window.shaderCodes.findIndex(s => s.name === name);
    if (existingIdx >= 0) {
      console.warn('[WGSL Bridge] Shader already registered - skipping:', name);
      return 1; // Success - already registered
    }
    
    // Build shader config
    // Note: We combine vertex+fragment into fragmentShader field if vertex is empty
    const combinedCode = vertexCode ? vertexCode + '\n' + fragmentCode : fragmentCode;
    
    const shaderConfig = {
      name: name,
      content: `function getShaderConfig() { 
        return { 
          vertexShader: \`${vertexCode}\`, 
          fragmentShader: \`${combinedCode}\`, 
          uniforms: ${JSON.stringify(uniforms)} 
        }; 
      }`
    };
    
    window.shaderCodes.push(shaderConfig);
    window.shaderReady = true;
    
    console.log('[WGSL Bridge] ✓ Registered shader:', name, '(total:', window.shaderCodes.length, ')');
    
    // Initialize shader system (like frontmatter loader does)
    if (typeof window.initShaderSystem === 'function') {
      console.log('[WGSL Bridge] Initializing shader system...');
      try {
        // initShaderSystem is async but we can't await here
        // It will complete in the background and set window.shaderSystem when ready
        window.initShaderSystem();
        console.log('[WGSL Bridge] Shader system initialization started (async)');
      } catch (error) {
        console.error('[WGSL Bridge] Failed to start shader system:', error);
      }
    } else {
      console.warn('[WGSL Bridge] Shader system not available - initShaderSystem not found');
    }
    
    // Success - reset failure count
    window._shaderSafety.failureCount = 0;
    return 1;
    
  } catch (error) {
    console.error('[WGSL SAFETY] CRITICAL ERROR:', error);
    console.error('[WGSL SAFETY] Stack:', error.stack);
    
    if (window._shaderSafety) {
      window._shaderSafety.failureCount++;
      window._shaderSafety.cooldownUntil = Date.now() + 5000; // 5 sec cooldown
      
      if (window._shaderSafety.failureCount >= window._shaderSafety.maxFailures) {
        console.error('[WGSL SAFETY] Circuit breaker TRIGGERED - shader system disabled');
      }
    }
    return 0;
  }
};

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
