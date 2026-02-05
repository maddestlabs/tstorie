#!/bin/bash
# TStorie WASM compiler with WebGPU support
# Based on build-web.sh but adds WebGPU compute capabilities

VERSION="0.1.0"

show_help() {
    cat << EOF
TStorie WASM compiler with WebGPU support v$VERSION
Compile TStorie for web deployment with GPU-accelerated noise generation

Usage: ./build-web-webgpu.sh [OPTIONS]

Options:
  -h, --help            Show this help message
  -v, --version         Show version information
  -d, --debug           Compile in debug mode (default is release with size optimization)
  -s, --serve           Start a local web server after compilation
  -o, --output DIR      Output directory (default: docs)

Examples:
  ./build-web-webgpu.sh                   # Compile to WASM with WebGPU
  ./build-web-webgpu.sh -d                # Compile in debug mode
  ./build-web-webgpu.sh -s                # Compile and serve
  ./build-web-webgpu.sh -o docs           # Output to docs/ (for GitHub Pages)

The compiled files will be placed in the specified output directory.

Features:
  - WebGPU rendering pipeline (Phase 6 - unified GPU context)
  - WebGPU compute shaders (GPU-accelerated noise)
  - Hybrid renderer with progressive enhancement (WebGPU → WebGL)
  - 50-300× performance improvement for complex multi-octave noise
  - Automatic fallback to WebGL for older browsers

Requirements:
  - Nim compiler with Emscripten support
  - Emscripten SDK (emcc)
  - Browser with WebGPU support (Chrome 113+, Edge 113+, Safari 18+)

Setup Emscripten:
  git clone https://github.com/emscripten-core/emsdk.git
  cd emsdk
  ./emsdk install latest
  ./emsdk activate latest
  source ./emsdk_env.sh

EOF
}

RELEASE_MODE="-d:release --opt:size -d:strip -d:useMalloc"
SERVE=false
OUTPUT_DIR="docs"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "tstorie WASM compiler with WebGPU support version $VERSION"
            exit 0
            ;;
        -d|--debug)
            RELEASE_MODE=""
            shift
            ;;
        -s|--serve)
            SERVE=true
            shift
            ;;
        -o|--output)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                OUTPUT_DIR="$2"
                shift 2
            else
                echo "Error: --output requires a directory argument"
                exit 1
            fi
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check for Emscripten
if ! command -v emcc &> /dev/null; then
    echo "Error: Emscripten (emcc) not found!"
    echo ""
    echo "Please install and activate Emscripten:"
    echo "  git clone https://github.com/emscripten-core/emsdk.git"
    echo "  cd emsdk"
    echo "  ./emsdk install latest"
    echo "  ./emsdk activate latest"
    echo "  source ./emsdk_env.sh"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Compiling tstorie to WASM with WebGPU support..."
echo "Output directory: $OUTPUT_DIR"
echo ""

# Emscripten compilation flags
export EMCC_CFLAGS="-Os"

# Nim compiler options for Emscripten
NIM_OPTS="c
  --path:nimini/src
  --cpu:wasm32
  --os:linux
  --cc:clang
  --clang.exe:emcc
  --clang.linkerexe:emcc
  --clang.cpp.exe:emcc
  --clang.cpp.linkerexe:emcc
  -d:emscripten
  -d:noSignalHandler
  --threads:off
  --exceptions:goto
  $RELEASE_MODE
  --nimcache:nimcache_wasm
  --passL:-s --passL:ALLOW_MEMORY_GROWTH=1
    --passL:-s --passL:EXPORTED_FUNCTIONS=['_malloc','_free','_emInit','_emUpdate','_emResize','_emGetCell','_emGetCellFgR','_emGetCellFgG','_emGetCellFgB','_emGetCellBgR','_emGetCellBgG','_emGetCellBgB','_emGetCellBold','_emGetCellItalic','_emGetCellUnderline','_emGetCellWidth','_emHandleKeyPress','_emHandleTextInput','_emHandleMouseClick','_emHandleMouseRelease','_emHandleMouseMove','_emHandleMouseWheel','_emSetWaitingForGist','_emLoadMarkdownFromJS','_emCheckDropTarget','_emHandleDroppedFile','_emscripten_setParam_internal','_invokeComputeCallback']
  --passL:-s --passL:EXPORTED_RUNTIME_METHODS=['ccall','cwrap','allocateUTF8','UTF8ToString','lengthBytesUTF8','stringToUTF8']
  --passL:-s --passL:MODULARIZE=0
  --passL:-s --passL:EXPORT_NAME='Module'
  --passL:-s --passL:ENVIRONMENT=web
  --passL:-s --passL:INITIAL_MEMORY=33554432
  --passL:-s --passL:STACK_SIZE=5242880
  --passL:-s --passL:ASSERTIONS=0
  --passL:-s --passL:STACK_OVERFLOW_CHECK=0
  --passL:-Os
  --passL:-flto
  --passL:--js-library --passL:web/console_bridge.js \
  --passL:--js-library --passL:web/audio_bridge.js \
  --passL:--js-library --passL:web/figlet_bridge.js \
  --passL:--js-library --passL:web/document_bridge.js \
  --passL:--js-library --passL:web/font_metrics_bridge.js \
  --passL:--js-library --passL:web/file_drop_bridge.js \
  --passL:--js-library --passL:web/webgpu_bridge_extern.js \
  --passL:--js-library --passL:web/file_drop_bridge.js \
  -o:$OUTPUT_DIR/tstorie.wasm.js \
  tstorie.nim"

