// TStorie Hybrid Renderer
// Progressive Enhancement: WebGPU → WebGL fallback
// Automatically selects best available rendering backend

class TStorieHybridRenderer {
    constructor(canvasElement, options = {}) {
        this.canvas = canvasElement;
        this.options = {
            fontFamily: options.fontFamily || "'3270-Regular', 'Consolas', 'Monaco', monospace",
            fontSize: options.fontSize || 16,
            preferWebGPU: options.preferWebGPU !== false,
            webgpuBridge: options.webgpuBridge || null,  // Shared WebGPU device
            fallbackToWebGL: options.fallbackToWebGL !== false
        };
        
        this.renderer = null;
        this.backend = null;  // 'webgpu' | 'webgl' | null
        this.initialized = false;
        this.initPromise = null;
    }
    
    /**
     * Initialize renderer - tries WebGPU first, falls back to WebGL
     */
    async init() {
        if (this.initialized) return this.backend;
        if (this.initPromise) return this.initPromise;
        
        this.initPromise = (async () => {
            console.log('[Hybrid Renderer] Initializing...');
            
            // Try WebGPU first if preferred
            if (this.options.preferWebGPU && this.isWebGPUAvailable()) {
                console.log('[Hybrid Renderer] Attempting WebGPU...');
                
                try {
                    // Get shared device from bridge if available
                    let sharedDevice = null;
                    if (this.options.webgpuBridge && this.options.webgpuBridge.isInitialized()) {
                        sharedDevice = this.options.webgpuBridge.getDevice();
                        console.log('[Hybrid Renderer] Using shared WebGPU device from bridge');
                    }
                    
                    // Create WebGPU renderer
                    this.renderer = new TStorieWebGPURender(
                        this.canvas,
                        sharedDevice,
                        this.options.fontFamily,
                        this.options.fontSize
                    );
                    
                    // Initialize
                    const success = await this.renderer.init();
                    
                    if (success) {
                        this.backend = 'webgpu';
                        this.initialized = true;
                        
                        // Register with bridge for unified device management
                        if (this.options.webgpuBridge) {
                            this.options.webgpuBridge.setRenderer(this.renderer);
                        }
                        
                        console.log('[Hybrid Renderer] ✓ WebGPU initialized successfully');
                        return 'webgpu';
                    } else {
                        console.warn('[Hybrid Renderer] WebGPU init failed');
                    }
                } catch (error) {
                    console.warn('[Hybrid Renderer] WebGPU error:', error);
                }
            }
            
            // Fall back to WebGL
            if (this.options.fallbackToWebGL) {
                console.log('[Hybrid Renderer] Falling back to WebGL...');
                
                try {
                    this.renderer = new TStorieTerminal(
                        this.canvas,
                        this.options.fontFamily,
                        this.options.fontSize
                    );
                    
                    this.backend = 'webgl';
                    this.initialized = true;
                    console.log('[Hybrid Renderer] ✓ WebGL initialized successfully');
                    return 'webgl';
                } catch (error) {
                    console.error('[Hybrid Renderer] WebGL init failed:', error);
                    this.backend = null;
                    return null;
                }
            }
            
            console.error('[Hybrid Renderer] No rendering backend available');
            this.backend = null;
            return null;
        })();
        
        return this.initPromise;
    }
    
    /**
     * Check if WebGPU is available in this browser
     */
    isWebGPUAvailable() {
        return typeof navigator !== 'undefined' && 
               navigator.gpu !== undefined &&
               typeof TStorieWebGPURender !== 'undefined';
    }
    
    /**
     * Check if WebGL is available in this browser
     */
    isWebGLAvailable() {
        try {
            const testCanvas = document.createElement('canvas');
            const gl = testCanvas.getContext('webgl2');
            return gl !== null;
        } catch {
            return false;
        }
    }
    
    /**
     * Get current backend name
     */
    getBackend() {
        return this.backend;
    }
    
    /**
     * Check if renderer is using WebGPU
     */
    isWebGPU() {
        return this.backend === 'webgpu';
    }
    
    /**
     * Check if renderer is using WebGL
     */
    isWebGL() {
        return this.backend === 'webgl';
    }
    
    /**
     * Render terminal cells
     * Forwards to appropriate backend
     */
    render(cells) {
        if (!this.initialized || !this.renderer) {
            console.warn('[Hybrid Renderer] Not initialized');
            return;
        }
        
        this.renderer.render(cells);
    }
    
    /**
     * Resize terminal
     */
    resize(cols, rows) {
        if (this.renderer) {
            this.renderer.resize(cols, rows);
        }
    }
    
