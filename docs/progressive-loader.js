/**
 * TStorie Progressive Loader - SIDE_MODULE Architecture
 * 
 * Fast startup through modular plugin loading:
 * 1. Load core module first (MAIN_MODULE with SDL3 + runtime)
 * 2. Analyze content to detect required features
 * 3. Load plugin SIDE_MODULEs dynamically via loadDynamicLibrary()
 * 4. Plugins share main module's symbols (SDL3, malloc, etc.)
 * 
 * Architecture:
 * - Core: tstorie-core.wasm (MAIN_MODULE=2, exports loadDynamicLibrary)
 * - Plugins: plugins/*.wasm (SIDE_MODULE=2, depend on core)
 * - Loading: Module.loadDynamicLibrary('plugins/ttf.wasm')
 * - Init: Module._loadTTFPlugin() (Nim export)
 */

class ProgressiveLoader {
  constructor() {
    this.coreModule = null;
    this.loadedPlugins = new Set();
    this.loadingPromises = new Map();
    this.startTime = performance.now();
    this.contentAnalyzed = false;
    
    // Feature detection patterns
    this.featurePatterns = {
      // Unicode/emoji detection - TTF required
      ttf: /[\u{1F300}-\u{1F9FF}]|[\u{2500}-\u{257F}]|[\u{2580}-\u{259F}]|[\u{4E00}-\u{9FFF}]|[\u{0600}-\u{06FF}]|[\u{0100}-\u{017F}]|[\u{0180}-\u{024F}]/u,
      
      // Audio features
      audio: /playSound|beep|tone|music|audio|sound/i,
      
      // Particle systems
      particles: /particle|emitter|spark|trail|explosion/i,
      
      // Advanced effects
      effects: /blur|glow|shadow|pixelate|chromatic|wobble|distort/i
    };
    
    // Plugin configuration
    this.pluginConfig = {
      ttf: {
        path: 'plugins/ttf.wasm',
        size: 1500, // KB (includes FreeType + HarfBuzz)
        features: ['ttf'],
        nimInit: 'loadTTFPlugin', // Nim export to call after loading
        description: 'TTF font rendering (SDL_ttf, FreeType, HarfBuzz)'
      },
      audio: {
        path: 'plugins/audio.wasm',
        size: 300, // KB
        features: ['audio'],
        nimInit: 'loadAudioPlugin',
        description: 'Audio synthesis and playback (miniaudio)',
        status: 'planned' // Not yet built
      },
      particles: {
        path: 'plugins/particles.wasm',
        size: 150, // KB
        features: ['particles'],
        nimInit: 'loadParticlePlugin',
        description: 'Particle system',
        status: 'planned'
      },
      effects: {
        path: 'plugins/effects.wasm',
        size: 200, // KB
        features: ['effects'],
        nimInit: 'loadEffectsPlugin',
        description: 'Layer effects and shaders',
        status: 'planned'
      }
    };
  }
  
  /**
   * Initialize the loader and load core module
   */
  async init(canvasId = 'canvas') {
    console.log('[Loader] Initializing TStorie Progressive Loader...');
    
    try {
      // Load core module (MAIN_MODULE)
      this.coreModule = await this.loadCore(canvasId);
      console.log('[Loader] Core module loaded and ready');
      
      return this.coreModule;
    } catch (error) {
      console.error('[Loader] Initialization failed:', error);
      throw error;
    }
  }
  
  /**
   * Load the core MAIN_MODULE
   */
  async loadCore(canvasId) {
    const startTime = performance.now();
    console.log('[Loader] Loading core module (MAIN_MODULE)...');
    
    return new Promise((resolve, reject) => {
      // Check if TStorieCore is already defined (script already loaded)
      if (typeof TStorieCore !== 'undefined') {
        console.log('[Loader] Core script already loaded, initializing...');
        this.initializeCoreModule(canvasId).then(resolve).catch(reject);
        return;
      }
      
      // Load core JavaScript (which loads WASM)
      const script = document.createElement('script');
      script.src = 'tstorie-core.js';
      script.async = true;
      
      script.onload = () => {
        console.log('[Loader] Core script loaded');
        this.initializeCoreModule(canvasId).then(resolve).catch(reject);
      };
      
      script.onerror = () => {
        reject(new Error('Failed to load tstorie-core.js'));
      };
      
      document.head.appendChild(script);
    });
  }
  
