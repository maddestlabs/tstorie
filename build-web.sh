#!/bin/bash
# TStorie WASM compiler script

VERSION="0.1.0"

show_help() {
    cat << EOF
TStorie WASM compiler v$VERSION
Compile TStorie for web deployment

Usage: ./build-web.sh [OPTIONS]

Options:
  -h, --help            Show this help message
  -v, --version         Show version information
  -d, --debug           Compile in debug mode (default is release with size optimization)
  -s, --serve           Start a local web server after compilation
  -o, --output DIR      Output directory (default: docs)

Examples:
  ./build-web.sh                          # Compile to WASM
  ./build-web.sh -d                       # Compile in debug mode
  ./build-web.sh -s                       # Compile and serve
  ./build-web.sh -o docs                  # Output to docs/ (for GitHub Pages)
  ./build-web.sh -o .                     # Output to root directory

The compiled files will be placed in the specified output directory.

Note: Application logic is in src/runtime_api.nim
      (formerly index.nim, now part of the core engine)

Requirements:
  - Nim compiler with Emscripten support
  - Emscripten SDK (emcc)

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
            echo "tstorie WASM compiler version $VERSION"
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

echo "Compiling tstorie to WASM..."
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
  --passL:-s --passL:EXPORTED_FUNCTIONS=['_malloc','_free','_emInit','_emUpdate','_emResize','_emGetCell','_emGetCellFgR','_emGetCellFgG','_emGetCellFgB','_emGetCellBgR','_emGetCellBgG','_emGetCellBgB','_emGetCellBold','_emGetCellItalic','_emGetCellUnderline','_emGetCellWidth','_emHandleKeyPress','_emHandleTextInput','_emHandleMouseClick','_emHandleMouseRelease','_emHandleMouseMove','_emHandleMouseWheel','_emSetWaitingForGist','_emLoadMarkdownFromJS','_emCheckDropTarget','_emHandleDroppedFile','_emscripten_setParam_internal']
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
    if [ -f "web/index.html" ]; then
        cp web/index.html "$OUTPUT_DIR/index.html"
        echo "  - $OUTPUT_DIR/index.html (copied from web/)"
    fi
    # Copy index.md if it exists (needed at runtime)
    if [ -f "index.md" ]; then
        cp index.md "$OUTPUT_DIR/index.md"
        echo "  - $OUTPUT_DIR/index.md (runtime content)"
    fi
else
    echo "  - $OUTPUT_DIR/tstorie.js (JavaScript interface)"
    echo "  - $OUTPUT_DIR/index.html (HTML template)"
    # Copy index.md if it exists (needed at runtime)
    if [ -f "index.md" ]; then
        cp index.md "$OUTPUT_DIR/index.md"
        echo "  - $OUTPUT_DIR/index.md (runtime content)"
    fi
fi

# Check for required supporting files and copy renderers
if [ ! -f "$OUTPUT_DIR/tstorie-webgl.js" ]; then
    if [ -f "web/tstorie-webgl.js" ]; then
        cp web/tstorie-webgl.js "$OUTPUT_DIR/tstorie-webgl.js"
        echo "  - $OUTPUT_DIR/tstorie-webgl.js (WebGL renderer - copied)"
    else
        echo ""
        echo "Warning: web/tstorie-webgl.js not found."
        echo "         The WebGL renderer is required for the WASM build."
    fi
fi

# Copy WebGPU files for progressive enhancement (WebGPU → WebGL fallback)
for file in "webgpu_bridge.js" "webgpu_shader_system.js" "tstorie-webgpu-render.js" "tstorie-hybrid-renderer.js" "webgpu_wasm_bridge.js" "wgsl_runtime.js"; do
    if [ -f "web/$file" ]; then
        cp "web/$file" "$OUTPUT_DIR/$file"
        echo "  - $OUTPUT_DIR/$file (WebGPU support - copied)"
    elif [ -f "docs/$file" ]; then
        # wgsl_runtime.js is in docs/ not web/
        cp "docs/$file" "$OUTPUT_DIR/$file"
        echo "  - $OUTPUT_DIR/$file (WGSL runtime - copied)"
    fi
done

if [ ! -f "$OUTPUT_DIR/index.html" ]; then
    echo ""
    echo "Warning: $OUTPUT_DIR/index.html not found."
    echo "         Copy web/index.html to $OUTPUT_DIR/ or create the HTML template."
fi

# Start web server if requested
if [ "$SERVE" = true ]; then
    echo ""
    echo "Starting local web server..."
    echo "Open http://localhost:8000 in your browser"
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
    echo "  Then open http://localhost:8000 in your browser"
fi
