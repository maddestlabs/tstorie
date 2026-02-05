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

// Compute shader pipeline cache: code hash → pipeline
const computePipelineCache = new Map();

// Hash function for compute shader code
function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0; // Convert to 32-bit integer
  }
  return hash.toString(36);
}

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
    
    if (!window.webgpuBridge || !window.webgpuBridge.device) {
        console.warn('[WGSL Runtime] WebGPU not initialized');
        return false;
    }
    
    const device = window.webgpuBridge.device;
    const codeHash = hashString(code);
    console.log('[WGSL Runtime] Code hash:', codeHash);
    
    try {
        // Get or create cached pipeline
        let pipeline = computePipelineCache.get(codeHash);
        if (!pipeline) {
            console.log('[WGSL Runtime] Compiling new compute pipeline...');
            const shaderModule = device.createShaderModule({
                code: code,
                label: 'Compute Shader'
            });
            
            // Use async pipeline creation (faster, non-blocking)
            pipeline = await device.createComputePipelineAsync({
                layout: 'auto',
                compute: { 
                    module: shaderModule, 
                    entryPoint: 'main' 
                }
            });
            
            computePipelineCache.set(codeHash, pipeline);
            console.log('[WGSL Runtime] ✓ Pipeline cached');
        } else {
            console.log('[WGSL Runtime] ✓ Using cached pipeline');
        }
        
        // Create buffers
        const inputBuffer = device.createBuffer({
            size: inputData.length * 4,  // u32 = 4 bytes
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true
        });
        new Float32Array(inputBuffer.getMappedRange()).set(inputData);
        inputBuffer.unmap();
        
        const outputBuffer = device.createBuffer({
          size: outputData.length * 4,
          // COPY_DST so we can initialize from outputData.
          usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
        });
        // Initialize output buffer with the current contents of outputData.
        // This enables patterns where the compute shader reads initial values from the output buffer.
        device.queue.writeBuffer(outputBuffer, 0, outputData);
        
        const stagingBuffer = device.createBuffer({
            size: outputData.length * 4,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
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
    return window.webgpuBridge && window.webgpuBridge.device !== null;
};

/**
 * Run a compute shader asynchronously with callback (called from nimini)
 * @param {number} codePtr - WASM pointer to shader code string
 * @param {number} inputPtr - WASM pointer to input float array
 * @param {number} inputLen - Input array length
 * @param {number} outputPtr - WASM pointer to output float array
 * @param {number} outputLen - Output array length
 * @param {number} workX - Workgroup X size
 * @param {number} workY - Workgroup Y size
 * @param {number} workZ - Workgroup Z size
 * @param {number} callbackId - Callback ID to invoke when done
 * @returns {number} - 1 on success, 0 on failure
 */
window.tStorie_runComputeShaderAsync = async function(codePtr, inputPtr, inputLen, outputPtr, outputLen, workX, workY, workZ, callbackId) {
    if (!window.webgpuBridge?.device) {
        console.warn('[WGSL Runtime] WebGPU not initialized');
        return 0;
    }
    
    const device = window.webgpuBridge.device;
    
    try {
        // Convert WASM pointers to JavaScript
        const code = UTF8ToString(codePtr);
        const inputData = new Float32Array(HEAPF32.buffer, inputPtr, inputLen);
        const outputData = new Float32Array(HEAPF32.buffer, outputPtr, outputLen);
        const workgroupSize = [workX, workY, workZ];
        
        console.log('[WGSL Async] Starting compute shader, callback ID:', callbackId,
          'outputPtr:', outputPtr, 'outputLen:', outputLen,
          'heapBytes:', (typeof HEAPU8 !== 'undefined' ? HEAPU8.length : 'n/a'));
        
        // Use cached pipeline
        const codeHash = hashString(code);
        
        let pipeline = computePipelineCache.get(codeHash);
        if (!pipeline) {
            const shaderModule = device.createShaderModule({ code, label: 'Compute' });
            pipeline = await device.createComputePipelineAsync({
                layout: 'auto',
                compute: { module: shaderModule, entryPoint: 'main' }
            });
            computePipelineCache.set(codeHash, pipeline);
            console.log('[WGSL Async] ✓ Pipeline cached');
        } else {
            console.log('[WGSL Async] ✓ Using cached pipeline');
        }
        
        // Execute GPU work (same as sync version)
        const inputBuffer = device.createBuffer({
            size: inputLen * 4,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true
        });
        new Float32Array(inputBuffer.getMappedRange()).set(inputData);
        inputBuffer.unmap();
        
        const outputBuffer = device.createBuffer({
          size: outputLen * 4,
          // COPY_DST so we can initialize from outputData.
          usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
        });
        // Initialize output buffer with the current contents of outputData.
        // This enables patterns where the compute shader reads initial values from the output buffer.
        device.queue.writeBuffer(outputBuffer, 0, outputData);
        
        const stagingBuffer = device.createBuffer({
            size: outputLen * 4,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        });
        
        const bindGroup = device.createBindGroup({
            layout: pipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: { buffer: inputBuffer } },
                { binding: 1, resource: { buffer: outputBuffer } }
            ]
        });
        
        const commandEncoder = device.createCommandEncoder();
        const passEncoder = commandEncoder.beginComputePass();
        passEncoder.setPipeline(pipeline);
        passEncoder.setBindGroup(0, bindGroup);
        
        const workgroupCount = Math.ceil(outputLen / workgroupSize[0]);
        passEncoder.dispatchWorkgroups(workgroupCount, workgroupSize[1], workgroupSize[2]);
        passEncoder.end();
        
        commandEncoder.copyBufferToBuffer(outputBuffer, 0, stagingBuffer, 0, outputLen * 4);
        device.queue.submit([commandEncoder.finish()]);
        
        // Wait for GPU completion (non-blocking for browser)
        await device.queue.onSubmittedWorkDone();
        
        // Read back results
        await stagingBuffer.mapAsync(GPUMapMode.READ);
        const results = new Float32Array(stagingBuffer.getMappedRange());
        
        // Copy results back to WASM memory
        // IMPORTANT: Get current buffer after async operations (memory may have grown)
        // HEAP8 is a global that gets updated by Emscripten's updateMemoryViews()
        const currentOutputData = new Float32Array(HEAPF32.buffer, outputPtr, outputLen);
        currentOutputData.set(results.subarray(0, outputLen));
        
        stagingBuffer.unmap();
        
        // Cleanup
        inputBuffer.destroy();
        outputBuffer.destroy();
        stagingBuffer.destroy();
        
        console.log('[WGSL Async] ✓ Compute complete, invoking callback', callbackId,
          'outputPtr:', outputPtr, 'outputLen:', outputLen,
          'heapBytes:', (typeof HEAPU8 !== 'undefined' ? HEAPU8.length : 'n/a'));
        
        // Invoke callback (exported from WASM)
        Module._invokeComputeCallback(callbackId);
        
        return 1;  // Success
        
    } catch (error) {
        console.error('[WGSL Async] Compute shader execution failed:', error);
        return 0;
    }
};

