/**
 * TStorie WebGPU Bridge
 * 
 * Provides WebGPU compute shader capabilities to TStorie WASM.
 * Handles device initialization, shader compilation, buffer management, and execution.
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