# Compile
echo "Running Nim compiler..."
nim $NIM_OPTS

if [ $? -ne 0 ]; then
    echo ""
    echo "Compilation failed!"
    exit 1
fi

echo ""
echo "✓ Compilation successful!"
echo ""
echo "Output files:"
echo "  - $OUTPUT_DIR/tstorie.wasm.js"
echo "  - $OUTPUT_DIR/tstorie.wasm"
echo ""

# Copy supporting files from web/ template if they exist and output is different
if [ "$OUTPUT_DIR" != "web" ]; then
    if [ -f "web/tstorie.js" ]; then
        cp web/tstorie.js "$OUTPUT_DIR/tstorie.js"
        echo "  - $OUTPUT_DIR/tstorie.js (copied from web/)"
    fi
    
    # Copy index.md if it exists (needed at runtime)
    if [ -f "index.md" ]; then
        cp index.md "$OUTPUT_DIR/index.md"
        echo "  - $OUTPUT_DIR/index.md (runtime content)"
    fi
else
    echo "  - $OUTPUT_DIR/tstorie.js (JavaScript interface)"
    
    # Copy index.md if it exists (needed at runtime)
    if [ -f "index.md" ]; then
        cp index.md "$OUTPUT_DIR/index.md"
        echo "  - $OUTPUT_DIR/index.md (runtime content)"
    fi
fi

# Check for required supporting files and copy renderers
# PHASE 6: Now includes WebGPU render pipeline + hybrid renderer

# Copy WebGL renderer (fallback)
if [ ! -f "$OUTPUT_DIR/tstorie-webgl.js" ]; then
    if [ -f "web/tstorie-webgl.js" ]; then
        cp web/tstorie-webgl.js "$OUTPUT_DIR/tstorie-webgl.js"
        echo "  - $OUTPUT_DIR/tstorie-webgl.js (WebGL renderer - fallback)"
    else
        echo ""
        echo "Warning: web/tstorie-webgl.js not found."
        echo "         The WebGL renderer is required for fallback."
    fi
fi

# Copy WebGPU renderer (Phase 6)
if [ -f "web/tstorie-webgpu-render.js" ]; then
    cp web/tstorie-webgpu-render.js "$OUTPUT_DIR/tstorie-webgpu-render.js"
    echo "  - $OUTPUT_DIR/tstorie-webgpu-render.js (WebGPU renderer - Phase 6)"
else
    echo ""
    echo "Warning: web/tstorie-webgpu-render.js not found."
    echo "         WebGPU rendering will not be available."
fi

# Copy Hybrid renderer (Phase 6 - progressive enhancement)
if [ -f "web/tstorie-hybrid-renderer.js" ]; then
    cp web/tstorie-hybrid-renderer.js "$OUTPUT_DIR/tstorie-hybrid-renderer.js"
    echo "  - $OUTPUT_DIR/tstorie-hybrid-renderer.js (Hybrid renderer - auto-selects backend)"
else
    echo ""
    echo "Warning: web/tstorie-hybrid-renderer.js not found."
    echo "         Hybrid rendering will not be available."
fi

# Copy Shader loader (WebGPU/WebGL auto-detection)
if [ -f "web/shader_loader.js" ]; then
    cp web/shader_loader.js "$OUTPUT_DIR/shader_loader.js"
    echo "  - $OUTPUT_DIR/shader_loader.js (WebGPU-aware shader loader)"
else
    echo ""
    echo "Warning: web/shader_loader.js not found."
    echo "         WGSL shader auto-loading will not be available."
fi

