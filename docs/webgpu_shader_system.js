/**
 * WebGPU Shader Chain System for TStorie
 * 
 * Renders multi-pass shader effects using WebGPU API
 * Similar to WebGL shader chain but using modern WebGPU architecture
 */

async function initWebGPUShaderSystem(shaderCodes) {
  console.log('[WebGPU Shaders] Initializing shader chain system');
  
  // Get terminal canvas and create WebGPU canvas
  const terminalCanvas = window.canvas || document.getElementById('terminal');
  if (!terminalCanvas) {
    console.error('[WebGPU Shaders] Terminal canvas not found');
    throw new Error('Terminal canvas not found');
  }
  
  // Check WebGPU availability
  if (!navigator.gpu || !window.webgpuBridge) {
    console.warn('[WebGPU Shaders] WebGPU not available');
    throw new Error('WebGPU not available');
  }
  
  try {
    // Ensure WebGPU bridge is initialized
    if (!window.webgpuBridge.initialized) {
      console.log('[WebGPU Shaders] Initializing WebGPU bridge...');
      await window.webgpuBridge.init();
    }
    
    const device = window.webgpuBridge.getDevice();
    if (!device) {
      console.error('[WebGPU Shaders] Failed to get WebGPU device');
      return initWebGLShaderSystem(shaderCodes);
    }
    
    // Get actual dimensions
    const width = terminalCanvas.width || 800;
    const height = terminalCanvas.height || 600;
    
    console.log('[WebGPU Shaders] Terminal dimensions:', width, 'x', height);
    
    // Create WebGPU canvas for shader output
    const webgpuCanvas = document.createElement('canvas');
    webgpuCanvas.id = 'terminal-webgpu';
    const dpr = window.devicePixelRatio || 1;
    webgpuCanvas.width = window.innerWidth * dpr;
    webgpuCanvas.height = window.innerHeight * dpr;
    webgpuCanvas.className = terminalCanvas.className;
    webgpuCanvas.style.position = 'absolute';
    webgpuCanvas.style.top = '0';
    webgpuCanvas.style.left = '0';
    webgpuCanvas.style.width = '100%';
    webgpuCanvas.style.height = '100%';
    webgpuCanvas.style.outline = 'none';
    webgpuCanvas.style.zIndex = '1'; // Explicitly above terminal
    webgpuCanvas.tabIndex = terminalCanvas.tabIndex || 0;
    
    // Keep terminal canvas visible but behind the WebGPU canvas
    // We need it visible to copy from it
    terminalCanvas.style.position = 'absolute';
    terminalCanvas.style.top = '0';
    terminalCanvas.style.left = '0';
    terminalCanvas.style.zIndex = '-1';
    terminalCanvas.style.pointerEvents = 'none';
    terminalCanvas.style.visibility = 'visible'; // Explicitly set visible for copying
    
    // Insert WebGPU canvas
    terminalCanvas.parentNode.insertBefore(webgpuCanvas, terminalCanvas.nextSibling);
    
    // Function to sync WebGPU canvas dimensions on window resize
    function syncWebGPUCanvasDimensions() {
      const dpr = window.devicePixelRatio || 1;
      const newWidth = window.innerWidth * dpr;
      const newHeight = window.innerHeight * dpr;
      
      // Only resize if dimensions actually changed
      if (webgpuCanvas.width !== newWidth || webgpuCanvas.height !== newHeight) {
        webgpuCanvas.width = newWidth;
        webgpuCanvas.height = newHeight;
        console.log('[WebGPU Shaders] Canvas resized to:', newWidth, 'x', newHeight);
      }
    }
    
    // Watch for window resize events
    window.addEventListener('resize', () => {
      requestAnimationFrame(syncWebGPUCanvasDimensions);
    });
    
    // Forward input events
    ['keydown', 'keyup', 'keypress', 'mousedown', 'mouseup', 'mousemove', 'click', 'wheel', 'contextmenu'].forEach(eventType => {
      webgpuCanvas.addEventListener(eventType, function(e) {
        if (eventType === 'contextmenu') {
          e.preventDefault();
        }
        const clonedEvent = new e.constructor(e.type, e);
        terminalCanvas.dispatchEvent(clonedEvent);
      });
    });
    
    // Get WebGPU context
    const context = webgpuCanvas.getContext('webgpu');
    if (!context) {
      console.error('[WebGPU Shaders] Failed to get WebGPU context');
      throw new Error('No WebGPU context');
    }
    
    const format = navigator.gpu.getPreferredCanvasFormat();
    context.configure({
      device,
      format,
      alphaMode: 'premultiplied',
    });
    
    console.log('[WebGPU Shaders] Canvas format:', format);
    
    // Compile shader pipelines
    const shaderPipelines = [];
    
    for (let i = 0; i < shaderCodes.length; i++) {
      const shader = shaderCodes[i];
      console.log('[WebGPU Shaders] Compiling', (i + 1), '/', shaderCodes.length, ':', shader.name);
      
      try {
        // Eval shader code to get config
        const getShaderConfig = (function() {
          eval(shader.content);
          if (typeof getShaderConfig !== 'function') {
            throw new Error('Shader must export getShaderConfig()');
          }
          return getShaderConfig();
        })();
        
        // Create WGSL shader module
        const shaderModule = device.createShaderModule({
          label: shader.name,
          code: getShaderConfig.vertexShader + '\n' + getShaderConfig.fragmentShader
        });
        
        // Check if shader has @group(0) bindings by looking for @group in the shader code
        const fullShaderCode = getShaderConfig.vertexShader + '\n' + getShaderConfig.fragmentShader;
        const hasBindings = fullShaderCode.includes('@group(0)');
        
        // Check if shader uses binding(2) for uniforms
        const usesUniformsBuffer = /\@binding\(2\)/.test(fullShaderCode);
        
        // Check for compilation errors
        const info = await shaderModule.getCompilationInfo();
        const errors = info.messages.filter(m => m.type === 'error');
        if (errors.length > 0) {
          console.error('[WebGPU Shaders] Compilation errors in', shader.name + ':', errors);
          throw new Error('Shader compilation failed: ' + shader.name);
        }
        
        // Create render pipeline
        const pipeline = device.createRenderPipeline({
          label: shader.name + '_pipeline',
          layout: 'auto',
          vertex: {
            module: shaderModule,
            entryPoint: 'vertexMain',
            buffers: [{
              arrayStride: 8, // 2 floats * 4 bytes
              attributes: [{
                shaderLocation: 0,
                offset: 0,
                format: 'float32x2'
              }]
            }]
          },
          fragment: {
            module: shaderModule,
            entryPoint: 'fragmentMain',
            targets: [{
              format: format
            }]
          },
          primitive: {
            topology: 'triangle-list'
          }
        });
        
        shaderPipelines.push({
          name: shader.name,
          pipeline: pipeline,
          module: shaderModule,
          uniforms: getShaderConfig.uniforms || {},
          hasBindings: hasBindings,
          usesUniformsBuffer: usesUniformsBuffer
        });
        
        console.log('[WebGPU Shaders] ✓ Compiled:', shader.name);
        
      } catch (error) {
        console.error('[WebGPU Shaders] Failed to compile', shader.name + ':', error);
        throw error;
      }
    }
    
    console.log('[WebGPU Shaders] Successfully compiled', shaderPipelines.length, 'pipeline(s)');
    
    // Create fullscreen quad vertex buffer
    const vertices = new Float32Array([
      -1, -1,  1, -1,  -1, 1,
      -1, 1,   1, -1,   1, 1
    ]);
    
    const vertexBuffer = device.createBuffer({
      label: 'fullscreen_quad',
      size: vertices.byteLength,
      usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(vertexBuffer, 0, vertices);
    
    // Create textures for intermediate passes
    const intermediateTextures = [];
    for (let i = 0; i < shaderPipelines.length - 1; i++) {
      const texture = device.createTexture({
        label: `intermediate_${i}`,
        size: [webgpuCanvas.width, webgpuCanvas.height],
        format: format,
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
      });
      intermediateTextures.push(texture);
    }
    
    // Create sampler
    const sampler = device.createSampler({
      magFilter: 'linear',
      minFilter: 'linear',
      addressModeU: 'clamp-to-edge',
      addressModeV: 'clamp-to-edge',
    });
    
    // Create per-shader uniform buffers (each shader gets its own buffer)
    const shaderUniformBuffers = [];
    for (let i = 0; i < shaderPipelines.length; i++) {
      const shader = shaderPipelines[i];
      if (shader.usesUniformsBuffer) {
        const buffer = device.createBuffer({
          label: `uniforms_${shader.name}`,
          size: 256, // Enough for time, resolution, and custom shader uniforms
          usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });
        shaderUniformBuffers.push(buffer);
      } else {
        shaderUniformBuffers.push(null); // No buffer for shaders without uniforms
      }
    }
    
    // Create persistent terminal texture for canvas copy
    const terminalTexture = device.createTexture({
      label: 'terminal_input',
      size: [terminalCanvas.width, terminalCanvas.height],
      format: 'rgba8unorm', // Use rgba8unorm for ImageBitmap compatibility
      usage: GPUTextureUsage.TEXTURE_BINDING | 
             GPUTextureUsage.COPY_DST | 
             GPUTextureUsage.RENDER_ATTACHMENT
    });
    
    console.log('[WebGPU Shaders] Created terminal texture:', terminalCanvas.width + 'x' + terminalCanvas.height);
    
    // Store shader system globally
    window.shaderSystem = {
      backend: 'webgpu',
      device: device,
      context: context,
      canvas: webgpuCanvas,
      terminalCanvas: terminalCanvas,
      terminalTexture: terminalTexture,
      pipelines: shaderPipelines,
      vertexBuffer: vertexBuffer,
      intermediateTextures: intermediateTextures,
      sampler: sampler,
      shaderUniformBuffers: shaderUniformBuffers, // Per-shader uniform buffers
      format: format,
      startTime: performance.now(),
      frameCount: 0,
      render: renderWebGPUShaderChain
    };
    
    window.terminalCanvas = terminalCanvas;
    
    console.log('[WebGPU Shaders] Shader chain initialized:', 
                shaderPipelines.map(p => p.name).join(' → '));
    
    // Instead of independent render loop, hook into terminal's render cycle
    // This eliminates flickering by ensuring shader system only samples fully rendered frames
    let renderRequested = false;
    
    window.shaderSystem.onTerminalRenderComplete = function() {
      if (!renderRequested) {
        renderRequested = true;
        // Use setImmediate-like behavior via Promise microtask
        Promise.resolve().then(async () => {
          renderRequested = false;
          await renderWebGPUShaderChain();
        });
      }
    };
    
    console.log('[WebGPU Shaders] Synchronized with terminal render loop');
    console.log('[WebGPU Shaders] Render loop started');
    console.log('[WebGPU Shaders] WebGPU canvas:', webgpuCanvas.id, webgpuCanvas.width + 'x' + webgpuCanvas.height);
    console.log('[WebGPU Shaders] Terminal canvas:', terminalCanvas.id, terminalCanvas.width + 'x' + terminalCanvas.height);
    
  } catch (error) {
    console.error('[WebGPU Shaders] Initialization failed:', error);
    console.log('[WebGPU Shaders] WebGPU shaders not available - page needs to reload WebGL shaders');
    throw error; // Let caller handle fallback by reloading appropriate shaders
  }
}

function renderWebGPUShaderChain() {
  return (async function() {
    try {
    const system = window.shaderSystem;
    if (!system || system.backend !== 'webgpu') return;
    
    try {
      const device = system.device;
      const context = system.context;
      const terminalCanvas = system.terminalCanvas;
      
      // Check if terminal canvas size changed - recreate texture if needed
      if (system.terminalTexture.width !== terminalCanvas.width || 
          system.terminalTexture.height !== terminalCanvas.height) {
        console.log('[WebGPU Shaders] Terminal canvas resized:', 
                    system.terminalTexture.width + 'x' + system.terminalTexture.height,
                    '→', terminalCanvas.width + 'x' + terminalCanvas.height);
        
        // Recreate terminal texture with new dimensions
        system.terminalTexture.destroy();
        system.terminalTexture = device.createTexture({
          label: 'terminal_input',
          size: [terminalCanvas.width, terminalCanvas.height],
          format: 'rgba8unorm',
          usage: GPUTextureUsage.TEXTURE_BINDING | 
                 GPUTextureUsage.COPY_DST | 
                 GPUTextureUsage.RENDER_ATTACHMENT
        });
      }
    
    // Only log first frame to avoid spam
    if (system.frameCount === 0) {
      console.log('[WebGPU Shaders] First frame render starting...');
    }
    
    // Get texture references from system (terminalCanvas already declared above)
    const terminalTexture = system.terminalTexture;
    
    if (system.frameCount === 0) {
      console.log('[WebGPU Shaders] Terminal canvas:', terminalCanvas.width, 'x', terminalCanvas.height);
    }
    
    // Check if terminal has content
    if (terminalCanvas.width === 0 || terminalCanvas.height === 0) {
      console.warn('[WebGPU Shaders] Terminal canvas has zero dimensions, skipping frame');
      return; // Skip this frame, render loop will retry
    }
    
    // Copy terminal canvas to texture (only needed for shaders with bindings)
    const needsTerminalInput = system.pipelines.some(p => p.hasBindings);
    
    if (needsTerminalInput) {
      if (system.frameCount === 0) {
        console.log('[WebGPU Shaders] Copying terminal canvas (shader chain uses bindings)...');
      }
      
      try {
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Using writeTexture method (avoids copyExternalImageToTexture crash)...');
        }
        
        // Alternative approach: get pixel data from canvas and write to texture
        // This avoids the copyExternalImageToTexture GPU driver crash
        const ctx2d = document.createElement('canvas').getContext('2d');
        const tempCanvas = ctx2d.canvas;
        tempCanvas.width = terminalCanvas.width;
        tempCanvas.height = terminalCanvas.height;
        ctx2d.drawImage(terminalCanvas, 0, 0);
        
        const imageData = ctx2d.getImageData(0, 0, terminalCanvas.width, terminalCanvas.height);
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Got image data:', imageData.width + 'x' + imageData.height);
          console.log('[WebGPU Shaders] Writing to texture...');
        }
        
        device.queue.writeTexture(
          { texture: terminalTexture },
          imageData.data,
          { 
            offset: 0,
            bytesPerRow: terminalCanvas.width * 4,
            rowsPerImage: terminalCanvas.height
          },
          {
            width: terminalCanvas.width,
            height: terminalCanvas.height,
            depthOrArrayLayers: 1
          }
        );
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] ✓ Terminal canvas copied successfully via writeTexture');
        }
      } catch (e) {
        console.error('[WebGPU Shaders] Failed to copy terminal canvas:', e);
        return;
      }
    } else {
      if (system.frameCount === 0) {
        console.log('[WebGPU Shaders] Skipping canvas copy (no shaders use bindings)');
      }
    }
    
    if (system.frameCount === 0) {
      console.log('[WebGPU Shaders] Creating command encoder...');
    }
    
    const encoder = device.createCommandEncoder();
    
    if (system.frameCount === 0) {
      console.log('[WebGPU Shaders] Command encoder created');
    }
    
    // Update uniforms for each shader that needs them
    const currentTime = (performance.now() - system.startTime) / 1000.0;
    
    for (let i = 0; i < system.pipelines.length; i++) {
      const shader = system.pipelines[i];
      const uniformBuffer = system.shaderUniformBuffers[i];
      
      if (!uniformBuffer) continue; // Skip shaders without uniforms
      
      // Build uniform array for this specific shader
      const uniformArray = [
        currentTime,                      // time (f32)
        0, 0, 0,                          // padding
        system.terminalCanvas.width,      // resolution.x - terminal canvas size for pixel-accurate cell-aligned shaders
        system.terminalCanvas.height,     // resolution.y
        0, 0                              // padding after resolution
      ];
      
      // Add this shader's custom uniforms in the order they appear in the uniforms object
      // JavaScript object iteration order is insertion order (ES2015+)
      const uniformNames = Object.keys(shader.uniforms);
      
      for (const name of uniformNames) {
        let value = shader.uniforms[name];
        
        // Special handling for cellSize - get live values from terminal (with DPR scaling)
        if (name === 'cellSize' && window.terminal) {
          const t = window.terminal;
          // Prefer deriving cell size from the *actual* terminal canvas pixel grid.
          // This avoids accumulating drift if canvas.width/height were rounded.
          if (t.cols && t.rows && system.terminalCanvas && system.terminalCanvas.width > 0 && system.terminalCanvas.height > 0) {
            value = [
              system.terminalCanvas.width / t.cols,
              system.terminalCanvas.height / t.rows
            ];
          } else {
            const dpr = window.devicePixelRatio || 1;
            value = [t.charWidth * dpr, t.charHeight * dpr];
          }
          
          if (system.frameCount === 0) {
            console.log(`[WebGPU Shaders] ${shader.name} cellSize:`, value, 'terminal:', t.cols + 'x' + t.rows, 'canvas:', system.terminalCanvas.width + 'x' + system.terminalCanvas.height);
          }
        }
        
        if (system.frameCount === 0 && name !== 'cellSize') {
          console.log(`[WebGPU Shaders] ${shader.name} uniform ${name}:`, value);
        }
        
        if (typeof value === 'number') {
          uniformArray.push(value);
          // Don't pad individual numbers - let them pack naturally
        } else if (Array.isArray(value)) {
          if (value.length === 2) {
            uniformArray.push(value[0], value[1]);
            // vec2 - add 2 padding floats to reach vec4 alignment
            uniformArray.push(0, 0);
          } else if (value.length === 3) {
            uniformArray.push(value[0], value[1], value[2]);
            // vec3 - add 1 padding float to reach vec4 alignment
            uniformArray.push(0);
          } else if (value.length === 4) {
            uniformArray.push(value[0], value[1], value[2], value[3]);
          }
        }
      }
      
      // Pad the final array to vec4 alignment
      while (uniformArray.length % 4 !== 0) {
        uniformArray.push(0);
      }
      
      const uniformData = new Float32Array(uniformArray);
      
      if (system.frameCount === 0) {
        console.log(`[WebGPU Shaders] ${shader.name} uniform buffer (${uniformData.length} floats):`, Array.from(uniformData));
      }
      
      device.queue.writeBuffer(uniformBuffer, 0, uniformData);
    }
    
    // Render shader chain
    let inputTexture = terminalTexture;
    
    if (system.frameCount === 0) {
      console.log('[WebGPU Shaders] Starting shader chain with', system.pipelines.length, 'shader(s)');
    }
    
    for (let i = 0; i < system.pipelines.length; i++) {
      const shader = system.pipelines[i];
      const isLastShader = i === system.pipelines.length - 1;
      
      if (system.frameCount === 0) {
        console.log('[WebGPU Shaders] Rendering shader', i, ':', shader.name);
        console.log('[WebGPU Shaders] Is last shader?', isLastShader);
      }
      
      let outputTexture;
      let renderPass;
      try {
        outputTexture = isLastShader ? 
          context.getCurrentTexture() : 
          system.intermediateTextures[i];
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Creating render pass...');
        }
        
        renderPass = encoder.beginRenderPass({
          colorAttachments: [{
            view: outputTexture.createView(),
            loadOp: 'clear',
            storeOp: 'store',
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          }],
        });
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Setting pipeline...');
        }
        renderPass.setPipeline(shader.pipeline);
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Setting vertex buffer...');
        }
        renderPass.setVertexBuffer(0, system.vertexBuffer);
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Checking for bindings...');
        }
        
        // Only create and set bind group if shader actually has bindings
        if (shader.hasBindings) {
          try {
            const bindGroupLayout = shader.pipeline.getBindGroupLayout(0);
            
            if (system.frameCount === 0) {
              console.log('[WebGPU Shaders] Creating bind group for', shader.name);
            }
            
            // Create bind group with correct number of bindings
            let entries;
            if (shader.usesUniformsBuffer) {
              // Shader needs all 3 bindings - use per-shader uniform buffer
              const uniformBuffer = system.shaderUniformBuffers[i];
              entries = [
                { binding: 0, resource: inputTexture.createView() },
                { binding: 1, resource: system.sampler },
                { binding: 2, resource: { buffer: uniformBuffer } }
              ];
            } else {
              // Shader only needs texture and sampler
              entries = [
                { binding: 0, resource: inputTexture.createView() },
                { binding: 1, resource: system.sampler }
              ];
            }
            
            const bindGroup = device.createBindGroup({
              layout: bindGroupLayout,
              entries: entries
            });
            
            if (system.frameCount === 0) {
              console.log('[WebGPU Shaders] Bind group created with', entries.length, 'bindings');
            }
            
            renderPass.setBindGroup(0, bindGroup);
          } catch (e) {
            console.error('[WebGPU Shaders] Failed to create bind group:', e);
          }
        } else {
          if (system.frameCount === 0) {
            console.log('[WebGPU Shaders] Shader', shader.name, 'has no bindings');
          }
        }
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Issuing draw call...');
        }
        renderPass.draw(6, 1, 0, 0);
        
        if (system.frameCount === 0) {
          console.log('[WebGPU Shaders] Draw call completed');
        }
      } catch (e) {
        console.error('[WebGPU Shaders] Render pass failed for', shader.name + ':', e);
        throw e;
      } finally {
        if (renderPass) {
          if (system.frameCount === 0) {
            console.log('[WebGPU Shaders] Ending render pass...');
          }
          renderPass.end();
        }
      }
      
      // Output becomes input for next shader
      inputTexture = outputTexture;
    }
    
    device.queue.submit([encoder.finish()]);
    system.frameCount++;
    
  } catch (error) {
    console.error('[WebGPU Shaders] Render error:', error);
    console.error('[WebGPU Shaders] Error stack:', error.stack);
  }
  } catch (outerError) {
    console.error('[WebGPU Shaders] Fatal render error:', outerError);
    console.error('[WebGPU Shaders] Fatal error stack:', outerError.stack);
  }
  })();
}

// Export for use in HTML
window.initWebGPUShaderSystem = initWebGPUShaderSystem;
window.renderWebGPUShaderChain = renderWebGPUShaderChain;
