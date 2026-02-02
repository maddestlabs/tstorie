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
    const themeValue = UTF8ToString(themeValuePtr);
    console.log('✅ [URL OVERRIDE] Successfully applied URL theme:', themeValue);
  },
  
  tStorie_logUrlThemeFailed: function(themeValuePtr) {
    const themeValue = UTF8ToString(themeValuePtr);
    console.log('❌ [URL OVERRIDE] Failed to apply URL theme:', themeValue);
  },
  
  tStorie_logNoUrlTheme: function() {
    console.log('ℹ️  [URL PARAM] No URL theme parameter - using front matter or default theme');
  }
});