# Copy WebGPU shader system
if [ -f "web/webgpu_shader_system.js" ]; then
    cp web/webgpu_shader_system.js "$OUTPUT_DIR/webgpu_shader_system.js"
    echo "  - $OUTPUT_DIR/webgpu_shader_system.js (WebGPU shader chain renderer)"
else
    echo ""
    echo "Warning: web/webgpu_shader_system.js not found."
    echo "         WebGPU shader chains will not be available."
fi

# Copy WebGPU bridge for GPU-accelerated compute + unified device
if [ -f "web/webgpu_bridge.js" ]; then
    cp web/webgpu_bridge.js "$OUTPUT_DIR/webgpu_bridge.js"
    echo "  - $OUTPUT_DIR/webgpu_bridge.js (WebGPU compute + unified device)"
else
    echo ""
    echo "Warning: web/webgpu_bridge.js not found."
    echo "         WebGPU features will not be available."
fi

# Copy WebGPU WASM bridge for Nim->JS integration
if [ -f "web/webgpu_wasm_bridge.js" ]; then
    cp web/webgpu_wasm_bridge.js "$OUTPUT_DIR/webgpu_wasm_bridge.js"
    echo "  - $OUTPUT_DIR/webgpu_wasm_bridge.js (WASM integration)"
else
    echo ""
    echo "Warning: web/webgpu_wasm_bridge.js not found."
    echo "         GPU execution from Nim will not be available."
fi

# Create index-webgpu.html with Phase 6 full WebGPU support
if [ -f "web/index.html" ]; then
    # Copy base index.html
    cp web/index.html "$OUTPUT_DIR/index-webgpu.html"
    
    # Inject WebGPU scripts before the closing body tag
    # Order matters: bridge → shader system → renderers → WASM bridge
    sed -i 's|</body>|    <!-- WebGPU Phase 6: Full rendering + compute -->\n    <script src="webgpu_bridge.js"></script>\n    <script src="webgpu_shader_system.js"></script>\n    <script src="tstorie-webgpu-render.js"></script>\n    <script src="tstorie-hybrid-renderer.js"></script>\n    <script src="webgpu_wasm_bridge.js"></script>\n</body>|' "$OUTPUT_DIR/index-webgpu.html"
    
    echo "  - $OUTPUT_DIR/index-webgpu.html (Phase 6: Full WebGPU)"
    echo ""
    echo "✓ WebGPU Phase 6 integration complete"
else
    echo ""
    echo "Warning: web/index.html not found."
    echo "         Could not create index-webgpu.html"
fi

if [ ! -f "$OUTPUT_DIR/index.html" ]; then
    echo ""
    echo "Note: Creating standard index.html (WebGL only)..."
    if [ -f "web/index.html" ]; then
        cp web/index.html "$OUTPUT_DIR/index.html"
        echo "  - $OUTPUT_DIR/index.html (WebGL renderer)"
    fi
fi

echo ""
echo "Features included:"
echo "  ✓ WebGPU rendering pipeline (Phase 6 - unified GPU context)"
echo "  ✓ WebGPU compute shaders (GPU-accelerated noise)"
echo "  ✓ Hybrid renderer (WebGPU → WebGL fallback)"
echo "  ✓ WebGL fallback for older browsers"
echo ""
echo "Pages:"
echo "  - index.html         : Standard TStorie (WebGL only)"
echo "  - index-webgpu.html  : TStorie with WebGPU support"

# Start web server if requested
if [ "$SERVE" = true ]; then
    echo ""
    echo "Starting local web server..."
    echo "Open http://localhost:8000/index-webgpu.html in your browser"
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Try different server options
    if command -v python3 &> /dev/null; then
        cd "$OUTPUT_DIR" && python3 -m http.server 8000
    elif command -v python &> /dev/null; then
        cd "$OUTPUT_DIR" && python -m SimpleHTTPServer 8000
    elif command -v php &> /dev/null; then
        cd "$OUTPUT_DIR" && php -S localhost:8000
    else
        echo "Error: No web server available (tried python3, python, php)"
        echo "Please install Python or PHP, or serve the $OUTPUT_DIR/ directory manually."
        exit 1
    fi
else
    echo ""
    echo "To test the build:"
    echo "  cd $OUTPUT_DIR && python3 -m http.server 8000"
    echo "  Then open http://localhost:8000/index-webgpu.html in your browser"
    echo ""
    echo "Browser requirements:"
    echo "  - Chrome/Edge 113+ (full WebGPU support)"
    echo "  - Safari 18+ (macOS Sonoma 14.3+)"
    echo "  - Firefox Nightly (enable dom.webgpu.enabled flag)"
fi