  /**
   * Initialize the core module after script loads
   */
  async initializeCoreModule(canvasId) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
      throw new Error(`Canvas element '${canvasId}' not found`);
    }
    
    const Module = {
      canvas: canvas,
      printErr: (text) => console.error('[Core]', text),
      print: (text) => console.log('[Core]', text),
      onRuntimeInitialized: () => {
        console.log('[Loader] Core runtime initialized');
      }
    };
    
    // Call TStorieCore factory
    const coreModule = await TStorieCore(Module);
    
    const loadTime = performance.now() - this.startTime;
    console.log(`[Loader] Core module ready in ${loadTime.toFixed(0)}ms`);
    
    return coreModule;
  }
  
  /**
   * Analyze content to determine which plugins are needed
   */
  analyzeContent(markdown) {
    if (!markdown || this.contentAnalyzed) {
      return [];
    }
    
    const neededPlugins = [];
    
    for (const [pluginName, config] of Object.entries(this.pluginConfig)) {
      // Skip plugins that aren't built yet
      if (config.status === 'planned') {
        continue;
      }
      
      // Check if any feature patterns match
      const needsPlugin = config.features.some(featureName => {
        const pattern = this.featurePatterns[featureName];
        return pattern && pattern.test(markdown);
      });
      
      if (needsPlugin) {
        neededPlugins.push(pluginName);
        console.log(`[Loader] Content requires plugin: ${pluginName}`);
      }
    }
    
    this.contentAnalyzed = true;
    return neededPlugins;
  }
  
  /**
   * Load a plugin SIDE_MODULE dynamically
   */
  async loadPlugin(pluginName) {
    // Return cached promise if already loading
    if (this.loadingPromises.has(pluginName)) {
      return this.loadingPromises.get(pluginName);
    }
    
    // Return immediately if already loaded
    if (this.loadedPlugins.has(pluginName)) {
      console.log(`[Loader] Plugin ${pluginName} already loaded`);
      return true;
    }
    
    const config = this.pluginConfig[pluginName];
    if (!config) {
      console.error(`[Loader] Unknown plugin: ${pluginName}`);
      return false;
    }
    
    if (config.status === 'planned') {
      console.warn(`[Loader] Plugin ${pluginName} not yet implemented`);
      return false;
    }
    
    if (!this.coreModule) {
      console.error('[Loader] Core module not loaded yet');
      return false;
    }
    
    const startTime = performance.now();
    console.log(`[Loader] Loading plugin: ${pluginName} (${config.size}KB)`);
    console.log(`[Loader] Plugin path: ${config.path}`);
    
    const loadPromise = (async () => {
      try {
        // Use Emscripten's loadDynamicLibrary to load SIDE_MODULE
        await this.coreModule.loadDynamicLibrary(config.path, {
          loadAsync: true,   // Load asynchronously
          nodelete: true,    // Don't unload plugin
          global: true       // Make symbols globally available
        });
        
        const loadTime = performance.now() - startTime;
        console.log(`[Loader] Plugin ${pluginName} WASM loaded in ${loadTime.toFixed(0)}ms`);
        
        // Call Nim initialization function if specified
        if (config.nimInit) {
          console.log(`[Loader] Calling Nim init: ${config.nimInit}()`);
          
          const initFuncName = `_${config.nimInit}`;
          if (typeof this.coreModule[initFuncName] === 'function') {
            this.coreModule[initFuncName]();
            console.log(`[Loader] Plugin ${pluginName} initialized via ${config.nimInit}()`);
          } else {
            console.warn(`[Loader] Init function ${initFuncName} not found`);
          }
        }
        
        this.loadedPlugins.add(pluginName);
        
        const totalTime = performance.now() - startTime;
        console.log(`[Loader] Plugin ${pluginName} fully loaded in ${totalTime.toFixed(0)}ms`);
        
        return true;
      } catch (error) {
        console.error(`[Loader] Failed to load plugin ${pluginName}:`, error);
        return false;
      }
    })();
    
    this.loadingPromises.set(pluginName, loadPromise);
    return loadPromise;
  }
  
  /**
   * Load multiple plugins in parallel
   */
  async loadPlugins(pluginNames) {
    if (!Array.isArray(pluginNames) || pluginNames.length === 0) {
      return [];
    }
    
    console.log(`[Loader] Loading ${pluginNames.length} plugins in parallel...`);
    const results = await Promise.all(
      pluginNames.map(name => this.loadPlugin(name))
    );
    
    const successful = results.filter(r => r).length;
    console.log(`[Loader] Loaded ${successful}/${pluginNames.length} plugins`);
    
    return results;
  }
  
  /**
   * Inject markdown content into the running application
   */
  injectContent(markdown) {
    if (!this.coreModule) {
      console.error('[Loader] Core module not loaded');
      return false;
    }
    
    try {
      // Call the Nim export to set markdown content
      if (typeof this.coreModule._setMarkdownContent === 'function') {
        this.coreModule._setMarkdownContent(markdown);
        console.log('[Loader] Content injected successfully');
        return true;
      } else {
        console.error('[Loader] setMarkdownContent export not found');
        return false;
      }
    } catch (error) {
      console.error('[Loader] Failed to inject content:', error);
      return false;
    }
  }
  
  /**
   * Start the main application loop
   */
  startMainLoop() {
    if (!this.coreModule) {
      console.error('[Loader] Core module not loaded');
      return false;
    }
    
    try {
      // Call _main() to start the Emscripten main loop
      if (typeof this.coreModule._main === 'function') {
        console.log('[Loader] Starting main loop...');
        this.coreModule._main();
        
        // Note: _main() may throw a non-fatal RangeDefect during init
        // This is a known issue - the main loop still starts successfully
        console.log('[Loader] Main loop started (ignoring non-fatal init errors)');
        return true;
      } else {
        console.error('[Loader] _main export not found');
        return false;
      }
    } catch (error) {
      // Known issue: RangeDefect with epochTime() during init
      // The error is non-fatal - main loop continues running
      if (error.message && error.message.includes('ExitStatus')) {
        console.warn('[Loader] Non-fatal exit during main loop setup:', error.message);
        console.warn('[Loader] This is expected - rendering should still work');
        // Don't re-throw - the main loop is actually running
        return true;
      } else {
        console.error('[Loader] Failed to start main loop:', error);
        throw error;
      }
    }
  }
  
  /**
   * Get status of all plugins (for debugging)
   */
  getStatus() {
    const status = {
      coreLoaded: !!this.coreModule,
      loadedPlugins: Array.from(this.loadedPlugins),
      availablePlugins: Object.keys(this.pluginConfig),
      contentAnalyzed: this.contentAnalyzed,
      uptime: performance.now() - this.startTime
    };
    
    // Get plugin status from Nim if available
    if (this.coreModule && typeof this.coreModule._getPluginStatus === 'function') {
      try {
        const nimStatus = this.coreModule.UTF8ToString(
          this.coreModule._getPluginStatus()
        );
        status.nimPlugins = JSON.parse(nimStatus);
      } catch (e) {
        console.warn('[Loader] Could not get Nim plugin status:', e);
      }
    }
    
    return status;
  }
  
  /**
   * Complete workflow: load core, analyze content, load plugins, start app
   */
  async loadAndStart(markdown, canvasId = 'canvas') {
    try {
      // Step 1: Load core
      await this.init(canvasId);
      
      // Step 2: Analyze content
      const neededPlugins = this.analyzeContent(markdown);
      
      // Step 3: Load plugins (if any)
      if (neededPlugins.length > 0) {
        console.log(`[Loader] Loading ${neededPlugins.length} plugins...`);
        await this.loadPlugins(neededPlugins);
      } else {
        console.log('[Loader] No plugins required for this content');
      }
      
      // Step 4: Inject content (if provided)
      if (markdown) {
        this.injectContent(markdown);
      }
      
      // Step 5: Start main loop
      this.startMainLoop();
      
      console.log('[Loader] Application started successfully');
      return this.coreModule;
    } catch (error) {
      console.error('[Loader] Failed to load and start:', error);
      throw error;
    }
  }
}

// Export for use in HTML
if (typeof window !== 'undefined') {
  window.ProgressiveLoader = ProgressiveLoader;
}
