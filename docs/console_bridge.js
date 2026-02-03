// Console logging bridge for Nim/WASM
// Provides access to JavaScript console.log from Nim code

mergeInto(LibraryManager.library, {
  emConsoleLog: function(msgPtr) {
    const msg = UTF8ToString(msgPtr);
    console.log('[TSTORIE]', msg);
  },
  
  tStorie_logFrontMatterTheme: function(themeNamePtr) {
    const themeName = UTF8ToString(themeNamePtr);
    console.log('🎨 [FRONT MATTER] Theme specified in front matter:', themeName);
  },
  
  tStorie_logUrlThemeDetected: function(themeValuePtr) {
    const themeValue = UTF8ToString(themeValuePtr);
    console.log('🎨 [URL PARAM] URL theme parameter detected:', themeValue);
  },
  
  tStorie_logUrlThemeSuccess: function(themeValuePtr) {
    // Nim currently calls this with no args; tolerate null/0/undefined.
    let themeValue = '';
    try {
      if (themeValuePtr) themeValue = UTF8ToString(themeValuePtr);
    } catch {
      themeValue = '';
    }
    console.log('✅ [URL OVERRIDE] Successfully applied URL theme:', themeValue);
  },
  
  tStorie_logUrlThemeFailed: function(themeValuePtr) {
    const themeValue = UTF8ToString(themeValuePtr);
    console.log('❌ [URL OVERRIDE] Failed to apply URL theme:', themeValue);
  },
  
  tStorie_logNoUrlTheme: function() {
    console.log('ℹ️  [URL PARAM] No URL theme parameter - using front matter or default theme');
  },

  // Publish active theme background color for shaders/JS.
  // Called on theme apply/switch (not per-frame).
  tStorie_setThemeBackground: function(r, g, b) {
    const rr = (r | 0) & 255;
    const gg = (g | 0) & 255;
    const bb = (b | 0) & 255;

    const rgb01 = [rr / 255, gg / 255, bb / 255];

    window.__tstorieTheme = window.__tstorieTheme || {};
    window.__tstorieTheme.backgroundRgb255 = [rr, gg, bb];
    window.__tstorieTheme.backgroundRgb01 = rgb01;

    // If the WebGPU shader system is active, seed its live cache.
    if (window.shaderSystem && window.shaderSystem.backend === 'webgpu') {
      window.shaderSystem.liveThemeBackgroundRgb01 = rgb01;
    }
  }
});
