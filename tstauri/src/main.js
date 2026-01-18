// @ts-check
import { invoke, convertFileSrc } from '@tauri-apps/api/core'
import { getCurrentWindow } from '@tauri-apps/api/window'
import { listen } from '@tauri-apps/api/event'

let tstorieInstance = null;
let currentMarkdownPath = null;
let tstorieInitialized = false;

const dropZone = document.getElementById('drop-zone');
const tstorieContainer = document.getElementById('tstorie-container');
const controls = document.getElementById('controls');
const status = document.getElementById('status');
const resetBtn = document.getElementById('reset-btn');

// Load tStorie WASM engine
async function loadTStorieEngine() {
    try {
        // Intercept shader fetch requests to use bundled shaders
        const originalFetch = window.fetch;
        window.fetch = async function(url, ...args) {
            // Check if this is a shader request
            if (typeof url === 'string' && url.startsWith('shaders/') && url.endsWith('.js')) {
                const shaderName = url.replace('shaders/', '').replace('.js', '');
                console.log('Intercepting shader request:', shaderName);
                
                try {
                    const shaderContent = await invoke('load_bundled_shader', { shaderName });
                    console.log('✓ Loaded bundled shader:', shaderName);
                    
                    // Return a Response object that fetch would normally return
                    return new Response(shaderContent, {
                        status: 200,
                        statusText: 'OK',
                        headers: {
                            'Content-Type': 'application/javascript'
                        }
                    });
                } catch (error) {
                    console.log('Bundled shader not found, falling back to Gist:', error);
                    // Fall back to original fetch (will try Gist)
                    return originalFetch(url, ...args);
                }
            }
            
            // For all other requests, use original fetch
            return originalFetch(url, ...args);
        };
        
        // Get the bundled WASM files path
        const resourcePath = await invoke('get_bundled_wasm_path');
        console.log('Resource path:', resourcePath);
        
        // Pre-load all WASM files as blob URLs (Emscripten needs synchronous access)
        console.log('Pre-loading WASM files...');
        const wasmFiles = {};
        
        // Load tstorie.wasm.wasm
        console.log('Loading tstorie.wasm.wasm...');
        const wasmBytes = await invoke('get_bundled_wasm_file', { filename: 'tstorie.wasm.wasm' });
        const wasmBlob = new Blob([new Uint8Array(wasmBytes)], { type: 'application/wasm' });
        wasmFiles['tstorie.wasm.wasm'] = URL.createObjectURL(wasmBlob);
        console.log('✓ Created blob URL for tstorie.wasm.wasm');
        
        // Load tstorie.wasm.js (Emscripten runtime - this is what we'll load first)
        console.log('Loading tstorie.wasm.js (Emscripten runtime)...');
        const wasmJsBytes = await invoke('get_bundled_wasm_file', { filename: 'tstorie.wasm.js' });
        const wasmJsBlob = new Blob([new Uint8Array(wasmJsBytes)], { type: 'application/javascript' });
        const wasmJsUrl = URL.createObjectURL(wasmJsBlob);
        console.log('✓ Created blob URL for tstorie.wasm.js');
        
        // Load tstorie-webgl.js (WebGL renderer - must be loaded before tstorie.js)
        console.log('Loading tstorie-webgl.js (WebGL renderer)...');
        const webglBytes = await invoke('get_bundled_wasm_file', { filename: 'tstorie-webgl.js' });
        const webglBlob = new Blob([new Uint8Array(webglBytes)], { type: 'application/javascript' });
        const webglUrl = URL.createObjectURL(webglBlob);
        console.log('✓ Created blob URL for tstorie-webgl.js');
        
        // Load tstorie.js (terminal wrapper - we'll load this after WASM initializes)
        console.log('Loading tstorie.js (terminal wrapper)...');
        const tsJsBytes = await invoke('get_bundled_wasm_file', { filename: 'tstorie.js' });
        const tsJsBlob = new Blob([new Uint8Array(tsJsBytes)], { type: 'application/javascript' });
        const tsJsUrl = URL.createObjectURL(tsJsBlob);
        console.log('✓ Created blob URL for tstorie.js');
        
        console.log('✓ All WASM files pre-loaded');
        
        // Wait for canvas to be accessible (must be visible in DOM)
        console.log('Waiting for terminal canvas element...');
        let canvas = null;
        for (let i = 0; i < 20; i++) {  // Increased attempts
            canvas = document.getElementById('terminal');
            if (canvas) {
                console.log('✓ Terminal canvas found on attempt', i + 1);
                break;
            }
            console.log('Canvas not found, waiting... attempt', i + 1);
            await new Promise(resolve => setTimeout(resolve, 100));  // Increased interval
        }
        
        if (!canvas) {
            throw new Error('Canvas element not found after 2 seconds');
        }
        
        // Set up the Module object BEFORE loading the script
        return new Promise((resolve, reject) => {
            let initTimeout;
            
            window.Module = {
                preRun: [],
                postRun: [],
                canvas: canvas,
                setStatus: function(text) {
                    if (text) {
                        console.log('Module status:', text);
                    }
                },
                // This callback fires when the WASM runtime is fully initialized
                onRuntimeInitialized: function() {
                    console.log('✓ WASM runtime initialized');
                    console.log('Module._emInit available:', !!window.Module._emInit);
                    
                    // Clear the global timeout
                    if (initTimeout) {
                        clearTimeout(initTimeout);
                    }
                    
                    // Load WebGL renderer FIRST (required for TStorieTerminal class)
                    console.log('Loading tstorie-webgl.js renderer...');
                    const webglScript = document.createElement('script');
                    webglScript.src = webglUrl;
                    webglScript.onload = () => {
                        console.log('✓ tstorie-webgl.js loaded (WebGL renderer ready)');
                        
                        // Now load tstorie.js which contains the inittstorie() function
                        console.log('Loading tstorie.js wrapper...');
                        const tsScript = document.createElement('script');
                        tsScript.src = tsJsUrl;
                        tsScript.onload = () => {
                            console.log('✓ tstorie.js loaded');
                            
                            // Now wait for inittstorie to be defined
                            let attempts = 0;
                            const checkInit = setInterval(() => {
                                attempts++;
                                console.log(`Checking for inittstorie... attempt ${attempts}`);
                                
                                if (window.inittstorie && typeof window.inittstorie === 'function') {
                                    clearInterval(checkInit);
                                    console.log('✓ inittstorie function ready');
                                    
                                    // Verify canvas is still accessible
                                    const canvasCheck = document.getElementById('terminal');
                                    console.log('Pre-init terminal canvas check:', {
                                        'getElementById': !!canvasCheck,
                                        'Module.canvas': !!window.Module.canvas,
                                        'canvasCheck === Module.canvas': canvasCheck === window.Module.canvas
                                    });
                                    
                                    showStatus('⚡ Starting tStorie engine...', false);
                                    
                                    // Call inittstorie to set up the terminal
                                    window.inittstorie().then(() => {
                                        console.log('✓ tStorie engine initialized successfully');
                                        console.log('Module ready:', !!window.Module);
                                        console.log('emLoadMarkdownFromJS:', !!window.Module?._emLoadMarkdownFromJS);
                                        showStatus('✓ Ready to load files', false);
                                        resolve();
                                    }).catch(err => {
                                        console.error('❌ Failed to initialize tStorie:', err);
                                        showStatus('❌ Init failed: ' + err.message, true);
                                        reject(err);
                                    });
                                }
                            }, 100);
                            
                            // Timeout after 5 seconds waiting for inittstorie
                            setTimeout(() => {
                                clearInterval(checkInit);
                                if (!window.inittstorie) {
                                    const msg = 'Timeout waiting for inittstorie after ' + attempts + ' attempts';
                                    console.error('❌ ' + msg);
                                    showStatus('❌ ' + msg, true);
                                    reject(new Error(msg));
                                }
                            }, 5000);
                        };
                        tsScript.onerror = (err) => {
                            console.error('❌ Failed to load tstorie.js:', err);
                            reject(err);
                        };
                        document.head.appendChild(tsScript);
                    };
                    webglScript.onerror = (err) => {
                        console.error('❌ Failed to load tstorie-webgl.js:', err);
                        reject(err);
                    };
                    document.head.appendChild(webglScript);
                },
                // Override getElementById to ensure canvas is found
                locateCanvas: function() {
                    const c = document.getElementById('terminal');
                    console.log('locateCanvas called, found:', !!c);
                    return c || canvas; // fallback to our stored reference
                },
                // Synchronously return pre-loaded WASM blob URLs
                locateFile: function(path, prefix) {
                    console.log(`Module requesting: ${path}`);
                    if (wasmFiles[path]) {
                        console.log(`✓ Returning pre-loaded blob URL for ${path}`);
                        return wasmFiles[path];
                    }
                    console.log(`⚠ File ${path} not pre-loaded, using default path`);
                    return prefix + path;
                }
            };
        
        // Set up a global timeout for the entire initialization
        initTimeout = setTimeout(() => {
            const msg = 'Timeout: WASM runtime did not initialize within 30 seconds';
            console.error('❌ ' + msg);
            showStatus('❌ ' + msg, true);
            reject(new Error(msg));
        }, 30000);
        
        // Load the Emscripten WASM runtime (tstorie.wasm.js) - NOT tstorie.js
        const script = document.createElement('script');
        script.src = wasmJsUrl;  // Load WASM runtime, not terminal wrapper
        script.onerror = (err) => {
            if (initTimeout) clearTimeout(initTimeout);
            console.error('❌ Script load error:', err);
            showStatus('❌ Failed to load WASM runtime', true);
            reject(err);
        };
        
        // Just append the script - onRuntimeInitialized callback will handle the rest
        console.log('✓ Loading Emscripten WASM runtime...');
        showStatus('⏳ Loading WASM module...', false);
        document.head.appendChild(script);
        });
    } catch (error) {
        console.error('Failed to load tStorie engine:', error);
        showStatus('❌ Failed to load tStorie engine', true);
        throw error;
    }
}

