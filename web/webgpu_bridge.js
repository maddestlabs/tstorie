/**
 * TStorie WebGPU Bridge
 * 
 * Provides WebGPU compute shader capabilities to TStorie WASM.
 * Handles device initialization, shader compilation, buffer management, and execution.
 * 
 * PHASE 6: Now supports unified device management for compute + render pipelines
 */

class WebGPUBridge {
  constructor() {
    this.device = null;
    this.adapter = null;
    this.queue = null;
    this.pipelines = new Map(); // name -> ComputePipeline
    this.buffers = new Map();   // name -> GPUBuffer
    this.bindGroups = new Map(); // name -> GPUBindGroup
    this.shaderModules = new Map(); // name -> GPUShaderModule
    this.initialized = false;
    this.initPromise = null;
    
    // Phase 6: Renderer integration
    this.renderer = null;  // TStorieWebGPURender instance
    
    // Double buffering for noise shader execution
    this.currentNoiseBuffer = null;      // Current result buffer (keep alive)
    this.currentNoiseResults = null;     // Current results Uint32Array
    this.previousNoiseResources = null;  // Resources to cleanup from previous execution
  }
  
  /**
   * Get the shared WebGPU device
   * Can be used by renderer for unified context
   */
  getDevice() {
    return this.device;
  }
  
  /**
   * Check if device is initialized
   */
  isInitialized() {
    return this.initialized;
  }
  
  /**
   * Set renderer instance for unified device management
   */
  setRenderer(renderer) {
    this.renderer = renderer;
    console.log('[WebGPU] Renderer attached to bridge');
  }

  /**
   * Initialize WebGPU (async)
   * Must be called before any other operations
   */
  async init() {
    if (this.initialized) return true;
    if (this.initPromise) return this.initPromise;

    this.initPromise = (async () => {
      console.log('[WebGPU] Initializing...');

      // Check WebGPU support
      if (!navigator.gpu) {
        console.error('[WebGPU] WebGPU not supported in this browser');
        return false;
      }

      // Request adapter
      this.adapter = await navigator.gpu.requestAdapter({
        powerPreference: 'high-performance'
      });

      if (!this.adapter) {
        console.error('[WebGPU] Failed to get GPU adapter');
        return false;
      }

      console.log('[WebGPU] Adapter obtained:', this.adapter);

      // Request device
      this.device = await this.adapter.requestDevice({
        requiredLimits: {
          maxStorageBufferBindingSize: this.adapter.limits.maxStorageBufferBindingSize,
          maxComputeWorkgroupSizeX: 256,
          maxComputeWorkgroupSizeY: 256,
        }
      });

      if (!this.device) {
        console.error('[WebGPU] Failed to get GPU device');
        return false;
      }

      this.queue = this.device.queue;

      // Handle device lost
      this.device.lost.then((info) => {
        console.error('[WebGPU] Device lost:', info.message);
        this.initialized = false;
      });

      this.initialized = true;
      console.log('[WebGPU] Initialized successfully');
      return true;
    })();

    return this.initPromise;
  }

