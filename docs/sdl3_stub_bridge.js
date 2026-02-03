/**
 * SDL3 Stub Bridge
 * 
 * Provides no-op implementations of JS bridge functions for SDL3 builds
 * SDL3 uses native font rendering, so these terminal-specific functions are not needed
 * 
 * NOTE: FIGlet fonts are handled by web/figlet_bridge.js (included separately)
 */

mergeInto(LibraryManager.library, {
  emLoadFont: function(fontNamePtr) {
    // No-op: SDL3 uses native TTF font loading
  },
  
  emLoadShaders: function(shadersPtr) {
    // No-op: SDL3 handles rendering natively
  },
  
  emSetFontSize: function(size) {
    // No-op: SDL3 uses native font sizing
  },
  
  emSetFontScale: function(scale) {
    // No-op: SDL3 uses native font scaling
  }
});
