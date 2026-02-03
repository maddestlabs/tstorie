/**
 * Module Loader for tstorie WASM
 * 
 * Provides JavaScript-side support for loading Nim modules from GitHub gists
 * Works with the emRequireModule and emLoadGistCode exports from tstorie
 */

/**
 * Cache of loaded module code
 */
const moduleCache = new Map();

/**
 * Parse a module reference into gist components
 * @param {string} moduleRef - Reference like "gist:abc123/file.nim"
 * @returns {Object|null} - {gistId, filename} or null if not a gist
 */
function parseGistRef(moduleRef) {
  if (!moduleRef.startsWith('gist:')) {
    return null;
  }
  
  const parts = moduleRef.substring(5).split('/');
  if (parts.length !== 2) {
    throw new Error(`Invalid gist format: ${moduleRef}. Use: gist:ID/file.nim`);
  }
  
  return {
    gistId: parts[0],
    filename: parts[1]
  };
}

/**
 * Fetch a file from a GitHub gist
 * @param {string} gistId - The gist ID
 * @param {string} filename - The filename within the gist
 * @returns {Promise<string>} - The file contents
 */
async function fetchGistFile(gistId, filename) {
  const url = `https://gist.githubusercontent.com/raw/${gistId}/${filename}`;
  
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch gist: ${response.status} ${response.statusText}`);
    }
    return await response.text();
  } catch (error) {
    throw new Error(`Failed to fetch gist ${gistId}/${filename}: ${error.message}`);
  }
}

/**
 * Require a Nim module at runtime
 * Automatically fetches from gist if needed, then compiles via WASM
 * 
 * @param {string} moduleRef - Module reference (e.g., "gist:abc123/canvas.nim")
 * @returns {Promise<void>}
 */
async function requireModule(moduleRef) {
  // Check if already cached
  if (moduleCache.has(moduleRef)) {
    return;
  }
  
  const gistInfo = parseGistRef(moduleRef);
  
  if (gistInfo) {
    // It's a gist reference - fetch the code
    console.log(`Fetching module: ${moduleRef}`);
    const code = await fetchGistFile(gistInfo.gistId, gistInfo.filename);
    
    // Pass the code to the WASM module
    if (typeof Module._emLoadGistCode === 'function') {
      Module._emLoadGistCode(moduleRef, code);
      moduleCache.set(moduleRef, code);
    } else {
      throw new Error('WASM module not properly initialized (missing emLoadGistCode)');
    }
  }
  
  // Now try to compile/load the module
  if (typeof Module._emRequireModule === 'function') {
    const result = Module._emRequireModule(moduleRef);
    
    if (result.startsWith('error:')) {
      throw new Error(`Failed to load module ${moduleRef}: ${result.substring(7)}`);
    } else if (result === 'fetch_needed') {
      // This shouldn't happen if we fetched above, but handle it
      if (gistInfo) {
        throw new Error(`Module fetch failed for ${moduleRef}`);
      } else {
        throw new Error(`Local module not found: ${moduleRef}`);
      }
    }
    // result === 'loaded' - success!
    console.log(`Module loaded: ${moduleRef}`);
  } else {
    throw new Error('WASM module not properly initialized (missing emRequireModule)');
  }
}

/**
 * Preload multiple modules before starting the application
 * Useful for loading dependencies before init
 * 
 * @param {string[]} moduleRefs - Array of module references
 * @returns {Promise<void>}
 */
async function preloadModules(moduleRefs) {
  const promises = moduleRefs.map(ref => requireModule(ref));
  await Promise.all(promises);
}

/**
 * Clear the module cache (useful for development)
 */
function clearModuleCache() {
  moduleCache.clear();
}

// Export for use in browser or Node.js
if (typeof window !== 'undefined') {
  window.tstorieModuleLoader = {
    requireModule,
    preloadModules,
    clearModuleCache,
    fetchGistFile,
    parseGistRef
  };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    requireModule,
    preloadModules,
    clearModuleCache,
    fetchGistFile,
    parseGistRef
  };
}