// Run a markdown file
async function runMarkdown(filePath) {
    console.log('=== runMarkdown called ===');
    console.log('File path:', filePath);
    
    try {
        showStatus('📖 Reading file...', false);
        console.log('Invoking load_markdown_content...');
        
        // Load the markdown content
        const content = await invoke('load_markdown_content', { path: filePath });
        await loadMarkdownContent(content, filePath);
        
    } catch (error) {
        console.error('❌ Failed to run markdown:', error);
        console.error('Error stack:', error.stack);
        showStatus('❌ ' + error.message, true);
    }
}

// Load markdown content (shared by file drop and welcome screen)
async function loadMarkdownContent(content, sourceName = 'content') {
    console.log('✓ Content read successfully, length:', content.length);
    console.log('First 100 chars:', content.substring(0, 100));
    
    currentMarkdownPath = sourceName;
    const fileName = sourceName.split(/[\\/]/).pop();
    
    // Show container BEFORE initializing tStorie (canvas must be visible)
    console.log('Showing container for tStorie initialization...');
    dropZone.classList.add('hidden');
    tstorieContainer.classList.add('active');
    controls.classList.add('active');
    
    // Wait a moment for the DOM to update and canvas to be rendered
    await new Promise(resolve => setTimeout(resolve, 50));
    
    // Initialize tStorie on first load (now that canvas is visible and rendered)
    if (!tstorieInitialized) {
        console.log('First load - initializing tStorie engine...');
        showStatus('⚡ Initializing tStorie engine...', false);
        try {
            await loadTStorieEngine();
            tstorieInitialized = true;
            console.log('✓ tStorie engine ready');
        } catch (error) {
            console.error('Failed to initialize tStorie:', error);
            showStatus('❌ Failed to initialize: ' + error.message, true);
            // Reset UI on failure
            resetToDropZone();
            return;
        }
    }
    
    showStatus(`✓ Loaded: ${fileName}`, false);
    
    // Check Module state
    console.log('=== Checking Module state ===');
    console.log('window.Module exists:', !!window.Module);
    console.log('Module.ccall exists:', !!(window.Module && window.Module.ccall));
    console.log('Module._emLoadMarkdownFromJS exists:', !!(window.Module && window.Module._emLoadMarkdownFromJS));
        
        // Load markdown into tStorie WASM module
        if (window.Module && typeof window.Module.ccall === 'function') {
            console.log('Using Module.ccall to load markdown...');
            showStatus('⚡ Loading into engine (ccall)...', false);
            try {
                window.Module.ccall(
                    'emLoadMarkdownFromJS',
                    null,
                    ['string'],
                    [content],
                    { async: false }
                );
                console.log('✓ Markdown loaded successfully via ccall');
                showStatus('✓ Running: ' + fileName, false);
            } catch (err) {
                console.error('❌ Failed to call emLoadMarkdownFromJS:', err);
                showStatus('❌ Load failed (ccall): ' + err.message, true);
            }
        } else if (window.Module && typeof window.Module._emLoadMarkdownFromJS === 'function') {
            console.log('Using Module._emLoadMarkdownFromJS to load markdown...');
            showStatus('⚡ Loading into engine (direct)...', false);
            try {
                const len = window.Module.lengthBytesUTF8(content) + 1;
                const strPtr = window.Module._malloc(len);
                console.log('Allocated', len, 'bytes at', strPtr);
                window.Module.stringToUTF8(content, strPtr, len);
                window.Module._emLoadMarkdownFromJS(strPtr);
                window.Module._free(strPtr);
                console.log('✓ Markdown loaded successfully via direct call');
                showStatus('✓ Running: ' + fileName, false);
            } catch (err) {
                console.error('❌ Failed to call _emLoadMarkdownFromJS:', err);
                showStatus('❌ Load failed (direct): ' + err.message, true);
            }
        } else {
            console.error('❌ Module not ready or emLoadMarkdownFromJS not found');
            console.log('Available Module properties:', window.Module ? Object.keys(window.Module).filter(k => k.includes('em')).join(', ') : 'Module not defined');
            showStatus('❌ tStorie engine not ready', true);
        }
}

