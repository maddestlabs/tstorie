/**
 * TStorie WebGPU WASM Bridge
 * 
 * Provides JavaScript functions that are called from Nim/WASM to execute
 * GPU compute shaders via the WebGPU API.
 * 
 * Since JavaScript async/await doesn't work well with synchronous WASM calls,
 * we use a polling-based approach where Nim can check if results are ready.
 */

// Store GPU state
window.tStorieGPU = {
  pendingOperation: null,
  currentResult: null,
  resultReady: false,
  error: null,
  width: 0,
  height: 0
};

/**
 * Check if WebGPU is supported
 */
function tStorie_webgpuIsSupported() {
  return window.webgpuBridge && window.webgpuBridge.isSupported() ? 1 : 0;
}

/**
 * Check if WebGPU is initialized and ready
 */
function tStorie_webgpuIsReady() {
  return window.webgpuBridge && window.webgpuBridge.isReady() ? 1 : 0;
}

/**
 * Start GPU noise execution (async - results available later)
 * Returns 1 if operation started, 0 if failed to start
 */
function tStorie_webgpuStartExecution(wgsl, width, height, offsetX, offsetY) {
  if (!window.webgpuBridge || !window.webgpuBridge.isReady()) {
    console.error('[GPU WASM] WebGPU not ready');
    return 0;
  }

  console.log(`[GPU WASM] Starting execution: ${width}x${height} @ (${offsetX}, ${offsetY})`);
  
  // Mark as pending
  window.tStorieGPU.resultReady = false;
  window.tStorieGPU.currentResult = null;
  window.tStorieGPU.error = null;
  window.tStorieGPU.width = width;
  window.tStorieGPU.height = height;
  
  // Start async execution
  window.tStorieGPU.pendingOperation = window.webgpuBridge
    .executeNoiseShader(wgsl, width, height, offsetX, offsetY)
    .then(results => {
      if (results) {
        console.log(`[GPU WASM] Execution completed: ${results.length} values`);
        window.tStorieGPU.currentResult = results;
        window.tStorieGPU.resultReady = true;
        return true;
      } else {
        console.error('[GPU WASM] Execution failed - no results');
        window.tStorieGPU.error = 'No results returned';
        return false;
      }
    })
    .catch(error => {
      console.error('[GPU WASM] Execution error:', error);
      window.tStorieGPU.error = error.message || 'Unknown error';
      window.tStorieGPU.resultReady = false;
      return false;
    });
  
  return 1; // Operation started
}

/**
 * Check if GPU result is ready
 */
function tStorie_webgpuIsResultReady() {
  return window.tStorieGPU.resultReady ? 1 : 0;
}

/**
 * Get a single result value at index
 * Returns value [0..65535] or 0 if index out of bounds
 */
function tStorie_webgpuGetValue(index) {
  if (!window.tStorieGPU.resultReady || !window.tStorieGPU.currentResult) {
    return 0;
  }
  
  if (index >= 0 && index < window.tStorieGPU.currentResult.length) {
    return window.tStorieGPU.currentResult[index];
  }
  
  return 0;
}

/**
 * Get result buffer size
 */
function tStorie_webgpuGetResultSize() {
  if (window.tStorieGPU.currentResult) {
    return window.tStorieGPU.currentResult.length;
  }
  return 0;
}

/**
 * Cancel any pending operation
 */
function tStorie_webgpuCancel() {
  window.tStorieGPU.pendingOperation = null;
  window.tStorieGPU.resultReady = false;
  window.tStorieGPU.currentResult = null;
  window.tStorieGPU.error = null;
}

console.log('[GPU WASM] WebGPU WASM Bridge loaded');