/**
 * Run a compute shader synchronously (fire-and-forget, called from nimini)
 * @param {number} codePtr - WASM pointer to shader code string
 * @param {number} inputPtr - WASM pointer to input float array
 * @param {number} inputLen - Input array length
 * @param {number} outputPtr - WASM pointer to output float array
 * @param {number} outputLen - Output array length
 * @param {number} workX - Workgroup X size
 * @param {number} workY - Workgroup Y size
 * @param {number} workZ - Workgroup Z size
 * @returns {number} - 1 on success, 0 on failure
 */
window.tStorie_runComputeShaderSync = function(codePtr, inputPtr, inputLen, outputPtr, outputLen, workX, workY, workZ) {
    if (!window.webgpuBridge?.device) {
        console.warn('[WGSL Runtime] WebGPU not initialized');
        return 0;
    }
    
    try {
        // Convert WASM pointers to JavaScript
        const code = UTF8ToString(codePtr);
        const inputData = Array.from(new Float32Array(HEAPF32.buffer, inputPtr, inputLen));
        const outputData = new Float32Array(HEAPF32.buffer, outputPtr, outputLen);
        const workgroupSize = [workX, workY, workZ];
        
        console.log('[WGSL Sync] Starting compute shader (fire-and-forget)');
        
        // Call the async version and let it run in background
        window.runComputeShader(code, inputData, outputData, workgroupSize)
            .then(result => {
                console.log('[WGSL Sync] ✓ Compute completed');
                // Copy results back to WASM memory
                for (let i = 0; i < outputLen && i < result.length; i++) {
                    outputData[i] = result[i];
                }
            })
            .catch(error => {
                console.error('[WGSL Sync] Compute failed:', error);
            });
        
        return 1;  // Started successfully
        
    } catch (error) {
        console.error('[WGSL Sync] Failed to start compute shader:', error);
        return 0;
    }
};

console.log('[WGSL Runtime] Loaded - GPU compute shader support enabled');
