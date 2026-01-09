// Font metrics bridge for Nim/WASM
// Provides access to font measurement and scaling functions

mergeInto(LibraryManager.library, {
  emGetCharPixelWidth: function() {
    if (typeof window !== 'undefined' && window.terminal) {
      return window.terminal.getCharPixelWidth();
    }
    return 10; // Default fallback
  },

  emGetCharPixelHeight: function() {
    if (typeof window !== 'undefined' && window.terminal) {
      return window.terminal.getCharPixelHeight();
    }
    return 20; // Default fallback
  },

  emGetViewportPixelWidth: function() {
    if (typeof window !== 'undefined') {
      return window.innerWidth;
    }
    return 800; // Default fallback
  },

  emGetViewportPixelHeight: function() {
    if (typeof window !== 'undefined') {
      return window.innerHeight;
    }
    return 600; // Default fallback
  },

  emSetFontSize: function(size) {
    if (typeof window !== 'undefined' && window.terminal) {
      window.terminal.setFontSize(size);
    }
  },

  emSetFontScale: function(scale) {
    if (typeof window !== 'undefined' && window.terminal) {
      window.terminal.setFontScale(scale);
    }
  }
});
