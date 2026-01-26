/**
 * TStorie Asset Loader
 * On-demand asset loading to reduce initial bundle size
 */

class AssetLoader {
  constructor() {
    this.loadedAssets = new Map();
    this.loadingPromises = new Map();
    this.cacheEnabled = true;
  }
  
  /**
   * Load a font on-demand
   */
  async loadFont(fontPath, fontFamily = 'KodeMono') {
    const cacheKey = `font:${fontPath}`;
    
    if (this.loadedAssets.has(cacheKey)) {
      return this.loadedAssets.get(cacheKey);
    }
    
    if (this.loadingPromises.has(cacheKey)) {
      return this.loadingPromises.get(cacheKey);
    }
    
    const loadPromise = (async () => {
      try {
        console.log(`[Assets] Loading font: ${fontPath}`);
        
        const response = await fetch(fontPath);
        const blob = await response.blob();
        const fontFace = new FontFace(fontFamily, `url(${URL.createObjectURL(blob)})`);
        
        await fontFace.load();
        document.fonts.add(fontFace);
        
        this.loadedAssets.set(cacheKey, fontFace);
        console.log(`[Assets] Font loaded: ${fontFamily}`);
        
        return fontFace;
      } catch (error) {
        console.error(`[Assets] Failed to load font ${fontPath}:`, error);
        throw error;
      }
    })();
    
    this.loadingPromises.set(cacheKey, loadPromise);
    return loadPromise;
  }
  
  /**
   * Preload demo content in background
   */
  async preloadDemo(demoName) {
    const cacheKey = `demo:${demoName}`;
    
    if (this.loadedAssets.has(cacheKey)) {
      return this.loadedAssets.get(cacheKey);
    }
    
    try {
      const paths = [
        `demos/${demoName}.md`,
        `presets/${demoName}.md`,
        `docs/demos/${demoName}.md`
      ];
      
      for (const path of paths) {
        try {
          const response = await fetch(path);
          if (response.ok) {
            const content = await response.text();
            this.loadedAssets.set(cacheKey, content);
            return content;
          }
        } catch (e) {
          // Try next path
        }
      }
      
      throw new Error(`Demo not found: ${demoName}`);
    } catch (error) {
      console.error(`[Assets] Failed to preload demo ${demoName}:`, error);
      throw error;
    }
  }
  
  /**
   * Get estimated size of an asset
   */
  async getAssetSize(url) {
    try {
      const response = await fetch(url, { method: 'HEAD' });
      const size = response.headers.get('content-length');
      return size ? parseInt(size) : null;
    } catch (error) {
      return null;
    }
  }
  
  /**
   * Clear cache
   */
  clearCache() {
    this.loadedAssets.clear();
    this.loadingPromises.clear();
  }
}

// Export for use in HTML
window.AssetLoader = AssetLoader;
