/**
 * Plugin Loader - Incremental Loading System for TStorie
 * Manages dynamic loading of WASM plugin modules
 */

class PluginLoader {
  constructor() {
    this.coreModule = null;
    this.plugins = {
      ttf: {
        url: 'plugins/ttf.wasm',
        size: 1.45 * 1024 * 1024,
        status: 'not-loaded',
        requiresUserGesture: false
      },
      audio: {
        url: 'plugins/audio.wasm',
        size: 330 * 1024,
        status: 'not-loaded',
        requiresUserGesture: true
      },
      effects: {
        url: 'plugins/effects.wasm',
        size: 200 * 1024,
        status: 'not-loaded',
        requiresUserGesture: false
      },
      network: {
        url: 'plugins/network.wasm',
        size: 150 * 1024,
        status: 'not-loaded',
        requiresUserGesture: false
      }
    };
    
    this.hadUserGesture = false;
    this.deferredPlugins = [];
    this.loadingCallbacks = {};
  }
  
  /**
   * Load core module (SDL3 + debug text)
   * This loads immediately and can render right away
   */
  async loadCore() {
    console.log('[PluginLoader] Loading core module...');
    
    const startTime = performance.now();
    
    this.coreModule = await TStorieCore({
      locateFile: (path) => {
        if (path.endsWith('.wasm')) return 'tstorie-core.wasm';
        if (path.endsWith('.data')) return 'tstorie-core.data';
        return path;
      },
      
      print: (text) => console.log('[Core]', text),
      printErr: (text) => console.error('[Core]', text),
      
      onRuntimeInitialized: () => {
        const loadTime = performance.now() - startTime;
        console.log(`[PluginLoader] Core ready in ${loadTime.toFixed(0)}ms`);
        console.log('[PluginLoader] Rendering with debug text (ASCII only)');
      }
    });
    
    return this.coreModule;
  }
  
  /**
   * Analyze content and determine needed plugins
   */
  analyzeContent(markdown) {
    if (!this.coreModule) {
      console.error('[PluginLoader] Core not loaded yet');
      return [];
    }
    
    // Call WASM function to analyze content
    const jsonString = this.coreModule.ccall(
      'emAnalyzeContent',
      'string',
      ['string'],
      [markdown]
    );
    
    const plugins = JSON.parse(jsonString);
    console.log('[PluginLoader] Required plugins:', plugins);
    
    return plugins;
  }
  
  /**
   * Load a single plugin
   */
  async loadPlugin(name) {
    const plugin = this.plugins[name];
    
    if (!plugin) {
      throw new Error(`Unknown plugin: ${name}`);
    }
    
    if (plugin.status === 'loaded') {
      console.log(`[PluginLoader] Plugin ${name} already loaded`);
      return;
    }
    
    if (plugin.status === 'loading') {
      console.log(`[PluginLoader] Plugin ${name} already loading`);
      return;
    }
    
    // Check if user gesture required
    if (plugin.requiresUserGesture && !this.hadUserGesture) {
      console.log(`[PluginLoader] Plugin ${name} requires user gesture, deferring...`);
      this.deferredPlugins.push(name);
      return;
    }
    
    plugin.status = 'loading';
    
    // Show loading indicator
    this.showLoadingIndicator(name, plugin.size);
    
    const startTime = performance.now();
    
    try {
      console.log(`[PluginLoader] Loading plugin: ${name} (${(plugin.size / 1024).toFixed(0)}KB)`);
      
      // Load the plugin module dynamically
      await this.coreModule.loadDynamicLibrary(plugin.url, {
        loadAsync: true,
        global: true,
        nodelete: true
      });
      
      // Notify core that plugin is ready
      this.coreModule.ccall('emPluginLoaded', 'number', ['string'], [name]);
      
      plugin.status = 'loaded';
      
      const loadTime = performance.now() - startTime;
      console.log(`[PluginLoader] Plugin ${name} loaded in ${loadTime.toFixed(0)}ms`);
      
      // Hide loading indicator
      this.hideLoadingIndicator(name);
      
      // Trigger callback if registered
      if (this.loadingCallbacks[name]) {
        this.loadingCallbacks[name]();
      }
      
      // If this was TTF, trigger re-render with better fonts
      if (name === 'ttf') {
        console.log('[PluginLoader] Upgrading to TTF rendering');
        this.coreModule._emRefreshDisplay();
      }
      
    } catch (error) {
      plugin.status = 'failed';
      console.error(`[PluginLoader] Failed to load plugin ${name}:`, error);
      this.showError(name, error);
    }
  }
  
  /**
   * Load multiple plugins in priority order
   */
  async loadPlugins(pluginNames) {
    for (const name of pluginNames) {
      await this.loadPlugin(name);
    }
  }
  
  /**
   * Load deferred plugins (after user gesture)
   */
  async loadDeferred() {
    if (this.deferredPlugins.length === 0) {
      return;
    }
    
    console.log('[PluginLoader] Loading deferred plugins:', this.deferredPlugins);
    
    const plugins = [...this.deferredPlugins];
    this.deferredPlugins = [];
    
    for (const name of plugins) {
      await this.loadPlugin(name);
    }
  }
  
  /**
   * Register callback for when plugin loads
   */
  onPluginLoaded(name, callback) {
    this.loadingCallbacks[name] = callback;
  }
  
  /**
   * Show loading indicator in UI
   */
  showLoadingIndicator(name, size) {
    const indicator = document.getElementById('loading-indicator');
    if (indicator) {
      const sizeMB = (size / 1024 / 1024).toFixed(2);
      indicator.textContent = `Loading ${name} plugin (${sizeMB}MB)...`;
      indicator.style.display = 'block';
    }
  }
  
  /**
   * Hide loading indicator
   */
  hideLoadingIndicator(name) {
    const indicator = document.getElementById('loading-indicator');
    if (indicator) {
      indicator.style.display = 'none';
    }
  }
  
  /**
   * Show error message
   */
  showError(name, error) {
    const errorDiv = document.getElementById('error-message');
    if (errorDiv) {
      errorDiv.textContent = `Failed to load ${name}: ${error.message}`;
      errorDiv.style.display = 'block';
    }
  }
}

// Initialize plugin loader
const pluginLoader = new PluginLoader();

// Setup user gesture detection for audio
document.addEventListener('click', () => {
  if (!pluginLoader.hadUserGesture) {
    pluginLoader.hadUserGesture = true;
    console.log('[PluginLoader] User gesture detected');
    pluginLoader.loadDeferred();
  }
}, { once: true });

// Export for global access
window.pluginLoader = pluginLoader;