// Load welcome screen
async function loadWelcomeScreen() {
    try {
        console.log('Loading bundled welcome screen...');
        const welcomeContent = await invoke('load_bundled_welcome');
        await loadMarkdownContent(welcomeContent, 'Welcome');
        console.log('✓ Welcome screen loaded');
    } catch (error) {
        console.error('Failed to load welcome screen:', error);
        // If welcome screen fails, just stay on drop zone
        console.log('Staying on drop zone');
    }
}

// Reset to drop zone
function resetToDropZone() {
    currentMarkdownPath = null;
    console.log('Returning to welcome screen...');
    loadWelcomeScreen();
}

// Show status message
function showStatus(message, isError = false) {
    status.textContent = message;
    status.style.color = isError ? '#ff4444' : '#00d4ff';
    status.classList.add('active');
    
    if (!isError) {
        setTimeout(() => {
            status.classList.remove('active');
        }, 3000);
    }
}

// Event listeners
resetBtn.addEventListener('click', resetToDropZone);

// Listen for file drop events from Tauri
await listen('file-dropped', async (event) => {
    const filePath = event.payload;
    console.log('=== FILE DROP EVENT RECEIVED ===');
    console.log('File path:', filePath);
    console.log('Event:', event);
    showStatus('📄 File dropped: ' + filePath.split(/[\\/]/).pop(), false);
    
    try {
        await runMarkdown(filePath);
    } catch (error) {
        console.error('Error in file drop handler:', error);
        showStatus('❌ Error: ' + error.message, true);
    }
});

// Listen for command-line file arguments (file dropped on exe)
await listen('cli-file-arg', async (event) => {
    const filePath = event.payload;
    console.log('=== COMMAND-LINE FILE ARGUMENT RECEIVED ===');
    console.log('File path:', filePath);
    console.log('Event:', event);
    showStatus('📂 Opening: ' + filePath.split(/[\\/]/).pop(), false);
    
    try {
        await runMarkdown(filePath);
    } catch (error) {
        console.error('Error in CLI file handler:', error);
        showStatus('❌ Error: ' + error.message, true);
    }
});

console.log('✓ File drop listener registered');
console.log('✓ CLI file argument listener registered');
console.log('✓ tStauri ready');

// Load welcome screen automatically on startup
loadWelcomeScreen();

// Keyboard shortcuts
window.addEventListener('keydown', (e) => {
    // Escape to return to welcome screen
    if (e.key === 'Escape' && currentMarkdownPath && currentMarkdownPath !== 'Welcome') {
        resetToDropZone();
    }
});

console.log('tStauri initialized');
