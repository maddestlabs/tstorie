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
  },

  // Load custom font from Google Fonts or URL
  emLoadFont: function(fontNamePtr) {
    if (typeof window === 'undefined') return;
    
    const fontName = UTF8ToString(fontNamePtr);
    if (!fontName) return;
    
    try {
      console.log('[WASM] Loading font from front matter:', fontName);
      let actualUrl = fontName;
      let fontFamily = '';
      
      // Check if it's a full URL or just a font name
      if (fontName.startsWith('http://') || fontName.startsWith('https://')) {
        // It's a full URL
        const fontMatch = fontName.match(/family=([^:&]+)/);
        if (fontMatch) {
          fontFamily = fontMatch[1].replace(/\+/g, ' ');
        }
      } else {
        // It's just a font name, construct Google Fonts URL
        fontFamily = fontName.replace(/-/g, ' ');
        actualUrl = 'https://fonts.googleapis.com/css2?family=' + fontName.replace(/\s+/g, '+') + '&display=swap';
      }
      
      console.log('[WASM] Loading font from:', actualUrl);
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = actualUrl;
      document.head.appendChild(link);
      
      if (fontFamily) {
        document.documentElement.style.setProperty('--custom-font-family', fontFamily);
        document.body.classList.add('custom-font');
        if (window.terminal && window.terminal.canvas) {
          window.terminal.canvas.classList.add('custom-font');
        }
        // Store font family for terminal to use
        const fullFontFamily = "'" + fontFamily + "', '3270-Regular', 'Consolas', 'Monaco', monospace";
        if (typeof Module !== 'undefined') {
          Module.customFontFamily = fullFontFamily;
        }
        
        // Force terminal to refresh with new font after a delay for font loading
        setTimeout(function() {
          // Update canvas element if it exists
          const canvas = window.canvas || document.getElementById('terminal');
          if (canvas && canvas.style) {
            canvas.style.fontFamily = fullFontFamily;
            console.log('[WASM] Applied font to canvas:', fontFamily);
          }
          
          // Update terminal element if it exists
          if (window.terminal && window.terminal.element && window.terminal.element.style) {
            window.terminal.element.style.fontFamily = fullFontFamily;
            console.log('[WASM] Applied font to terminal element:', fontFamily);
            if (window.terminal.refresh) {
              window.terminal.refresh(0, window.terminal.rows - 1);
            }
          }
        }, 500);  // Longer delay to ensure font is loaded
        
        console.log('[WASM] Applied custom font:', fontFamily);
      }
    } catch (e) {
      console.warn('[WASM] Error loading font:', e);
    }
  },

  // Load shader chain (semicolon-separated shader names)
  emLoadShaders: function(shadersPtr) {
    if (typeof window === 'undefined') return;

    // If URL explicitly specifies shaders, it takes precedence over front matter.
    try {
      const urlParams = new URLSearchParams(window.location.search);
      const urlShaders = (urlParams.get('shaders') || urlParams.get('shader') || '').trim();
      if (urlShaders) {
        console.log('[WASM] URL shaders specified; ignoring front matter shaders:', urlShaders);
        return;
      }
    } catch (e) {
      // ignore URL parsing issues and proceed with front matter
    }
    
    const shadersStr = UTF8ToString(shadersPtr);
    if (!shadersStr) return;
    
    try {
      console.log('[WASM] Loading shaders from front matter:', shadersStr);
      
      // Parse shader names - support both '+' and semicolon separators
      const shaderNames = shadersStr.split(/[+;]/).map(s => s.trim()).filter(s => s);
      if (shaderNames.length === 0) return;
      
      console.log('[WASM] Parsed shader names:', shaderNames);
      
      // Check if loadSingleShader function exists (from index-webgpu.html)
      if (typeof window.loadSingleShader !== 'function') {
        console.warn('[WASM] loadSingleShader not available, shaders cannot be loaded');
        return;
      }
      
      // Load all shaders using the HTML's loader
      Promise.all(shaderNames.map(window.loadSingleShader))
        .then(function(results) {
          console.log('[WASM] All shaders loaded from frontmatter:', results.map(r => r.name).join(' → '));
          
          // Store shader codes globally and initialize shader system
          window.shaderCodes = results;
          window.shaderReady = true;
          
          if (typeof window.initShaderSystem === 'function') {
            window.initShaderSystem();
          } else {
            console.warn('[WASM] Shader system not available');
          }
        })
        .catch(function(error) {
          console.warn('[WASM] Error loading shaders from frontmatter:', error);
        });
      
    } catch (e) {
      console.warn('[WASM] Error loading shaders:', e);
    }
  }
});