  /**
   * Compile a WGSL shader module
   * @param {string} name - Unique shader name
   * @param {string} wgslCode - WGSL shader source code
   * @returns {boolean} Success
   */
  compileShader(name, wgslCode) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    try {
      console.log(`[WebGPU] Compiling shader: ${name}`);
      
      const shaderModule = this.device.createShaderModule({
        code: wgslCode,
        label: `Shader: ${name}`
      });

      this.shaderModules.set(name, shaderModule);
      console.log(`[WebGPU] Shader compiled: ${name}`);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to compile shader ${name}:`, error);
      return false;
    }
  }

  /**
   * Create a compute pipeline from a compiled shader
   * @param {string} name - Pipeline name
   * @param {string} shaderName - Name of compiled shader module
   * @param {string} entryPoint - Entry point function name (default: "main")
   * @returns {boolean} Success
   */
  createPipeline(name, shaderName, entryPoint = 'main') {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    const shaderModule = this.shaderModules.get(shaderName);
    if (!shaderModule) {
      console.error(`[WebGPU] Shader module not found: ${shaderName}`);
      return false;
    }

    try {
      console.log(`[WebGPU] Creating pipeline: ${name}`);
      
      const pipeline = this.device.createComputePipeline({
        layout: 'auto',
        compute: {
          module: shaderModule,
          entryPoint: entryPoint
        },
        label: `Pipeline: ${name}`
      });

      this.pipelines.set(name, pipeline);
      console.log(`[WebGPU] Pipeline created: ${name}`);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to create pipeline ${name}:`, error);
      return false;
    }
  }

  /**
   * Create a storage buffer
   * @param {string} name - Buffer name
   * @param {number} size - Buffer size in bytes
   * @param {boolean} readable - Whether buffer can be read back to CPU
   * @returns {boolean} Success
   */
  createBuffer(name, size, readable = true) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    try {
      let usage = GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST;
      if (readable) {
        usage |= GPUBufferUsage.COPY_SRC;
      }

      const buffer = this.device.createBuffer({
        size: size,
        usage: usage,
        label: `Buffer: ${name}`
      });

      this.buffers.set(name, buffer);
      console.log(`[WebGPU] Buffer created: ${name} (${size} bytes)`);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to create buffer ${name}:`, error);
      return false;
    }
  }

  /**
   * Create a uniform buffer
   * @param {string} name - Buffer name
   * @param {number} size - Buffer size in bytes
   * @returns {boolean} Success
   */
  createUniformBuffer(name, size) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    try {
      const buffer = this.device.createBuffer({
        size: size,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        label: `Uniform: ${name}`
      });

      this.buffers.set(name, buffer);
      console.log(`[WebGPU] Uniform buffer created: ${name} (${size} bytes)`);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to create uniform buffer ${name}:`, error);
      return false;
    }
  }

  /**
   * Write data to a buffer
   * @param {string} name - Buffer name
   * @param {Uint32Array|ArrayBuffer} data - Data to write
   * @param {number} offset - Byte offset (default: 0)
   * @returns {boolean} Success
   */
  writeBuffer(name, data, offset = 0) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    const buffer = this.buffers.get(name);
    if (!buffer) {
      console.error(`[WebGPU] Buffer not found: ${name}`);
      return false;
    }

    try {
      this.queue.writeBuffer(buffer, offset, data);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to write buffer ${name}:`, error);
      return false;
    }
  }

  /**
   * Create a bind group for a pipeline
   * @param {string} name - Bind group name
   * @param {string} pipelineName - Pipeline name
   * @param {Array} bindings - Array of {binding: number, bufferName: string}
   * @returns {boolean} Success
   */
  createBindGroup(name, pipelineName, bindings) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    const pipeline = this.pipelines.get(pipelineName);
    if (!pipeline) {
      console.error(`[WebGPU] Pipeline not found: ${pipelineName}`);
      return false;
    }

    try {
      const entries = bindings.map(b => {
        const buffer = this.buffers.get(b.bufferName);
        if (!buffer) {
          throw new Error(`Buffer not found: ${b.bufferName}`);
        }
        return {
          binding: b.binding,
          resource: { buffer: buffer }
        };
      });

      const bindGroup = this.device.createBindGroup({
        layout: pipeline.getBindGroupLayout(0),
        entries: entries,
        label: `BindGroup: ${name}`
      });

      this.bindGroups.set(name, bindGroup);
      console.log(`[WebGPU] Bind group created: ${name}`);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to create bind group ${name}:`, error);
      return false;
    }
  }

  /**
   * Dispatch a compute shader
   * @param {string} pipelineName - Pipeline to execute
   * @param {string} bindGroupName - Bind group to use
   * @param {number} workgroupsX - Number of workgroups in X dimension
   * @param {number} workgroupsY - Number of workgroups in Y dimension
   * @param {number} workgroupsZ - Number of workgroups in Z dimension (default: 1)
   * @returns {boolean} Success
   */
  dispatch(pipelineName, bindGroupName, workgroupsX, workgroupsY, workgroupsZ = 1) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return false;
    }

    const pipeline = this.pipelines.get(pipelineName);
    const bindGroup = this.bindGroups.get(bindGroupName);

    if (!pipeline) {
      console.error(`[WebGPU] Pipeline not found: ${pipelineName}`);
      return false;
    }
    if (!bindGroup) {
      console.error(`[WebGPU] Bind group not found: ${bindGroupName}`);
      return false;
    }

    try {
      const commandEncoder = this.device.createCommandEncoder({
        label: `Dispatch: ${pipelineName}`
      });

      const passEncoder = commandEncoder.beginComputePass({
        label: `Compute: ${pipelineName}`
      });

      passEncoder.setPipeline(pipeline);
      passEncoder.setBindGroup(0, bindGroup);
      passEncoder.dispatchWorkgroups(workgroupsX, workgroupsY, workgroupsZ);
      passEncoder.end();

      this.queue.submit([commandEncoder.finish()]);
      return true;
    } catch (error) {
      console.error(`[WebGPU] Failed to dispatch ${pipelineName}:`, error);
      return false;
    }
  }

  /**
   * Read data back from a buffer (async)
   * @param {string} name - Buffer name
   * @param {number} size - Number of bytes to read
   * @returns {Promise<Uint32Array|null>} Buffer data or null on error
   */
  async readBuffer(name, size) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized');
      return null;
    }

    const buffer = this.buffers.get(name);
    if (!buffer) {
      console.error(`[WebGPU] Buffer not found: ${name}`);
      return null;
    }

    try {
      // Create staging buffer
      const stagingBuffer = this.device.createBuffer({
        size: size,
        usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
        label: `Staging: ${name}`
      });

      // Copy GPU buffer to staging buffer
      const commandEncoder = this.device.createCommandEncoder();
      commandEncoder.copyBufferToBuffer(buffer, 0, stagingBuffer, 0, size);
      this.queue.submit([commandEncoder.finish()]);

      // Map staging buffer and read
      await stagingBuffer.mapAsync(GPUMapMode.READ);
      const arrayBuffer = stagingBuffer.getMappedRange(0, size);
      const data = new Uint32Array(arrayBuffer.slice(0));
      stagingBuffer.unmap();
      stagingBuffer.destroy();

      return data;
    } catch (error) {
      console.error(`[WebGPU] Failed to read buffer ${name}:`, error);
      return null;
    }
  }

  /**
   * Destroy a resource
   * @param {string} type - 'buffer', 'pipeline', 'bindGroup', 'shader'
   * @param {string} name - Resource name
   */
  destroy(type, name) {
    switch (type) {
      case 'buffer':
        const buffer = this.buffers.get(name);
        if (buffer) {
          buffer.destroy();
          this.buffers.delete(name);
        }
        break;
      case 'pipeline':
        this.pipelines.delete(name);
        break;
      case 'bindGroup':
        this.bindGroups.delete(name);
        break;
      case 'shader':
        this.shaderModules.delete(name);
        break;
    }
  }

  /**
   * Get info about the GPU device
   * @returns {object} Device info
   */
  getDeviceInfo() {
    if (!this.initialized) return null;
    
    return {
      vendor: this.adapter.info?.vendor || 'unknown',
      architecture: this.adapter.info?.architecture || 'unknown',
      device: this.adapter.info?.device || 'unknown',
      description: this.adapter.info?.description || 'unknown',
      limits: {
        maxComputeWorkgroupSizeX: this.device.limits.maxComputeWorkgroupSizeX,
        maxComputeWorkgroupSizeY: this.device.limits.maxComputeWorkgroupSizeY,
        maxComputeWorkgroupSizeZ: this.device.limits.maxComputeWorkgroupSizeZ,
        maxStorageBufferBindingSize: this.device.limits.maxStorageBufferBindingSize,
      }
    };
  }

  /**
   * High-level method: Execute noise shader and return results using double buffering
   * @param {string} wgslCode - Complete WGSL shader code
   * @param {number} width - Output width
   * @param {number} height - Output height
   * @param {number} offsetX - X offset for sampling
   * @param {number} offsetY - Y offset for sampling
   * @returns {Promise<Uint32Array|null>} Noise values [0..65535] or null on error
   */
  async executeNoiseShader(wgslCode, width, height, offsetX = 0, offsetY = 0) {
    if (!this.initialized) {
      console.error('[WebGPU] Not initialized - cannot execute shader');
      return null;
    }

    const timestamp = Date.now();
    const shaderName = `noise_${timestamp}`;
    const pipelineName = `pipeline_${timestamp}`;
    const bindGroupName = `bindgroup_${timestamp}`;
    const outputBufferName = `output_${timestamp}`;
    const paramsBufferName = `params_${timestamp}`;

    try {
      // Clean up resources from PREVIOUS execution (not current one)
      // This implements double buffering - old results stay alive until new ones are ready
      if (this.previousNoiseResources) {
        console.log('[WebGPU] Cleaning up previous execution resources');
        const prev = this.previousNoiseResources;
        this.destroy('buffer', prev.outputBufferName);
        this.destroy('buffer', prev.paramsBufferName);
        this.destroy('bindGroup', prev.bindGroupName);
        this.destroy('pipeline', prev.pipelineName);
        this.destroy('shader', prev.shaderName);
        this.previousNoiseResources = null;
      }

      // Step 1: Compile shader
      console.log(`[WebGPU] Compiling shader (${wgslCode.length} bytes)`);
      if (!this.compileShader(shaderName, wgslCode)) {
        throw new Error('Shader compilation failed');
      }

      // Step 2: Create pipeline
      console.log('[WebGPU] Creating compute pipeline');
      if (!this.createPipeline(pipelineName, shaderName, 'main')) {
        throw new Error('Pipeline creation failed');
      }

      // Step 3: Create buffers
      const outputSize = width * height * 4; // u32 = 4 bytes
      console.log(`[WebGPU] Creating buffers: output=${outputSize} bytes`);
      
      if (!this.createBuffer(outputBufferName, outputSize, true)) {
        throw new Error('Output buffer creation failed');
      }
      
      // Uniform buffer: vec4<u32> = 16 bytes
      if (!this.createUniformBuffer(paramsBufferName, 16)) {
        throw new Error('Params buffer creation failed');
      }

      // Step 4: Write params buffer (width, height, offsetX, offsetY)
      const paramsData = new Uint32Array([width, height, offsetX, offsetY]);
      if (!this.writeBuffer(paramsBufferName, paramsData)) {
        throw new Error('Failed to write params buffer');
      }

      // Step 5: Create bind group
      console.log('[WebGPU] Creating bind group');
      if (!this.createBindGroup(bindGroupName, pipelineName, [
        { binding: 0, bufferName: outputBufferName },
        { binding: 1, bufferName: paramsBufferName }
      ])) {
        throw new Error('Bind group creation failed');
      }

      // Step 6: Dispatch compute shader
      // Workgroup size is 8x8, so we need ceil(width/8) x ceil(height/8) workgroups
      const workgroupsX = Math.ceil(width / 8);
      const workgroupsY = Math.ceil(height / 8);
      
      console.log(`[WebGPU] Dispatching: ${workgroupsX}x${workgroupsY} workgroups (${width}x${height} pixels)`);
      if (!this.dispatch(pipelineName, bindGroupName, workgroupsX, workgroupsY, 1)) {
        throw new Error('Dispatch failed');
      }

      // Step 7: Wait for completion and read results
      console.log('[WebGPU] Reading back results...');
      const results = await this.readBuffer(outputBufferName, outputSize);
      
      if (!results) {
        throw new Error('Failed to read results buffer');
      }

      // Step 8: Store current resources for cleanup on NEXT execution (double buffering)
      // This keeps the buffer alive so reads from the Nim side continue to work
      this.previousNoiseResources = {
        outputBufferName,
        paramsBufferName,
        bindGroupName,
        pipelineName,
        shaderName
      };
      
      this.currentNoiseBuffer = outputBufferName;
      this.currentNoiseResults = results;

      const elapsed = Date.now() - timestamp;
      console.log(`[WebGPU] Execution completed in ${elapsed}ms (${width * height} samples)`);
      console.log(`[WebGPU] Results buffered - will cleanup on next execution`);
      
      return results;
    } catch (error) {
      console.error('[WebGPU] executeNoiseShader failed:', error);
      
      // Cleanup on error (immediate cleanup for failed execution)
      this.destroy('buffer', outputBufferName);
      this.destroy('buffer', paramsBufferName);
      this.destroy('bindGroup', bindGroupName);
      this.destroy('pipeline', pipelineName);
      this.destroy('shader', shaderName);
      
      return null;
    }
  }

  /**
   * Check if WebGPU is available and initialized
   * @returns {boolean} True if ready to use
   */
  isReady() {
    return this.initialized;
  }

  /**
   * Check if WebGPU is supported in this browser
   * @returns {boolean} True if supported (may not be initialized yet)
   */
  isSupported() {
    return !!navigator.gpu;
  }
}

// Create global instance
window.webgpuBridge = new WebGPUBridge();

// Auto-initialize on load
window.addEventListener('load', async () => {
  const success = await window.webgpuBridge.init();
  if (success) {
    console.log('[WebGPU] Ready!');
    const info = window.webgpuBridge.getDeviceInfo();
    console.log('[WebGPU] Device:', info);
  } else {
    console.warn('[WebGPU] Initialization failed - compute shaders unavailable');
  }
});

console.log('[WebGPU Bridge] Loaded');
