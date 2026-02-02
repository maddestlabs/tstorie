# WGSL Shader Integration Guide

This document explains how to integrate the converted WGSL shaders into the WebGPU build, supporting both URL parameters and front matter specifications.

## Current Shader Loading System

TStorie currently loads shaders via two methods:

1. **Front Matter** - Specify in markdown:
   ```markdown
   ---
   shaders: crt+scanlines+bloom
   ---
   ```

2. **URL Parameters** - Override via URL:
   ```
   ?shader=crt+scanlines
   ```

The shader loading happens in:
- `web/font_metrics_bridge.js` - `emLoadShaders()` function (called from WASM)
- `docs/index-webgpu.html` - `loadSingleShader()` function (called from HTML)

## Integration Strategy

To use WGSL shaders with the WebGPU build, we need to:

### 1. Auto-Detect Backend and Load Appropriate Format

**Easy Implementation** (~30 minutes of work):

```javascript
/**
 * WebGPU-aware Shader Loader
 * 
 * Automatically loads WGSL shaders for WebGPU, GLSL for WebGL
 * Drop-in replacement for existing shader loading logic
 */

function loadSingleShaderWebGPU(shaderName) {
  return new Promise(function(resolve, reject) {
    // Detect active backend
    const useWebGPU = window.usePhase6Renderer && 
                      navigator.gpu !== undefined &&
                      window.TStorieWebGPURender !== undefined;
    
    // Check for explicit format override
    const urlParams = new URLSearchParams(window.location.search);
    const formatOverride = urlParams.get('format'); // 'glsl' or 'wgsl'
    
    // Determine shader path
    let shaderDir, extension, backend;
    if (formatOverride === 'wgsl') {
      shaderDir = 'shaders/wgsl/';
      extension = '.wgsl.js';
      backend = 'webgpu';
    } else if (formatOverride === 'glsl') {
      shaderDir = 'shaders/';
      extension = '.js';
      backend = 'webgl';
    } else {
      // Auto-detect
      shaderDir = useWebGPU ? 'shaders/wgsl/' : 'shaders/';
      extension = useWebGPU ? '.wgsl.js' : '.js';
      backend = useWebGPU ? 'webgpu' : 'webgl';
    }
    
    const localShaderUrl = shaderDir + shaderName + extension;
    
    console.log('[Shader] Loading', shaderName, 'from', localShaderUrl, 
                '(backend:', backend + ')');
    
    fetch(localShaderUrl)
      .then(function(response) {
        if (!response.ok) {
          // If WGSL not found, try fallback to GLSL
          if (backend === 'webgpu' && !formatOverride) {
            console.warn('[Shader] WGSL version not found, falling back to GLSL');
            return fetch('shaders/' + shaderName + '.js')
              .then(function(fallbackResponse) {
                if (!fallbackResponse.ok) {
                  // Try Gist as last resort
                  console.log('[Shader] Local shader not found, trying Gist:', shaderName);
                  return fetch('https://api.github.com/gists/' + shaderName)
                    .then(function(gistResponse) {
                      if (!gistResponse.ok) {
                        throw new Error('Shader not found: ' + shaderName);
                      }
                      return gistResponse.json();
                    })
                    .then(function(gist) {
                      for (const filename in gist.files) {
                        if (filename.endsWith('.js')) {
                          return {
                            text: function() { 
                              return Promise.resolve(gist.files[filename].content); 
                            },
                            ok: true,
                            _backend: 'webgl',
                            _source: 'gist'
                          };
                        }
                      }
                      throw new Error('No .js file in gist: ' + shaderName);
                    });
                }
                return Object.assign(fallbackResponse, { 
                  _backend: 'webgl', 
                  _source: 'local-fallback' 
                });
              });
          } else {
            // Try Gist
            console.log('[Shader] Local shader not found, trying Gist:', shaderName);
            return fetch('https://api.github.com/gists/' + shaderName)
              .then(function(gistResponse) {
                if (!gistResponse.ok) {
                  throw new Error('Shader not found: ' + shaderName);
                }
                return gistResponse.json();
              })
              .then(function(gist) {
                for (const filename in gist.files) {
                  if (filename.endsWith('.js')) {
                    return {
                      text: function() { 
                        return Promise.resolve(gist.fil

## Implementation Details

### Step 1: Add WebGPU-Aware Loader

Create `web/shader_loader.js` with the code above, then:

**In `docs/index-webgpu.html`:**
```html
<!-- After webgpu_bridge.js, before shader loading -->
<script src="shader_loader.js"></script>
```

**In `web/font_metrics_bridge.js`:**
```javascript
// Replace loadSingleShader function with:
function loadSingleShader(shaderName) {
  if (typeof window.loadSingleShaderWebGPU === 'function') {
    return window.loadSingleShaderWebGPU(shaderName);
  }
  // Fallback to original implementation
  return originalLoadSingleShader(shaderName);
}
```

### Step 2: Update Shader System Initialization

**In `docs/index-webgpu.html` (initShaderSystem function):**

```javascript
function initShaderSystem() {
  const codes = window.shaderCodes || shaderCodes;
  if (!codes || codes.length === 0) return;
  
  // Check if using WebGPU backend
  const useWebGPU = codes[0].backend === 'webgpu' || 
                    (window.usePhase6Renderer && navigator.gpu);
  
  if (useWebGPU) {
    console.log('Initializing WebGPU shader pipeline');
    initWebGPUShaderSystem(codes);
  } else {
    console.log('Initializing WebGL shader pipeline');
    initWebGLShaderSystem(codes);
  }
}
```

### Step 3: WebGPU Shader Pipeline

Create a WebGPU version of the shader chain system:

```javascript
async function initWebGPUShaderSystem(shaderCodes) {
  const canvas = document.getElementById('terminal-webgl');
  const context = canvas.getContext('webgpu');
  
  if (!context || !window.webgpuBridge) {
    console.warn('WebGPU not available, falling back to WebGL');
    return initWebGLShaderSystem(shaderCodes);
  }
  
  // Ensure WebGPU bridge is initialized
  if (!window.webgpuBridge.initialized) {
    await window.webgpuBridge.init();
  }
  
  const device = window.webgpuBridge.getDevice();
  const format = navigator.gpu.getPreferredCanvasFormat();
  
  context.configure({
    device,
    format,
    alphaMode: 'premultiplied',
  });
  
  // Create shader pipeline
  const shaderPipelines = [];
  
  for (let i = 0; i < shaderCodes.length; i++) {
    const shader = shaderCodes[i];
    
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
      code: getShaderConfig.vertexShader + '\n' + getShaderConfig.fragmentShader
    });
    
    // Check for errors
    const info = await shaderModule.getCompilationInfo();
    const errors = info.messages.filter(m => m.type === 'error');
    if (errors.length > 0) {
      console.error('Shader compilation errors:', shader.name, errors);
      throw new Error('Shader compilation failed: ' + shader.name);
    }
    
    // Create render pipeline
    const pipeline = device.createRenderPipeline({
      layout: 'auto',
      vertex: {
        module: shaderModule,
        entryPoint: 'vertexMain',
        buffers: [{
          arrayStride: 8,
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
      uniforms: getShaderConfig.uniforms || {}
    });
  }
  
  console.log('WebGPU shader pipeline created:', 
              shaderPipelines.map(p => p.name).join(' → '));
  
  // Store globally
  window.shaderSystem = {
    backend: 'webgpu',
    device: device,
    context: context,
    pipelines: shaderPipelines,
    render: renderWebGPUShaderChain
  };
}

function renderWebGPUShaderChain() {
  // Render shader chain each frame
  // Similar to existing WebGL chain but using WebGPU API
}
```

## Usage Examples

### Example 1: Front Matter with Auto-Detection

```markdown
---
shaders: crt+scanlines+bloom
---
```

- **WebGPU browser**: Loads `shaders/wgsl/crt.wgsl.js`, `shaders/wgsl/scanlines.wgsl.js`, etc.
- **WebGL browser**: Loads `shaders/crt.js`, `shaders/scanlines.js`, etc.
- **Fallback**: If WGSL not found, automatically tries GLSL version

### Example 2: URL Parameter Override

```
?shader=crt+bloom
```

Works the same way - auto-detects backend and loads appropriate format.

### Example 3: Force Specific Format

```
?format=wgsl&shader=crt+bloom
```

Forces loading WGSL shaders (useful for testing).

```
?format=glsl&shader=crt+bloom
```

Forces loading GLSL shaders (useful for comparing).

## Backward Compatibility

✅ **Fully backward compatible**:
- Existing projects with `shaders=` continue working
- GLSL shaders still load and work in WebGL mode
- If WGSL version doesn't exist, falls back to GLSL automatically
- No changes needed to existing markdown files

## Testing Workflow

1. **Create test page** with shader chain:
   ```markdown
   ---
   shaders: crt+scanlines+grille
   ---
   ```

2. **Test in WebGPU browser**:
   - Open with `?format=wgsl` → should load WGSL shaders
   - Check console for "WebGPU shader pipeline created"
   - Verify visual output matches GLSL version

3. **Test fallback**:
   - Delete one WGSL shader temporarily
   - Reload - should automatically fall back to GLSL version
   - Console should warn about fallback

4. **Test WebGL**:
   - Open with `?format=glsl` → should load GLSL shaders
   - Should work identically to current system

## Implementation Effort

### Difficulty: **Easy to Medium**

**Time estimate:** 2-4 hours

**Breakdown:**
1. Create `shader_loader.js` - **30 min** (mostly copying code above)
2. Update `font_metrics_bridge.js` - **15 min** (simple function replacement)
3. Update `index-webgpu.html` - **30 min** (add script tag, update loadSingleShader)
4. Create `initWebGPUShaderSystem()` - **1-2 hours** (adapt existing WebGL logic)
5. Testing and debugging - **30-60 min**

**Complexity factors:**
- ✅ Shader loading logic already exists (just need to duplicate)
- ✅ WGSL shaders already converted and ready
- ✅ WebGPU bridge already has device management
- ⚠️ Shader chain rendering needs WebGPU framebuffer/texture setup
- ⚠️ Uniform buffer creation and binding (different from WebGL)

## Key Differences: GLSL vs WGSL Shader Chains

### WebGL (Current System)

```javascript
// Framebuffer ping-pong
const fb1 = gl.createFramebuffer();
const fb2 = gl.createFramebuffer();

// Render chain
gl.bindFramebuffer(gl.FRAMEBUFFER, fb1);
renderShader1(terminalTexture);

gl.bindFramebuffer(gl.FRAMEBUFFER, fb2);
renderShader2(fb1.texture);

gl.bindFramebuffer(gl.FRAMEBUFFER, null);
renderShader3(fb2.texture);
```

### WebGPU (New System)

```javascript
// Texture ping-pong
const texture1 = device.createTexture({...});
const texture2 = device.createTexture({...});

// Render chain
const encoder = device.createCommandEncoder();

const pass1 = encoder.beginRenderPass({
  colorAttachments: [{ view: texture1.createView(), ... }]
});
renderShader1(terminalTexture, pass1);
pass1.end();

const pass2 = encoder.beginRenderPass({
  colorAttachments: [{ view: texture2.createView(), ... }]
});
renderShader2(texture1, pass2);
pass2.end();

const pass3 = encoder.beginRenderPass({
  colorAttachments: [{ view: canvasTexture.createView(), ... }]
});
renderShader3(texture2, pass3);
pass3.end();

device.queue.submit([encoder.finish()]);
```

## Advanced: Hybrid Renderer Integration

The hybrid renderer ([tstorie-hybrid-renderer.js](web/tstorie-hybrid-renderer.js)) already handles backend detection. We can leverage it:

```javascript
// In shader loader
const renderer = window.tStorieRenderer;
if (renderer && renderer.getBackend) {
  const backend = renderer.getBackend(); // 'webgpu' or 'webgl'
  // Use backend to determine shader format
}
```

This ensures shader loading matches the actual rendering backend being used.

## Benefits

1. **Zero user changes** - Existing projects work as-is
2. **Automatic optimization** - WebGPU users get faster shaders automatically
3. **Graceful degradation** - Falls back to GLSL if WGSL unavailable
4. **Easy testing** - URL param allows A/B comparison
5. **Future-proof** - Can add more backends (Vulkan, Metal) with same pattern

## Next Steps

1. ✅ WGSL shaders converted (done)
2. ⬜ Implement shader loader (2-4 hours)
3. ⬜ Implement WebGPU shader chain rendering (2-3 hours)
4. ⬜ Test with all 38 shaders
5. ⬜ Document in user guide

**Total implementation time: ~4-7 hours** (one afternoon of focused work)

## Summary

**How hard would it be?** 

**Answer: Not very hard!** 

The system is already 80% complete:
- ✅ WGSL shaders ready
- ✅ WebGPU device management working
- ✅ Shader loading infrastructure exists
- ✅ Front matter parsing works
- ⬜ Just need to wire it together (4-7 hours)

The hardest part is adapting the shader chain rendering from WebGL to WebGPU, but that's mostly mechanical translation of GL calls to WebGPU equivalents. The actual shader loading and format detection is straightforward.es[filename].content); 
                      },
                      ok: true,
                      _backend: backend,
                      _source: 'gist'
                    };
                  }
                }
                throw new Error('No .js file in gist: ' + shaderName);
              });
          }
        }
        return Object.assign(response, { 
          _backend: backend, 
          _source: 'local' 
        });
      })
      .then(function(response) {
        return response.text().then(function(content) {
          return {
            name: shaderName,
            content: content,
            backend: response._backend,
            source: response._source || 'local'
          };
        });
      })
      .then(resolve)
      .catch(reject);
  });
}

// Export for use in font_metrics_bridge.js
window.loadSingleShaderWebGPU = loadSingleShaderWebGPU;
