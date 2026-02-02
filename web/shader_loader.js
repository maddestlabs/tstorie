/**
 * WebGPU-aware Shader Loader for TStorie
 * 
 * Automatically loads WGSL shaders for WebGPU, GLSL for WebGL
 * Supports front matter (shaders=) and URL parameters (?shader=)
 * 
 * Features:
 * - Auto-detects active backend (WebGPU vs WebGL)
 * - Falls back to GLSL if WGSL not available
 * - Supports format override via ?format=wgsl or ?format=glsl
 * - Loads from local files or Gist (same as existing system)
 */

(function() {
  'use strict';

  /**
   * Load a single shader with WebGPU/WebGL awareness
   * @param {string} shaderName - Name of shader (without extension)
   * @returns {Promise<Object>} Shader object with name, content, backend, source
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
              console.warn('[Shader] WGSL version not found, falling back to GLSL:', shaderName);
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
                          return Promise.resolve(gist.files[filename].content); 
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
              source: response._source || 'local',
              filename: shaderName + (response._backend === 'webgpu' ? '.wgsl.js' : '.js')
            };
          });
        })
        .then(resolve)
        .catch(reject);
    });
  }

  // Export globally
  window.loadSingleShaderWebGPU = loadSingleShaderWebGPU;

  // Also export as module for compatibility
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { loadSingleShaderWebGPU };
  }

})();
