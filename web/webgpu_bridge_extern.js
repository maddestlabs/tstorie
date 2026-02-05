/**
 * WebGPU Bridge External Functions for Emscripten
 * 
 * These functions are defined here so that Emscripten can link them during compilation.
 * The actual implementations are in webgpu_wasm_bridge.js which is loaded at runtime.
 */

mergeInto(LibraryManager.library, {
  tStorie_webgpuIsSupported: function() {
    if (typeof window !== 'undefined' && window.tStorie_webgpuIsSupported) {
      return window.tStorie_webgpuIsSupported();
    }
    return 0;
  },
  
  tStorie_webgpuIsReady: function() {
    if (typeof window !== 'undefined' && window.tStorie_webgpuIsReady) {
      return window.tStorie_webgpuIsReady();
    }
    return 0;
  },
  
  tStorie_webgpuStartExecution: function(wgslPtr, width, height, offsetX, offsetY) {
    if (typeof window !== 'undefined' && window.tStorie_webgpuStartExecution) {
      const wgsl = UTF8ToString(wgslPtr);
      return window.tStorie_webgpuStartExecution(wgsl, width, height, offsetX, offsetY);
    }
    return 0;
  },
  
  tStorie_webgpuIsResultReady: function() {
    if (typeof window !== 'undefined' && window.tStorie_webgpuIsResultReady) {
      return window.tStorie_webgpuIsResultReady();
    }
    return 0;
  },
  
  tStorie_webgpuGetValue: function(index) {
    if (typeof window !== 'undefined' && window.tStorie_webgpuGetValue) {
      return window.tStorie_webgpuGetValue(index);
    }
    return 0;
  },
  
  tStorie_webgpuGetResultSize: function() {
    if (typeof window !== 'undefined' && window.tStorie_webgpuGetResultSize) {
      return window.tStorie_webgpuGetResultSize();
    }
    return 0;
  },
  
  tStorie_webgpuCancel: function() {
    if (typeof window !== 'undefined' && window.tStorie_webgpuCancel) {
      window.tStorie_webgpuCancel();
    }
  },
  
  tStorie_injectWGSLShader: function(namePtr, vertexPtr, fragmentPtr, uniformsPtr) {
    if (typeof window !== 'undefined' && window.tStorie_injectWGSLShader) {
      const name = UTF8ToString(namePtr);
      const vertex = UTF8ToString(vertexPtr);
      const fragment = UTF8ToString(fragmentPtr);
      const uniformsJson = UTF8ToString(uniformsPtr);
      return window.tStorie_injectWGSLShader(name, vertex, fragment, uniformsJson);
    }
    return 0;
  }
});