    /**
     * Get terminal dimensions
     */
    getDimensions() {
        if (!this.renderer) return { cols: 80, rows: 24 };
        return {
            cols: this.renderer.cols,
            rows: this.renderer.rows
        };
    }
    
    /**
     * Get character dimensions
     */
    getCharDimensions() {
        if (!this.renderer) return { width: 10, height: 20 };
        return {
            width: this.renderer.charWidth,
            height: this.renderer.charHeight
        };
    }
    
    /**
     * Get mouse position in terminal coordinates
     */
    getMousePosition() {
        if (!this.renderer) return { x: 0, y: 0 };
        return {
            x: this.renderer.mouseX,
            y: this.renderer.mouseY
        };
    }
    
    /**
     * Cache a character in the glyph atlas
     */
    cacheChar(char) {
        if (this.renderer && this.renderer.cacheChar) {
            return this.renderer.cacheChar(char);
        }
        return null;
    }
    
    /**
     * Cache a range of characters
     */
    cacheCharRange(start, end) {
        if (this.renderer && this.renderer.cacheCharRange) {
            this.renderer.cacheCharRange(start, end);
        }
    }
    
    /**
     * Export canvas as PNG (if supported)
     */
    async exportPNG() {
        if (!this.canvas) return null;
        
        return new Promise((resolve) => {
            this.canvas.toBlob((blob) => {
                resolve(blob);
            }, 'image/png');
        });
    }
    
    /**
     * Get rendering statistics
     */
    getStats() {
        const stats = {
            backend: this.backend,
            initialized: this.initialized,
            webgpuAvailable: this.isWebGPUAvailable(),
            webglAvailable: this.isWebGLAvailable()
        };
        
        if (this.renderer) {
            stats.cols = this.renderer.cols;
            stats.rows = this.renderer.rows;
            stats.charWidth = this.renderer.charWidth;
            stats.charHeight = this.renderer.charHeight;
            stats.glyphsCached = this.renderer.glyphCache ? this.renderer.glyphCache.size : 0;
        }
        
        return stats;
    }
    
    /**
     * API compatibility methods for existing TStorie code
     */
    get cols() {
        return this.renderer ? this.renderer.cols : 80;
    }
    
    get rows() {
        return this.renderer ? this.renderer.rows : 24;
    }
    
    get charWidth() {
        return this.renderer ? this.renderer.charWidth : 10;
    }
    
    get charHeight() {
        return this.renderer ? this.renderer.charHeight : 20;
    }
    
    getCharPixelWidth() {
        return this.getCharDimensions().width;
    }
    
    getCharPixelHeight() {
        return this.getCharDimensions().height;
    }
    
    getViewportPixelWidth() {
        return typeof window !== 'undefined' ? window.innerWidth : 800;
    }
    
    getViewportPixelHeight() {
        return typeof window !== 'undefined' ? window.innerHeight : 600;
    }
    
    setFontSize(size) {
        if (this.renderer && this.renderer.setFontSize) {
            this.renderer.setFontSize(size);
        }
    }
    
    setFontScale(scale) {
        if (this.renderer && this.renderer.setFontScale) {
            this.renderer.setFontScale(scale);
        }
    }
    
    startAnimationLoop() {
        // Delegate to underlying renderer
        if (this.renderer && this.renderer.startAnimationLoop) {
            console.log('[Hybrid Renderer] Starting animation loop via', this.backend, 'renderer');
            this.renderer.startAnimationLoop();
        } else {
            console.warn('[Hybrid Renderer] No startAnimationLoop method on renderer');
        }
    }
    
    /**
     * Cleanup resources
     */
    destroy() {
        if (this.renderer && this.renderer.destroy) {
            this.renderer.destroy();
        }
        this.renderer = null;
        this.backend = null;
        this.initialized = false;
    }
}

// Export for use in TStorie
if (typeof window !== 'undefined') {
    window.TStorieHybridRenderer = TStorieHybridRenderer;
}

/**
 * Helper function to create renderer with automatic backend selection
 * 
 * Usage:
 *   const renderer = await createTStorieRenderer(canvas, {
 *     preferWebGPU: true,
 *     webgpuBridge: window.webgpuBridge  // Optional shared device
 *   });
 *   
 *   console.log('Using backend:', renderer.getBackend());
 *   renderer.render(cells);
 */
async function createTStorieRenderer(canvas, options = {}) {
    const renderer = new TStorieHybridRenderer(canvas, options);
    await renderer.init();
    return renderer;
}

if (typeof window !== 'undefined') {
    window.createTStorieRenderer = createTStorieRenderer;
}
