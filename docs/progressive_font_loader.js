/**
 * Progressive Font Loader for SDL3 Build
 * 
 * Strategy:
 * 1. App starts with minimal 3270-Regular.ttf (250KB, bundled in WASM)
 * 2. After 2 seconds (app is interactive), load 3270NerdFont-Regular.ttf (2.6MB)
 * 3. Hot-swap font when loaded, invalidate glyph cache
 * 
 * This gives users fast startup while eventually providing full glyph coverage
 * (programming icons, powerline symbols, etc.)
 */

console.log('[Font Loader] Script loaded');

window.progressiveFontLoader = {
  loaded: false,
  loading: false,
  
  /**
   * Start loading the comprehensive Nerd Font in the background
   * Call this after the app is interactive (e.g., 2 seconds after load)
   */
  loadNerdFont: function() {
    if (this.loading || this.loaded) {
      return;
    }
    
    this.loading = true;
    const startTime = performance.now();
    
    // The font is already preloaded in the WASM binary, just need to switch to it
    // Check if file exists in virtual FS
    try {
      const exists = Module.FS.analyzePath('/fonts/3270NerdFont-Regular.ttf').exists;
      if (!exists) {
        console.error('[Progressive Font] 3270NerdFont-Regular.ttf not found in virtual FS');
        this.loading = false;
        return;
      }
      
      // Simulate async delay to avoid blocking startup
      // (In reality the file is already in memory, but we wait to avoid
      // interfering with initial render performance)
      setTimeout(() => {
        try {
          // Call back into WASM to reload the font
          if (Module._emReloadFontSDL3) {
            const fontPath = '/fonts/3270NerdFont-Regular.ttf';
            const ptr = Module.allocateUTF8(fontPath);
            
            // Hot-swap the font (updates internal pointer, clears glyph cache)
            Module._emReloadFontSDL3(ptr, 16.0);
            
            // Force a complete redraw with the new font (low-level)
            if (Module._emForceRedraw) {
              Module._emForceRedraw();
            }
            
            // Also trigger Nimini-level redraw (calls on:render handlers)
            if (Module.ccall) {
              try {
                Module.ccall('nimini_forceRedraw', null, [], []);
              } catch (e) {
                // Ignore if function doesn't exist (older builds)
              }
            }
            
            const elapsed = ((performance.now() - startTime) / 1000).toFixed(2);
            console.log(`✓ 3270 Nerd Font loaded (${elapsed}s) - Programming icons now available`);
            
            this.loaded = true;
            this.loading = false;
            
            // Dispatch custom event so app can react if needed
            window.dispatchEvent(new CustomEvent('nerd-font-loaded'));
          } else {
            console.error('[Progressive Font] _emReloadFontSDL3 not found in WASM exports');
            this.loading = false;
          }
        } catch (e) {
          console.error('[Progressive Font] Failed to load Nerd Font:', e);
          this.loading = false;
        }
      }, 2000); // Wait 2 seconds after app start
      
    } catch (e) {
      console.error('[Progressive Font] Error checking font file:', e);
      this.loading = false;
    }
  },
  
  /**
   * Initialize progressive loading when Module is ready
   */
  init: function() {
    // Verify Module and dependencies are available
    const moduleExists = typeof Module !== 'undefined';
    const hasReloadFunc = moduleExists && Module._emReloadFontSDL3;
    const fsExists = moduleExists && Module.FS;
    
    console.log('[Font Loader] Dependencies:', {
      Module: moduleExists,
      _emReloadFontSDL3: hasReloadFunc,
      'Module.FS': fsExists
    });
    
    if (!moduleExists || !hasReloadFunc || !fsExists) {
      console.error('[Font Loader] Missing dependencies - cannot load Nerd Font');
      return;
    }
    
    console.log('[Font] Progressive loader ready, will upgrade to Nerd Font in 2s');
    
    // Wait 2 seconds after Module is ready, then load Nerd Font
    setTimeout(() => this.loadNerdFont(), 2000);
  }
};

// NOTE: This script is called by index-modular.html after Module is initialized
// Do not auto-init here - wait for explicit call from HTML
